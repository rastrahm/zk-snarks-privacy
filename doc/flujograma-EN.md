# Flowchart — Full Privacy Pool cycle (ZK-SNARKs)

End-to-end flow between users, circuit, pool, verifier, and relayer (module 17, **v1 implemented**).  
**Sync:** 2026-09-13 · **65 PASS**.

## Actors

| Actor | Role |
|-------|------|
| Depositor | Generates `(nullifier, secret)`, computes the commitment, calls `deposit` |
| Withdrawer | Witness + Groth16 proof; calls `withdraw` (or via relayer) |
| Relayer | Pays gas; receives `fee` bound to the proof |
| PrivacyPool | Leaves, roots, nullifiers, verify, Yul payout |
| Groth16Verifier | Alt_BN128 pairing (`ecPairing` `0x08`) |
| Circom / SnarkJS | `Withdraw(4)`, fixtures, VK export |
| Deployer | `Deploy.s.sol`: hasher + verifier + pool |
| CI / Foundry | Unit, fuzz, gas snapshot, e2e fixture |

---

## Flowchart — Deploy

```mermaid
flowchart TD
    Start([Start]) --> Dep[Deploy.s.sol: PoseidonHasher + Groth16Verifier + PrivacyPool]
    Dep --> Env[DENOMINATION_WEI + MERKLE_TREE_LEVELS=4]
    Env --> Ready([Pool ready — levels must = circuit])
```

---

## Main flowchart — Deposit → Prove → Withdraw

```mermaid
flowchart TD
    Start([User picks nullifier and secret]) --> Comm[commitment = Poseidon nullifier, secret]
    Comm --> Dep[deposit commitment + denomination ETH]
    Dep --> Tree[Insert leaf + historical root]
    Tree --> Wait[Wait for anonymity set / time]
    Wait --> Path[Get Merkle path off-chain]
    Path --> Prove[SnarkJS: witness + Groth16 proof]
    Prove --> Mode{gasless withdraw?}
    Mode -->|No| W1[User calls withdraw fee=0]
    Mode -->|Yes| W2[Relayer calls withdraw with fee]
    W1 --> Val[Validate root + nullifier + proof]
    W2 --> Val
    Val --> Auth{all OK?}
    Auth -->|No| Fail[Revert custom error]
    Auth -->|Yes| Mark[Mark nullifierHash]
    Mark --> Pay[Payout recipient ± relayer]
    Pay --> Done([Funds withdrawn with no on-chain link to the deposit])
    Fail --> End([End])
    Done --> End
```

---

## Flowchart — Withdraw defense layers

```mermaid
flowchart TD
    A[Incoming withdraw] --> B[1. Known root isKnownRoot]
    B --> C[2. Nullifier not spent]
    C --> D[3. fee <= denomination]
    D --> E[4. verifyProof Groth16]
    E --> F[5. Mark nullifier CEI]
    F --> G[6. Yul ETH call recipient/relayer]
    B -.->|fail| X1[UnknownRoot]
    C -.->|fail| X2[NullifierAlreadySpent]
    D -.->|fail| X3[FeeExceedsDenomination]
    E -.->|fail| X4[InvalidZKProof]
    G -.->|fail| X5[EthTransferFailed]
    G --> Ok([Success])
```

---

## Flowchart — Circuit toolchain (lab)

```mermaid
flowchart TD
    Start([circuits/withdraw.circom Withdraw 4]) --> Comp[npm run compile:circuit]
    Comp --> Ptau[local lab ptau power-12]
    Ptau --> Setup[npm run generate:proof]
    Setup --> VK[npm run export:verifier]
    VK --> Fix[test/fixtures/withdraw]
    Fix --> Forge[Foundry e2e / gas]
    Forge --> End([65 PASS])
```

---

## Flowchart — Gasless relayer

```mermaid
flowchart TD
    Start([User without ETH for gas]) --> Build[User generates proof off-chain]
    Build --> Send[Sends proof + public inputs to relayer]
    Send --> Rel[Relayer: withdraw ... fee > 0]
    Rel --> Pool[PrivacyPool validates and pays]
    Pool --> U[recipient: denomination - fee]
    Pool --> R[relayer: fee]
    U --> Done([Tx confirmed])
    R --> Done
```

---

## Happy / failure path matrix

| Scenario | Expected result |
|----------|-----------------|
| Deposit with `msg.value == denomination` | Leaf inserted + `Deposit` |
| Withdraw valid proof + historical root | Payout + nullifier marked |
| Same `nullifierHash` twice | `NullifierAlreadySpent` |
| Never-seen root | `UnknownRoot` |
| Altered proof / signals | `InvalidZKProof` |
| `fee > denomination` | `FeeExceedsDenomination` |
| Recipient/relayer rejects ETH | `EthTransferFailed` |

---

## Related diagrams

- Type structure: [`diagrama-de-clases-EN.md`](./diagrama-de-clases-EN.md)
- Internal decisions: [`diagrama-de-flujo-EN.md`](./diagrama-de-flujo-EN.md)
- Phases / gas / SWC: [`planificacion-EN.md`](./planificacion-EN.md) · [`GAS-EN.md`](./GAS-EN.md) · [`SWC-AUDIT-EN.md`](./SWC-AUDIT-EN.md)
- Index: [`README-EN.md`](./README-EN.md)

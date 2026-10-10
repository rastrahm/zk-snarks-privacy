# Flow diagram — Deposit, prove, and withdraw

Internal decision flows of the pool, Merkle tree, and ZK verification (module 17, **v1 implemented**).  
**Sync:** 2026-09-13.

## 1. deposit (commitment + Merkle)

```mermaid
flowchart TD
    A[User: deposit commitment + msg.value] --> B{commitment != 0?}
    B -->|No| Z0[Revert InvalidCommitment]
    B -->|Yes| C{msg.value == denomination?}
    C -->|No| Z1[Revert InvalidDenomination]
    C -->|Yes| D{already deposited?}
    D -->|Yes| Z0
    D -->|No| E{nextIndex < 2^levels?}
    E -->|No| Z2[Revert TreeFull]
    E -->|Yes| F[commitments = true]
    F --> G[_insert leaf + roots ring]
    G --> H[Emit Deposit]
    Z0 --> End([End — revert])
    Z1 --> End
    Z2 --> End
    H --> Ok([End — OK])
```

> `commitment = Poseidon(nullifier, secret)` off-chain. Guard: **transient reentrancy**.

---

## 2. Proof generation (off-chain — Circom / SnarkJS)

```mermaid
flowchart TD
    A[User knows nullifier, secret, path] --> B[Compute nullifierHash = Poseidon nullifier]
    B --> C[Build input.json: private + public]
    C --> D[Witness + groth16 prove]
    D --> E[proof + publicSignals]
    E --> F[Export calldata / Foundry fixture]
    F --> Ok([Ready for on-chain withdraw])
```

---

## 3. withdraw (root → proof → nullifier → payout)

```mermaid
flowchart TD
    A[Caller: withdraw proof + public inputs] --> B{isKnownRoot root?}
    B -->|No| Z1[Revert UnknownRoot]
    B -->|Yes| C{nullifierHashes already true?}
    C -->|Yes| Z2[Revert NullifierAlreadySpent]
    C -->|No| D{fee <= denomination?}
    D -->|No| Z3[Revert FeeExceedsDenomination]
    D -->|Yes| E{recipient != 0?}
    E -->|No| Z4[Revert ZeroAddress]
    E -->|Yes| F[Pack publicInputs aligned with the circuit]
    F --> G{verifier.verifyProof?}
    G -->|No| Z5[Revert InvalidZKProof]
    G -->|Yes| H[nullifierHashes = true]
    H --> I[amountToRecipient = denomination - fee]
    I --> J[Yul ETH call to recipient]
    J --> K{OK?}
    K -->|No| Z6[Revert EthTransferFailed]
    K -->|Yes| L{fee > 0?}
    L -->|No| M[Emit Withdrawal]
    L -->|Yes| N[Yul ETH call to relayer]
    N --> O{OK?}
    O -->|No| Z6
    O -->|Yes| M
    Z1 --> End([End — revert])
    Z2 --> End
    Z3 --> End
    Z4 --> End
    Z5 --> End
    Z6 --> End
    M --> Ok([End — OK])
```

> CEI: mark `nullifierHashes` **before** the ETH `call`s (Yul, no returndata). Transient reentrancy.

---

## 4. Historical root validation

```mermaid
flowchart TD
    A[Withdraw with root R] --> B{R == currentRoot?}
    B -->|Yes| Ok[Continue]
    B -->|No| C{R in isKnownRoot history?}
    C -->|Yes| Ok
    C -->|No| Fail[UnknownRoot]
```

---

## 5. Anti double-spend (nullifier)

```mermaid
flowchart TD
    A[Withdraw with nullifierHash N] --> B{nullifierHashes N?}
    B -->|Yes| D[NullifierAlreadySpent]
    B -->|No| E[Mark + payout]
    D --> Fail([Revert])
    E --> Ok([A single withdraw per commitment])
```

---

## 6. Invalid / tampered proof

```mermaid
flowchart TD
    A[Altered proof or publicInputs] --> B[verifyProof]
    B --> C{pairing OK?}
    C -->|No| D[InvalidZKProof]
    C -->|Yes| E{signals == withdraw args?}
    E -->|No| D
    E -->|Yes| Ok([Legitimate path])
    D --> Fail([Revert — forgery blocked])
```

---

## 7. Relayer fee split

```mermaid
flowchart TD
    A[Fixed pool denomination] --> B[fee public in proof]
    B --> C{fee == 0?}
    C -->|Yes| D[100% to recipient]
    C -->|No| E[recipient: denomination - fee]
    E --> F[relayer: fee]
    D --> Done([Atomic payout in the same tx])
    F --> Done
```

---

## Related docs

- UML: [`diagrama-de-clases-EN.md`](./diagrama-de-clases-EN.md)
- E2E: [`flujograma-EN.md`](./flujograma-EN.md)
- Index: [`README-EN.md`](./README-EN.md)

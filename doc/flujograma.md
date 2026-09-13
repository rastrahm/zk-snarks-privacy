# Flujograma — Ciclo completo Privacy Pool (ZK-SNARKs)

Flujo extremo a extremo entre usuarios, circuito, pool, verifier y relayer (módulo 17, **v1 implementado**).  
**Sync:** 2026-09-13 · **65 PASS**.

## Actores

| Actor | Rol |
|-------|-----|
| Depositor | Genera `(nullifier, secret)`, calcula commitment, llama `deposit` |
| Withdrawer | Witness + proof Groth16; llama `withdraw` (o vía relayer) |
| Relayer | Paga gas; recibe `fee` ligado al proof |
| PrivacyPool | Leaves, roots, nullifiers, verify, payout Yul |
| Groth16Verifier | Pairing Alt_BN128 (`ecPairing` `0x08`) |
| Circom / SnarkJS | `Withdraw(4)`, fixtures, export VK |
| Deployer | `Deploy.s.sol`: hasher + verifier + pool |
| CI / Foundry | Unit, fuzz, gas snapshot, e2e fixture |

---

## Flujograma — Deploy

```mermaid
flowchart TD
    Start([Inicio]) --> Dep[Deploy.s.sol: PoseidonHasher + Groth16Verifier + PrivacyPool]
    Dep --> Env[DENOMINATION_WEI + MERKLE_TREE_LEVELS=4]
    Env --> Ready([Pool listo — levels deben = circuito])
```

---

## Flujograma principal — Deposit → Prove → Withdraw

```mermaid
flowchart TD
    Start([Usuario elige nullifier y secret]) --> Comm[commitment = Poseidon nullifier, secret]
    Comm --> Dep[deposit commitment + denomination ETH]
    Dep --> Tree[Insert leaf + root histórica]
    Tree --> Wait[Espera anonymity set / tiempo]
    Wait --> Path[Obtener Merkle path off-chain]
    Path --> Prove[SnarkJS: witness + Groth16 proof]
    Prove --> Mode{¿retiro gasless?}
    Mode -->|No| W1[Usuario llama withdraw fee=0]
    Mode -->|Sí| W2[Relayer llama withdraw con fee]
    W1 --> Val[Validar root + nullifier + proof]
    W2 --> Val
    Val --> Auth{¿todo OK?}
    Auth -->|No| Fail[Revert custom error]
    Auth -->|Sí| Mark[Marcar nullifierHash]
    Mark --> Pay[Payout recipient ± relayer]
    Pay --> Done([Fondos retirados sin link on-chain al deposit])
    Fail --> End([Fin])
    Done --> End
```

---

## Flujograma — Capas de defensa en withdraw

```mermaid
flowchart TD
    A[Withdraw entrante] --> B[1. Root conocida isKnownRoot]
    B --> C[2. Nullifier no gastado]
    C --> D[3. fee <= denomination]
    D --> E[4. verifyProof Groth16]
    E --> F[5. Marcar nullifier CEI]
    F --> G[6. Yul call ETH recipient/relayer]
    B -.->|fail| X1[UnknownRoot]
    C -.->|fail| X2[NullifierAlreadySpent]
    D -.->|fail| X3[FeeExceedsDenomination]
    E -.->|fail| X4[InvalidZKProof]
    G -.->|fail| X5[EthTransferFailed]
    G --> Ok([Éxito])
```

---

## Flujograma — Toolchain circuito (lab)

```mermaid
flowchart TD
    Start([circuits/withdraw.circom Withdraw 4]) --> Comp[npm run compile:circuit]
    Comp --> Ptau[ptau lab power-12 local]
    Ptau --> Setup[npm run generate:proof]
    Setup --> VK[npm run export:verifier]
    VK --> Fix[test/fixtures/withdraw]
    Fix --> Forge[Foundry e2e / gas]
    Forge --> End([65 PASS])
```

---

## Flujograma — Relayer gasless

```mermaid
flowchart TD
    Start([Usuario sin ETH para gas]) --> Build[Usuario genera proof off-chain]
    Build --> Send[Envía proof + públicos al relayer]
    Send --> Rel[Relayer: withdraw ... fee > 0]
    Rel --> Pool[PrivacyPool valida y paga]
    Pool --> U[recipient: denomination - fee]
    Pool --> R[relayer: fee]
    U --> Done([Tx confirmada])
    R --> Done
```

---

## Matriz de caminos felices / fallo

| Escenario | Resultado esperado |
|-----------|-------------------|
| Deposit con `msg.value == denomination` | Leaf insertado + `Deposit` |
| Withdraw proof válida + root histórica | Payout + nullifier marcado |
| Mismo `nullifierHash` dos veces | `NullifierAlreadySpent` |
| Root nunca vista | `UnknownRoot` |
| Proof / signals alterados | `InvalidZKProof` |
| `fee > denomination` | `FeeExceedsDenomination` |
| Recipient/relayer rechaza ETH | `EthTransferFailed` |

---

## Relación con otros diagramas

- Estructura de tipos: [`diagrama-de-clases.md`](./diagrama-de-clases.md)
- Decisiones internas: [`diagrama-de-flujo.md`](./diagrama-de-flujo.md)
- Fases / gas / SWC: [`planificacion.md`](./planificacion.md) · [`GAS.md`](./GAS.md) · [`SWC-AUDIT.md`](./SWC-AUDIT.md)
- Índice: [`README.md`](./README.md)

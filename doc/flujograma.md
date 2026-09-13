# Flujograma — Ciclo completo Privacy Pool (ZK-SNARKs)

Flujo extremo a extremo entre usuarios, circuito, pool, verifier y relayer (módulo 17, **planificación v1**).

## Actores

| Actor | Rol |
|-------|-----|
| Depositor | Genera `(nullifier, secret)`, calcula commitment, llama `deposit` |
| Withdrawer | Construye witness + proof Groth16; llama `withdraw` (o pide a relayer) |
| Relayer | Paga gas; recibe `fee`; entrega proof en nombre del usuario |
| PrivacyPool | Inserta leaves, guarda roots/nullifiers, verifica proof, paga ETH |
| Groth16Verifier | Pairing Alt_BN128 (`ecPairing` `0x08`) |
| Circom / SnarkJS | Compila circuito, genera proof y VK |
| Admin / owner | Deploy denomination, hasher, verifier (mínimo en v1) |
| CI / Foundry | Unit, fixtures de proof, fuzz Merkle, gas |

---

## Flujograma — Deploy

```mermaid
flowchart TD
    Start([Inicio]) --> Dep[Deploy Hasher + Groth16Verifier + PrivacyPool]
    Dep --> Den[denomination immutable]
    Den --> Link[Pool apunta a hasher y verifier]
    Link --> Ready([Pool listo para deposits])
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
    F --> G[6. Transferencias ETH .call]
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
    Start([circuits/withdraw.circom]) --> Comp[circom compile r1cs wasm]
    Comp --> Ptau[Powers of Tau lab — no commitear]
    Ptau --> Setup[snarkjs groth16 setup → zkey]
    Setup --> VK[Export verification_key / Verifier.sol]
    VK --> Fix[generate-proof → test/fixtures]
    Fix --> Forge[Foundry consume fixtures]
    Forge --> End([Tests de integración ZK])
```

---

## Flujograma — Relayer gasless

```mermaid
flowchart TD
    Start([Usuario sin ETH para gas]) --> Build[Usuario genera proof off-chain]
    Build --> Send[Envía proof + públicos al relayer]
    Send --> Rel[Relayer: withdraw ... fee > 0]
    Rel --> Pool[PrivacyPool valida y paga]
    Pool --> U[recipient recibe denomination - fee]
    Pool --> R[relayer recibe fee + reembolso de gas off-protocol]
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
| `msg.value != denomination` en deposit | `InvalidDenomination` |

---

## Relación con otros diagramas

- Estructura de tipos: [`diagrama-de-clases.md`](./diagrama-de-clases.md)
- Decisiones internas detalladas: [`diagrama-de-flujo.md`](./diagrama-de-flujo.md)
- Fases y gates: [`planificacion.md`](./planificacion.md)

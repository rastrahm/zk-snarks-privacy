# Diagrama de flujo — Deposit, prove y withdraw

Flujos de decisión internos del pool, Merkle tree y verificación ZK (módulo 17, **planificación v1**).

## 1. deposit (commitment + Merkle)

```mermaid
flowchart TD
    A[Usuario: deposit commitment + msg.value] --> B{¿commitment != 0?}
    B -->|No| Z0[Revert InvalidCommitment]
    B -->|Sí| C{¿msg.value == denomination?}
    C -->|No| Z1[Revert InvalidDenomination]
    C -->|Sí| D{¿árbol con capacidad?}
    D -->|No| Z2[Revert TreeFull]
    D -->|Sí| E[Insert leaf en MerkleTreeWithHistory]
    E --> F[Registrar currentRoot en isKnownRoot / roots]
    F --> G[Emit Deposit index, commitment, root]
    Z0 --> End([Fin — revert])
    Z1 --> End
    Z2 --> End
    G --> Ok([Fin — OK])
```

> El `commitment = Poseidon(nullifier, secret)` se calcula **off-chain**; on-chain solo se inserta el leaf.

---

## 2. Generación de proof (off-chain — Circom / SnarkJS)

```mermaid
flowchart TD
    A[Usuario conoce nullifier, secret, path] --> B[Calcular nullifierHash = Poseidon nullifier]
    B --> C[Armar input.json: privados + públicos]
    C --> D[Witness + groth16 prove]
    D --> E[proof + publicSignals]
    E --> F[Export calldata / fixture Foundry]
    F --> Ok([Listo para withdraw on-chain])
```

---

## 3. withdraw (root → proof → nullifier → payout)

```mermaid
flowchart TD
    A[Caller: withdraw proof + públicos] --> B{¿isKnownRoot root?}
    B -->|No| Z1[Revert UnknownRoot]
    B -->|Sí| C{¿nullifierHashes ya true?}
    C -->|Sí| Z2[Revert NullifierAlreadySpent]
    C -->|No| D{¿fee <= denomination?}
    D -->|No| Z3[Revert FeeExceedsDenomination]
    D -->|Sí| E{¿recipient != 0?}
    E -->|No| Z4[Revert ZeroAddress]
    E -->|Sí| F[Pack publicInputs alineados al circuito]
    F --> G{¿verifier.verifyProof?}
    G -->|No| Z5[Revert InvalidZKProof]
    G -->|Sí| H[nullifierHashes hash = true]
    H --> I[amountToRecipient = denomination - fee]
    I --> J[.call value amountToRecipient a recipient]
    J --> K{¿OK?}
    K -->|No| Z6[Revert EthTransferFailed]
    K -->|Sí| L{¿fee > 0 y relayer != 0?}
    L -->|No| M[Emit Withdraw]
    L -->|Sí| N[.call value fee a relayer]
    N --> O{¿OK?}
    O -->|No| Z6
    O -->|Sí| M
    Z1 --> End([Fin — revert])
    Z2 --> End
    Z3 --> End
    Z4 --> End
    Z5 --> End
    Z6 --> End
    M --> Ok([Fin — OK])
```

> CEI: marcar `nullifierHashes` **antes** de las transferencias ETH.

---

## 4. Validación de raíz histórica

```mermaid
flowchart TD
    A[Withdraw con root R] --> B{¿R == currentRoot?}
    B -->|Sí| Ok[Continuar]
    B -->|No| C{¿R en historial isKnownRoot?}
    C -->|Sí| Ok
    C -->|No| Fail[UnknownRoot]
```

---

## 5. Anti double-spend (nullifier)

```mermaid
flowchart TD
    A[Withdraw con nullifierHash N] --> B{¿nullifierHashes N?}
    B -->|Sí| D[NullifierAlreadySpent]
    B -->|No| E[Marcar + payout]
    D --> Fail([Revert])
    E --> Ok([Un solo retiro por commitment])
```

---

## 6. Proof inválida / tampered

```mermaid
flowchart TD
    A[Proof o publicInputs alterados] --> B[verifyProof]
    B --> C{¿pairing OK?}
    C -->|No| D[InvalidZKProof]
    C -->|Sí| E{¿signals == args withdraw?}
    E -->|No| D
    E -->|Sí| Ok([Path legítimo])
    D --> Fail([Revert — forge bloqueado])
```

---

## 7. Relayer fee split

```mermaid
flowchart TD
    A[denomination fija del pool] --> B[fee público en proof]
    B --> C{¿fee == 0?}
    C -->|Sí| D[100% a recipient]
    C -->|No| E[recipient: denomination - fee]
    E --> F[relayer: fee]
    D --> Done([Payout atómico en misma tx])
    F --> Done
```

# Diagrama de clases — ZK-SNARKs & Privacy Protocols

Vista estructural propuesta de contratos, circuitos, librerías e interfaces (módulo 17, **planificación v1**).

## Diagrama (Mermaid)

```mermaid
classDiagram
    direction TB

    class IPrivacyPool {
        <<interface>>
        +denomination() uint256
        +currentRoot() bytes32
        +isKnownRoot(root) bool
        +nullifierHashes(hash) bool
        +deposit(commitment) payable
        +withdraw(proof, root, nullifierHash, recipient, relayer, fee)
    }

    class IHasher {
        <<interface>>
        +hash(left, right) bytes32
        +hashPreimage(nullifier, secret) bytes32
    }

    class IVerifier {
        <<interface>>
        +verifyProof(a, b, c, input) bool
    }

    class PrivacyErrors {
        <<errors>>
        +NullifierAlreadySpent()
        +InvalidZKProof()
        +UnknownRoot()
        +InvalidCommitment()
        +TreeFull()
        +FeeExceedsDenomination()
        +EthTransferFailed()
        +ZeroAddress()
        +InvalidDenomination()
        +Unauthorized()
    }

    class PoseidonT3 {
        <<library / contract>>
        +hash(left, right) bytes32
    }

    class MerkleTreeWithHistory {
        <<library / base>>
        +levels uint32
        +currentRootIndex uint32
        +nextIndex uint32
        +filledSubtrees bytes32[]
        +roots bytes32[]
        +_insert(leaf) uint32
        +isKnownRoot(root) bool
        +getLastRoot() bytes32
    }

    class ProofLib {
        <<library>>
        +packPublicInputs(root, nullifierHash, recipient, relayer, fee) uint256[]
        +decodeProof(data) Proof
    }

    class Proof {
        <<struct>>
        +a uint256[2]
        +b uint256[2][2]
        +c uint256[2]
    }

    class Groth16Verifier {
        +verifyProof(a, b, c, input) bool
    }

    class PrivacyPool {
        +denomination uint256
        +hasher IHasher
        +verifier IVerifier
        +nullifierHashes mapping
        +deposit(commitment) payable
        +withdraw(proof, root, nullifierHash, recipient, relayer, fee)
    }

    class MockVerifier {
        <<mock>>
        +shouldPass bool
        +verifyProof(...) bool
    }

    class MockHasher {
        <<mock>>
        +hash(left, right) bytes32
    }

    class WithdrawCircuit {
        <<circom>>
        +nullifier private
        +secret private
        +pathElements private
        +pathIndices private
        +root public
        +nullifierHash public
        +recipient public
        +relayer public
        +fee public
    }

    IPrivacyPool <|.. PrivacyPool
    IHasher <|.. PoseidonT3
    IHasher <|.. MockHasher
    IVerifier <|.. Groth16Verifier
    IVerifier <|.. MockVerifier

    PrivacyPool --> IHasher : commitment / tree nodes
    PrivacyPool --> IVerifier : verifyProof
    PrivacyPool --> MerkleTreeWithHistory : insert / roots
    PrivacyPool --> ProofLib : public inputs
    PrivacyPool --> PrivacyErrors : reverts
    PrivacyPool o-- Proof : withdraw args

    MerkleTreeWithHistory --> IHasher : parent = hash(L,R)
    ProofLib ..> Proof : packs
    Groth16Verifier ..> WithdrawCircuit : VK matches circuit
```

---

## Relaciones clave

| Relación | Descripción |
|----------|-------------|
| Pool → Hasher | `commitment` off-chain; nodos on-chain con el mismo Poseidon |
| Pool → MerkleTreeWithHistory | Cada deposit inserta leaf y registra root en historial |
| Pool → Verifier | Solo withdraw con proof Groth16 válida |
| Pool → nullifierHashes | Un nullifierHash = un withdraw (anti double-spend) |
| Circuito → Verifier | Misma VK; señales públicas deben casar 1:1 con args de withdraw |
| Relayer | No es contrato: EOA que llama `withdraw` y recibe `fee` |

---

## Notas de diseño

- `ReentrancyGuard` en `deposit` / `withdraw`; CEI: marcar nullifier **antes** de `.call` ETH.
- Denomination `immutable` para gas y anonymity set fijo.
- `isKnownRoot` debe aceptar raíces anteriores (nuevos deposits no invalidan proofs en vuelo).
- El circuito vive off-chain (`circuits/`); on-chain solo la VK embebida en `Groth16Verifier`.
- Detalle de flujos: [`diagrama-de-flujo.md`](./diagrama-de-flujo.md) · ciclo e2e: [`flujograma.md`](./flujograma.md).

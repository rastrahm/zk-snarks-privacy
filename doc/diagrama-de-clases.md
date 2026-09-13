# Diagrama de clases — ZK-SNARKs & Privacy Protocols

Vista estructural de contratos, circuitos, librerías e interfaces (módulo 17, **v1 implementado**).  
**Sync:** 2026-09-13 · Suite **65 PASS**.

## Diagrama (Mermaid)

```mermaid
classDiagram
    direction TB

    class IPrivacyPool {
        <<interface>>
        +denomination() uint256
        +currentRoot() bytes32
        +nullifierHashes(hash) bool
        +deposit(commitment) payable
        +withdraw(a,b,c,root,nullifierHash,recipient,relayer,fee)
    }

    class IHasher {
        <<interface>>
        +hashLeftRight(left, right) bytes32
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

    class TransientReentrancyGuard {
        <<abstract>>
        +nonReentrant()
    }

    class PoseidonT3 {
        <<library>>
        +hash(uint256[2]) uint256
    }

    class PoseidonHasher {
        +hashLeftRight(left, right) bytes32
        +hashPreimage(nullifier, secret) bytes32
    }

    class MerkleTreeWithHistory {
        <<abstract>>
        +ROOT_HISTORY_SIZE uint32
        +levels uint32
        +hasher IHasher
        +filledSubtrees bytes32[32]
        +zeros bytes32[32]
        +roots bytes32[30]
        +nextIndex() uint32
        +currentRootIndex() uint32
        +_insert(leaf) uint32
        +isKnownRoot(root) bool
        +getLastRoot() bytes32
    }

    class Groth16Verifier {
        +verifyProof(a, b, c, input) bool
    }

    class VerifierGate {
        +VERIFIER IVerifier
        +requireValidProof(a,b,c,input)
    }

    class PrivacyPool {
        +denomination uint256
        +verifier IVerifier
        +nullifierHashes mapping
        +commitments mapping
        +deposit(commitment) payable
        +withdraw(a,b,c,root,nullifierHash,recipient,relayer,fee)
        +currentRoot() bytes32
    }

    class MockVerifier {
        <<mock>>
        +shouldPass bool
        +verifyProof(...) bool
    }

    class MockHasher {
        <<mock>>
        +hashLeftRight(...) bytes32
        +hashPreimage(...) bytes32
    }

    class RejectETH {
        <<mock>>
        +receive()
    }

    class WithdrawCircuit {
        <<circom Withdraw(4)>>
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
    IHasher <|.. PoseidonHasher
    IHasher <|.. MockHasher
    IVerifier <|.. Groth16Verifier
    IVerifier <|.. MockVerifier

    TransientReentrancyGuard <|-- PrivacyPool
    MerkleTreeWithHistory <|-- PrivacyPool
    PoseidonHasher --> PoseidonT3
    VerifierGate --> IVerifier
    PrivacyPool --> IVerifier : verifyProof
    PrivacyPool --> PrivacyErrors : reverts
    MerkleTreeWithHistory --> IHasher : parent hash
    Groth16Verifier ..> WithdrawCircuit : VK matches
```

---

## Relaciones clave

| Relación | Descripción |
|----------|-------------|
| Pool → Hasher | Nodos on-chain Poseidon; commitment off-chain |
| Pool → MerkleTreeWithHistory | Deposit inserta leaf; ring de 30 roots |
| Pool → Verifier | Withdraw solo con Groth16 válida |
| Pool → nullifierHashes | Un hash = un withdraw |
| Circuito → Verifier | 5 públicos en el mismo orden |
| Relayer | EOA/`msg.sender` de withdraw; recibe `fee` |

---

## Notas de diseño

- `TransientReentrancyGuard` (Cancun) + CEI: nullifier **antes** de ETH Yul `call`.
- Merkle: arrays fijos + `_packedIndices` (no mappings de índices).
- Lab: **levels = 4**; cambiar circuito + re-exportar VK para otra profundidad.
- Suite: **65 PASS**. [`GAS.md`](./GAS.md) · [`SWC-AUDIT.md`](./SWC-AUDIT.md) · flujos: [`diagrama-de-flujo.md`](./diagrama-de-flujo.md) / [`flujograma.md`](./flujograma.md).

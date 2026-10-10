# Class diagram — ZK-SNARKs & Privacy Protocols

Structural view of contracts, circuits, libraries, and interfaces (module 17, **v1 implemented**).  
**Sync:** 2026-09-13 · Suite **65 PASS**.

## Diagram (Mermaid)

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

## Key relationships

| Relationship | Description |
|--------------|-------------|
| Pool → Hasher | On-chain Poseidon nodes; commitment computed off-chain |
| Pool → MerkleTreeWithHistory | Deposit inserts a leaf; ring of 30 roots |
| Pool → Verifier | Withdraw only with a valid Groth16 proof |
| Pool → nullifierHashes | One hash = one withdraw |
| Circuit → Verifier | 5 public signals in the same order |
| Relayer | EOA/`msg.sender` of withdraw; receives `fee` |

---

## Design notes

- `TransientReentrancyGuard` (Cancun) + CEI: nullifier **before** the Yul ETH `call`.
- Merkle: fixed arrays + `_packedIndices` (no index mappings).
- Lab: **levels = 4**; change the circuit + re-export the VK for another depth.
- Suite: **65 PASS**. [`GAS-EN.md`](./GAS-EN.md) · [`SWC-AUDIT-EN.md`](./SWC-AUDIT-EN.md) · flows: [`diagrama-de-flujo-EN.md`](./diagrama-de-flujo-EN.md) / [`flujograma-EN.md`](./flujograma-EN.md).

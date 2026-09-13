# Auditoría SWC — ZK-SNARKs & Privacy Protocols

Verificación del Privacy Pool contra el [SWC Registry](https://swcregistry.io/) (EIP-1470). Estilo alineado a [`01-erc20/doc/SWC-AUDIT.md`](../../01-erc20/doc/SWC-AUDIT.md).

> **Nota:** El SWC Registry no se mantiene activamente desde ~2020. Complementar con [SCSVS](https://github.com/ComposableSecurity/SCSVS) y [EEA EthTrust](https://entethalliance.org/specs/ethtrust/).

**Contratos auditados (prod / core):**  
`src/PrivacyPool.sol`,  
`src/libraries/MerkleTreeWithHistory.sol`,  
`src/PoseidonHasher.sol`,  
`src/verifiers/{Groth16Verifier,VerifierGate}.sol`,  
`src/interfaces/{IPrivacyPool,IHasher,IVerifier}.sol`,  
`src/errors/PrivacyErrors.sol`

**Dependencias de confianza (fuera de alcance de bugs propios):**  
OpenZeppelin Contracts v5.2 (`ReentrancyGuard`), PoseidonT3 (`poseidon-solidity` MIT), Groth16Verifier (snarkJS GPL-3.0)

**Mocks (fuera de prod):** `MockHasher`, `MockVerifier`, `RejectETH`  
**Fecha:** 2026-09-13  
**Referencia tests:** `test/NullifierReplay.t.sol`, `test/InvalidRoot.t.sol`, `test/PoolProofVerification.t.sol`, `test/RelayerFee.t.sol`, `test/ProofVerification.t.sol`, `test/PrivacyPool*.t.sol`  
**Índice:** [`planificacion.md`](./planificacion.md) · README: [`../README.md`](../README.md)

---

## Resumen ejecutivo

| Estado | Cantidad |
|--------|----------|
| ✅ Mitigado / No aplicable | 30 |
| ⚠️ Informativo (diseño mixer / trust / ops) | 6 |
| ❌ Vulnerable | 0 |

**Conclusión:** Sin vulnerabilidades SWC explotables en el alcance v1. El pool usa **`ReentrancyGuard`**, **CEI** (nullifier antes de ETH), **`isKnownRoot`**, **`nullifierHashes`**, verificación **Groth16** con binding de recipient/relayer/fee, **custom errors** y pragma fijo **`0.8.24`**. Riesgos informativos: trusted setup de lab, anonymity set pequeño (depth 4), front-running de withdraw en mempool, dependencia de hasher/verifier correctos en deploy.

**Principios del suite / módulo 17 verificados:**

| Principio | Estado |
|-----------|--------|
| Custom errors (no `require` strings) | ✅ `PrivacyErrors` |
| Pragma fijo `0.8.24` | ✅ (Groth16Verifier parcheado) |
| CEI + `ReentrancyGuard` | ✅ deposit / withdraw |
| ETH `.call` (no `transfer`/`send`) | ✅ `_sendEth` |
| `NullifierAlreadySpent` | ✅ |
| `isKnownRoot` histórico | ✅ |
| Relayer fee split atómico | ✅ |
| ZK proof binding públicos | ✅ |
| Fuzz ≥ 1000 runs | ✅ `foundry.toml` |

---

## Matriz completa SWC-100 — SWC-136

| ID | Título | Aplica | Estado | Evidencia en Privacy Pool |
|----|--------|--------|--------|---------------------------|
| SWC-100 | Function Default Visibility | Sí | ✅ | Visibilidad explícita en `src/` |
| SWC-101 | Integer Overflow and Underflow | Sí | ✅ | Solidity `0.8.24`; `fee <= denomination` antes de resta |
| SWC-102 | Outdated Compiler Version | Sí | ✅ | `pragma solidity 0.8.24` + `foundry.toml` |
| SWC-103 | Floating Pragma | Sí | ✅ | Pragma exacto (sin `^`); verifier export parcheado |
| SWC-104 | Unchecked Call Return Value | Sí | ✅ | `_sendEth` chequea `ok` → `EthTransferFailed` |
| SWC-105 | Unprotected Ether Withdrawal | Sí | ✅ | Solo `withdraw` con proof+nullifier; sin drain admin |
| SWC-106 | Unprotected SELFDESTRUCT | No | N/A | Sin `selfdestruct` |
| SWC-107 | Reentrancy | Sí | ✅ | `nonReentrant` + marcar nullifier antes de `.call` |
| SWC-108 | State Variable Default Visibility | Sí | ✅ | `public` / `immutable` / `mapping` explícitos |
| SWC-109 | Uninitialized Storage Pointer | No | N/A | Sin punteros storage legacy |
| SWC-110 | Assert Violation | No | N/A | Sin `assert` de producción |
| SWC-111 | Deprecated Solidity Functions | Sí | ✅ | Sin `suicide` / `throw` / `tx.origin` / ETH `transfer`/`send` |
| SWC-112 | Delegatecall to Untrusted Callee | No | N/A | Sin `delegatecall` (PoseidonT3 library link ok) |
| SWC-113 | DoS with Failed Call | Parcial | ✅ | Recipient/relayer que rechazan ETH revierten tx; tests `RejectETH` |
| SWC-114 | Transaction Order Dependence | Sí | ⚠️ | Front-running de withdraw en mempool — ver riesgos |
| SWC-115 | Authorization through tx.origin | No | N/A | Auth vía proof ZK, no `tx.origin` |
| SWC-116 | Block values as a proxy for time | Parcial | ✅ | `block.timestamp` solo en evento `Deposit` (no auth) |
| SWC-117 | Signature Malleability | Parcial | ⚠️ | Groth16 malleability residual — ver riesgos |
| SWC-118 | Incorrect Constructor Name | No | N/A | `constructor` 0.8+ |
| SWC-119 | Shadowing State Variables | Sí | ✅ | Sin shadowing material |
| SWC-120 | Weak Sources of Randomness | No | N/A | Sin RNG on-chain |
| SWC-121 | Missing Protection against Signature Replay | Sí | ✅ | Equivalente: `nullifierHashes` + tests NullifierReplay |
| SWC-122 | Lack of Proper Signature Verification | Sí | ✅ | `verifier.verifyProof` + binding públicos; tests tampered |
| SWC-123 | Requirement Violation | Sí | ✅ | Custom errors + matriz Fase 6 |
| SWC-124 | Write to Arbitrary Storage Location | Parcial | ✅ | Assembly solo en PoseidonT3 / Groth16 pairing (memory) |
| SWC-125 | Incorrect Inheritance Order | Sí | ✅ | `IPrivacyPool, MerkleTreeWithHistory, ReentrancyGuard` |
| SWC-126 | Insufficient Gas Griefing | Parcial | ⚠️ | Relayer paga gas; recipient malicioso puede revertir — ver riesgos |
| SWC-127 | Arbitrary Jump with Function Type Variable | No | N/A | Sin function types dinámicos |
| SWC-128 | DoS With Block Gas Limit | Parcial | ✅ | Insert O(levels); levels fijo (lab 4 / prod tipico 20) |
| SWC-129 | Typographical Error | Sí | ✅ | Revisión + `forge test` |
| SWC-130 | Right-To-Left-Override control character | No | N/A | ASCII en NatSpec/tests |
| SWC-131 | Presence of unused variables | Sí | ✅ | Sin variables muertas materiales |
| SWC-132 | Unexpected Ether balance | Parcial | ✅ | Balance = deposits no gastados; withdraw exacto denomination |
| SWC-133 | Hash Collisions With Multiple Variable Length Arguments | Parcial | ✅ | Poseidon field hash; commitments `bytes32` fijos |
| SWC-134 | Message call with hardcoded gas amount | No | N/A | Sin `.call{gas: ...}` |
| SWC-135 | Code With No Effects | No | N/A | Sin statements vacíos relevantes |
| SWC-136 | Unencrypted Private Data On-Chain | Parcial | ⚠️ | Commitments/roots publicos por diseño mixer — ver riesgos |

---

## Riesgos informativos

### SWC-114 — Front-running de `withdraw`

**Descripción:** Un observador del mempool puede ver la proof y reenviarla con el mismo nullifier (o intentar frontrun). El primero en confirmar gasta el nullifier; el segundo revierte `NullifierAlreadySpent`.

**Estado:** ⚠️ Inherente a mixers on-chain; mitigado parcialmente por binding recipient/relayer/fee en el circuito (no se puede cambiar el payout sin invalidar la proof).

**Mitigaciones:** Binding de públicos; relayer privado / flashbots opcional (fuera de v1).

### SWC-117 — Malleability Groth16

**Descripción:** Algunas formas de malleability de proofs Groth16 existen en literatura; el nullifier on-chain evita double-spend aunque la proof se reescriba.

**Estado:** ⚠️ Informativo; el gasto único depende de `nullifierHash`, no de unicidad de la proof.

### SWC-126 — Relayer / recipient griefing

**Descripción:** Si `recipient` (o `relayer` con fee > 0) rechaza ETH, toda la tx revierte. Un usuario que elige un recipient contract hostil no puede completar el withdraw.

**Estado:** ⚠️ By design; responsabilidad del prover al elegir addresses.

### SWC-136 — Datos públicos del anonymity set

**Descripción:** Commitments, roots e historial son visibles on-chain. La privacidad depende del tamaño del set y de no reutilizar nullifiers/secrets off-chain.

**Estado:** ⚠️ Diseño de mixer; depth lab = 4 (set pequeño). Producción tipica usa depth 20.

### Trusted setup (ops)

**Descripción:** El ptau/zkey de lab es una ceremonia insegura local. Un VK comprometido permite proofs falsas.

**Estado:** ⚠️ Ops; usar ptau público auditado + ceremony multi-party antes de mainnet.

### Deploy hasher / verifier incorrectos

**Descripción:** Si el deploy usa `MockHasher` o un verifier de otro circuito, deposits/withdraws no alinean con proofs de usuarios.

**Estado:** ⚠️ Ops; `Deploy.s.sol` (Fase 7) debe cablear Poseidon + Groth16 del mismo circuito.

---

## Mapeo SWC → tests (Fase 6)

| SWC / amenaza | Test(s) |
|---------------|---------|
| Double-spend / SWC-121 | `NullifierReplay.t.sol` |
| Root inválida | `InvalidRoot.t.sol` |
| Proof / binding (SWC-122) | `PoolProofVerification.t.sol`, `ProofVerification.t.sol` |
| Relayer fee / SWC-104 | `RelayerFee.t.sol` |
| Reentrancy / SWC-107 | CEI en `PrivacyPool.withdraw`; `nonReentrant` |
| Reject ETH / SWC-113 | `test_relayerRejectsEth_reverts`, `RejectETH` |
| Overflow fee | `test_feeExceedsDenomination_reverts` |

---

## Referencias

- [SWC Registry](https://swcregistry.io/)
- [EIP-1470](https://eips.ethereum.org/EIPS/eip-1470)
- [Tornado Cash research / nullifiers](https://tornado.cash/) (referencia educativa)
- [`01-erc20/doc/SWC-AUDIT.md`](../../01-erc20/doc/SWC-AUDIT.md)
- [`circuits/README.md`](../circuits/README.md)

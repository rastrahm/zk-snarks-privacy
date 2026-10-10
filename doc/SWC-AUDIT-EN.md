# SWC Audit — ZK-SNARKs & Privacy Protocols

Verification of the Privacy Pool against the [SWC Registry](https://swcregistry.io/) (EIP-1470). Style aligned with [`01-erc20/doc/SWC-AUDIT-EN.md`](../../01-erc20/doc/SWC-AUDIT-EN.md).

> **Note:** The SWC Registry has not been actively maintained since ~2020. Complement it with [SCSVS](https://github.com/ComposableSecurity/SCSVS) and [EEA EthTrust](https://entethalliance.org/specs/ethtrust/).

**Audited contracts (prod / core):**  
`src/PrivacyPool.sol`,  
`src/PoseidonHasher.sol`,  
`src/libraries/{MerkleTreeWithHistory,TransientReentrancyGuard,PoseidonT3}.sol`,  
`src/verifiers/{Groth16Verifier,VerifierGate}.sol`,  
`src/interfaces/{IPrivacyPool,IHasher,IVerifier}.sol`,  
`src/errors/PrivacyErrors.sol`

**Trusted dependencies (out of scope for own bugs):**  
forge-std, OpenZeppelin Contracts v5.2 (in `lib/`; the pool does not use OZ ReentrancyGuard), PoseidonT3 (`poseidon-solidity` MIT), Groth16Verifier (snarkJS GPL-3.0)

**Mocks (not prod):** `MockHasher`, `MockVerifier`, `RejectETH`  
**Date:** 2026-09-13 (post Phase 7 / docs sync)  
**Test references:** `test/NullifierReplay.t.sol`, `test/InvalidRoot.t.sol`, `test/PoolProofVerification.t.sol`, `test/RelayerFee.t.sol`, `test/ProofVerification.t.sol`, `test/PrivacyPool*.t.sol`, `test/gas/`  
**Index:** [`README-EN.md`](./README-EN.md) · Module README: [`../README-EN.md`](../README-EN.md)

---

## Executive summary

| Status | Count |
|--------|-------|
| ✅ Mitigated / Not applicable | 30 |
| ⚠️ Informational (mixer design / trust / ops) | 6 |
| ❌ Vulnerable | 0 |

**Conclusion:** No exploitable SWC vulnerabilities in v1 scope. The pool uses **`TransientReentrancyGuard`**, **CEI** (nullifier before Yul ETH), **`isKnownRoot`**, **`nullifierHashes`**, **Groth16** verification with recipient/relayer/fee binding, **custom errors**, and fixed pragma **`0.8.24`**. Informational risks: lab trusted setup, small anonymity set (depth 4), withdraw front-running in the mempool, reliance on a correct hasher/verifier at deploy.

**Suite / module 17 principles verified:**

| Principle | Status |
|-----------|--------|
| Custom errors (no `require` strings) | ✅ `PrivacyErrors` |
| Fixed pragma `0.8.24` | ✅ (Groth16Verifier patched) |
| CEI + `ReentrancyGuard` | ✅ CEI + **transient** reentrancy (Cancun) |
| ETH `.call` (no `transfer`/`send`) | ✅ Yul `call` without returndata |
| `NullifierAlreadySpent` | ✅ |
| Historical `isKnownRoot` | ✅ |
| Atomic relayer fee split | ✅ |
| ZK proof public binding | ✅ |
| Fuzz ≥ 1000 runs | ✅ `foundry.toml` |

---

## Full matrix SWC-100 — SWC-136

| ID | Title | Applies | Status | Evidence in Privacy Pool |
|----|-------|---------|--------|--------------------------|
| SWC-100 | Function Default Visibility | Yes | ✅ | Explicit visibility in `src/` |
| SWC-101 | Integer Overflow and Underflow | Yes | ✅ | Solidity `0.8.24`; `fee <= denomination` before subtraction |
| SWC-102 | Outdated Compiler Version | Yes | ✅ | `pragma solidity 0.8.24` + `foundry.toml` |
| SWC-103 | Floating Pragma | Yes | ✅ | Exact pragma (no `^`); exported verifier patched |
| SWC-104 | Unchecked Call Return Value | Yes | ✅ | `_sendEth` checks `ok` → `EthTransferFailed` |
| SWC-105 | Unprotected Ether Withdrawal | Yes | ✅ | Only `withdraw` with proof+nullifier; no admin drain |
| SWC-106 | Unprotected SELFDESTRUCT | No | N/A | No `selfdestruct` |
| SWC-107 | Reentrancy | Yes | ✅ | `TransientReentrancyGuard` (tstore) + nullifier before ETH |
| SWC-108 | State Variable Default Visibility | Yes | ✅ | Explicit `public` / `immutable` / `mapping` |
| SWC-109 | Uninitialized Storage Pointer | No | N/A | No legacy storage pointers |
| SWC-110 | Assert Violation | No | N/A | No production `assert` |
| SWC-111 | Deprecated Solidity Functions | Yes | ✅ | No `suicide` / `throw` / `tx.origin` / ETH `transfer`/`send` |
| SWC-112 | Delegatecall to Untrusted Callee | No | N/A | No `delegatecall` (PoseidonT3 library link ok) |
| SWC-113 | DoS with Failed Call | Partial | ✅ | Recipient/relayer rejecting ETH revert the tx; `RejectETH` tests |
| SWC-114 | Transaction Order Dependence | Yes | ⚠️ | Withdraw front-running in the mempool — see risks |
| SWC-115 | Authorization through tx.origin | No | N/A | Auth via ZK proof, not `tx.origin` |
| SWC-116 | Block values as a proxy for time | Partial | ✅ | `block.timestamp` only in the `Deposit` event (no auth) |
| SWC-117 | Signature Malleability | Partial | ⚠️ | Residual Groth16 malleability — see risks |
| SWC-118 | Incorrect Constructor Name | No | N/A | 0.8+ `constructor` |
| SWC-119 | Shadowing State Variables | Yes | ✅ | No material shadowing |
| SWC-120 | Weak Sources of Randomness | No | N/A | No on-chain RNG |
| SWC-121 | Missing Protection against Signature Replay | Yes | ✅ | Equivalent: `nullifierHashes` + NullifierReplay tests |
| SWC-122 | Lack of Proper Signature Verification | Yes | ✅ | `verifier.verifyProof` + public binding; tampered tests |
| SWC-123 | Requirement Violation | Yes | ✅ | Custom errors + Phase 6 matrix |
| SWC-124 | Write to Arbitrary Storage Location | Partial | ✅ | Assembly only in PoseidonT3 / Groth16 pairing (memory) |
| SWC-125 | Incorrect Inheritance Order | Yes | ✅ | `IPrivacyPool, MerkleTreeWithHistory, ReentrancyGuard` |
| SWC-126 | Insufficient Gas Griefing | Partial | ⚠️ | Relayer pays gas; malicious recipient can revert — see risks |
| SWC-127 | Arbitrary Jump with Function Type Variable | No | N/A | No dynamic function types |
| SWC-128 | DoS With Block Gas Limit | Partial | ✅ | Insert O(levels); fixed levels (lab 4 / typical prod 20) |
| SWC-129 | Typographical Error | Yes | ✅ | Review + `forge test` |
| SWC-130 | Right-To-Left-Override control character | No | N/A | ASCII in NatSpec/tests |
| SWC-131 | Presence of unused variables | Yes | ✅ | No material dead variables |
| SWC-132 | Unexpected Ether balance | Partial | ✅ | Balance = unspent deposits; withdraw exactly denomination |
| SWC-133 | Hash Collisions With Multiple Variable Length Arguments | Partial | ✅ | Poseidon field hash; fixed `bytes32` commitments |
| SWC-134 | Message call with hardcoded gas amount | No | N/A | No `.call{gas: ...}` |
| SWC-135 | Code With No Effects | No | N/A | No relevant empty statements |
| SWC-136 | Unencrypted Private Data On-Chain | Partial | ⚠️ | Commitments/roots public by mixer design — see risks |

---

## Informational risks

### SWC-114 — `withdraw` front-running

**Description:** A mempool observer can see the proof and rebroadcast it with the same nullifier (or try to front-run). The first to confirm spends the nullifier; the second reverts with `NullifierAlreadySpent`.

**Status:** ⚠️ Inherent to on-chain mixers; partially mitigated by recipient/relayer/fee binding in the circuit (the payout cannot be changed without invalidating the proof).

**Mitigations:** Public binding; private relayer / optional Flashbots (out of v1).

### SWC-117 — Groth16 malleability

**Description:** Some forms of Groth16 proof malleability exist in the literature; the on-chain nullifier prevents double-spend even if the proof is rewritten.

**Status:** ⚠️ Informational; single spend depends on `nullifierHash`, not on proof uniqueness.

### SWC-126 — Relayer / recipient griefing

**Description:** If `recipient` (or `relayer` with fee > 0) rejects ETH, the whole tx reverts. A user choosing a hostile recipient contract cannot complete the withdraw.

**Status:** ⚠️ By design; the prover is responsible for choosing addresses.

### SWC-136 — Public anonymity set data

**Description:** Commitments, roots, and history are visible on-chain. Privacy depends on the set size and on not reusing nullifiers/secrets off-chain.

**Status:** ⚠️ Mixer design; lab depth = 4 (small set). Typical production uses depth 20.

### Trusted setup (ops)

**Description:** The lab ptau/zkey is an insecure local ceremony. A compromised VK allows forged proofs.

**Status:** ⚠️ Ops; use an audited public ptau + multi-party ceremony before mainnet.

### Wrong hasher / verifier at deploy

**Description:** If the deploy uses `MockHasher` or a verifier from another circuit, deposits/withdrawals will not match users' proofs.

**Status:** ⚠️ Ops; `Deploy.s.sol` (Phase 7) must wire Poseidon + Groth16 from the same circuit.

---

## SWC → tests mapping (Phase 6)

| SWC / threat | Test(s) |
|--------------|---------|
| Double-spend / SWC-121 | `NullifierReplay.t.sol` |
| Invalid root | `InvalidRoot.t.sol` |
| Proof / binding (SWC-122) | `PoolProofVerification.t.sol`, `ProofVerification.t.sol` |
| Relayer fee / SWC-104 | `RelayerFee.t.sol` |
| Reentrancy / SWC-107 | CEI + `TransientReentrancyGuard`; nullifier before ETH |
| Reject ETH / SWC-113 | `test_relayerRejectsEth_reverts`, `RejectETH` |
| Fee overflow | `test_feeExceedsDenomination_reverts` |

---

## References

- [SWC Registry](https://swcregistry.io/)
- [EIP-1470](https://eips.ethereum.org/EIPS/eip-1470)
- [Tornado Cash research / nullifiers](https://tornado.cash/) (educational reference)
- [`01-erc20/doc/SWC-AUDIT-EN.md`](../../01-erc20/doc/SWC-AUDIT-EN.md)
- [`circuits/README.md`](../circuits/README.md)

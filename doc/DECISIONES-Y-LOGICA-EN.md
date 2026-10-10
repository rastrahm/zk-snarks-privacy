# Technical decisions, logic, and gas — Module 17

A document aimed at **understanding** the v1 Privacy Pool: why each piece was chosen, how the protocol flows, and where gas can still be trimmed.

**Scope:** `PrivacyPool` + Poseidon Merkle + Circom circuit `Withdraw(4)` + Groth16 + SWC/gas Phase 7.  
**Status:** Phases 0–7 closed · 65 tests PASS.  
**See also:** [`GAS-EN.md`](./GAS-EN.md) · [`SWC-AUDIT-EN.md`](./SWC-AUDIT-EN.md) · [`flujograma-EN.md`](./flujograma-EN.md) · [`circuits/README.md`](../circuits/README.md).

---

## 1. System logic

### The idea in one sentence

A user **deposits ETH** together with an opaque *commitment* into a Merkle tree; later they **prove in zero-knowledge** that they know a valid leaf without revealing which one, and withdraw the fixed amount to a `recipient` (optionally paying a `fee` to a `relayer`).

### Cryptographic pieces

| Piece | Role |
|-------|------|
| `nullifier`, `secret` | User's off-chain secrets |
| `commitment = Poseidon(nullifier, secret)` | Merkle leaf (public on deposit) |
| `nullifierHash = Poseidon(nullifier)` | Published on withdraw; can be spent only **once** |
| Poseidon Merkle (depth `levels`) | Anonymity set: "I belong to some leaf of the root" |
| Groth16 proof | Proves commitment ∈ root and that public inputs (recipient/relayer/fee) are bound |

### Deposit → prove → withdraw cycle

```text
1. Off-chain
   nullifier, secret  →  commitment = Poseidon(nullifier, secret)

2. On-chain  deposit(commitment) + msg.value == denomination
   - commitments[commitment] = true   (anti leaf replay)
   - Merkle insert → new historical root (isKnownRoot)

3. Off-chain (whenever they want to withdraw)
   - Merkle path of the leaf
   - Circom witness + SnarkJS → proof (a,b,c) + pubSignals

4. On-chain  withdraw(a,b,c, root, nullifierHash, recipient, relayer, fee)
   - known root
   - unspent nullifier
   - fee ≤ denomination
   - verifier.verifyProof(...)  with public inputs in fixed order
   - mark nullifier  (CEI, before ETH)
   - payout: recipient = denomination - fee; relayer = fee (if fee > 0)
```

### Fixed order of public signals (binding)

Circuit and contract must match:

| Index | Signal | Why it is public |
|-------|--------|------------------|
| 0 | `root` | The pool only accepts roots it has seen |
| 1 | `nullifierHash` | Anti double-spend |
| 2 | `recipient` | The destination cannot change without invalidating the proof |
| 3 | `relayer` | Same for the fee collector |
| 4 | `fee` | Same for the fee amount |

Without that binding, a mempool attacker could rebroadcast the proof with a different `recipient`/`fee`. With binding, rebroadcasting can only **spend the same nullifier** to the same recipients (informational front-running, SWC-114).

### Check order in `withdraw` (defense in layers)

1. `isKnownRoot(root)` → `UnknownRoot`
2. `!nullifierHashes[nullifierHash]` → `NullifierAlreadySpent`
3. `fee <= denomination` (+ non-zero addresses)
4. `verifyProof` → `InvalidZKProof`
5. **Effects:** `nullifierHashes[...] = true`
6. **Interactions:** Yul ETH `call` to recipient (± relayer)
7. `Withdrawal` event

This is **CEI** + transient reentrancy guard: the nullifier is marked **before** sending ETH.

### Lab vs production (design logic)

| Lab (v1) | Typical production |
|----------|--------------------|
| Merkle depth **4** (16 leaves) | Depth **20** (~1M leaves) |
| Local power-12 ptau (insecure) | Real trusted setup / MPC |
| Fixed denomination (e.g. 0.1 ETH) | Same (pools per amount) or variants |
| Relayer fee in the proof | Same; off-chain relayer UX |

---

## 2. Technical decisions

### Stack and toolchain

| Decision | Choice | Reason |
|----------|--------|--------|
| Contract language | Fixed Solidity **0.8.24** | Native overflow checks; SWC-103 (no floating pragma) |
| Tests / deploy | Foundry | Gas snapshot, fuzz ≥ 1000, e2e with fixtures |
| Circuit | Circom 2 + SnarkJS | Industry standard for Groth16 |
| Proof system | **Groth16** (bn128) | Compact on-chain verifier; pairing via precompile `0x08` |
| On-chain / circuit hash | **Poseidon** (`PoseidonT3` + circomlib) | Circuit↔contract alignment; cheaper than keccak in a ZK tree |
| EVM | Cancun | Enables the guard's `tstore`/`tload` |

### On-chain architecture

| Decision | Choice | Reason |
|----------|--------|--------|
| Monolithic pool | `PrivacyPool` inherits Merkle + TransientGuard | One clear deposit/withdraw entrypoint |
| Fixed denomination | `immutable denomination` | Simplifies the circuit (no variable amount in the v1 proof) |
| Historical roots | Ring buffer + `isKnownRoot` | You can withdraw with an old root even after new deposits |
| Nullifiers | `mapping(bytes32 => bool)` | O(1) double-spend check; SWC-121 |
| Commitments | Anti-duplicate mapping | Prevents reinserting the same leaf |
| Verifier | `IVerifier` interface + exported `Groth16Verifier` | Tests with `MockVerifier`; prod with real pairing |
| Hasher | `IHasher` interface | Gas tests with `MockHasher`; prod Poseidon |
| Errors | `PrivacyErrors` custom errors | Gas + typing vs strings |
| Reentrancy | `TransientReentrancyGuard` | Cheaper than OZ (no persistent SSTORE) |
| ETH out | Assembly `call` without returndata | Less overhead than `.call{value}("")` |

### Circuit

| Decision | Choice | Reason |
|----------|--------|--------|
| Template | `Withdraw(levels)` | One circuit = one depth = one VK |
| Lab depth | **4** | Fast compile/prove; light fixtures |
| Recipient/relayer/fee binding | Circom constraints | Closes the "change the payout" vector |
| Trusted setup | Local lab ptau | Demos only; **never** production |

### Security / SWC (design criteria)

- **Mitigate on-chain** what is exploitable: nullifier replay, fake root, invalid proof, fee overflow, reentrancy, `call` return value.
- **Document as informational** what is inherent to the model: mempool front-running of the same proof, public anonymity set, recipient/relayer rejecting ETH, residual Groth16 malleability (single spend is guaranteed by the nullifier).
- Defensive tests (no offensive PoCs): `NullifierReplay`, `InvalidRoot`, `PoolProofVerification`, `RelayerFee`, `RejectETH`.

### Gas (Phase 7) — what was optimized and why

| Technique | Why |
|-----------|-----|
| Transient reentrancy | The flag doesn't need to survive the tx → `tstore` is enough |
| Fixed Merkle arrays | Cheaper access than mappings on insert |
| Indices packed into 1 slot | One SLOAD/SSTORE for `currentRootIndex` + `nextIndex` |
| Bit ops + `unchecked` in `_insert` | Index path without expensive DIV/MOD |
| `denomination` / hasher cached on the stack | Fewer immutable SLOADs in the hot path |
| Capacity before marking the commitment | Avoids orphan state / wasted gas |
| `optimizer_runs = 10_000` | Favors frequent calls |
| `via_ir = false` | PoseidonT3 + IR does not scale in compile time |

Indicative baseline (mock): deposit ~**133 255**; withdraw zero-fee ~**221 925**; Groth16 e2e ~**2.15 M** (pairing + Poseidon dominate). Details in [`GAS-EN.md`](./GAS-EN.md).

---

## 3. Can the existing gas be improved?

Yes, but the **useful ceiling** depends on whether we mean the pool "around" the proof or the hard cryptographic cost.

### Cost dominance (important)

On the real e2e path:

```text
e2e gas ≈ verifyProof (Groth16 ~215k+)  +  N × PoseidonT3 (~18k per hash)  +  SSTORE nullifier/root  +  ETH calls
```

At depth 4, Poseidon already weighs on deposit; at depth 20 it would be ~5× the hashes. **No pool micro-optimization removes the pairing.** The improvements below are either incremental or design changes.

### Feasible improvements without changing the ZK model

| Improvement | Expected impact | Tradeoff |
|-------------|-----------------|----------|
| Pack more Merkle state (roots ring) | Low–medium on deposit | Less clarity; careful with storage layout |
| Strict `calldata` / less `memory` in `pubSignals` | Low on withdraw | Requires a compatible verifier API |
| Skip the second `_sendEth` when `fee==0` (done) / batch unpaid | Already applied in spirit | — |
| Custom errors in the generated verifier | Low | Post-export patch |
| Fewer events / indexed data | Low | Worse off-chain indexing |
| `immutable` levels already used via inheritance | — | — |
| Compile with another version / different runs | Variable | Mandatory re-benchmark |

### Improvements that actually move the needle (design changes)

| Improvement | Impact | Engineering cost |
|-------------|--------|------------------|
| **Smaller depth** | Less on-chain Poseidon | Worse anonymity set (lab only) |
| **Plonk / others** with a different verifier | Depends | Redo circuit + VK + tests |
| **Recursion / aggregation** (batch withdraws) | Amortizes pairing | Out of v1 scope |
| **Hasher precompile / tighter audited library** | Medium on deposit | External dependency; `via_ir` |
| **Nullifier as `uint256` packing / bitmap** | Low–medium SSTORE | Only if the domain allows it |
| **ERC-4337 / paymaster** off-path | UX, not pool gas | Another layer |
| **Remove on-chain Poseidon** (verify path only in the circuit) | Much cheaper deposit | Leaf insert still needs a consistent on-chain hash **or** a different tree design |

Rule of thumb:

- If the goal is to **cheapen the mock hot path** (no pairing): transient + Merkle + Yul are already close to a reasonable floor.
- If the goal is to **cheapen real users**: the next jump is **proof system / depth / aggregation**, not more local `unchecked`.

### What you should *not* "optimize"

- Removing `isKnownRoot` or nullifiers → breaks security.
- Marking the nullifier **after** ETH → opens classic reentrancy.
- Blindly setting `via_ir = true` → compile time / PoseidonT3.
- Lab trusted setup on mainnet → cryptographic risk, not a gas one.

---

## 4. Quick mental map

```text
                    ┌──────────── off-chain ────────────┐
                    │  secret + nullifier               │
                    │  commitment / path / Groth16 proof│
                    └───────────────┬───────────────────┘
                                    │
         deposit                    │                 withdraw
    ┌──────────────┐                │            ┌──────────────────┐
    │ ETH + leaf   │                │            │ root + nullifier │
    │ Merkle update│                │            │ + proof + fee    │
    │ root history │                │            │ verify → pay ETH │
    └──────────────┘                │            └──────────────────┘
                                    │
                         anonymity set grows
                         (public commitments;
                          the deposit↔withdraw link
                          does not appear on-chain)
```

### Decisions that "close" the educational design

1. **Same Poseidon** in Circom and Solidity → circuit roots = pool roots.  
2. **Bound public inputs** → gasless relayer without changing the payout.  
3. **On-chain nullifier** → double-spend impossible even if the proof is rebroadcast.  
4. **Defensive SWC tests** → misuse must revert; no exploit PoC.  
5. **Documented gas** → measure what is optimizable (pool) and accept what is cryptographic (pairing).

---

## 5. References in the repo

| What | Where |
|------|-------|
| Pool | `src/PrivacyPool.sol` |
| Merkle | `src/libraries/MerkleTreeWithHistory.sol` |
| Guard | `src/libraries/TransientReentrancyGuard.sol` |
| Circuit | `circuits/withdraw.circom` |
| Proof fixtures | `test/fixtures/withdraw/` |
| Gas snapshot | `.gas-snapshot` · `test/gas/` |
| Portfolio web | `portfolio/index.html` |

Docs README: [`README-EN.md`](./README-EN.md).

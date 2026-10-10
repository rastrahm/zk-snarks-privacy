# Planning — Module 17: ZK-SNARKs & Privacy Protocols

**Status:** Phases **0–7** ✅ (module v1 closed).  
**Note:** The per-phase authorization rule applied during construction; v1 has no pending phases.

---

## 1. Goal

Build a **mixer / shielded pool privacy protocol** (educational Tornado Cash style) that allows:

- Depositing ETH with a **commitment** `Poseidon(nullifier, secret)` without revealing on-chain identity.
- Inserting commitments into an on-chain **Merkle tree** (Poseidon / MiMC) and keeping valid **historical roots**.
- Withdrawing with a **Groth16 proof** (Circom circuit + SnarkJS) that proves knowledge of the leaf without revealing the full path outside the proof.
- Preventing double-spend with `nullifierHashes` and `error NullifierAlreadySpent()`.
- Supporting **gasless withdrawals via relayer**: atomic split between `recipient` and the relayer fee in the proof execution.
- Verifying proofs on-chain with `Groth16Verifier` (Alt_BN128 pairing / precompile `0x08`).

Stack: **Foundry + Solidity `0.8.24`** + **Circom + SnarkJS**. Next.js frontend is **out of v1 scope**.

---

## 2. Scope

| Included (v1) | Excluded (v1) |
|---------------|---------------|
| `PrivacyPool` — deposit / withdraw / roots / nullifiers | Multi-asset ERC-20 pools |
| Poseidon Merkle **depth 4 (lab)** + `isKnownRoot` (function + ring buffer) | Production depth 20 / Sparse Merkle Tree |
| Circom circuit `Withdraw(4)` + recipient/relayer/fee binding | Plonk / Halo2 circuits |
| `Groth16Verifier` + `VerifierGate` / `InvalidZKProof` | Mainnet trusted setup (local lab ptau) |
| Relayer fee split in `withdraw` | Production off-chain relayer |
| On-chain `PoseidonHasher` (`PoseidonT3`) | MiMC (not used in v1) |
| Tests: proof, nullifier, root, fee, gas | Next.js frontend (App Router) |
| Circom/SnarkJS scripts + `Deploy.s.sol` | Compliance / sanctions screening |

---

## 3. Stack and technical constraints

### Suite (`evm-smart-contracts-suite` + `solidity.cursorrules`)

- **Exact** Solidity `0.8.24` (no floating pragma).
- OpenZeppelin Contracts v5.x in `lib/` (suite deps); the v1 pool uses its own **`TransientReentrancyGuard`** (Cancun), not the OZ guard.
- Foundry: unit + fuzz (`runs >= 1000`) + gas reports / snapshot.
- **Custom errors** (`PrivacyErrors`); `InvalidZKProof` wrapper (no `require` strings in the pool).
- Strict CEI; ETH via **Yul `call`** without returndata (never `transfer`/`send`).
- NatSpec on public/external API.
- Layout: Interfaces → Libraries → Contracts → State → Events → Errors → Modifiers → Functions.

### Module 17 (local `.cursorrules`)

- Primitives: **Poseidon** (`PoseidonT3` / circomlib).
- Verification: Groth16 over **Alt_BN128** (`ecPairing` `0x08`).
- `mapping(bytes32 => bool) public nullifierHashes` + `NullifierAlreadySpent()`.
- Historical roots: `roots[ROOT_HISTORY_SIZE]` + `isKnownRoot(root)` (not a boolean mapping).
- Gasless withdraw: atomic `recipient` + `relayer` fee payout bound to the proof.
- Verifier: `IVerifier.verifyProof` → `InvalidZKProof()` on failure.

### Circom / SnarkJS (v1)

- `circuits/withdraw.circom` → `Withdraw(4)`; build in `circuits/build/` (gitignored).
- Fixtures: `test/fixtures/withdraw/` (committable).
- Local lab ptau power-12 (`pot12_final_lab.ptau`); **do not** commit `.ptau` / `.zkey`.

### Next.js (`nextjs.cursorrules`) — post-v1

- Deposit/withdraw UI: App Router, Zod, Vitest + RTL, JSDoc, no `any`.
- Outside phases 0–7.

---

## 4. Architecture (v1 implemented)

```
17-zk-snarks-privacy/
├── README.md                    # bilingual index
├── README-ES.md / README-EN.md
├── doc/
│   ├── README.md                # bilingual index
│   ├── README-{ES,EN}.md
│   ├── planificacion-{ES,EN}.md
│   ├── diagrama-de-clases-{ES,EN}.md
│   ├── diagrama-de-flujo-{ES,EN}.md
│   ├── flujograma-{ES,EN}.md
│   ├── SWC-AUDIT-{ES,EN}.md
│   ├── GAS-{ES,EN}.md
│   └── DECISIONES-Y-LOGICA-{ES,EN}.md
├── circuits/
│   ├── README.md
│   ├── withdraw.circom          # Withdraw(4)
│   ├── merkleTree.circom        # DualMux + Poseidon
│   └── build/                   # gitignored
├── scripts/
│   ├── compile-circuit.mjs
│   ├── generate-proof.mjs
│   └── export-verifier.mjs
├── src/
│   ├── PrivacyPool.sol
│   ├── PoseidonHasher.sol
│   ├── verifiers/
│   │   ├── Groth16Verifier.sol  # snarkJS GPL-3.0, pragma 0.8.24
│   │   └── VerifierGate.sol
│   ├── interfaces/
│   │   ├── IPrivacyPool.sol
│   │   ├── IHasher.sol
│   │   └── IVerifier.sol
│   ├── libraries/
│   │   ├── PoseidonT3.sol
│   │   ├── MerkleTreeWithHistory.sol
│   │   └── TransientReentrancyGuard.sol
│   ├── errors/
│   │   └── PrivacyErrors.sol
│   └── mocks/
│       ├── MockVerifier.sol
│       ├── MockHasher.sol
│       └── RejectETH.sol
├── test/
│   ├── helpers/{MerkleTreeHarness,ProofFixture}.sol
│   ├── MerkleTree.t.sol
│   ├── PrivacyPool.t.sol
│   ├── PrivacyPoolWithdraw.t.sol
│   ├── NullifierReplay.t.sol
│   ├── InvalidRoot.t.sol
│   ├── PoolProofVerification.t.sol
│   ├── ProofVerification.t.sol
│   ├── RelayerFee.t.sol
│   ├── PrivacyErrors.t.sol
│   ├── gas/PrivacyPool.gas.t.sol
│   └── fixtures/withdraw/
├── script/
│   └── Deploy.s.sol
├── foundry.toml
├── remappings.txt
├── package.json
├── .gas-snapshot
├── .env.example
└── .gitignore
```

### Contracts and responsibilities

| Artifact | Responsibility |
|----------|----------------|
| `PrivacyPool` | Deposit / withdraw; nullifiers; CEI + transient reentrancy; Yul ETH |
| `MerkleTreeWithHistory` | Insert; fixed arrays; packed indices; `isKnownRoot` / ring of 30 |
| `PoseidonHasher` / `PoseidonT3` | 2-input hash aligned with circomlib |
| `IVerifier` / `Groth16Verifier` | Groth16 pairing (5 public inputs) |
| `VerifierGate` | `requireValidProof` → `InvalidZKProof` |
| `TransientReentrancyGuard` | EIP-1153 lock (Cancun) |
| `MockVerifier` / `MockHasher` / `RejectETH` | Tests |
| `PrivacyErrors` | 10 custom errors |

---

## 5. Custom errors (module)

```solidity
error NullifierAlreadySpent();   // mandatory (.cursorrules)
error InvalidZKProof();          // failed / tampered proof
error UnknownRoot();             // non-historical root
error InvalidCommitment();       // zero / already inserted if applicable
error TreeFull();                // Merkle capacity exhausted
error FeeExceedsDenomination();  // relayer fee > pool fixed amount
error EthTransferFailed();       // failed Yul ETH call
error ZeroAddress();
error InvalidDenomination();     // msg.value != denomination
error Unauthorized();            // reserved (future admin)
```

Module mandatory items: `NullifierAlreadySpent()`, historical root validation, ZK verification, atomic relayer payout.

### Denomination and depth (v1 lab)

| Parameter | v1 value |
|-----------|----------|
| `denomination` | `0.1 ether` (configurable at deploy) |
| Merkle / circuit | **levels = 4** (16 leaves) |
| `ROOT_HISTORY_SIZE` | 30 |
| Proof public inputs | `root, nullifierHash, recipient, relayer, fee` |

---

## 6. Phase governance (mandatory authorization)

| Rule | Detail |
|------|--------|
| **Gate** | No code for a phase is written until: *"I authorize Phase N"*. |
| **Delivery** | On close: acceptance checklist + touched files. |
| **Blocking** | New scope → document and wait for new authorization. |
| **TDD** | In contract phases: tests first, then implementation. |

### Phase board

| Phase | Name | Status | Authorization |
|-------|------|--------|---------------|
| 0 | Foundry + Node/Circom setup + structure | ✅ Completed | ✅ Authorized |
| 1 | Errors + Hasher + MerkleTreeWithHistory | ✅ Completed | ✅ Authorized |
| 2 | Circom `withdraw` circuit + compile/prove scripts | ✅ Completed | ✅ Authorized |
| 3 | `Groth16Verifier` + `IVerifier` + fixtures | ✅ Completed | ✅ Authorized |
| 4 | `PrivacyPool.deposit` + historical roots | ✅ Completed | ✅ Authorized |
| 5 | `PrivacyPool.withdraw` + nullifier + relayer split | ✅ Completed | ✅ Authorized |
| 6 | Security suite: replay / root / proof / fee | ✅ Completed | ✅ Authorized |
| 7 | Gas + Deploy + NatSpec / v1 close | ✅ Completed | ✅ Authorized |

---

## 7. Per-phase detail

### Phase 0 — Foundry setup + ZK toolchain ✅

**Goal:** compilable repo + documented Circom/SnarkJS toolchain.

1. Foundry scaffold (`foundry.toml`: solc `0.8.24`, optimizer, fuzz `runs >= 1000`).
2. Dependencies: `forge-std`, OpenZeppelin v5.
3. Folders `src/{verifiers,interfaces,libraries,errors,mocks}`, `test/{helpers,fuzz,gas}`, `circuits/`, `scripts/`, `script/`, `test/fixtures/`.
4. `package.json` with `snarkjs` / utilities; `.env.example`; stub + smoke test; `README.md`.

**Exit criterion:** `forge build` and `forge test` green; README with Circom prereqs.

**Done (2026-09-13):**
- `foundry.toml` (solc `0.8.24`, Cancun, optimizer `10_000`, `via_ir`, fuzz `runs = 1000`, RPC `mainnet` / `sepolia`, `fs_permissions` to fixtures).
- `remappings.txt`: `forge-std/`, `@openzeppelin/contracts/`.
- Dependencies in `lib/` (gitignored): `forge-std` **v1.16.2**, OpenZeppelin **v5.2.0** (copied from module 16).
- Folders `src/{verifiers,interfaces,libraries,errors,mocks}`, `test/{helpers,fuzz,gas,fixtures}`, `circuits/`, `scripts/`, `script/`.
- Stub `src/Placeholder.sol` + `test/Placeholder.t.sol` (ping + IERC20 remapping + fuzz).
- Stub `script/Deploy.s.sol` (Phase 7), Node stubs `scripts/{compile-circuit,generate-proof,export-verifier}.mjs`.
- `package.json` + `npm install` (`snarkjs`, `circomlib`); `.env.example`; `README.md` with Circom prereqs.
- `forge build` OK; `forge test` → **3 PASS** (fuzz 1000).

---

### Phase 1 — Errors + Hasher + Merkle tree ✅

**Goal:** on-chain commitment tree with root history.

1. TDD: insert leaf, root changes, `isKnownRoot` for previous roots.
2. `PoseidonT3` (or MiMC) via `IHasher`.
3. Capacity / `TreeFull`; zero leaf handling.
4. `PrivacyErrors.sol` with the errors from §5.

**Exit criterion:** Merkle tests + insert fuzz green.

**Done (2026-09-13):**
- `src/errors/PrivacyErrors.sol` — 10 custom errors (incl. `NullifierAlreadySpent`).
- `src/interfaces/IHasher.sol` — `hashLeftRight` + `hashPreimage`.
- `src/libraries/PoseidonT3.sol` — 2-input Poseidon (poseidon-solidity MIT, pragma `0.8.24`).
- `src/PoseidonHasher.sol` — IHasher wrapper for the Circom circuit.
- `src/mocks/MockHasher.sol` — keccak for fast tree tests.
- `src/libraries/MerkleTreeWithHistory.sol` — insert, `isKnownRoot`, `ROOT_HISTORY_SIZE=30`, `TreeFull` / `InvalidCommitment`.
- Tests: `PrivacyErrors.t.sol`, `MerkleTree.t.sol` (history, full, zero, fuzz 1000, Poseidon e2e levels=3).
- `Placeholder` stub removed.
- `foundry.toml`: `via_ir = false` (PoseidonT3 + via_ir does not compile in practical time).
- **`forge test` → 13 PASS**.

---

### Phase 2 — Circom circuit + proof scripts ✅

**Goal:** reproducible withdraw circuit.

1. `withdraw.circom`: Merkle path, nullifierHash, binding to recipient/relayer/fee (public signals aligned with the contract).
2. Scripts: compile → witness → prove (Groth16) → export calldata/fixtures.
3. Document lab ptau and commands; artifacts in `circuits/build/` ignored.

**Exit criterion:** lab proof generated; public signals documented.

**Done (2026-09-13):**
- Circom **2.1.9** installed (`cargo install` from iden3); `circomlibjs` in npm.
- `circuits/merkleTree.circom` — DualMux + Poseidon HashLeftRight + MerkleTreeChecker.
- `circuits/withdraw.circom` — `Withdraw(4)`: commitment, nullifierHash Poseidon(1), membership, recipient/relayer/fee binding.
- Compilation: **1428** constraints, **5** public inputs.
- Scripts: `compile-circuit.mjs`, `generate-proof.mjs` (local lab ptau power-12 if no `PTAU_PATH`).
- Fixtures: `test/fixtures/withdraw/{input,proof,public,verification_key}.json` — `snarkjs.verify = true`.
- Docs: `circuits/README.md` (public signal order).
- **`forge test` → 13 PASS** (no regression).

---

### Phase 3 — On-chain verifier + fixtures ✅

**Goal:** `Groth16Verifier` usable from Foundry.

1. Export / adapt `Groth16Verifier.sol` (`pragma 0.8.24`).
2. `IVerifier` wrapper + `MockVerifier` for unit tests.
3. Fixtures in `test/fixtures/` consumable by Solidity tests.

**Exit criterion:** valid pairing test + invalid proof → revert.

**Done (2026-09-13):**
- `scripts/export-verifier.mjs` — snarkjs export + pragma `0.8.24` patch + `is IVerifier`.
- `src/verifiers/Groth16Verifier.sol` (GPL-3.0 snarkJS) + `VerifierGate` (`InvalidZKProof`).
- `src/interfaces/IVerifier.sol` + `src/mocks/MockVerifier.sol`.
- Fixture `test/fixtures/withdraw/solidity_proof.json` (a/b/c/input hex, Ethereum order).
- Tests: `ProofVerification.t.sol` — valid, tampered input/proof → false / `InvalidZKProof`, mock gate.
- **`forge test` → 20 PASS**.

---

### Phase 4 — PrivacyPool.deposit ✅

**Goal:** fixed-denomination deposits and Merkle insertion.

1. Tests: `msg.value == denomination`; commitment inserted; `Deposit` event; historical root.
2. CEI + `ReentrancyGuard`.
3. Reject invalid commitment / full tree.

**Exit criterion:** deposit unit + denomination fuzz green.

**Done (2026-09-13):**
- `IPrivacyPool` + `PrivacyPool` (inherits `MerkleTreeWithHistory`, `ReentrancyGuard`).
- `deposit`: exact denomination, zero/duplicate commitment, `_insert`, `commitments`, `Deposit` event.
- `nullifierHashes` + `verifier` ready for Phase 5.
- Tests: `PrivacyPool.t.sol` — success, historical roots, TreeFull, denomination fuzz + unique leaves, Poseidon hasher.
- **`forge test` → 32 PASS**.

---

### Phase 5 — PrivacyPool.withdraw + relayer ✅

**Goal:** ZK withdrawal with anti double-spend and fee split.

1. CEI order: validate root → verify proof → mark nullifier → transfer ETH.
2. Split: `recipient` receives `denomination - fee`; `relayer` receives `fee` (fee may be 0).
3. Binding: public signals must match `withdraw` args.

**Exit criterion:** e2e withdraw with a real fixture or mock verifier + correct split.

**Done (2026-09-13):**
- `PrivacyPool.withdraw` — `UnknownRoot`, `NullifierAlreadySpent`, `InvalidZKProof`, fee/recipient checks.
- CEI: `nullifierHashes[hash]=true` before the ETH `.call`; recipient/relayer split.
- Mock tests: fee split, zero fee, replay, historical root, RejectETH.
- E2E: fixture commitment deposit + `Groth16Verifier` — on-chain root == circuit; withdraw + replay.
- **`forge test` → 43 PASS**.

---

### Phase 6 — Security matrix (module tests) ✅

| Type | What it validates |
|------|-------------------|
| Valid proof | Successful withdraw; correct balances |
| Nullifier replay | Second withdraw → `NullifierAlreadySpent` |
| Invalid / unknown root | → `UnknownRoot` |
| Tampered proof | → `InvalidZKProof` |
| Relayer fee | Exact recipient / relayer split |

**Exit criterion:** `NullifierReplay`, `InvalidRoot`, `ProofVerification`, `RelayerFee` green.

**Done (2026-09-13):**
- `test/NullifierReplay.t.sol` — replay + nullifier fuzz.
- `test/InvalidRoot.t.sol` — unknown/zero/stale root + fuzz.
- `test/PoolProofVerification.t.sol` — valid e2e, tampered proof/fee binding, mock false.
- `test/RelayerFee.t.sol` — exact split, max fee, RejectETH, fee fuzz.
- `doc/SWC-AUDIT.md` — SWC-100–136 matrix (`01-erc20` style), 0 vulnerable, 6 informational.
- **`forge test` → 61 PASS**.

---

### Phase 7 — Gas + Deploy + hardening ✅

**Goal:** profiling and v1 close.

1. Gas: deposit, withdraw, verifier; snapshot / `doc/GAS.md` (if creation is authorized).
2. `Deploy.s.sol` + full NatSpec.
3. Update diagrams / planning to "implemented".
4. Optional: update `doc/SWC-AUDIT.md` if the code changes.

**Exit criterion:** full suite green; module v1 ready to close.

**Done (2026-09-13):**
- Gas opts: transient reentrancy, fixed Merkle arrays, packed indices, Yul ETH call, bit ops, caches.
- `test/gas/PrivacyPool.gas.t.sol` + `.gas-snapshot` + `doc/GAS.md`.
- `script/Deploy.s.sol` — PoseidonHasher + Groth16Verifier + PrivacyPool.
- SWC-AUDIT updated (transient guard).
- **`forge test` → 65 PASS**.

---

## 8. Cryptographic model (v1)

### Commitment and nullifier

```text
commitment    = Poseidon(nullifier, secret)
nullifierHash = Poseidon(nullifier)          // public on withdraw; raw nullifier stays private
```

The Merkle tree leaf is the `commitment`. The proof shows:

1. Knowledge of `(nullifier, secret)` such that the leaf is in the tree with the public root.
2. Correct `nullifierHash`.
3. Binding to `recipient`, `relayer`, `fee` (anti front-running / payout malleability).

### Public signals (v1 — fixed order)

```text
publicInputs = [
  root,
  nullifierHash,
  recipient,      // address → uint160 → field
  relayer,
  fee
]
```

Exactly aligned: `withdraw.circom` ↔ `PrivacyPool.withdraw` ↔ fixtures.

### Denomination

**Fixed-amount** pool (`0.1 ether` default in lab/deploy). v1 Merkle/circuit depth = **4**.

---

## 9. Global acceptance criteria (v1)

- [x] Fixed pragma `0.8.24` in all contracts.
- [x] `nullifierHashes` + `NullifierAlreadySpent`.
- [x] `isKnownRoot` allows withdraw after new deposits.
- [x] On-chain Groth16 verification (or mock in unit + real in integration).
- [x] Atomic relayer fee split in withdraw.
- [x] Tests: proof OK, replay, invalid root, tampered proof, fee split.
- [x] NatSpec + custom errors + CEI / reentrancy (Cancun transient).
- [x] Circom/SnarkJS documented; secrets/ptau/zkey not committed.
- [x] Documentation (`doc/`) aligned with final code + GAS + SWC.

> **Module v1 closed.** Future extensions: depth 20, Plonk, multi-asset, Next.js frontend.

---

## 10. Post-v1 status

Module **v1 is closed** (phases 0–7). Extensions require new scope authorization.

Reference suite: `forge test` → **65 PASS**.

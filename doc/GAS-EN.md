# Gas optimization — ZK-SNARKs & Privacy Protocols

Regenerate:

```bash
export PATH="$HOME/.foundry/bin:$PATH"
forge test --match-contract PrivacyPoolGasTest --gas-report
forge snapshot --match-contract PrivacyPoolGasTest
```

**Baseline date:** 2026-09-13 (Phase 7)  
**Snapshot:** `.gas-snapshot` (`test/gas/PrivacyPool.gas.t.sol`)  
**Optimizer:** `optimizer_runs = 10_000`, `via_ir = false` (PoseidonT3), solc `0.8.24`, EVM Cancun

---

## Operation baseline (gas snapshot tests)

| Path | Gas (snapshot) | Notes |
|------|----------------|-------|
| `testGas_deposit` | **133 255** | MockHasher, levels=4 |
| `testGas_withdraw_zeroFee` | **221 925** | MockVerifier + 1 deposit |
| `testGas_withdraw_withRelayerFee` | **258 391** | Recipient/relayer split |
| `testGas_e2e_groth16_withdraw` | **2 149 226** | Poseidon + Groth16 + fixture |

### Gas report (on-chain function, mock)

| Function | Min | Median | Notes |
|----------|-----|--------|-------|
| `deposit` | ~142 937 | ~142 949 | No Poseidon |
| `withdraw` | ~94 442 | ~128 932 | MockVerifier (~2.6k) |
| `Groth16Verifier.verifyProof` | **215 514** | — | Dominant in e2e |
| `PoseidonT3.hash` | **18 229** | — | Per Merkle node |

> Real e2e cost is dominated by the **Groth16 pairing** + **Poseidon** per level; pool optimizations save SLOAD/SSTORE/call overhead.

---

## Applied optimizations (Phase 7)

| Technique | Where | Effect |
|-----------|-------|--------|
| Transient reentrancy (`tstore`/`tload`) | `TransientReentrancyGuard` | No OZ guard SSTORE |
| Fixed arrays `bytes32[32]` / `[30]` | MerkleTree | Cheaper than mappings |
| Packed indices (`uint256` slot) | `currentRootIndex` + `nextIndex` | 1 SLOAD/SSTORE vs 2 |
| Bit ops (`& 1`, `>>=`) + `unchecked` | `_insert` | Fewer DIV/MOD |
| Hasher cached on the stack | `_insert` / constructor | Fewer immutable SLOADs |
| Yul ETH `call` without returndata | `_sendEth` | Cheaper than `.call` |
| Capacity check before `commitments` | `deposit` | Avoids orphan SSTORE |
| Local `denomination` cache | deposit/withdraw | 1 immutable SLOAD |
| Custom errors | `PrivacyErrors` | vs `require` strings |
| `optimizer_runs = 10_000` | `foundry.toml` | Hot-path inlining |

### Tradeoffs

- **`via_ir = false`:** PoseidonT3 + IR does not compile in practical time; kept disabled.
- **Lab depth 4:** insert gas scales with `levels`; typical production depth 20 ⇒ ~5× Poseidon hashes per deposit.
- **Groth16:** not optimizable on-chain without changing the proof system.

### Indicative comparison (deposit tests, mock)

| Metric | Pre-Phase 7 (approx.) | Post-Phase 7 |
|--------|-----------------------|--------------|
| `test_deposit_success` (suite) | ~150 k | ~147 k |
| `testGas_deposit` | — | **133 255** |
| Reentrancy guard | OZ SSTORE | Cancun transient |

---

## Deploy

```bash
anvil   # another terminal
export PATH="$HOME/.foundry/bin:$PATH"
forge script script/Deploy.s.sol:Deploy --rpc-url http://127.0.0.1:8545 --broadcast
```

Env: `PRIVATE_KEY`, `DENOMINATION_WEI`, `MERKLE_TREE_LEVELS` (default 4). See `.env.example`.

**Important:** `MERKLE_TREE_LEVELS` must match the circuit's `Withdraw(N)` and the VK embedded in `Groth16Verifier`.

README: [`../README-EN.md`](../README-EN.md) · Docs index: [`README-EN.md`](./README-EN.md) · SWC: [`SWC-AUDIT-EN.md`](./SWC-AUDIT-EN.md) · Plan: [`planificacion-EN.md`](./planificacion-EN.md)

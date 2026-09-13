# Optimización de gas — ZK-SNARKs & Privacy Protocols

Regenerar:

```bash
export PATH="$HOME/.foundry/bin:$PATH"
forge test --match-contract PrivacyPoolGasTest --gas-report
forge snapshot --match-contract PrivacyPoolGasTest
```

**Fecha baseline:** 2026-09-13 (Fase 7)  
**Snapshot:** `.gas-snapshot` (`test/gas/PrivacyPool.gas.t.sol`)  
**Optimizer:** `optimizer_runs = 10_000`, `via_ir = false` (PoseidonT3), solc `0.8.24`, EVM Cancun

---

## Baseline operaciones (snapshot test gas)

| Path | Gas (snapshot) | Notas |
|------|----------------|-------|
| `testGas_deposit` | **133 255** | MockHasher, levels=4 |
| `testGas_withdraw_zeroFee` | **221 925** | MockVerifier + 1 deposit |
| `testGas_withdraw_withRelayerFee` | **258 391** | Split recipient/relayer |
| `testGas_e2e_groth16_withdraw` | **2 149 226** | Poseidon + Groth16 + fixture |

### Gas report (función on-chain, mock)

| Función | Min | Median | Notas |
|---------|-----|--------|-------|
| `deposit` | ~142 937 | ~142 949 | Sin Poseidon |
| `withdraw` | ~94 442 | ~128 932 | MockVerifier (~2.6k) |
| `Groth16Verifier.verifyProof` | **215 514** | — | Dominante en e2e |
| `PoseidonT3.hash` | **18 229** | — | Por nodo Merkle |

> El coste e2e real lo domina **pairing Groth16** + **Poseidon** por nivel; las opts de pool ahorran SLOAD/SSTORE/call overhead.

---

## Optimizaciones aplicadas (Fase 7)

| Técnica | Dónde | Efecto |
|---------|-------|--------|
| Transient reentrancy (`tstore`/`tload`) | `TransientReentrancyGuard` | Sin SSTORE del guard OZ |
| Arrays fijos `bytes32[32]` / `[30]` | MerkleTree | Más barato que mappings |
| Indices packed (`uint256` slot) | `currentRootIndex` + `nextIndex` | 1 SLOAD/SSTORE vs 2 |
| Bit ops (`& 1`, `>>=`) + `unchecked` | `_insert` | Menos DIV/MOD |
| Hasher cacheado en stack | `_insert` / constructor | Menos SLOAD immutable |
| ETH Yul `call` sin returndata | `_sendEth` | Más barato que `.call` |
| Capacidad check antes de `commitments` | `deposit` | Evita SSTORE huerfano |
| Cache `denomination` local | deposit/withdraw | 1 SLOAD immutable |
| Custom errors | `PrivacyErrors` | vs `require` strings |
| `optimizer_runs = 10_000` | `foundry.toml` | Inlining hot paths |

### Tradeoffs

- **`via_ir = false`:** PoseidonT3 + IR no compila en tiempo práctico; se mantiene desactivado.
- **Depth 4 lab:** gas de insert escala con `levels`; producción tipica depth 20 ⇒ ~5× hashes Poseidon en deposit.
- **Groth16:** no optimizable on-chain sin cambiar sistema de prueba.

### Comparativa orientativa (tests deposit, mock)

| Métrica | Pre-Fase 7 (aprox.) | Post-Fase 7 |
|---------|---------------------|-------------|
| `test_deposit_success` (suite) | ~150 k | ~147 k |
| `testGas_deposit` | — | **133 255** |
| Guard reentrancy | SSTORE OZ | transient Cancun |

---

## Deploy

```bash
anvil   # otra terminal
export PATH="$HOME/.foundry/bin:$PATH"
forge script script/Deploy.s.sol:Deploy --rpc-url http://127.0.0.1:8545 --broadcast
```

Env: `PRIVATE_KEY`, `DENOMINATION_WEI`, `MERKLE_TREE_LEVELS` (default 4). Ver `.env.example`.

**Importante:** `MERKLE_TREE_LEVELS` debe coincidir con `Withdraw(N)` del circuito y el VK embebido en `Groth16Verifier`.

README: [`../README.md`](../README.md) · Índice docs: [`README.md`](./README.md) · SWC: [`SWC-AUDIT.md`](./SWC-AUDIT.md) · Plan: [`planificacion.md`](./planificacion.md)

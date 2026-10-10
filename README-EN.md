# 17 — ZK-SNARKs & Privacy Protocols

Educational privacy pool (Poseidon Merkle commitments + nullifiers + Groth16 withdrawals) with relayer fee split. Solidity `0.8.24` + Foundry + Circom/SnarkJS.

**Status:** Phases **0–7** ✅ (module v1 closed).  
**Suite:** `forge test` → **65 PASS**.

## Docs

| File | Content |
|------|---------|
| [`doc/README-EN.md`](./doc/README-EN.md) | Documentation index |
| [`doc/planificacion-EN.md`](./doc/planificacion-EN.md) | Phases, architecture, criteria |
| [`doc/diagrama-de-clases-EN.md`](./doc/diagrama-de-clases-EN.md) | UML |
| [`doc/diagrama-de-flujo-EN.md`](./doc/diagrama-de-flujo-EN.md) | Deposit / prove / withdraw |
| [`doc/flujograma-EN.md`](./doc/flujograma-EN.md) | E2E cycle + relayer |
| [`doc/SWC-AUDIT-EN.md`](./doc/SWC-AUDIT-EN.md) | SWC-100–136 matrix |
| [`doc/GAS-EN.md`](./doc/GAS-EN.md) | Optimizations + snapshot |
| [`doc/DECISIONES-Y-LOGICA-EN.md`](./doc/DECISIONES-Y-LOGICA-EN.md) | Technical decisions, logic, and gas headroom |
| [`circuits/README.md`](./circuits/README.md) | `Withdraw(4)` circuit + signals |

## Stack

| Layer | Technology |
|-------|------------|
| Contracts | Solidity `0.8.24` (fixed pragma) |
| Tooling | Foundry (`forge` / `cast` / `anvil`) |
| Deps | forge-std, OpenZeppelin v5.2 in `lib/` |
| Guard | `TransientReentrancyGuard` (Cancun tstore) |
| Circuits | Circom 2.1.9 + SnarkJS Groth16 / bn128 |
| Hash | Poseidon (`PoseidonT3` / circomlib) |
| Lab | Merkle **levels = 4**, denomination `0.1 ether` |
| Security | Nullifiers, `isKnownRoot`, `InvalidZKProof`, fee split |

## Foundry setup

```bash
export PATH="$HOME/.foundry/bin:$PATH"

forge build
forge test
```

Dependencies (already in `lib/`; reinstall if needed):

```bash
forge install foundry-rs/forge-std@v1.16.2 --no-git --shallow
forge install OpenZeppelin/openzeppelin-contracts@v5.2.0 --no-git --shallow
```

## Circom / SnarkJS setup

1. **Node.js** >= 18  
2. **Circom** >= 2.1 (`cargo install --git https://github.com/iden3/circom.git --tag v2.1.9 circom`)  
3. `npm install`

```bash
export PATH="$HOME/.cargo/bin:$PATH"
npm run compile:circuit
npm run generate:proof      # lab ptau + fixtures
npm run export:verifier     # → src/verifiers/Groth16Verifier.sol
```

**Do not commit:** `*.ptau`, `*.zkey`, `circuits/build/` (see `.gitignore`).

## Local deploy

```bash
anvil   # another terminal
forge script script/Deploy.s.sol:Deploy --rpc-url http://127.0.0.1:8545 --broadcast
```

Env: `.env.example` (`PRIVATE_KEY`, `DENOMINATION_WEI`, `MERKLE_TREE_LEVELS` — must be **4** with the current VK).

## Gas

```bash
forge test --match-contract PrivacyPoolGasTest --gas-report
forge snapshot --match-contract PrivacyPoolGasTest
```

See [`doc/GAS-EN.md`](./doc/GAS-EN.md).

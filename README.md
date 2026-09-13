# 17 — ZK-SNARKs & Privacy Protocols

Privacy pool educativo (commitment Merkle + nullifiers + retiros Groth16) con relayer fee split. Solidity `0.8.24` + Foundry + Circom/SnarkJS.

**Estado:** Fases **0–2** ✅. Fases **3–7** pendientes (requieren autorización).

## Docs

| Archivo | Contenido |
|---------|-----------|
| [`doc/planificacion.md`](./doc/planificacion.md) | Fases, arquitectura, criterios |
| [`doc/diagrama-de-clases.md`](./doc/diagrama-de-clases.md) | UML |
| [`doc/diagrama-de-flujo.md`](./doc/diagrama-de-flujo.md) | Deposit / prove / withdraw |
| [`doc/flujograma.md`](./doc/flujograma.md) | Ciclo e2e + relayer |

## Stack

| Capa | Tecnología |
|------|------------|
| Contratos | Solidity `0.8.24` (pragma fijo) |
| Tooling | Foundry (`forge` / `cast` / `anvil`) |
| Librerías | OpenZeppelin Contracts v5.2, forge-std |
| Circuitos | Circom 2.x + SnarkJS (Groth16 / Alt_BN128) |
| Hash | Poseidon (preferido) / MiMC |
| Seguridad | `NullifierAlreadySpent`, `isKnownRoot`, verifier pairing |

## Setup Foundry

```bash
export PATH="$HOME/.foundry/bin:$PATH"

forge build
forge test
```

Dependencias (ya en `lib/`; reinstalar si hace falta):

```bash
forge install foundry-rs/forge-std@v1.16.2 --no-git --shallow
forge install OpenZeppelin/openzeppelin-contracts@v5.2.0 --no-git --shallow
```

## Setup Circom / SnarkJS (prereqs)

Necesario a partir de **Fase 2** (circuitos). En Fase 0 solo está el scaffold Node.

1. **Node.js** >= 18  
2. **Circom** >= 2.1 — [instalación oficial](https://docs.circom.io/getting-started/installation/)  
3. Dependencias npm del módulo:

```bash
npm install
```

Scripts (stubs hasta Fase 2–3):

```bash
npm run compile:circuit   # Fase 2
npm run generate:proof    # Fase 2
npm run export:verifier   # Fase 3
```

**No versionar:** `*.ptau`, `*.zkey`, `circuits/build/` (ver `.gitignore`).

## Deploy local (stub Fase 0)

```bash
anvil   # otra terminal
forge script script/Deploy.s.sol:Deploy --rpc-url http://127.0.0.1:8545 --broadcast
```

Env: ver `.env.example` (`PRIVATE_KEY`, `DENOMINATION_WEI`, `MERKLE_TREE_LEVELS`, RPCs).

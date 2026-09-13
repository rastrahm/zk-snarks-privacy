# Planificación — Módulo 17: ZK-SNARKs & Privacy Protocols

**Estado:** Fases **0–7** ✅ (módulo v1 cerrado).  
**Nota:** La regla de autorización por fase aplicó durante la construcción; v1 ya no tiene fases pendientes.

---

## 1. Objetivo

Construir un protocolo de **privacidad tipo mixer / shielded pool** (estilo Tornado Cash educativo) que permita:

- Depositar ETH con un **commitment** `Poseidon(nullifier, secret)` sin revelar la identidad on-chain.
- Insertar commitments en un **Merkle tree** on-chain (Poseidon / MiMC) y mantener **raíces históricas** válidas.
- Retirar con una **prueba Groth16** (circuito Circom + SnarkJS) que demuestre conocimiento del leaf sin revelar el path completo fuera del proof.
- Prevenir double-spend con `nullifierHashes` y `error NullifierAlreadySpent()`.
- Soportar **retiros gasless vía relayer**: split atómico entre `recipient` y fee del relayer en la ejecución del proof.
- Verificar pruebas on-chain con `Groth16Verifier` (pairing Alt_BN128 / precompile `0x08`).

Stack: **Foundry + Solidity `0.8.24`** + **Circom + SnarkJS**. Frontend Next.js queda **fuera de alcance v1**.

---

## 2. Alcance

| Incluido (v1) | Excluido (v1) |
|---------------|---------------|
| `PrivacyPool` — deposit / withdraw / roots / nullifiers | Multi-asset ERC-20 pools |
| Merkle Poseidon **depth 4 (lab)** + `isKnownRoot` (función + ring buffer) | Depth 20 producción / Sparse Merkle Tree |
| Circuito Circom `Withdraw(4)` + binding recipient/relayer/fee | Circuitos Plonk / Halo2 |
| `Groth16Verifier` + `VerifierGate` / `InvalidZKProof` | Trusted setup mainnet (ptau lab local) |
| Relayer fee split en `withdraw` | Relayer off-chain de producción |
| `PoseidonHasher` on-chain (`PoseidonT3`) | MiMC (no usado en v1) |
| Tests: proof, nullifier, root, fee, gas | Frontend Next.js (App Router) |
| Scripts Circom/SnarkJS + `Deploy.s.sol` | Compliance / sanctions screening |

---

## 3. Stack y restricciones técnicas

### Suite (`evm-smart-contracts-suite` + `solidity.cursorrules`)

- Solidity **exacto** `0.8.24` (sin floating pragma).
- OpenZeppelin Contracts v5.x en `lib/` (deps de suite); el pool v1 usa **`TransientReentrancyGuard`** propio (Cancun), no el guard OZ.
- Foundry: unit + fuzz (`runs >= 1000`) + gas reports / snapshot.
- **Custom errors** (`PrivacyErrors`); wrapper `InvalidZKProof` (no `require` strings en pool).
- CEI estricto; ETH vía **Yul `call`** sin returndata (nunca `transfer`/`send`).
- NatSpec en API pública/externa.
- Layout: Interfaces → Libraries → Contracts → State → Events → Errors → Modifiers → Functions.

### Módulo 17 (`.cursorrules` local)

- Primitivas: **Poseidon** (`PoseidonT3` / circomlib).
- Verificación: Groth16 sobre **Alt_BN128** (`ecPairing` `0x08`).
- `mapping(bytes32 => bool) public nullifierHashes` + `NullifierAlreadySpent()`.
- Raíces históricas: `roots[ROOT_HISTORY_SIZE]` + `isKnownRoot(root)` (no mapping booleano).
- Withdraw gasless: payout atómico `recipient` + `relayer` fee ligados al proof.
- Verifier: `IVerifier.verifyProof` → `InvalidZKProof()` si falla.

### Circom / SnarkJS (v1)

- `circuits/withdraw.circom` → `Withdraw(4)`; build en `circuits/build/` (gitignored).
- Fixtures: `test/fixtures/withdraw/` (versionables).
- Ptau lab local power-12 (`pot12_final_lab.ptau`); **no** versionar `.ptau` / `.zkey`.

### Next.js (`nextjs.cursorrules`) — post-v1

- UI deposit/withdraw: App Router, Zod, Vitest + RTL, JSDoc, sin `any`.
- Fuera de fases 0–7.

---

## 4. Arquitectura (v1 implementado)

```
17-zk-snarks-privacy/
├── README.md
├── doc/
│   ├── README.md
│   ├── planificacion.md
│   ├── diagrama-de-clases.md
│   ├── diagrama-de-flujo.md
│   ├── flujograma.md
│   ├── SWC-AUDIT.md
│   └── GAS.md
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

### Contratos y responsabilidades

| Artefacto | Responsabilidad |
|-----------|-----------------|
| `PrivacyPool` | Deposit / withdraw; nullifiers; CEI + transient reentrancy; ETH Yul |
| `MerkleTreeWithHistory` | Insert; arrays fijos; indices packed; `isKnownRoot` / ring 30 |
| `PoseidonHasher` / `PoseidonT3` | Hash 2-inputs alineado a circomlib |
| `IVerifier` / `Groth16Verifier` | Pairing Groth16 (5 públicos) |
| `VerifierGate` | `requireValidProof` → `InvalidZKProof` |
| `TransientReentrancyGuard` | Lock EIP-1153 (Cancun) |
| `MockVerifier` / `MockHasher` / `RejectETH` | Tests |
| `PrivacyErrors` | 10 custom errors |

---

## 5. Errores custom (módulo)

```solidity
error NullifierAlreadySpent();   // obligatorio (.cursorrules)
error InvalidZKProof();          // proof fallida / tampered
error UnknownRoot();             // raíz no histórica
error InvalidCommitment();       // zero / ya insertado si aplica
error TreeFull();                // capacidad Merkle agotada
error FeeExceedsDenomination();  // relayer fee > monto fijo del pool
error EthTransferFailed();       // Yul call ETH fallido
error ZeroAddress();
error InvalidDenomination();     // msg.value != denomination
error Unauthorized();            // reservado (admin futuro)
```

Obligatorios del módulo: `NullifierAlreadySpent()`, validación de root histórica, verificación ZK, payout relayer atómico.

### Denomination y profundidad (v1 lab)

| Parámetro | Valor v1 |
|-----------|----------|
| `denomination` | `0.1 ether` (configurable en deploy) |
| Merkle / circuito | **levels = 4** (16 hojas) |
| `ROOT_HISTORY_SIZE` | 30 |
| Públicos proof | `root, nullifierHash, recipient, relayer, fee` |

---

## 6. Gobernanza de fases (autorización obligatoria)

| Regla | Detalle |
|-------|---------|
| **Gate** | No se escribe código de una fase hasta: *“autorizo Fase N”*. |
| **Entrega** | Al cerrar: checklist de aceptación + archivos tocados. |
| **Bloqueo** | Alcance nuevo → documentar y esperar nueva autorización. |
| **TDD** | En fases de contratos: tests primero, luego implementación. |

### Tablero de fases

| Fase | Nombre | Estado | Autorización |
|------|--------|--------|--------------|
| 0 | Setup Foundry + Node/Circom + estructura | ✅ Completada | ✅ Autorizada |
| 1 | Errors + Hasher + MerkleTreeWithHistory | ✅ Completada | ✅ Autorizada |
| 2 | Circuito Circom `withdraw` + compile/prove scripts | ✅ Completada | ✅ Autorizada |
| 3 | `Groth16Verifier` + `IVerifier` + fixtures | ✅ Completada | ✅ Autorizada |
| 4 | `PrivacyPool.deposit` + raíces históricas | ✅ Completada | ✅ Autorizada |
| 5 | `PrivacyPool.withdraw` + nullifier + relayer split | ✅ Completada | ✅ Autorizada |
| 6 | Suite seguridad: replay / root / proof / fee | ✅ Completada | ✅ Autorizada |
| 7 | Gas + Deploy + NatSpec / cierre v1 | ✅ Completada | ✅ Autorizada |

---

## 7. Detalle por fase

### Fase 0 — Setup Foundry + toolchain ZK ✅

**Objetivo:** repo compilable + toolchain Circom/SnarkJS documentada.

1. Scaffold Foundry (`foundry.toml`: solc `0.8.24`, optimizer, fuzz `runs >= 1000`).
2. Dependencias: `forge-std`, OpenZeppelin v5.
3. Carpetas `src/{verifiers,interfaces,libraries,errors,mocks}`, `test/{helpers,fuzz,gas}`, `circuits/`, `scripts/`, `script/`, `test/fixtures/`.
4. `package.json` con `snarkjs` / utilidades; `.env.example`; stub + smoke test; `README.md`.

**Criterio de salida:** `forge build` y `forge test` en verde; README con prereqs Circom.

**Hecho (2026-09-13):**
- `foundry.toml` (solc `0.8.24`, Cancun, optimizer `10_000`, `via_ir`, fuzz `runs = 1000`, RPC `mainnet` / `sepolia`, `fs_permissions` a fixtures).
- `remappings.txt`: `forge-std/`, `@openzeppelin/contracts/`.
- Dependencias en `lib/` (gitignored): `forge-std` **v1.16.2**, OpenZeppelin **v5.2.0** (copiadas del módulo 16).
- Carpetas `src/{verifiers,interfaces,libraries,errors,mocks}`, `test/{helpers,fuzz,gas,fixtures}`, `circuits/`, `scripts/`, `script/`.
- Stub `src/Placeholder.sol` + `test/Placeholder.t.sol` (ping + remapping IERC20 + fuzz).
- Stub `script/Deploy.s.sol` (Fase 7), stubs Node `scripts/{compile-circuit,generate-proof,export-verifier}.mjs`.
- `package.json` + `npm install` (`snarkjs`, `circomlib`); `.env.example`; `README.md` con prereqs Circom.
- `forge build` OK; `forge test` → **3 PASS** (fuzz 1000).

---

### Fase 1 — Errors + Hasher + Merkle tree ✅

**Objetivo:** commitment tree on-chain con historial de roots.

1. TDD: insert leaf, root cambia, `isKnownRoot` para roots previos.
2. `PoseidonT3` (o MiMC) vía `IHasher`.
3. Capacidad / `TreeFull`; zero leaf handling.
4. `PrivacyErrors.sol` con errores del §5.

**Criterio de salida:** tests Merkle + fuzz de inserts en verde.

**Hecho (2026-09-13):**
- `src/errors/PrivacyErrors.sol` — 10 custom errors (incl. `NullifierAlreadySpent`).
- `src/interfaces/IHasher.sol` — `hashLeftRight` + `hashPreimage`.
- `src/libraries/PoseidonT3.sol` — Poseidon 2-inputs (poseidon-solidity MIT, pragma `0.8.24`).
- `src/PoseidonHasher.sol` — wrapper IHasher para circuito Circom.
- `src/mocks/MockHasher.sol` — keccak para tests rapidos del arbol.
- `src/libraries/MerkleTreeWithHistory.sol` — insert, `isKnownRoot`, `ROOT_HISTORY_SIZE=30`, `TreeFull` / `InvalidCommitment`.
- Tests: `PrivacyErrors.t.sol`, `MerkleTree.t.sol` (historial, full, zero, fuzz 1000, Poseidon e2e levels=3).
- Stub `Placeholder` eliminado.
- `foundry.toml`: `via_ir = false` (PoseidonT3 + via_ir no compila en tiempo practico).
- **`forge test` → 13 PASS**.

---

### Fase 2 — Circuito Circom + scripts de proof ✅

**Objetivo:** circuito de withdraw reproducible.

1. `withdraw.circom`: path Merkle, nullifierHash, binding a recipient/relayer/fee (señales públicas alineadas al contrato).
2. Scripts: compile → witness → prove (Groth16) → export calldata/fixtures.
3. Documentar ptau de lab y comandos; artefactos en `circuits/build/` ignorados.

**Criterio de salida:** proof de lab generada; señales públicas documentadas.

**Hecho (2026-09-13):**
- Circom **2.1.9** instalado (`cargo install` desde iden3); `circomlibjs` en npm.
- `circuits/merkleTree.circom` — DualMux + Poseidon HashLeftRight + MerkleTreeChecker.
- `circuits/withdraw.circom` — `Withdraw(4)`: commitment, nullifierHash Poseidon(1), membership, binding recipient/relayer/fee.
- Compilacion: **1428** constraints, **5** public inputs.
- Scripts: `compile-circuit.mjs`, `generate-proof.mjs` (ptau lab power-12 local si no hay `PTAU_PATH`).
- Fixtures: `test/fixtures/withdraw/{input,proof,public,verification_key}.json` — `snarkjs.verify = true`.
- Docs: `circuits/README.md` (orden de señales publicas).
- **`forge test` → 13 PASS** (sin regresion).

---

### Fase 3 — Verifier on-chain + fixtures ✅

**Objetivo:** `Groth16Verifier` integrable desde Foundry.

1. Export / adaptar `Groth16Verifier.sol` (`pragma 0.8.24`).
2. Wrapper `IVerifier` + `MockVerifier` para unit tests.
3. Fixtures en `test/fixtures/` consumibles por tests Solidity.

**Criterio de salida:** test de pairing válida + proof inválida → revert.

**Hecho (2026-09-13):**
- `scripts/export-verifier.mjs` — snarkjs export + patch pragma `0.8.24` + `is IVerifier`.
- `src/verifiers/Groth16Verifier.sol` (GPL-3.0 snarkJS) + `VerifierGate` (`InvalidZKProof`).
- `src/interfaces/IVerifier.sol` + `src/mocks/MockVerifier.sol`.
- Fixture `test/fixtures/withdraw/solidity_proof.json` (a/b/c/input hex, orden Ethereum).
- Tests: `ProofVerification.t.sol` — valid, tampered input/proof → false / `InvalidZKProof`, mock gate.
- **`forge test` → 20 PASS**.

---

### Fase 4 — PrivacyPool.deposit ✅

**Objetivo:** depósitos con denomination fija e inserción Merkle.

1. Tests: `msg.value == denomination`; commitment insertado; evento `Deposit`; root histórica.
2. CEI + `ReentrancyGuard`.
3. Rechazo commitment inválido / árbol lleno.

**Criterio de salida:** deposit unit + fuzz denomination en verde.

**Hecho (2026-09-13):**
- `IPrivacyPool` + `PrivacyPool` (hereda `MerkleTreeWithHistory`, `ReentrancyGuard`).
- `deposit`: denomination exacta, zero/duplicate commitment, `_insert`, `commitments`, evento `Deposit`.
- `nullifierHashes` + `verifier` listos para Fase 5.
- Tests: `PrivacyPool.t.sol` — success, roots historicas, TreeFull, fuzz denomination + unique leaves, Poseidon hasher.
- **`forge test` → 32 PASS**.

---

### Fase 5 — PrivacyPool.withdraw + relayer ✅

**Objetivo:** retiro ZK con anti-double-spend y fee split.

1. Orden CEI: validar root → verificar proof → marcar nullifier → transferir ETH.
2. Split: `recipient` recibe `denomination - fee`; `relayer` recibe `fee` (fee puede ser 0).
3. Binding: señales públicas deben coincidir con args de `withdraw`.

**Criterio de salida:** withdraw e2e con fixture real o mock verifier + split correcto.

**Hecho (2026-09-13):**
- `PrivacyPool.withdraw` — `UnknownRoot`, `NullifierAlreadySpent`, `InvalidZKProof`, fee/recipient checks.
- CEI: `nullifierHashes[hash]=true` antes de `.call` ETH; split recipient/relayer.
- Tests mock: fee split, zero fee, replay, root historica, RejectETH.
- E2E: deposit commitment fixture + `Groth16Verifier` — root on-chain == circuito; withdraw + replay.
- **`forge test` → 43 PASS**.

---

### Fase 6 — Matriz de seguridad (tests del módulo) ✅

| Tipo | Qué valida |
|------|------------|
| Proof válida | Withdraw exitoso; balances correctos |
| Nullifier replay | Segundo withdraw → `NullifierAlreadySpent` |
| Root inválida / desconocida | → `UnknownRoot` |
| Proof tampered | → `InvalidZKProof` |
| Relayer fee | Split exacto recipient / relayer |

**Criterio de salida:** `NullifierReplay`, `InvalidRoot`, `ProofVerification`, `RelayerFee` en verde.

**Hecho (2026-09-13):**
- `test/NullifierReplay.t.sol` — replay + fuzz nullifier.
- `test/InvalidRoot.t.sol` — unknown/zero/stale root + fuzz.
- `test/PoolProofVerification.t.sol` — e2e valida, tampered proof/fee binding, mock false.
- `test/RelayerFee.t.sol` — split exacto, max fee, RejectETH, fuzz fee.
- `doc/SWC-AUDIT.md` — matriz SWC-100–136 (estilo `01-erc20`), 0 vulnerables, 6 informativos.
- **`forge test` → 61 PASS**.

---

### Fase 7 — Gas + Deploy + hardening ✅

**Objetivo:** profiling y cierre v1.

1. Gas: deposit, withdraw, verifier; snapshot / `doc/GAS.md` (si se autoriza crear).
2. `Deploy.s.sol` + NatSpec completo.
3. Actualizar diagramas / planificación a “implementado”.
4. Opcional: actualizar `doc/SWC-AUDIT.md` si el código cambia.

**Criterio de salida:** suite completa en verde; módulo v1 listo para cierre.

**Hecho (2026-09-13):**
- Gas opts: transient reentrancy, arrays fijos Merkle, indices packed, Yul ETH call, bit ops, caches.
- `test/gas/PrivacyPool.gas.t.sol` + `.gas-snapshot` + `doc/GAS.md`.
- `script/Deploy.s.sol` — PoseidonHasher + Groth16Verifier + PrivacyPool.
- SWC-AUDIT actualizado (transient guard).
- **`forge test` → 65 PASS**.

---

## 8. Modelo criptográfico (v1)

### Commitment y nullifier

```text
commitment    = Poseidon(nullifier, secret)
nullifierHash = Poseidon(nullifier)          // público en withdraw; privado el nullifier crudo
```

El leaf del Merkle tree es el `commitment`. El proof demuestra:

1. Conocimiento de `(nullifier, secret)` tal que el leaf está en el árbol con root pública.
2. `nullifierHash` correcto.
3. Binding a `recipient`, `relayer`, `fee` (anti-front-running / malleability del payout).

### Señales públicas (v1 — orden fijo)

```text
publicInputs = [
  root,
  nullifierHash,
  recipient,      // address → uint160 → field
  relayer,
  fee
]
```

Alineado exactamente: `withdraw.circom` ↔ `PrivacyPool.withdraw` ↔ fixtures.

### Denomination

Pool de **monto fijo** (`0.1 ether` por defecto en lab/deploy). Depth Merkle/circuito v1 = **4**.

---

## 9. Criterios de aceptación globales (v1)

- [x] Pragma fijo `0.8.24` en todos los contratos.
- [x] `nullifierHashes` + `NullifierAlreadySpent`.
- [x] `isKnownRoot` permite withdraw tras nuevos deposits.
- [x] Verificación Groth16 on-chain (o mock en unit + real en integration).
- [x] Relayer fee split atómico en withdraw.
- [x] Tests: proof OK, replay, root inválida, proof tampered, fee split.
- [x] NatSpec + custom errors + CEI / reentrancy (transient Cancun).
- [x] Circom/SnarkJS documentados; secretos/ptau/zkey no versionados.
- [x] Documentación (`doc/`) alineada al código final + GAS + SWC.

> **Módulo v1 cerrado.** Extensiones futuras: depth 20, Plonk, multi-asset, frontend Next.js.

---

## 10. Estado post-v1

El módulo **v1 está cerrado** (fases 0–7). Extensiones requieren nueva autorización de alcance.

Suite de referencia: `forge test` → **65 PASS**.

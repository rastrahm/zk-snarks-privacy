# Planificación — Módulo 17: ZK-SNARKs & Privacy Protocols

**Estado:** Fases **0–3** ✅. Fases **4–7** ⏳ pendientes.  
**Regla de avance:** cada fase requiere **autorización explícita** del responsable antes de empezar (*“autorizo Fase N”* o equivalente).

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
| Merkle tree Poseidon (depth fijo, p. ej. 20) + `isKnownRoot` | Árboles dinámicos / Sparse Merkle Tree producción |
| Circuito Circom: membership + nullifier + recipient binding | Circuitos Plonk / Halo2 (solo mención; verifier Groth16) |
| `Groth16Verifier` generado + wrapper seguro | Trusted setup propia en mainnet (usar ptau público de lab) |
| Relayer fee split en `withdraw` | Relayer off-chain de producción / mempool privado |
| Hasher on-chain Poseidon (o MiMC si gas lo exige) | Anonymity set analytics / UI |
| Tests Foundry: proof válida, nullifier replay, root inválida, fee split | Frontend Next.js (App Router) |
| Scripts: compile circuit, gen proof fixtures, Deploy | Compliance / sanctions screening |

---

## 3. Stack y restricciones técnicas

### Suite (`evm-smart-contracts-suite` + `solidity.cursorrules`)

- Solidity **exacto** `0.8.24` (sin floating pragma).
- OpenZeppelin Contracts v5.x (`ReentrancyGuard`, `Ownable2Step` si hay admin).
- Foundry: unit + fuzz (`runs >= 1000`) + gas reports.
- **Custom errors** (no `require` con strings salvo el check documentado del verifier si el generador SnarkJS lo impone; envolver en wrapper con custom error cuando sea posible).
- CEI estricto; ETH vía `.call{value: ...}("")` (nunca `transfer`/`send`).
- NatSpec en toda API pública/externa.
- Layout: Interfaces → Libraries → Contracts → State → Events → Errors → Modifiers → Functions.
- TDD: tests primero en fases de contratos; cobertura de ramas de lógica explícita.

### Módulo 17 (`.cursorrules` local)

- Primitivas: **Poseidon** (preferido) / MiMC para leaves y nodos del Merkle tree.
- Verificación: Groth16 sobre **Alt_BN128** (`ecPairing` `0x08`).
- `mapping(bytes32 => bool) public nullifierHashes` + `NullifierAlreadySpent()`.
- `mapping(bytes32 => bool) public isKnownRoot` (raíces históricas; no solo `currentRoot`).
- Withdraw gasless: payout atómico `recipient` + `relayer` fee desde el proof payload / args públicos.
- `require(verifier.verifyProof(...), "Invalid ZK Proof")` o equivalente con custom error `InvalidZKProof()` en wrapper.

### Next.js (`nextjs.cursorrules`) — post-v1

- Si se añade UI deposit/withdraw: App Router, Zod, Vitest + RTL, JSDoc, sin `any`, sin prop drilling.
- No forma parte de las fases 0–7.

### Circom / SnarkJS

- Circuito versionado en `circuits/`; artefactos de build en `.gitignore`.
- Fixtures de proof para Foundry en `test/fixtures/` (permitidos en git).
- **No** versionar `.zkey` de producción ni `*.ptau` (toxic waste / ceremonia).

---

## 4. Arquitectura propuesta (v1)

```
17-zk-snarks-privacy/
├── README.md
├── doc/
│   ├── planificacion.md
│   ├── diagrama-de-clases.md
│   ├── diagrama-de-flujo.md
│   └── flujograma.md
├── circuits/
│   ├── withdraw.circom          # membership + nullifier + public signals
│   └── (build/ gitignored)
├── scripts/                     # Node: compile, prove, export verifier
│   ├── compile-circuit.mjs
│   ├── generate-proof.mjs
│   └── export-verifier.mjs
├── src/
│   ├── PrivacyPool.sol          # deposit + withdraw + roots + nullifiers
│   ├── verifiers/
│   │   └── Groth16Verifier.sol  # generado / adaptado
│   ├── interfaces/
│   │   ├── IPrivacyPool.sol
│   │   ├── IHasher.sol
│   │   └── IVerifier.sol
│   ├── libraries/
│   │   ├── PoseidonT3.sol       # o wrapper MiMC
│   │   ├── MerkleTreeWithHistory.sol
│   │   └── ProofLib.sol         # decode / pack public inputs
│   ├── errors/
│   │   └── PrivacyErrors.sol
│   └── mocks/
│       ├── MockVerifier.sol
│       └── MockHasher.sol
├── test/
│   ├── helpers/PrivacyTestBase.sol
│   ├── MerkleTree.t.sol
│   ├── PrivacyPool.t.sol
│   ├── NullifierReplay.t.sol
│   ├── InvalidRoot.t.sol
│   ├── RelayerFee.t.sol
│   ├── ProofVerification.t.sol
│   ├── fuzz/
│   └── gas/
├── script/
│   └── Deploy.s.sol
├── test/fixtures/               # proofs / public inputs de lab
├── foundry.toml
├── remappings.txt
├── package.json                 # snarkjs, circomlib (scripts)
├── .env.example
└── .gitignore
```

### Contratos y responsabilidades

| Artefacto | Responsabilidad |
|-----------|-----------------|
| `PrivacyPool` | Deposit ETH + commitment; withdraw con proof; CEI + reentrancy |
| `MerkleTreeWithHistory` | Insert leaf; `currentRoot`; `isKnownRoot`; profundidad fija |
| `IHasher` / Poseidon | Hash de 2 inputs para nodos y commitments |
| `IVerifier` / `Groth16Verifier` | `verifyProof(a,b,c, publicInputs)` |
| `ProofLib` | Empaquetar señales públicas (root, nullifierHash, recipient, relayer, fee) |
| `MockVerifier` | Tests unitarios sin pairing real |
| `PrivacyErrors` | Custom errors del módulo |

---

## 5. Errores custom (módulo)

```solidity
error NullifierAlreadySpent();   // obligatorio (.cursorrules)
error InvalidZKProof();          // proof fallida / tampered
error UnknownRoot();             // raíz no histórica
error InvalidCommitment();       // zero / ya insertado si aplica
error TreeFull();                // capacidad Merkle agotada
error FeeExceedsDenomination();  // relayer fee > monto fijo del pool
error EthTransferFailed();       // .call ETH fallido
error ZeroAddress();
error InvalidDenomination();     // msg.value != denomination
error Unauthorized();            // admin si aplica
```

Obligatorios del módulo: `NullifierAlreadySpent()`, validación de root histórica, verificación ZK, payout relayer atómico.

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
| 4 | `PrivacyPool.deposit` + raíces históricas | ⏳ Pendiente | ⏳ Esperando |
| 5 | `PrivacyPool.withdraw` + nullifier + relayer split | ⏳ Pendiente | ⏳ Esperando |
| 6 | Suite seguridad: replay / root / proof / fee | ⏳ Pendiente | ⏳ Esperando |
| 7 | Gas + Deploy + NatSpec / cierre v1 | ⏳ Pendiente | ⏳ Esperando |

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

### Fase 4 — PrivacyPool.deposit

**Objetivo:** depósitos con denomination fija e inserción Merkle.

1. Tests: `msg.value == denomination`; commitment insertado; evento `Deposit`; root histórica.
2. CEI + `ReentrancyGuard`.
3. Rechazo commitment inválido / árbol lleno.

**Criterio de salida:** deposit unit + fuzz denomination en verde.

---

### Fase 5 — PrivacyPool.withdraw + relayer

**Objetivo:** retiro ZK con anti-double-spend y fee split.

1. Orden CEI: validar root → verificar proof → marcar nullifier → transferir ETH.
2. Split: `recipient` recibe `denomination - fee`; `relayer` recibe `fee` (fee puede ser 0).
3. Binding: señales públicas deben coincidir con args de `withdraw`.

**Criterio de salida:** withdraw e2e con fixture real o mock verifier + split correcto.

---

### Fase 6 — Matriz de seguridad (tests del módulo)

| Tipo | Qué valida |
|------|------------|
| Proof válida | Withdraw exitoso; balances correctos |
| Nullifier replay | Segundo withdraw → `NullifierAlreadySpent` |
| Root inválida / desconocida | → `UnknownRoot` |
| Proof tampered | → `InvalidZKProof` |
| Relayer fee | Split exacto recipient / relayer |

**Criterio de salida:** `NullifierReplay`, `InvalidRoot`, `ProofVerification`, `RelayerFee` en verde.

---

### Fase 7 — Gas + Deploy + hardening

**Objetivo:** profiling y cierre v1.

1. Gas: deposit, withdraw, verifier; snapshot / `doc/GAS.md` (si se autoriza crear).
2. `Deploy.s.sol` + NatSpec completo.
3. Actualizar diagramas / planificación a “implementado”.
4. Opcional: `doc/SWC-AUDIT.md` alineado a módulos previos.

**Criterio de salida:** suite completa en verde; módulo v1 listo para cierre.

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

### Señales públicas (propuesta)

```text
publicInputs = [
  root,
  nullifierHash,
  recipient,      // como field element / packed
  relayer,
  fee
]
```

Alinear exactamente circuito ↔ `PrivacyPool.withdraw` en Fase 2–5.

### Denomination

Pool de **monto fijo** (p. ej. `0.1 ether`) para maximizar el anonymity set educativo (como Tornado denominaciones).

---

## 9. Criterios de aceptación globales (v1)

- [ ] Pragma fijo `0.8.24` en todos los contratos.
- [ ] `nullifierHashes` + `NullifierAlreadySpent`.
- [ ] `isKnownRoot` permite withdraw tras nuevos deposits.
- [ ] Verificación Groth16 on-chain (o mock en unit + real en integration).
- [ ] Relayer fee split atómico en withdraw.
- [ ] Tests: proof OK, replay, root inválida, proof tampered, fee split.
- [ ] NatSpec + custom errors + CEI / ReentrancyGuard.
- [ ] Circom/SnarkJS documentados; secretos/ptau/zkey no versionados.
- [ ] Documentación (`doc/`) alineada al código final.

> **Fases 0–3 cerradas.** No iniciar Fase 4 hasta autorización explícita.

---

## 10. Próximo paso

Responder con **“autorizo Fase 4”** para `PrivacyPool.deposit` + raíces históricas.

# Decisiones técnicas, lógica y gas — Módulo 17

Documento orientado a **entender** el Privacy Pool v1: por qué se eligió cada pieza, cómo fluye el protocolo y dónde aún se puede recortar gas.

**Alcance:** `PrivacyPool` + Merkle Poseidon + circuito Circom `Withdraw(4)` + Groth16 + SWC/gas Fase 7.  
**Estado:** Fases 0–7 cerradas · 65 tests PASS.  
**Complementos:** [`GAS-ES.md`](./GAS-ES.md) · [`SWC-AUDIT-ES.md`](./SWC-AUDIT-ES.md) · [`flujograma-ES.md`](./flujograma-ES.md) · [`circuits/README.md`](../circuits/README.md).

---

## 1. Lógica que sigue el sistema

### Idea en una frase

Un usuario **deposita ETH** junto a un *commitment* opaco en un árbol Merkle; más tarde **prueba en zero-knowledge** que conoce un leaf válido sin revelar cuál, y retira el monto fijo a un `recipient` (opcionalmente pagando `fee` a un `relayer`).

### Piezas criptográficas

| Pieza | Rol |
|-------|-----|
| `nullifier`, `secret` | Secretos off-chain del usuario |
| `commitment = Poseidon(nullifier, secret)` | Leaf del Merkle (público al depositar) |
| `nullifierHash = Poseidon(nullifier)` | Se publica al retirar; solo se puede gastar **una** vez |
| Merkle Poseidon (depth `levels`) | Anonymity set: “pertenezco a alguna hoja del root” |
| Proof Groth16 | Prueba que commitment ∈ root y que los públicos (recipient/relayer/fee) están ligados |

### Ciclo deposit → prove → withdraw

```text
1. Off-chain
   nullifier, secret  →  commitment = Poseidon(nullifier, secret)

2. On-chain  deposit(commitment) + msg.value == denomination
   - commitments[commitment] = true   (anti leaf replay)
   - insert en Merkle → nueva root histórica (isKnownRoot)

3. Off-chain (cuando quiera retirar)
   - path Merkle del leaf
   - witness Circom + SnarkJS → proof (a,b,c) + pubSignals

4. On-chain  withdraw(a,b,c, root, nullifierHash, recipient, relayer, fee)
   - root conocida
   - nullifier libre
   - fee ≤ denomination
   - verifier.verifyProof(...)  con públicos en orden fijo
   - marcar nullifier  (CEI, antes de ETH)
   - payout: recipient = denomination - fee; relayer = fee (si fee > 0)
```

### Orden fijo de señales públicas (binding)

El circuito y el contrato deben coincidir:

| Índice | Señal | Por qué es pública |
|--------|--------|-------------------|
| 0 | `root` | El pool solo acepta raíces ya vistas |
| 1 | `nullifierHash` | Anti double-spend |
| 2 | `recipient` | No se puede cambiar el destino sin invalidar la proof |
| 3 | `relayer` | Idem para el cobrador del fee |
| 4 | `fee` | Idem para el monto del fee |

Sin ese binding, un atacante en mempool podría reenviar la proof cambiando `recipient`/`fee`. Con binding, reenviar solo puede **gastar el mismo nullifier** hacia los mismos destinatarios (front-running informativo, SWC-114).

### Orden de checks en `withdraw` (defensa en capas)

1. `isKnownRoot(root)` → `UnknownRoot`
2. `!nullifierHashes[nullifierHash]` → `NullifierAlreadySpent`
3. `fee <= denomination` (+ addresses no cero)
4. `verifyProof` → `InvalidZKProof`
5. **Effects:** `nullifierHashes[...] = true`
6. **Interactions:** Yul `call` ETH a recipient (± relayer)
7. Evento `Withdrawal`

Esto es **CEI** + guard de reentrancy transient: el nullifier se marca **antes** de enviar ETH.

### Lab vs producción (lógica de diseño)

| Lab (v1) | Producción típica |
|----------|-------------------|
| Depth Merkle **4** (16 hojas) | Depth **20** (~1M hojas) |
| Ptau local power-12 (inseguro) | Trusted setup / MPC real |
| Denomination fija (ej. 0.1 ETH) | Igual (pools por monto) o variantes |
| Relayer fee en el proof | Igual; UX off-chain del relayer |

---

## 2. Decisiones técnicas

### Stack y toolchain

| Decisión | Elección | Motivo |
|----------|----------|--------|
| Lenguaje contratos | Solidity **0.8.24** fijo | Overflow checks nativos; SWC-103 (sin floating pragma) |
| Tests / deploy | Foundry | Snapshot gas, fuzz ≥ 1000, e2e con fixtures |
| Circuito | Circom 2 + SnarkJS | Estándar industria para Groth16 |
| Sistema de prueba | **Groth16** (bn128) | Verifier compacto on-chain; pairing en precompile `0x08` |
| Hash on-chain / circuito | **Poseidon** (`PoseidonT3` + circomlib) | Alineado circuito↔contrato; más barato que keccak en árbol ZK |
| EVM | Cancun | Habilita `tstore`/`tload` del guard |

### Arquitectura on-chain

| Decisión | Elección | Motivo |
|----------|----------|--------|
| Pool monolítico | `PrivacyPool` hereda Merkle + TransientGuard | Un entrypoint claro deposit/withdraw |
| Denomination fija | `immutable denomination` | Simplifica el circuito (no hay monto variable en la proof v1) |
| Raíces históricas | Ring buffer + `isKnownRoot` | Puedes retirar con un root viejo aunque haya nuevos deposits |
| Nullifiers | `mapping(bytes32 => bool)` | Double-spend O(1); SWC-121 |
| Commitments | mapping anti-duplicado | Evita reinsertar el mismo leaf |
| Verifier | Interface `IVerifier` + `Groth16Verifier` exportado | Tests con `MockVerifier`; prod con pairing real |
| Hasher | Interface `IHasher` | Tests gas con `MockHasher`; prod Poseidon |
| Errores | Custom errors `PrivacyErrors` | Gas + tipado vs strings |
| Reentrancy | `TransientReentrancyGuard` | Más barato que OZ (sin SSTORE persistente) |
| ETH out | Assembly `call` sin returndata | Menos overhead que `.call{value}("")` |

### Circuito

| Decisión | Elección | Motivo |
|----------|----------|--------|
| Template | `Withdraw(levels)` | Un circuito = un depth = un VK |
| Depth lab | **4** | Compila/prueba rápido; fixtures livianos |
| Binding recipient/relayer/fee | Restricciones en Circom | Cierra el vector de “cambiar payout” |
| Trusted setup | Ptau lab local | Solo demos; **nunca** producción |

### Seguridad / SWC (criterio de diseño)

- **Mitigar on-chain** lo explotable: replay nullifier, root falsa, proof inválida, fee overflow, reentrancy, return de `call`.
- **Documentar como informativo** lo que es inherentemente del modelo: mempool front-run del mismo proof, set de anonimato público, recipient/relayer que rechazan ETH, malleability residual de Groth16 (el gasto único lo da el nullifier).
- Tests defensivos (no PoCs ofensivos): `NullifierReplay`, `InvalidRoot`, `PoolProofVerification`, `RelayerFee`, `RejectETH`.

### Gas (Fase 7) — qué se optimizó y por qué

| Técnica | Por qué |
|---------|---------|
| Transient reentrancy | El flag no necesita sobrevivir la tx → `tstore` basta |
| Arrays fijos Merkle | Acceso más barato que mappings en insert |
| Índices packed en 1 slot | Un SLOAD/SSTORE para `currentRootIndex` + `nextIndex` |
| Bit ops + `unchecked` en `_insert` | Path índice sin DIV/MOD caros |
| Cache `denomination` / hasher en stack | Menos SLOAD de immutables en hot path |
| Capacidad antes de marcar commitment | Evita estados huérfanos / gas desperdiciado |
| `optimizer_runs = 10_000` | Favorece calls frecuentes |
| `via_ir = false` | PoseidonT3 + IR no escala en tiempo de compile |

Baseline orientativo (mock): deposit ~**133 255**; withdraw zero-fee ~**221 925**; e2e Groth16 ~**2.15 M** (domina pairing + Poseidon). Detalle en [`GAS-ES.md`](./GAS-ES.md).

---

## 3. ¿Se puede mejorar el gas de lo que existe?

Sí, pero el **techo útil** depende de si hablamos del pool “alrededor” de la proof o del coste criptográfico duro.

### Dominancia de coste (importante)

En el path e2e real:

```text
Gas e2e ≈ verifyProof (Groth16 ~215k+)  +  N × PoseidonT3 (~18k por hash)  +  SSTORE nullifier/root  +  calls ETH
```

Con depth 4, Poseidon en deposit ya pesa; con depth 20 sería ~5× hashes. **Ninguna micro-opt del pool elimina el pairing.** Las mejoras siguientes son incrementales o de cambio de diseño.

### Mejoras factibles sin cambiar el modelo ZK

| Mejora | Impacto esperado | Tradeoff |
|--------|------------------|----------|
| Empaquetar más estado Merkle (roots ring) | Bajo–medio en deposit | Menos claridad; cuidado con layout storage |
| `calldata` estricto / menos `memory` en `pubSignals` | Bajo en withdraw | Requiere API verifier compatible |
| Evitar segundo `_sendEth` si `fee==0` (ya) / batch unpaid | Ya aplicado en espíritu | — |
| Custom errors en verifier generado | Bajo | Parche post-export |
| Reducir eventos / datos indexados | Bajo | Peor indexación off-chain |
| `immutable` levels ya usado vía herencia | — | — |
| Compilar con otra versión / runs distintos | Variable | Re-benchmark obligatorio |

### Mejoras que sí mueven la aguja (cambio de diseño)

| Mejora | Impacto | Coste de ingeniería |
|--------|---------|---------------------|
| **Depth menor** | Menos Poseidon on-chain | Anonymity set peor (solo lab) |
| **Plonk / otros** con verifier distinto | Depende | Rehacer circuito + VK + tests |
| **Recursive / aggregation** (batch withdraws) | Amortiza pairing | Fuera de alcance v1 |
| **Hasher precompile / librería auditada más tight** | Medio en deposit | Dependencia externa; `via_ir` |
| **Nullifier como `uint256` packing / bitmap** | Bajo–medio SSTORE | Solo si el dominio lo permite |
| **ERC-4337 / paymaster** off-path | UX, no gas del pool | Otra capa |
| **Sacar Poseidon on-chain** (solo verificar path en circuito) | Deposit mucho más barato | El leaf insert sigue necesitando hash coherente on-chain **o** otro diseño de tree |

Regla práctica:

- Si el objetivo es **barajar el hot path mock** (sin pairing): transient + Merkle + Yul ya están cerca del suelo razonable.
- Si el objetivo es **barajar usuarios reales**: el siguiente salto es **sistema de prueba / depth / agregación**, no más `unchecked` locales.

### Lo que *no* conviene “optimizar”

- Quitar `isKnownRoot` o nullifiers → rompe seguridad.
- Marcar nullifier **después** de ETH → abre reentrancy clásica.
- `via_ir = true` a ciegas → compile time / PoseidonT3.
- Trusted setup lab en mainnet → riesgo criptográfico, no de gas.

---

## 4. Mapa mental rápido

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
                         anonymity set crece
                         (commitments públicos;
                          link deposit↔withdraw
                          no aparece on-chain)
```

### Decisiones que “cierran” el diseño educativo

1. **Misma Poseidon** en Circom y en Solidity → roots del circuito = roots del pool.  
2. **Públicos ligados** → relayer gasless sin cambiar el payout.  
3. **Nullifier on-chain** → double-spend imposible aunque la proof se reenvíe.  
4. **Tests SWC defensivos** → el misuse debe revertir; no hay PoC de exploit.  
5. **Gas documentado** → se mide lo optimizable (pool) y se acepta lo criptográfico (pairing).

---

## 5. Referencias en el repo

| Qué | Dónde |
|-----|--------|
| Pool | `src/PrivacyPool.sol` |
| Merkle | `src/libraries/MerkleTreeWithHistory.sol` |
| Guard | `src/libraries/TransientReentrancyGuard.sol` |
| Circuito | `circuits/withdraw.circom` |
| Fixtures proof | `test/fixtures/withdraw/` |
| Gas snapshot | `.gas-snapshot` · `test/gas/` |
| Portfolio web | `portfolio/index.html` |

README docs: [`README-ES.md`](./README-ES.md).

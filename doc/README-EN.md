# Documentation — Module 17: ZK-SNARKs & Privacy Protocols

Design, security, gas, and circuit index for the Privacy Pool (Poseidon Merkle commitments + Groth16 + relayer fee).

| File | Content | Status |
|------|---------|--------|
| [planificacion-EN.md](./planificacion-EN.md) | Phases 0–7, implemented architecture, criteria | ✅ Closed |
| [diagrama-de-clases-EN.md](./diagrama-de-clases-EN.md) | UML: pool, Merkle, hasher, verifier, circuit | ✅ Updated |
| [diagrama-de-flujo-EN.md](./diagrama-de-flujo-EN.md) | Decisions: deposit → prove → withdraw | ✅ Updated |
| [flujograma-EN.md](./flujograma-EN.md) | E2E deposit/prove/withdraw + relayer + defenses | ✅ Updated |
| [SWC-AUDIT-EN.md](./SWC-AUDIT-EN.md) | SWC-100–136 matrix (0 vulnerable) | ✅ |
| [GAS-EN.md](./GAS-EN.md) | Transient/Yul/Merkle opts + snapshot | ✅ |
| [DECISIONES-Y-LOGICA-EN.md](./DECISIONES-Y-LOGICA-EN.md) | Technical decisions, protocol logic, and gas headroom | ✅ |
| [../circuits/README.md](../circuits/README.md) | `Withdraw(4)` circuit + public signals | ✅ |

**Module status:** Phases **0–7** ✅ (v1 closed).  
**Verified suite:** `forge test` → **65 PASS**.  
**Docs sync:** 2026-09-13 (aligned to `src/` / `circuits/` after Phase 7).

Module README: [`../README-EN.md`](../README-EN.md).

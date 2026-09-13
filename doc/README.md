# Documentación — Módulo 17: ZK-SNARKs & Privacy Protocols

Índice de diseño, seguridad, gas y circuitos del Privacy Pool (commitment Merkle Poseidon + Groth16 + relayer fee).

| Archivo | Contenido | Estado |
|---------|-----------|--------|
| [planificacion.md](./planificacion.md) | Fases 0–7, arquitectura implementada, criterios | ✅ Cerrado |
| [diagrama-de-clases.md](./diagrama-de-clases.md) | UML: pool, Merkle, hasher, verifier, circuito | ✅ Actualizado |
| [diagrama-de-flujo.md](./diagrama-de-flujo.md) | Decisiones: deposit → prove → withdraw | ✅ Actualizado |
| [flujograma.md](./flujograma.md) | E2E deposit/prove/withdraw + relayer + defensas | ✅ Actualizado |
| [SWC-AUDIT.md](./SWC-AUDIT.md) | Matriz SWC-100–136 (0 vulnerables) | ✅ |
| [GAS.md](./GAS.md) | Opts transient/Yul/Merkle + snapshot | ✅ |
| [../circuits/README.md](../circuits/README.md) | Circuito `Withdraw(4)` + señales públicas | ✅ |

**Estado del módulo:** Fases **0–7** ✅ (v1 cerrado).  
**Suite verificada:** `forge test` → **65 PASS**.  
**Sync docs:** 2026-09-13 (alineado a `src/` / `circuits/` post Fase 7).

README del módulo: [`../README.md`](../README.md).

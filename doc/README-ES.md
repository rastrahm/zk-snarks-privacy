# Documentación — Módulo 17: ZK-SNARKs & Privacy Protocols

Índice de diseño, seguridad, gas y circuitos del Privacy Pool (commitment Merkle Poseidon + Groth16 + relayer fee).

| Archivo | Contenido | Estado |
|---------|-----------|--------|
| [planificacion-ES.md](./planificacion-ES.md) | Fases 0–7, arquitectura implementada, criterios | ✅ Cerrado |
| [diagrama-de-clases-ES.md](./diagrama-de-clases-ES.md) | UML: pool, Merkle, hasher, verifier, circuito | ✅ Actualizado |
| [diagrama-de-flujo-ES.md](./diagrama-de-flujo-ES.md) | Decisiones: deposit → prove → withdraw | ✅ Actualizado |
| [flujograma-ES.md](./flujograma-ES.md) | E2E deposit/prove/withdraw + relayer + defensas | ✅ Actualizado |
| [SWC-AUDIT-ES.md](./SWC-AUDIT-ES.md) | Matriz SWC-100–136 (0 vulnerables) | ✅ |
| [GAS-ES.md](./GAS-ES.md) | Opts transient/Yul/Merkle + snapshot | ✅ |
| [DECISIONES-Y-LOGICA-ES.md](./DECISIONES-Y-LOGICA-ES.md) | Decisiones técnicas, lógica del protocolo y margen de gas | ✅ |
| [../circuits/README.md](../circuits/README.md) | Circuito `Withdraw(4)` + señales públicas | ✅ |

**Estado del módulo:** Fases **0–7** ✅ (v1 cerrado).  
**Suite verificada:** `forge test` → **65 PASS**.  
**Sync docs:** 2026-09-13 (alineado a `src/` / `circuits/` post Fase 7).

README del módulo: [`../README-ES.md`](../README-ES.md).

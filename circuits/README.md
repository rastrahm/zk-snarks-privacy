# Circuitos Circom — Privacy Pool (modulo 17)

## withdraw.circom

| Item | Valor |
|------|-------|
| Template | `Withdraw(4)` — depth lab = 4 (16 hojas) |
| Hash | Poseidon (circomlib) |
| Proof system | Groth16 / bn128 |

### Senales publicas (orden fijo)

| # | Nombre | Uso on-chain |
|---|--------|--------------|
| 0 | `root` | Debe pasar `isKnownRoot` |
| 1 | `nullifierHash` | Anti double-spend |
| 2 | `recipient` | Address (field) del payout |
| 3 | `relayer` | Address del relayer |
| 4 | `fee` | Fee en wei |

### Privadas

`nullifier`, `secret`, `pathElements[4]`, `pathIndices[4]`

### Relaciones

```text
commitment    = Poseidon(nullifier, secret)
nullifierHash = Poseidon(nullifier)          // Poseidon(1)
MerklePoseidon(commitment, path) == root
```

Recipient / relayer / fee se enlazan al proof via restricciones cuadraticas (binding).

## Comandos

```bash
export PATH="$HOME/.cargo/bin:$PATH"

npm run compile:circuit   # → circuits/build/
npm run generate:proof    # ptau + zkey + proof + test/fixtures/withdraw/
```

### Ptau (lab)

Por defecto se genera un **ptau local inseguro** (`pot12_final_lab.ptau`, power 12) en `circuits/build/` si no existe. Solo laboratorio.

```bash
PTAU_PATH=/ruta/a/tu.ptau npm run generate:proof
```

**Nunca** versionar `.ptau` ni `.zkey` de produccion.

### Cambiar profundidad

1. Editar `component main ... = Withdraw(N);` en `withdraw.circom`
2. `LEVELS=N npm run generate:proof`
3. Alinear `MerkleTreeWithHistory` / pool al mismo `N`

## Artefactos

| Ruta | Git |
|------|-----|
| `circuits/build/` | ignorado |
| `test/fixtures/withdraw/` | versionable (fixtures Foundry) |

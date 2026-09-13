/**
 * Setup Groth16 (ptau lab) + genera proof + fixtures Foundry.
 * Uso: `npm run generate:proof`
 *
 * Artefactos en circuits/build/ (gitignored).
 * Fixtures en test/fixtures/withdraw/ (versionables).
 *
 * Env:
 *   PTAU_PATH — ruta a powersOfTau (default: genera pot12 lab local si falta)
 *   LEVELS    — debe coincidir con Withdraw(N) en withdraw.circom (default 4)
 */
import { spawnSync } from "node:child_process";
import {
  existsSync,
  mkdirSync,
  writeFileSync,
  copyFileSync,
} from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { buildPoseidon } from "circomlibjs";
import * as snarkjs from "snarkjs";

const __dirname = dirname(fileURLToPath(import.meta.url));
const root = join(__dirname, "..");
const buildDir = join(root, "circuits", "build");
const fixturesDir = join(root, "test", "fixtures", "withdraw");
const LEVELS = Number(process.env.LEVELS || 4);

const r1cs = join(buildDir, "withdraw.r1cs");
const wasm = join(buildDir, "withdraw_js", "withdraw.wasm");
const zkey = join(buildDir, "withdraw_final.zkey");
const vkeyPath = join(buildDir, "verification_key.json");

mkdirSync(buildDir, { recursive: true });
mkdirSync(fixturesDir, { recursive: true });

function run(cmd, args) {
  const r = spawnSync(cmd, args, { encoding: "utf8", cwd: root });
  if (r.stdout) process.stdout.write(r.stdout);
  if (r.stderr) process.stderr.write(r.stderr);
  if (r.status !== 0) {
    throw new Error(`${cmd} ${args.join(" ")} failed (${r.status})`);
  }
}

async function ensurePtau() {
  const defaultPtau = join(buildDir, "pot12_final_lab.ptau");
  const ptau = process.env.PTAU_PATH || defaultPtau;
  if (existsSync(ptau)) {
    console.log("[ptau] using", ptau);
    return ptau;
  }

  // Ceremony insegura de lab (NO produccion). Power 12 (>= constraints del circuito).
  console.log("[ptau] generating local lab ptau (power 12) via snarkjs CLI");
  const snarkjsBin = join(root, "node_modules", ".bin", "snarkjs");
  const p0 = join(buildDir, "pot12_0000.ptau");
  const p1 = join(buildDir, "pot12_0001.ptau");
  run(snarkjsBin, ["powersoftau", "new", "bn128", "12", p0, "-v"]);
  run(snarkjsBin, [
    "powersoftau",
    "contribute",
    p0,
    p1,
    "--name=lab",
    "-v",
    "-e=lab-entropy-" + Date.now(),
  ]);
  run(snarkjsBin, ["powersoftau", "prepare", "phase2", p1, ptau, "-v"]);
  console.log("[ptau] saved", ptau);
  return ptau;
}

function toHex(f) {
  return "0x" + BigInt(f).toString(16).padStart(64, "0");
}

function poseidonHash(poseidon, inputs) {
  const F = poseidon.F;
  return F.toObject(poseidon(inputs.map((x) => F.e(x))));
}

/** Arbol Merkle Poseidon alineado a MerkleTreeWithHistory on-chain. */
function buildMerkleTree(poseidon, leaves, levels) {
  const capacity = 1 << levels;
  if (leaves.length > capacity) throw new Error("too many leaves");

  const zeros = [];
  let z = 0n;
  zeros.push(z);
  for (let i = 1; i <= levels; i++) {
    z = poseidonHash(poseidon, [z, z]);
    zeros.push(z);
  }

  const layers = [];
  const layer0 = Array(capacity).fill(zeros[0]);
  for (let i = 0; i < leaves.length; i++) layer0[i] = leaves[i];
  layers.push(layer0);

  for (let lvl = 0; lvl < levels; lvl++) {
    const prev = layers[lvl];
    const next = [];
    for (let i = 0; i < prev.length; i += 2) {
      next.push(poseidonHash(poseidon, [prev[i], prev[i + 1]]));
    }
    layers.push(next);
  }

  const root = layers[levels][0];

  function path(index) {
    const pathElements = [];
    const pathIndices = [];
    let idx = index;
    for (let lvl = 0; lvl < levels; lvl++) {
      const sib = idx ^ 1;
      pathElements.push(layers[lvl][sib]);
      pathIndices.push(idx & 1);
      idx >>= 1;
    }
    return { pathElements, pathIndices };
  }

  return { root, path, zeros };
}

async function main() {
  if (!existsSync(r1cs) || !existsSync(wasm)) {
    console.log("[setup] compilando circuito primero...");
    run("node", [join(root, "scripts", "compile-circuit.mjs")]);
  }

  const ptau = await ensurePtau();

  if (!existsSync(zkey)) {
    const zkey0 = join(buildDir, "withdraw_0000.zkey");
    console.log("[zkey] groth16 setup");
    await snarkjs.zKey.newZKey(r1cs, ptau, zkey0);
    console.log("[zkey] contribute (lab entropy)");
    await snarkjs.zKey.contribute(
      zkey0,
      zkey,
      "lab-phase2",
      "phase2-lab-entropy-" + Date.now(),
    );
  } else {
    console.log("[zkey] reusing", zkey);
  }

  const vkey = await snarkjs.zKey.exportVerificationKey(zkey);
  writeFileSync(vkeyPath, JSON.stringify(vkey, null, 2));

  const poseidon = await buildPoseidon();
  // Escenario lab: un leaf en indice 0
  const nullifier = 123456789n;
  const secret = 987654321n;
  const commitment = poseidonHash(poseidon, [nullifier, secret]);
  const nullifierHash = poseidonHash(poseidon, [nullifier]);

  const recipient = 0x1111111111111111111111111111111111111111n;
  const relayer = 0x2222222222222222222222222222222222222222n;
  const fee = 1000000000000000n; // 0.001 ether

  const { root, path } = buildMerkleTree(poseidon, [commitment], LEVELS);
  const { pathElements, pathIndices } = path(0);

  const input = {
    root: root.toString(),
    nullifierHash: nullifierHash.toString(),
    recipient: recipient.toString(),
    relayer: relayer.toString(),
    fee: fee.toString(),
    nullifier: nullifier.toString(),
    secret: secret.toString(),
    pathElements: pathElements.map((x) => x.toString()),
    pathIndices: pathIndices.map((x) => x.toString()),
  };

  const inputPath = join(buildDir, "input.json");
  writeFileSync(inputPath, JSON.stringify(input, null, 2));
  console.log("[prove] generating witness + proof");

  const { proof, publicSignals } = await snarkjs.groth16.fullProve(input, wasm, zkey);
  const ok = await snarkjs.groth16.verify(vkey, publicSignals, proof);
  if (!ok) throw new Error("local verify failed");
  console.log("[prove] verified OK");
  console.log("[prove] publicSignals order: root, nullifierHash, recipient, relayer, fee");
  console.log(publicSignals);

  const calldata = await snarkjs.groth16.exportSolidityCallData(proof, publicSignals);
  // calldata format: "[a],[[b]],[c],[inputs]"
  writeFileSync(join(buildDir, "proof.json"), JSON.stringify(proof, null, 2));
  writeFileSync(join(buildDir, "public.json"), JSON.stringify(publicSignals, null, 2));
  writeFileSync(join(buildDir, "calldata.txt"), calldata);

  // Fixtures versionables para Foundry (Fase 3+)
  const fixture = {
    levels: LEVELS,
    publicSignals,
    publicInputsHex: publicSignals.map(toHex),
    proof,
    calldata,
    note: {
      nullifier: nullifier.toString(),
      secret: secret.toString(),
      commitment: commitment.toString(),
      commitmentHex: toHex(commitment),
      leafIndex: 0,
    },
    signalOrder: ["root", "nullifierHash", "recipient", "relayer", "fee"],
  };
  writeFileSync(join(fixturesDir, "proof.json"), JSON.stringify(fixture, null, 2));
  writeFileSync(join(fixturesDir, "public.json"), JSON.stringify(publicSignals, null, 2));
  writeFileSync(join(fixturesDir, "input.json"), JSON.stringify(input, null, 2));
  copyFileSync(vkeyPath, join(fixturesDir, "verification_key.json"));

  console.log("[fixtures] wrote", fixturesDir);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});

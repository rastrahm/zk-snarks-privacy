pragma circom 2.1.0;

include "./merkleTree.circom";
include "../node_modules/circomlib/circuits/poseidon.circom";

/**
 * @title Withdraw
 * @notice Prueba de membership + nullifier + binding a recipient/relayer/fee.
 *
 * Publicos (orden fijo — alinear con PrivacyPool / fixtures):
 *   0: root
 *   1: nullifierHash
 *   2: recipient   (address como field)
 *   3: relayer     (address como field)
 *   4: fee         (wei como field)
 *
 * Privados:
 *   nullifier, secret, pathElements[levels], pathIndices[levels]
 *
 * Relaciones:
 *   commitment    = Poseidon(nullifier, secret)
 *   nullifierHash = Poseidon(nullifier)   // Poseidon(1)
 *   Merkle(commitment, path) => root
 */
template Withdraw(levels) {
    // Publicos
    signal input root;
    signal input nullifierHash;
    signal input recipient;
    signal input relayer;
    signal input fee;

    // Privados
    signal input nullifier;
    signal input secret;
    signal input pathElements[levels];
    signal input pathIndices[levels];

    // commitment = Poseidon(nullifier, secret)
    component commitmentHasher = Poseidon(2);
    commitmentHasher.inputs[0] <== nullifier;
    commitmentHasher.inputs[1] <== secret;

    // nullifierHash = Poseidon(nullifier)
    component nullifierHasher = Poseidon(1);
    nullifierHasher.inputs[0] <== nullifier;
    nullifierHash === nullifierHasher.out;

    // Membership en Merkle Poseidon
    component tree = MerkleTreeChecker(levels);
    tree.leaf <== commitmentHasher.out;
    tree.root <== root;
    for (var i = 0; i < levels; i++) {
        tree.pathElements[i] <== pathElements[i];
        tree.pathIndices[i] <== pathIndices[i];
    }

    // Binding: forzar uso de publicos (anti-malleability del payout)
    // Cuadrados no-cero-safe: cualquier valor de field es valido; la restriccion
    // introduce las senales en el R1CS sin restringir el rango de address.
    signal recipientSquare;
    signal relayerSquare;
    signal feeSquare;
    recipientSquare <== recipient * recipient;
    relayerSquare <== relayer * relayer;
    feeSquare <== fee * fee;
}

// Lab: depth 4 (16 hojas). Produccion tipica Tornado: 20 — cambiar y recompilar.
component main {public [root, nullifierHash, recipient, relayer, fee]} = Withdraw(4);

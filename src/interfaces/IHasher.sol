// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/**
 * @title IHasher
 * @notice Hash de 2 field elements para commitments y nodos Merkle (Poseidon / mock).
 */
interface IHasher {
    /**
     * @notice Hash de dos hojas/nodos hermanos.
     * @param left Hijo izquierdo.
     * @param right Hijo derecho.
     * @return Hash resultante (field embebido en bytes32).
     */
    function hashLeftRight(bytes32 left, bytes32 right) external pure returns (bytes32);

    /**
     * @notice Commitment `Poseidon(nullifier, secret)` (o equivalente del hasher).
     * @param nullifier Nullifier privado.
     * @param secret Secret privado.
     * @return commitment Leaf a insertar en el Merkle tree.
     */
    function hashPreimage(bytes32 nullifier, bytes32 secret) external pure returns (bytes32);
}

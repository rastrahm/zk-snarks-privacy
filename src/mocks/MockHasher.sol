// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IHasher} from "../interfaces/IHasher.sol";

/**
 * @title MockHasher
 * @notice Hasher determinista con keccak256 para tests de arbol (no compatible con circuito Circom).
 * @dev Solo lab / unit tests. El pool de produccion debe usar `PoseidonHasher`.
 */
contract MockHasher is IHasher {
    /**
     * @inheritdoc IHasher
     */
    function hashLeftRight(bytes32 left, bytes32 right) external pure returns (bytes32) {
        return keccak256(abi.encodePacked(left, right));
    }

    /**
     * @inheritdoc IHasher
     */
    function hashPreimage(bytes32 nullifier, bytes32 secret) external pure returns (bytes32) {
        return keccak256(abi.encodePacked(nullifier, secret));
    }
}

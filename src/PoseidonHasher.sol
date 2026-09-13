// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IHasher} from "./interfaces/IHasher.sol";
import {PoseidonT3} from "./libraries/PoseidonT3.sol";

/**
 * @title PoseidonHasher
 * @notice Wrapper IHasher sobre PoseidonT3 (circomlib / alt_bn128), alineado a circuitos Circom.
 * @dev PoseidonT3 proviene de `poseidon-solidity` (MIT), pragma fijado a 0.8.24.
 */
contract PoseidonHasher is IHasher {
    /**
     * @inheritdoc IHasher
     */
    function hashLeftRight(bytes32 left, bytes32 right) external pure returns (bytes32) {
        return bytes32(PoseidonT3.hash([uint256(left), uint256(right)]));
    }

    /**
     * @inheritdoc IHasher
     */
    function hashPreimage(bytes32 nullifier, bytes32 secret) external pure returns (bytes32) {
        return bytes32(PoseidonT3.hash([uint256(nullifier), uint256(secret)]));
    }
}

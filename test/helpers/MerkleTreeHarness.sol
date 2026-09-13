// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {MerkleTreeWithHistory} from "../../src/libraries/MerkleTreeWithHistory.sol";
import {IHasher} from "../../src/interfaces/IHasher.sol";

/**
 * @title MerkleTreeHarness
 * @notice Expone `_insert` para tests Foundry.
 */
contract MerkleTreeHarness is MerkleTreeWithHistory {
    constructor(uint32 levels_, IHasher hasher_) MerkleTreeWithHistory(levels_, hasher_) {}

    /**
     * @notice Inserta una hoja y emite el nuevo indice.
     * @param leaf Commitment.
     * @return index Indice insertado.
     */
    function insert(bytes32 leaf) external returns (uint32 index) {
        return _insert(leaf);
    }
}

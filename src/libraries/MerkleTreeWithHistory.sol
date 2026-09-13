// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IHasher} from "../interfaces/IHasher.sol";
import {PrivacyErrors} from "../errors/PrivacyErrors.sol";

/**
 * @title MerkleTreeWithHistory
 * @notice Arbol Merkle incremental con historial de raices (estilo Tornado Cash).
 * @dev Contrato abstracto con storage; el pool hereda e invoca `_insert`.
 *      `isKnownRoot` permite withdraws validos tras nuevos deposits.
 */
abstract contract MerkleTreeWithHistory {
    /// @notice Tamano del ring buffer de raices historicas.
    uint32 public constant ROOT_HISTORY_SIZE = 30;

    /// @notice Profundidad del arbol (capacidad = 2^levels).
    uint32 public immutable levels;

    /// @notice Hasher Poseidon / mock inyectado.
    IHasher public immutable hasher;

    /// @notice Subarboles llenos por nivel (camino de insercion).
    mapping(uint256 => bytes32) public filledSubtrees;

    /// @notice Ceros precomputados por nivel.
    mapping(uint256 => bytes32) public zeros;

    /// @notice Ring buffer de raices.
    mapping(uint256 => bytes32) public roots;

    /// @notice Indice actual en el ring de raices.
    uint32 public currentRootIndex;

    /// @notice Proximo indice de hoja libre.
    uint32 public nextIndex;

    /**
     * @notice Inicializa ceros, subarboles y raiz vacia.
     * @param levels_ Profundidad (1..31).
     * @param hasher_ Contrato IHasher.
     */
    constructor(uint32 levels_, IHasher hasher_) {
        if (levels_ == 0 || levels_ >= 32) revert PrivacyErrors.InvalidCommitment();
        if (address(hasher_) == address(0)) revert PrivacyErrors.ZeroAddress();

        levels = levels_;
        hasher = hasher_;

        bytes32 currentZero = bytes32(0);
        for (uint32 i = 0; i < levels_; ++i) {
            zeros[i] = currentZero;
            filledSubtrees[i] = currentZero;
            currentZero = hasher_.hashLeftRight(currentZero, currentZero);
        }

        roots[0] = currentZero;
    }

    /**
     * @notice Ultima raiz conocida (current).
     * @return Raiz en `currentRootIndex`.
     */
    function getLastRoot() public view returns (bytes32) {
        return roots[currentRootIndex];
    }

    /**
     * @notice True si `root` esta en el historial circular (y no es cero).
     * @param root Raiz a validar.
     */
    function isKnownRoot(bytes32 root) public view returns (bool) {
        if (root == bytes32(0)) {
            return false;
        }

        uint32 current = currentRootIndex;
        uint32 i = current;
        do {
            if (root == roots[i]) {
                return true;
            }
            if (i == 0) {
                i = ROOT_HISTORY_SIZE;
            }
            unchecked {
                --i;
            }
        } while (i != current);

        return false;
    }

    /**
     * @notice Inserta una hoja y actualiza la raiz historica.
     * @param leaf Commitment (no cero).
     * @return index Indice de la hoja insertada.
     */
    function _insert(bytes32 leaf) internal returns (uint32 index) {
        if (leaf == bytes32(0)) revert PrivacyErrors.InvalidCommitment();

        uint32 _nextIndex = nextIndex;
        uint32 maxIndex = uint32(1) << levels;
        if (_nextIndex >= maxIndex) revert PrivacyErrors.TreeFull();

        uint32 currentIndex = _nextIndex;
        bytes32 currentLevelHash = leaf;
        bytes32 left;
        bytes32 right;

        for (uint32 i = 0; i < levels; ++i) {
            if (currentIndex % 2 == 0) {
                left = currentLevelHash;
                right = zeros[i];
                filledSubtrees[i] = currentLevelHash;
            } else {
                left = filledSubtrees[i];
                right = currentLevelHash;
            }
            currentLevelHash = hasher.hashLeftRight(left, right);
            currentIndex /= 2;
        }

        uint32 newRootIndex = (currentRootIndex + 1) % ROOT_HISTORY_SIZE;
        currentRootIndex = newRootIndex;
        roots[newRootIndex] = currentLevelHash;
        nextIndex = _nextIndex + 1;

        return _nextIndex;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import {IPrivacyPool} from "./interfaces/IPrivacyPool.sol";
import {IHasher} from "./interfaces/IHasher.sol";
import {IVerifier} from "./interfaces/IVerifier.sol";
import {MerkleTreeWithHistory} from "./libraries/MerkleTreeWithHistory.sol";
import {PrivacyErrors} from "./errors/PrivacyErrors.sol";

/**
 * @title PrivacyPool
 * @notice Mixer educativo: deposit ETH + commitment Merkle (Poseidon). Withdraw en Fase 5.
 * @dev CEI + `ReentrancyGuard`. Denomination y verifier immutables.
 */
contract PrivacyPool is IPrivacyPool, MerkleTreeWithHistory, ReentrancyGuard {
    /// @notice Monto fijo por deposit (wei).
    uint256 public immutable override denomination;

    /// @notice Verifier Groth16 (usado en withdraw — Fase 5).
    IVerifier public immutable verifier;

    /// @notice Nullifiers gastados (anti double-spend).
    mapping(bytes32 => bool) public override nullifierHashes;

    /// @notice Commitments ya depositados (anti replay de leaf).
    mapping(bytes32 => bool) public commitments;

    /**
     * @notice Despliega el pool.
     * @param levels_ Profundidad Merkle (debe alinear con el circuito).
     * @param hasher_ Poseidon / mock hasher.
     * @param verifier_ Groth16 verifier (o mock).
     * @param denomination_ Monto fijo en wei (> 0).
     */
    constructor(uint32 levels_, IHasher hasher_, IVerifier verifier_, uint256 denomination_)
        MerkleTreeWithHistory(levels_, hasher_)
    {
        if (address(verifier_) == address(0)) revert PrivacyErrors.ZeroAddress();
        if (denomination_ == 0) revert PrivacyErrors.InvalidDenomination();

        verifier = verifier_;
        denomination = denomination_;
    }

    /**
     * @inheritdoc IPrivacyPool
     */
    function currentRoot() external view returns (bytes32) {
        return getLastRoot();
    }

    /**
     * @inheritdoc IPrivacyPool
     * @dev Checks → effects (`_insert` + `commitments`) → sin interactions externas de ETH.
     */
    function deposit(bytes32 commitment) external payable nonReentrant {
        if (msg.value != denomination) revert PrivacyErrors.InvalidDenomination();
        if (commitment == bytes32(0)) revert PrivacyErrors.InvalidCommitment();
        if (commitments[commitment]) revert PrivacyErrors.InvalidCommitment();

        uint32 leafIndex = _insert(commitment);
        commitments[commitment] = true;

        emit Deposit(commitment, leafIndex, block.timestamp);
    }
}

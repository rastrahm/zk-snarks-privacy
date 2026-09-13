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
 * @notice Mixer educativo: deposit + withdraw Groth16 con nullifier y relayer fee.
 * @dev CEI + `ReentrancyGuard`. Senales publicas: root, nullifierHash, recipient, relayer, fee.
 */
contract PrivacyPool is IPrivacyPool, MerkleTreeWithHistory, ReentrancyGuard {
    /// @notice Monto fijo por deposit/withdraw (wei).
    uint256 public immutable override denomination;

    /// @notice Verifier Groth16 del circuito withdraw.
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

    /**
     * @inheritdoc IPrivacyPool
     * @dev Orden CEI: checks (root/nullifier/fee/proof) → effect (marcar nullifier) → interactions (ETH).
     */
    function withdraw(
        uint256[2] calldata a,
        uint256[2][2] calldata b,
        uint256[2] calldata c,
        bytes32 root,
        bytes32 nullifierHash,
        address payable recipient,
        address payable relayer,
        uint256 fee
    ) external nonReentrant {
        if (!isKnownRoot(root)) revert PrivacyErrors.UnknownRoot();
        if (nullifierHashes[nullifierHash]) revert PrivacyErrors.NullifierAlreadySpent();
        if (fee > denomination) revert PrivacyErrors.FeeExceedsDenomination();
        if (recipient == address(0)) revert PrivacyErrors.ZeroAddress();
        if (fee > 0 && relayer == address(0)) revert PrivacyErrors.ZeroAddress();

        uint256[5] memory pubSignals = [
            uint256(root),
            uint256(nullifierHash),
            uint256(uint160(address(recipient))),
            uint256(uint160(address(relayer))),
            fee
        ];

        if (!verifier.verifyProof(a, b, c, pubSignals)) {
            revert PrivacyErrors.InvalidZKProof();
        }

        // Effects antes de transferencias ETH
        nullifierHashes[nullifierHash] = true;

        uint256 toRecipient = denomination - fee;
        _sendEth(recipient, toRecipient);
        if (fee > 0) {
            _sendEth(relayer, fee);
        }

        emit Withdrawal(recipient, nullifierHash, relayer, fee);
    }

    /**
     * @dev ETH via `.call` (nunca transfer/send).
     */
    function _sendEth(address payable to, uint256 amount) private {
        if (amount == 0) return;
        (bool ok,) = to.call{value: amount}("");
        if (!ok) revert PrivacyErrors.EthTransferFailed();
    }
}

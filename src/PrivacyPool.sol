// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IPrivacyPool} from "./interfaces/IPrivacyPool.sol";
import {IHasher} from "./interfaces/IHasher.sol";
import {IVerifier} from "./interfaces/IVerifier.sol";
import {MerkleTreeWithHistory} from "./libraries/MerkleTreeWithHistory.sol";
import {TransientReentrancyGuard} from "./libraries/TransientReentrancyGuard.sol";
import {PrivacyErrors} from "./errors/PrivacyErrors.sol";

/**
 * @title PrivacyPool
 * @notice Mixer educativo: deposit + withdraw Groth16 con nullifier y relayer fee.
 * @dev CEI + transient reentrancy (Cancun). ETH via assembly `call` sin returndata.
 */
contract PrivacyPool is IPrivacyPool, MerkleTreeWithHistory, TransientReentrancyGuard {
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
     * @dev Checks → effects (`commitments` + `_insert`) → sin interactions ETH.
     */
    function deposit(bytes32 commitment) external payable nonReentrant {
        uint256 denom = denomination;
        if (msg.value != denom) revert PrivacyErrors.InvalidDenomination();
        if (commitment == bytes32(0)) revert PrivacyErrors.InvalidCommitment();
        if (commitments[commitment]) revert PrivacyErrors.InvalidCommitment();

        // Marcar antes del insert (si TreeFull revierte, no queda commitment huerfano:
        // comprobamos capacidad primero).
        uint32 _next = nextIndex();
        uint32 _levels = levels;
        uint32 capacity;
        unchecked {
            capacity = uint32(1) << _levels;
        }
        if (_next >= capacity) revert PrivacyErrors.TreeFull();

        commitments[commitment] = true;
        uint32 leafIndex = _insert(commitment);

        emit Deposit(commitment, leafIndex, block.timestamp);
    }

    /**
     * @inheritdoc IPrivacyPool
     * @dev CEI: checks → nullifier → ETH assembly → evento.
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

        uint256 denom = denomination;
        if (fee > denom) revert PrivacyErrors.FeeExceedsDenomination();
        if (recipient == address(0)) revert PrivacyErrors.ZeroAddress();
        if (fee != 0 && relayer == address(0)) revert PrivacyErrors.ZeroAddress();

        // Stack array (no memory alloc dinamica)
        uint256[5] memory pubSignals;
        pubSignals[0] = uint256(root);
        pubSignals[1] = uint256(nullifierHash);
        pubSignals[2] = uint256(uint160(address(recipient)));
        pubSignals[3] = uint256(uint160(address(relayer)));
        pubSignals[4] = fee;

        if (!verifier.verifyProof(a, b, c, pubSignals)) {
            revert PrivacyErrors.InvalidZKProof();
        }

        nullifierHashes[nullifierHash] = true;

        unchecked {
            _sendEth(recipient, denom - fee);
        }
        if (fee != 0) {
            _sendEth(relayer, fee);
        }

        emit Withdrawal(recipient, nullifierHash, relayer, fee);
    }

    /**
     * @dev ETH via Yul `call` sin copiar returndata (mas barato que `.call`).
     */
    function _sendEth(address to, uint256 amount) private {
        if (amount == 0) return;
        assembly ("memory-safe") {
            let success := call(gas(), to, amount, 0, 0, 0, 0)
            if iszero(success) {
                // keccak256("EthTransferFailed()")[:4] = 0x6d963f88
                mstore(0x00, 0x6d963f88)
                revert(0x1c, 0x04)
            }
        }
    }
}

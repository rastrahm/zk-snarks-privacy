// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/**
 * @title IPrivacyPool
 * @notice Pool de denomination fija: deposit con commitment Merkle (withdraw en Fase 5).
 */
interface IPrivacyPool {
    /**
     * @notice Monto fijo de deposit/withdraw en wei.
     */
    function denomination() external view returns (uint256);

    /**
     * @notice Raiz Merkle actual del arbol de commitments.
     */
    function currentRoot() external view returns (bytes32);

    /**
     * @notice True si el nullifierHash ya fue gastado.
     * @param nullifierHash Hash publico del nullifier.
     */
    function nullifierHashes(bytes32 nullifierHash) external view returns (bool);

    /**
     * @notice Deposita `denomination` ETH con un commitment Poseidon.
     * @param commitment Leaf `Poseidon(nullifier, secret)`.
     */
    function deposit(bytes32 commitment) external payable;

    /**
     * @notice Emitido tras insertar un commitment.
     * @param commitment Leaf insertado.
     * @param leafIndex Indice en el Merkle tree.
     * @param timestamp `block.timestamp`.
     */
    event Deposit(bytes32 indexed commitment, uint32 leafIndex, uint256 timestamp);
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/**
 * @title IPrivacyPool
 * @notice Pool de denomination fija: deposit + withdraw ZK con relayer opcional.
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
     * @notice Retira `denomination` con proof Groth16; fee opcional al relayer.
     * @param a Punto A de la proof.
     * @param b Punto B de la proof (orden Ethereum).
     * @param c Punto C de la proof.
     * @param root Raiz historica del Merkle tree.
     * @param nullifierHash Nullifier publico (anti double-spend).
     * @param recipient Destinatario del payout neto.
     * @param relayer Relayer (address(0) si fee == 0).
     * @param fee Fee en wei (<= denomination), ligada al proof.
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
    ) external;

    /**
     * @notice Emitido tras insertar un commitment.
     * @param commitment Leaf insertado.
     * @param leafIndex Indice en el Merkle tree.
     * @param timestamp `block.timestamp`.
     */
    event Deposit(bytes32 indexed commitment, uint32 leafIndex, uint256 timestamp);

    /**
     * @notice Emitido tras un withdraw exitoso.
     * @param to Recipient del neto.
     * @param nullifierHash Nullifier gastado.
     * @param relayer Relayer pagado (puede ser 0).
     * @param fee Fee pagada al relayer.
     */
    event Withdrawal(address to, bytes32 nullifierHash, address relayer, uint256 fee);
}

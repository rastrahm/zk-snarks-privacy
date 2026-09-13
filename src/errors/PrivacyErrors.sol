// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/**
 * @title PrivacyErrors
 * @notice Custom errors del Privacy Pool (modulo 17).
 */
library PrivacyErrors {
    /// @notice El nullifierHash ya fue usado en un withdraw previo.
    error NullifierAlreadySpent();

    /// @notice La prueba Groth16 no verifico o las senales no coinciden.
    error InvalidZKProof();

    /// @notice La raiz Merkle no esta en el historial conocido.
    error UnknownRoot();

    /// @notice Commitment cero o invalido para insertar en el arbol.
    error InvalidCommitment();

    /// @notice El Merkle tree alcanzo 2^levels hojas.
    error TreeFull();

    /// @notice La fee del relayer supera la denomination del pool.
    error FeeExceedsDenomination();

    /// @notice Fallo la transferencia ETH vía `.call`.
    error EthTransferFailed();

    /// @notice Se recibio address(0) donde no esta permitido.
    error ZeroAddress();

    /// @notice `msg.value` distinto de la denomination fija.
    error InvalidDenomination();

    /// @notice Caller no autorizado (admin / roles).
    error Unauthorized();
}

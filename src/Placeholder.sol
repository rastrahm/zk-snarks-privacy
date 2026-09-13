// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/**
 * @title Placeholder
 * @notice Stub de Fase 0 para validar compilacion Foundry y remappings.
 * @dev Se elimina en Fase 1 al introducir Hasher / Merkle / PrivacyPool.
 */
contract Placeholder {
    /// @notice Identificador del modulo para smoke tests.
    string public constant MODULE = "17-zk-snarks-privacy";

    /**
     * @notice Eco de un valor para comprobar llamadas basicas.
     * @param value Entero arbitrario.
     * @return El mismo `value`.
     */
    function ping(uint256 value) external pure returns (uint256) {
        return value;
    }
}

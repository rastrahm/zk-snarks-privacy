// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/**
 * @title IVerifier
 * @notice Verificacion Groth16 (5 senales publicas del circuito withdraw).
 */
interface IVerifier {
    /**
     * @notice Verifica una prueba Groth16.
     * @param _pA Punto A de la proof.
     * @param _pB Punto B de la proof (G2, orden Ethereum / snarkjs calldata).
     * @param _pC Punto C de la proof.
     * @param _pubSignals [root, nullifierHash, recipient, relayer, fee].
     * @return True si el pairing es valido.
     */
    function verifyProof(
        uint256[2] calldata _pA,
        uint256[2][2] calldata _pB,
        uint256[2] calldata _pC,
        uint256[5] calldata _pubSignals
    ) external view returns (bool);
}

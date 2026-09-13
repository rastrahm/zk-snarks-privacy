// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {PrivacyErrors} from "../src/errors/PrivacyErrors.sol";
import {Groth16Verifier} from "../src/verifiers/Groth16Verifier.sol";
import {VerifierGate} from "../src/verifiers/VerifierGate.sol";
import {MockVerifier} from "../src/mocks/MockVerifier.sol";
import {ProofFixtureBase, ProofFixtureLib} from "./helpers/ProofFixture.sol";

/**
 * @title ProofVerificationTest
 * @notice Fase 3: pairing valida on-chain + proof invalida → InvalidZKProof.
 */
contract ProofVerificationTest is ProofFixtureBase {
    Groth16Verifier internal verifier;
    VerifierGate internal gate;

    function setUp() public {
        verifier = new Groth16Verifier();
        gate = new VerifierGate(verifier);
    }

    function test_validProof_verifyProof_returnsTrue() public view {
        ProofFixtureLib.ProofData memory p = _loadProof();
        assertTrue(verifier.verifyProof(p.a, p.b, p.c, p.input));
    }

    function test_validProof_requireValidProof_ok() public view {
        ProofFixtureLib.ProofData memory p = _loadProof();
        gate.requireValidProof(p.a, p.b, p.c, p.input);
    }

    function test_tamperedInput_returnsFalse() public view {
        ProofFixtureLib.ProofData memory p = _loadProof();
        p.input[4] = p.input[4] + 1; // fee alterada
        assertFalse(verifier.verifyProof(p.a, p.b, p.c, p.input));
    }

    function test_tamperedProof_requireValid_revertsInvalidZKProof() public {
        ProofFixtureLib.ProofData memory p = _loadProof();
        p.a[0] = p.a[0] + 1;

        vm.expectRevert(PrivacyErrors.InvalidZKProof.selector);
        gate.requireValidProof(p.a, p.b, p.c, p.input);
    }

    function test_tamperedPublicRoot_revertsInvalidZKProof() public {
        ProofFixtureLib.ProofData memory p = _loadProof();
        p.input[0] = p.input[0] + 1;

        vm.expectRevert(PrivacyErrors.InvalidZKProof.selector);
        gate.requireValidProof(p.a, p.b, p.c, p.input);
    }

    function test_mockVerifier_gateRespectsFlag() public {
        MockVerifier mock = new MockVerifier();
        VerifierGate mockGate = new VerifierGate(mock);
        ProofFixtureLib.ProofData memory p = _loadProof();

        mockGate.requireValidProof(p.a, p.b, p.c, p.input);

        mock.setShouldPass(false);
        vm.expectRevert(PrivacyErrors.InvalidZKProof.selector);
        mockGate.requireValidProof(p.a, p.b, p.c, p.input);
    }

    function test_gate_rejectsZeroVerifier() public {
        vm.expectRevert(PrivacyErrors.ZeroAddress.selector);
        new VerifierGate(Groth16Verifier(address(0)));
    }
}

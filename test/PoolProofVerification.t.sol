// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {PrivacyPool} from "../src/PrivacyPool.sol";
import {PrivacyErrors} from "../src/errors/PrivacyErrors.sol";
import {PoseidonHasher} from "../src/PoseidonHasher.sol";
import {Groth16Verifier} from "../src/verifiers/Groth16Verifier.sol";
import {MockHasher} from "../src/mocks/MockHasher.sol";
import {MockVerifier} from "../src/mocks/MockVerifier.sol";
import {IHasher} from "../src/interfaces/IHasher.sol";
import {ProofFixtureBase, ProofFixtureLib} from "./helpers/ProofFixture.sol";

/**
 * @title PoolProofVerificationTest
 * @notice Fase 6: proof valida / tampered a nivel PrivacyPool (mock + Groth16).
 */
contract PoolProofVerificationTest is ProofFixtureBase {
    uint32 internal constant LEVELS = 4;
    uint256 internal constant DENOMINATION = 0.1 ether;

    function test_validProof_e2e_balances() public {
        ProofFixtureLib.ProofData memory p = _loadProof();
        PrivacyPool zkPool = new PrivacyPool(
            LEVELS, IHasher(address(new PoseidonHasher())), new Groth16Verifier(), DENOMINATION
        );

        bytes32 commitment =
            bytes32(uint256(0x2536d01521137bf7b39e3fd26c1376f456ce46a45993a5d7c3c158a450fd7329));
        zkPool.deposit{value: DENOMINATION}(commitment);

        address payable recipient = payable(address(uint160(p.input[2])));
        address payable relayer = payable(address(uint160(p.input[3])));
        uint256 fee = p.input[4];
        uint256 balR = recipient.balance;
        uint256 balL = relayer.balance;

        zkPool.withdraw(
            p.a,
            p.b,
            p.c,
            bytes32(p.input[0]),
            bytes32(p.input[1]),
            recipient,
            relayer,
            fee
        );

        assertEq(recipient.balance - balR, DENOMINATION - fee);
        assertEq(relayer.balance - balL, fee);
        assertEq(address(zkPool).balance, 0);
    }

    function test_tamperedProof_revertsInvalidZKProof() public {
        ProofFixtureLib.ProofData memory p = _loadProof();
        PrivacyPool zkPool = new PrivacyPool(
            LEVELS, IHasher(address(new PoseidonHasher())), new Groth16Verifier(), DENOMINATION
        );
        bytes32 commitment =
            bytes32(uint256(0x2536d01521137bf7b39e3fd26c1376f456ce46a45993a5d7c3c158a450fd7329));
        zkPool.deposit{value: DENOMINATION}(commitment);

        p.a[0] = p.a[0] + 1;

        vm.expectRevert(PrivacyErrors.InvalidZKProof.selector);
        zkPool.withdraw(
            p.a,
            p.b,
            p.c,
            bytes32(p.input[0]),
            bytes32(p.input[1]),
            payable(address(uint160(p.input[2]))),
            payable(address(uint160(p.input[3]))),
            p.input[4]
        );
    }

    function test_tamperedPublicFee_binding_reverts() public {
        ProofFixtureLib.ProofData memory p = _loadProof();
        PrivacyPool zkPool = new PrivacyPool(
            LEVELS, IHasher(address(new PoseidonHasher())), new Groth16Verifier(), DENOMINATION
        );
        bytes32 commitment =
            bytes32(uint256(0x2536d01521137bf7b39e3fd26c1376f456ce46a45993a5d7c3c158a450fd7329));
        zkPool.deposit{value: DENOMINATION}(commitment);

        uint256 forgedFee = p.input[4] + 1;
        if (forgedFee > DENOMINATION) {
            forgedFee = DENOMINATION;
            // Si coincide con fee original no sirve; forzar otro publico
            if (forgedFee == p.input[4]) forgedFee = 0;
        }
        // Si forgedFee == fee original, cambiar recipient binding en su lugar
        if (forgedFee == p.input[4]) {
            vm.expectRevert(PrivacyErrors.InvalidZKProof.selector);
            zkPool.withdraw(
                p.a,
                p.b,
                p.c,
                bytes32(p.input[0]),
                bytes32(p.input[1]),
                payable(address(0xBEEF)),
                payable(address(uint160(p.input[3]))),
                p.input[4]
            );
            return;
        }

        vm.expectRevert(PrivacyErrors.InvalidZKProof.selector);
        zkPool.withdraw(
            p.a,
            p.b,
            p.c,
            bytes32(p.input[0]),
            bytes32(p.input[1]),
            payable(address(uint160(p.input[2]))),
            payable(address(uint160(p.input[3]))),
            forgedFee
        );
    }

    function test_mockVerifier_false_reverts() public {
        MockVerifier mock = new MockVerifier();
        PrivacyPool pool = new PrivacyPool(LEVELS, new MockHasher(), mock, DENOMINATION);
        pool.deposit{value: DENOMINATION}(keccak256("c"));
        mock.setShouldPass(false);

        bytes32 root = pool.currentRoot();
        uint256[2] memory a;
        uint256[2][2] memory b;
        uint256[2] memory c;

        vm.expectRevert(PrivacyErrors.InvalidZKProof.selector);
        pool.withdraw(a, b, c, root, keccak256("n"), payable(address(0x1)), payable(address(0)), 0);
    }
}

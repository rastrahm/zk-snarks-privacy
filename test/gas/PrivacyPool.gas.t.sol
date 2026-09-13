// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";

import {PrivacyPool} from "../../src/PrivacyPool.sol";
import {MockHasher} from "../../src/mocks/MockHasher.sol";
import {MockVerifier} from "../../src/mocks/MockVerifier.sol";
import {PoseidonHasher} from "../../src/PoseidonHasher.sol";
import {Groth16Verifier} from "../../src/verifiers/Groth16Verifier.sol";
import {IHasher} from "../../src/interfaces/IHasher.sol";
import {ProofFixtureBase, ProofFixtureLib} from "../helpers/ProofFixture.sol";

/**
 * @title PrivacyPoolGasTest
 * @notice Snapshot de gas deposit/withdraw (mock hasher) y e2e Groth16.
 */
contract PrivacyPoolGasTest is ProofFixtureBase {
    uint32 internal constant LEVELS = 4;
    uint256 internal constant DENOMINATION = 0.1 ether;

    PrivacyPool internal pool;
    MockHasher internal hasher;
    MockVerifier internal verifier;

    uint256[2] internal a;
    uint256[2][2] internal b;
    uint256[2] internal c;
    address payable internal recipient = payable(address(0xA11CE));
    address payable internal relayer = payable(address(0xB0B));

    function setUp() public {
        hasher = new MockHasher();
        verifier = new MockVerifier();
        pool = new PrivacyPool(LEVELS, hasher, verifier, DENOMINATION);
        a[0] = 1;
        a[1] = 2;
        b[0][0] = 3;
        b[0][1] = 4;
        b[1][0] = 5;
        b[1][1] = 6;
        c[0] = 7;
        c[1] = 8;
    }

    function testGas_deposit() public {
        pool.deposit{value: DENOMINATION}(keccak256("gas-deposit"));
    }

    function testGas_withdraw_zeroFee() public {
        pool.deposit{value: DENOMINATION}(keccak256("gas-w0"));
        bytes32 root = pool.currentRoot();
        pool.withdraw(a, b, c, root, keccak256("n-gas-0"), recipient, payable(address(0)), 0);
    }

    function testGas_withdraw_withRelayerFee() public {
        pool.deposit{value: DENOMINATION}(keccak256("gas-wf"));
        bytes32 root = pool.currentRoot();
        pool.withdraw(a, b, c, root, keccak256("n-gas-f"), recipient, relayer, 0.01 ether);
    }

    function testGas_e2e_groth16_withdraw() public {
        ProofFixtureLib.ProofData memory p = _loadProof();
        PrivacyPool zkPool = new PrivacyPool(
            LEVELS, IHasher(address(new PoseidonHasher())), new Groth16Verifier(), DENOMINATION
        );
        bytes32 commitment =
            bytes32(uint256(0x2536d01521137bf7b39e3fd26c1376f456ce46a45993a5d7c3c158a450fd7329));
        zkPool.deposit{value: DENOMINATION}(commitment);
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
}

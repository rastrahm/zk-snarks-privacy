// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";

import {PrivacyPool} from "../src/PrivacyPool.sol";
import {PrivacyErrors} from "../src/errors/PrivacyErrors.sol";
import {MockHasher} from "../src/mocks/MockHasher.sol";
import {MockVerifier} from "../src/mocks/MockVerifier.sol";
import {RejectETH} from "../src/mocks/RejectETH.sol";
import {PoseidonHasher} from "../src/PoseidonHasher.sol";
import {Groth16Verifier} from "../src/verifiers/Groth16Verifier.sol";
import {IHasher} from "../src/interfaces/IHasher.sol";
import {ProofFixtureBase, ProofFixtureLib} from "./helpers/ProofFixture.sol";

/**
 * @title PrivacyPoolWithdrawTest
 * @notice Fase 5: withdraw mock (fee/nullifier/root) + e2e Groth16 con fixture.
 */
contract PrivacyPoolWithdrawTest is ProofFixtureBase {
    uint32 internal constant LEVELS = 4;
    uint256 internal constant DENOMINATION = 0.1 ether;

    MockHasher internal mockHasher;
    MockVerifier internal mockVerifier;
    PrivacyPool internal pool;

    address payable internal recipient = payable(address(0xA11CE));
    address payable internal relayer = payable(address(0xB0B));

    uint256[2] internal a;
    uint256[2][2] internal b;
    uint256[2] internal c;

    event Withdrawal(address to, bytes32 nullifierHash, address relayer, uint256 fee);

    function setUp() public {
        mockHasher = new MockHasher();
        mockVerifier = new MockVerifier();
        pool = new PrivacyPool(LEVELS, mockHasher, mockVerifier, DENOMINATION);

        // Dummy proof coords (mock ignora valores)
        a[0] = 1;
        a[1] = 2;
        b[0][0] = 3;
        b[0][1] = 4;
        b[1][0] = 5;
        b[1][1] = 6;
        c[0] = 7;
        c[1] = 8;

        // Un deposit para tener root conocida y liquidez
        pool.deposit{value: DENOMINATION}(keccak256("leaf-0"));
    }

    function test_withdraw_feeSplit() public {
        bytes32 root = pool.currentRoot();
        bytes32 nullifierHash = keccak256("n1");
        uint256 fee = 0.01 ether;

        uint256 balRBefore = recipient.balance;
        uint256 balLBefore = relayer.balance;

        vm.expectEmit(true, true, true, true);
        emit Withdrawal(recipient, nullifierHash, relayer, fee);

        pool.withdraw(a, b, c, root, nullifierHash, recipient, relayer, fee);

        assertEq(recipient.balance - balRBefore, DENOMINATION - fee);
        assertEq(relayer.balance - balLBefore, fee);
        assertTrue(pool.nullifierHashes(nullifierHash));
        assertEq(address(pool).balance, 0);
    }

    function test_withdraw_zeroFee_allToRecipient() public {
        bytes32 root = pool.currentRoot();
        bytes32 nullifierHash = keccak256("n2");

        uint256 before = recipient.balance;
        pool.withdraw(a, b, c, root, nullifierHash, recipient, payable(address(0)), 0);
        assertEq(recipient.balance - before, DENOMINATION);
    }

    function test_withdraw_nullifierReplay_reverts() public {
        bytes32 root = pool.currentRoot();
        bytes32 nullifierHash = keccak256("n3");
        // Segundo deposit para poder retirar dos veces de liquidez
        pool.deposit{value: DENOMINATION}(keccak256("leaf-1"));

        pool.withdraw(a, b, c, root, nullifierHash, recipient, payable(address(0)), 0);

        vm.expectRevert(PrivacyErrors.NullifierAlreadySpent.selector);
        pool.withdraw(a, b, c, root, nullifierHash, recipient, payable(address(0)), 0);
    }

    function test_withdraw_unknownRoot_reverts() public {
        vm.expectRevert(PrivacyErrors.UnknownRoot.selector);
        pool.withdraw(a, b, c, bytes32(uint256(0xdead)), keccak256("n4"), recipient, payable(address(0)), 0);
    }

    function test_withdraw_invalidProof_reverts() public {
        mockVerifier.setShouldPass(false);
        bytes32 root = pool.currentRoot();
        vm.expectRevert(PrivacyErrors.InvalidZKProof.selector);
        pool.withdraw(a, b, c, root, keccak256("n5"), recipient, payable(address(0)), 0);
    }

    function test_withdraw_feeExceeds_reverts() public {
        bytes32 root = pool.currentRoot();
        vm.expectRevert(PrivacyErrors.FeeExceedsDenomination.selector);
        pool.withdraw(a, b, c, root, keccak256("n6"), recipient, relayer, DENOMINATION + 1);
    }

    function test_withdraw_zeroRecipient_reverts() public {
        bytes32 root = pool.currentRoot();
        vm.expectRevert(PrivacyErrors.ZeroAddress.selector);
        pool.withdraw(a, b, c, root, keccak256("n7"), payable(address(0)), payable(address(0)), 0);
    }

    function test_withdraw_feeWithoutRelayer_reverts() public {
        bytes32 root = pool.currentRoot();
        vm.expectRevert(PrivacyErrors.ZeroAddress.selector);
        pool.withdraw(a, b, c, root, keccak256("n8"), recipient, payable(address(0)), 1);
    }

    function test_withdraw_rejectEth_reverts() public {
        RejectETH sink = new RejectETH();
        bytes32 root = pool.currentRoot();
        vm.expectRevert(PrivacyErrors.EthTransferFailed.selector);
        pool.withdraw(a, b, c, root, keccak256("n9"), payable(address(sink)), payable(address(0)), 0);
    }

    function test_withdraw_historicalRoot_afterNewDeposit() public {
        bytes32 root0 = pool.currentRoot();
        pool.deposit{value: DENOMINATION}(keccak256("leaf-later"));
        // root0 sigue siendo valida
        pool.withdraw(a, b, c, root0, keccak256("n-hist"), recipient, payable(address(0)), 0);
        assertTrue(pool.nullifierHashes(keccak256("n-hist")));
    }
}

/**
 * @title PrivacyPoolWithdrawE2ETest
 * @notice Withdraw real: deposit commitment de fixture + Groth16Verifier.
 */
contract PrivacyPoolWithdrawE2ETest is ProofFixtureBase {
    uint32 internal constant LEVELS = 4;
    uint256 internal constant DENOMINATION = 0.1 ether;

    function test_e2e_depositFixtureCommitment_thenWithdraw() public {
        ProofFixtureLib.ProofData memory p = _loadProof();

        PoseidonHasher hasher = new PoseidonHasher();
        Groth16Verifier verifier = new Groth16Verifier();
        PrivacyPool zkPool = new PrivacyPool(LEVELS, IHasher(address(hasher)), verifier, DENOMINATION);

        // Commitment y publicos de la fixture lab (generate-proof.mjs)
        bytes32 commitment = bytes32(
            uint256(0x2536d01521137bf7b39e3fd26c1376f456ce46a45993a5d7c3c158a450fd7329)
        );
        bytes32 root = bytes32(p.input[0]);
        bytes32 nullifierHash = bytes32(p.input[1]);
        address payable fixtureRecipient = payable(address(uint160(p.input[2])));
        address payable fixtureRelayer = payable(address(uint160(p.input[3])));
        uint256 fee = p.input[4];

        zkPool.deposit{value: DENOMINATION}(commitment);
        assertEq(zkPool.currentRoot(), root, "on-chain root must match circuit root");

        uint256 balR = fixtureRecipient.balance;
        uint256 balL = fixtureRelayer.balance;

        zkPool.withdraw(
            p.a,
            p.b,
            p.c,
            root,
            nullifierHash,
            fixtureRecipient,
            fixtureRelayer,
            fee
        );

        assertEq(fixtureRecipient.balance - balR, DENOMINATION - fee);
        assertEq(fixtureRelayer.balance - balL, fee);
        assertTrue(zkPool.nullifierHashes(nullifierHash));

        // Replay
        vm.expectRevert(PrivacyErrors.NullifierAlreadySpent.selector);
        zkPool.withdraw(
            p.a, p.b, p.c, root, nullifierHash, fixtureRecipient, fixtureRelayer, fee
        );
    }
}

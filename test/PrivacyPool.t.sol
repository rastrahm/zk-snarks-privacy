// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";

import {PrivacyPool} from "../src/PrivacyPool.sol";
import {PrivacyErrors} from "../src/errors/PrivacyErrors.sol";
import {MockHasher} from "../src/mocks/MockHasher.sol";
import {MockVerifier} from "../src/mocks/MockVerifier.sol";
import {PoseidonHasher} from "../src/PoseidonHasher.sol";
import {IHasher} from "../src/interfaces/IHasher.sol";
import {IVerifier} from "../src/interfaces/IVerifier.sol";

/**
 * @title PrivacyPoolDepositTest
 * @notice Fase 4: deposit, denomination, roots historicas, TreeFull.
 */
contract PrivacyPoolDepositTest is Test {
    uint32 internal constant LEVELS = 4;
    uint256 internal constant DENOMINATION = 0.1 ether;

    MockHasher internal mockHasher;
    MockVerifier internal mockVerifier;
    PrivacyPool internal pool;

    event Deposit(bytes32 indexed commitment, uint32 leafIndex, uint256 timestamp);

    function setUp() public {
        mockHasher = new MockHasher();
        mockVerifier = new MockVerifier();
        pool = new PrivacyPool(LEVELS, mockHasher, mockVerifier, DENOMINATION);
    }

    function test_constructor_setsDenominationAndEmptyRoot() public view {
        assertEq(pool.denomination(), DENOMINATION);
        bytes32 root = pool.currentRoot();
        assertTrue(root != bytes32(0));
        assertTrue(pool.isKnownRoot(root));
    }

    function test_constructor_rejectsZeroDenomination() public {
        vm.expectRevert(PrivacyErrors.InvalidDenomination.selector);
        new PrivacyPool(LEVELS, mockHasher, mockVerifier, 0);
    }

    function test_constructor_rejectsZeroVerifier() public {
        vm.expectRevert(PrivacyErrors.ZeroAddress.selector);
        new PrivacyPool(LEVELS, mockHasher, IVerifier(address(0)), DENOMINATION);
    }

    function test_deposit_success_emitsAndUpdatesRoot() public {
        bytes32 commitment = keccak256("c1");
        bytes32 rootBefore = pool.currentRoot();

        vm.expectEmit(true, false, false, true);
        emit Deposit(commitment, 0, block.timestamp);

        pool.deposit{value: DENOMINATION}(commitment);

        bytes32 rootAfter = pool.currentRoot();
        assertTrue(rootAfter != rootBefore);
        assertTrue(pool.isKnownRoot(rootBefore));
        assertTrue(pool.isKnownRoot(rootAfter));
        assertTrue(pool.commitments(commitment));
        assertEq(pool.nextIndex(), 1);
        assertEq(address(pool).balance, DENOMINATION);
    }

    function test_deposit_wrongValue_reverts() public {
        bytes32 commitment = keccak256("c2");
        vm.expectRevert(PrivacyErrors.InvalidDenomination.selector);
        pool.deposit{value: DENOMINATION - 1}(commitment);
    }

    function test_deposit_zeroCommitment_reverts() public {
        vm.expectRevert(PrivacyErrors.InvalidCommitment.selector);
        pool.deposit{value: DENOMINATION}(bytes32(0));
    }

    function test_deposit_duplicateCommitment_reverts() public {
        bytes32 commitment = keccak256("dup");
        pool.deposit{value: DENOMINATION}(commitment);

        vm.expectRevert(PrivacyErrors.InvalidCommitment.selector);
        pool.deposit{value: DENOMINATION}(commitment);
    }

    function test_multipleDeposits_preserveHistoricalRoots() public {
        bytes32 r0 = pool.currentRoot();
        pool.deposit{value: DENOMINATION}(keccak256("a"));
        bytes32 r1 = pool.currentRoot();
        pool.deposit{value: DENOMINATION}(keccak256("b"));
        bytes32 r2 = pool.currentRoot();

        assertTrue(pool.isKnownRoot(r0));
        assertTrue(pool.isKnownRoot(r1));
        assertTrue(pool.isKnownRoot(r2));
        assertEq(address(pool).balance, 2 * DENOMINATION);
    }

    function test_deposit_treeFull_reverts() public {
        uint32 capacity = uint32(1) << LEVELS;
        for (uint32 i = 0; i < capacity; ++i) {
            pool.deposit{value: DENOMINATION}(keccak256(abi.encodePacked("leaf", i)));
        }
        vm.expectRevert(PrivacyErrors.TreeFull.selector);
        pool.deposit{value: DENOMINATION}(keccak256("overflow"));
    }

    function testFuzz_deposit_onlyExactDenomination(uint256 value, bytes32 commitment) public {
        vm.assume(commitment != bytes32(0));
        value = bound(value, 0, 10 ether);
        vm.assume(value != DENOMINATION);

        vm.expectRevert(PrivacyErrors.InvalidDenomination.selector);
        pool.deposit{value: value}(commitment);
    }

    function testFuzz_deposit_uniqueCommitments(bytes32 a, bytes32 b) public {
        vm.assume(a != bytes32(0) && b != bytes32(0) && a != b);

        bytes32 r0 = pool.currentRoot();
        pool.deposit{value: DENOMINATION}(a);
        bytes32 r1 = pool.currentRoot();
        pool.deposit{value: DENOMINATION}(b);
        bytes32 r2 = pool.currentRoot();

        assertTrue(r1 != r0 && r2 != r1);
        assertTrue(pool.isKnownRoot(r0));
        assertTrue(pool.isKnownRoot(r1));
        assertTrue(pool.isKnownRoot(r2));
    }

    function test_deposit_withPoseidonHasher() public {
        PoseidonHasher poseidon = new PoseidonHasher();
        PrivacyPool poseidonPool = new PrivacyPool(3, IHasher(address(poseidon)), mockVerifier, DENOMINATION);

        bytes32 commitment = poseidon.hashPreimage(bytes32(uint256(7)), bytes32(uint256(9)));
        bytes32 rootBefore = poseidonPool.currentRoot();
        poseidonPool.deposit{value: DENOMINATION}(commitment);

        assertTrue(poseidonPool.currentRoot() != rootBefore);
        assertTrue(poseidonPool.commitments(commitment));
    }
}

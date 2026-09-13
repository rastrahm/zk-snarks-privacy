// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";

import {PrivacyErrors} from "../src/errors/PrivacyErrors.sol";
import {MockHasher} from "../src/mocks/MockHasher.sol";
import {PoseidonHasher} from "../src/PoseidonHasher.sol";
import {MerkleTreeHarness} from "./helpers/MerkleTreeHarness.sol";

/**
 * @title MerkleTreeTest
 * @notice TDD Fase 1: inserts, raices historicas, TreeFull, zero leaf, Poseidon.
 */
contract MerkleTreeTest is Test {
    uint32 internal constant LEVELS = 4; // capacidad 16 — suficiente para unit/fuzz

    MockHasher internal mockHasher;
    MerkleTreeHarness internal tree;

    function setUp() public {
        mockHasher = new MockHasher();
        tree = new MerkleTreeHarness(LEVELS, mockHasher);
    }

    function test_emptyRoot_isKnown() public view {
        bytes32 root = tree.getLastRoot();
        assertTrue(root != bytes32(0));
        assertTrue(tree.isKnownRoot(root));
    }

    function test_insert_changesRoot_andKeepsHistory() public {
        bytes32 root0 = tree.getLastRoot();

        bytes32 leaf1 = keccak256("leaf-1");
        tree.insert(leaf1);
        bytes32 root1 = tree.getLastRoot();

        assertTrue(root1 != root0);
        assertTrue(tree.isKnownRoot(root0));
        assertTrue(tree.isKnownRoot(root1));
        assertEq(tree.nextIndex(), 1);
    }

    function test_multipleInserts_preservePriorRoots() public {
        bytes32 r0 = tree.getLastRoot();
        tree.insert(keccak256("a"));
        bytes32 r1 = tree.getLastRoot();
        tree.insert(keccak256("b"));
        bytes32 r2 = tree.getLastRoot();
        tree.insert(keccak256("c"));
        bytes32 r3 = tree.getLastRoot();

        assertTrue(tree.isKnownRoot(r0));
        assertTrue(tree.isKnownRoot(r1));
        assertTrue(tree.isKnownRoot(r2));
        assertTrue(tree.isKnownRoot(r3));
        assertEq(tree.nextIndex(), 3);
    }

    function test_zeroRoot_notKnown() public view {
        assertFalse(tree.isKnownRoot(bytes32(0)));
    }

    function test_unknownRoot_notKnown() public view {
        assertFalse(tree.isKnownRoot(keccak256("forgery")));
    }

    function test_insert_zeroLeaf_reverts() public {
        vm.expectRevert(PrivacyErrors.InvalidCommitment.selector);
        tree.insert(bytes32(0));
    }

    function test_treeFull_reverts() public {
        uint32 capacity = uint32(1) << LEVELS;
        for (uint32 i = 0; i < capacity; ++i) {
            tree.insert(keccak256(abi.encodePacked("leaf", i)));
        }
        vm.expectRevert(PrivacyErrors.TreeFull.selector);
        tree.insert(keccak256("overflow"));
    }

    function test_constructor_rejectsZeroLevels() public {
        vm.expectRevert(PrivacyErrors.InvalidCommitment.selector);
        new MerkleTreeHarness(0, mockHasher);
    }

    function test_constructor_rejectsZeroHasher() public {
        vm.expectRevert(PrivacyErrors.ZeroAddress.selector);
        new MerkleTreeHarness(LEVELS, MockHasher(address(0)));
    }

    function testFuzz_insert_uniqueLeaves(bytes32 a, bytes32 b) public {
        vm.assume(a != bytes32(0) && b != bytes32(0) && a != b);

        bytes32 r0 = tree.getLastRoot();
        tree.insert(a);
        bytes32 r1 = tree.getLastRoot();
        tree.insert(b);
        bytes32 r2 = tree.getLastRoot();

        assertTrue(r1 != r0);
        assertTrue(r2 != r1);
        assertTrue(tree.isKnownRoot(r0));
        assertTrue(tree.isKnownRoot(r1));
        assertTrue(tree.isKnownRoot(r2));
    }

    function test_poseidonHasher_hashLeftRight_deterministic() public {
        PoseidonHasher poseidon = new PoseidonHasher();
        bytes32 left = bytes32(uint256(1));
        bytes32 right = bytes32(uint256(2));
        bytes32 h1 = poseidon.hashLeftRight(left, right);
        bytes32 h2 = poseidon.hashLeftRight(left, right);
        assertEq(h1, h2);
        assertTrue(h1 != bytes32(0));
        assertTrue(h1 != poseidon.hashLeftRight(right, left));
    }

    function test_poseidonTree_insert_updatesRoot() public {
        PoseidonHasher poseidon = new PoseidonHasher();
        MerkleTreeHarness poseidonTree = new MerkleTreeHarness(3, poseidon);

        bytes32 root0 = poseidonTree.getLastRoot();
        bytes32 leaf = poseidon.hashPreimage(bytes32(uint256(11)), bytes32(uint256(22)));
        poseidonTree.insert(leaf);

        bytes32 root1 = poseidonTree.getLastRoot();
        assertTrue(root1 != root0);
        assertTrue(poseidonTree.isKnownRoot(root0));
        assertTrue(poseidonTree.isKnownRoot(root1));
    }
}

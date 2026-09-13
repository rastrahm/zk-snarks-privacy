// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";

import {PrivacyPool} from "../src/PrivacyPool.sol";
import {PrivacyErrors} from "../src/errors/PrivacyErrors.sol";
import {MockHasher} from "../src/mocks/MockHasher.sol";
import {MockVerifier} from "../src/mocks/MockVerifier.sol";

/**
 * @title NullifierReplayTest
 * @notice Fase 6: double-spend / replay de nullifierHash.
 */
contract NullifierReplayTest is Test {
    uint32 internal constant LEVELS = 4;
    uint256 internal constant DENOMINATION = 0.1 ether;

    PrivacyPool internal pool;
    MockVerifier internal verifier;

    uint256[2] internal a;
    uint256[2][2] internal b;
    uint256[2] internal c;

    address payable internal recipient = payable(address(0xA11CE));

    function setUp() public {
        verifier = new MockVerifier();
        pool = new PrivacyPool(LEVELS, new MockHasher(), verifier, DENOMINATION);
        pool.deposit{value: DENOMINATION}(keccak256("c0"));
        pool.deposit{value: DENOMINATION}(keccak256("c1"));
        a[0] = 1;
        a[1] = 1;
        b[0][0] = 1;
        b[0][1] = 1;
        b[1][0] = 1;
        b[1][1] = 1;
        c[0] = 1;
        c[1] = 1;
    }

    function test_nullifierReplay_secondWithdraw_reverts() public {
        bytes32 root = pool.currentRoot();
        bytes32 nullifierHash = keccak256("spent-once");

        pool.withdraw(a, b, c, root, nullifierHash, recipient, payable(address(0)), 0);
        assertTrue(pool.nullifierHashes(nullifierHash));

        vm.expectRevert(PrivacyErrors.NullifierAlreadySpent.selector);
        pool.withdraw(a, b, c, root, nullifierHash, recipient, payable(address(0)), 0);
    }

    function test_distinctNullifiers_bothSucceed() public {
        bytes32 root = pool.currentRoot();
        pool.withdraw(a, b, c, root, keccak256("n-a"), recipient, payable(address(0)), 0);
        pool.withdraw(a, b, c, root, keccak256("n-b"), recipient, payable(address(0)), 0);
        assertTrue(pool.nullifierHashes(keccak256("n-a")));
        assertTrue(pool.nullifierHashes(keccak256("n-b")));
    }

    function testFuzz_nullifierMarkedBeforeSecondCall(bytes32 nullifierHash) public {
        vm.assume(nullifierHash != bytes32(0));
        // Liquidez: un deposit extra por fuzz run puede agotar el arbol; usar pool fresco
        PrivacyPool local = new PrivacyPool(LEVELS, new MockHasher(), verifier, DENOMINATION);
        local.deposit{value: DENOMINATION}(keccak256(abi.encodePacked("leaf", nullifierHash)));
        bytes32 root = local.currentRoot();

        local.withdraw(a, b, c, root, nullifierHash, recipient, payable(address(0)), 0);
        assertTrue(local.nullifierHashes(nullifierHash));

        vm.expectRevert(PrivacyErrors.NullifierAlreadySpent.selector);
        local.withdraw(a, b, c, root, nullifierHash, recipient, payable(address(0)), 0);
    }
}

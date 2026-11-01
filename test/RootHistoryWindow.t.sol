// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";

import {PrivacyPool} from "../src/PrivacyPool.sol";
import {PrivacyErrors} from "../src/errors/PrivacyErrors.sol";
import {MockHasher} from "../src/mocks/MockHasher.sol";
import {MockVerifier} from "../src/mocks/MockVerifier.sol";

/**
 * @title RootHistoryWindowTest
 * @notice Ventana de raices historicas: una root sobrevive 29 deposits posteriores
 *         y se expulsa en el 30; el withdraw se recupera regenerando la proof.
 * @dev LEVELS = 6 (64 hojas): con depth 4 (16 hojas) el ring de 30 nunca rota.
 *      MockVerifier basta porque `isKnownRoot` se evalua antes de `verifyProof`.
 */
contract RootHistoryWindowTest is Test {
    uint32 internal constant LEVELS = 6;
    uint256 internal constant DENOMINATION = 0.1 ether;

    PrivacyPool internal pool;
    uint32 internal historySize;
    uint256 internal leafCounter;

    uint256[2] internal a;
    uint256[2][2] internal b;
    uint256[2] internal c;
    address payable internal recipient = payable(address(0xA11CE));
    bytes32 internal constant NULLIFIER = keccak256("patient-user");

    function setUp() public {
        pool = new PrivacyPool(LEVELS, new MockHasher(), new MockVerifier(), DENOMINATION);
        historySize = pool.ROOT_HISTORY_SIZE();
        a = [uint256(1), 1];
        b = [[uint256(1), 1], [uint256(1), 1]];
        c = [uint256(1), 1];
    }

    function _deposit(uint256 n) internal {
        for (uint256 i; i < n; ++i) {
            pool.deposit{value: DENOMINATION}(keccak256(abi.encode("leaf", leafCounter++)));
        }
    }

    function _withdraw(bytes32 root) internal {
        pool.withdraw(a, b, c, root, NULLIFIER, recipient, payable(address(0)), 0);
    }

    function test_rootHistorySize_is30() public view {
        assertEq(historySize, 30);
    }

    function test_root_survives_29LaterDeposits() public {
        _deposit(1);
        bytes32 userRoot = pool.currentRoot();

        _deposit(historySize - 1);

        assertTrue(pool.isKnownRoot(userRoot));
        _withdraw(userRoot);
        assertTrue(pool.nullifierHashes(NULLIFIER));
        assertEq(recipient.balance, DENOMINATION);
    }

    function test_root_evicted_after30LaterDeposits() public {
        _deposit(1);
        bytes32 userRoot = pool.currentRoot();

        _deposit(historySize);

        assertFalse(pool.isKnownRoot(userRoot));
        vm.expectRevert(PrivacyErrors.UnknownRoot.selector);
        _withdraw(userRoot);
        assertFalse(pool.nullifierHashes(NULLIFIER));
    }

    function test_evictedRoot_recovers_withProofAgainstCurrentRoot() public {
        _deposit(1);
        bytes32 userRoot = pool.currentRoot();
        _deposit(historySize);

        vm.expectRevert(PrivacyErrors.UnknownRoot.selector);
        _withdraw(userRoot);

        bytes32 freshRoot = pool.currentRoot();
        assertTrue(pool.isKnownRoot(freshRoot));
        _withdraw(freshRoot);

        assertTrue(pool.nullifierHashes(NULLIFIER));
        assertEq(recipient.balance, DENOMINATION);
    }

    function testFuzz_rootKnown_iffFewerThan30LaterDeposits(uint256 laterDeposits) public {
        laterDeposits = bound(laterDeposits, 0, 2 * historySize);
        _deposit(1);
        bytes32 userRoot = pool.currentRoot();

        _deposit(laterDeposits);

        assertEq(pool.isKnownRoot(userRoot), laterDeposits < historySize);
    }
}

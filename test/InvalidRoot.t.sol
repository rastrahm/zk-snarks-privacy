// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";

import {PrivacyPool} from "../src/PrivacyPool.sol";
import {PrivacyErrors} from "../src/errors/PrivacyErrors.sol";
import {MockHasher} from "../src/mocks/MockHasher.sol";
import {MockVerifier} from "../src/mocks/MockVerifier.sol";

/**
 * @title InvalidRootTest
 * @notice Fase 6: withdraw con raiz desconocida / cero.
 */
contract InvalidRootTest is Test {
    uint32 internal constant LEVELS = 4;
    uint256 internal constant DENOMINATION = 0.1 ether;

    PrivacyPool internal pool;

    uint256[2] internal a;
    uint256[2][2] internal b;
    uint256[2] internal c;
    address payable internal recipient = payable(address(0xA11CE));

    function setUp() public {
        pool = new PrivacyPool(LEVELS, new MockHasher(), new MockVerifier(), DENOMINATION);
        pool.deposit{value: DENOMINATION}(keccak256("c0"));
        a[0] = 1;
        a[1] = 1;
        b[0][0] = 1;
        b[0][1] = 1;
        b[1][0] = 1;
        b[1][1] = 1;
        c[0] = 1;
        c[1] = 1;
    }

    function test_unknownRoot_reverts() public {
        vm.expectRevert(PrivacyErrors.UnknownRoot.selector);
        pool.withdraw(
            a, b, c, keccak256("forged-root"), keccak256("n"), recipient, payable(address(0)), 0
        );
    }

    function test_zeroRoot_reverts() public {
        vm.expectRevert(PrivacyErrors.UnknownRoot.selector);
        pool.withdraw(a, b, c, bytes32(0), keccak256("n"), recipient, payable(address(0)), 0);
    }

    function test_staleRoot_stillValid_afterNewDeposit() public {
        bytes32 stale = pool.currentRoot();
        pool.deposit{value: DENOMINATION}(keccak256("c1"));
        assertTrue(pool.isKnownRoot(stale));
        pool.withdraw(a, b, c, stale, keccak256("n-stale"), recipient, payable(address(0)), 0);
        assertTrue(pool.nullifierHashes(keccak256("n-stale")));
    }

    function testFuzz_randomUnknownRoot_reverts(bytes32 forged) public {
        vm.assume(forged != bytes32(0));
        vm.assume(!pool.isKnownRoot(forged));
        vm.expectRevert(PrivacyErrors.UnknownRoot.selector);
        pool.withdraw(a, b, c, forged, keccak256("n"), recipient, payable(address(0)), 0);
    }
}

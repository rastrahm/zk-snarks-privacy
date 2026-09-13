// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";

import {PrivacyPool} from "../src/PrivacyPool.sol";
import {PrivacyErrors} from "../src/errors/PrivacyErrors.sol";
import {MockHasher} from "../src/mocks/MockHasher.sol";
import {MockVerifier} from "../src/mocks/MockVerifier.sol";
import {RejectETH} from "../src/mocks/RejectETH.sol";

/**
 * @title RelayerFeeTest
 * @notice Fase 6: split exacto recipient / relayer y edge cases de fee.
 */
contract RelayerFeeTest is Test {
    uint32 internal constant LEVELS = 4;
    uint256 internal constant DENOMINATION = 0.1 ether;

    PrivacyPool internal pool;

    uint256[2] internal a;
    uint256[2][2] internal b;
    uint256[2] internal c;

    address payable internal recipient = payable(address(0xA11CE));
    address payable internal relayer = payable(address(0xB0B));

    function setUp() public {
        pool = new PrivacyPool(LEVELS, new MockHasher(), new MockVerifier(), DENOMINATION);
        a[0] = 1;
        a[1] = 1;
        b[0][0] = 1;
        b[0][1] = 1;
        b[1][0] = 1;
        b[1][1] = 1;
        c[0] = 1;
        c[1] = 1;
    }

    function _fundOne() internal returns (bytes32 root) {
        pool.deposit{value: DENOMINATION}(keccak256(abi.encodePacked(pool.nextIndex())));
        return pool.currentRoot();
    }

    function test_feeSplit_exactBalances() public {
        bytes32 root = _fundOne();
        uint256 fee = 0.025 ether;
        uint256 rBefore = recipient.balance;
        uint256 lBefore = relayer.balance;

        pool.withdraw(a, b, c, root, keccak256("fee-1"), recipient, relayer, fee);

        assertEq(recipient.balance - rBefore, DENOMINATION - fee);
        assertEq(relayer.balance - lBefore, fee);
        assertEq(address(pool).balance, 0);
    }

    function test_zeroFee_fullToRecipient() public {
        bytes32 root = _fundOne();
        uint256 rBefore = recipient.balance;
        pool.withdraw(a, b, c, root, keccak256("fee-0"), recipient, payable(address(0)), 0);
        assertEq(recipient.balance - rBefore, DENOMINATION);
    }

    function test_maxFee_allToRelayer() public {
        bytes32 root = _fundOne();
        uint256 lBefore = relayer.balance;
        uint256 rBefore = recipient.balance;
        pool.withdraw(a, b, c, root, keccak256("fee-max"), recipient, relayer, DENOMINATION);
        assertEq(recipient.balance - rBefore, 0);
        assertEq(relayer.balance - lBefore, DENOMINATION);
    }

    function test_feeExceedsDenomination_reverts() public {
        bytes32 root = _fundOne();
        vm.expectRevert(PrivacyErrors.FeeExceedsDenomination.selector);
        pool.withdraw(a, b, c, root, keccak256("fee-x"), recipient, relayer, DENOMINATION + 1);
    }

    function test_feeWithoutRelayer_reverts() public {
        bytes32 root = _fundOne();
        vm.expectRevert(PrivacyErrors.ZeroAddress.selector);
        pool.withdraw(a, b, c, root, keccak256("fee-nr"), recipient, payable(address(0)), 1 wei);
    }

    function test_relayerRejectsEth_reverts() public {
        bytes32 root = _fundOne();
        RejectETH badRelayer = new RejectETH();
        vm.expectRevert(PrivacyErrors.EthTransferFailed.selector);
        pool.withdraw(
            a, b, c, root, keccak256("fee-rej"), recipient, payable(address(badRelayer)), 0.01 ether
        );
    }

    function testFuzz_feeSplit(uint256 fee) public {
        fee = bound(fee, 0, DENOMINATION);
        address payable rel = fee == 0 ? payable(address(0)) : relayer;
        bytes32 root = _fundOne();

        uint256 rBefore = recipient.balance;
        uint256 lBefore = relayer.balance;

        pool.withdraw(a, b, c, root, keccak256(abi.encodePacked("fuzz", fee)), recipient, rel, fee);

        assertEq(recipient.balance - rBefore, DENOMINATION - fee);
        if (fee > 0) {
            assertEq(relayer.balance - lBefore, fee);
        }
    }
}

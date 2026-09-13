// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";

import {PrivacyErrors} from "../src/errors/PrivacyErrors.sol";

/**
 * @title PrivacyErrorsTest
 * @notice Smoke de selectores de errores custom (Fase 1).
 */
contract PrivacyErrorsTest is Test {
    function test_errorSelectors_distinct() public pure {
        bytes4[10] memory selectors = [
            PrivacyErrors.NullifierAlreadySpent.selector,
            PrivacyErrors.InvalidZKProof.selector,
            PrivacyErrors.UnknownRoot.selector,
            PrivacyErrors.InvalidCommitment.selector,
            PrivacyErrors.TreeFull.selector,
            PrivacyErrors.FeeExceedsDenomination.selector,
            PrivacyErrors.EthTransferFailed.selector,
            PrivacyErrors.ZeroAddress.selector,
            PrivacyErrors.InvalidDenomination.selector,
            PrivacyErrors.Unauthorized.selector
        ];

        for (uint256 i = 0; i < selectors.length; ++i) {
            assertTrue(selectors[i] != bytes4(0));
            for (uint256 j = i + 1; j < selectors.length; ++j) {
                assertTrue(selectors[i] != selectors[j]);
            }
        }
    }
}

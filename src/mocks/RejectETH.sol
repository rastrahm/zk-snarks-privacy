// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/**
 * @title RejectETH
 * @notice Receptor que rechaza ETH (tests de EthTransferFailed).
 */
contract RejectETH {
    receive() external payable {
        revert();
    }

    fallback() external payable {
        revert();
    }
}

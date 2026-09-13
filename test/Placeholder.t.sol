// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {Placeholder} from "../src/Placeholder.sol";

/**
 * @title PlaceholderTest
 * @notice Smoke test de Fase 0: forge-std + OpenZeppelin remappings.
 */
contract PlaceholderTest is Test {
    Placeholder internal placeholder;

    function setUp() public {
        placeholder = new Placeholder();
    }

    function test_ping() public view {
        assertEq(placeholder.ping(17), 17);
        assertEq(keccak256(bytes(placeholder.MODULE())), keccak256(bytes("17-zk-snarks-privacy")));
    }

    function test_openzeppelinRemapping() public pure {
        // Compila el remapping @openzeppelin; el selector no se usa en runtime.
        assertTrue(IERC20.transfer.selector != bytes4(0));
    }

    function testFuzz_ping(uint256 value) public view {
        assertEq(placeholder.ping(value), value);
    }
}

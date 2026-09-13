// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Script, console2} from "forge-std/Script.sol";

import {PrivacyPool} from "../src/PrivacyPool.sol";
import {PoseidonHasher} from "../src/PoseidonHasher.sol";
import {Groth16Verifier} from "../src/verifiers/Groth16Verifier.sol";
import {IHasher} from "../src/interfaces/IHasher.sol";
import {IVerifier} from "../src/interfaces/IVerifier.sol";

/**
 * @title Deploy
 * @notice Despliega PoseidonHasher + Groth16Verifier + PrivacyPool (lab).
 * @dev Ejemplo Anvil:
 *      `forge script script/Deploy.s.sol:Deploy --rpc-url http://127.0.0.1:8545 --broadcast`
 *
 * Env:
 * - `PRIVATE_KEY` — deployer (default Anvil #0)
 * - `DENOMINATION_WEI` — default 0.1 ether
 * - `MERKLE_TREE_LEVELS` — default 4 (debe coincidir con el circuito)
 */
contract Deploy is Script {
    function run() external {
        uint256 pk =
            vm.envOr("PRIVATE_KEY", uint256(0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80));
        uint256 denomination = vm.envOr("DENOMINATION_WEI", uint256(0.1 ether));
        uint32 levels = uint32(vm.envOr("MERKLE_TREE_LEVELS", uint256(4)));

        vm.startBroadcast(pk);

        PoseidonHasher hasher = new PoseidonHasher();
        Groth16Verifier verifier = new Groth16Verifier();
        PrivacyPool pool = new PrivacyPool(levels, IHasher(address(hasher)), IVerifier(address(verifier)), denomination);

        console2.log("PoseidonHasher", address(hasher));
        console2.log("Groth16Verifier", address(verifier));
        console2.log("PrivacyPool", address(pool));
        console2.log("denomination", denomination);
        console2.log("levels", levels);

        vm.stopBroadcast();
    }
}

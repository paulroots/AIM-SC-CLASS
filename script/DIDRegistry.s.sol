// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {DIDRegistry} from "../src/DIDRegistry.sol";

/// @notice Deploys DIDRegistry. Run through `make deploy NETWORK=local CONTRACT=DIDRegistry`.
///         `make did STEP=setup` deploys it together with StatusList.
contract DIDRegistryScript is Script {
    function run() external returns (DIDRegistry registry) {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerKey);
        registry = new DIDRegistry();
        vm.stopBroadcast();

        console.log("DIDRegistry deployed at", address(registry));
    }
}

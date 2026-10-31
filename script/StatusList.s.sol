// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {DIDRegistry} from "../src/DIDRegistry.sol";
import {StatusList} from "../src/StatusList.sol";

/// @notice Deploys StatusList against an existing DIDRegistry, named by DID_REGISTRY.
///         `make did STEP=setup` passes it for you.
contract StatusListScript is Script {
    function run() external returns (StatusList status) {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        address registry = vm.envAddress("DID_REGISTRY");

        vm.startBroadcast(deployerKey);
        status = new StatusList(DIDRegistry(registry));
        vm.stopBroadcast();

        console.log("StatusList deployed at", address(status));
        console.log("Registry", registry);
    }
}

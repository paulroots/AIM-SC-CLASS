// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {__NAME__} from "../src/__NAME__.sol";

/// @notice Deploys __NAME__. Run with `make deploy NETWORK=local CONTRACT=__NAME__`.
contract __NAME__Script is Script {
    function run() external returns (__NAME__ deployed) {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerKey);
        deployed = new __NAME__("hello from __NAME__");
        vm.stopBroadcast();

        console.log("__NAME__ deployed at", address(deployed));
    }
}

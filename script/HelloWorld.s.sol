// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {HelloWorld} from "../src/HelloWorld.sol";

/// @notice Deploys HelloWorld. Run with `make deploy NETWORK=local CONTRACT=HelloWorld`.
contract HelloWorldScript is Script {
    function run() external returns (HelloWorld deployed) {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerKey);
        deployed = new HelloWorld("hello from HelloWorld");
        vm.stopBroadcast();

        console.log("HelloWorld deployed at", address(deployed));
    }
}

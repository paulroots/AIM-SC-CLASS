// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {Counter} from "../src/Counter.sol";

/// @notice Deploys Counter. Run through `make deploy NETWORK=local` or `make deploy NETWORK=prismo`.
/// @dev The same script serves every network. The network comes from `--rpc-url`, the signer
///      from the PRIVATE_KEY environment variable, and `--legacy` keeps Prismo happy.
contract CounterScript is Script {
    function run() external returns (Counter counter) {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        uint256 initial = vm.envOr("COUNTER_INITIAL", uint256(0));

        vm.startBroadcast(deployerKey);
        counter = new Counter(initial);
        vm.stopBroadcast();

        console.log("Counter deployed at", address(counter));
        console.log("Owner", counter.owner());
        console.log("Initial number", counter.number());
    }
}

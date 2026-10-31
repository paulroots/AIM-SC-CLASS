// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {HelloWorld} from "../src/HelloWorld.sol";

contract HelloWorldTest is Test {
    HelloWorld internal target;
    address internal deployer = makeAddr("deployer");

    event MessageChanged(address indexed by, string newMessage);

    function setUp() public {
        vm.prank(deployer);
        target = new HelloWorld("initial");
    }

    function test_constructor_storesInitialMessage() public view {
        assertEq(target.owner(), deployer);
        assertEq(target.message(), "initial");
    }

    function test_setMessage_updatesAndEmits() public {
        vm.expectEmit(true, false, false, true);
        emit MessageChanged(address(this), "updated");

        target.setMessage("updated");
        assertEq(target.message(), "updated");
    }
}

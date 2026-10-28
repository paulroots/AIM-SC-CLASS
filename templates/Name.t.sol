// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {__NAME__} from "../src/__NAME__.sol";

contract __NAME__Test is Test {
    __NAME__ internal target;
    address internal deployer = makeAddr("deployer");

    event MessageChanged(address indexed by, string newMessage);

    function setUp() public {
        vm.prank(deployer);
        target = new __NAME__("initial");
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

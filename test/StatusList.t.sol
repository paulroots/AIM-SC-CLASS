// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {DIDRegistry} from "../src/DIDRegistry.sol";
import {StatusList} from "../src/StatusList.sol";

/// @notice Tests for StatusList. Run with `forge test --match-contract StatusListTest -vv`.
contract StatusListTest is Test {
    DIDRegistry internal registry;
    StatusList internal status;

    address internal university = makeAddr("university");
    address internal newOwner = makeAddr("newOwner");
    address internal attacker = makeAddr("attacker");

    function setUp() public {
        registry = new DIDRegistry();
        status = new StatusList(registry);
    }

    function test_setRevoked_flipsTheBit() public {
        vm.prank(university);
        status.setRevoked(university, 1337, true);

        assertTrue(status.isRevoked(university, 1337));
        assertFalse(status.isRevoked(university, 1336));
    }

    function test_setRevoked_canReinstate() public {
        vm.startPrank(university);
        status.setRevoked(university, 7, true);
        status.setRevoked(university, 7, false);
        vm.stopPrank();

        assertFalse(status.isRevoked(university, 7));
    }

    function test_setRevoked_revertsForStranger() public {
        vm.expectRevert(abi.encodeWithSelector(StatusList.NotIssuer.selector, university, attacker));
        vm.prank(attacker);
        status.setRevoked(university, 7, true);
    }

    function test_setRevoked_followsTheRegistryController() public {
        vm.prank(university);
        registry.changeOwner(university, newOwner);

        vm.prank(newOwner);
        status.setRevoked(university, 7, true);
        assertTrue(status.isRevoked(university, 7));

        vm.expectRevert(abi.encodeWithSelector(StatusList.NotIssuer.selector, university, university));
        vm.prank(university);
        status.setRevoked(university, 8, true);
    }

    function testFuzz_setRevoked_touchesOnlyOneBit(uint256 index, uint256 other) public {
        vm.assume(index != other);
        vm.prank(university);
        status.setRevoked(university, index, true);

        assertTrue(status.isRevoked(university, index));
        assertFalse(status.isRevoked(university, other));
    }
}

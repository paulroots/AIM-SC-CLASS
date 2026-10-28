// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {Counter} from "../src/Counter.sol";

/// @notice Tests for Counter. Run with `forge test -vv`.
/// @dev Each test is one behaviour. Names read as sentences: test_<what>_<when>.
contract CounterTest is Test {
    Counter internal counter;

    address internal deployer = makeAddr("deployer");
    address internal student = makeAddr("student");

    /// @dev Re-declared so `vm.expectEmit` can compare against it.
    event NumberChanged(address indexed by, uint256 newValue);

    function setUp() public {
        vm.prank(deployer);
        counter = new Counter(10);
    }

    function test_constructor_setsOwnerAndInitialNumber() public view {
        assertEq(counter.owner(), deployer);
        assertEq(counter.number(), 10);
    }

    function test_increment_addsOne() public {
        counter.increment();
        assertEq(counter.number(), 11);
    }

    function test_increment_emitsEvent() public {
        vm.expectEmit(true, false, false, true);
        emit NumberChanged(student, 11);

        vm.prank(student);
        counter.increment();
    }

    function test_decrement_subtractsOne() public {
        counter.decrement();
        assertEq(counter.number(), 9);
    }

    function test_decrement_revertsAtZero() public {
        vm.prank(deployer);
        counter.setNumber(0);

        vm.expectRevert(Counter.Underflow.selector);
        counter.decrement();
    }

    function test_setNumber_ownerCanSet() public {
        vm.prank(deployer);
        counter.setNumber(42);
        assertEq(counter.number(), 42);
    }

    function test_setNumber_revertsForNonOwner() public {
        vm.prank(student);
        vm.expectRevert(abi.encodeWithSelector(Counter.NotOwner.selector, student));
        counter.setNumber(42);
    }

    /// @dev A fuzz test: Foundry calls this hundreds of times with random inputs.
    function testFuzz_setNumber_storesAnyValue(uint256 value) public {
        vm.prank(deployer);
        counter.setNumber(value);
        assertEq(counter.number(), value);
    }
}

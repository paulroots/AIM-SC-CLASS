// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {DIDRegistry} from "../src/DIDRegistry.sol";

/// @notice Tests for DIDRegistry. Run with `forge test --match-contract DIDRegistryTest -vv`.
contract DIDRegistryTest is Test {
    DIDRegistry internal registry;

    address internal university = makeAddr("university");
    address internal newKey = makeAddr("newKey");
    address internal attacker = makeAddr("attacker");
    bytes32 internal constant VERI_KEY = "veriKey";

    /// @dev Re-declared so `vm.expectEmit` can compare against them.
    event DIDOwnerChanged(address indexed identity, address owner, uint256 previousChange);
    event DIDDelegateChanged(
        address indexed identity, bytes32 delegateType, address delegate, uint256 validTo, uint256 previousChange
    );

    function setUp() public {
        registry = new DIDRegistry();
    }

    function test_identityOwner_defaultsToItself() public view {
        assertEq(registry.identityOwner(university), university);
    }

    function test_changeOwner_movesControl() public {
        vm.prank(university);
        registry.changeOwner(university, newKey);

        assertEq(registry.identityOwner(university), newKey);
    }

    function test_changeOwner_revertsForStranger() public {
        vm.expectRevert(abi.encodeWithSelector(DIDRegistry.NotOwner.selector, university, attacker));
        vm.prank(attacker);
        registry.changeOwner(university, attacker);
    }

    function test_changeOwner_oldOwnerLosesControl() public {
        vm.prank(university);
        registry.changeOwner(university, newKey);

        vm.expectRevert(abi.encodeWithSelector(DIDRegistry.NotOwner.selector, university, university));
        vm.prank(university);
        registry.changeOwner(university, university);
    }

    function test_addDelegate_isValidUntilExpiry() public {
        vm.prank(university);
        registry.addDelegate(university, VERI_KEY, newKey, 1 days);
        assertTrue(registry.validDelegate(university, VERI_KEY, newKey));

        vm.warp(block.timestamp + 1 days);
        assertFalse(registry.validDelegate(university, VERI_KEY, newKey));
    }

    function test_revokeDelegate_endsValidityNow() public {
        vm.startPrank(university);
        registry.addDelegate(university, VERI_KEY, newKey, 1 days);
        registry.revokeDelegate(university, VERI_KEY, newKey);
        vm.stopPrank();

        assertFalse(registry.validDelegate(university, VERI_KEY, newKey));
    }

    function test_events_linkToThePreviousChange() public {
        vm.roll(100);
        vm.prank(university);
        registry.addDelegate(university, VERI_KEY, newKey, 1 days);

        // The second change points back at block 100, where the first one happened.
        vm.roll(250);
        vm.expectEmit(true, false, false, true);
        emit DIDOwnerChanged(university, newKey, 100);
        vm.prank(university);
        registry.changeOwner(university, newKey);

        assertEq(registry.changed(university), 250);
    }
}

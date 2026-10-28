// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/// @title Counter
/// @notice The first contract in the course. One number, three ways to change it, one event.
/// @dev Read this top to bottom. Every line is something you will use again.
contract Counter {
    /// @notice The address that deployed the contract. Only it may reset the number.
    address public immutable owner;

    /// @notice The single piece of state this contract keeps.
    uint256 public number;

    /// @notice Emitted every time `number` changes. The dApp listens for this.
    /// @param by The account that made the change.
    /// @param newValue The value of `number` after the change.
    event NumberChanged(address indexed by, uint256 newValue);

    /// @dev Custom errors are cheaper than revert strings and show up by name in the explorer.
    error NotOwner(address caller);
    error Underflow();

    /// @param initial The starting value of `number`.
    constructor(uint256 initial) {
        owner = msg.sender;
        number = initial;
    }

    /// @notice Add one to the number. Anyone can call this.
    function increment() external {
        number += 1;
        emit NumberChanged(msg.sender, number);
    }

    /// @notice Subtract one from the number. Reverts at zero so the state can never wrap.
    function decrement() external {
        if (number == 0) revert Underflow();
        number -= 1;
        emit NumberChanged(msg.sender, number);
    }

    /// @notice Set the number directly. Only the owner may do this.
    /// @param newValue The value to store.
    function setNumber(uint256 newValue) external {
        if (msg.sender != owner) revert NotOwner(msg.sender);
        number = newValue;
        emit NumberChanged(msg.sender, newValue);
    }
}

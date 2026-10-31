// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/// @title HelloWorld
/// @notice Describe what this contract is for in one sentence.
contract HelloWorld {
    address public immutable owner;
    string public message;

    event MessageChanged(address indexed by, string newMessage);

    error NotOwner(address caller);

    constructor(string memory initialMessage) {
        owner = msg.sender;
        message = initialMessage;
    }

    /// @notice Replace the stored message. Anyone can call this.
    function setMessage(string calldata newMessage) external {
        message = newMessage;
        emit MessageChanged(msg.sender, newMessage);
    }
}

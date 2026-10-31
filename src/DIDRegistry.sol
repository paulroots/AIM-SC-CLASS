// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/// @title DIDRegistry
/// @notice A teaching copy of the ERC-1056 registry that backs did:ethr identifiers.
/// @dev Every Ethereum address is already a DID: did:ethr:<chainId>:<address>. Nothing has to be
///      written here until the identity changes its controller or adds a key. Function and event
///      signatures match ERC-1056, so a standard did:ethr resolver can read this contract.
///      The meta-transaction (signed) variants and attributes of the full registry are left out.
contract DIDRegistry {
    /// @notice Controller of an identity, if it was ever changed. Zero means "the identity itself".
    mapping(address identity => address owner) public owners;

    /// @notice Expiry time of each delegate key, by identity and delegate type.
    mapping(address identity => mapping(bytes32 delegateType => mapping(address delegate => uint256 validTo)))
        public delegates;

    /// @notice Block number of the last change to an identity. Each event points at the previous
    ///         one, so a resolver can walk an identity's history backwards, block by block.
    mapping(address identity => uint256 blockNumber) public changed;

    event DIDOwnerChanged(address indexed identity, address owner, uint256 previousChange);
    event DIDDelegateChanged(
        address indexed identity, bytes32 delegateType, address delegate, uint256 validTo, uint256 previousChange
    );

    error NotOwner(address identity, address caller);

    modifier onlyOwner(address identity) {
        if (msg.sender != identityOwner(identity)) revert NotOwner(identity, msg.sender);
        _;
    }

    /// @notice The address that controls `identity`. By default an identity controls itself.
    function identityOwner(address identity) public view returns (address) {
        address owner = owners[identity];
        return owner == address(0) ? identity : owner;
    }

    /// @notice True while `delegate` is an unexpired key of type `delegateType` for `identity`.
    function validDelegate(address identity, bytes32 delegateType, address delegate) external view returns (bool) {
        return delegates[identity][delegateType][delegate] > block.timestamp;
    }

    /// @notice Hand control of `identity` to `newOwner`. Use this to recover from a lost or stolen key.
    function changeOwner(address identity, address newOwner) external onlyOwner(identity) {
        owners[identity] = newOwner;
        emit DIDOwnerChanged(identity, newOwner, changed[identity]);
        changed[identity] = block.number;
    }

    /// @notice Add a key that may act for `identity` for `validity` seconds. Key rotation is: add the
    ///         new key, then revoke the old one.
    function addDelegate(address identity, bytes32 delegateType, address delegate, uint256 validity)
        external
        onlyOwner(identity)
    {
        uint256 validTo = block.timestamp + validity;
        delegates[identity][delegateType][delegate] = validTo;
        emit DIDDelegateChanged(identity, delegateType, delegate, validTo, changed[identity]);
        changed[identity] = block.number;
    }

    /// @notice Stop `delegate` acting for `identity`, effective now.
    function revokeDelegate(address identity, bytes32 delegateType, address delegate) external onlyOwner(identity) {
        delegates[identity][delegateType][delegate] = block.timestamp;
        emit DIDDelegateChanged(identity, delegateType, delegate, block.timestamp, changed[identity]);
        changed[identity] = block.number;
    }
}

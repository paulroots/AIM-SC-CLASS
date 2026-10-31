// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {DIDRegistry} from "./DIDRegistry.sol";

/// @title StatusList
/// @notice Revocation for verifiable credentials: one long bitstring per issuer, one bit per credential.
/// @dev The idea behind W3C Bitstring Status List, kept on chain for the demo. A credential names its
///      issuer and an index; the bit at that index is 1 once revoked. Verifiers read whole 256-bit
///      words, and many credentials share each word, so a check does not single out one holder.
///      Only the current controller of the issuer's DID, as recorded in the registry, may flip bits.
contract StatusList {
    /// @notice The DID registry that decides who controls an issuer.
    DIDRegistry public immutable registry;

    /// @notice The bitstring, stored 256 bits per word.
    mapping(address issuer => mapping(uint256 word => uint256 bits)) public words;

    event StatusChanged(address indexed issuer, uint256 indexed index, bool revoked);

    error NotIssuer(address issuer, address caller);

    constructor(DIDRegistry registry_) {
        registry = registry_;
    }

    /// @notice Revoke (or reinstate) the credential at `index` issued by `issuer`.
    function setRevoked(address issuer, uint256 index, bool revoked) external {
        if (registry.identityOwner(issuer) != msg.sender) revert NotIssuer(issuer, msg.sender);
        uint256 bit = 1 << (index % 256);
        if (revoked) words[issuer][index / 256] |= bit;
        else words[issuer][index / 256] &= ~bit;
        emit StatusChanged(issuer, index, revoked);
    }

    /// @notice True if the credential at `index` issued by `issuer` has been revoked.
    function isRevoked(address issuer, uint256 index) external view returns (bool) {
        return words[issuer][index / 256] & (1 << (index % 256)) != 0;
    }
}

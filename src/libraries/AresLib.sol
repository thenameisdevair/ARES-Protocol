// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title AresLib - Pure helper functions for ARES Protocol
/// @notice Stateless utility library. Used by SigVerifier and MerkleDistributor.
library AresLib {

    /// @notice Build EIP-712 struct hash from proposal fields
    /// @dev Used by SigVerifier — keeps hash logic in one auditable place
    function buildProposalStructHash(
        bytes32 typehash,
        uint256 id,
        address to,
        uint256 amount,
        bytes memory data,
        uint256 nonce
    ) internal pure returns (bytes32) {
        return keccak256(
            abi.encode(typehash, id, to, amount, keccak256(data), nonce)
        );
    }

    /// @notice Build Merkle leaf from contributor address and amount
    /// @dev Used by MerkleDistributor — consistent leaf encoding
    function buildMerkleLeaf(
        address contributor,
        uint256 amount
    ) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(contributor, amount));
    }
}

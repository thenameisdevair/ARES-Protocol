// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title IMerkleDistributor - Contributor Reward Distribution Interface
interface IMerkleDistributor {
    event RewardClaimed(address indexed contributor, uint256 amount, uint256 window);
    event MerkleRootUpdated(bytes32 newRoot, uint256 newWindow);

    /// @notice Claim reward using Merkle proof
    function claim(address contributor, uint256 amount, bytes32[] calldata merkleProof) external;

    /// @notice Update Merkle root — opens new claim window — only multisig
    function updateMerkleRoot(bytes32 newRoot) external;

    function hasClaimed(address contributor) external view returns (bool);
    function getMerkleRoot() external view returns (bytes32);
    function getCurrentWindow() external view returns (uint256);
}

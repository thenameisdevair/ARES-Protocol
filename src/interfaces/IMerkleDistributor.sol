// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;


interface IMerkleDistributor {
    event RewardClaimed(address indexed contributor, uint256 amount, uint256 window);
    event MerkleRootUpdated(bytes32 newRoot, uint256 newWindow);

 
    function claim(address contributor, uint256 amount, bytes32[] calldata merkleProof) external;

    
    function updateMerkleRoot(bytes32 newRoot) external;

    function hasClaimed(address contributor) external view returns (bool);
    function getMerkleRoot() external view returns (bytes32);
    function getCurrentWindow() external view returns (uint256);
}

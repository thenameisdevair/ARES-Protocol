// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;


interface IAresProtocol {
    event ProposalSubmitted(uint256 indexed proposalId, address indexed proposer);
    event ProposalConfirmed(uint256 indexed proposalId, address indexed owner);
    event ProposalQueued(uint256 indexed proposalId);
    event ProposalExecuted(uint256 indexed proposalId);
    event RewardClaimed(address indexed contributor, uint256 amount);

   
    function submitProposal(address to, uint256 amount, bytes calldata data) external returns (uint256 proposalId);

    
    function confirmProposal(uint256 proposalId, bytes calldata signature) external;

   
    function queueProposal(uint256 proposalId) external;

    
    function executeProposal(uint256 proposalId) external;

  
    function deposit(uint256 amount) external;

   
    function claimReward(address contributor, uint256 amount, bytes32[] calldata merkleProof) external;

    function isExecutable(uint256 proposalId) external view returns (bool);
    function isPaused() external view returns (bool);
}

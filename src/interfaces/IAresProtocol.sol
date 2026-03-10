// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title IAresProtocol - System Coordinator Entry Point Interface
interface IAresProtocol {
    event ProposalSubmitted(uint256 indexed proposalId, address indexed proposer);
    event ProposalConfirmed(uint256 indexed proposalId, address indexed owner);
    event ProposalQueued(uint256 indexed proposalId);
    event ProposalExecuted(uint256 indexed proposalId);
    event RewardClaimed(address indexed contributor, uint256 amount);

    /// @notice Submit a new treasury transaction proposal — only owners
    function submitProposal(address to, uint256 amount, bytes calldata data) external returns (uint256 proposalId);

    /// @notice Confirm a proposal with EIP-712 signature
    function confirmProposal(uint256 proposalId, bytes calldata signature) external;

    /// @notice Move proposal to queue once threshold reached
    function queueProposal(uint256 proposalId) external;

    /// @notice Execute proposal after 24hr timelock
    function executeProposal(uint256 proposalId) external;

    /// @notice Deposit ERC20 tokens into treasury
    function deposit(uint256 amount) external;

    /// @notice Claim contributor reward via Merkle proof
    function claimReward(address contributor, uint256 amount, bytes32[] calldata merkleProof) external;

    function isExecutable(uint256 proposalId) external view returns (bool);
    function isPaused() external view returns (bool);
}

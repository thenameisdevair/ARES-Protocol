// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./IAresTypes.sol";

/// @title IQueue - Time-Delayed Execution Engine Interface
interface IQueue {
    event ProposalCreated(uint256 indexed proposalId, address indexed proposer);
    event ProposalQueued(uint256 indexed proposalId, uint256 unlockTimestamp);
    event ProposalExecuted(uint256 indexed proposalId);
    event ProposalCancelled(uint256 indexed proposalId);

    /// @notice Create a new proposal — registers it in MultisigAuth
    function createProposal(address to, uint256 amount, bytes calldata data) external returns (uint256 proposalId);

    /// @notice Move proposal to queue once threshold is reached — starts 24hr timelock
    function queueProposal(uint256 proposalId) external;

    /// @notice Execute after timelock — nonce incremented before execution
    function executeProposal(uint256 proposalId) external;

    /// @notice Cancel a pending or queued proposal
    function cancelProposal(uint256 proposalId) external;

    function getProposal(uint256 proposalId) external view returns (Proposal memory);
    function isExecutable(uint256 proposalId) external view returns (bool);
    function getNonce() external view returns (uint256);
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "src/interfaces/IAresTypes.sol";


interface IQueue {
    event ProposalCreated(uint256 indexed proposalId, address indexed proposer);
    event ProposalQueued(uint256 indexed proposalId, uint256 unlockTimestamp);
    event ProposalExecuted(uint256 indexed proposalId);
    event ProposalCancelled(uint256 indexed proposalId);

   
    function createProposal(address to, uint256 amount, bytes calldata data) external returns (uint256 proposalId);

    
    function queueProposal(uint256 proposalId) external;

    function executeProposal(uint256 proposalId) external;


    function cancelProposal(uint256 proposalId) external;

    function getProposal(uint256 proposalId) external view returns (IAresTypes.Proposal memory);
    function isExecutable(uint256 proposalId) external view returns (bool);
    function getNonce() external view returns (uint256);
}

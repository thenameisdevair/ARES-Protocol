// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./interfaces/IQueue.sol";
import "./interfaces/IVault.sol";
import "./interfaces/IMultisigAuth.sol";
import "./interfaces/IGuard.sol";
import "./interfaces/IAresTypes.sol";

/// @title Queue - Time-Delayed Execution Engine
/// @notice Manages proposal lifecycle. Enforces 24hr timelock before execution.
/// @dev Nonce incremented before execution — prevents replay and reentrancy via state reuse.
contract Queue is IQueue, ReentrancyGuard {
    IVault public vault;
    IMultisigAuth public multisigAuth;
    IGuard public guard;

    uint256 public constant TIMELOCK_DURATION = 24 hours;

    // Global nonce — incremented before each execution
    uint256 public nonce;

    // proposalId => Proposal
    mapping(uint256 => Proposal) public proposals;
    uint256 public proposalCount;

    modifier onlyOwner() {
        require(multisigAuth.isOwner(msg.sender), "Queue: not owner");
        _;
    }

    modifier notPaused() {
        require(!guard.isPaused(), "Queue: system paused");
        _;
    }

    constructor(address _vault, address _multisigAuth, address _guard) {
        vault = IVault(_vault);
        multisigAuth = IMultisigAuth(_multisigAuth);
        guard = IGuard(_guard);
    }

    /// @notice Create a new proposal — registers it in MultisigAuth for signing
    function createProposal(
        address to,
        uint256 amount,
        bytes calldata data
    ) external onlyOwner notPaused returns (uint256 proposalId) {
        proposalId = proposalCount++;

        proposals[proposalId] = Proposal({
            id: proposalId,
            to: to,
            amount: amount,
            data: data,
            status: ProposalStatus.Pending,
            submissionTime: block.timestamp,
            unlockTimestamp: 0,
            confirmations: 0,
            isVerified: false,
            nonce: nonce
        });

        // Register in MultisigAuth — owners can now confirm
        multisigAuth.registerProposal(proposalId, to, amount, data, nonce);

        emit ProposalCreated(proposalId, msg.sender);
    }

    /// @notice Move proposal to queue once threshold is reached — starts 24hr timelock
    function queueProposal(uint256 proposalId) external onlyOwner notPaused {
        Proposal storage p = proposals[proposalId];

        require(p.status == ProposalStatus.Pending, "Queue: not pending");
        require(multisigAuth.isThresholdReached(proposalId), "Queue: threshold not reached");

        p.status = ProposalStatus.Queued;
        p.isVerified = true;
        p.confirmations = multisigAuth.getConfirmations(proposalId);
        p.unlockTimestamp = block.timestamp + TIMELOCK_DURATION;

        emit ProposalQueued(proposalId, p.unlockTimestamp);
    }

    /// @notice Execute proposal after 24hr timelock
    /// @dev Nonce incremented and status updated BEFORE external call — checks-effects-interactions
    function executeProposal(uint256 proposalId) external onlyOwner notPaused nonReentrant {
        Proposal storage p = proposals[proposalId];

        require(p.status == ProposalStatus.Queued, "Queue: not queued");
        require(p.isVerified, "Queue: not verified");
        require(block.timestamp >= p.unlockTimestamp, "Queue: timelock active");

        // Increment nonce BEFORE external call — replay and reentrancy protection
        nonce++;

        // Update state BEFORE releasing funds — checks-effects-interactions
        p.status = ProposalStatus.Executed;

        // Release funds from Vault
        vault.releaseFunds(p.to, p.amount);

        emit ProposalExecuted(proposalId);
    }

    /// @notice Cancel a pending or queued proposal
    function cancelProposal(uint256 proposalId) external onlyOwner {
        Proposal storage p = proposals[proposalId];
        require(
            p.status == ProposalStatus.Pending || p.status == ProposalStatus.Queued,
            "Queue: cannot cancel"
        );
        p.status = ProposalStatus.Cancelled;
        emit ProposalCancelled(proposalId);
    }

    function getProposal(uint256 proposalId) external view returns (Proposal memory) {
        return proposals[proposalId];
    }

    function isExecutable(uint256 proposalId) external view returns (bool) {
        Proposal memory p = proposals[proposalId];
        return (
            p.status == ProposalStatus.Queued &&
            p.isVerified &&
            block.timestamp >= p.unlockTimestamp
        );
    }

    function getNonce() external view returns (uint256) {
        return nonce;
    }
}

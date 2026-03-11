// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "src/interfaces/IQueue.sol";
import "src/interfaces/IVault.sol";
import "src/interfaces/IMultisigAuth.sol";
import "src/interfaces/IGuard.sol";
import "src/interfaces/IAresTypes.sol";


contract Queue is IQueue, IAresTypes, ReentrancyGuard {
    IVault public vault;
    IMultisigAuth public multisigAuth;
    IGuard public guard;

    uint256 public constant TIMELOCK_DURATION = 24 hours;

    // Global nonce — incremented before each execution
    uint256 public nonce;

    // proposalId => Proposal
    mapping(uint256 => IAresTypes.Proposal) public proposals;
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

    // @notice Create a new proposal — registers it in MultisigAuth for signing
    function createProposal(
        address to,
        uint256 amount,
        bytes calldata data
    ) external onlyOwner notPaused returns (uint256 proposalId) {
        proposalId = proposalCount++;

        proposals[proposalId] = IAresTypes.Proposal({
            id: proposalId,
            to: to,
            amount: amount,
            data: data,
            status: IAresTypes.ProposalStatus.Pending,
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

 
    // @notice  Adds a proposal for queue ( this queuing phase helps mitiagate Timestamp mutation attack)
    function queueProposal(uint256 proposalId) external onlyOwner notPaused {
        IAresTypes.Proposal storage p = proposals[proposalId];

        require(p.status == IAresTypes.ProposalStatus.Pending, "Queue: not pending");
        require(multisigAuth.isThresholdReached(proposalId), "Queue: threshold not reached");

        p.status = IAresTypes.ProposalStatus.Queued;
        p.isVerified = true;
        p.confirmations = multisigAuth.getConfirmations(proposalId);
        p.unlockTimestamp = block.timestamp + TIMELOCK_DURATION;

        emit ProposalQueued(proposalId, p.unlockTimestamp);
    }

    // @notice This executes a queued proposal, after queing phase has been exhausted. 
    function executeProposal(uint256 proposalId) external onlyOwner notPaused nonReentrant {
        IAresTypes.Proposal storage p = proposals[proposalId];

        require(p.status == IAresTypes.ProposalStatus.Queued, "Queue: not queued");
        require(p.isVerified, "Queue: not verified");
        require(block.timestamp >= p.unlockTimestamp, "Queue: timelock active");

        // Increment nonce BEFORE external call — replay and reentrancy protection
        nonce++;

        // Update state BEFORE releasing funds — checks-effects-interactions
        p.status = IAresTypes.ProposalStatus.Executed;

        // Release funds from Vault
        vault.releaseFunds(p.to, p.amount);

        emit ProposalExecuted(proposalId);
    }

    // @notice helps cancel proposal ( probablty mallicious ones, discovered during the queing period)
    function cancelProposal(uint256 proposalId) external onlyOwner {
        IAresTypes.Proposal storage p = proposals[proposalId];
        require(
            p.status == IAresTypes.ProposalStatus.Pending || p.status == IAresTypes.ProposalStatus.Queued,
            "Queue: cannot cancel"
        );
        p.status = IAresTypes.ProposalStatus.Cancelled;
        emit ProposalCancelled(proposalId);
    }

    function getProposal(uint256 proposalId) external view returns (IAresTypes.Proposal memory) {
        return proposals[proposalId];
    }

    function isExecutable(uint256 proposalId) external view returns (bool) {
        IAresTypes.Proposal memory p = proposals[proposalId];
        return (
            p.status == IAresTypes.ProposalStatus.Queued &&
            p.isVerified &&
            block.timestamp >= p.unlockTimestamp
        );
    }

    function getNonce() external view returns (uint256) {
        return nonce;
    }
}

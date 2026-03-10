// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "src/interfaces/IAresProtocol.sol";
import "src/interfaces/IQueue.sol";
import "src/interfaces/IMultisigAuth.sol";
import "src/interfaces/IMerkleDistributor.sol";
import "src/interfaces/IVault.sol";
import "src/interfaces/IGuard.sol";

/// @title AresProtocol - System Coordinator
/// @notice Single entry point for all user interactions. Delegates to specialized contracts.
/// @dev Users never interact with sub-contracts directly — all flow through here.
contract AresProtocol is IAresProtocol {
    IQueue public queue;
    IMultisigAuth public multisigAuth;
    IMerkleDistributor public merkleDistributor;
    IVault public vault;
    IGuard public guard;

    modifier notPaused() {
        require(!guard.isPaused(), "Ares: system paused");
        _;
    }

    constructor(
        address _queue,
        address _multisigAuth,
        address _merkleDistributor,
        address _vault,
        address _guard
    ) {
        queue = IQueue(_queue);
        multisigAuth = IMultisigAuth(_multisigAuth);
        merkleDistributor = IMerkleDistributor(_merkleDistributor);
        vault = IVault(_vault);
        guard = IGuard(_guard);
    }

    /// @notice Submit a new treasury transaction proposal — only owners
    function submitProposal(
        address to,
        uint256 amount,
        bytes calldata data
    ) external notPaused returns (uint256 proposalId) {
        proposalId = queue.createProposal(to, amount, data);
        emit ProposalSubmitted(proposalId, msg.sender);
    }

    /// @notice Confirm proposal with EIP-712 signature
    function confirmProposal(uint256 proposalId, bytes calldata signature) external notPaused {
        multisigAuth.confirmProposal(proposalId, signature);
        emit ProposalConfirmed(proposalId, msg.sender);
    }

    /// @notice Move proposal to queue once threshold reached
    function queueProposal(uint256 proposalId) external notPaused {
        queue.queueProposal(proposalId);
        emit ProposalQueued(proposalId);
    }

    /// @notice Execute proposal after 24hr timelock
    function executeProposal(uint256 proposalId) external notPaused {
        queue.executeProposal(proposalId);
        emit ProposalExecuted(proposalId);
    }

    /// @notice Deposit ERC20 tokens into treasury
    function deposit(uint256 amount) external notPaused {
        vault.deposit(amount);
    }

    /// @notice Claim contributor reward via Merkle proof
    function claimReward(
        address contributor,
        uint256 amount,
        bytes32[] calldata merkleProof
    ) external notPaused {
        merkleDistributor.claim(contributor, amount, merkleProof);
        emit RewardClaimed(contributor, amount);
    }

    function isExecutable(uint256 proposalId) external view returns (bool) {
        return queue.isExecutable(proposalId);
    }

    function isPaused() external view returns (bool) {
        return guard.isPaused();
    }
}

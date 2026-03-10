// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./interfaces/IMultisigAuth.sol";
import "./interfaces/ISigVerifier.sol";
import "./interfaces/IGuard.sol";

/// @title MultisigAuth - Owner Registry and Confirmation Tracking
/// @notice Immutable owner set set at deployment. Tracks confirmations per proposal.
/// @dev Removes SPOF — threshold of owners required before any proposal advances.
contract MultisigAuth is IMultisigAuth {
    ISigVerifier public sigVerifier;
    IGuard public guard;

    // Immutable owner set — cannot be changed after deployment
    mapping(address => bool) public isOwner;
    address[] public owners;
    uint256 public threshold;

    // proposalId => owner => hasConfirmed
    mapping(uint256 => mapping(address => bool)) public hasConfirmed;

    // proposalId => confirmation count
    mapping(uint256 => uint256) public confirmationCount;

    // Internal proposal data needed for signature verification
    struct ProposalData {
        address to;
        uint256 amount;
        bytes data;
        uint256 nonce;
        bool exists;
    }
    mapping(uint256 => ProposalData) private _proposalData;

    modifier onlyOwner() {
        require(isOwner[msg.sender], "MultisigAuth: not owner");
        _;
    }

    modifier notPaused() {
        require(!guard.isPaused(), "MultisigAuth: system paused");
        _;
    }

    /// @param _owners Immutable owner set
    /// @param _threshold Minimum confirmations required
    constructor(
        address[] memory _owners,
        uint256 _threshold,
        address _sigVerifier,
        address _guard
    ) {
        require(_threshold > 0, "MultisigAuth: zero threshold");
        require(_owners.length >= _threshold, "MultisigAuth: threshold exceeds owners");

        for (uint256 i = 0; i < _owners.length; i++) {
            require(_owners[i] != address(0), "MultisigAuth: zero address");
            require(!isOwner[_owners[i]], "MultisigAuth: duplicate owner");
            isOwner[_owners[i]] = true;
            owners.push(_owners[i]);
        }

        threshold = _threshold;
        sigVerifier = ISigVerifier(_sigVerifier);
        guard = IGuard(_guard);
    }

    /// @notice Register proposal data for confirmation tracking
    /// @dev Called by Queue when a proposal is created
    function registerProposal(
        uint256 proposalId,
        address to,
        uint256 amount,
        bytes calldata data,
        uint256 nonce
    ) external onlyOwner notPaused {
        require(!_proposalData[proposalId].exists, "MultisigAuth: already registered");
        _proposalData[proposalId] = ProposalData(to, amount, data, nonce, true);
    }

    /// @notice Confirm proposal with EIP-712 signature
    /// @dev Verifies signature via SigVerifier — recovered signer must match caller
    function confirmProposal(
        uint256 proposalId,
        bytes calldata signature
    ) external onlyOwner notPaused {
        require(_proposalData[proposalId].exists, "MultisigAuth: proposal not found");
        require(!hasConfirmed[proposalId][msg.sender], "MultisigAuth: already confirmed");

        ProposalData memory p = _proposalData[proposalId];

        // Verify EIP-712 signature — recovered signer must be the calling owner
        address recovered = sigVerifier.verifySignature(
            proposalId, p.to, p.amount, p.data, p.nonce, signature
        );
        require(recovered == msg.sender, "MultisigAuth: invalid signature");

        hasConfirmed[proposalId][msg.sender] = true;
        confirmationCount[proposalId]++;

        emit OwnerConfirmed(proposalId, msg.sender);

        if (confirmationCount[proposalId] >= threshold) {
            emit ThresholdReached(proposalId);
        }
    }

    function isThresholdReached(uint256 proposalId) external view returns (bool) {
        return confirmationCount[proposalId] >= threshold;
    }

    function getConfirmations(uint256 proposalId) external view returns (uint256) {
        return confirmationCount[proposalId];
    }

    function getThreshold() external view returns (uint256) {
        return threshold;
    }

    function getOwnerCount() external view returns (uint256) {
        return owners.length;
    }
}

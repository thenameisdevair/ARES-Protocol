// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "src/modules/SigVerifier.sol";
import "src/modules/Guard.sol";
import "src/interfaces/IMultisigAuth.sol";



contract MultisigAuth is IMultisigAuth {
    SigVerifier public sigVerifier;
    Guard public guard;

    // Immutable owner set — set at deployment, cannot be changed
    mapping(address => bool) public isOwner;
    address[] public owners;
    uint256 public threshold;

    // Tracks which owners have confirmed each proposal
    // proposalId => owner => hasConfirmed
    mapping(uint256 => mapping(address => bool)) public hasConfirmed;

    // Tracks total confirmations per proposal
    mapping(uint256 => uint256) public confirmationCount;

    // Tracks proposal data for signature verification
    // proposalId => (to, amount, data, nonce)
    mapping(uint256 => ProposalData) public proposalData;

    struct ProposalData {
        address to;
        uint256 amount;
        bytes data;
        uint256 nonce;
        bool exists;
    }

    function getThreshold() external view returns (uint256) {
        return threshold;
    }

    modifier onlyOwner() {
        require(isOwner[msg.sender], "MultisigAuth: not owner");
        _;
    }

    modifier notPaused() {
        require(!guard.isPaused(), "MultisigAuth: system paused");
        _;
    }

    constructor(
        address[] memory _owners,
        uint256 _threshold,
        address _sigVerifier,
        address _guard
    ) {
        require(_owners.length >= _threshold, "MultisigAuth: threshold exceeds owners");
        require(_threshold > 0, "MultisigAuth: threshold zero");

        for (uint256 i = 0; i < _owners.length; i++) {
            require(_owners[i] != address(0), "MultisigAuth: zero address owner");
            require(!isOwner[_owners[i]], "MultisigAuth: duplicate owner");
            isOwner[_owners[i]] = true;
            owners.push(_owners[i]);
        }

        threshold = _threshold;
        sigVerifier = SigVerifier(_sigVerifier);
        guard = Guard(_guard);
    }


    function registerProposal(
        uint256 proposalId,
        address to,
        uint256 amount,
        bytes calldata data,
        uint256 nonce
    ) external notPaused {
        require(!proposalData[proposalId].exists, "MultisigAuth: proposal exists");
        proposalData[proposalId] = ProposalData(to, amount, data, nonce, true);
    }


    function confirmProposal(
        uint256 proposalId,
        bytes calldata signature
    ) external onlyOwner notPaused {
        require(proposalData[proposalId].exists, "MultisigAuth: proposal not found");
        require(!hasConfirmed[proposalId][msg.sender], "MultisigAuth: already confirmed");

        ProposalData memory p = proposalData[proposalId];

        // Verify EIP-712 signature — recovers signer address
        address recovered = sigVerifier.verifySignature(
            proposalId, p.to, p.amount, p.data, p.nonce, signature
        );

        // Recovered signer must match the calling owner
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

    function getOwnerCount() external view returns (uint256) {
        return owners.length;
    }
}

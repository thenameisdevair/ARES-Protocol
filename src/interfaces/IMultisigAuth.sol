// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title IMultisigAuth - Owner Registry and Confirmation Tracking Interface
interface IMultisigAuth {
    event OwnerConfirmed(uint256 indexed proposalId, address indexed owner);
    event ThresholdReached(uint256 indexed proposalId);

    /// @notice Register a new proposal for confirmation tracking
    function registerProposal(
        uint256 proposalId,
        address to,
        uint256 amount,
        bytes calldata data,
        uint256 nonce
    ) external;

    /// @notice Confirm a proposal with EIP-712 signature
    function confirmProposal(uint256 proposalId, bytes calldata signature) external;

    function isOwner(address account) external view returns (bool);
    function getConfirmations(uint256 proposalId) external view returns (uint256);
    function isThresholdReached(uint256 proposalId) external view returns (bool);
    function getThreshold() external view returns (uint256);
    function getOwnerCount() external view returns (uint256);
}

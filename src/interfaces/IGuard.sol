// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title IGuard - Emergency Circuit Breaker Interface
interface IGuard {
    event Paused(address indexed triggeredBy);
    event Unpaused(address indexed triggeredBy);

    /// @notice Pause all protocol operations
    function pause() external;

    /// @notice Unpause protocol — only multisig
    function unpause() external;

    /// @notice Returns whether protocol is currently paused
    function isPaused() external view returns (bool);
}

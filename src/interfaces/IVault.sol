// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title IVault - ERC20 Treasury Storage Interface
interface IVault {
    event Deposited(address indexed contributor, uint256 amount);
    event FundsReleased(address indexed to, uint256 amount);
    event CircuitBreakerTriggered(address indexed to, uint256 amount);

    /// @notice Deposit ERC20 tokens into the treasury
    function deposit(uint256 amount) external;

    /// @notice Release funds — only callable by Queue
    function releaseFunds(address to, uint256 amount) external;

    /// @notice Set Queue address — callable once after deployment
    function setQueue(address _queue) external;

    function getBalance() external view returns (uint256);
    function getToken() external view returns (address);
    function getDrainThreshold() external view returns (uint256);
}

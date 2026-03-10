// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./interfaces/IVault.sol";
import "./interfaces/IGuard.sol";

/// @title Vault - ERC20 Treasury Storage
/// @notice Holds a single ERC20 token set at deployment. Releases funds only through Queue.
/// @dev Drain threshold triggers Guard circuit breaker to prevent large treasury drains.
contract Vault is IVault, ReentrancyGuard {
    IERC20 public immutable token;
    IGuard public guard;

    address public queue;           // Only Queue can release funds
    uint256 public drainThreshold;  // Max % releasable in one tx (e.g. 30 = 30%)

    modifier onlyQueue() {
        require(msg.sender == queue, "Vault: not queue");
        _;
    }

    modifier notPaused() {
        require(!guard.isPaused(), "Vault: system paused");
        _;
    }

    /// @param _token Single ERC20 token accepted — immutable after deployment
    /// @param _guard Circuit breaker contract
    /// @param _drainThreshold Percentage that triggers circuit breaker
    constructor(address _token, address _guard, uint256 _drainThreshold) {
        require(_token != address(0), "Vault: zero token");
        require(_drainThreshold > 0 && _drainThreshold < 100, "Vault: invalid threshold");
        token = IERC20(_token);
        guard = IGuard(_guard);
        drainThreshold = _drainThreshold;
    }

    /// @notice Set Queue address — callable only once after deployment
    function setQueue(address _queue) external {
        require(queue == address(0), "Vault: queue already set");
        require(_queue != address(0), "Vault: zero address");
        queue = _queue;
    }

    /// @notice Deposit ERC20 into treasury
    /// @dev Balance-delta check handles fee-on-transfer edge cases
    function deposit(uint256 amount) external notPaused nonReentrant {
        require(amount > 0, "Vault: zero amount");

        uint256 before = token.balanceOf(address(this));
        token.transferFrom(msg.sender, address(this), amount);

        // Delta check — actual received must match expected
        require(token.balanceOf(address(this)) - before == amount, "Vault: transfer mismatch");

        emit Deposited(msg.sender, amount);
    }

    /// @notice Release funds — only callable by Queue after timelock
    /// @dev Triggers Guard if release exceeds drain threshold — checks-effects-interactions
    function releaseFunds(address to, uint256 amount) external onlyQueue notPaused nonReentrant {
        require(to != address(0), "Vault: zero recipient");
        require(amount > 0, "Vault: zero amount");

        uint256 balance = token.balanceOf(address(this));
        require(balance >= amount, "Vault: insufficient balance");

        // Trigger circuit breaker if drain exceeds threshold
        if ((amount * 100) / balance > drainThreshold) {
            emit CircuitBreakerTriggered(to, amount);
            guard.pause();
            revert("Vault: drain threshold exceeded");
        }

        // Transfer after all checks — checks-effects-interactions
        token.transfer(to, amount);

        emit FundsReleased(to, amount);
    }

    function getBalance() external view returns (uint256) {
        return token.balanceOf(address(this));
    }

    function getToken() external view returns (address) {
        return address(token);
    }

    function getDrainThreshold() external view returns (uint256) {
        return drainThreshold;
    }
}

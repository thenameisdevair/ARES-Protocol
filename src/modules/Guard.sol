// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./interfaces/IGuard.sol";

/// @title Guard - Emergency Circuit Breaker
/// @notice Standalone pausable contract. Triggered by Vault on large drains or directly by multisig.
contract Guard is IGuard {
    bool private _paused;
    address public multisig;

    modifier onlyMultisig() {
        require(msg.sender == multisig, "Guard: not multisig");
        _;
    }

    /// @param _multisig Address authorized to pause and unpause
    constructor(address _multisig) {
        require(_multisig != address(0), "Guard: zero address");
        multisig = _multisig;
    }

    /// @notice Pause all protocol operations
    function pause() external onlyMultisig {
        _paused = true;
        emit Paused(msg.sender);
    }

    /// @notice Unpause protocol operations
    function unpause() external onlyMultisig {
        _paused = false;
        emit Unpaused(msg.sender);
    }

    function isPaused() external view returns (bool) {
        return _paused;
    }
}

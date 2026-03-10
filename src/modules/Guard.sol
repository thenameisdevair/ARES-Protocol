// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "src/interfaces/IGuard.sol";


contract Guard is IGuard {
    bool private _paused;
    address public multisig;

    modifier onlyMultisig() {
        require(msg.sender == multisig, "Guard: not multisig");
        _;
    }

    constructor(address _multisig) {
        require(_multisig != address(0), "Guard: zero address");
        multisig = _multisig;
    }

    function pause() external onlyMultisig {
        _paused = true;
        emit Paused(msg.sender);
    }

    function unpause() external onlyMultisig {
        _paused = false;
        emit Unpaused(msg.sender);
    }

    function isPaused() external view returns (bool) {
        return _paused;
    }
}

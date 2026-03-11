// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract Guard {
    bool private _paused;
    address public multisig;
    address public vault; // Vault authorized to trigger pause on drain threshold

    event Paused(address indexed triggeredBy);
    event Unpaused(address indexed triggeredBy);

   
    modifier onlyAuthorized() {
        require(msg.sender == multisig || msg.sender == vault, "Guard: not authorized");
        _;
    }

    modifier onlyMultisig() {
        require(msg.sender == multisig, "Guard: not multisig");
        _;
    }

    constructor(address _multisig) {
        require(_multisig != address(0), "Guard: zero address");
        multisig = _multisig;
    }


    function setVault(address _vault) external onlyMultisig {
        require(vault == address(0), "Guard: vault already set");
        require(_vault != address(0), "Guard: zero address");
        vault = _vault;
    }


    function pause() external onlyAuthorized {
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

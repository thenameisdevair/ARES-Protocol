// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;


interface IVault {
    event Deposited(address indexed contributor, uint256 amount);
    event FundsReleased(address indexed to, uint256 amount);
    event CircuitBreakerTriggered(address indexed to, uint256 amount);

  
    function deposit(uint256 amount) external;

 
    function releaseFunds(address to, uint256 amount) external;


    function setQueue(address _queue) external;

    function getBalance() external view returns (uint256);
    function getToken() external view returns (address);
    function getDrainThreshold() external view returns (uint256);
}

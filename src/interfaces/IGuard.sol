// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;


interface IGuard {
    event Paused(address indexed triggeredBy);
    event Unpaused(address indexed triggeredBy);

  
    function pause() external;

 
    function unpause() external;

 
    function isPaused() external view returns (bool);
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

abstract contract IAresTypes {
enum ProposalStatus {
    Pending,   // Submitted — awaiting confirmations
    Queued,    // Threshold reached — in timelock
    Executed,  // Successfully executed
    Cancelled  // Cancelled by owners
}

struct Proposal {
    uint256 id;
    address to;               // Recipient of funds
    uint256 amount;           // ERC20 amount to release
    bytes data;               // Optional calldata
    ProposalStatus status;
    uint256 submissionTime;   // When proposal was created
    uint256 unlockTimestamp;  // submissionTime + 24hrs — set when queued
    uint256 confirmations;    // Number of owner confirmations
    bool isVerified;          // True once threshold reached
    uint256 nonce;            // Replay protection — incremented before execution
}
}

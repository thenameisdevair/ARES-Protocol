// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;


interface ISigVerifier {

    function verifySignature(
        uint256 id,
        address to,
        uint256 amount,
        bytes calldata data,
        uint256 nonce,
        bytes calldata signature
    ) external view returns (address recoveredSigner);


    function getDomainSeparator() external view returns (bytes32);
}

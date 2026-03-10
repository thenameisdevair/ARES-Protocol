// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title ISigVerifier - EIP-712 Stateless Signature Verification Interface
interface ISigVerifier {
    /// @notice Verify EIP-712 signature — returns recovered signer address
    /// @dev MultisigAuth checks recovered address against owner registry
    function verifySignature(
        uint256 id,
        address to,
        uint256 amount,
        bytes calldata data,
        uint256 nonce,
        bytes calldata signature
    ) external view returns (address recoveredSigner);

    /// @notice Returns EIP-712 domain separator — bound to contractAddress + chainId
    function getDomainSeparator() external view returns (bytes32);
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import "src/interfaces/ISigVerifier.sol";
import "src/libraries/AresLib.sol";

contract SigVerifier is ISigVerifier, EIP712 {
    using ECDSA for bytes32;
    using AresLib for bytes32;

    /// @dev Typed data hash — must match exact proposal fields used in buildProposalStructHash
    bytes32 public constant PROPOSAL_TYPEHASH = keccak256(
        "Proposal(uint256 id,address to,uint256 amount,bytes data,uint256 nonce)"
    );

    constructor() EIP712("AresProtocol", "1") {}

    function verifySignature(
        uint256 id,
        address to,
        uint256 amount,
        bytes calldata data,
        uint256 nonce,
        bytes calldata signature
    ) external view returns (address recoveredSigner) {
        // Build struct hash via library — single source of truth for encoding
        bytes32 structHash = AresLib.buildProposalStructHash(
            PROPOSAL_TYPEHASH, id, to, amount, data, nonce
        );

        // Combine with domain separator — binds to this contract + chainId
        bytes32 digest = _hashTypedDataV4(structHash);

        // Recover signer — OZ enforces low-s canonical form, prevents malleability
        recoveredSigner = digest.recover(signature);
    }

    /// @notice Returns domain separator — bound to contractAddress + chainId
    function getDomainSeparator() external view returns (bytes32) {
        return _domainSeparatorV4();
    }
}

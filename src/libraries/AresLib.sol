// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;


library AresLib {

    function buildProposalStructHash(
        bytes32 typehash,
        uint256 id,
        address to,
        uint256 amount,
        bytes memory data,
        uint256 nonce
    ) internal pure returns (bytes32) {
        return keccak256(
            abi.encode(typehash, id, to, amount, keccak256(data), nonce)
        );
    }


    function buildMerkleLeaf(
        address contributor,
        uint256 amount
    ) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(contributor, amount));
    }
}

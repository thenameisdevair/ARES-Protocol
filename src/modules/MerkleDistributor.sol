// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "src/interfaces/IMerkleDistributor.sol";
import "src/interfaces/IGuard.sol";
import "src/libraries/AresLib.sol";


contract MerkleDistributor is IMerkleDistributor {
    IERC20 public immutable token;
    IGuard public guard;
    address public multisig;

    bytes32 public merkleRoot;
    uint256 public currentWindow;

    // window => contributor => hasClaimed
    mapping(uint256 => mapping(address => bool)) private _claimed;

    modifier onlyMultisig() {
        require(msg.sender == multisig, "Merkle: not multisig");
        _;
    }

    modifier notPaused() {
        require(!guard.isPaused(), "Merkle: system paused");
        _;
    }

    constructor(address _token, address _guard, address _multisig) {
        require(_token != address(0), "Merkle: zero token");
        token = IERC20(_token);
        guard = IGuard(_guard);
        multisig = _multisig;
    }

    function claim(
        address contributor,
        uint256 amount,
        bytes32[] calldata merkleProof
    ) external notPaused {
        require(!_claimed[currentWindow][contributor], "Merkle: already claimed");
        require(amount > 0, "Merkle: zero amount");

        // Build leaf — must match off-chain leaf generation exactly
        bytes32 leaf = AresLib.buildMerkleLeaf(contributor, amount);

        // Verify proof against current root
        require(MerkleProof.verify(merkleProof, merkleRoot, leaf), "Merkle: invalid proof");

        // Mark claimed BEFORE transfer — checks-effects-interactions
        _claimed[currentWindow][contributor] = true;

        token.transfer(contributor, amount);

        emit RewardClaimed(contributor, amount, currentWindow);
    }


    function updateMerkleRoot(bytes32 newRoot) external onlyMultisig {
        require(newRoot != bytes32(0), "Merkle: zero root");
        merkleRoot = newRoot;
        currentWindow++;
        emit MerkleRootUpdated(newRoot, currentWindow);
    }

    function hasClaimed(address contributor) external view returns (bool) {
        return _claimed[currentWindow][contributor];
    }

    function getMerkleRoot() external view returns (bytes32) {
        return merkleRoot;
    }

    function getCurrentWindow() external view returns (uint256) {
        return currentWindow;
    }
}

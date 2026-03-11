// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "src/interfaces/IGuard.sol";
import "src/modules/SigVerifier.sol";
import "src/modules/MultisigAuth.sol";
import "src/modules/Vault.sol";
import "src/modules/Guard.sol";
import "src/modules/Queue.sol";
import "src/modules/MerkleDistributor.sol";
import "src/interfaces/IMerkleDistributor.sol";
import "src/core/AresProtocol.sol";
import "src/interfaces/IAresTypes.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockToken is ERC20 {
    constructor() ERC20("MockToken", "MTK") {
        _mint(msg.sender, 1_000_000 ether);
    }
}


contract AresProtocolTest is Test {

    // Contracts
    Guard public guard;
    SigVerifier public sigVerifier;
    MultisigAuth public multisigAuth;
    Vault public vault;
    Queue public queue;
    MerkleDistributor public merkleDistributor;
    AresProtocol public aresProtocol;
    MockToken public token;

    // Test accounts
    address public owner1;
    address public owner2;
    address public owner3;
    address public attacker;
    address public contributor;

    uint256 public owner1Key = 0xA11CE;
    uint256 public owner2Key = 0xB0B;
    uint256 public owner3Key = 0xCA1;

    address[] public owners;
    uint256 public constant THRESHOLD = 2;
    uint256 public constant DRAIN_THRESHOLD = 30; // 30%

    function setUp() public {
        // Derive addresses from private keys
        owner1 = vm.addr(owner1Key);
        owner2 = vm.addr(owner2Key);
        owner3 = vm.addr(owner3Key);
        attacker = makeAddr("attacker");
        contributor = makeAddr("contributor");

        owners.push(owner1);
        owners.push(owner2);
        owners.push(owner3);

        // Deploy token
        token = new MockToken();

        // Deploy in dependency order
        guard = new Guard(owner1); // owner1 acts as multisig for guard in tests
        sigVerifier = new SigVerifier();
        multisigAuth = new MultisigAuth(owners, THRESHOLD, address(sigVerifier), address(guard));
        vault = new Vault(address(token), address(guard), DRAIN_THRESHOLD);
        queue = new Queue(address(vault), address(multisigAuth), address(guard));
        merkleDistributor = new MerkleDistributor(address(token), address(guard), address(multisigAuth));

        // Wire queue into vault and vault into guard
        vault.setQueue(address(queue));
        vm.prank(owner1);
        guard.setVault(address(vault));

        aresProtocol = new AresProtocol(
            address(queue),
            address(multisigAuth),
            address(merkleDistributor),
            address(vault),
            address(guard)
        );

        // Fund vault with tokens for testing
        token.transfer(address(vault), 100_000 ether);
        token.transfer(contributor, 1_000 ether);
    }


    function test_Guard_PauseAndUnpause() public {
        vm.prank(owner1);
        guard.pause();
        assertTrue(guard.isPaused(), "Should be paused");

        vm.prank(owner1);
        guard.unpause();
        assertFalse(guard.isPaused(), "Should be unpaused");
    }

    function test_Guard_OnlyMultisigCanPause() public {
        vm.prank(attacker);
        vm.expectRevert("Guard: not authorized");
        guard.pause();
    }

    function test_MultisigAuth_OwnersSetCorrectly() public {
        assertTrue(multisigAuth.isOwner(owner1));
        assertTrue(multisigAuth.isOwner(owner2));
        assertTrue(multisigAuth.isOwner(owner3));
        assertFalse(multisigAuth.isOwner(attacker));
    }

    function test_MultisigAuth_ThresholdSetCorrectly() public {
        assertEq(multisigAuth.getThreshold(), THRESHOLD);
    }

    function test_MultisigAuth_AttackerNotOwner() public {
        assertFalse(multisigAuth.isOwner(attacker));
    }

    function test_Vault_Deposit() public {
        uint256 depositAmount = 1_000 ether;
        token.approve(address(vault), depositAmount);

        uint256 balanceBefore = vault.getBalance();
        vault.deposit(depositAmount);
        uint256 balanceAfter = vault.getBalance();

        assertEq(balanceAfter - balanceBefore, depositAmount);
    }

    function test_Vault_OnlyQueueCanRelease() public {
        vm.prank(attacker);
        vm.expectRevert("Vault: not queue");
        vault.releaseFunds(attacker, 100 ether);
    }

    function test_Vault_DrainThresholdTriggersPause() public {
        uint256 balance = vault.getBalance();
        uint256 largeDrain = (balance * 40) / 100; // 40% — exceeds 30% threshold

        vm.prank(address(queue));
        vm.expectRevert("Vault: drain threshold exceeded");
        vault.releaseFunds(owner1, largeDrain);

        // Guard should now be paused
        assertTrue(guard.isPaused());
    }

    function test_Vault_QueueCannotBeSetTwice() public {
        vm.expectRevert("Vault: queue already set");
        vault.setQueue(address(queue));
    }


    function test_Queue_CreateProposal() public {
        vm.prank(owner1);
        uint256 proposalId = queue.createProposal(owner2, 100 ether, "");

        Queue.Proposal memory p = queue.getProposal(proposalId);
        assertEq(p.to, owner2);
        assertEq(p.amount, 100 ether);
        assertEq(uint(p.status), uint(IAresTypes.ProposalStatus.Pending));
    }

    function test_Queue_NonOwnerCannotCreateProposal() public {
        vm.prank(attacker);
        vm.expectRevert("Queue: not owner");
        queue.createProposal(attacker, 100 ether, "");
    }

    function test_Queue_TimelockEnforced() public {
        // Create and queue a proposal
        vm.prank(owner1);
        uint256 proposalId = queue.createProposal(owner2, 100 ether, "");

        // Register and confirm with threshold
        _confirmProposal(proposalId, 100 ether, owner2, "");

        // Try to execute before timelock — should fail
        vm.prank(owner1);
        vm.expectRevert("Queue: timelock active");
        queue.executeProposal(proposalId);
    }

    function test_Queue_NonceIncrementsAfterExecution() public {
        uint256 nonceBefore = queue.getNonce();

        vm.prank(owner1);
        uint256 proposalId = queue.createProposal(owner2, 1_000 ether, "");
        _confirmProposal(proposalId, 1_000 ether, owner2, "");

        // Fast forward past timelock
        vm.warp(block.timestamp + 25 hours);

        vm.prank(owner1);
        queue.executeProposal(proposalId);

        assertEq(queue.getNonce(), nonceBefore + 1);
    }


    function test_SigVerifier_RecoversSigner() public {
        uint256 id = 0;
        address to = owner2;
        uint256 amount = 100 ether;
        bytes memory data = "";
        uint256 proposalNonce = 0;

        // Build EIP-712 digest
        bytes32 structHash = keccak256(
            abi.encode(
                sigVerifier.PROPOSAL_TYPEHASH(),
                id, to, amount, keccak256(data), proposalNonce
            )
        );
        bytes32 digest = keccak256(
            abi.encodePacked("\x19\x01", sigVerifier.getDomainSeparator(), structHash)
        );

        // Sign with owner1 key
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(owner1Key, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        address recovered = sigVerifier.verifySignature(id, to, amount, data, proposalNonce, signature);
        assertEq(recovered, owner1);
    }

    function test_SigVerifier_WrongSignerFails() public {
        uint256 id = 0;
        address to = owner2;
        uint256 amount = 100 ether;
        bytes memory data = "";
        uint256 proposalNonce = 0;

        bytes32 structHash = keccak256(
            abi.encode(
                sigVerifier.PROPOSAL_TYPEHASH(),
                id, to, amount, keccak256(data), proposalNonce
            )
        );
        bytes32 digest = keccak256(
            abi.encodePacked("\x19\x01", sigVerifier.getDomainSeparator(), structHash)
        );

        // Sign with attacker key — not a registered owner
        uint256 attackerKey = 0xDEAD;
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(attackerKey, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        address recovered = sigVerifier.verifySignature(id, to, amount, data, proposalNonce, signature);
        assertNotEq(recovered, owner1);
    }


    function test_Merkle_ClaimWithValidProof() public {
        uint256 claimAmount = 500 ether;

        // Build simple merkle tree with one leaf
        bytes32 leaf = keccak256(abi.encodePacked(contributor, claimAmount));
        bytes32 root = leaf; // Single leaf — root equals leaf

        // Fund distributor
        token.transfer(address(merkleDistributor), claimAmount);

        // Set root via multisig (owner1 is set as multisig in constructor)
        vm.prank(address(multisigAuth));
        merkleDistributor.updateMerkleRoot(root);

        // Claim with empty proof (single leaf tree)
        bytes32[] memory proof = new bytes32[](0);
        vm.prank(contributor);
        merkleDistributor.claim(contributor, claimAmount, proof);

        assertTrue(merkleDistributor.hasClaimed(contributor));
    }

    function test_Merkle_CannotClaimTwice() public {
        uint256 claimAmount = 500 ether;
        bytes32 leaf = keccak256(abi.encodePacked(contributor, claimAmount));
        bytes32 root = leaf;

        token.transfer(address(merkleDistributor), claimAmount * 2);

        vm.prank(address(multisigAuth));
        merkleDistributor.updateMerkleRoot(root);

        bytes32[] memory proof = new bytes32[](0);
        vm.prank(contributor);
        merkleDistributor.claim(contributor, claimAmount, proof);

        // Second claim should fail
        vm.prank(contributor);
        vm.expectRevert("Merkle: already claimed");
        merkleDistributor.claim(contributor, claimAmount, proof);
    }

    function test_Merkle_InvalidProofReverts() public {
        uint256 claimAmount = 500 ether;
        bytes32 root = keccak256(abi.encodePacked("real_root"));

        vm.prank(address(multisigAuth));
        merkleDistributor.updateMerkleRoot(root);

        // Wrong proof
        bytes32[] memory proof = new bytes32[](1);
        proof[0] = keccak256(abi.encodePacked("fake"));

        vm.prank(attacker);
        vm.expectRevert("Merkle: invalid proof");
        merkleDistributor.claim(attacker, claimAmount, proof);
    }


    function test_Integration_FullProposalLifecycle() public {
        address recipient = makeAddr("recipient");
        uint256 amount = 1_000 ether;

        // Step 1 — Owner submits proposal
        vm.prank(owner1);
        uint256 proposalId = queue.createProposal(recipient, amount, "");

        // Step 2 — Owners confirm with valid EIP-712 signatures
        _confirmProposal(proposalId, amount, recipient, "");

        // Step 3 — Queue proposal after threshold reached
        vm.prank(owner1);
        queue.queueProposal(proposalId);

        Queue.Proposal memory p = queue.getProposal(proposalId);
        assertEq(uint(p.status), uint(IAresTypes.ProposalStatus.Queued));
        assertTrue(p.isVerified);

        // Step 4 — Fast forward past 24hr timelock
        vm.warp(block.timestamp + 25 hours);

        // Step 5 — Execute proposal — funds released from Vault
        uint256 recipientBefore = token.balanceOf(recipient);

        vm.prank(owner1);
        queue.executeProposal(proposalId);

        uint256 recipientAfter = token.balanceOf(recipient);
        assertEq(recipientAfter - recipientBefore, amount);

        p = queue.getProposal(proposalId);
        assertEq(uint(p.status), uint(IAresTypes.ProposalStatus.Executed));
    }

    function test_Integration_PausedSystemBlocksAll() public {
        // Pause system
        vm.prank(owner1);
        guard.pause();

        // All operations should revert
        vm.prank(owner1);
        vm.expectRevert("Queue: system paused");
        queue.createProposal(owner2, 100 ether, "");
    }

    function test_Integration_ReplayAttackFails() public {
        address recipient = makeAddr("recipient");
        uint256 amount = 1_000 ether;

        // Execute proposal once
        vm.prank(owner1);
        uint256 proposalId = queue.createProposal(recipient, amount, "");
        _confirmProposal(proposalId, amount, recipient, "");

        vm.prank(owner1);
        queue.queueProposal(proposalId);
        vm.warp(block.timestamp + 25 hours);

        vm.prank(owner1);
        queue.executeProposal(proposalId);

        // Try to execute same proposal again — should fail
        vm.prank(owner1);
        vm.expectRevert("Queue: not queued");
        queue.executeProposal(proposalId);
    }


    function _confirmProposal(
        uint256 proposalId,
        uint256 amount,
        address to,
        bytes memory data
    ) internal {
        uint256 proposalNonce = queue.getNonce();

        // Build EIP-712 digest
        bytes32 structHash = keccak256(
            abi.encode(
                sigVerifier.PROPOSAL_TYPEHASH(),
                proposalId, to, amount, keccak256(data), proposalNonce
            )
        );
        bytes32 digest = keccak256(
            abi.encodePacked("\x19\x01", sigVerifier.getDomainSeparator(), structHash)
        );

        // Owner1 confirms
        (uint8 v1, bytes32 r1, bytes32 s1) = vm.sign(owner1Key, digest);
        vm.prank(owner1);
        multisigAuth.confirmProposal(proposalId, abi.encodePacked(r1, s1, v1));

        // Owner2 confirms — threshold reached
        (uint8 v2, bytes32 r2, bytes32 s2) = vm.sign(owner2Key, digest);
        vm.prank(owner2);
        multisigAuth.confirmProposal(proposalId, abi.encodePacked(r2, s2, v2));
    }
}

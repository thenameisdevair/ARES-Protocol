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

/// @dev Simple ERC20 for testing
contract MockToken is ERC20 {
    constructor() ERC20("MockToken", "MTK") {
        _mint(msg.sender, 1_000_000 ether);
    }
}

/// @title AresProtocolTest - Unit and Integration Tests
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

    // Test accounts with known private keys for EIP-712 signing
    uint256 public owner1Key = 0xA11CE;
    uint256 public owner2Key = 0xB0B;
    uint256 public owner3Key = 0xCA1;

    address public owner1;
    address public owner2;
    address public owner3;
    address public attacker;
    address public contributor;

    address[] public owners;
    uint256 public constant THRESHOLD = 2;
    uint256 public constant DRAIN_THRESHOLD = 30;

    function setUp() public {
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
        guard        = new Guard(owner1);
        sigVerifier  = new SigVerifier();
        multisigAuth = new MultisigAuth(owners, THRESHOLD, address(sigVerifier), address(guard));
        vault        = new Vault(address(token), address(guard), DRAIN_THRESHOLD);
        queue        = new Queue(address(vault), address(multisigAuth), address(guard));
        merkleDistributor = new MerkleDistributor(address(token), address(guard), address(multisigAuth));

        // Wire queue into vault — one-time set
        vault.setQueue(address(queue));

        aresProtocol = new AresProtocol(
            address(queue),
            address(multisigAuth),
            address(merkleDistributor),
            address(vault),
            address(guard)
        );

        // Seed vault and contributor with tokens
        token.transfer(address(vault), 100_000 ether);
        token.transfer(contributor, 1_000 ether);
    }

    function test_Guard_PauseAndUnpause() public {
        vm.prank(owner1);
        guard.pause();
        assertTrue(guard.isPaused());

        vm.prank(owner1);
        guard.unpause();
        assertFalse(guard.isPaused());
    }

    function test_Guard_AttackerCannotPause() public {
        vm.prank(attacker);
        vm.expectRevert("Guard: not multisig");
        guard.pause();
    }


    function test_MultisigAuth_OwnersRegistered() public {
        assertTrue(multisigAuth.isOwner(owner1));
        assertTrue(multisigAuth.isOwner(owner2));
        assertTrue(multisigAuth.isOwner(owner3));
        assertFalse(multisigAuth.isOwner(attacker));
    }

    function test_MultisigAuth_ThresholdCorrect() public {
        assertEq(multisigAuth.getThreshold(), THRESHOLD);
    }


    function test_Vault_Deposit() public {
        uint256 amount = 500 ether;
        token.approve(address(vault), amount);

        uint256 before = vault.getBalance();
        vault.deposit(amount);

        assertEq(vault.getBalance() - before, amount);
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
    }

    function test_Vault_QueueCannotBeSetTwice() public {
        vm.expectRevert("Vault: queue already set");
        vault.setQueue(address(queue));
    }

    function test_Queue_CreateProposal() public {
        vm.prank(owner1);
        uint256 id = queue.createProposal(owner2, 100 ether, "");

        Proposal memory p = queue.getProposal(id);
        assertEq(p.to, owner2);
        assertEq(p.amount, 100 ether);
        assertEq(uint(p.status), uint(ProposalStatus.Pending));
    }

    function test_Queue_AttackerCannotCreate() public {
        vm.prank(attacker);
        vm.expectRevert("Queue: not owner");
        queue.createProposal(attacker, 100 ether, "");
    }

    function test_Queue_TimelockEnforced() public {
        vm.prank(owner1);
        uint256 id = queue.createProposal(owner2, 100 ether, "");
        _confirmAndQueue(id, 100 ether, owner2, "");

        // Try to execute before 24hrs — must fail
        vm.prank(owner1);
        vm.expectRevert("Queue: timelock active");
        queue.executeProposal(id);
    }

    function test_Queue_NonceIncrementsOnExecution() public {
        uint256 before = queue.getNonce();

        vm.prank(owner1);
        uint256 id = queue.createProposal(owner2, 1_000 ether, "");
        _confirmAndQueue(id, 1_000 ether, owner2, "");

        vm.warp(block.timestamp + 25 hours);
        vm.prank(owner1);
        queue.executeProposal(id);

        assertEq(queue.getNonce(), before + 1);
    }


    function test_SigVerifier_RecoversSigner() public {
        bytes32 structHash = keccak256(abi.encode(
            sigVerifier.PROPOSAL_TYPEHASH(),
            uint256(0), owner2, uint256(100 ether), keccak256(""), uint256(0)
        ));
        bytes32 digest = keccak256(abi.encodePacked(
            "\x19\x01", sigVerifier.getDomainSeparator(), structHash
        ));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(owner1Key, digest);
        address recovered = sigVerifier.verifySignature(
            0, owner2, 100 ether, "", 0, abi.encodePacked(r, s, v)
        );

        assertEq(recovered, owner1);
    }

    function test_SigVerifier_WrongKeyFails() public {
        bytes32 structHash = keccak256(abi.encode(
            sigVerifier.PROPOSAL_TYPEHASH(),
            uint256(0), owner2, uint256(100 ether), keccak256(""), uint256(0)
        ));
        bytes32 digest = keccak256(abi.encodePacked(
            "\x19\x01", sigVerifier.getDomainSeparator(), structHash
        ));

        // Sign with attacker key
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(0xDEAD, digest);
        address recovered = sigVerifier.verifySignature(
            0, owner2, 100 ether, "", 0, abi.encodePacked(r, s, v)
        );

        assertNotEq(recovered, owner1);
    }


    function test_Merkle_ValidClaim() public {
        uint256 amount = 500 ether;
        bytes32 leaf = keccak256(abi.encodePacked(contributor, amount));

        token.transfer(address(merkleDistributor), amount);

        vm.prank(address(multisigAuth));
        merkleDistributor.updateMerkleRoot(leaf);

        bytes32[] memory proof = new bytes32[](0);
        vm.prank(contributor);
        merkleDistributor.claim(contributor, amount, proof);

        assertTrue(merkleDistributor.hasClaimed(contributor));
    }

    function test_Merkle_CannotClaimTwice() public {
        uint256 amount = 500 ether;
        bytes32 leaf = keccak256(abi.encodePacked(contributor, amount));

        token.transfer(address(merkleDistributor), amount * 2);

        vm.prank(address(multisigAuth));
        merkleDistributor.updateMerkleRoot(leaf);

        bytes32[] memory proof = new bytes32[](0);
        vm.prank(contributor);
        merkleDistributor.claim(contributor, amount, proof);

        vm.prank(contributor);
        vm.expectRevert("Merkle: already claimed");
        merkleDistributor.claim(contributor, amount, proof);
    }

    function test_Merkle_InvalidProofReverts() public {
        vm.prank(address(multisigAuth));
        merkleDistributor.updateMerkleRoot(keccak256("root"));

        bytes32[] memory proof = new bytes32[](1);
        proof[0] = keccak256("fake");

        vm.prank(attacker);
        vm.expectRevert("Merkle: invalid proof");
        merkleDistributor.claim(attacker, 100 ether, proof);
    }


    function test_Integration_FullLifecycle() public {
        address recipient = makeAddr("recipient");
        uint256 amount = 1_000 ether;

        // 1. Owner submits proposal
        vm.prank(owner1);
        uint256 id = queue.createProposal(recipient, amount, "");

        // 2. Owners confirm with valid EIP-712 signatures
        _confirmAndQueue(id, amount, recipient, "");

        // 3. Verify queued state
        Proposal memory p = queue.getProposal(id);
        assertEq(uint(p.status), uint(ProposalStatus.Queued));
        assertTrue(p.isVerified);

        // 4. Warp past 24hr timelock
        vm.warp(block.timestamp + 25 hours);

        // 5. Execute — funds released from Vault
        uint256 before = token.balanceOf(recipient);
        vm.prank(owner1);
        queue.executeProposal(id);

        assertEq(token.balanceOf(recipient) - before, amount);
        assertEq(uint(queue.getProposal(id).status), uint(ProposalStatus.Executed));
    }

    function test_Integration_PausedSystemBlocksAll() public {
        vm.prank(owner1);
        guard.pause();

        vm.prank(owner1);
        vm.expectRevert("Queue: system paused");
        queue.createProposal(owner2, 100 ether, "");
    }

    function test_Integration_ReplayAttackFails() public {
        address recipient = makeAddr("recipient");

        vm.prank(owner1);
        uint256 id = queue.createProposal(recipient, 1_000 ether, "");
        _confirmAndQueue(id, 1_000 ether, recipient, "");

        vm.warp(block.timestamp + 25 hours);
        vm.prank(owner1);
        queue.executeProposal(id);

        // Attempt replay — must fail
        vm.prank(owner1);
        vm.expectRevert("Queue: not queued");
        queue.executeProposal(id);
    }

    function _confirmAndQueue(
        uint256 proposalId,
        uint256 amount,
        address to,
        bytes memory data
    ) internal {
        uint256 proposalNonce = queue.getNonce();

        bytes32 structHash = keccak256(abi.encode(
            sigVerifier.PROPOSAL_TYPEHASH(),
            proposalId, to, amount, keccak256(data), proposalNonce
        ));
        bytes32 digest = keccak256(abi.encodePacked(
            "\x19\x01", sigVerifier.getDomainSeparator(), structHash
        ));

        (uint8 v1, bytes32 r1, bytes32 s1) = vm.sign(owner1Key, digest);
        vm.prank(owner1);
        multisigAuth.confirmProposal(proposalId, abi.encodePacked(r1, s1, v1));

        (uint8 v2, bytes32 r2, bytes32 s2) = vm.sign(owner2Key, digest);
        vm.prank(owner2);
        multisigAuth.confirmProposal(proposalId, abi.encodePacked(r2, s2, v2));

        vm.prank(owner1);
        queue.queueProposal(proposalId);
    }
}

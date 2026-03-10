# ARES Protocol

**A Secure Treasury Execution Protocol built on Ethereum.**

ARES was designed to solve a fundamental problem in decentralized treasury management — existing vault architectures fail under coordinated attacks. Governance takeovers, signature replay, flash-loan manipulation, Merkle root fraud, and multisig griefing are not edge cases. They are documented, repeated exploits. ARES was built to make each one structurally impossible.

---

## The Problem

Traditional vaults fail because they treat security as a feature rather than an architecture. A single contract holding funds and managing execution is a single point of failure. ARES separates every concern into a dedicated contract with one responsibility, so compromising one layer does not compromise the system.

---

## Architecture

ARES is a 7-contract system with a single entry point.

```
AresProtocol.sol        → System coordinator. All user interactions enter here.
├── MultisigAuth.sol    → Immutable owner registry. Confirmation tracking. Threshold enforcement.
├── SigVerifier.sol     → Stateless EIP-712 signature verification. No state. No storage.
├── Queue.sol           → Time-delayed execution engine. Nonce management. Timelock enforcement.
├── Vault.sol           → ERC20 treasury. Single token set at deployment. Drain threshold guard.
├── MerkleDistributor.sol → Contributor reward distribution via Merkle proof verification.
└── Guard.sol           → Standalone circuit breaker. Emergency pause. Called by Vault.
```

### Shared Types

```
interfaces/
└── IAresTypes.sol      → Shared Proposal struct and ProposalStatus enum. Imported by all contracts.
```

### Execution Flow

A transaction moves through every layer in order. There are no bypasses.

```
Owner proposes → MultisigAuth confirms (EIP-712 via SigVerifier) → Queue holds (24hr timelock) → Vault releases funds
```

No funds move without threshold confirmation. No confirmation passes without signature verification. No execution happens before the timelock expires.

---

## Contracts

### AresProtocol.sol
The single entry point for all external interactions. Users never call the underlying contracts directly. AresProtocol delegates to each specialized contract and emits top-level events for off-chain monitoring.

### MultisigAuth.sol
Manages the owner set, which is immutable after deployment. Tracks per-proposal confirmations and enforces the threshold before a proposal can be queued. Calls SigVerifier internally to validate each owner's EIP-712 signature before recording their confirmation.

### SigVerifier.sol
Stateless. Takes proposal data and a signature, returns the recovered signer address. Uses OpenZeppelin's EIP712 and ECDSA libraries. The domain separator binds every signature to this specific contract on this specific chain — preventing cross-chain replay and fake contract attacks.

### Queue.sol
Manages the full proposal lifecycle from creation to execution. Enforces the 24-hour timelock via `unlockTimestamp`. Increments the global nonce **before** execution — following checks-effects-interactions — preventing both replay attacks and reentrancy through nonce reuse.

### Vault.sol
Holds a single ERC20 token set immutably at deployment. Only Queue can trigger fund release. Uses balance-delta verification on deposit to handle any accounting edge cases. Checks the drain threshold on every release — if a single transaction attempts to move more than the configured percentage of the treasury, Guard is triggered automatically.

### MerkleDistributor.sol
Distributes contributor rewards without storing every contributor on-chain. A Merkle root represents the full contributor set. Contributors submit a proof — the contract verifies the proof against the root and releases their entitled amount. Each address can claim once per distribution window. The root is updated only through the multisig threshold, preventing fraudulent root substitution.

### Guard.sol
Standalone pausable contract. Has no knowledge of business logic. When triggered — either by Vault on a large drain attempt or directly by the multisig — it pauses the entire protocol. Every contract checks `guard.isPaused()` before executing. Only the multisig threshold can unpause.

---

## Security

### Flash-Loan Governance Attack
The owner set is immutable. Set at deployment. Cannot be changed. A flash loan attacker cannot borrow their way into the owner registry because no mechanism to add owners exists after deployment. Threshold multisig ensures no single compromised key can pass a proposal. The 24-hour timelock gives legitimate owners time to detect and trigger the circuit breaker.

### Signature Replay + Malleability
EIP-712 constructs a domain separator by hashing the contract address and chainId — binding every signature to one specific contract on one specific chain. The nonce, managed by Queue and incremented before execution, ensures each signature is consumed exactly once. OpenZeppelin's ECDSA enforces a low canonical `s` value, making `(r, s)` → `(r, n-s)` substitution invalid.

### Reentrancy + Timelock Bypass
Proposal status is updated to `Executed` before the ERC20 transfer — checks-effects-interactions. Vault inherits OpenZeppelin `ReentrancyGuard`. Queue enforces `block.timestamp >= unlockTimestamp` before any execution is triggered.

### Merkle Root Manipulation
Root updates require the full multisig threshold. No single owner can substitute a fraudulent root. A `claimed` mapping per distribution window prevents double claiming. All proof verification uses OpenZeppelin's `MerkleProof.verify()`.

### Multisig Griefing
A minority of owners cannot block a legitimate majority — the threshold is fixed at deployment. Spam proposals are disincentivized by the mandatory 24-hour timelock. Guard can be triggered by the majority to pause the system if griefing is detected.

---

## Token Design

ARES accepts a single ERC20 token set immutably at deployment. This is a deliberate security decision. Accepting arbitrary tokens opens the system to reentrant ERC20 attacks and fee-on-transfer accounting exploits. By locking to one audited token, that entire attack surface is eliminated by design. Deposit uses balance-delta verification as a secondary accounting check.

---

## Tests

Tests are written in Foundry.

```bash
forge test -vv
```

### Unit Tests
- `Guard` — pause, unpause, access control
- `MultisigAuth` — owner registry, threshold, duplicate confirmation prevention
- `Vault` — deposit, drain threshold, queue-only release, queue immutability
- `Queue` — proposal creation, timelock enforcement, nonce increment, non-owner rejection
- `SigVerifier` — correct signer recovery, wrong signer rejection
- `MerkleDistributor` — valid proof claim, double claim prevention, invalid proof rejection

### Integration Tests
- Full proposal lifecycle — propose → confirm → queue → timelock → execute → funds released
- Paused system blocks all operations
- Replay attack fails on executed proposal

---

## Project Structure

```
src/
  interfaces/
    IAresTypes.sol
    IAresProtocol.sol
    IVault.sol
    IQueue.sol
    IMultisigAuth.sol
    ISigVerifier.sol
    IMerkleDistributor.sol
    IGuard.sol
  AresProtocol.sol
  Vault.sol
  Queue.sol
  MultisigAuth.sol
  SigVerifier.sol
  MerkleDistributor.sol
  Guard.sol
test/
  AresProtocol.t.sol
```

---

## Dependencies

- [OpenZeppelin Contracts v5](https://github.com/OpenZeppelin/openzeppelin-contracts)
  - `EIP712` + `ECDSA` — signature verification
  - `ReentrancyGuard` — reentrancy protection
  - `MerkleProof` — contributor claim verification
  - `IERC20` — token interface

---

## Author

Built as part of Web3Bridge Cohort XIV — Week 7 

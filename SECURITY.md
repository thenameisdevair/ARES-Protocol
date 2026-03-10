### Security Analysis 

## 1. FlashLoan attack :- flash loan, a legitimate DeFi tool that allows users to borrow massive amounts of digital assets without collateral, provided the funds are returned within the same transaction.

For a flashLoan attack to happen on my system, the attacker needs to become a registered owner and does the borrowin all in one transaction.

# My System
Owner set is immutable, set at deployment. Cannot be changed. Therefore the attacker cannot borrow thier way into the owner registry.Becauese of immutability , the attack cannot even begin

How is this seen in my Contract 
# Layer1. - Immutable owner set in MultisigAuth.sol prevents attacker from gaining signing authority. 
# Layer2 -  Threshold multisig makes that even a compromised single key cannot pass a proposal alone.
# Layer 3 - 24hr timelock gives legitimate owners time to detect and trigger Guard.sol emergency pause. 



### Signature Reply + Malleability. 

2. Signature Replay + Malleability Attack: A Signature Replay and Malleability attack occurs due to the exploiting of signatures, making them reusable on different chains, or on the same protocol after first use.

EIP-712 uses a domain separator logic that hashes the contract address and chainId together, creating unique signatures, therefore eliminating cross-chain replay. The nonce, managed by Queue.sol and incremented before execution, ensures each signature is bound to one specific proposal — subsequent transactions produce a different nonce, making replay useless. OpenZeppelin's ECDSA library enforces a low canonical s value, making it mathematically difficult to rearrange (r, s) into (r, n-s) for reuse.
How this is seen in the contracts:

Layer 1 — SigVerifier.sol performs EIP-712 structured hash verification, binding signatures to one contract on one chain.

Layer 2 — Queue.sol manages and increments the nonce before execution, following checks-effects-interactions pattern, preventing both replay and reentrancy through nonce reuse.

Layer 3 — OpenZeppelin ECDSA canonical form enforced inside SigVerifier.sol eliminates malleability at the cryptographic level.


### Reentrancy + Timelock Bypass

3. Reentrancy + Timelock Bypass: A reentrancy attack occurs when a malicious contract repeatedly calls back into the Vault before the first execution completes, draining funds. A timelock bypass attempts to execute a queued transaction before the mandatory delay has elapsed.

ARES prevents this through a combination of architectural pattern enforcement and OpenZeppelin's ReentrancyGuard. State is always updated before external calls — checks-effects-interactions — meaning by the time the ERC20 transfer occurs, the proposal status is already marked executed. The unlockTimestamp is verified by Queue.sol before any execution is triggered, making it impossible to execute before the 24hr window expires.
How this is seen in the contracts:

Layer 1 — Queue.sol enforces block.timestamp >= unlockTimestamp before execution.

Layer 2 — Vault.sol inherits OpenZeppelin ReentrancyGuard, applying nonReentrant modifier on all fund release functions.

Layer 3 — Proposal status is updated to executed before ERC20 transfer, following checks-effects-interactions pattern.

4. Merkle Root Manipulation: A Merkle root manipulation attack occurs when an attacker attempts to submit a fraudulent Merkle root, allowing unauthorized addresses to claim rewards or claim more than their entitled amount.

ARES restricts Merkle root updates exclusively to the multisig threshold — no single owner can update the root unilaterally. Each claim window has a fixed open period, after which the root is updated only through a fully verified proposal pipeline. Each address can only claim once per root state, tracked through a claimed mapping, preventing double claiming within the same window.
How this is seen in the contracts:

Layer 1 — MerkleDistributor.sol only accepts root updates authorized through the full MultisigAuth.sol threshold.

Layer 2 — A claimed mapping per root state prevents double claiming within the same distribution window.

Layer 3 — Merkle proof verification uses OpenZeppelin's MerkleProof.verify(), ensuring only valid leaves against the current root are accepted.

5. Multisig Griefing: A multisig griefing attack occurs when one or more owners deliberately refuse to sign valid proposals, or flood the system with spam proposals to exhaust other owners or obscure malicious intent.

ARES mitigates griefing through threshold design and proposal structure. The threshold is set at deployment — a griefing owner cannot block execution if the remaining owners meet threshold. Spam proposals are economically disincentivized through the mandatory 24hr timelock, making flooding the queue costly in time and coordination. The immutable owner set means no new griefing actors can be introduced after deployment.
How this is seen in the contracts:

Layer 1 — MultisigAuth.sol threshold enforcement means a minority of owners cannot block a legitimate majority.

Layer 2 — Queue.sol mandatory 24hr timelock makes proposal spam expensive and visible.

Layer 3 — Guard.sol circuit breaker can be triggered by the legitimate owner majority to pause the system if griefing is detected.
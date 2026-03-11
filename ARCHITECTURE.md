### ARES PROTOCOL ARCHITECTURE

## Why ARES

Problem - failure in traditional vault architecture
· Solution - build a new secure treasury execution protocol

What failed traditional vaults (what ARES must prevent)

Governance takeovers
Replay attacks on signatures
Flash-loan governance manipulation
Merkle root manipulation
Timelock bypass via reentrancy
Multisig griefing attacks

I Am goint to Implemet 5 major Things: a transaction proposal system, a cryptographic authorization layer, a time-delayed execution engine, a contributor reward distribution system, and governance attack mitigation. Four independent modules minimum.


Before I started building, I broke down what each one actually means and what it needs to prevent.

**Proposing transactions** — I needed to ask: who can propose? The owners, set at deployment, immutable. Can owners be changed? No. If owners can be changed after deployment, then an attacker just needs to propose adding themselves as an owner. The immutability of the owner set is a very neccessay part.

**Cryptographic authorization** — My first instinct was multisig. But multisig alone doesn't prevent signature replay, malleability, or cross-chain replay. I researched and found EIP-712 — a structured signature standard that binds every signature to a specific contract on a specific chain through a domain separator. Combining multisig with EIP-712 gives me a threshold confirmation AND cryptographic uniqueness per signature. Neither one alone is sufficient.

**Time-delayed execution** — A queue that holds proposals for 24 hours before execution. But I had to check what the delay system itself needs to resist: reentrancy bypass, transaction replacement, timestamp manipulation, and proposal replay. Each one needed an answer in the architecture before I moved forward.

**Contributor rewards** — Thousands of contributors, independent claiming, no double claims, root updates. The moment I saw this I thought: Merkle tree. Instead of storing every contributor on-chain, I store a single 32-byte root. Contributors claim with a proof. Scalable to any number of recipients.

## My Structure

I ended up with seven contracts. The decision to separate them came from a simple principle: a contract that owns two responsibilities can be compromised at both of them simultaneously.

**AresProtocol.sol** — The single entry point. Every external interaction comes through here. It holds no state. It only delegates. This makes the trust boundary explicit.

**MultisigAuth.sol** — Owns the owner registry and confirmation tracking. Nothing else. The registry is immutable. No function exists to modify it after deployment.

**SigVerifier.sol** — Entirely stateless. Takes proposal data and a signature, returns a recovered address. It cannot be manipulated because it has nothing to manipulate. No state, no storage.

**Queue.sol** — Manages the full proposal lifecycle. Enforces the 24-hour timelock through a stored `unlockTimestamp`. Manages the global nonce — incremented before every execution.

**Vault.sol** — Holds one ERC20 token, set at deployment. Only Queue can trigger a release. Checks the drain threshold on every release. If exceeded, calls Guard before reverting.

**MerkleDistributor.sol** — Handles contributor reward claims. Verifies proofs against the current root. One claim per address per distribution window.

**Guard.sol** — Standalone circuit breaker. Knows nothing about treasury logic. When triggered — by Vault on a large drain or directly by multisig — it sets a paused flag that every contract checks before executing. Easy to trigger, requires multisig to undo.

## Do They Really Prevent It?

The mandatory execution pipeline answers this question. Every treasury action must go through: MultisigAuth confirmation → SigVerifier signature check → Queue timelock → Vault release. 

There is no shortcut. MultisigAuth cannot release funds — it has no Vault reference. Vault cannot execute proposals — it only responds to Queue. The dependency line enforces the pipeline structurally. Not through checks alone but through architecture.

## Single ERC20 token set at deployment. 

### Vault.Sol - Main function ( HOLDS MONEY)
Vault checks the Queue before releasing.
Hold tokens. 
Triggers Guard if drain threshold exceedes

### Queue.sol - MAIN function (Manages what leaves and to who)
stateful
manages proposals
tracks confirmations,
enforces timeslock.

### SigVerifier.sol - Main Funtion (signature off chain verifiction)
stateless(doesn't affect state)
implements EIP-712 ( for signature approbals).
purely for verification
SigVerifier receives: the transaction struct data + the signature bytes. It returns: the recovered signer address. MultisigAuth then checks if that recovered address is a registered owner.

### MultisigAuth.sol - Main function ( enforces multisig logic to prefent SPOF)
statful(affects state)
tracks owners(signers)
confirmations,
thresholds.

### MerkleDistributor.sol - Main function ( claims (token drop))
verifies contributor claims
pulls from vault

### Guard.sol - Main function (circuit breaker)
standalone pausable circuit breaker, 
called by Vault.


## Execution flow - no bypasses: MultisigSuth -> Queue -> Vault -> ERC20 transfer



Inner thoughts that brough insight to my model. 

Deciding whethre to take only one ERC-20 or any ERC-20 token

Restricting the Vault to a single ERC20 token — set immutably at deployment — eliminates an entire class of token-based attack vectors. By design, arbitrary or malicious tokens such as reentrant ERC20s are never accepted into the system. Fee-on-transfer token accounting discrepancies are mitigated through balance-delta verification on deposit. The protocol knows exactly what asset it is managing, simplifying accounting, audit surface, and reward distribution logic.


Q- Thinking of having a single point of acction for better UI/UX and audittability.
ARES Protocol exposes a single entry point — AresProtocol.sol — which acts as the system coordinator. External users and integrators interact exclusively through this contract, which delegates operations to the six specialized contracts underneath. This design serves two purposes: it simplifies user experience by providing one coherent interface, and it reduces audit surface by making the trust boundary explicit. All system interactions flow through one controlled gateway rather than being scattered across six independent contracts.

q - What should my Proposal look like. 
struct Proposal {
    uint256 id;
    address to;
    uint256 amount;
    bytes data;
    ProposalStatus status;
    uint256 submissionTime;
    uint256 unlockTimestamp;
    uint256 confirmations;
    bool isVerified;
    uint256 nonce;
}

Q - what should the full process in detial look like 

An owner proposes a transaction by calling AresProtocol.sol, passing all parameters captured in the Proposal struct. The proposal enters a pending state where the required threshold of owners must independently confirm it through MultisigAuth.sol, which tracks confirmations against the registered owner set. Each confirmation signature is passed through SigVerifier.sol, which constructs an EIP-712 structured hash of the proposal data, recovers the signer address, and returns it to MultisigAuth for owner validation — preventing replay, malleability, and cross-chain signature reuse via nonce management. Once threshold is reached, the proposal is marked verified and entered into Queue.sol, where it is held for a mandatory 24-hour timelock recorded as unlockTimestamp. After the timelock expires, Queue triggers execution, calling Vault.sol to release the specified ERC20 amount to the target address. At no point can funds be released without passing through every layer of this pipeline.




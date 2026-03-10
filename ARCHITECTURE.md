### ARES PROTOCOL ARCHITECTURE

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



<!-- security issue of using any erc-20 tokne. 

Fot(fee on transfer) toknes, and reentrant ERC20 are types of weired ERC20 toknes that deviate from the standard behaviour expected by most Defi protocols, oftne causing failed transactions, acounting errors, or dreainable liquidiy pools. 
FoT tokens : They ded;uct a percentage fee upon transfer. 
while Reentrant tokens: allow malicous call back into a contract during a transfer. -->

Restricting the Vault to a single ERC20 token — set immutably at deployment — eliminates an entire class of token-based attack vectors. By design, arbitrary or malicious tokens such as reentrant ERC20s are never accepted into the system. Fee-on-transfer token accounting discrepancies are mitigated through balance-delta verification on deposit. The protocol knows exactly what asset it is managing, simplifying accounting, audit surface, and reward distribution logic.

<!-- therer should be a AresProtocl.sol, that delegates to the 6 contracts underaneath. 
when it comes to user expericne, it is is neccessary that its easy for them, to interact with the contract form one single point, and also help me understand the contract for sudits.  -->

ARES Protocol exposes a single entry point — AresProtocol.sol — which acts as the system coordinator. External users and integrators interact exclusively through this contract, which delegates operations to the six specialized contracts underneath. This design serves two purposes: it simplifies user experience by providing one coherent interface, and it reduces audit surface by making the trust boundary explicit. All system interactions flow through one controlled gateway rather than being scattered across six independent contracts.

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

<!-- execution lifesycle. 
on of the owner proposes a transaction, this call, takes all the parameters in the proposal struct(return the full proposal struct), now this proposal, goes to a waiitng period or rather pending, in the penidn g pharse, we need the threshold amount of owners to sign off on it, once, the threshold is reached(this threshold testing is done by the multisig contract), it then goes to the sigverifer(to take instance of the transction) and evidence, of the onwers, and thier signes, then it goes to the queue contract, it holds it there for 24 hrs, given room for more review, before its finally executed. the execution is done by the multisign contract, and then it goes to the vault to release the funds. --> 

### Execution lifescycle

An owner proposes a transaction by calling AresProtocol.sol, passing all parameters captured in the Proposal struct. The proposal enters a pending state where the required threshold of owners must independently confirm it through MultisigAuth.sol, which tracks confirmations against the registered owner set. Each confirmation signature is passed through SigVerifier.sol, which constructs an EIP-712 structured hash of the proposal data, recovers the signer address, and returns it to MultisigAuth for owner validation — preventing replay, malleability, and cross-chain signature reuse via nonce management. Once threshold is reached, the proposal is marked verified and entered into Queue.sol, where it is held for a mandatory 24-hour timelock recorded as unlockTimestamp. After the timelock expires, Queue triggers execution, calling Vault.sol to release the specified ERC20 amount to the target address. At no point can funds be released without passing through every layer of this pipeline.




ARES PROTOCOL DESIGN

Problem - failure in traditional vault architecture
· Solution - build a new secure treasury execution protocol

What failed traditional vaults (what to prevent)

Governance takeovers
Replay attacks on signatures
Flash-loan governance manipulation
Merkle root manipulation
Timelock bypass via reentrancy
Multisig griefing attacks

Major Tasks to implement

Propose Treasury txns

Delay execution - cryptographic approval.

Verify authorization - time delay mechanism. (access control mechanisms)

Distribute funds and reward to Contributors (using vault system)

Prevent governance attacks.

Thought process to achieving this.

What is a treasury: A treasury is a place, department, or fund where money, valuables, or public revenues are stored and managed. It refers to the government department handling national finances, a repository for assets, or a collection of valuable resources. Synonyms include exchequer, vault.

What is the use of treasury: Treasury management involves managing an organization's cash, liquidity, and financial risks to ensure operational stability and support strategic goals.

What is the aim of treasury: The primary aim of treasury is to manage an organization's cash, liquidity, and financial risks to ensure financial stability and support business operations. It focuses on maintaining adequate cash, optimizing working capital, mitigating risks (interest rate, currency, credit), managing bank relationships, and investing surplus funds safely.

Now I have a mental picture of what to implement.

What is governance attack (Governance attack is a form of cyber attack where a malicious actor gains enough voting power within a decentralized autonomous organization, to pass harmful proposals.)

Methods: flashloans, and sybil attack (creating multiple independent accounts to gain influence).
Similar to the 51% attack in blockchain.

Going with the first.

PROPOSING TREASURY TRANSACTION.

Q1. Who can propose a Treasury transaction?
A1. The owners of the Treasury.

Q2. Who determines the owners of a treasury?
A2. Will be set in the constructor, during contract creation.

Q3. Can the owners be changed/removed?
A3. no.


Q5. What should a Treasury transaction contain?
A5.
Address to (receiver address)
Amount: amount being sent
Data: details of the transaction
Status: has transaction been executed
Time of submission: when was this transaction proposed.
Confirmations: how many of the owners have signed (will be determined by threshold).
Execution time: when txn was executed.

After thoughts


SO UNDER PROPOSE TREASURY TRANSACTION WE ARE LOOKING AT THREE FUNCTIONS.

Submitting a transaction.

Confirming a transaction. (Would have preferred to use multi-sig here, but instruction says to use cryptographic authorization.)

What is cryptographic authorization?
Foolish me.
Googled what cryptographic authorization layer means, figured out multisig was a form of cryptographic authorization layer.
So yeah, first choice using multi-sig.

But a block arises, can multisig alone prevent?
However, the protocol must prevent:
· Signature replay
· Signature malleability
· Cross-chain replay
· Domain collisions

Your design must include:
· A structured signature scheme
· Replay protection
· Nonce management

The answer is No, to achieve the above requirement I must...
The authorization layer must be built on a Structured Signature Scheme (specifically EIP-712) and include specific protocol-level safeguards.

To this then, I have to combine multisig too. To solve these, the authorization layer must be built on a Structured Signature Scheme (specifically EIP-712) and include specific protocol-level safeguards.

Now we know implementing the both will stop our system from:

Single point of failure.

Signature replay (EIP-712) - A signature replay attack is a security vulnerability where an attacker captures a valid digital signature or transaction data (e.g., from a blockchain or online banking) and fraudulently retransmits it to execute unauthorized actions, such as stealing funds. This occurs when systems fail to uniquely validate, or "nonce," each transaction.
Prevention of signature replay - Security measures include implementing unique nonces for every signature and verifying chain-specific IDs to prevent cross-chain or cross-project replays.

Signature malleability - Signature malleability is a cryptographic vulnerability where a valid digital signature (e.g., ECDSA) can be modified by an attacker into a different, yet still valid, signature for the same message without requiring the private key. This can lead to transaction replay attacks, enabling attackers to change transaction IDs or double-spend funds, particularly in blockchain systems.
Prevention - To prevent this, developers should use secure libraries, enforce strict canonical signature formats (e.g., low-v values), and ensure signatures are not used in a way that allows them to be reused or modified.

This is why I am using OpenZeppelin.

Cross-chain replay - simply doing signature replay for different chains.
Domain collision - When a proxy contract delegates calls to an implementation contract, both must share the same storage layout. If the implementation contract's storage structure is changed (e.g., reordering state variables) without careful management, it may write data to a storage slot that is already in use.

Prevention - Using structured storage patterns, such as the Diamond Standard (ERC-2535), can help prevent storage layout mismatches.

Our design now has:
8. A structured signature scheme.
6. Replay protection and nonce management.

Now these are quite difficult things to do, so I researched, and found out that OpenZeppelin has libraries that will help me implement them.

Next will be Time-delayed execution engine.

Luckily for us, the requirement that our execution engine must be resistant to is already solved above, which means the above must be checked and implemented before we forward to the execution engine.

The delay system must be resistant to:

Reentrancy bypass - A reentrancy attack is a critical security vulnerability in smart contracts where an attacker's contract repeatedly calls a function in a victim contract before the first execution of that function has finished.
Prevention - Using a "lock" (like OpenZeppelin’s ReentrancyGuard) that prevents a function from being entered again if it is already executing.

Transaction replacement attacks - A transaction replacement attack (often associated with Replace-By-Fee or RBF) occurs when a malicious actor replaces a pending, unconfirmed transaction in the mempool with a new one that spends the same funds to a different address. This is essentially a specialized form of a double-spend attack that targets the window before a transaction is confirmed in a block.
Prevention - Using a queue-based execution architecture.

Timestamp manipulation - Timestamp manipulation (also known as Timestamp Dependence) is a vulnerability where a block proposer (miner or validator) slightly modifies the block's timestamp to benefit themselves or trigger specific contract conditions.
Prevention - With our waiting and timeframe of 24-48 hours we can mitigate that.

Proposal replay - A proposal replay attack occurs when a valid signature for a governance action (like a vote or a treasury withdrawal) is captured and resubmitted to the same or a different contract to execute the action again without the signer's consent.
Prevention - While EIP-712 prevents the signature from being re-used, your queue-based architecture acts as a second layer of defense against ordering-based replays or "Signature Malleability".

Having seen what is expected for a time-delay system, we now see that earlier implementation didn’t actually cover up for it as I thought.

So, for reentrancy I will stick with OpenZeppelin.
For transaction replacement attack, a good combo of the 712, multisig, and queueing, can help solve that.
For timestamp manipulation, increasing waiting time frame to 24-48 hrs can solve that.
And lastly, for proposal replay, we can stick with our earlier logic.

So second to last.

Contributor reward Distribution.

I remembered, the task from yesterday involved a merkle tree, and merkle tree actually initially helped solve bulk data issue, also during research yesterday, I found out that merkle tree verification is used for airdrop, and if there’s one place that have thousands of users claiming, it will be airdrop.

So yeah I decided, to try to implement the merkle tree verification for it.

Now the questions:
Q1. Is it every contributor that will get airdrop?
A1. Well yes.

Q2. If so, then how can I keep track of everyone?
A2. I don’t have to, I can use the merkle tree to check if the person has contributed and the amount he has contributed.

Q3. It says distributes tokens, what should I use as the tokens?
A3. For simplicity I will stick with ether.

Q4. If someone contributes 10,000, and another 100, do they get same reward?
A4. Not meant to be, so probably another calculation, say 0.5% of total contribution or 1% of total contribution.

Q5. Is the claiming only once, or will subsequent contribution lead to later claiming later?
A5. It should allow subsequent claiming.

Q6. How will it allow subsequent claiming?
A6. By updating root state, new claim calculates from new state root, and this will be universal, so there will be an open claiming time, say for first airdrop, then after that time frame, it clears state (updates state) before new claim is allowed.

Q7. Is one allowed to claim more than once, even during an airdrop window?
A7. No.

Last point GOVERNANCE ATTACK MITIGATION.

System must include exploit defenses against economic attacks. Including:

Flash-loan governance manipulation - Flash loans allow attackers to instantly borrow massive voting power to pass malicious proposals within a single transaction block.
Prevention - Require a non-zero delay (e.g., 48 hours) between a proposal passing and its actual code execution.
This provides a "grace period" for the community to detect a malicious "passed" proposal and exit the protocol or trigger an emergency pause.

So this means that my earlier instructions already made provision for this.

Large treasury drains - Treasury drains often occur when governance is hijacked to transfer funds to an attacker's wallet.
Prevention - Multisig accounts for this.

Proposal griefing - Proposal griefing involves flooding the system with spam proposals to exhaust community attention or hide malicious intent.

Voting Power Lock-up: A mechanism where tokens must be "staked" in the governance contract for a minimum period to generate voting power, preventing flash-loan-based "flash voting".

Emergency Circuit Breaker: An automated or multisig-triggered "pause" button that halts all governance executions if a proposal attempts to move more than X% of the treasury at once.
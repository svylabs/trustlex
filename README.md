# Trustlex
Trustlex is a decentralized cross chain, non-custodial Bitcoin exchange protocol which can be used to exchange Bitcoin with assets on the other chain(eg: Ethereum, Avalanche C-Chain or other EVM compatible chains)

# How it works
There are two smart contracts 
1. **BitcoinSPVChain contract** is an incentivised contract where any user can submit new Bitcoin block headers in return for **SPVC** tokens. For more details on **SPVC** tokens see the [Tokenomics section](#Tokenomics)
2. **Swap contract** are deployed per asset pair (eg: BTC-ETH) and serves as an order book. 
 - Step 1: A ETH holder can post their order(eg: Sell 100 ETH for 10 BTC) and also provide their BTC address to the contract. 
 - Step 2: A Bitcoin holder wanting to swap Bitcoin for Ethereum can send Bitcoins to the specified address by the user
 - Step 3: The Bitcoin holder posts merkle proof of transfer to the swap contract and withdraws ETH if the block has been confirmed and the transaction is included in the block to withdraw ETH from contract.

# Tokenomics
**BitcoinSPVChain contract** mints and allocates **SPVC** tokens to the block submitter. This is done to incentivise block submission to the contract. The token is used as a pass by users of the swap contracts. The users of swap contract can either submit blocks to gain tokens to be used during swap process or they can purchase the tokens from the market.

Initial reward starts at 50 SPVC per block, and each month the reward reduces by half, until the contract issues 0.01 SPVC per block, and subsequently there is no halving and the contract issues 0.01 SPVC perpetually to every new block confirmed. Initially the reward is higher to encourage submission of new Bitcoin blocks to the contract, subsequently if there are many users of the swap contract, the assumption is that at least one person wanting to swap will submit the new blocks.

# Security

## Accidental Reorgs
- If there are block reorgs happening inside the confirmation window of 6 blocks, the contract handles it gracefully.
- If there are block reorgs happening after a block has been confirmed, the contract increases the time to confirm a block. Subsequently when the fork has resolved, the confirmation time is decreased by the contract. The minimum number of confirmations set by the contract is 6. The dapp using the contract should take into account the number of confirmations to enable / disable fund locking mechanism. The contract also rewards 20 times the current reward for users notifying of any forks.

## HardForks
- The contract doesn't currently handle hardforks. The proposed solution is to fork a new Relay contract by the token holders.

# Abstract

A smart contract based protocol allows trustless exchange of Native Bitcoin to assets on Ethereum and other networks and vice-versa, where the funds on either side would be in control of the users themselves, and not any custodian. While solutions using centralized custodian of funds, and threshold-signature-scheme based custodians offer such an exchange at scale, the main benefit would be lost if the funds were still to be held by a custodian. Custodians have to ensure they are always online, not hacked, and should be trusted by the users. Atomic cross chain swaps offer part of the solution where users can exchange trustlessly in a self-custodial manner. But the main drawback of the atomic swap solution is in the UX. It is not intuitive enough for the users, order discoverability is hard and the users need to be online, monitor the transactions on either chain to complete the swap. In our work, we take smart contract elements from atomic swaps, use an orderbook based exchange on Ethereum, and have Bitcoin light client within Ethereum smart contracts to enable trustless swaps in a self-custodial manner, and with much better user experience - better order discoverability, allowing for fractional swaps, Bitcoin transactions are verified using smart contracts, instead of manually checking the chain and importantly where the funds are in control by the users at all times.
 
# Introduction

Decentralized exchanges have exploded in popularity in recent years and is often beating centralized exchanges in terms of volume. However, it is still not possible to exchange Bitcoin with assets on other chains in a trustless manner. People often resort to centralized exchanges or have to park their funds with a custodian run using threshold-signature-scheme. While these solutions offers better user experience and scalable exchange experience, the main drawback is the centralized nature of such a scheme and users do not have control over their funds at all times. As we have seen several times, centralized exchanges do not maintain full reserves of the user funds, could get hacked and threshold signature scheme based solutions are also based on trust that the participants in the scheme would not collude to steal user funds and the threshold is often limited to a few tens of users. Atomic swaps are a solution to this problem, but the user experience is poor due to issues with peer / order discoverability, fractional swaps are not possible, and users have to be online to complete the swap.

In this work, we propose a non-custodial solution to the problem of enabling trustless swaps from Bitcoin to assets on Ethereum(or other networks), where the funds are always in control by the users and reach the conclusion how our solution offers much better user experience than other trustless swapping solutions like atomic swaps and why this protocol is suitable for trustless swaps involving large orders compared to having BTC custodied by custodians run by threshold-signature-schemes.

# Background

To enable trustless cross-chain swaps from Bitcoin to Ethereum(extensible to other networks), we use the following core technologies.

**Hash Time Lock Contracts(HTLC):**
HTLCs are a staple of cross-chain exchange protocols. Let's say, a user Bob wants to send funds to Alice, but also have the capability to redeem funds if it's not claimed within a time period for various reasons. This can be accomplished by using timelock contract (CheckLockTimeVerify on Bitcoin). Further, Alice should be able to claim the funds only after presenting a pre-image of a hash encoded into the Bitcoin P2WSH script. These two conditions can simultaneously be achieved using HTLC script. The reason for hash lock is to ensure that Alice can only claim funds after Bob has revealed the pre-image of the hash. The timelock makes it possible for Bob to recover funds after a certain time, for whatever reason - for example: Alice backs out of the deal.

**Simplified Payment Verification:**
Simplified Payment Verification envisioned in the Bitcoin whitepaper is a primary ingredient in providing better user experience in trustless cross-chain swaps. By having a smart contract track Bitcoin block headers, verification of Bitcoin transactions can be done in an automated way by smart contracts executed on ethereum. After making Bitcoin transaction, the user generates a merkle proof of the transaction and submits the proof to the smart contract. The smart contract can verify if the transaction is included in Bitcoin block. This mechanism allows for a better user experience in the cross-chain exchange protocol.

By combining these two technologies, we are able to offer seamless and secure user experience in our cross-chain exchange protocol.

# Problem Statement

Let's say there are two parties Alice and Bob. Alice has ETH on Ethereum, and Bob has Native BTC. Further, Alice and Bob do not know each other nor have a way to discover each other. Both Alice and Bob are unwilling to use centralized exchange to complete the swap nor use an escrow/custodian to park their funds during the swap process. They want to perform the exchange trustlessly.

# Solution (Protocol)

Step 1: Alice places her ETH locked into a smart contract, along with BTC address where Alice wants to receive BTC.
Step 2: Bob discovers the smart contract and finds funds in the smart contract that could be obtained by sending BTC.
Step 3: Bob generates a secret, hashes the secret and generates a HTLC address using Alice's address, along with his own address for recovery after a certain time period.
Step 4: Bob sends BTC to the HTLC address
Step 5: Bob waits a few confirmations on BTC block, generates merkle proof of the transaction and submits to the contract
Step 7: Contract verifies the merkle proof and locks the ETH for 15 minutes
Step 8: Bob now sends the plaintext secret to the smart contract that Alice can use to unlock funds.
Step 8: Contract verifies if it's a valid secret and releases the ETH funds to Bob.
Step 9: Alice can spend funds from BTC address using the secret.

(Protocol)[./protocol.svg]

# Technical Details

# Security

# DAO

# Tokenomics

# Use cases

# Roadmap

# Team

# Risks & Challenges

# Conclusion
// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;
import {SafeMath} from "./SafeMath.sol";
import {ERC20} from "./ERC20.sol";
import {ISPVChain, BlockHeader} from "./ISPVChain.sol";
import {BitcoinUtils} from "./BitcoinUtils.sol";


contract BitcoinSPVChain is ERC20, ISPVChain {

  using SafeMath for uint256;

  /** Minimum Reward to be paid by the contract for submitting blocks */
  uint256 public MIN_REWARD = 1 * (10 ** decimals()) / 100; // 0.01 SPVC

  /** Reward halving time for block submission */
  uint256 public REWARD_HALVING_TIME = 144 * 30; // every 432 blocks

  /** Number of blocks needed on top of an existing block for confirmation of a certain block */
  uint256 public CONFIRMATIONS = 6;

  /** Deletes all prior blocks */
  uint256 public BLOCKS_TO_STORE = 144 * 60; // Store two months of data in contract
  
  /** This is needed when doing the difficulty adjustment for the first time and is set by constructor */
  uint256 public initialEpochTime;

  /** Total number of blocks confirmed by the contract */
  uint256 private confirmedBlocks = 0;

  /** Current reward for submitting the blocks */
  uint256 public currentReward = 50 * (10 ** decimals());

  /** Block Headers  */
  mapping (bytes32 => BlockHeader) private blocks;

  /** Mapping of block height to block hash */
  mapping (uint256 => bytes32) private blockHeightToBlockHash;
  

  constructor(bytes memory initialConfirmedBlockHeader, uint256 height, uint256 _initialEpochTime) {
      BlockHeader memory header = this._parseBytesToBlockHeader(initialConfirmedBlockHeader);
      header.blockHeight = height;
      blocks[header.blockHash] = header;
      blockHeightToBlockHash[height] = header.blockHash;
      initialEpochTime = _initialEpochTime;
  }

  /**
     Parses BlockHeader given as bytes and returns a struct BlockHeader
   */
  function _parseBytesToBlockHeader(bytes calldata blockHeaderBytes) view public returns (BlockHeader memory result) {
    require(blockHeaderBytes.length >= 80);
    result = BlockHeader({
      previousHeaderHash: BitcoinUtils._leToBytes32(blockHeaderBytes, 4),
      merkleRootHash: BitcoinUtils._leToBytes32(blockHeaderBytes, 36),
      time: BitcoinUtils._leToUint32(blockHeaderBytes, 68),
      nBits: BitcoinUtils._leToBytes4(blockHeaderBytes, 72),
      blockHash: sha256(abi.encodePacked(sha256(blockHeaderBytes[0: 80]))),
      blockHeight: 0,
      submitter: msg.sender
    });
    return result;
  }

  /**
    Validates if the incoming block is valid.
       * Check if the block matches the difficulty target
       * Compute a new difficulty and verify if it's correct
   */
  function _validateBlock(BlockHeader memory header, BlockHeader memory previousBlock) public view returns (bool result) {
    uint256 target = BitcoinUtils._nBitsToTarget(header.nBits);
    require(uint256(header.blockHash) < target); // Require blockHash < target

    uint256 epochStartBlockTime = 0;
    if (header.blockHeight % 2016 == 1) {
       bytes32 epochStartBlockHash = blockHeightToBlockHash[header.blockHeight - 2016];
       if (epochStartBlockHash != 0x0) {
         epochStartBlockTime = blocks[epochStartBlockHash].time;
       } else {
         epochStartBlockTime = initialEpochTime;
       }
       uint256 newTarget = BitcoinUtils._retargetAlgorithm(BitcoinUtils._nBitsToTarget(previousBlock.nBits), epochStartBlockTime, previousBlock.time);
       require(newTarget == BitcoinUtils._nBitsToTarget(header.nBits));
    }
    return true;
  }

  /**
     Confirm a block and allocate token to the submitter
   */
  function _confirmBlock(BlockHeader memory header) private {
    bytes32 previousHeaderHash = header.previousHeaderHash;
    for (uint256 height = header.blockHeight - 1; height > header.blockHeight - CONFIRMATIONS; height--) {
      previousHeaderHash = blocks[previousHeaderHash].previousHeaderHash;
      if (previousHeaderHash == 0x0) {
        break;
      }
    }
    // Validate if the block is not confirmed already
    if (previousHeaderHash != 0x0 && blockHeightToBlockHash[header.blockHeight - CONFIRMATIONS] == 0x0) {
      // Set confirmed block height
      blockHeightToBlockHash[header.blockHeight - CONFIRMATIONS] = previousHeaderHash;
      confirmedBlocks++;

      _allocateTokens(msg.sender);
    }
  }

  /**
     Clear older blocks
   */
  function _clearBlock(BlockHeader memory header) private {
    bytes32 blockHeaderHashToClear = blockHeightToBlockHash[header.blockHeight - BLOCKS_TO_STORE];
    if (blockHeaderHashToClear != 0x0) {
      delete blocks[blockHeaderHashToClear];
      delete blockHeightToBlockHash[header.blockHeight - BLOCKS_TO_STORE];
    }
  }

  /**
      Allocate tokens to the beneficiary
   */
  function _allocateTokens(address beneficiary) internal {
      _mint(beneficiary, currentReward);
      if (confirmedBlocks % REWARD_HALVING_TIME == 0 && currentReward > MIN_REWARD) {
        currentReward = currentReward / 2;
        if (currentReward < MIN_REWARD) {
          currentReward = MIN_REWARD;
        }
      }
  }

  /**
     submitBlock will be used by users to submit blocks to the contract
   */
  function submitBlock(bytes calldata blockHeader) external {
    BlockHeader memory header = _parseBytesToBlockHeader(blockHeader);
    // Check if the block has not been submitted before
    require (blocks[header.blockHash].time == 0);

    bytes32 previousHeaderHash = BitcoinUtils._leToBytes32(blockHeader, 4);
    
    BlockHeader memory previousBlock = blocks[previousHeaderHash];
    header.blockHeight = previousBlock.blockHeight + 1;

    // If the block is available
    if (previousBlock.time == 0) {
      return;
    }

    require(_validateBlock(header, previousBlock));

    // Confirm the current - 6 block
    _confirmBlock(header);

    // Clear earliest block data
    _clearBlock(header);
    
  }

  /**
    getTxMerkleRootAtHeight returns the transaction merkle root at height specified or returns 0x0 if none exists.
     The function also checks if the user holds a minimum amount of tokens in their account equivalent to currentReward
   */
  function getTxMerkleRootAtHeight(uint256 height) external view returns (bytes32) {
    /* 
      Using tx.origin is NOT a bug. This is exactly what we want. We want only the holders of the token
      to be able to use this function and not allow any arbitrary contracts.
    */
     require(balanceOf(tx.origin) >= currentReward);
     return blocks[blockHeightToBlockHash[height]].merkleRootHash;
  }

  /**
     getBlockHeader returns the BlockHeader at height specified.
     The function also checks if the user holds a minimum amount of tokens in their account equivalent to currentReward
   */
  function getBlockHeader(uint256 height) external view returns (BlockHeader memory) {
    /* 
      Using tx.origin is NOT a bug. This is exactly what we want. We want only the holders of the token
      to be able to use this function and not allow any arbitrary contract
    */
     require(balanceOf(tx.origin) >= currentReward);
     return blocks[blockHeightToBlockHash[height]];
  }

}

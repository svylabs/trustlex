// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;
import {SafeMath} from "./SafeMath.sol";
import {ERC20} from "./ERC20.sol";
import {ISPVChain, BlockHeader, IGov} from "./ISPVChain.sol";
import {BitcoinUtils} from "./BitcoinUtils.sol";


contract BitcoinSPVChain is ERC20, ISPVChain, IGov {

  using SafeMath for uint256;

  /** Minimum Reward to be paid by the contract for submitting blocks */
  uint256 public MIN_REWARD = 1 * (10 ** decimals()) / 100; // 0.01 SPVC

  /** Reward halving time for block submission */
  uint256 public REWARD_HALVING_TIME = 144 * 30; // every 432 blocks

  /** Number of blocks needed on top of an existing block for confirmation of a certain block */
  uint256 public CONFIRMATIONS = 6;

  /** Number of blocks needed on top of an existing block for confirmation of a certain block */
  uint256 public MIN_CONFIRMATIONS = 6;

  /** Deletes all prior blocks */
  uint256 public BLOCKS_TO_STORE = 144 * 60; // Store two months of data in contract
  
  /** This is needed when doing the difficulty adjustment for the first time and is set by constructor */
  uint32 public initialEpochTime;

  /** Latest confirmed block height */
  uint256 public confirmedBlockHeight = 0;

  /** First block height */
  uint256 public initialConfirmedBlockHeight = 0;

  /** Current reward for submitting the blocks */
  uint256 public currentReward = 50 * (10 ** decimals());

  /** Block Headers  */
  mapping (bytes32 => BlockHeader) private blocks;

  /** Mapping of block height to block hash */
  mapping (uint256 => bytes32) public blockHeightToBlockHash;

  /** Fork detected event */
  event FORK_DETECTED(uint256 height, bytes32 storedBlockHash, bytes32 collidingBlockHash, uint256 newConfirmations);

  constructor(bytes memory initialConfirmedBlockHeader, uint256 height, uint32 _initialEpochTime) {
      BlockHeader memory header = BlockHeader({
        previousHeaderHash: BitcoinUtils._leToBytes32(initialConfirmedBlockHeader, 4),
        merkleRootHash: BitcoinUtils._leToBytes32(initialConfirmedBlockHeader, 36),
        time: BitcoinUtils._leToUint32(initialConfirmedBlockHeader, 68),
        nBits: BitcoinUtils._leToBytes4(initialConfirmedBlockHeader, 72),
        blockHeight: 0,
        submitter: msg.sender
      });
      bytes32 blockHash = BitcoinUtils.swapEndian(sha256(abi.encodePacked(sha256(initialConfirmedBlockHeader))));
      header.blockHeight = height;
      blocks[blockHash] = header;
      blockHeightToBlockHash[height] = blockHash;
      confirmedBlockHeight = height;
      initialEpochTime = _initialEpochTime;
      initialConfirmedBlockHeight = height;
  }

  /**
     Parses BlockHeader given as bytes and returns a struct BlockHeader
   */
  function _parseBytesToBlockHeader(bytes calldata blockHeaderBytes) public view returns (BlockHeader memory result, bytes32 blockHash) {
    require(blockHeaderBytes.length >= 80);
    result = BlockHeader({
      previousHeaderHash: BitcoinUtils._leToBytes32(blockHeaderBytes, 4),
      merkleRootHash: BitcoinUtils._leToBytes32(blockHeaderBytes, 36),
      time: BitcoinUtils._leToUint32(blockHeaderBytes, 68),
      nBits: BitcoinUtils._leToBytes4(blockHeaderBytes, 72),
      blockHeight: 0,
      submitter: msg.sender
    });
    blockHash = BitcoinUtils.swapEndian(sha256(abi.encodePacked(sha256(blockHeaderBytes[0: 80]))));
  }

  /**
    Validates if the incoming block is valid.
       * Check if the block matches the difficulty target
       * Compute a new difficulty and verify if it's correct
   */
  function _validateBlock(bytes32 blockHash, BlockHeader memory header, BlockHeader memory previousBlock) public view returns (bool result) {
    uint256 target = BitcoinUtils._nBitsToTarget(header.nBits);
    require(uint256(blockHash) < target); // Require blockHash < target
    uint256 epochStartBlockTime = 0;
    if (header.blockHeight % 2016 == 0) {
       bytes32 epochStartBlockHash = blockHeightToBlockHash[header.blockHeight - 2016];
       if (epochStartBlockHash != 0x0) {
         epochStartBlockTime = blocks[epochStartBlockHash].time;
       } else {
         epochStartBlockTime = initialEpochTime;
       }
       uint256 newTarget = BitcoinUtils._retargetAlgorithm(BitcoinUtils._nBitsToTarget(previousBlock.nBits), epochStartBlockTime, previousBlock.time);
       require(bytes4(BitcoinUtils._targetToNBits(newTarget)) == header.nBits);
       /*
       emit LOG2(bytes4(BitcoinUtils._targetToNBits(newTarget)));
       emit LOG2(header.nBits);
       emit LOG1(bytes32(newTarget));
       emit LOG(newTarget);
       emit LOG(BitcoinUtils._nBitsToTarget(header.nBits));
       emit LOG1(bytes32(header.nBits));
       emit LOG1(bytes32(newTarget & BitcoinUtils._nBitsToTarget(header.nBits)));
       emit LOG1(bytes32(uint256(BitcoinUtils._targetToNBits(newTarget))));
       emit LOG1(bytes32(uint256(BitcoinUtils._targetToNBits(BitcoinUtils._nBitsToTarget(previousBlock.nBits)))));
       emit LOG1(bytes32(previousBlock.nBits));
       */
    }
    return true;
  }

  /**
     Confirm a block and allocate token to the submitter
   */
  function _confirmBlock(BlockHeader memory header, bytes32 blockHash) private {
    bytes32 previousHeaderHash = header.previousHeaderHash;
    uint256 confirmationBlockHeight = header.blockHeight - CONFIRMATIONS;
    for (uint256 height = header.blockHeight - 1; height > confirmationBlockHeight; height--) {
      previousHeaderHash = blocks[previousHeaderHash].previousHeaderHash;
      if (previousHeaderHash == 0x0) {
        break;
      }
    }
    // Validate if the block is not confirmed already
    if (previousHeaderHash != 0x0 && blockHeightToBlockHash[confirmationBlockHeight] == 0x0) {
      // Set confirmed block height
      blockHeightToBlockHash[confirmationBlockHeight] = previousHeaderHash;
      confirmedBlockHeight = header.blockHeight;

      _allocateTokens(msg.sender, 1);
    } else if (blockHeightToBlockHash[confirmationBlockHeight] != 0x0) {
      _forkDetected(confirmationBlockHeight, blockHash);
    }
  }

  /**
     If a fork has been detected, 
   */
  function _forkDetected(uint256 height, bytes32 collidingBlockHash) private {
      uint256 affectedBlocks = confirmedBlockHeight - height + 1;
      for (uint256 _h = height; _h <= confirmedBlockHeight; _h++) {
         blockHeightToBlockHash[_h] = 0x0;
      }
      if (affectedBlocks < CONFIRMATIONS) {
        CONFIRMATIONS = CONFIRMATIONS * 2;
      } else {
        CONFIRMATIONS = (CONFIRMATIONS + affectedBlocks) * 2;
      }
      emit FORK_DETECTED(height, blockHeightToBlockHash[height], collidingBlockHash, CONFIRMATIONS);
      // Higher rewards for notifying of forks
      _allocateTokens(msg.sender, 10); 
  }

  /**
     Clear older blocks
   */
  function _clearBlock(BlockHeader memory header) private {
    if (header.blockHeight < BLOCKS_TO_STORE) {
      return ;
    }
    bytes32 blockHeaderHashToClear = blockHeightToBlockHash[header.blockHeight - BLOCKS_TO_STORE];
    if (blockHeaderHashToClear != 0x0) {
      delete blocks[blockHeaderHashToClear];
      delete blockHeightToBlockHash[header.blockHeight - BLOCKS_TO_STORE];
    }
  }

  /**
      Allocate tokens to the beneficiary
   */
  function _allocateTokens(address beneficiary, uint256 factor) internal {
      _mint(beneficiary, currentReward * factor);
      if ((confirmedBlockHeight - initialConfirmedBlockHeight) % REWARD_HALVING_TIME == 0 && currentReward > MIN_REWARD) {
        currentReward = currentReward / 2;
        if (currentReward < MIN_REWARD) {
          currentReward = MIN_REWARD;
        }
      }
  }

  /**
     submitBlock will be used by users to submit blocks to the contract
   */
  function submitBlock(bytes calldata blockHeader) external override {
    (BlockHeader memory header, bytes32 blockHash) = _parseBytesToBlockHeader(blockHeader);
    // Check if the block has not been submitted before
    require (blocks[blockHash].time == 0);

    bytes32 previousHeaderHash = header.previousHeaderHash;
    
    BlockHeader memory previousBlock = blocks[previousHeaderHash];
    header.blockHeight = previousBlock.blockHeight + 1;

    // If the block is not available
    if (previousBlock.time == 0) {
      return;
    }

    require(_validateBlock(blockHash,header, previousBlock));
    blocks[blockHash] = header;

    // Confirm the current - 6 block
    _confirmBlock(header, blockHash);

    // Clear earliest block data
    _clearBlock(header);
    
  }

  /**
    getTxMerkleRootAtHeight returns the transaction merkle root at height specified or returns 0x0 if none exists.
     The function also checks if the user holds a minimum amount of tokens in their account equivalent to currentReward
   */
  function getTxMerkleRootAtHeight(uint256 height) external view override returns (bytes32) {
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
  function getBlockHeader(uint256 height) external view override returns (BlockHeader memory) {
    /* 
      Using tx.origin is NOT a bug. This is exactly what we want. We want only the holders of the token
      to be able to use this function and not allow any arbitrary contract
    */
     require((balanceOf(tx.origin) >= currentReward) || (blocks[blockHeightToBlockHash[height]].submitter == tx.origin));
     return blocks[blockHeightToBlockHash[height]];
  }

  function getBlockHeader(bytes32 blockHash) external view override returns (BlockHeader memory) {
    /* 
      Using tx.origin is NOT a bug. This is exactly what we want. We want only the holders of the token
      to be able to use this function and not allow any arbitrary contract
    */
    require((balanceOf(tx.origin) >= currentReward) || (blocks[blockHash].submitter == tx.origin));
    return blocks[blockHash];
  }

  /**
      Governance action to reduce the confirmations and set the confirmed blocks
   */
  function updateConfirmations(uint256 confirmations, bytes calldata confirmedBlocks) external override {
    require(balanceOf(msg.sender) > (totalSupply() / 2), "Governance quorum not met");
    // process confirmedBlocks and update blocks at the specified height
    if (confirmations >= MIN_CONFIRMATIONS) {
      CONFIRMATIONS = confirmations;
    } else {
      CONFIRMATIONS = MIN_CONFIRMATIONS;
    }
  }

}

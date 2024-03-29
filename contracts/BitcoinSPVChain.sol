// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;
import {SafeMath} from "./SafeMath.sol";
import {ERC20} from "./ERC20.sol";
import {ISPVChain, ITxVerifier, BlockHeader, IGov} from "./ISPVChain.sol";
import {BitcoinUtils} from "./BitcoinUtils.sol";

contract BitcoinSPVChain is ERC20, ISPVChain, ITxVerifier, IGov {

  using SafeMath for uint256;

  /** Reward halving time for block submission */
  uint32 public constant REWARD_HALVING_TIME = 144 * 30; // every 4320 blocks

  uint32 public constant CONFIRMATION_RETARGET_TIME_PERIOD = 6 * 60 * 60;

  uint32 public constant FORK_DETECTION_RESOLUTION_REWARD_FACTOR = 15;

  /** Number of blocks needed on top of an existing block for confirmation of a certain block */
  uint32 public constant MIN_CONFIRMATIONS = 6;

  /** Minimum Reward to be paid by the contract for submitting blocks */
  uint32 public constant MIN_REWARD = uint32(1 * (10 ** (DECIMALS - 2))); // 0.01 SPVC

  /** Current reward for submitting the blocks */
  uint32 public currentReward = uint32(42 * (10 ** decimals()));

  /** Number of blocks needed on top of an existing block for confirmation of a certain block */
  uint32 public CONFIRMATIONS = 6;

  /** This is needed when doing the difficulty adjustment for the first time and is set by constructor */
  uint32 public initialEpochTime;

  uint32 public checkpointedHeight = 0;

  /** Latest confirmed block height */
  uint32 public confirmedBlockHeight = 0;

  /** First block height */
  uint32 public initialConfirmedBlockHeight = 0;

  /** Time when the fork was detected  */
  uint32 public forkDetectedTime = 0;

  /** When was the last fork retarget time */
  uint32 public confirmationRetargetTimestamp = 0;
  
  /** Block Headers  */
  mapping (bytes32 => BlockHeader) private blocks;

  /** Mapping of block height to block hash */
  mapping (uint256 => bytes32) private blockHeightToBlockHash;

  /** Fork detected event */
  event FORK_DETECTED(uint256 height, bytes32 storedBlockHash, bytes32 collidingBlockHash, uint256 newConfirmations);

  event BLOCK_SUBMITTED(bytes32 currentBlockHash, bytes32 previousBlockHash);

  event BLOCK_CONFIRMED(bytes32 confirmedBlockHash);

  constructor(bytes memory initialConfirmedBlockHeader, uint32 height, uint32 _initialEpochTime) {
      uint32 time = BitcoinUtils._leToUint32(initialConfirmedBlockHeader, 68);
      bytes4 nBits = BitcoinUtils._leToBytes4(initialConfirmedBlockHeader, 72);
      uint32 blockHeight = height;
      address submitter = msg.sender;
      BlockHeader memory header = BlockHeader({
        previousHeaderHash: BitcoinUtils._leToBytes32(initialConfirmedBlockHeader, 4),
        merkleRootHash: BitcoinUtils._leToBytes32(initialConfirmedBlockHeader, 36),
        compactBytes: _makeCompactHeaderBytes(submitter, time, nBits, blockHeight)
      });
      bytes32 blockHash = BitcoinUtils.swapEndian(sha256(abi.encodePacked(sha256(initialConfirmedBlockHeader))));
      blocks[blockHash] = header;
      blockHeightToBlockHash[height] = blockHash;
      confirmedBlockHeight = height;
      initialEpochTime = _initialEpochTime;
      initialConfirmedBlockHeight = height;
  }

  function _parseCompactHeaderBytes(bytes32 compact) private pure returns (address submitter, uint32 time, bytes4 nBits, uint32 height)  {
      submitter = address(uint160(uint256(compact >> (8 * 12))));
      time = uint32(uint256(compact >> (8 * 8))) & 0xffffffff;
      nBits = bytes4(uint32(uint256(compact >> (8 * 4)) & 0xffffffff));
      height = uint32(uint256(compact) & 0xffffffff);
  }

  function _makeCompactHeaderBytes(address submitter, uint32 time, bytes4 nBits, uint32 height) private pure returns (uint256 compact) {
      compact |= uint256(uint160(submitter)) << (8 * 12);
      compact |= uint256(time) << (8 * 8);
      compact |= uint256(uint32(nBits)) << (8 * 4);
      compact |= uint256(height);
      return compact;
  }

  /**
     Parses BlockHeader given as bytes and returns a struct BlockHeader
   */
  function _parseBytesToBlockHeader(bytes calldata blockHeaderBytes) internal view 
        returns (bytes32 merkleRootHash, uint32 time, bytes4 nBits, bytes32 blockHash) {
    require(blockHeaderBytes.length == 80);
    time = BitcoinUtils._leToUint32(blockHeaderBytes, 68);
    nBits = BitcoinUtils._leToBytes4(blockHeaderBytes, 72);
    merkleRootHash = BitcoinUtils._leToBytes32(blockHeaderBytes, 36);
    blockHash = BitcoinUtils.swapEndian(_sha256d(blockHeaderBytes));
  }

  /**
    Validates if the incoming block is valid.
       * Check if the block matches the difficulty target
       * Compute a new difficulty and verify if it's correct
   */
  function _validateBlock(bytes32 blockHash, bytes4 nBits, uint32 blockHeight, uint256 previousBlockCompactBytes) internal view returns (bool result) {
    uint256 target = BitcoinUtils._nBitsToTarget(nBits);
    require(uint256(blockHash) < target); // Require blockHash < target
    uint256 epochStartBlockTime = 0;
    if (blockHeight % 2016 == 0) {
       bytes32 epochStartBlockHash = blockHeightToBlockHash[blockHeight - 2016];
       if (epochStartBlockHash != 0x0) {
         epochStartBlockTime = _getBlockTime(blocks[epochStartBlockHash].compactBytes);
       } else {
         epochStartBlockTime = initialEpochTime;
       }
       uint256 newTarget = BitcoinUtils._retargetAlgorithm(BitcoinUtils._nBitsToTarget(_getBlockNBits(previousBlockCompactBytes)), epochStartBlockTime, _getBlockTime(previousBlockCompactBytes));
       require(bytes4(BitcoinUtils._targetToNBits(newTarget)) == nBits);
    }
    return true;
  }

  /**
     Confirm a block and allocate token to the submitter
   */
  function _confirmBlock(bytes32 previousHeaderHash, uint32 blockHeight) internal {
    bytes32 blockHashToConfirm = previousHeaderHash;
    uint256 confirmations = CONFIRMATIONS;
    uint256 confirmationBlockHeight = blockHeight - confirmations;

    // Check if there is any checkpointed block height, block confirmation cannot happen for blockheight < checkpointed height
    require(confirmationBlockHeight > checkpointedHeight);

    for (uint256 height = blockHeight - 1; height > confirmationBlockHeight; height--) {
      blockHashToConfirm = blocks[blockHashToConfirm].previousHeaderHash;
      if (blockHashToConfirm == 0x0) {
        break;
      }
    }
    uint256 blockCompactBytes = blocks[blockHashToConfirm].compactBytes;

    bytes32 existingConfirmedBlockHash = blockHeightToBlockHash[confirmationBlockHeight];
    
    // Validate if the block is not confirmed already
    if (blockCompactBytes != 0x0 && existingConfirmedBlockHash == 0x0) {
      // Set confirmed block height
      blockHeightToBlockHash[confirmationBlockHeight] = blockHashToConfirm;
      confirmedBlockHeight = uint32(confirmationBlockHeight);
      address submitter = _getBlockSubmitter(blockCompactBytes);

      _allocateTokens(submitter, 10 ** (confirmations / 10));
      emit BLOCK_CONFIRMED(blockHashToConfirm);
    } else if (blockCompactBytes != 0x0 && existingConfirmedBlockHash != 0x0 && existingConfirmedBlockHash != blockHashToConfirm) { // TODO: Check this condition again
      _forkDetected(confirmationBlockHeight, existingConfirmedBlockHash);
    }
  }

  /**
     If a fork has been detected, reset the block hash for the confirmed block heights to 0x0 and
     increase the number of confirmations
   */
  function _forkDetected(uint256 height, bytes32 collidingBlockHash) internal {
      uint32 affectedBlocks = uint32(confirmedBlockHeight - height + 1);
      for (uint256 _h = height; _h <= confirmedBlockHeight; _h++) {
         blockHeightToBlockHash[_h] = 0x0;
      }
      // Increase the confirmations required
      CONFIRMATIONS = (CONFIRMATIONS * 4 ) / 3 + affectedBlocks;
      emit FORK_DETECTED(height, blockHeightToBlockHash[height], collidingBlockHash, CONFIRMATIONS);
      forkDetectedTime = uint32(block.timestamp);

      // Higher rewards for users notifying the forks
      _allocateTokens(msg.sender, FORK_DETECTION_RESOLUTION_REWARD_FACTOR); 
  }

  /**
      Allocate tokens to the beneficiary
   */
  function _allocateTokens(address beneficiary, uint256 factor) internal {
      uint64 reward = currentReward;
      uint64 minReward = MIN_REWARD;
      _mint(beneficiary, reward * factor);
      if (reward > minReward && ((confirmedBlockHeight - initialConfirmedBlockHeight) % REWARD_HALVING_TIME == 0)) {
        reward = reward / 2;
        if (reward < minReward) {
          currentReward = MIN_REWARD;
        } else {
          currentReward = MIN_REWARD;
        }
      }
  }

  /**
     Reset confirmations based on when was the last fork detected. This function does 3 things.
     1. Updates the confirmations to the passed number
     2. Sets the intermediary blocks to confirmed state
     3. Updates the confirmation block height
     4. Rewards users
   */
  function _resetConfirmations(uint32 newConfirmations, uint32 height, bytes32 currentBlockHash, uint256 reward) internal {
          uint256 previousConfirmations = CONFIRMATIONS;

          // Update confirmations to the new value
          CONFIRMATIONS = newConfirmations;
          if (CONFIRMATIONS < MIN_CONFIRMATIONS) {
            CONFIRMATIONS = MIN_CONFIRMATIONS;
          }

          // Update when the last confirmation retarget happened
          confirmationRetargetTimestamp = uint32(block.timestamp);
          
          bytes32 blockHashToConfirm = currentBlockHash;
          uint32 blockHeight = height;
          uint32 heightToConfirm = blockHeight - CONFIRMATIONS;
          // Update the blocks to confirmed
          for (uint256 _height = blockHeight; _height >= (blockHeight - previousConfirmations); _height--) {
            if (height <= heightToConfirm) {
                // Confirm blocks
                blockHeightToBlockHash[height] = blockHashToConfirm;
                emit BLOCK_CONFIRMED(blockHashToConfirm);
            }
            blockHashToConfirm = blocks[blockHashToConfirm].previousHeaderHash;
            if (blockHashToConfirm == 0x0) {
              break;
            }
          }

          // Update the confirmed BlockHeight
          confirmedBlockHeight = heightToConfirm;

          _mint(msg.sender, reward);
  }

  function _getBlockHeight(uint256 blockCompactBytes) private pure returns (uint32) {
     return uint32(blockCompactBytes & 0xffffffff);
  }

  function _getBlockNBits(uint256 blockCompactBytes) private pure returns (bytes4) {
    return bytes4(uint32(blockCompactBytes >> (8 * 4)) & 0xffffffff);
  }

  function _getBlockTime(uint256 blockCompactBytes) private pure returns (uint32) {
    return uint32((blockCompactBytes >> (8 * 8)) & 0xffffffff);
  }

  function _getBlockSubmitter(uint256 blockCompactBytes) private pure returns (address) {
    return address(uint160(blockCompactBytes >> (8 * 12)));
  }

  /**
     submitBlock will be used by users to submit blocks to the contract
   */
  function submitBlock(bytes calldata blockHeader) external override {
    bytes32 previousHeaderHash = BitcoinUtils._leToBytes32(blockHeader, 4);
    uint256 previousBlockCompactBytes = blocks[previousHeaderHash].compactBytes;
    uint32 blockHeight = _getBlockHeight(previousBlockCompactBytes) + 1;
    require (previousBlockCompactBytes != 0x0);
    (bytes32 merkleRootHash, uint32 time, bytes4 nBits, bytes32 blockHash) = _parseBytesToBlockHeader(blockHeader);
    // Check if the block has not been submitted before
    require (blocks[blockHash].compactBytes == 0x0);
    BlockHeader memory header = BlockHeader({
      previousHeaderHash: previousHeaderHash,
      merkleRootHash: merkleRootHash,
      compactBytes: _makeCompactHeaderBytes(msg.sender, time, nBits, blockHeight)
    });
    require(_validateBlock(blockHash, nBits, blockHeight, previousBlockCompactBytes));
    blocks[blockHash] = header;
    emit BLOCK_SUBMITTED(blockHash, previousHeaderHash);

    // Confirm the current - 6 block
    _confirmBlock(header.previousHeaderHash, blockHeight);

    // Reset confirmations
    if (CONFIRMATIONS > MIN_CONFIRMATIONS) {
      if ((block.timestamp - forkDetectedTime) >= CONFIRMATION_RETARGET_TIME_PERIOD 
          && (block.timestamp - confirmationRetargetTimestamp) >= CONFIRMATION_RETARGET_TIME_PERIOD) {
          uint32 newConfirmations = (CONFIRMATIONS * 3) / 4;
          uint256 reward = currentReward * FORK_DETECTION_RESOLUTION_REWARD_FACTOR;
          _resetConfirmations(newConfirmations, blockHeight, blockHash, reward);
      }
    }
    
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
     require((balanceOf(tx.origin) >= currentReward) || (_getBlockSubmitter(blocks[blockHeightToBlockHash[height]].compactBytes) == tx.origin));
     return blocks[blockHeightToBlockHash[height]];
  }

  function getBlockHeader(bytes32 blockHash) external view override returns (BlockHeader memory) {
    /* 
      Using tx.origin is NOT a bug. This is exactly what we want. We want only the holders of the token
      to be able to use this function and not allow any arbitrary contract
    */
    require((balanceOf(tx.origin) >= currentReward) || (_getBlockSubmitter(blocks[blockHash].compactBytes) == tx.origin));
    return blocks[blockHash];
  }

  function _sha256d(bytes32 data1, bytes32 data2) internal view returns (bytes32 result) {
        assembly {
            let ptr := mload(0x40)
            mstore(ptr, data1)
            mstore(add(ptr, 0x20), data2)
            pop(staticcall(gas(), 2, ptr, 0x40, ptr, 0x20))
            pop(staticcall(gas(), 2, ptr, 0x20, ptr, 0x20))
            result := mload(ptr)
        }
  }

  function _sha256d(bytes calldata bz) internal view returns (bytes32 result) {
        assembly {
            let ptr := mload(0x40)
            calldatacopy(ptr, bz.offset, 0x50)
            let res := mload(0x40)
            pop(staticcall(gas(), 2, ptr, 0x50, res, 0x20))
            pop(staticcall(gas(), 2, res, 0x20, res, 0x20))
            result := mload(res)
        }
  }

  function verifyTxInclusionProof(bytes32 txId, uint32 blockHeight, uint256 index, bytes calldata hashes) external view returns (bool result) {
      bytes32 blockHash = blockHeightToBlockHash[blockHeight];
      require((balanceOf(tx.origin) >= currentReward) || (_getBlockSubmitter(blocks[blockHash].compactBytes) == tx.origin));
      bytes32 root = txId;
      uint256 len = (hashes.length / 32);
      bytes32 _h;
      for (uint256 i = 0; i < len; i++) {
         _h = bytes32(hashes[i * 32: (i + 1) * 32]);
        if (index & 1 == 1) {
          root = _sha256d(_h, root);
        } else {
          root = _sha256d(root, _h);
        }
        index = index >> 1;
      }
      return (BitcoinUtils.swapEndian(root) == blocks[blockHash].merkleRootHash);
  }

  /**
      Governance action to reduce the confirmations and set the confirmed blocks.

      This can be executed once every CONFIRMATION RETARGET WINDOW which is currently set to 8 hours.
   */
  function updateConfirmations(uint32 confirmations, bytes32 currentBlockHash) external override {
    require(balanceOf(msg.sender) > (totalSupply() / 2), "Governance quorum not met");
    // process confirmedBlocks and update blocks at the specified height
    if (confirmations > MIN_CONFIRMATIONS) {
      CONFIRMATIONS = confirmations;
    } else {
      CONFIRMATIONS = MIN_CONFIRMATIONS;
    }

    uint32 currentBlockHeight = _getBlockHeight(blocks[currentBlockHash].compactBytes);
    checkpointedHeight = currentBlockHeight;

    // Reset the confirmations and confirm the blocks based on the new block height
    // Reward 0.5% for executing the governance action
    uint256 reward = (totalSupply() / 200);
    _resetConfirmations(CONFIRMATIONS, currentBlockHeight, currentBlockHash, reward);

  }

}

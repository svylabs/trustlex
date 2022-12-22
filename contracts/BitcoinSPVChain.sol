// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;
import {SafeMath} from "./SafeMath.sol";
import {ERC20} from "./ERC20.sol";
import {ISPVChain, BlockHeader} from "./ISPVChain.sol";


contract BitcoinSPVChain is ERC20, ISPVChain {

  using SafeMath for uint256;

  /** Retarget period for Bitcoin Difficulty Adjustment */
  uint256 public constant RETARGET_PERIOD = 2 * 7 * 24 * 60 * 60;  // 2 weeks in seconds

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

  function _parseBytesToBlockHeader(bytes calldata blockHeaderBytes) view public returns (BlockHeader memory result) {
    require(blockHeaderBytes.length >= 80);
    result = BlockHeader({
      previousHeaderHash: _leToBytes32(blockHeaderBytes, 4),
      merkleRootHash: _leToBytes32(blockHeaderBytes, 36),
      time: _leToUint32(blockHeaderBytes, 68),
      nBits: _leToBytes4(blockHeaderBytes, 72),
      blockHash: sha256(abi.encodePacked(sha256(blockHeaderBytes[0: 80]))),
      blockHeight: 0,
      submitter: msg.sender
    });
    return result;
  }


  
  // If block is valid accept the block and store it.
    /**
      - Check if the block hash matches the difficulty target
      - Compute a new difficulty target
     */
  function _validateBlock(BlockHeader memory header, BlockHeader memory previousBlock) public view returns (bool result) {
    uint256 target = _nBitsToTarget(header.nBits);
    require(uint256(header.blockHash) < target); // Require blockHash < target

    uint256 epochStartBlockTime = 0;
    if (header.blockHeight % 2016 == 1) {
       bytes32 epochStartBlockHash = blockHeightToBlockHash[header.blockHeight - 2016];
       if (epochStartBlockHash != 0x0) {
         epochStartBlockTime = blocks[epochStartBlockHash].time;
       } else {
         epochStartBlockTime = initialEpochTime;
       }
       uint256 newTarget = _retargetAlgorithm(_nBitsToTarget(previousBlock.nBits), epochStartBlockTime, previousBlock.time);
       require(newTarget == _nBitsToTarget(header.nBits));
    }
    return true;
  }

  function _confirmBlock(BlockHeader memory header) private {
    bytes32 previousHeaderHash = header.previousHeaderHash;
    for (uint256 height = header.blockHeight - 1; height > header.blockHeight - CONFIRMATIONS; height--) {
      previousHeaderHash = blocks[previousHeaderHash].previousHeaderHash;
      if (previousHeaderHash == 0x0) {
        break;
      }
    }
    if (previousHeaderHash != 0x0) {
      // Set confirmed block height
      blockHeightToBlockHash[header.blockHeight - CONFIRMATIONS] = previousHeaderHash;
      confirmedBlocks++;

      _allocateTokens(msg.sender);
    }
  }

  function _clearBlock(BlockHeader memory header) private {
    bytes32 blockHeaderHashToClear = blockHeightToBlockHash[header.blockHeight - BLOCKS_TO_STORE];
    if (blockHeaderHashToClear != 0x0) {
      delete blocks[blockHeaderHashToClear];
      delete blockHeightToBlockHash[header.blockHeight - BLOCKS_TO_STORE];
    }
  }

  function _allocateTokens(address beneficiary) internal {
      _mint(beneficiary, currentReward);
      if (confirmedBlocks % REWARD_HALVING_TIME == 0 && currentReward > MIN_REWARD) {
        currentReward = currentReward / 2;
        if (currentReward < MIN_REWARD) {
          currentReward = MIN_REWARD;
        }
      }
  }

  function submitBlock(bytes calldata blockHeader) external {
    BlockHeader memory header = _parseBytesToBlockHeader(blockHeader);
    bytes32 previousHeaderHash = _leToBytes32(blockHeader, 4);
    
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

  function getTxMerkleRootAtHeight(uint256 height) external view returns (bytes32) {
     // TODO: Validate the presence of token and return the merkle root
     require(balanceOf(tx.origin) >= currentReward);
     return blocks[blockHeightToBlockHash[height]].merkleRootHash;
  }

  function getBlockHeader(uint256 height) external view returns (BlockHeader memory) {
     require(balanceOf(tx.origin) >= currentReward);
     return blocks[blockHeightToBlockHash[height]];
  }


  /**
     input: 0x...01020304....., 3
     output: 0x04030201
   */
  function _leToUint32(bytes calldata bz, uint startIndex) pure public returns (uint32 result) {
    bytes4 v = bytes4(bz[startIndex: startIndex+4]);

    // swap bytes
    v = ((v >> 8) & 0x00FF00FF) |
         ((v & 0x00FF00FF) << 8);
    // swap 2-byte long pairs
    v = ((v >> 16) & 0x0000FFFF) |
         ((v & 0x0000FFFF) << 16);

    result = uint32(v);
    
    return result;
  }

  /**
     input: 0x...01020304....., 3
     output: 0x04030201
   */
  function _leToBytes4(bytes calldata bz, uint startIndex) pure public returns (bytes4 result) {

    result = bytes4(bz[startIndex: startIndex+4]);

    // swap bytes
    result = ((result >> 8) & 0x00FF00FF) |
         ((result & 0x00FF00FF) << 8);
    // swap 2-byte long pairs
    result = ((result >> 16) & 0x0000FFFF) |
         ((result & 0x0000FFFF) << 16);

    return result;
  }

  /**
      input: 0x...000102030405060708090A0B0C0D0E0F0102030405060708090A0B0C0D0E0F...., 32
      output: 0x0F0E0D0C0B0A090807060504030201000F0E0D0C0B0A09080706050403020100
   */

  function _leToBytes32(bytes calldata bz, uint startIndex) pure public returns (bytes32 result) {

    result = bytes32(bz[startIndex: startIndex+32]);

    // swap bytes
    result = ((result >> 8) & 0x00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF) |
            ((result & 0x00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF) << 8);
    // swap 2-byte long pairs
    result = ((result >> 16) & 0x0000FFFF0000FFFF0000FFFF0000FFFF0000FFFF0000FFFF0000FFFF0000FFFF) |
            ((result & 0x0000FFFF0000FFFF0000FFFF0000FFFF0000FFFF0000FFFF0000FFFF0000FFFF) << 16);
    // swap 4-byte long pairs
    result = ((result >> 32) & 0x00000000FFFFFFFF00000000FFFFFFFF00000000FFFFFFFF00000000FFFFFFFF) |
            ((result & 0x00000000FFFFFFFF00000000FFFFFFFF00000000FFFFFFFF00000000FFFFFFFF) << 32);
    // swap 8-byte long pairs
    result = ((result >> 64) & 0x0000000000000000FFFFFFFFFFFFFFFF0000000000000000FFFFFFFFFFFFFFFF) |
            ((result & 0x0000000000000000FFFFFFFFFFFFFFFF0000000000000000FFFFFFFFFFFFFFFF) << 64);
    // swap 16-byte long pairs
    result = (result >> 128) | (result << 128);
    return result;
  }

  function _nBitsToTarget(bytes4 nBits) pure public returns (uint256 target) {
    uint256 _mantissa = uint256(bytes32(nBits)) & (0xffffff);
    uint256 _exponent = ((uint256(bytes32(nBits)) & (0xff000000)) >> 24).sub(3);
    return _mantissa.mul(256 ** _exponent);
  }

  /** 
    Code copied from
    https://github.com/summa-tx/bitcoin-spv/blob/master/solidity/contracts/ViewBTC.sol#L493
   */
  function _retargetAlgorithm(
        uint256 _previousTarget,
        uint256 _firstTimestamp,
        uint256 _secondTimestamp
    ) internal pure returns (uint256) {
        uint256 _elapsedTime = _secondTimestamp.sub(_firstTimestamp);

        // Normalize ratio to factor of 4 if very long or very short
        if (_elapsedTime < RETARGET_PERIOD.div(4)) {
            _elapsedTime = RETARGET_PERIOD.div(4);
        }
        if (_elapsedTime > RETARGET_PERIOD.mul(4)) {
            _elapsedTime = RETARGET_PERIOD.mul(4);
        }

        /*
            NB: high targets e.g. ffff0020 can cause overflows here
                so we divide it by 256**2, then multiply by 256**2 later
                we know the target is evenly divisible by 256**2, so this isn't an issue
        */
        uint256 _adjusted = _previousTarget.div(65536).mul(_elapsedTime);
        return _adjusted.div(RETARGET_PERIOD).mul(65536);
    }

}

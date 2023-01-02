// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;
import {SafeMath} from "./SafeMath.sol";

library BitcoinUtils {
  
  using SafeMath for uint256;

  /** Retarget period for Bitcoin Difficulty Adjustment */
  uint256 public constant RETARGET_PERIOD = 2 * 7 * 24 * 60 * 60;  // 2 weeks in seconds

  uint256 public constant MAX_TARGET = 0x00000000FFFF0000000000000000000000000000000000000000000000000000;

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

    result = swapEndian(result);
  }

  function swapEndian(bytes32 bz) pure internal returns (bytes32 result) {

    result = bz;

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
    uint256 _mantissa = uint256(uint32(nBits) & 0x007fffff);
    uint256 _exponent = (uint256(uint32(nBits) & uint32(0xff000000)) >> 24).sub(3);
    return _mantissa.mul(256 ** _exponent);
  }

  function _targetToNBits(uint256 target) pure public returns (uint32 compact) {
     if (target == 0) {
        return 0;
     }
     // Since the base for the exponent is 256, the exponent can be treated
     // as the number of bytes.  So, shift the number right or left
     // accordingly.  This is equivalent to:
     // mantissa = mantissa / 256^(exponent-3)
	uint32 mantissa;
	uint32 exponent = 0;
        uint256 _target = target;
        while (_target != 0) {
                exponent++;
                _target >>= 8;
        }
        if (exponent <= 3) {
		mantissa = uint32(target & 0xffffffff);
		mantissa <<= 8 * (3 - exponent);
	} else {
		// Use a copy to avoid modifying the caller's original number.
		mantissa = uint32((target >> (8 * (exponent - 3))) & 0xffffffff);
	}

	// When the mantissa already has the sign bit set, the number is too
	// large to fit into the available 23-bits, so divide the number by 256
	// and increment the exponent accordingly.
	if ((mantissa & 0x00800000) != 0) {
		mantissa >>= 8;
		exponent++;
	}

	// Pack the exponent, sign bit, and mantissa into an unsigned 32-bit
	// int and return it.
	compact = uint32(exponent<<24) | mantissa;

	return compact;
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
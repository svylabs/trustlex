pragma solidity >=0.4.22 <0.9.0;

import {ITxVerifier} from './ISPVChain.sol';
import {BitcoinUtils} from './BitcoinUtils.sol';

contract TrustedBitcoinSPVChain is ITxVerifier {

    address owner;

    mapping (uint256 => bytes32) merkleRoots;

    constructor() {
        owner = msg.sender;
    }

    function AddHeader(uint256 height, bytes32 merkleRoot) external  {
        if (msg.sender == owner) {
          merkleRoots[height] = merkleRoot;
        }
    }

    function verifyTxInclusionProof(bytes32 txId, uint32 blockHeight, uint256 index, bytes calldata hashes) external view returns (bool result) {
      bytes32 root = txId;
      uint256 len = (hashes.length / 32);
      bytes32 _h;
      for (uint256 i = 0; i < len; i++) {
         _h = bytes32(hashes[i * 32: (i + 1) * 32]);
        if (index & 1 == 1) {
          root = BitcoinUtils._sha256d(_h, root);
        } else {
          root = BitcoinUtils._sha256d(root, _h);
        }
        index = index >> 1;
      }
      return (BitcoinUtils.swapEndian(root) == merkleRoots[blockHeight]);
  }
}
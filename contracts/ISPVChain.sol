// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

struct BlockHeader {
        bytes32 previousHeaderHash;
        bytes32 merkleRootHash;
        uint256 compactBytes;
}

interface ISPVChain {
      function submitBlock(bytes calldata blockHeaderBytes) external;
      function getTxMerkleRootAtHeight(uint256 height) external view returns (bytes32);
      function getBlockHeader(uint256 height) external view returns (BlockHeader memory);
      function getBlockHeader(bytes32 blockHash) external view returns (BlockHeader memory);
}

interface ITxVerifier {
      function verifyTxInclusionProof(bytes32 txId, uint32 blockHeight, uint256 index, bytes calldata hashes) external view returns (bool result);
}

interface IGov {
      function updateConfirmations(uint32 confirmations, bytes32 currentBlockHash) external;
      //function createOrderBookContract(address token) external;
      //function setForkBlock(uint32 blockHeight, bytes calldata blockHeader) external; // should invalidate other blocks in front of it and should confirm this block
}

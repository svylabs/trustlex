// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

struct BlockHeader {
        bytes32 previousHeaderHash;
        bytes32 merkleRootHash;
        uint256 blockHeight;
        address submitter;
        uint32 time;
        bytes4 nBits;
}

interface ISPVChain {
      function submitBlock(bytes calldata blockHeaderBytes) external;
      function getTxMerkleRootAtHeight(uint256 height) external view returns (bytes32);
      function getBlockHeader(uint256 height) external view returns (BlockHeader memory);
      function getBlockHeader(bytes32 blockHash) external view returns (BlockHeader memory);
}

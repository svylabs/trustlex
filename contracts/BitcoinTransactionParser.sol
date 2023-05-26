pragma solidity ^0.8.0;

contract BitcoinTransactionParser {
    struct TransactionInput {
        bytes32 prevTransactionHash;
        uint outputIndex;
        bytes scriptSig;
        uint sequence;
    }

    struct TransactionOutput {
        uint value;
        bytes scriptPubKey;
    }

    struct ParsedTransaction {
        uint version;
        uint lockTime;
        TransactionInput[10] inputs;
        TransactionOutput[10] outputs;
    }
    
    function hasOutput(bytes calldata transactionData, uint256 value, bytes calldata scriptPubKey) external pure returns (bool) {
        uint offset = 0;
        ParsedTransaction memory parsedTx;
        parsedTx.version = parseUint32LE(transactionData, offset);
        offset += 4;
        bool found = false;
    
        uint inputsCount;
        (inputsCount, offset) = parseVarInt(transactionData, offset);
        require(inputsCount == 1, "Input counts is not 1");

        for (uint i = 0; i < inputsCount; i++) {
            TransactionInput memory input;

            //input.prevTransactionHash = bytes32(transactionData[offset: offset+32]);
            offset += 32;

            //input.outputIndex = parseUint32LE(transactionData, offset);
            offset += 4;

            uint scriptSigLength;
            (scriptSigLength, offset) = parseVarInt(transactionData, offset);

            //input.scriptSig = transactionData[offset: offset+scriptSigLength];
            offset += scriptSigLength;

            //input.sequence = parseUint32LE(transactionData, offset);
            offset += 4;

            parsedTx.inputs[i] = input;
        }

        uint outputsCount;
        (outputsCount, offset) = parseVarInt(transactionData, offset);
        require(outputsCount == 2, "Output counts is not 2");

        for (uint i = 0; i < outputsCount; i++) {
            TransactionOutput memory output;

            output.value = parseUint64LE(transactionData, offset);
            offset += 8;

            uint scriptPubKeyLength;
            (scriptPubKeyLength, offset) = parseVarInt(transactionData, offset);

            output.scriptPubKey = transactionData[offset: offset + scriptPubKeyLength];
            if (keccak256(output.scriptPubKey) == keccak256(scriptPubKey) && output.value >= value) {
                // output is found and has the required value
                found = true;
            }
            offset += scriptPubKeyLength;

            parsedTx.outputs[i] = output;
        }

        parsedTx.lockTime = parseUint32LE(transactionData, offset);
        if (parsedTx.lockTime > 0) {
            found = false;
        }

        return found;
    }

    function parseVarInt(bytes calldata data, uint offset) private pure returns (uint, uint) {
        uint8 prefix = uint8(data[offset]);

        if (prefix < 0xFD) {
            return (uint(prefix), offset + 1);
        } else if (prefix == 0xFD) {
            return (parseUint16LE(data, offset + 1), offset + 3);
        } else if (prefix == 0xFE) {
            return (parseUint32LE(data, offset + 1), offset + 5);
        } else {
            return (parseUint64LE(data, offset + 1), offset + 9);
        }
    }

    function parseUint16LE(bytes calldata data, uint offset) private pure returns (uint) {
        return uint(uint16(uint8(data[offset])) | (uint16(uint8(data[offset + 1])) << 8));
    }

    function parseUint32LE(bytes calldata data, uint offset) private pure returns (uint) {
        return uint(uint32(uint8(data[offset])) |
            (uint32(uint8(data[offset + 1])) << 8) |
            (uint32(uint8(data[offset + 2])) << 16) |
            (uint32(uint8(data[offset + 3])) << 24));
    }

    function parseUint64LE(bytes calldata data, uint offset) private pure returns (uint) {
        return uint(uint64(uint8(data[offset])) |
            (uint64(uint8(data[offset + 1])) << 8) |
            (uint64(uint8(data[offset + 2])) << 16) |
            (uint64(uint8(data[offset + 3])) << 24) |
            (uint64(uint8(data[offset + 4])) << 32) |
            (uint64(uint8(data[offset + 5])) << 40) |
            (uint64(uint8(data[offset + 6])) << 48) |
            (uint64(uint8(data[offset + 7])) << 56));
    }

    function parseUint(bytes memory data, uint offset) private pure returns (uint) {
        uint value;

        for (uint i = offset; i < offset + 32; i++) {
            value = value * 256 + uint(uint8(data[i]));
        }

        return value;
    }

    function checkOutputExists(bytes calldata transactionData, uint outputIndex) public pure returns (bool) {
        uint offset;

        // Skip the version
        offset += 4;

        uint inputsCount;
        (inputsCount, offset) = parseVarInt(transactionData, offset);

        // Skip the inputs
        offset += inputsCount;

        uint outputsCount;
        (outputsCount, offset) = parseVarInt(transactionData, offset);

        // Check if the specified output index is within bounds
        if (outputIndex >= outputsCount) {
            return false;
        }

        // Skip the outputs
        for (uint i = 0; i < outputsCount; i++) {
            uint scriptPubKeyLength;
            (scriptPubKeyLength, offset) = parseVarInt(transactionData, offset);
            offset += scriptPubKeyLength;

            // If the output index matches the specified index, return true
            if (i == outputIndex) {
                return true;
            }
        }

        // Output not found
        return false;
    }
}

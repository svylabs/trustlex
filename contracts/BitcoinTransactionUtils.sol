// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library BitcoinTransactionUtils {

    /**
      First version of the script to generate a trustlex address. Doesn't have any way to recover funds in case the confirmation time took too long.
     */

    function getTrustlexScript(address contractId, uint256 orderId, uint256 fulfillmentId, bytes20 pubkeyHash, uint256 orderTime) public view returns (bytes memory) {
        bytes32 hashedOrderId = keccak256(bytes.concat(bytes20(contractId), bytes32(orderId), bytes32(fulfillmentId), pubkeyHash, bytes32(orderTime)));
        bytes4 shortOrderId = bytes4(hashedOrderId);
        // ORDER_ID OP_DROP OP_DUP OP_HASH160 <pubkeyHash> OP_EQUAL_VERIFY OP_CHECK_SIG
        bytes memory script = bytes.concat(
            bytes1(0x04), // length of order id
            shortOrderId,
            bytes4(0x7576a914), // OP_DROP OP_DUP OP_HASH160 LENGTH_OF_PUBKEY_HASH
            pubkeyHash,
            bytes2(0x88ac) // OP_EQUALVERIFY OP_CHECKSIG
        );
        return bytes.concat(
            bytes2(0x0020), 
            sha256(script)
        );
    }

    /*
       First iteration of the script, it's not secure.
    */

    function getTrustlexScriptV1(address contractId, uint256 orderId, uint256 fulfillmentId, bytes20 pubkeyHash, uint256 orderTime, bytes20 redeemerPubkeyHash, uint32 lockTime) public pure returns (bytes memory)  {
        bytes32 hashedOrderId = keccak256(bytes.concat(bytes20(contractId), bytes32(orderId), bytes32(fulfillmentId), pubkeyHash, bytes32(orderTime)));
        bytes4 shortOrderId = bytes4(hashedOrderId);
        // ORDER_ID OP_DROP OP_DUP OP_HASH160 <pubkeyHash> OP_EQUAL_VERIFY OP_CHECK_SIG
        bytes memory script = bytes.concat(
            bytes1(0x04), // length of order id
            shortOrderId, 
            bytes4(0x7576a914), // OP_DROP OP_DUP OP_HASH160 LENGTH_OF_PUBKEY_HASH:
            pubkeyHash,
            bytes2(0x8764),
            encodeNumber(lockTime), // timestamp
            bytes5(0xb17576a914), // OP_CHECKLOCKTIMEVERIFY OP_DROP OP_DUP  OP_HASH160 LENGTH_OF_PUBKEY_HASH
            bytes20(redeemerPubkeyHash), // Redeemer public key
            bytes3(0x8868ac) // OP_EQUALVERIFYOP_ENDIF OP_CHECKSIG
        );
        //return script;
        return bytes.concat(
            bytes2(0x0020), 
            sha256(script)
        );
    }

    
    /*
     This is based on HTLC, and is secure to transact. 
     - User that sends to this address has a way to recover the funds after a few days.
     - Ensures atomic swap(but also relies on the receiver to act after receiving funds)
    */
    function getTrustlexScriptV2(
        address contractId, 
        uint256 orderFulfillmentId, 
        bytes20 pubkeyHash, 
        uint256 orderTime, 
        bytes20 redeemerPubkeyHash, 
        uint32 lockTime, 
        bytes32 hashedSecret) public pure returns (bytes memory) {
        bytes32 hashedOrderId = keccak256(bytes.concat(bytes20(contractId), bytes32(orderFulfillmentId >> 128), bytes32(orderFulfillmentId & ((1 << 128 - 1))), pubkeyHash, bytes32(orderTime)));
        bytes4 shortOrderId = bytes4(hashedOrderId);
        bytes memory script = bytes.concat(
            bytes1(0x04), // length of order id
            shortOrderId, 
            bytes4(0x7576a914), // OP_DROP OP_DUP OP_HASH160 LENGTH_OF_PUBKEY_HASH:
            pubkeyHash,
            bytes5(0x87637caa20), // OP_EQUAL OP_IF OP_SWAP OP_HASH256  LENGTH_OF_HASHEDSECRET
            hashedSecret,
            bytes2(0x8867), // OP_EQUALVERIFY OP_ELSE
            encodeNumber(lockTime), // timestamp 
            bytes5(0xb17576a914), // OP_CHECKLOCKTIMEVERIFY OP_DROP OP_DUP  OP_HASH160 LENGTH_OF_PUBKEY_HASH
            bytes20(redeemerPubkeyHash), // Redeemer public key
            bytes3(0x8868ac) // OP_EQUALVERIFY OP_ENDIF OP_CHECKSIG
        );
        //return script;
        //emit BYTES(script);
        return bytes.concat(
            bytes2(0x0020), 
            sha256(script)
        );
    }

    /*
     This is based on HTLC, and is secure to transact. 
     - User that sends to this address has a way to recover the funds after a few days.
     - Ensures atomic swap(but also relies on the receiver to act after receiving funds)
    */
    function getTrustlexScriptV3(
        address contractId, 
        uint256 orderFulfillmentId, 
        bytes20 pubkeyHash, 
        uint256 orderTime, 
        bytes20 redeemerPubkeyHash, 
        uint32 lockTime, 
        bytes32 hashedSecret) public pure returns (bytes memory) {
        bytes32 hashedOrderId = keccak256(bytes.concat(bytes20(contractId), bytes32(orderFulfillmentId >> (160)), bytes32(orderFulfillmentId & ((1 << 160 - 1))), pubkeyHash, bytes32(orderTime)));
        bytes4 shortOrderId = bytes4(hashedOrderId);
        bytes memory script = bytes.concat(
            bytes1(0x04), // length of order id
            shortOrderId, 
            bytes4(0x7576a914), // OP_DROP OP_DUP OP_HASH160 LENGTH_OF_PUBKEY_HASH:
            pubkeyHash,
            bytes5(0x87637caa20), // OP_EQUAL OP_IF OP_SWAP OP_HASH256  LENGTH_OF_HASHEDSECRET
            hashedSecret,
            bytes2(0x8867), // OP_EQUALVERIFY OP_ELSE
            encodeNumber(lockTime), // timestamp 
            bytes5(0xb17576a914), // OP_CHECKLOCKTIMEVERIFY OP_DROP OP_DUP  OP_HASH160 LENGTH_OF_PUBKEY_HASH
            bytes20(redeemerPubkeyHash), // Redeemer public key
            bytes3(0x8868ac) // OP_EQUALVERIFY OP_ENDIF OP_CHECKSIG
        );
        //return script;
        //emit BYTES(script);
        return bytes.concat(
            bytes2(0x0020), 
            sha256(script)
        );
    }

    function hasOutput(bytes calldata transactionData, uint256 value, bytes calldata scriptPubKey) external pure returns (bool) {
        uint offset = 0;
        //parsedTx.version = parseUint32LE(transactionData, offset);
        offset += 4; // increment version
        bool found = false;
    
        uint inputsCount;
        (inputsCount, offset) = parseVarInt(transactionData, offset);
        require(inputsCount == 1, "Input counts is not 1");

        for (uint i = 0; i < inputsCount; i++) {
            //TransactionInput memory input;

            //input.prevTransactionHash = bytes32(transactionData[offset: offset+32]);
            offset += 32; // prevHash

            //input.outputIndex = parseUint32LE(transactionData, offset);
            offset += 4; // outputIndex

            uint scriptSigLength;
            (scriptSigLength, offset) = parseVarInt(transactionData, offset);

            //input.scriptSig = transactionData[offset: offset+scriptSigLength];
            offset += scriptSigLength;

            //input.sequence = parseUint32LE(transactionData, offset);
            offset += 4;

            //parsedTx.inputs[i] = input;
        }

        uint outputsCount;
        (outputsCount, offset) = parseVarInt(transactionData, offset);
        require(outputsCount == 2, "Output counts is not 2");

        for (uint i = 0; i < outputsCount; i++) {
            //TransactionOutput memory output;

            uint256 outputValue = parseUint64LE(transactionData, offset);
            offset += 8;

            uint scriptPubKeyLength;
            (scriptPubKeyLength, offset) = parseVarInt(transactionData, offset);

            bytes memory outputScriptPubKey = transactionData[offset: offset + scriptPubKeyLength];
            if (keccak256(outputScriptPubKey) == keccak256(scriptPubKey) && outputValue >= value) {
                // output is found and has the required value
                found = true;
            }
            offset += scriptPubKeyLength;

            //parsedTx.outputs[i] = output;
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

    function scriptNumSize(uint256 num) public pure returns (uint) {
        if(num > 0x7fffffff) {
            return 5;
        } else if (num > 0x7fffff) {
            return 4;
        } else if (num > 0x7fff) {
            return 3;
        } else if (num  > 0x7f) {
            return 2;
        } else if (num > 0x00) {
            return 1;
        }
        return 0;
    }

    function encodeNumber(uint256 number) public pure returns (bytes memory ret) {
        uint256 size = scriptNumSize(number);
        uint8 current = 0;
        for (uint256 i = 0; i < size; ++i) {
            current = (uint8(number) & 0xff);
            if (i == (size -1) && (current & 0x80 > 0)) {
                ret = bytes.concat(ret, bytes1(0x00));
            } else {
                ret = bytes.concat(ret, bytes1(current));
            }
            number = number >> 8;
        }
        return bytes.concat(
            bytes1(uint8(ret.length)),
            ret
        );
    }

}

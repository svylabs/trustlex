
var BitcoinUtils = artifacts.require("BitcoinUtils");
var SafeMath = artifacts.require('SafeMath');
const spvchain = artifacts.require("BitcoinSPVChain");
const fs = require('fs');

contract("BitcoinSPVChain: Happy Case", (accounts) => {
    const [owner, user1, user2] = accounts;
    const txParams = { from: owner };
    beforeEach(async function() {
        spvchain.link(await BitcoinUtils.deployed());
        spvchain.link(await SafeMath.deployed());
        this.bitcoinSPVChain = await spvchain.new('0x0000a0203d0b88d3fded0b806262f5889ce83b3b21b2f0db0097080000000000000000006516022a0c1902642fc1f1d76084dea42770a2c572694d1af44e872a19400743f2f84363aef90817923155bf', 758015, 1664333794, txParams);
    });

    it ('submit block', async function() {
        const res = await this.bitcoinSPVChain.submitBlock('0x00e07e2e56f4bfdfb9d72f106f29dcae91b7ca375221f201f3090000000000000000000023f4af32986fd85064522a5a8fa6b96fec66be9c6fcf16c3aca58cfd52dba250d2fa436372e707170acc1b27', txParams);
        //console.log(res);
        const header = await this.bitcoinSPVChain.getBlockHeader.call('0x00000000000000000005e5ddf901baa6810c88926d55f21d0fee8969cf3447c1', txParams);
        ///assert.equal(header.blockHeight, 758016, "Header height doesn't match");
        assert.equal(header.previousHeaderHash, '0x0000000000000000000009f301f2215237cab791aedc296f102fd7b9dfbff456', 'Previous header hash doesn\'t match');
        assert.equal(header.merkleRootHash, '0x50a2db52fd8ca5acc316cf6f9cbe66ec6fb9a68f5a2a526450d86f9832aff423', 'Transaction merkle root hash doesn\'t match');
        //assert.equal(header.nBits, '0x1707e772', 'difficulty bits doesn\'t match');
    });
})

fs.readFile('./test/files/difficulty_change_test.csv', 'utf8', (err, data) => {
    contract("BitcoinSPVChain: Test difficulty change", (accounts) => {
        const [owner, user1, user2] = accounts;
        const txParams = { from: owner };

        beforeEach(async function() {
        });

        
        const lines = data.split("\n");
        const rand = Math.floor(Math.random() * 100) % 4 ;
        lines.forEach((line, i) => {
            it ('submit block - ' + i + ((i % 4 != rand)? " skipped": ""), async function() {
                if (i % 4 != rand) {
                    return;
                }    
                const parts = line.split(" ");
                if (parts[0] === '') {
                    return;
                }
                console.log("Executing..." + i);
                spvchain.link(await BitcoinUtils.deployed());
                spvchain.link(await SafeMath.deployed());
                this.bitcoinSPVChain = await spvchain.new(parts[0], parseInt(parts[1]), parseInt(parts[2]), txParams);
                const res = await this.bitcoinSPVChain.submitBlock(parts[3], txParams);
                console.log(res.receipt.gasUsed);
                const header = await this.bitcoinSPVChain.getBlockHeader.call(parts[4], txParams);
                //assert.equal(header.blockHeight, parseInt(parts[1]) + 1, "Header height doesn't match");
                assert.equal(header.merkleRootHash, parts[5], 'Transaction merkle root hash doesn\'t match');
                assert.equal(header.previousHeaderHash, parts[6], 'Previous header hash doesn\'t match');
            });
        });
    });

})

fs.readFile('./test/files/confirmation_test.csv', 'utf8', (err, data) => {
    contract("BitcoinSPVChain: Test confirmation", (accounts) => {
        const [owner, user1, user2] = accounts;
        const txParams = { from: owner };
        const lines = data.split("\n");

        const parts = lines[0].split(" ");
        const length = lines.length - 2;
        
        lines.forEach((line, i) => {
            it ('submit block - ' + i, async function() {
                const parts = line.split(" ");
                if (parts[0] === '') {
                    return;
                }
                if (i == 0) {
                    console.log("Creating the contract..");
                    spvchain.link(await BitcoinUtils.deployed());
                    spvchain.link(await SafeMath.deployed());
                    this.bitcoinSPVChain = await spvchain.new(parts[1], parseInt(parts[2]), 1630333672, txParams);
                } else {
                    console.log("Executing..." + i);
                    const res = await this.bitcoinSPVChain.submitBlock(parts[1], txParams);
                    console.log(res.receipt.gasUsed, res.receipt.logs.length);
                    //console.log(res.receipt.logs[1]);
                    //console.log(res.receipt.logs[0]);
                }
                const header = await this.bitcoinSPVChain.getBlockHeader.call(parts[0], txParams);
                //assert.equal(header.blockHeight, parseInt(parts[2]), "Header height doesn't match");
                assert.equal(header.merkleRootHash, parts[4], 'Transaction merkle root hash doesn\'t match');
                assert.equal(header.previousHeaderHash, parts[5], 'Previous header hash doesn\'t match');
                if (i == length) {
                    console.log("Calling verify...");
                    const proof = '0xaf3f74b55a1d7530f6a74fb535ad79745e2793df8a979fb419783b5d38cff538185a5059a2089612163550d45122e9fc85082f91f70e6770831b8289b400bbd7afb225a13dcf7cc769f8c2aa6345757f31a5ef35bf18c4342e04086f998c91832f168fef3dc665a5278f93d08f0905eb86c6986cc77af7efaee0b604b86e5f2ca93e29790b535c7c32405b480d0d1b3ef8c0f2c3262c009448938d050753a9221b0c214e6b2eeeb07ae41bc0aa48ed38331650661aa402828e3720023bce46ea4d24dbe4af14d7a00afae1155e2af465a9610b58abd23d45686478cf1d8057a5e84997241118e369865952734a5f35e9618759d74b553984b238f49be15f4180';
                    const index = 356;
                    const txId = '0x42d0ba6385728ad26b33a9437c83a71f1523c191eed469530399fcdc245a1583';
                    const height = 700003;
                    const result = await this.bitcoinSPVChain.verifyTxInclusionProof.call(txId, height, index, proof, txParams);
                    assert.equal(result, true, "Unable to verify transaction");
                }

            });
        });
        
    });
})
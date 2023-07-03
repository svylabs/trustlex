var BitcoinUtils = artifacts.require("BitcoinUtils");
var SafeMath = artifacts.require('SafeMath');
const spvchain = artifacts.require("TrustedBitcoinSPVChain");
const fs = require('fs');

contract("BitcoinSPVChain: Happy Case", (accounts) => {
    const [owner, user1, user2] = accounts;
    const txParams = { from: accounts[5] };
    beforeEach(async function() {
        spvchain.link(await BitcoinUtils.deployed());
        this.bitcoinspvchain = await spvchain.deployed();
        //console.log(this.bitcoinspvchain);
        //spvchain.link(await BitcoinUtils.deployed());
        //spvchain.link(await SafeMath.deployed());
        //this.bitcoinSPVChain = await spvchain.new('0x0000a0203d0b88d3fded0b806262f5889ce83b3b21b2f0db0097080000000000000000006516022a0c1902642fc1f1d76084dea42770a2c572694d1af44e872a19400743f2f84363aef90817923155bf', 758015, 1664333794, txParams);
    });

    it ('test proof', async function() {
        const res = await this.bitcoinspvchain.AddHeader(2440170, '0x7ad3bd00391bdfa4ecdb8d901668f20b0c3f6a9c9c1a63b0eb361dd530849052', txParams);
        console.log(res);
        const txId = '0x'+ Buffer.from('15c8c84b817e3400928542b278ae2bf99dbf4a3ad05fdef1be53e90d739cd930', 'hex').reverse().toString('hex');
        const blockHeight = 2440170;
        const index = 99;
        const proof = '0xb8f3f8f55ced05cb609fb1eb1c209c36019d51bdc1cde7aa9767d24f11273d4024206941eef1bad4bda0950769c1f91d3823892cccd6d0475376cbdeb3de7e32f99a4c5bbe04e0ea706d9d38aa88d8c16df398c6ff716469a45b0518407801e01cfcbf13bae223a876da61cc84c6dede1aed2d145097e81b8f4b761fc18ca88adb34ac9b20b385b5e693c3b8661d65c129817f8d8a3bc252ab036ff897b77f92a9dc981dc0b2b60c43b26fa670764891608ea5702d91f3711c5de3378b062e6a';
        //const proof = '';
        console.log(await this.bitcoinspvchain.verifyTxInclusionProof(txId, blockHeight, index, proof));
        /*console.log((await this.bitcoinspvchain.verifyTxInclusionProof(txId, blockHeight, index, proof)).logs.forEach((log) => {
            console.log(log.args.val);
        }));*/

        //assert.equal(header.nBits, '0x1707e772', 'difficulty bits doesn\'t match');
    });
})
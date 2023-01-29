var BitcoinUtils = artifacts.require("BitcoinUtils");
var SafeMath = artifacts.require('SafeMath');
const trustlexapp = artifacts.require("TrustlexPerAssetOrderBook");
const fs = require('fs');

contract("Create TrustlexOrderBookContract", (accounts) => {
    const [owner, user1, user2] = accounts;
    const txParams = { from: owner };
    it ('submit block', async function() {
        trustlexapp.link(await BitcoinUtils.deployed());
        trustlexapp.link(await SafeMath.deployed());
        this.trustlexappcontract = await trustlexapp.new('0x0', txParams);
        console.log(this.trustlexappcontract.address);
    });
})


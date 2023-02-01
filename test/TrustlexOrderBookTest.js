//var BitcoinUtils = artifacts.require("BitcoinUtils");
//var SafeMath = artifacts.require('SafeMath');
const trustlexapp = artifacts.require("TrustlexPerAssetOrderBook");

contract("Create TrustlexOrderBookContract", (accounts) => {
    const [owner, user1, user2] = accounts;
    const txParam = { from: owner};
    const txParams = { from: owner, value: web3.utils.toWei('10',"ether") };
    const txParams1 = { from: user1, value: web3.utils.toWei('8.5',"ether") };
    const txParams2 = { from: user2, value: web3.utils.toWei('7',"ether") };
    it ('Create contract and add some data', async function() {
        //trustlexapp.link(await BitcoinUtils.deployed());
        //trustlexapp.link(await SafeMath.deployed());
        this.trustlexappcontract = await trustlexapp.new('0x0', txParam);
        console.log(this.trustlexappcontract.address);
        //function addOfferWithEth(uint64 satoshis, bytes20 bitcoinAddress, uint32 offerValidTill) public payable {
        await this.trustlexappcontract.addOfferWithEth(100000000, 
            '0x0000000000000000000000000000000000000000', 
            (parseInt(new Date().getTime() / 1000) + 7 * 24 * 60 * 60),
            txParams
            );
        await this.trustlexappcontract.addOfferWithEth(90000000, '0x0000000000000000000000000000000000000001', (parseInt((new Date).getTime() / 1000) + 6 * 24 * 60 * 60), txParams1);
        await this.trustlexappcontract.addOfferWithEth(80000000, '0x0000000000000000000000000000000000000003', (parseInt((new Date).getTime() / 1000) + 6 * 24 * 60 * 60), txParams2);
    });
})


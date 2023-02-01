//var BitcoinUtils = artifacts.require("BitcoinUtils");
//var SafeMath = artifacts.require('SafeMath');
const trustlexapp = artifacts.require("TrustlexPerAssetOrderBook");

contract("Create TrustlexOrderBookContract", (accounts) => {
    const [owner, user1, user2, user3, user4, user5] = accounts;
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
        let res = await this.trustlexappcontract.addOfferWithEth(100000000, 
            '0x0000000000000000000000000000000000000000', 
            (parseInt(new Date().getTime() / 1000) + 7 * 24 * 60 * 60),
            txParams
            );
        //console.log(res.logs[0].args);
        await this.trustlexappcontract.addOfferWithEth(90000000, '0x0000000000000000000000000000000000000001', (parseInt((new Date).getTime() / 1000) + 6 * 24 * 60 * 60), txParams1);
        await this.trustlexappcontract.addOfferWithEth(80000000, '0x0000000000000000000000000000000000000003', (parseInt((new Date).getTime() / 1000) + 6 * 24 * 60 * 60), txParams2);
        //  function initiateFulfillment(uint256 offerId, FulfillmentRequest calldata _fulfillment) public payable {
        //console.log(res.logs[0].args["1"]);
        res = await this.trustlexappcontract.initiateFulfillment(res.logs[0].args["1"], {fulfillmentBy: user4, quantityRequested: 10000000, allowAnyoneToSubmitPaymentProofForFee: true, allowAnyoneToAddCollateralForFee: true, totalCollateralAdded: 0, expiryTime: 0, fulfilledTime: 0, collateralAddedBy: '0x0000000000000000000000000000000000000000'}, {from: user4});
        //console.log(res);
    });
})


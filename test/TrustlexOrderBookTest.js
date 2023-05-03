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
        this.trustlexappcontract = await trustlexapp.new('0x0000000000000000000000000000000000000000', txParam);
        console.log(this.trustlexappcontract.address);
        //function addOfferWithEth(uint64 satoshis, bytes20 bitcoinAddress, uint32 offerValidTill) public payable {
        let res = await this.trustlexappcontract.addOfferWithEth(txParams.value,100000000, 
            '0x0000000000000000000000000000000000000000', 
            (parseInt(new Date().getTime() / 1000) + 7 * 24 * 60 * 60),
            txParams
            );
        // console.log(res.logs[0].args);
        let res1= await this.trustlexappcontract.addOfferWithEth(txParams1.value,90000000, '0x0000000000000000000000000000000000000001', (parseInt((new Date).getTime() / 1000) + 6 * 24 * 60 * 60), txParams1);
        await this.trustlexappcontract.addOfferWithEth(txParams2.value,80000000, '0x0000000000000000000000000000000000000003', (parseInt((new Date).getTime() / 1000) + 6 * 24 * 60 * 60), txParams2);
        //  function initiateFulfillment(uint256 offerId, FulfillmentRequest calldata _fulfillment) public payable {
        //console.log(res);
        

        initiateFulfillmentRes1 = await this.trustlexappcontract.initiateFulfillment(res.logs[0].args["1"], {fulfillmentBy: user4, quantityRequested: 10000000, allowAnyoneToSubmitPaymentProofForFee: true, allowAnyoneToAddCollateralForFee: true, totalCollateralAdded: 0, expiryTime: 0, fulfilledTime: 0, collateralAddedBy: '0x0000000000000000000000000000000000000000'}, {from: user4});
        let quantityRequested = 10000000;
        let initiateFulfillmentEventArgumnets = initiateFulfillmentRes1.logs[0].args
        let orderBy = initiateFulfillmentEventArgumnets[0];
        let offerId = initiateFulfillmentEventArgumnets[1].toString();
        let fulfillmentId  = initiateFulfillmentEventArgumnets[2].toString();
        console.log(res.logs[0].args["1"].toString(),orderBy,offerId,fulfillmentId);
        // get the eth balance of user
        let userBalance = await web3.eth.getBalance(user4);
        userBalance = web3.utils.fromWei(userBalance,"ether")
        console.log(user4,userBalance)

        let balance = await this.trustlexappcontract.getBalance();
        console.log(balance.toString())
        // initiateFulfillmentRes2 = await this.trustlexappcontract.initiateFulfillment(res1.logs[0].args["1"], {fulfillmentBy: user5, quantityRequested: 20000000, allowAnyoneToSubmitPaymentProofForFee: true, allowAnyoneToAddCollateralForFee: true, totalCollateralAdded: 0, expiryTime: 0, fulfilledTime: 0, collateralAddedBy: '0x0000000000000000000000000000000000000000'}, {from: user3});
        
        //submit the proof 
        // function submitPaymentProof(
        //     uint256 offerId,
        //     uint256 fulfillmentId // bytes calldata transaction, // bytes calldata proof, // uint32 blockHeight
        // )    
        let submitPaymentProofRes = await this.trustlexappcontract.submitPaymentProof(initiateFulfillmentEventArgumnets[0],initiateFulfillmentEventArgumnets[2]);
        console.log(submitPaymentProofRes)
        userBalance = await web3.eth.getBalance(user4);
        userBalance = web3.utils.fromWei(userBalance,"ether")
        console.log(user4,userBalance)

        balance = await this.trustlexappcontract.getBalance();
        console.log(balance.toString())


        // let totalOffers= await this.trustlexappcontract.getTotalOffers()
        // console.log(totalOffers.toString());
        // const offers = await this.trustlexappcontract.getOffers(3);
        // console.log(offers.total.toString());

        // console.log(offers.result[0].offerId, offers.result[0].offer);
        // console.log(offers.result[1].offerId, offers.result[1].offer);
        // console.log(offers.result[2].offerId, offers.result[2].offer);
        
        
        
    });
})


//var BitcoinUtils = artifacts.require("BitcoinUtils");



//var SafeMath = artifacts.require('SafeMath');
const trustlexapp = artifacts.require("TrustlexPerAssetOrderBook");

contract("Create TrustlexOrderBookContract", (accounts) => {
    const [owner, user1, user2, user3, user4, user5] = accounts;
    const txParam = { from: owner};
    const txParams = { from: owner, value: web3.utils.toWei('10',"ether") };
    const txParams1 = { from: user1, value: web3.utils.toWei('8.5',"ether") };
    const txParams2 = { from: user2, value: web3.utils.toWei('7',"ether") };
    

    it('Create the contract for order with ETH',async function(){
        //trustlexapp.link(await BitcoinUtils.deployed());
        //trustlexapp.link(await SafeMath.deployed());
        this.trustlexappcontract = await trustlexapp.new('0x0000000000000000000000000000000000000000', txParam);
    });

    it('Add the Offer with ETH',async function(){
        let offer1SatoshisToReceive = 1*(10**8); //1 BTC
        //function addOfferWithEth(uint64 satoshis, bytes20 bitcoinAddress, uint32 offerValidTill) public payable {
        let res = await this.trustlexappcontract.addOfferWithEth(txParams.value,offer1SatoshisToReceive, 
            '0x0000000000000000000000000000000000000000', 
            (parseInt(new Date().getTime() / 1000) + 7 * 24 * 60 * 60),
            txParams
        );
        this.totalFulfillmentRequests = 0;     
        let res1= await this.trustlexappcontract.addOfferWithEth(txParams1.value,90000000, '0x0000000000000000000000000000000000000001', (parseInt((new Date).getTime() / 1000) + 6 * 24 * 60 * 60), txParams1);
        let res2 = await this.trustlexappcontract.addOfferWithEth(txParams2.value,80000000, '0x0000000000000000000000000000000000000003', (parseInt((new Date).getTime() / 1000) + 6 * 24 * 60 * 60), txParams2);
        
        let totalOffersAmount = parseFloat(txParams.value)+parseFloat(txParams1.value)+parseFloat(txParams2.value);

        //get the total offers
        let totaloffers= await this.trustlexappcontract.getTotalOffers();
        assert.equal(totaloffers,3,"No. of offers are not matched");

        this.offer1Id = res.logs[0].args["1"];
        this.offer2Id = res1.logs[0].args["1"];
        this.offer3Id = res2.logs[0].args["1"];

        let offer1Details = await this.trustlexappcontract.getOffer(this.offer1Id);
        let offer2Details = await this.trustlexappcontract.getOffer(this.offer2Id);
        let offer3Details = await this.trustlexappcontract.getOffer(this.offer3Id);

        // console.log(offer1Details)

        let Offer1Amount = parseFloat(offer1Details.offerQuantity);
        let Offer2Amount = parseFloat(offer2Details.offerQuantity);
        let Offer3Amount = parseFloat(offer3Details.offerQuantity);
        
        let totalOffersAmountInContract = Offer1Amount+Offer2Amount+Offer3Amount;
        assert.equal(totalOffersAmount,totalOffersAmountInContract,"Total offers amount is not matched");
        
        //balance of contract
        let balance = await this.trustlexappcontract.getBalance();
        balance = parseFloat(balance.toString())

        assert.equal(balance,totalOffersAmountInContract,"Contract balance is not equal to contract balance!")
    });

    it('Get the user balance',async function(){
        // get the eth balance of user
        let userBalance = await web3.eth.getBalance(user4);
        userBalance = web3.utils.fromWei(userBalance,"ether")
        // console.log(user4,userBalance)
    });

    
    it ('Create first initiateFulfillment for offer 1', async function() {
        //  function initiateFulfillment(uint256 offerId, FulfillmentRequest calldata _fulfillment) public payable {
        // create the  first initial fullfillments
        this.totalFulfillmentRequests = 0;     
        let quantityRequested = 0.2*(10**8);// 1 BTC
        
        this.initiateFulfillmentRes1 = await this.trustlexappcontract.initiateFulfillment(
            this.offer1Id, 
            {
                fulfillmentBy: user4, 
                quantityRequested: quantityRequested, 
                allowAnyoneToSubmitPaymentProofForFee: true, 
                allowAnyoneToAddCollateralForFee: true, 
                totalCollateralAdded: 0, 
                expiryTime: 0, 
                fulfilledTime: 0, 
                collateralAddedBy: '0x0000000000000000000000000000000000000000'
            }, 
            {from: user4}
        );
        this.totalFulfillmentRequests++;
        let initiateFulfillmentEventArgumnets = this.initiateFulfillmentRes1.logs[0].args
        let orderBy = initiateFulfillmentEventArgumnets[0];
        let offerId = initiateFulfillmentEventArgumnets[1].toString();
        let fulfillmentId  = initiateFulfillmentEventArgumnets[2].toString();
        let offer = await this.trustlexappcontract.getOffer(this.offer1Id);
        assert.equal(offer.fulfillmentRequests.length,this.totalFulfillmentRequests,'First initiateFulfillment could not be created !');
    });

    // it ('Create second initiateFulfillment for offer 1', async function() {
    //     // create the  second initial fullfillments
    //     let quantityRequested2 = 0.2*(10**8);// .2 BTC
    //     // initiateFulfillmentRes2 = await this.trustlexappcontract.initiateFulfillment(this.offer2Id, {fulfillmentBy: user5, quantityRequested: 20000000, allowAnyoneToSubmitPaymentProofForFee: true, allowAnyoneToAddCollateralForFee: true, totalCollateralAdded: 0, expiryTime: 0, fulfilledTime: 0, collateralAddedBy: '0x0000000000000000000000000000000000000000'}, {from: user3});
    //     this.initiateFulfillmentRes2 = await this.trustlexappcontract.initiateFulfillment(
    //         this.offer1Id, 
    //         {
    //             fulfillmentBy: user5, 
    //             quantityRequested: quantityRequested2, 
    //             allowAnyoneToSubmitPaymentProofForFee: true, 
    //             allowAnyoneToAddCollateralForFee: true, 
    //             totalCollateralAdded: 0, 
    //             expiryTime: 0, 
    //             fulfilledTime: 0, 
    //             collateralAddedBy: '0x0000000000000000000000000000000000000000'
    //         }, 
    //         {from: user5}
    //     );
    //     this.totalFulfillmentRequests++;
    //     offer = await this.trustlexappcontract.getOffer(this.offer1Id);
    //     assert.equal(offer.fulfillmentRequests.length,this.totalFulfillmentRequests,'second initiateFulfillment could not be created !')
        
    //     let initiateFulfillmentEventArgumnets2 = this.initiateFulfillmentRes2.logs[0].args
    //     let orderBy2 = initiateFulfillmentEventArgumnets2[0];
    //     let offerId2 = initiateFulfillmentEventArgumnets2[1].toString();
    //     let fulfillmentId2  = initiateFulfillmentEventArgumnets2[2].toString();
    //     // console.log(res.logs[0].args["1"].toString(),orderBy,offerId,fulfillmentId);

        
    // });

    it ('Get initiateFulfillment for offer 1', async function() {
        //first fech the initiateFulfillmentIds
        let offerFulfillmentRequests = await this.trustlexappcontract.getInitiateFulfillments(this.offer1Id);
        // console.log(offerFulfillmentRequests)
    });

    it ('Submit the proof for offer 1', async function() {
        //first fech the initiateFulfillmentIds
        let offer = await this.trustlexappcontract.getOffer(this.offer1Id);
        let offerFulfillmentRequests = offer.fulfillmentRequests;
        
        let offerofferFulfillmentRequestsDetails = await this.trustlexappcontract.initializedFulfillments(this.offer1Id,offerFulfillmentRequests[0]);
        // console.log('offer',offer)
        // console.log('offerFulfillmentRequestsDetails',offerofferFulfillmentRequestsDetails)
        let userBalance = await web3.eth.getBalance(user4);
        userBalance = web3.utils.fromWei(userBalance,"ether")
        console.log('user4 pre balance ',userBalance);


        // userBalance = await web3.eth.getBalance(user5);
        // userBalance = web3.utils.fromWei(userBalance,"ether")
        // console.log('user5 pre balance ',userBalance);
       
        let submitPaymentProofResults = [];
        let i=0;
        for(;i<offerFulfillmentRequests.length;i++){
            let FulfillmentRequestId = offerFulfillmentRequests[i];
            let submitPaymentProofRes = await this.trustlexappcontract.submitPaymentProof(this.offer1Id,FulfillmentRequestId);
            submitPaymentProofResults.push(submitPaymentProofRes);
        }
        Promise.all(submitPaymentProofResults).then(async values=>{
            values.forEach(function(currentValue, index, arr){
                // console.log(currentValue.logs.args)
            })
            
        })

        userBalance = await web3.eth.getBalance(user4);
        userBalance = web3.utils.fromWei(userBalance,"ether")
        console.log('user4 post balance',userBalance)

        // userBalance = await web3.eth.getBalance(user5);
        // userBalance = web3.utils.fromWei(userBalance,"ether")
        // console.log('user4 post balance',userBalance)
    });

    it ('Prepare the data for my-swap', async function() {
        // fetched the offer created by a user
        let totalOffers = await this.trustlexappcontract.getTotalOffers();
        console.log(totalOffers.toString())
        let offersData = await this.trustlexappcontract.getOffers(totalOffers);
        let totalFetchedRecords = offersData.total;
        let offers = offersData.result;
        console.log(totalFetchedRecords);
        console.log(owner)
        const promises = [];
        for (let i = 0; i < totalFetchedRecords; i++) {
            let value = offers[i];
            let offer = value.offer;
            let offerId = value.offerId.toString();
            console.log(offer.offeredBy.toLowerCase() , owner.toLowerCase())
            if(offer.offeredBy.toLowerCase() === owner.toLowerCase()){
                const offerDetailsInJson = {
                    offerId: offerId,
                    offerQuantity: offer.offerQuantity.toString(),
                    offeredBy: offer.offeredBy.toString(),
                    offerValidTill: offer.offerValidTill.toString(),
                    orderedTime: offer.orderedTime.toString(),
                    offeredBlockNumber: offer.offeredBlockNumber.toString(),
                    bitcoinAddress: offer.bitcoinAddress.toString(),
                    satoshisToReceive: offer.satoshisToReceive.toString(),
                    satoshisReceived: offer.satoshisReceived.toString(),
                    satoshisReserved: offer.satoshisReserved.toString(),
                    collateralPer3Hours: offer.collateralPer3Hours.toString(),
                    fulfillmentRequests: offer.fulfillmentRequests,
                    progress : '',
                };
                
                promises.push({ offerDetailsInJson });
            }
        }

        const offersList = await Promise.all(promises);
        console.log(offersList)

    });
})


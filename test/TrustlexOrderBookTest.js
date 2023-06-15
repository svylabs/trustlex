//var BitcoinUtils = artifacts.require("BitcoinUtils");
//var SafeMath = artifacts.require('SafeMath');
const trustlexapp = artifacts.require("TrustlexPerAssetOrderBook");

contract("Create TrustlexOrderBookContract", (accounts) => {
    const [owner, user1, user2, user3, user4, user5] = accounts;
    const txParam = { from: owner};
    const txParams = { from: owner, value: web3.utils.toWei('10',"ether") };
    const txParams1 = { from: user1, value: web3.utils.toWei('8.5',"ether") };
    const txParams2 = { from: user2, value: web3.utils.toWei('7',"ether") };

    const txParams3 = { from: user3, value: web3.utils.toWei('10',"ether") };
    const txParams4 = { from: user4, value: web3.utils.toWei('15',"ether") };
    const txParams5 = { from: user5, value: web3.utils.toWei('20',"ether") };
    

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
                collateralAddedBy: '0x0000000000000000000000000000000000000000',
                paymentProofSubmitted:false,
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
    //             collateralAddedBy: '0x0000000000000000000000000000000000000000',
                    // paymentProofSubmitted:false,
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

    it ('Create first initiateFulfillment for offer 2', async function() {
        //  function initiateFulfillment(uint256 offerId, FulfillmentRequest calldata _fulfillment) public payable {
        // create the  first initial fullfillments
        this.totalFulfillmentRequestsforOffer2 = 0;     
        let quantityRequested = 0.9*(10**8);// 1 BTC
        
        this.initiateFulfillmentRes1forOffer2 = await this.trustlexappcontract.initiateFulfillment(
            this.offer2Id, 
            {
                fulfillmentBy: owner, 
                quantityRequested: quantityRequested, 
                allowAnyoneToSubmitPaymentProofForFee: true, 
                allowAnyoneToAddCollateralForFee: true, 
                totalCollateralAdded: 0, 
                expiryTime: 0, 
                fulfilledTime: 0, 
                collateralAddedBy: '0x0000000000000000000000000000000000000000',
                paymentProofSubmitted:false,
            }, 
            {from: owner}
        );
        this.totalFulfillmentRequestsforOffer2++;
        let initiateFulfillmentEventArgumnets = this.initiateFulfillmentRes1forOffer2.logs[0].args
        let orderBy = initiateFulfillmentEventArgumnets[0];
        let offerId = initiateFulfillmentEventArgumnets[1].toString();
        let fulfillmentId  = initiateFulfillmentEventArgumnets[2].toString();
        let offer = await this.trustlexappcontract.getOffer(this.offer2Id);
        assert.equal(offer.fulfillmentRequests.length,this.totalFulfillmentRequestsforOffer2,'First initiateFulfillment could not be created for offer2 !');
    });

    it ('Create first initiateFulfillment for offer 3', async function() {
        // create the  first initial fullfillments
        this.totalFulfillmentRequestsforOffer3 = 0;     
        let quantityRequested = 0.8*(10**8);// 1 BTC
        
        this.initiateFulfillmentRes1forOffer3 = await this.trustlexappcontract.initiateFulfillment(
            this.offer3Id, 
            {
                fulfillmentBy: owner, 
                quantityRequested: quantityRequested, 
                allowAnyoneToSubmitPaymentProofForFee: true, 
                allowAnyoneToAddCollateralForFee: true, 
                totalCollateralAdded: 0, 
                expiryTime: 0, 
                fulfilledTime: 0, 
                collateralAddedBy: '0x0000000000000000000000000000000000000000',
                paymentProofSubmitted:false,
            }, 
            {from: owner}
        );
        this.totalFulfillmentRequestsforOffer3++;
        let initiateFulfillmentEventArgumnets = this.initiateFulfillmentRes1forOffer3.logs[0].args
        let orderBy = initiateFulfillmentEventArgumnets[0];
        let offerId = initiateFulfillmentEventArgumnets[1].toString();
        let fulfillmentId  = initiateFulfillmentEventArgumnets[2].toString();
        let offer = await this.trustlexappcontract.getOffer(this.offer3Id);
        assert.equal(offer.fulfillmentRequests.length,this.totalFulfillmentRequestsforOffer3,'First initiateFulfillment could not be created for offer3 !');
    });

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

    it ('Submit the proof for offer 3', async function() {
        //first fech the initiateFulfillmentIds
        let offer = await this.trustlexappcontract.getOffer(this.offer3Id);
        let offerFulfillmentRequests = offer.fulfillmentRequests;
        
        let userBalance = await web3.eth.getBalance(owner);
        userBalance = web3.utils.fromWei(userBalance,"ether")
        console.log('owner pre balance ',userBalance);

        let submitPaymentProofResults = [];
        let i=0;
        for(;i<offerFulfillmentRequests.length;i++){
            let FulfillmentRequestId = offerFulfillmentRequests[i];
            let submitPaymentProofRes = await this.trustlexappcontract.submitPaymentProof(this.offer3Id,FulfillmentRequestId);
            submitPaymentProofResults.push(submitPaymentProofRes);
        }
        Promise.all(submitPaymentProofResults).then(async values=>{
            values.forEach(function(currentValue, index, arr){
                // console.log(currentValue.logs.args)
            })
            
        })
        userBalance = await web3.eth.getBalance(owner);
        userBalance = web3.utils.fromWei(userBalance,"ether")
        console.log('owner post balance',userBalance)
    });

    it ('Prepare the data for my-swap ongoing', async function() {
        // fetched the offer created by a user
        let totalOffers = await this.trustlexappcontract.getTotalOffers();
        let account = owner;
        let offersData = await this.trustlexappcontract.getOffers(totalOffers);
        let totalFetchedRecords = offersData.total;
        let offers = offersData.result;
        // console.log(totalFetchedRecords.toString());
        // console.log(owner)
        let MyOngoingOrdersPromises = [];
        const MyOffersPromises = [];
        for (let i = 0; i < totalFetchedRecords; i++) {
            let value = offers[i];
            let offer = value.offer;
            let offerId = value.offerId.toString();
            let fulfillmentRequests  = value.fulfillmentRequests;
            
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
                offerType: '',
                fullfillmentRequestId:undefined,
            };
            if(offer.offeredBy.toLowerCase() === account.toLowerCase()){
                let filled = 0;
                let satoshisReserved = offer.satoshisReserved;
                let satoshisToReceive = offer.satoshisToReceive;
                filled = (satoshisReserved/satoshisToReceive)*100;
                offerDetailsInJson.progress = filled+'% filled';
                offerDetailsInJson.offerType = 'My Offer';
                MyOffersPromises.push({ offerDetailsInJson });
            }

            // get the fullfillment list
            let FullfillmentResults = await this.trustlexappcontract.getInitiateFulfillments(value.offerId);
            
            let fullfillmentRequestId = undefined;
            let fullfillmentResult = FullfillmentResults && FullfillmentResults.find((fullfillmentResult,index) => {
                if(
                  fullfillmentResult.fulfillmentRequest.fulfillmentBy.toLowerCase() ===
                  account.toLowerCase() && fullfillmentResult.fulfillmentRequest.paymentProofSubmitted == false
                ){
                    fullfillmentRequestId = offer.fulfillmentRequests[index];
                    return true;
                }else{
                    return false;
                }
              });
             if(fullfillmentResult){
                offerDetailsInJson.offerType = 'My Order';
                offerDetailsInJson.progress = 'initiated';
                offerDetailsInJson.fullfillmentRequestId = fullfillmentRequestId;

             } 
            fullfillmentResult && MyOffersPromises.push(offerDetailsInJson)
        }
        const MyoffersList = await Promise.all(MyOffersPromises);
        console.log('Ongoing offers',MyoffersList)

    });

    it ('Prepare the data for my-swap completed', async function() {
        // fetched the offer created by a user
        let totalOffers = await this.trustlexappcontract.getTotalOffers();
        let account = owner;
        let offersData = await this.trustlexappcontract.getOffers(totalOffers);
        let totalFetchedRecords = offersData.total;
        let offers = offersData.result;
        // console.log(totalFetchedRecords.toString());
        // console.log(owner)
        let MyOngoingOrdersPromises = [];
        const MyOffersPromises = [];
        for (let i = 0; i < totalFetchedRecords; i++) {
            let value = offers[i];
            let offer = value.offer;
            let offerId = value.offerId.toString();
            let fulfillmentRequests  = value.fulfillmentRequests;
            
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
                offerType: '',
                fullfillmentRequestId:undefined,
            };
            let satoshisReserved = offer.satoshisReserved;
            let satoshisToReceive = offer.satoshisToReceive;
            let satoshisReceived = offer.satoshisReceived;
            if(offer.offeredBy.toLowerCase() === account.toLowerCase() && satoshisReceived ==satoshisToReceive){
                let filled = 0;
                
                filled = (satoshisReserved/satoshisToReceive)*100;
                offerDetailsInJson.progress = 'Completed';
                offerDetailsInJson.offerType = 'My Offer';
                MyOffersPromises.push({ offerDetailsInJson });
            }

            // get the fullfillment list
            let FullfillmentResults = await this.trustlexappcontract.getInitiateFulfillments(value.offerId);
            
            let fullfillmentRequestId = undefined;
            let fullfillmentResult = FullfillmentResults && FullfillmentResults.find((fullfillmentResult,index) => {
                if(
                  fullfillmentResult.fulfillmentRequest.fulfillmentBy.toLowerCase() ===
                  account.toLowerCase() && fullfillmentResult.fulfillmentRequest.paymentProofSubmitted == true
                ){
                    fullfillmentRequestId = offer.fulfillmentRequests[index];
                    return true;
                }else{
                    return false;
                }
              });
             if(fullfillmentResult){
                offerDetailsInJson.offerType = 'My Order';
                offerDetailsInJson.progress = 'initiated';
                offerDetailsInJson.fullfillmentRequestId = fullfillmentRequestId;

             } 
            fullfillmentResult && MyOffersPromises.push(offerDetailsInJson)
        }
        const MyoffersList = await Promise.all(MyOffersPromises);
        console.log('completed offers',MyoffersList)

    });

    it ('Prepare the data for all-swap ongoing', async function() {
        // fetched the offer created by a user
        let totalOffers = await this.trustlexappcontract.getTotalOffers();
        let account = owner;
        let offersData = await this.trustlexappcontract.getOffers(totalOffers);
        let totalFetchedRecords = offersData.total;
        let offers = offersData.result;
        // console.log(totalFetchedRecords.toString());
        // console.log(owner)
        let MyOngoingOrdersPromises = [];
        const MyOffersPromises = [];
        for (let i = 0; i < totalFetchedRecords; i++) {
            let value = offers[i];
            let offer = value.offer;
            let offerId = value.offerId.toString();
            let fulfillmentRequests  = value.fulfillmentRequests;
            
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
                offerType: '',
                fullfillmentRequestId:undefined,
            };
            // if(offer.offeredBy.toLowerCase() === account.toLowerCase()){
                let filled = 0;
                let satoshisReserved = offer.satoshisReserved;
                let satoshisToReceive = offer.satoshisToReceive;
                filled = (satoshisReserved/satoshisToReceive)*100;
                offerDetailsInJson.progress = filled+'% filled';
                offerDetailsInJson.offerType = 'My Offer';
                MyOffersPromises.push({ offerDetailsInJson });
            // }

            // get the fullfillment list
            let FullfillmentResults = await this.trustlexappcontract.getInitiateFulfillments(value.offerId);
            
            let fullfillmentRequestId = undefined;
            let fullfillmentResult = FullfillmentResults && FullfillmentResults.find((fullfillmentResult,index) => {
                if(
                  fullfillmentResult.fulfillmentRequest.paymentProofSubmitted == false
                ){
                    fullfillmentRequestId = offer.fulfillmentRequests[index];
                    return true;
                }else{
                    return false;
                }
              });
             if(fullfillmentResult){
                offerDetailsInJson.offerType = 'My Order';
                offerDetailsInJson.progress = 'initiated';
                offerDetailsInJson.fullfillmentRequestId = fullfillmentRequestId;

             } 
            fullfillmentResult && MyOffersPromises.push(offerDetailsInJson)
        }
        const MyoffersList = await Promise.all(MyOffersPromises);
        console.log('All-swap Ongoing offers',MyoffersList);
    });

    it ('Prepare the data for All-swap completed', async function() {
        // fetched the offer created by a user
        let totalOffers = await this.trustlexappcontract.getTotalOffers();
        let account = owner;
        let offersData = await this.trustlexappcontract.getOffers(totalOffers);
        let totalFetchedRecords = offersData.total;
        let offers = offersData.result;
        // console.log(totalFetchedRecords.toString());
        // console.log(owner)
        let MyOngoingOrdersPromises = [];
        const MyOffersPromises = [];
        for (let i = 0; i < totalFetchedRecords; i++) {
            let value = offers[i];
            let offer = value.offer;
            let offerId = value.offerId.toString();
            let fulfillmentRequests  = value.fulfillmentRequests;
            
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
                offerType: '',
                fullfillmentRequestId:undefined,
            };
            let satoshisReserved = offer.satoshisReserved;
            let satoshisToReceive = offer.satoshisToReceive;
            let satoshisReceived = offer.satoshisReceived;
            if(satoshisReceived ==satoshisToReceive){
                let filled = 0;
                
                filled = (satoshisReserved/satoshisToReceive)*100;
                offerDetailsInJson.progress = 'Completed';
                offerDetailsInJson.offerType = 'My Offer';
                MyOffersPromises.push({ offerDetailsInJson });
            }

            // get the fullfillment list
            let FullfillmentResults = await this.trustlexappcontract.getInitiateFulfillments(value.offerId);
            
            let fullfillmentRequestId = undefined;
            let fullfillmentResult = FullfillmentResults && FullfillmentResults.find((fullfillmentResult,index) => {
                if(
                  fullfillmentResult.fulfillmentRequest.paymentProofSubmitted == true
                ){
                    fullfillmentRequestId = offer.fulfillmentRequests[index];
                    return true;
                }else{
                    return false;
                }
              });
             if(fullfillmentResult){
                offerDetailsInJson.offerType = 'My Order';
                offerDetailsInJson.progress = 'initiated';
                offerDetailsInJson.fullfillmentRequestId = fullfillmentRequestId;

             } 
            fullfillmentResult && MyOffersPromises.push(offerDetailsInJson)
        }
        const MyoffersList = await Promise.all(MyOffersPromises);
        console.log('All completed offers',MyoffersList)
    });

    it("cancel offer",async function(){
        // Take two users and get the balance
        let user3Balance = await web3.eth.getBalance(user3);
        user3Balance = web3.utils.fromWei(user3Balance,"ether")
        console.log(user3,user3Balance)
        
        // first create two offers
        let offer1SatoshisToReceive = 1*(10**8); //1 BTC
        //function addOfferWithEth(uint64 satoshis, bytes20 bitcoinAddress, uint32 offerValidTill) public payable {
        let res = await this.trustlexappcontract.addOfferWithEth(
            txParams3.value,//WEIETH // value 10ETH
            offer1SatoshisToReceive, //satoshis
            "0x0000000000000000000000000000000000000000", //bitcoinAddress
            (parseInt(new Date().getTime() / 1000) + 7 * 24 * 60 * 60),//offerValidTill
            txParams3
        );
        let offer1Id = res.logs[0].args["1"];
        
        // get the first user balance
        let user3Balance_ = await web3.eth.getBalance(user3);
        user3Balance_ = web3.utils.fromWei(user3Balance_,"ether")
        console.log(user3,user3Balance_)    
        
        // cancel the first offer
        let offer1Result = await this.trustlexappcontract.cancelOffer(offer1Id, { from: user3});

        // get the first user balance
        user3Balance_ = await web3.eth.getBalance(user3);
        user3Balance_ = web3.utils.fromWei(user3Balance_,"ether")
        console.log(user3,user3Balance_)    

        let user4Balance = await web3.eth.getBalance(user4);
        user4Balance = web3.utils.fromWei(user4Balance,"ether")
        console.log(user4,user4Balance)

        // create the another offer
        let res2 = await this.trustlexappcontract.addOfferWithEth(
            txParams4.value,//WEIETH // value 15 ETH
            90000000, //satoshis  0.9 BTC
            '0x0000000000000000000000000000000000000000',//bitcoinAddress
            (parseInt((new Date).getTime() / 1000) + 6 * 24 * 60 * 60), //offerValidTill
            txParams4);

        let user4Balance_ = await web3.eth.getBalance(user4);
        user4Balance_ = web3.utils.fromWei(user4Balance_,"ether")
        console.log(user4,user4Balance_)
          
        let offer2Id = res2.logs[0].args["1"];  

        // initaiete the offer for offer two
        this.totalFulfillmentRequests = 0;     
        let quantityRequested = 0.5*(10**8);// 1 BTC
        
        let initiateFulfillmentRes2 = await this.trustlexappcontract.initiateFulfillment(
            offer2Id, 
            {
                fulfillmentBy: user5, 
                quantityRequested: quantityRequested, 
                allowAnyoneToSubmitPaymentProofForFee: true, 
                allowAnyoneToAddCollateralForFee: true, 
                totalCollateralAdded: 0, 
                expiryTime: 0, 
                fulfilledTime: 0, 
                collateralAddedBy: '0x0000000000000000000000000000000000000000',
                paymentProofSubmitted:false,
            }, 
            {from: user5}
        );
        await timeout(20000);
        

        // cancel the offer two
        let offer2Result = await this.trustlexappcontract.cancelOffer(offer2Id, { from: user4});
        // check the balance of user two
        
        let user4Balance_2 = await web3.eth.getBalance(user4);
        user4Balance_2 = web3.utils.fromWei(user4Balance_2,"ether")
        console.log(user4,user4Balance_2)
    
    })
    function timeout(ms) {
        return new Promise(resolve => setTimeout(resolve, ms));
    }
})


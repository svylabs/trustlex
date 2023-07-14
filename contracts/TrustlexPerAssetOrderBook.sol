// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;
import {SafeMath} from "./SafeMath.sol";
import {ITxVerifier} from "./ISPVChain.sol";
import {BitcoinUtils} from "./BitcoinUtils.sol";
import {BitcoinTransactionUtils} from "./BitcoinTransactionUtils.sol";
import {IERC20} from "./IERC20.sol";

// Error handling to check wether  _fulfillment.quantityRequested can be intiated or not
error ValidateOfferQuantity(
    uint64 satoshisToReceive,
    uint64 satoshisReserved,
    uint64 satoshisReceived,
    uint64 quantityRequested
);

contract TrustlexPerAssetOrderBook {
    IERC20 public MyTokenERC20;
    uint32 public fullFillmentExpiryTime;
    struct FulfillmentRequest {
        address fulfillmentBy;
        uint64 quantityRequested;
        uint32 expiryTime;
        uint256 totalCollateralAdded;
        address collateralAddedBy;
        uint32 fulfilledTime;
        uint32 fulfillRequestedTime;
        bool allowAnyoneToSubmitPaymentProofForFee;
        bool allowAnyoneToAddCollateralForFee;
        bool paymentProofSubmitted;
        bool isExpired;
    }

    struct Offer {
        uint256 offerQuantity;
        address offeredBy;
        uint32 offerValidTill;
        uint32 orderedTime;
        uint32 offeredBlockNumber;
        bytes20 bitcoinAddress;
        uint64 satoshisToReceive;
        uint64 satoshisReceived;
        uint64 satoshisReserved;
        uint8 collateralPer3Hours;
        uint256[] fulfillmentRequests;
        bool isCanceled;
    }

    struct ResultOffer {
        uint256 offerId;
        Offer offer;
    }

    struct ResultFulfillmentRequest {
        FulfillmentRequest fulfillmentRequest;
        uint256 fulfillmentRequestId;
    }

    struct CompactMetadata {
        address tokenContract; // 20 bytes
        uint32 totalOrdersInOrderBook; // total orders in order book
    }

    uint256 public orderBookCompactMetadata;

    address public txInclusionVerifierContract;

    // mapping(uint256 offerId => mapping(uint256 fullfillmentId => FulfillmentRequest fullfillmentData))
    mapping(uint256 => mapping(uint256 => FulfillmentRequest))
        public initializedFulfillments;

    mapping(uint256 => Offer) public offers;

    uint32 public constant CLAIM_PERIOD = 7 * 24 * 60 * 60;

    event NEW_OFFER(address indexed offeredBy, uint256 indexed offerId);

    event INITIALIZED_FULFILLMENT(
        address indexed claimedBy,
        uint256 indexed offerId,
        uint256 indexed fulfillmentId
    );

    // event PAYMENT_SUCCESSFUL(
    //     address indexed submittedBy,
    //     uint256 indexed offerId,
    //     uint256 indexed fulfillmentId
    // );
    event PAYMENT_SUCCESSFUL(
        address indexed submittedBy,
        address indexed receivedBy, // not sure if we can have more than 3 indexed parameters. If not, we can remove the indexed from 'fulfillmentId' - think about it.
        uint256 indexed offerId,
        uint256  compactFulfillmentDetail,
        bytes32 txHash, // This is the Bitcoin txHash
        bytes32 outputHash, // This will be the sha256 value of the scriptOutput
        bytes32 secret
    );
    event OfferExtendedEvent(uint256 offerId, uint32 offerValidTill);
    event OfferCancelEvent(uint256 offerId);

    constructor(address _tokenContract, address txInclusionVerifier) {
        orderBookCompactMetadata = (uint256(uint160(_tokenContract)) <<
            (12 * 8));
        MyTokenERC20 = IERC20(_tokenContract);
        fullFillmentExpiryTime = 7 * 24 * 60 * 60;
        txInclusionVerifierContract = txInclusionVerifier;
    }

    function deconstructMetadata()
        public
        view
        returns (CompactMetadata memory result)
    {
        uint256 compactMetadata = orderBookCompactMetadata;
        result.totalOrdersInOrderBook = uint32(
            (compactMetadata >> (8 * 8)) & (0xffffffff)
        );
        result.tokenContract = address(uint160(compactMetadata >> (12 * 8)));
    }

    function updateMetadata(CompactMetadata memory metadata) private {
        uint256 compactMeta = 0;
        compactMeta = (uint256(uint160(metadata.tokenContract)) << (12 * 8));
        compactMeta |= (uint256(metadata.totalOrdersInOrderBook) << (8 * 8));
        orderBookCompactMetadata = compactMeta;
    }

    // TODO: Remove after test
    function setFullFillmentExpiryTime(uint32 expiryTime) public {
        fullFillmentExpiryTime = expiryTime;
    }

    function getTotalOffers() public view returns (uint256) {
        return ((orderBookCompactMetadata >> (8 * 8)) & 0xffffffff);
    }

    // This function will return the full offer details
    function getOffer(
        uint256 offerId
    ) public view returns (Offer memory offer) {
        offer = offers[offerId];
    }

    function getOffers(
        uint256 fromOfferId
    ) public view returns (ResultOffer[50] memory result, uint256 total) {
        uint256 min = 0;
        if (fromOfferId >= 50) {
            min = fromOfferId - 50;
        }
        if (getTotalOffers() < fromOfferId) {
            fromOfferId = getTotalOffers();
        }
        for (uint256 offerId = uint256(fromOfferId); offerId > min; offerId--) {
            result[total++] = ResultOffer({
                offerId: offerId - 1,
                offer: offers[offerId - 1]
            });
        }
    }

    function addOfferWithEth(
        uint256 weieth,
        uint64 satoshis,
        bytes20 bitcoinAddress,
        uint32 offerValidTill
    ) public payable {
        CompactMetadata memory compact = deconstructMetadata();
        require(compact.tokenContract == address(0x0));
        require(msg.value >= weieth, "Please send the correct eth amount!");
        Offer memory offer;
        offer.offeredBy = msg.sender;
        offer.offerQuantity = msg.value;
        offer.satoshisToReceive = satoshis;
        offer.bitcoinAddress = bitcoinAddress;
        offer.offerValidTill = offerValidTill;
        offer.offeredBlockNumber = uint32(block.number);
        offer.orderedTime = uint32(block.timestamp);
        offer.isCanceled = false;

        uint256 offerId = compact.totalOrdersInOrderBook;
        offers[offerId] = offer;
        emit NEW_OFFER(msg.sender, offerId);
        compact.totalOrdersInOrderBook = compact.totalOrdersInOrderBook + 1;
        updateMetadata(compact);
    }

    function addOfferWithToken(
        uint256 value,
        uint64 satoshis,
        bytes20 bitcoinAddress,
        uint32 offerValidTill
    ) public {
        require(
            value <= MyTokenERC20.allowance(msg.sender, address(this)),
            "Sender does not have allownace."
        );

        // transfer the tokens
        MyTokenERC20.transferFrom(msg.sender, address(this), value);

        CompactMetadata memory compact = deconstructMetadata();
        require(compact.tokenContract != address(0x0));
        Offer memory offer;
        offer.offeredBy = msg.sender;
        offer.offerQuantity = value;
        offer.satoshisToReceive = satoshis;
        offer.bitcoinAddress = bitcoinAddress;
        offer.offerValidTill = offerValidTill;
        offer.offeredBlockNumber = uint32(block.number);
        offer.orderedTime = uint32(block.timestamp);
        offer.isCanceled = false;

        uint256 offerId = compact.totalOrdersInOrderBook;
        offers[offerId] = offer;
        emit NEW_OFFER(msg.sender, offerId);
        compact.totalOrdersInOrderBook = compact.totalOrdersInOrderBook + 1;
        updateMetadata(compact);
    }

    function initiateFulfillment(
        uint256 offerId,
        FulfillmentRequest calldata _fulfillment
    ) public payable {
        CompactMetadata memory compact = deconstructMetadata();
        Offer memory offer = offers[offerId];
        uint64 satoshisToReceive = offer.satoshisToReceive;
        uint64 satoshisReserved = offer.satoshisReserved;
        uint64 satoshisReceived = offer.satoshisReceived;

        // if (satoshisToReceive == (satoshisReserved + satoshisReceived)) {
        // Expire older fulfillments
        uint256[] memory fulfillmentIds = offer.fulfillmentRequests;
        for (uint256 index = 0; index < fulfillmentIds.length; index++) {
            FulfillmentRequest
                memory existingFulfillmentRequest = initializedFulfillments[
                    offerId
                ][fulfillmentIds[index]];
            if (
                existingFulfillmentRequest.expiryTime < block.timestamp &&
                existingFulfillmentRequest.isExpired == false &&
                existingFulfillmentRequest.paymentProofSubmitted == false
            ) {
                // TODO: Claim any satoshis reserved
                offer.satoshisReserved -= existingFulfillmentRequest
                    .quantityRequested;

                initializedFulfillments[offerId][fulfillmentIds[index]]
                    .isExpired = true;
                // TODO: Claim collateral
            }
        }
        satoshisReserved = offer.satoshisReserved;
        // }

        // require(
        //     satoshisToReceive >=
        //         (satoshisReserved +
        //             satoshisReceived +
        //             _fulfillment.quantityRequested),
        //     "satoshisToReceive is not equal or greater than sum of satoshisReserved amount ,satoshisReceived, current requested quanity"
        // );
        if (
            !(satoshisToReceive >=
                (satoshisReserved +
                    satoshisReceived +
                    _fulfillment.quantityRequested))
        ) {
            revert ValidateOfferQuantity({
                satoshisToReceive: satoshisToReceive,
                satoshisReserved: satoshisReserved,
                satoshisReceived: satoshisReceived,
                quantityRequested: _fulfillment.quantityRequested
            });
        }
        FulfillmentRequest memory fulfillment = _fulfillment;
        fulfillment.fulfillmentBy = msg.sender;
        fulfillment.isExpired = false;
        fulfillment.fulfillRequestedTime = uint32(block.timestamp);

        if (satoshisReserved > 0) {
            require(
                fulfillment.totalCollateralAdded > offer.collateralPer3Hours,
                "fulfillment.totalCollateralAdded > offer.collateralPer3Hours condition failed !"
            );
        }
        if (
            fulfillment.totalCollateralAdded > 0 &&
            compact.tokenContract == address(0x0)
        ) {
            fulfillment.totalCollateralAdded = msg.value;
            fulfillment.collateralAddedBy = msg.sender;
        } else if (fulfillment.totalCollateralAdded > 0) {
            // TODO: Get tokens from tokenContract
            // transfer colletaral tokens to contract
            IERC20(compact.tokenContract).transfer(
                address(this),
                fulfillment.totalCollateralAdded
            );

            fulfillment.collateralAddedBy = msg.sender;
        }
        fulfillment.expiryTime =
            uint32(block.timestamp) +
            fullFillmentExpiryTime; //Adding 3 hours by Glen
        // uint256 fulfillmentId = uint256(
        //     keccak256(abi.encode(fulfillment, block.timestamp))
        // );
        uint256 fulfillmentId = getOffer(offerId).fulfillmentRequests.length;
        initializedFulfillments[offerId][fulfillmentId] = fulfillment;
        // offers[offerId].satoshisReserved = offer.satoshisReserved;
        offers[offerId].satoshisReserved =
            offer.satoshisReserved +
            _fulfillment.quantityRequested;

        offers[offerId].fulfillmentRequests.push(fulfillmentId);
        emit INITIALIZED_FULFILLMENT(msg.sender, offerId, fulfillmentId);
    }

    // get the initial fullfillments list
    function getInitiateFulfillments(
        uint256 offerId
    ) public view returns (ResultFulfillmentRequest[] memory) {
        uint256[] memory fulfillmentIds = offers[offerId].fulfillmentRequests;
        ResultFulfillmentRequest[]
            memory resultFulfillmentRequest = new ResultFulfillmentRequest[](
                fulfillmentIds.length
            );

        for (uint256 index = 0; index < fulfillmentIds.length; index++) {
            FulfillmentRequest
                memory existingFulfillmentRequest = initializedFulfillments[
                    offerId
                ][fulfillmentIds[index]];
            resultFulfillmentRequest[index] = ResultFulfillmentRequest(
                existingFulfillmentRequest,
                fulfillmentIds[index]
            );
        }

        return resultFulfillmentRequest;
    }

    struct PaymentProof {
        bytes transaction;
        bytes proof;
        uint32 index;
        uint32 blockHeight;
    }

    struct HTLCReveal {
        bytes32 secret;
        bytes20 recoveryPubKeyHash;
    }

    function validateProof(uint256 offerId, uint256 fulfillmentId, PaymentProof calldata proof, HTLCReveal calldata htlcDetail) private returns (bytes32 txId, bytes memory scriptOutput) {
        uint256 valueRequested = initializedFulfillments[offerId][fulfillmentId]
            .quantityRequested;
        bytes32 hashedSecret = sha256(abi.encodePacked(sha256(bytes.concat(htlcDetail.secret))));
        uint32 lockTime = (initializedFulfillments[offerId][fulfillmentId].fulfillRequestedTime) + CLAIM_PERIOD;
        scriptOutput = BitcoinTransactionUtils.getTrustlexScriptV2(
                address(this),
                offerId << 128 | fulfillmentId,
                offers[offerId].bitcoinAddress,
                offers[offerId].orderedTime,
                htlcDetail.recoveryPubKeyHash,
                lockTime,
                hashedSecret
        );
        require(
            BitcoinTransactionUtils.hasOutput(
                proof.transaction,
                valueRequested,
                scriptOutput
            ),
            "required output is not available"
        );

        //bytes32 txId = BitcoinUtils._sha256d(proof.transaction);
        txId = sha256(abi.encodePacked(sha256(proof.transaction)));
        require(
            ITxVerifier(txInclusionVerifierContract).verifyTxInclusionProof(
                txId,
                proof.blockHeight,
                proof.index,
                proof.proof
            ),
            "Invalid tx inclusion proof"
        );
    }

    /*
       validate transaction  and pay all involved parties
    */
    function submitPaymentProof(
        uint256 offerId,
        uint256 fulfillmentId,
        PaymentProof calldata proof,
        HTLCReveal calldata htlcDetail
    ) external {
        CompactMetadata memory compact = deconstructMetadata();
        require(
            initializedFulfillments[offerId][fulfillmentId].fulfilledTime == 0,
            "fulfilledTime should be 0"
        );
        // add  check whether order is expired or not
        require(
            initializedFulfillments[offerId][fulfillmentId].expiryTime >=
                block.timestamp,
            "Order is exired"
        );

        (bytes32 txId, bytes memory scriptOutput) = validateProof(offerId, fulfillmentId, proof, htlcDetail);        

        offers[offerId].satoshisReceived += initializedFulfillments[offerId][
            fulfillmentId
        ].quantityRequested;
        offers[offerId].satoshisReserved -= initializedFulfillments[offerId][
            fulfillmentId
        ].quantityRequested;

        initializedFulfillments[offerId][fulfillmentId].fulfilledTime = uint32(
            block.timestamp
        );
        // Send ETH / TOKEN on success
        uint256 payAmountETh = (
            initializedFulfillments[offerId][fulfillmentId].quantityRequested
        ) * (offers[offerId].offerQuantity / offers[offerId].satoshisToReceive);
        if (compact.tokenContract == address(0x0)) {
            bool success = payable(
                initializedFulfillments[offerId][fulfillmentId].fulfillmentBy
            ).send(payAmountETh);
            require(success, "Transfer failed");

            if (
                initializedFulfillments[offerId][fulfillmentId]
                    .totalCollateralAdded > 0
            ) {
                bool successPaymentToRequester = payable(
                    initializedFulfillments[offerId][fulfillmentId]
                        .collateralAddedBy
                ).send(
                        initializedFulfillments[offerId][fulfillmentId]
                            .totalCollateralAdded
                    );
                require(
                    successPaymentToRequester,
                    "Payment Failed to collateralAddedBy"
                );
            }
        } else {
            IERC20(compact.tokenContract).transfer(
                initializedFulfillments[offerId][fulfillmentId].fulfillmentBy,
                payAmountETh
            );
            // transfer colletaral tokens to collateralAddedBy
            if (
                initializedFulfillments[offerId][fulfillmentId]
                    .totalCollateralAdded > 0
            ) {
                IERC20(compact.tokenContract).transfer(
                    initializedFulfillments[offerId][fulfillmentId]
                        .collateralAddedBy,
                    initializedFulfillments[offerId][fulfillmentId]
                        .totalCollateralAdded
                );
            }
        }
        initializedFulfillments[offerId][fulfillmentId]
            .paymentProofSubmitted = true;
         uint64 quantityRequested =   initializedFulfillments[offerId][fulfillmentId]
            .quantityRequested;
            
        emit PAYMENT_SUCCESSFUL(
            msg.sender, 
            offers[offerId].offeredBy,
            offerId, 
            (fulfillmentId  << (8 * 8)) | quantityRequested | (uint256(uint160(htlcDetail.recoveryPubKeyHash)) << (28 * 8)),
            txId,
            sha256(scriptOutput),
            htlcDetail.secret
        );
        
        
    }

    function addEthCollateral() public payable {}

    function addTokenCollateral() public payable {}

    function extendOffer(uint256 offerId, uint32 offerValidTill) public {
        require(offers[offerId].offeredBlockNumber > 0, "Invalid Offer ID");
        offers[offerId].offerValidTill =
            offers[offerId].offerValidTill +
            offerValidTill;
        emit OfferExtendedEvent(offerId, offerValidTill);
    }

    function cancelOffer(uint256 offerId) public payable {
        require(offers[offerId].offeredBlockNumber > 0, "Invalid Offer ID");
        CompactMetadata memory compact = deconstructMetadata();

        Offer memory offer = offers[offerId];
        uint64 satoshisToReceive = offer.satoshisToReceive;
        uint64 satoshisReserved = offer.satoshisReserved;
        uint64 satoshisReceived = offer.satoshisReceived;
        address offeredBy = offer.offeredBy;
        require(offeredBy == msg.sender, "Offer creator can only cancel offer");
        uint64 returnAbleAmountSatoshi;

        uint256[] memory fulfillmentIds = offer.fulfillmentRequests;
        uint256 payAmount;
        // if offer has no fullfillment orders
        if (fulfillmentIds.length == 0) {
            returnAbleAmountSatoshi = satoshisToReceive;
            offers[offerId].isCanceled = true;
            payAmount =
                (returnAbleAmountSatoshi) *
                (offers[offerId].offerQuantity /
                    offers[offerId].satoshisToReceive);
        } else {
            // if offer has  fullfillments order

            // Update satoshisReserved amount  for expired order
            for (uint256 index = 0; index < fulfillmentIds.length; index++) {
                FulfillmentRequest
                    memory existingFulfillmentRequest = initializedFulfillments[
                        offerId
                    ][fulfillmentIds[index]];
                if (
                    existingFulfillmentRequest.expiryTime < block.timestamp &&
                    existingFulfillmentRequest.isExpired == false &&
                    existingFulfillmentRequest.paymentProofSubmitted == false
                ) {
                    // Decrease the off satoshi resvered amou t for expired
                    offer.satoshisReserved -= existingFulfillmentRequest
                        .quantityRequested;

                    initializedFulfillments[offerId][fulfillmentIds[index]]
                        .isExpired = true;
                }
            }
            satoshisReserved = offer.satoshisReserved;

            returnAbleAmountSatoshi =
                satoshisToReceive -
                (satoshisReserved + satoshisReceived);

            satoshisToReceive -= returnAbleAmountSatoshi;

            payAmount =
                (returnAbleAmountSatoshi) *
                (offers[offerId].offerQuantity /
                    offers[offerId].satoshisToReceive);

            offers[offerId].satoshisReserved = satoshisReserved;
            offers[offerId].satoshisToReceive = satoshisToReceive;
            // decrease the offer quantity
            offers[offerId].offerQuantity -= payAmount;
        }

        if (compact.tokenContract == address(0x0)) {
            bool success = payable(offeredBy).send(payAmount);
            require(success, "Transfer failed");
        } else {
            IERC20(compact.tokenContract).transfer(offeredBy, payAmount);
        }

        // update the

        emit OfferCancelEvent(offerId);
    }

    function liquidateCollateral() public payable {}

    function getBalance() public view returns (uint256 balance) {
        return address(this).balance;
    }
}

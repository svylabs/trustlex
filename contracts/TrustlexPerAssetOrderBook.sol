// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;
import {SafeMath} from "./SafeMath.sol";
import {ERC20} from "./ERC20.sol";
import {ITxVerifier} from "./ISPVChain.sol";
import {BitcoinUtils} from "./BitcoinUtils.sol";

contract TrustlexPerAssetOrderBook {

    struct FulfillmentRequest {
        address fulfillmentBy;
        uint64 quantityRequested;
        bool allowAnyoneToSubmitPaymentProofForFee;
        bool allowAnyoneToAddCollateralForFee;
        uint256 totalCollateralAdded;
        uint32 expiryTime;
        uint32 fulfilledTime;
        address collateralAddedBy;
    }

    struct Offer {
        address offeredBy;
        uint256 offerQuantity;
        uint64 satoshisToReceive;
        uint64 satoshisReceived;
        uint64 satoshisReserved;
        bytes20 bitcoinAddress;
        uint32 offerValidTill;
        uint8 collateralPer3Hours;
        uint32 orderedTime;
        uint32 offeredBlockNumber;
        uint256[] fulfillmentRequests;
    }

    mapping (uint256 => mapping(uint256 => FulfillmentRequest)) initializedFulfillments;

    mapping (uint256 => Offer) public offers;

    address public tokenContract;

    constructor (address _tokenContract) {
        tokenContract = _tokenContract; 
    }

    Offer private _offer;

    event NEW_OFFER(uint256 indexed requestId);

    function addOfferWithEth(uint64 satoshis, bytes20 bitcoinAddress, uint32 offerValidTill) public payable {
        require(tokenContract == address(0x0));
        Offer memory offer = _offer;
        offer.offeredBy = msg.sender;
        offer.offerQuantity = msg.value;
        offer.satoshisToReceive = satoshis;
        offer.bitcoinAddress = bitcoinAddress;
        offer.offerValidTill = offerValidTill;
        offer.offeredBlockNumber = uint32(block.number);
        uint256 offerId = uint256(keccak256(abi.encode(offer)));
        offers[offerId] = offer;
        emit NEW_OFFER(offerId);
    }

    function addOfferWithToken(uint256 value, uint64 satoshis, bytes20 bitcoinAddress, uint32 offerValidTill) public {
        require(tokenContract != address(0x0));
        Offer memory offer = _offer;
        offer.offeredBy = msg.sender;
        offer.offerQuantity = value;
        offer.satoshisToReceive = satoshis;
        offer.bitcoinAddress = bitcoinAddress;
        offer.offerValidTill = offerValidTill;
        offer.offeredBlockNumber = uint32(block.number);
        uint256 offerId = uint256(keccak256(abi.encode(offer)));
        offers[offerId] = offer;
        emit NEW_OFFER(offerId);
    }

    function initiateFulfillment(uint256 offerId, FulfillmentRequest calldata _fulfillment) public payable {
        uint64 satoshisToReceive = offers[offerId].satoshisToReceive;
        uint64 satoshisReserved = offers[offerId].satoshisReserved;
        uint64 satoshisReceived = offers[offerId].satoshisReceived;
        uint64 quantityRequested = _fulfillment.quantityRequested;
        if (satoshisToReceive == (satoshisReserved + satoshisReceived)) {
            uint256[] memory fulfillmentIds = offers[offerId].fulfillmentRequests;
            for (uint256 index = 0; index < fulfillmentIds.length;index++) {
                FulfillmentRequest memory existingFulfillmentRequest = initializedFulfillments[offerId][fulfillmentIds[index]];
                if (existingFulfillmentRequest.expiryTime < block.timestamp) {
                    require(quantityRequested == existingFulfillmentRequest.quantityRequested);
                    // TODO: Claim any satoshis reserved
                    offers[offerId].satoshisReserved -= existingFulfillmentRequest.quantityRequested;
                    // TODO: Claim collateral

                }
            }
            satoshisReserved = offers[offerId].satoshisReserved;
        }
        require(satoshisToReceive >= (satoshisReserved + satoshisReceived + _fulfillment.quantityRequested));
        FulfillmentRequest memory fulfillment = _fulfillment;
        fulfillment.fulfillmentBy = msg.sender;
        if (satoshisReserved > 0) {
            require(fulfillment.totalCollateralAdded > offers[offerId].collateralPer3Hours);
        }
        if (fulfillment.totalCollateralAdded > 0 && tokenContract == address(0x0)) {
            fulfillment.totalCollateralAdded = msg.value;
        } else if (fulfillment.totalCollateralAdded > 0) {
            // TODO: Get tokens from tokenContract
            fulfillment.collateralAddedBy = msg.sender;
        }
        fulfillment.expiryTime  = uint32(block.timestamp);
        uint256 fulfillmentId = uint256(keccak256(abi.encode(fulfillment, block.timestamp)));
        initializedFulfillments[offerId][fulfillmentId] = fulfillment;
    }

    /*
       validate transaction 
    */
    function submitPaymentProof(uint256 offerId, bytes calldata transaction, bytes calldata proof, uint32 blockHeight) public {

    }

    /*
       validate transaction 
    */
    function submitPaymentProof(address requester, uint256 offerId, bytes calldata transaction, bytes calldata proof, uint32 blockHeight) public {

    }

    function addEthCollateral() public payable {

    }

    function addTokenCollateral() public payable {

    }

    function extendOffer() public {

    }

    function liquidateCollateral() public payable {

    }

}


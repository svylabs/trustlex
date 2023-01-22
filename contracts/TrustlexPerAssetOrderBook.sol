// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;
import {SafeMath} from "./SafeMath.sol";
import {ERC20} from "./ERC20.sol";
import {ITxVerifier} from "./ISPVChain.sol";
import {BitcoinUtils} from "./BitcoinUtils.sol";

contract TrustlexPerAssetOrderBook {

    struct FulfillmentRequest {
        address fulfillmentBy;
        uint256 quantityRequested;
        bool allowAnyoneToSubmitPaymentProofForFee;
        uint256 totalCollateralAdded;
        uint32 fee;
        uint32 fulfilledTime;
    }

    struct Offer {
        address orderedBy;
        uint256 orderQuantity;
        uint64 satoshisToReceive;
        uint64 satoshisReceived;
        bytes20 bitcoinAddress;
        uint32 offerValidTill;
        uint8 minimumCollateral;
        uint32 orderedTime;
    }

    mapping (uint256 => mapping (address => FulfillmentRequest)) initializedOrders;

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
        offer.orderedBy = msg.sender;
        offer.orderQuantity = msg.value;
        offer.satoshisToReceive = satoshis;
        offer.bitcoinAddress = bitcoinAddress;
        offer.offerValidTill = offerValidTill;
        uint256 offerId = uint256(keccak256(abi.encode(offer, block.number)));
        offers[offerId] = offer;
        emit NEW_OFFER(offerId);
    }

    function addOfferWithToken(uint256 value, uint64 satoshis, bytes20 bitcoinAddress, uint32 offerValidTill)) public {
        require(tokenContract != address(0x0));
        Offer memory offer = _offer;
        offer.orderedBy = msg.sender;
        offer.orderQuantity = value;
        offer.satoshisToReceive = satoshis;
        offer.bitcoinAddress = bitcoinAddress;
        offer.offerValidTill = offerValidTill;
        uint256 offerId = uint256(keccak256(abi.encode(offer, block.number)));
        offers[offerId] = offer;
        emit NEW_OFFER(offerId);
    }

    function initiateFulfillment(uint256 offerId, FulfillmentRequest calldata fulfillment) public {
        
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

    function addCollateral() public payable {

    }

    function extendOffer() public {

    }

    function liquidateCollateral() public payable {

    }

}


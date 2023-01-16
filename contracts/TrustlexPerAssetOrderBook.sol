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
        uint64 satsToReceive;
        uint64 satsReceived;
        bytes20 bitcoinAddress;
        uint32 offerValidTill;
        uint8 minimumCollateral;
        uint32 orderedTime;
        mapping (address => FulfillmentRequest) reservation;
    }

    mapping (uint256 => Offer) public offers;

    address public tokenContract;

    constructor (address _tokenContract) {
        tokenContract = _tokenContract; 
    }

    function addOfferWithEth() public payable {

    }

    function addOfferWithToken() public {

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


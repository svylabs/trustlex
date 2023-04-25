// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;
import {SafeMath} from "./SafeMath.sol";
import {ERC20} from "./ERC20.sol";
import {ITxVerifier} from "./ISPVChain.sol";
import {BitcoinUtils} from "./BitcoinUtils.sol";
import {IERC20} from "./IERC20.sol";

contract TrustlexPerAssetOrderBook {
    struct FulfillmentRequest {
        address fulfillmentBy;
        uint64 quantityRequested;
        uint32 expiryTime;
        uint256 totalCollateralAdded;
        address collateralAddedBy;
        uint32 fulfilledTime;
        bool allowAnyoneToSubmitPaymentProofForFee;
        bool allowAnyoneToAddCollateralForFee;
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
    }

    mapping(uint256 => mapping(uint256 => FulfillmentRequest))
        public initializedFulfillments;

    mapping(uint256 => Offer) public offers;

    uint256 public orderBookCompactMetadata;

    constructor(address _tokenContract) {
        orderBookCompactMetadata = (uint256(uint160(_tokenContract)) <<
            (12 * 8));
    }

    struct CompactMetadata {
        address tokenContract; // 20 bytes
        uint32 totalOrdersInOrderBook; // total orders in order book
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

    function getTotalOffers() public view returns (uint256) {
        return ((orderBookCompactMetadata >> (8 * 8)) & 0xffffffff);
    }

    struct ResultOffer {
        uint256 offerId;
        Offer offer;
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

    event NEW_OFFER(address indexed offeredBy, uint256 indexed offerId);

    event INITIALIZED_FULFILLMENT(
        address indexed claimedBy,
        uint256 indexed offerId,
        uint256 indexed fulfillmentId
    );

    event PAYMENT_SUCCESSFUL(
        address indexed submittedBy,
        uint256 indexed offerId,
        uint256 indexed fulfillmentId
    );

    function addOfferWithEth(
        uint64 satoshis,
        bytes20 bitcoinAddress,
        uint32 offerValidTill
    ) public payable {
        CompactMetadata memory compact = deconstructMetadata();
        require(compact.tokenContract == address(0x0));
        Offer memory offer;
        offer.offeredBy = msg.sender;
        offer.offerQuantity = msg.value;
        offer.satoshisToReceive = satoshis;
        offer.bitcoinAddress = bitcoinAddress;
        offer.offerValidTill = offerValidTill;
        offer.offeredBlockNumber = uint32(block.number);
        offer.orderedTime = uint32(block.timestamp);

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
        CompactMetadata memory compact = deconstructMetadata();
        require(compact.tokenContract != address(0x0));
        Offer memory offer;
        offer.offeredBy = msg.sender;
        offer.offerQuantity = value;
        offer.satoshisToReceive = satoshis;
        offer.bitcoinAddress = bitcoinAddress;
        offer.offerValidTill = offerValidTill;
        offer.offeredBlockNumber = uint32(block.number);
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
        if (satoshisToReceive == (satoshisReserved + satoshisReceived)) {
            // Expire older fulfillments
            uint256[] memory fulfillmentIds = offer.fulfillmentRequests;
            for (uint256 index = 0; index < fulfillmentIds.length; index++) {
                FulfillmentRequest
                    memory existingFulfillmentRequest = initializedFulfillments[
                        offerId
                    ][fulfillmentIds[index]];
                if (existingFulfillmentRequest.expiryTime < block.timestamp) {
                    // TODO: Claim any satoshis reserved
                    offer.satoshisReserved -= existingFulfillmentRequest
                        .quantityRequested;
                    // TODO: Claim collateral
                }
            }
            satoshisReserved = offer.satoshisReserved;
        }
        require(
            satoshisToReceive >=
                (satoshisReserved +
                    satoshisReceived +
                    _fulfillment.quantityRequested)
        );
        FulfillmentRequest memory fulfillment = _fulfillment;
        fulfillment.fulfillmentBy = msg.sender;
        if (satoshisReserved > 0) {
            require(
                fulfillment.totalCollateralAdded > offer.collateralPer3Hours
            );
        }
        if (
            fulfillment.totalCollateralAdded > 0 &&
            compact.tokenContract == address(0x0)
        ) {
            fulfillment.totalCollateralAdded = msg.value;
        } else if (fulfillment.totalCollateralAdded > 0) {
            // TODO: Get tokens from tokenContract
            fulfillment.collateralAddedBy = msg.sender;
        }
        fulfillment.expiryTime = uint32(block.timestamp);
        uint256 fulfillmentId = uint256(
            keccak256(abi.encode(fulfillment, block.timestamp))
        );
        initializedFulfillments[offerId][fulfillmentId] = fulfillment;
        offers[offerId].satoshisReserved = offer.satoshisReserved;
        offers[offerId].fulfillmentRequests.push(fulfillmentId);
        emit INITIALIZED_FULFILLMENT(msg.sender, offerId, fulfillmentId);
    }

    /*
       validate transaction  and pay all involved parties
    */
    function submitPaymentProof(
        uint256 offerId,
        uint256 fulfillmentId,
        bytes calldata transaction,
        bytes calldata proof,
        uint32 blockHeight
    ) public {
        CompactMetadata memory compact = deconstructMetadata();
        // TODO: Validate  transaction here
        require(
            initializedFulfillments[offerId][fulfillmentId].fulfilledTime == 0
        );
        offers[offerId].satoshisReceived += initializedFulfillments[offerId][
            fulfillmentId
        ].quantityRequested;
        offers[offerId].satoshisReserved -= initializedFulfillments[offerId][
            fulfillmentId
        ].quantityRequested;
        // Send ETH / TOKEN on success
        if (compact.tokenContract == address(0x0)) {
            (bool success, ) = (
                initializedFulfillments[offerId][fulfillmentId].fulfillmentBy
            ).call{
                value: initializedFulfillments[offerId][fulfillmentId]
                    .quantityRequested
            }("");
            require(success, "Transfer failed");
        } else {
            initializedFulfillments[offerId][fulfillmentId]
                .fulfilledTime = uint32(block.timestamp);
            IERC20(compact.tokenContract).transfer(
                initializedFulfillments[offerId][fulfillmentId].fulfillmentBy,
                initializedFulfillments[offerId][fulfillmentId]
                    .quantityRequested
            );
        }
        emit PAYMENT_SUCCESSFUL(msg.sender, offerId, fulfillmentId);
    }

    function addEthCollateral() public payable {}

    function addTokenCollateral() public payable {}

    function extendOffer() public {}

    function liquidateCollateral() public payable {}
}

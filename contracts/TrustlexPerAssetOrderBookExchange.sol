// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;
import {SafeMath} from "./SafeMath.sol";
import {ITxVerifier} from "./ISPVChain.sol";
import {BitcoinUtils} from "./BitcoinUtils.sol";
import {BitcoinTransactionUtils} from "./BitcoinTransactionUtils.sol";
import {IERC20} from "./IERC20.sol";

// Error handling to check wether  _settlement.quantityRequested can be intiated or not
error ValidateOfferQuantity(
    uint64 satoshisToReceive,
    uint64 satoshisReserved,
    uint64 satoshisReceived,
    uint64 quantityRequested
);

contract TrustlexPerAssetOrderBookExchange {
    
    IERC20 public MyTokenERC20;

    // Constants
    uint32 public constant SETTLEMENT_COMPETION_WINDOW = 15 * 60; // 15 minutes after initializing settlement

    uint32 public constant CLAIM_PERIOD = 7 * 24 * 60 * 60;

    // Structs
    struct SettlementRequest {
        address settledBy; // msg.sender
        uint64 quantityRequested;
        uint32 settlementRequestedTime;
        uint32 lockTime;
        bytes32 hashedSecret;
        bytes20 recoveryPubKeyHash;
        uint160 settlementId;
        uint32 expiryTime;
        uint32 settledTime;
        bool settled;
        bool isExpired;
        bytes32 txId;
        bytes32 scriptOutputHash;
    }

    struct Offer {
        uint256 offerQuantity;
        address offeredBy;
        uint32 offerValidTill;
        uint32 orderedTime;
        uint32 offeredBlockNumber;
        bytes20 pubKeyHash;
        uint64 satoshisToReceive;
        uint64 satoshisReceived;
        uint64 satoshisReserved;
        uint256[] settlementRequests;
        bool isCanceled;
    }

    struct ResultOffer {
        uint256 offerId;
        Offer offer;
    }

    struct ResultSettlementRequest {
        SettlementRequest settlementRequest;
        uint256 settlementRequestId;
    }

    struct CompactMetadata {
        address tokenContract; // 20 bytes
        uint32 totalOrdersInOrderBook; // total orders in order book
    }

    struct PaymentProof {
        bytes transaction;
        bytes proof;
        uint32 index;
        uint32 blockHeight;
    }

    struct HTLCReveal {
        bytes32 secret;
    }

    // Contract state

    uint256 public orderBookCompactMetadata;

    address public txInclusionVerifierContract;

    mapping(uint256 => mapping(uint256 => SettlementRequest))
        public initializedSettlements;

    mapping(uint256 => Offer) public offers;

    // Events

    event NEW_OFFER(address indexed offeredBy, uint256 indexed offerId);

    event INITIALIZED_SETTLEMENT(
        address indexed claimedBy,
        uint256 indexed offerId,
        uint256 indexed settlementId
    );

    event SETTLEMENT_SUCCESSFUL(
        address indexed submittedBy,
        address indexed receivedBy,
        uint256 indexed offerId,
        uint256  compactSettlementDetail,
        bytes32 txHash,
        bytes32 outputHash,
        bytes32 secret
    );
    event OfferExtendedEvent(uint256 offerId, uint32 offerValidTill);
    event OfferCancelEvent(uint256 offerId);

    constructor(address _tokenContract, address txInclusionVerifier) {
        orderBookCompactMetadata = (uint256(uint160(_tokenContract)) <<
            (12 * 8));
        MyTokenERC20 = IERC20(_tokenContract);
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
        bytes20 pubKeyHash,
        uint32 offerValidTill
    ) public payable {
        CompactMetadata memory compact = deconstructMetadata();
        require(compact.tokenContract == address(0x0));
        require(msg.value >= weieth, "Please send the correct eth amount!");
        Offer memory offer;
        offer.offeredBy = msg.sender;
        offer.offerQuantity = msg.value;
        offer.satoshisToReceive = satoshis;
        offer.pubKeyHash = pubKeyHash;
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
        bytes20 pubKeyHash,
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
        offer.pubKeyHash = pubKeyHash;
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


    function recoverExpiredSettlements(uint256 offerId, uint256 settlementId, Offer memory offer) private returns (Offer memory updatedOffer, bool settlementExists )  {
        uint256[] memory settlementIds = offer.settlementRequests;
        for (uint256 index = 0; index < settlementIds.length; index++) {
            SettlementRequest
                memory existingSettlementRequest = initializedSettlements[
                    offerId
                ][settlementIds[index]];
            if (
                existingSettlementRequest.expiryTime < block.timestamp &&
                existingSettlementRequest.isExpired == false &&
                existingSettlementRequest.settled == false
            ) {
                // Claim any satoshis reserved
                offer.satoshisReserved -= existingSettlementRequest
                    .quantityRequested;

                initializedSettlements[offerId][settlementIds[index]]
                    .isExpired = true;
            }
            if (settlementId == settlementIds[index]) {
                settlementExists = true;
            }
        }
        updatedOffer = offer;
    }

    /**

        Initiates the settlement
        - Checks if there is an existing settlement
        - Checks if there is an existing settlement

     */

    function initiateSettlement(
        uint256 offerId,
        SettlementRequest calldata _settlement,
        PaymentProof calldata proof
    ) public payable {
        uint256 settlementId = uint160(msg.sender);
        require(
             (
                (
                    (initializedSettlements[offerId][settlementId].settledBy == address(0x0)) ||
                    (initializedSettlements[offerId][settlementId].expiryTime > 0 && initializedSettlements[offerId][settlementId].expiryTime < block.timestamp)
                ) &&
                (
                    (initializedSettlements[offerId][settlementId].settled == false)
                )
             ),
             "Cannot update an existing or non-expired settlement"
        );
        Offer memory offer = offers[offerId];
        uint64 satoshisToReceive = offer.satoshisToReceive;
        uint64 satoshisReserved = offer.satoshisReserved;
        uint64 satoshisReceived = offer.satoshisReceived;

        bool settlementExists = false;
        (offer, settlementExists) = recoverExpiredSettlements(offerId, settlementId, offer);
        
        satoshisReserved = offer.satoshisReserved;
        if (
            !(satoshisToReceive >=
                (satoshisReserved +
                    satoshisReceived +
                    _settlement.quantityRequested))
        ) {
            revert ValidateOfferQuantity({
                satoshisToReceive: satoshisToReceive,
                satoshisReserved: satoshisReserved,
                satoshisReceived: satoshisReceived,
                quantityRequested: _settlement.quantityRequested
            });
        }
        SettlementRequest memory settlement = _settlement;
        settlement.settledBy = msg.sender;
        settlement.isExpired = false;
        settlement.settlementRequestedTime = uint32(block.timestamp);
        (bytes32 txId, bytes memory output) = validateProof(offerId, settlementId, _settlement, proof);
        settlement.txId = txId;
        bytes32 scriptOutputHash = sha256(bytes.concat(sha256(output)));
        settlement.scriptOutputHash = scriptOutputHash;

        settlement.expiryTime =
            uint32(block.timestamp) +
            SETTLEMENT_COMPETION_WINDOW; 
        initializedSettlements[offerId][settlementId] = settlement;
        // offers[offerId].satoshisReserved = offer.satoshisReserved;
        offers[offerId].satoshisReserved =
            offer.satoshisReserved +
            _settlement.quantityRequested;

        if (settlementExists) {
            offers[offerId].settlementRequests.push(settlementId);
        }
        emit INITIALIZED_SETTLEMENT(msg.sender, offerId, settlementId);
    }

    // get the initial fullfillments list
    function getInitiatedSettlements(
        uint256 offerId
    ) public view returns (ResultSettlementRequest[] memory) {
        uint256[] memory settlementIds = offers[offerId].settlementRequests;
        ResultSettlementRequest[]
            memory resultSettlementRequest = new ResultSettlementRequest[](
                settlementIds.length
            );

        for (uint256 index = 0; index < settlementIds.length; index++) {
            SettlementRequest
                memory existingSettlementRequest = initializedSettlements[
                    offerId
                ][settlementIds[index]];
            resultSettlementRequest[index] = ResultSettlementRequest(
                existingSettlementRequest,
                settlementIds[index]
            );
        }

        return resultSettlementRequest;
    }

    function validateProof(uint256 offerId, uint256 settlementId, SettlementRequest calldata settlementRequest, PaymentProof calldata proof) private view returns (bytes32 txId, bytes memory scriptOutput) {
        uint256 valueRequested = settlementRequest
            .quantityRequested;
        scriptOutput = BitcoinTransactionUtils.getTrustlexScriptV3(
                address(this),
                (offerId << 160) | settlementId,
                offers[offerId].pubKeyHash,
                offers[offerId].orderedTime,
                settlementRequest.recoveryPubKeyHash,
                settlementRequest.lockTime,
                settlementRequest.hashedSecret
        );
        require(
            BitcoinTransactionUtils.hasOutput(
                proof.transaction,
                valueRequested,
                scriptOutput
            ),
            "required output is not available"
        );

        txId = BitcoinUtils._sha256d(proof.transaction);
        //txId = sha256(abi.encodePacked(sha256(proof.transaction)));
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

    function settleOffer(uint256 offerId, uint256 settlementId) private {
        offers[offerId].satoshisReceived += initializedSettlements[offerId][
            settlementId
        ].quantityRequested;
        offers[offerId].satoshisReserved -= initializedSettlements[offerId][
            settlementId
        ].quantityRequested;
    }

    function settleSettlement(uint256 offerId, uint256 settlementId) private {
        initializedSettlements[offerId][settlementId].settledTime = uint32(
            block.timestamp
        );
        initializedSettlements[offerId][settlementId]
            .settled = true;
    }

    function settleFunds(uint256 offerId, uint256 settlementId, address tokenContract) private {
        // Send ETH / TOKEN on success
        uint256 payAmountETh = (
            initializedSettlements[offerId][settlementId].quantityRequested
        ) * (offers[offerId].offerQuantity / offers[offerId].satoshisToReceive);
        if (tokenContract == address(0x0)) {
            bool success = payable(
                msg.sender
            ).send(payAmountETh);
            require(success, "Transfer failed");
        } else {
            IERC20(tokenContract).transfer(
                msg.sender,
                payAmountETh
            );
        }
    }
    /*
       settleFunds:

       User reveals the HTLC secret.
       Contract checks:
        - If the given secret is valid
        - Checks if the settlement has not expired
        - checks if it was not settled before
    */
    function settle(
        uint256 offerId,
        HTLCReveal calldata htlcDetail
    ) external {
        uint256 settlementId = uint160(msg.sender);
        require(initializedSettlements[offerId][settlementId].settledBy == msg.sender, "Settlement should exist");
        require(initializedSettlements[offerId][settlementId].expiryTime > block.timestamp, "Settlement has expired");
        require(
            sha256(bytes.concat(sha256(bytes.concat(htlcDetail.secret)))) == initializedSettlements[offerId][settlementId].hashedSecret, 
            "Hashed secret doesn't match"
        );
        require(
            initializedSettlements[offerId][settlementId].settled == false,
            "Should not have settled before"
        );

        CompactMetadata memory compact = deconstructMetadata();
        settleOffer(offerId, settlementId);
        settleSettlement(offerId, settlementId);
        settleFunds(offerId, settlementId, compact.tokenContract);
        // settleFees

        uint64 quantityRequested =   initializedSettlements[offerId][settlementId]
            .quantityRequested;
            
        emit SETTLEMENT_SUCCESSFUL (
            msg.sender, 
            offers[offerId].offeredBy,
            offerId, 
            (quantityRequested | (uint256(uint160(initializedSettlements[offerId][settlementId].recoveryPubKeyHash)) << (28 * 8))),
            initializedSettlements[offerId][settlementId].txId,
            initializedSettlements[offerId][settlementId].scriptOutputHash,
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
        /*
        require(offers[offerId].offeredBlockNumber > 0, "Invalid Offer ID");
        CompactMetadata memory compact = deconstructMetadata();

        Offer memory offer = offers[offerId];
        uint64 satoshisToReceive = offer.satoshisToReceive;
        uint64 satoshisReserved = offer.satoshisReserved;
        uint64 satoshisReceived = offer.satoshisReceived;
        address offeredBy = offer.offeredBy;
        require(offeredBy == msg.sender, "Offer creator can only cancel offer");
        uint64 returnAbleAmountSatoshi;

        uint256[] memory settlementIds = offer.settlementRequests;
        uint256 payAmount;
        // if offer has no fullfillment orders
        if (settlementIds.length == 0) {
            returnAbleAmountSatoshi = satoshisToReceive;
            offers[offerId].isCanceled = true;
            payAmount =
                (returnAbleAmountSatoshi) *
                (offers[offerId].offerQuantity /
                    offers[offerId].satoshisToReceive);
        } else {
            // if offer has  fullfillments order

            // Update satoshisReserved amount  for expired order
            for (uint256 index = 0; index < settlementIds.length; index++) {
                SettlementRequest
                    memory existingSettlementRequest = initializedSettlements[
                        offerId
                    ][settlementIds[index]];
                if (
                    existingSettlementRequest.expiryTime < block.timestamp &&
                    existingSettlementRequest.isExpired == false &&
                    existingSettlementRequest.paymentProofSubmitted == false
                ) {
                    // Decrease the off satoshi resvered amou t for expired
                    offer.satoshisReserved -= existingSettlementRequest
                        .quantityRequested;

                    initializedSettlements[offerId][settlementIds[index]]
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
        */

        // update the

        emit OfferCancelEvent(offerId);
    }

    function liquidateCollateral() public payable {}

    function getBalance() public view returns (uint256 balance) {
        return address(this).balance;
    }
}

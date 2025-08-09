// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";

import {ILottery} from "./interfaces/ILottery.sol";
import {ILotteryErrors} from "./interfaces/ILotteryErrors.sol";

import {Types} from "./libraries/Types.sol";

/**
 * @notice Main lottery contract.
 */
contract Lottery is ILottery, ILotteryErrors, VRFConsumerBaseV2Plus {
    /**
     * @notice Information about every lottery participant.
     * @dev `participantIndex` helps to map given participant address
     * to its index in {participants}.
     */
    struct ParticipantInfo {
        uint256 ticketsBought;
        uint256 participantIndex;
        bytes encryptedContactDetails;
    }

    /**
     * @notice Common information about all the refunds after
     * particular invalid lottery.
     * @dev Important to notice that `totalUnclaimedFunds` decreases
     * after every user refund, so if whole refund batch expired,
     * organizer can simply withdraw `totalUnclaimedFunds`.
     */
    struct RefundBatch {
        uint256 refundAssignmentTime;
        uint256 totalUnclaimedFunds;
        mapping(address participant => uint256) refundBalances;
    }

    /**
     * @dev A set of state variables used to get information about
     * current lottery event and derive its status.
     */
    struct LotteryState {
        uint256 registrationEndTime;
        uint256 totalExtensionTime;
        bool wasStarted;
        bool waitingForOracleResponse;
        uint256 participantsCount;
        uint256 totalTicketsCount;
    }

    /* dummy values for now */
    uint8 public constant TARGET_PARTICIPANTS_NUMBER = 30;
    uint16 public constant MAX_PARTICIPANTS_NUMBER = 300;
    uint256 public constant REGISTRATION_DURATION = 21 days;
    uint256 public constant MAX_EXTENSION_TIME = 7 days;
    uint256 public constant REFUND_WINDOW = 14 days;

    /**
     * @notice Number of lotteries that must pass after a certain one
     * in order to be able to clear its data.
     */
    uint8 public constant LOTTERY_DATA_FRESHNESS_INTERVAL = 5;
    /**
     * @notice Maximum amount of participants that can be cleared
     * in a single {clearLotteryData} call.
     */
    uint8 public constant MAX_PARTICIPANTS_TO_CLEAR = 40;

    /* Chainlink VRF configuration (see VRFConsumerConfig in
     libraries/Configs.sol) */
    uint256 private immutable SUBSCRIPTION_ID;
    bytes32 private immutable KEY_HASH;
    uint32 private immutable CALLBACK_GAS_LIMIT;
    uint16 private immutable REQUEST_CONFIRMATIONS;

    address public immutable GUIDE_DAO_TOKEN;

    /**
     * @dev Address that can receive money from lotteries and
     * expired refunds.
     */
    address private _organizer;

    LotteryState private _state;

    /**
     * @notice Returns current lottery number.
     * If no one was started up to this moment, returns 0.
     */
    uint256 public lotteryNumber;

    /**
     * @notice Returns participant address from particular lottery by its number
     * and participant index.
     */
    mapping(uint256 lotteryNumber => mapping(uint256 index => address))
        public participants;

    /**
     * @notice Returns participant information from particular lottery by its number
     * and participant index.
     */
    mapping(uint256 lotteryNumber => mapping(address user => ParticipantInfo)) participantsInfo;

    /**
     * @notice Returns refund batch by its id.
     * Important to notice that there is always one refund batch per
     * one invalid lottery.
     */
    mapping(uint256 batchId => RefundBatch) public refundBatches;

    /**
     * @notice Returns batches for which specific user can
     * get their money back.
     */
    mapping(address participant => uint256[]) public refundBatchIds;

    /**
     * @notice If current lottery is declared invalid,
     * it will produce refund batch with the corresponding id.
     *
     * Returns 0 if there is no refund batches avialable.
     */
    uint256 public nextRefundBatchId;

    /**
     * @notice Funds that organizer can freely withdraw to their address.
     * @dev Updated in {fulfillRandomWords}.
     */
    uint256 public organizerFunds;

    uint256 public ticketPrice;

    address public lastWinner;

    /**
     * @notice Data about participants of lottery with `lotteryNumber` number (specifically
     * participants and corresponding participantsInfo) has been cleared from storage,
     * from one index in {participants} to another.
     */
    event LotteryDataCleared(
        uint256 lotteryNumber,
        uint256 fromParticipantIndex,
        uint256 toParticipantIndex
    );

    /**
     * @notice Unable to clear data about lottery participants because
     * current lottery number is not sufficient.
     */
    error TooEarlyToClearData(
        uint256 receivedCurrentLotteryNumber,
        uint256 minimumCurrentLotteryNumber
    );

    /**
     * @dev There is no data about participants of lottery
     * with given number to clear at some index (either there was no data
     * or it had already been cleared),
     */
    error NothingToClear(uint256 lotteryNumber, uint256 fromParticipantIndex);

    constructor(
        address organizer,
        uint256 _ticketPrice,
        address _guideDAOToken,
        address _vrfCoordinator,
        uint256 _subscriptionId,
        bytes32 _keyHash,
        uint32 _callbackGasLimit,
        uint16 _requestConfirmations
    ) VRFConsumerBaseV2Plus(_vrfCoordinator) {
        _organizer = organizer;
        ticketPrice = _ticketPrice;
        GUIDE_DAO_TOKEN = _guideDAOToken;
        SUBSCRIPTION_ID = _subscriptionId;
        KEY_HASH = _keyHash;
        CALLBACK_GAS_LIMIT = _callbackGasLimit;
        REQUEST_CONFIRMATIONS = _requestConfirmations;
    }

    /**
     * @inheritdoc ILottery
     */
    function registrationEndTime() external view returns (uint256) {
        return _state.registrationEndTime;
    }

    /**
     * @inheritdoc ILottery
     */
    function status() external view returns (Types.LotteryStatus) {
        return _status();
    }

    /**
     * @inheritdoc ILottery
     */
    function refundAmount(address _user) external view returns (uint256) {
        uint256[] storage userRefundBatchIds = refundBatchIds[_user];

        uint256 totalRefundAmount;

        for (uint256 i = 0; i < userRefundBatchIds.length; i++) {
            uint256 batchId = userRefundBatchIds[i];
            RefundBatch storage batch = refundBatches[batchId];

            if (block.timestamp <= batch.refundAssignmentTime + REFUND_WINDOW) {
                totalRefundAmount += batch.refundBalances[_user];
            }
        }

        return totalRefundAmount;
    }

    /**
     * @inheritdoc ILottery
     */
    function enter(
        uint256 _ticketsAmount,
        bytes calldata _encryptedContactDetails
    ) external payable {
        Types.LotteryStatus currentStatus = _status();
        require(
            currentStatus == Types.LotteryStatus.OpenedForRegistration,
            IncorrectLotteryStatus(
                currentStatus,
                Types.LotteryStatus.OpenedForRegistration
            )
        );

        mapping(address participant => ParticipantInfo)
            storage actualParticipantsInfo = participantsInfo[lotteryNumber];

        require(
            actualParticipantsInfo[msg.sender].ticketsBought == 0,
            AlreadyRegistered(msg.sender)
        );

        require(
            _state.participantsCount < MAX_PARTICIPANTS_NUMBER,
            ParticipantsLimitExceeded(MAX_PARTICIPANTS_NUMBER)
        );

        require(_ticketsAmount > 0, ZeroTicketsRequested(msg.sender));

        require(
            msg.value == ticketPrice * _ticketsAmount,
            InsufficientFunds(msg.sender, msg.value, ticketPrice)
        );

        LotteryState storage state = _state;

        mapping(uint index => address)
            storage actualParticipants = participants[lotteryNumber];

        actualParticipants[state.participantsCount] = msg.sender;

        ParticipantInfo storage userInfo = actualParticipantsInfo[msg.sender];

        userInfo.encryptedContactDetails = _encryptedContactDetails;
        userInfo.ticketsBought = _ticketsAmount;
        userInfo.participantIndex = state.participantsCount++;

        state.totalTicketsCount += _ticketsAmount;

        emit TicketsBought(lotteryNumber, msg.sender, _ticketsAmount);
    }

    /**
     * @inheritdoc ILottery
     */
    function buyMoreTickets(uint256 _amount) external payable {
        Types.LotteryStatus currentStatus = _status();
        require(
            currentStatus == Types.LotteryStatus.OpenedForRegistration,
            IncorrectLotteryStatus(
                currentStatus,
                Types.LotteryStatus.OpenedForRegistration
            )
        );

        mapping(address participant => ParticipantInfo)
            storage actualParticipantsInfo = participantsInfo[lotteryNumber];

        require(
            actualParticipantsInfo[msg.sender].ticketsBought > 0,
            HasNotRegistered(msg.sender)
        );

        require(_amount > 0, ZeroTicketsRequested(msg.sender));

        require(
            msg.value == ticketPrice * _amount,
            InsufficientFunds(msg.sender, msg.value, ticketPrice)
        );

        actualParticipantsInfo[msg.sender].ticketsBought += _amount;

        _state.totalTicketsCount += _amount;

        emit TicketsBought(lotteryNumber, msg.sender, _amount);
    }

    /**
     * @inheritdoc ILottery
     */
    function returnTickets(uint256 _amount) external {
        Types.LotteryStatus currentStatus = _status();
        require(
            currentStatus == Types.LotteryStatus.OpenedForRegistration,
            IncorrectLotteryStatus(
                currentStatus,
                Types.LotteryStatus.OpenedForRegistration
            )
        );

        mapping(address participant => ParticipantInfo)
            storage actualParticipantsInfo = participantsInfo[lotteryNumber];

        require(_amount > 0, ZeroTicketsRequested(msg.sender));

        require(
            actualParticipantsInfo[msg.sender].ticketsBought >= _amount,
            InsufficientTicketsNumber(
                msg.sender,
                actualParticipantsInfo[msg.sender].ticketsBought,
                _amount
            )
        );

        LotteryState storage state = _state;

        actualParticipantsInfo[msg.sender].ticketsBought -= _amount;

        _state.totalTicketsCount -= _amount;

        if (actualParticipantsInfo[msg.sender].ticketsBought == 0) {
            uint256 participantIndex = actualParticipantsInfo[msg.sender]
                .participantIndex;

            mapping(uint index => address)
                storage actualParticipants = participants[lotteryNumber];

            if (participantIndex != state.participantsCount - 1) {
                actualParticipants[participantIndex] = actualParticipants[
                    state.participantsCount - 1
                ];

                address movedParticipant = actualParticipants[participantIndex];
                actualParticipantsInfo[movedParticipant]
                    .participantIndex = participantIndex;
            }

            delete actualParticipants[--state.participantsCount];
        }

        emit TicketsReturned(lotteryNumber, msg.sender, _amount);

        (bool success, ) = msg.sender.call{value: ticketPrice * _amount}("");

        require(success, WithdrawFailed(msg.sender));
    }

    /**
     * @inheritdoc ILottery
     */
    function refund() external {
        uint256[] storage userRefundBatchIds = refundBatchIds[msg.sender];

        uint256 totalRefundAmount;

        for (uint256 i = 0; i < userRefundBatchIds.length; i++) {
            uint256 batchId = userRefundBatchIds[i];
            RefundBatch storage batch = refundBatches[batchId];

            if (block.timestamp <= batch.refundAssignmentTime + REFUND_WINDOW) {
                uint256 userBatchRefundBalance = batch.refundBalances[
                    msg.sender
                ];

                batch.refundBalances[msg.sender] = 0;
                totalRefundAmount += userBatchRefundBalance;
                batch.totalUnclaimedFunds -= userBatchRefundBalance;
            }
        }

        delete refundBatchIds[msg.sender];

        require(totalRefundAmount > 0, ZeroRefundBalance(msg.sender));

        emit MoneyRefunded(msg.sender, totalRefundAmount);

        (bool success, ) = msg.sender.call{value: totalRefundAmount}("");

        require(success, WithdrawFailed(msg.sender));
    }

    /**
     * @inheritdoc ILottery
     */
    function start() external /* access modifier */ {
        Types.LotteryStatus currentStatus = _status();
        require(
            currentStatus == Types.LotteryStatus.Closed,
            IncorrectLotteryStatus(currentStatus, Types.LotteryStatus.Closed)
        );

        lotteryNumber++;

        LotteryState storage state = _state;

        state.registrationEndTime = block.timestamp + REGISTRATION_DURATION;
        state.wasStarted = true;

        emit LotteryStarted(lotteryNumber, block.timestamp);
    }

    /**
     * @inheritdoc ILottery
     */
    function extendRegistrationTime(
        uint256 _duration
    ) external /* access modifier */ {
        Types.LotteryStatus currentStatus = _status();
        require(
            currentStatus == Types.LotteryStatus.OpenedForRegistration,
            IncorrectLotteryStatus(
                currentStatus,
                Types.LotteryStatus.OpenedForRegistration
            )
        );

        LotteryState storage state = _state;

        uint256 desiredExtensionTime = state.totalExtensionTime + _duration;
        require(
            desiredExtensionTime <= MAX_EXTENSION_TIME,
            ExtensionTooLong(desiredExtensionTime, MAX_EXTENSION_TIME)
        );

        state.totalExtensionTime = desiredExtensionTime;
        state.registrationEndTime += _duration;

        emit RegistrationTimeExtended(lotteryNumber, _duration);
    }

    /**
     * @inheritdoc ILottery
     */
    function closeInvalidLottery() external /* access modifier */ {
        Types.LotteryStatus currentStatus = _status();
        require(
            currentStatus == Types.LotteryStatus.Invalid,
            IncorrectLotteryStatus(currentStatus, Types.LotteryStatus.Invalid)
        );

        uint256 currentBatchId = nextRefundBatchId++;

        RefundBatch storage batch = refundBatches[currentBatchId];

        batch.refundAssignmentTime = block.timestamp;

        for (uint256 i = 0; i < _state.participantsCount; i++) {
            address participant = participants[lotteryNumber][i];

            uint256 userRefundBalance = participantsInfo[lotteryNumber][
                participant
            ].ticketsBought * ticketPrice;

            batch.refundBalances[participant] += userRefundBalance;
            batch.totalUnclaimedFunds += userRefundBalance;

            refundBatchIds[participant].push(currentBatchId);
        }

        delete _state;

        emit InvalidLotteryClosed(lotteryNumber, block.timestamp);
    }

    /**
     * @inheritdoc ILottery
     */
    function requestWinner() external /* access modifier */ {
        Types.LotteryStatus currentStatus = _status();
        require(
            currentStatus == Types.LotteryStatus.RegistrationEnded,
            IncorrectLotteryStatus(
                currentStatus,
                Types.LotteryStatus.RegistrationEnded
            )
        );

        _state.waitingForOracleResponse = true;

        uint256 requestId = s_vrfCoordinator.requestRandomWords(
            VRFV2PlusClient.RandomWordsRequest({
                keyHash: KEY_HASH,
                subId: SUBSCRIPTION_ID,
                requestConfirmations: REQUEST_CONFIRMATIONS,
                callbackGasLimit: CALLBACK_GAS_LIMIT,
                numWords: 1,
                extraArgs: VRFV2PlusClient._argsToBytes(
                    VRFV2PlusClient.ExtraArgsV1({nativePayment: false})
                )
            })
        );

        emit WinnerRequested(lotteryNumber, requestId, block.timestamp);
    }

    /**
     * @inheritdoc ILottery
     */
    function withdrawOrganizerFunds() external /* access modifier */ {
        uint256 fundsToWithdraw = organizerFunds;

        require(fundsToWithdraw > 0, ZeroOrganizerBalance());

        organizerFunds = 0;

        emit OrganizerFundsWithdrawn(fundsToWithdraw);

        (bool success, ) = _organizer.call{value: fundsToWithdraw}("");

        require(success, WithdrawFailed(_organizer));
    }

    /**
     * @inheritdoc ILottery
     */
    function collectExpiredRefunds(
        uint256 _batchId
    ) external /* access modifier */ {
        RefundBatch storage batch = refundBatches[_batchId];

        uint256 totalUnclaimedFunds = batch.totalUnclaimedFunds;

        require(
            batch.refundAssignmentTime + REFUND_WINDOW < block.timestamp &&
                totalUnclaimedFunds > 0,
            NoExpiredRefunds()
        );

        batch.totalUnclaimedFunds = 0;

        emit ExpiredRefundsCollected(_batchId);

        (bool success, ) = _organizer.call{value: totalUnclaimedFunds}("");

        require(success, WithdrawFailed(_organizer));
    }

    /**
     * @notice Clear data about participants of given lottery,
     * starting from certain index with defined maximum of {MAX_PARTICIPANTS_TO_CLEAR}.
     *
     * Emits {LotteryDataCleared} event.
     *
     * Requirements:
     * - Caller has permissions to clear lottery data
     * - Difference between current lottery number and number of
     * lottery to be cleared is at least {LOTTERY_DATA_FRESHNESS_INTERVAL}
     * - There is some data to clear at the specified index.
     */
    function clearLotteryData(
        uint256 _lotteryNumberToClear,
        uint256 _fromParticipantIndex
    ) external /* access modifier */ {
        uint256 minimumCurrentLotteryNumber = _lotteryNumberToClear +
            LOTTERY_DATA_FRESHNESS_INTERVAL;
        require(
            lotteryNumber >= minimumCurrentLotteryNumber,
            TooEarlyToClearData(lotteryNumber, minimumCurrentLotteryNumber)
        );

        uint8 clearedAmount;

        mapping(uint256 index => address)
            storage lotteryParticipants = participants[_lotteryNumberToClear];

        mapping(address participant => ParticipantInfo)
            storage lotteryParticipantsInfo = participantsInfo[
                _lotteryNumberToClear
            ];

        for (
            uint i = _fromParticipantIndex;
            clearedAmount < MAX_PARTICIPANTS_TO_CLEAR;
            i++
        ) {
            address participant = lotteryParticipants[i];

            if (participant == address(0)) {
                break;
            }

            delete lotteryParticipantsInfo[participant];
            delete lotteryParticipants[i];

            clearedAmount++;
        }

        require(
            clearedAmount > 0,
            NothingToClear(_lotteryNumberToClear, _fromParticipantIndex)
        );

        emit LotteryDataCleared(
            _lotteryNumberToClear,
            _fromParticipantIndex,
            _fromParticipantIndex + clearedAmount - 1
        );
    }

    function setOrganizer(
        address _newOrganizer
    ) external /* access modifier */ {
        require(_newOrganizer != address(0), ZeroOrganizerAddress());

        emit OrganizerChanged(_organizer, _newOrganizer);
        _organizer = _newOrganizer;
    }

    function setTicketPrice(
        uint256 _newTicketPrice
    ) external /* access modifier */ {
        Types.LotteryStatus currentStatus = _status();
        require(
            currentStatus == Types.LotteryStatus.Closed,
            IncorrectLotteryStatus(currentStatus, Types.LotteryStatus.Closed)
        );

        require(_newTicketPrice != 0, ZeroTicketPrice());

        emit TicketPriceChanged(ticketPrice, _newTicketPrice);
        ticketPrice = _newTicketPrice;
    }

    function f(uint256 requestId, uint256[] calldata randomWords) external {
        fulfillRandomWords(requestId, randomWords);
    }

    /**
     * @dev Callback to receive random words from
     * Chainlink oracle.
     */
    function fulfillRandomWords(
        uint256 /* requestId */,
        uint256[] calldata randomWords
    ) internal virtual override {
        uint256 winnerTicketId = (randomWords[0] % _state.totalTicketsCount) +
            1;
        address winner = _findWinnerFromUsers(winnerTicketId);

        lastWinner = winner;

        organizerFunds += _state.participantsCount * ticketPrice;

        delete _state;

        (bool success, ) = GUIDE_DAO_TOKEN.call(
            abi.encodeWithSignature(
                "setIsInWhiteList(address,bool)",
                winner,
                true
            )
        );

        require(success, CallFailed(GUIDE_DAO_TOKEN));

        emit WinnerRevealed(lotteryNumber, winner, block.timestamp);
    }

    /**
     * @dev Derives current lottery status.
     *
     *                  Lottery was started?
     *                 / (Yes)         (No) \
     *   Registration time has expired     Closed
     *        or there is maximum
     *      participants number already?
     *        / (Yes)         (No) \
     *   If registration time     OpenedForRegistration
     *      has expired, is
     *  participants number enough?
     *       / (Yes)   (No) \
     *      Waiting for    Invalid
     *    oracle response?
     *     / (Yes)  (No) \
     * WaitingForReveal  RegistrationEnded
     */
    function _status() private view returns (Types.LotteryStatus) {
        if (!_state.wasStarted) return Types.LotteryStatus.Closed;
        if (
            block.timestamp < _state.registrationEndTime &&
            _state.participantsCount < MAX_PARTICIPANTS_NUMBER
        ) return Types.LotteryStatus.OpenedForRegistration;
        if (_state.participantsCount < TARGET_PARTICIPANTS_NUMBER)
            return Types.LotteryStatus.Invalid;
        if (_state.waitingForOracleResponse) {
            return Types.LotteryStatus.WaitingForReveal;
        } else {
            return Types.LotteryStatus.RegistrationEnded;
        }
    }

    /**
     * @notice Function to find winner address from winner ticket id.
     * @dev Returns organizer address, if total tickets amount is less than
     * winnter ticket id, which should really never happen.
     */
    function _findWinnerFromUsers(
        uint256 _winnerTicketId
    ) internal view returns (address) {
        uint256 cumulativeTickets = 0;

        for (uint256 i = 0; i < _state.participantsCount; i++) {
            address participant = participants[lotteryNumber][i];
            cumulativeTickets += participantsInfo[lotteryNumber][participant]
                .ticketsBought;

            if (_winnerTicketId <= cumulativeTickets) {
                return participant;
            }
        }

        return _organizer;
    }
}

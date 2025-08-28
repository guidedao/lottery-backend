// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Types} from "../libraries/Types.sol";

/**
 * @notice Lottery contract interface with functions and events
 * necessary for interaction with end users.
 */
interface ILottery {
    /**
     * @notice `participant` has bought `amount` tickets.
     */
    event TicketsBought(
        uint256 indexed lotteryNumber,
        address indexed participant,
        uint256 amount
    );

    /**
     * @notice `participant` returned `amount` of their tickets back.
     */
    event TicketsReturned(
        uint256 indexed lotteryNumber,
        address indexed participant,
        uint256 amount
    );

    /**
     * @notice Participant has refunded their money as the lottery
     * has been declared invalid and closed.
     */
    event MoneyRefunded(address indexed participant, uint256 amount);

    /**
     * @notice Lottery has started and is opened for registrations.
     */
    event LotteryStarted(uint256 indexed lotteryNumber, uint256 startTime);

    /**
     * @notice Registration time has been prolongated by `duration` seconds.
     */
    event RegistrationTimeExtended(
        uint256 indexed lotteryNumber,
        uint256 duration
    );

    /**
     * @notice Lottery has been closed as invalid.
     */
    event InvalidLotteryClosed(
        uint256 indexed lotteryNumber,
        uint256 closeTime
    );

    /**
     * @notice The next winner reveal is pending.
     * @dev Chainlink VRF {requestRandomWords} has been called.
     */
    event WinnerRequested(
        uint256 indexed lotteryNumber,
        uint256 indexed requestId,
        uint256 requestTime
    );

    /**
     * @notice Lottery has ended with given winner address.
     * @dev Note: there is no particular function to reveal winner
     * in this interface. This event is only emitted in oracle
     * callback {fulfillRandomWords}.
     */
    event WinnerRevealed(
        uint256 indexed lotteryNumber,
        address indexed winner,
        uint revealTime
    );

    /**
     * @notice `amount` wei has been withdrawn to organizer address
     * after at least one successful lottery.
     */
    event OrganizerFundsWithdrawn(uint256 amount);

    /**
     * Refund batch deadlines has expired, and organizer
     * collected that money (`amount` wei).
     */
    event ExpiredRefundsCollected(uint256 indexed batchId, uint256 amount);

    /**
     * @notice Ticket price has been changed from old to new value.
     */
    event TicketPriceChanged(uint256 from, uint256 to);

    /**
     * @notice Organizer has been changed from old to new value.
     */
    event OrganizerChanged(address indexed from, address indexed to);

    /**
     * @notice GuideDAO NFT fallback recipient has been changed from old to new value.
     */
    event NftFallbackRecipientChanged(address indexed from, address indexed to);

    /**
     * @notice Returns number of lotteries that must pass to make
     * it possible to clear its data.
     *
     * User contact details left before this interval are considered stale
     * even if they has not been cleared, and hence they are not returned as
     * result of {latestContactDetails} call.
     */
    function LOTTERY_DATA_FRESHNESS_INTERVAL() external pure returns (uint8);

    /**
     * @notice Returns maximum patricipants number, which is constant.
     */
    function MAX_PARTICIPANTS_NUMBER() external pure returns (uint16);

    /**
     * @notice Returns number of lottery participants if it is active
     * or zero otherwise.
     */
    function participantsCount() external view returns (uint256);

    /**
     * @notice Returns total amount of tickets sold in current
     * lottery. Returns zero if there is no such ongoing one.
     */
    function totalTicketsCount() external view returns (uint256);

    /**
     * @notice Returns amount of tickets bought by particular user in current
     * lottery. Returns zero if there is no such ongoing one.
     */
    function userTicketsCount(address _user) external view returns (uint256);

    /**
     * @notice Returns true only if the lottery is active and given user
     * is its participant.
     */
    function isActualParticipant(address _user) external view returns (bool);

    /**
     * @notice Returns latest encrypted contact details that user has left.
     *
     * Requirements:
     * - User has participated in at least one
     * from last `LOTTERY_DATA_FRESHNESS_INTERVAL` lotteries.
     */
    function latestContactDetails(
        address _user
    ) external view returns (bytes memory);

    /**
     * @notice Returns ticket (entrance) price.
     */
    function ticketPrice() external view returns (uint256);

    /**
     * @notice Returns a enum value reflecting the lottery status.
     * @dev Note: status is derived from registration end time
     * and other state variables rather than set manually.
     */
    function status() external view returns (Types.LotteryStatus);

    /**
     * @notice Returns last winner of the lottery.
     * @dev Returns address(0) before first start.
     */
    function lastWinner() external view returns (address);

    /**
     * @notice Returns timestamp of expected lottery ending.
     * @dev Set to zero if there is no active lottery event.
     * If called during activity, returns the expected end time.
     */
    function registrationEndTime() external view returns (uint256);

    /**
     * @notice Returns current refund balance of the given user.
     */
    function refundAmount(address _user) external view returns (uint256);

    /**
     * @notice Enter lottery with corresponding contact information.
     * @dev Emits {ParticipantRegistered}.
     *
     * Requirements:
     * - `_amount` is not zero
     * - User account has no code
     * - User is not a lottery participant yet
     * - New total number of participants must not exceed the limit
     * - Registration is currently open
     * - The sent ether is sufficient to buy given tickets amount
     */
    function enter(
        uint256 _ticketsAmount,
        bytes calldata _encryptedContactDetails
    ) external payable;

    /**
     * @notice Buy specified amount of lottery tickets.
     * @dev Emits {TicketsBought}.
     *
     * Requirements:
     * - `_amount` is not zero
     * - User is a lottery participant
     * - Registration is currently open
     * - The sent ether is sufficient to buy given tickets amount
     */
    function buyMoreTickets(uint256 _amount) external payable;

    /**
     * @notice Sold some lottery tickets and receive a part of money back.
     * @dev Emits {TicketsReturned}.
     *
     * Requirements:
     * - Caller has at least `_amount` tickets
     * - Registration is currently open
     */
    function returnTickets(uint256 _amount) external;

    /**
     * @notice Refund all the avialable money if the user
     * participated in an invalid lottery.
     * @dev Money can be refunded after the lottery has been closed as invalid.
     *
     * Emits {MoneyRefunded} event.
     *
     * Requirements:
     * - Caller unexpired refund balance is more than zero
     */
    function refund() external;

    /**
     * @notice Start lottery event.
     * @dev Sets new registration end time based on current time
     * and default duration.
     *
     * Emits {LotteryStarted}.
     *
     * Requirements:
     * - Caller has permissions to control lottery flow
     * - Lottery is closed at the moment
     */
    function start() external;

    /**
     * @notice Extend registration time by given duration.
     * @dev Emits {RegistationTimeExtended}.
     *
     * Requirements:
     * - Caller has permissions to control lottery flow
     * - Registration is currently open
     * - Total extension time is not greater than the known constant
     */
    function extendRegistrationTime(uint256 _duration) external;

    /**
     * @notice Close lottery if it is invalid.
     * @dev Resets corresponding state variables and
     * updates all participants refund balances.
     *
     * Emits {InvalidLotteryClosed} event.
     *
     * Requirements:
     * - Caller has permissions to control lottery flow
     * - Lottery is currently invalid
     */
    function closeInvalidLottery() external;

    /**
     * @notice Request the lottery winner reveal.
     * @dev This function actually requests random words from Chainlink oracle
     * using their {requestRandomWords} method.
     *
     * Emits {WinnerRequested}.
     *
     * Requirements:
     * - Caller has permissions to control lottery flow
     * - Registration time has ended
     * - Participants amount is not less than expected
     */
    function requestWinner() external;

    /**
     * @notice Withdraw all accessible organizer funds to `_recipient` address.
     * @dev Note: accessible organizer funds are updated only after successful
     * lottery event in {fulfillRandomWords} callback.
     *
     * Emits {OrganizerFundsWithdrawn}.
     *
     * Requirements:
     * - Caller has permissions to withdraw money
     * - Accessible organizer funds is more than zero
     */
    function withdrawOrganizerFunds(address _recipient) external;

    /**
     * @notice Withdraw all refund money with expired deadlines from
     * one particular batch (i.e. from single invalid lottery).
     * @dev Emits {ExpiredRefundsCollected} event.
     *
     * Requirements:
     * - Caller has permission to withdraw money
     * - There is more than zero expired refunds
     */
    function collectExpiredRefunds(
        uint256 _batchId,
        address _recipient
    ) external;

    /**
     * @notice Change current organizer.
     * @dev Revokes organizer role from current organizer
     * and grants such to a new one.
     *
     * Emits {OrganizerChanged}.
     *
     * Requirements:
     * - Caller is current organizer
     * - New organizer is not zero address
     */
    function changeOrganizer(address _newOrganizer) external;

    /**
     * @notice Change current NFT fallback recipient.
     * @dev Emits {NftFallbackRecipientChanged}.
     *
     * Requirements:
     * - Caller is current organizer
     * - New NFT fallback recipient is not zero address
     * - New NFT fallback recipient account has no code
     */
    function changeNftFallbackRecipient(
        address _newNftFallbackRecipient
    ) external;

    /**
     * @notice Change current ticket price.
     * @dev Emits {TicketPriceChanged} event.
     *
     * Requirements:
     * - Caller has permissions to change ticket price
     * - Lottery is closed at the moment
     * - New price is greater than zero
     */
    function setTicketPrice(uint256 _newTicketPrice) external;
}

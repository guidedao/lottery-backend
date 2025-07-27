// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Types} from "../libraries/Types.sol";

/**
 * @notice Lottery contract interface with functions and events
 * necessary for interaction with end users.
 */
interface ILottery {
    /**
     * @notice New participant has entered the lottery.
     */
    event ParticipantRegistered(address indexed participant);

    /**
     * @notice Participant has unregistered from the lottery.
     */
    event ParticipantQuitted(address indexed participant);

    /**
     * @notice Participant has refunded their money as the lottery
     * has been declared invalid and closed.
     */
    event MoneyRefunded(address indexed participant);

    /**
     * @notice Lottery has started and is opened for registrations.
     */
    event LotteryStarted(uint256 startTimestamp);

    /**
     * @notice Registration time has been prolongated by `duration` seconds.
     */
    event RegistrationTimeExtended(uint256 duration);

    /**
     * @notice Lottery has been closed as invalid.
     */
    event InvalidLotteryClosed(uint256 closeTimestamp);

    /**
     * @notice The next winner reveal is pending.
     * @dev Chainlink VRF {requestRandomWords} has been called.
     */
    event WinnerRequested(uint256 requestId, uint256 requestTimestamp);

    /**
     * @notice Lottery has ended with given winner address.
     * @dev Note: there is no particular function to reveal winner
     * in this interface. This event is only emitted in oracle
     * callback {fulfillRandomWords}.
     */
    event WinnerRevealed(address indexed winner, uint revealTimestamp);

    /**
     * @notice `amount` wei has been withdrawn to organizer address
     * after at least one successful lottery.
     */
    event OrganizerFundsWithdrawn(uint256 amount);

    /**
     * The `participant`'s refund deadline has expired, and organizer
     * collected that money.
     */
    event ExpiredRefundCollected(address indexed participant, uint256 amount);

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
     * @notice Enter lottery with corresponding contact information.
     * @dev Emits {ParticipantRegistered}.
     *
     * Requirements:
     * - Caller has not registered before
     * - Registration is currently open
     * - The sent ether is sufficient to buy a ticket
     * */
    function enter(bytes calldata _encryptedContactDetails) external payable;

    /**
     * @notice Quit the lottery.
     * @dev Emits {ParticipantQuitted}.
     *
     * Requirements:
     * - Caller is a registered lottery participant
     * - Registration is currently open
     */
    function quit() external;

    /**
     * @notice Refund money if the user participated in an invalid lottery.
     * @dev Money can be refunded after the lottery has been closed as invalid.
     *
     * Emits {MoneyRefunded} event.
     *
     * Requirements:
     * - Caller refund balance is more than zero
     * - Refund window is not closed
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
     * @notice Extends registration time by given duration.
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
     * @notice Withdraw all accessible organizer funds to their address.
     * @dev Note: accessible organizer funds are updated only after successful
     * lottery event in {fulfillRandomWords} callback.
     *
     * Emits {OrganizerFundsWithdrawn}.
     *
     * Requirements:
     * - Caller has permissions to withdraw money
     * - Accessible organizer funds is more than zero
     */
    function withdrawOrganizerFunds() external;

    /**
     * @notice Withdraw all refund money with expired deadlines.
     * @dev Emits a number of {ExpiredRefundCollected} events.
     *
     * Requirements:
     * - Caller has permission to withdraw money
     * - There is more than zero expired refunds
     */
    function collectExpiredRefunds() external;
}

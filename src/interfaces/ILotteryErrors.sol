// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Types} from "../libraries/Types.sol";

/**
 * @notice Lottery contract errors interface.
 */
interface ILotteryErrors {
    /**
     * @notice The amount of ether sent is not enough.
     */
    error InsufficientFunds(address sender, uint256 sent, uint256 needed);

    /**
     * @notice The `participant` has already registered in the lottery.
     */
    error AlreadyRegistered(address participant);

    /**
     * @notice `buyer` requested zero tickets to buy.
     */
    error ZeroTicketsToBuy(address buyer);

    /**
     * @notice New user cannot enter the lottery, since participants
     * limit has been already reached.
     */
    error ParticipantsLimitExceeded(uint limit);

    /**
     * @notice The `caller` is not a lottery participant.
     */
    error HasNotRegistered(address caller);

    /**
     * @notice The `caller` has zero refund balance.
     */
    error ZeroRefundBalance(address caller);

    /**
     * @notice Unable to refund money as deadline has expired.
     */
    error RefundWindowIsClosed(
        uint256 currentTimestamp,
        uint256 refundDeadlineTimestamp
    );

    /*
     * @notice Received lottery status does not match expected.
     */
    error IncorrectLotteryStatus(
        Types.LotteryStatus received,
        Types.LotteryStatus expected
    );

    /**
     * @notice Total registration time extension is more than allowed.
     */
    error ExtensionTooLong(uint256 total, uint256 allowed);

    /**
     * @notice Unable to withdraw organizer funds, as they
     * have no accessible funds.
     */
    error ZeroOrganizerBalance();

    /**
     * @notice Unable to collect expired refunds as there is no such one.
     */
    error NoExpiredRefunds();

    /**
     * @notice Unable to send money to the `receiver`.
     */
    error WithdrawFailed(address receiver);
}

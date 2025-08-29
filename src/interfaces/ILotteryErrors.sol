// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Types} from "../libraries/Types.sol";

/**
 * @notice Lottery contract errors interface.
 */
interface ILotteryErrors {
    /**
     * @notice There are no contact details about this particular user
     * or they are stale.
     */
    error NoContactDetails(address user);

    /**
     * @notice `caller` account has code.
     */
    error HasCode(address caller);

    /**
     * @notice Attached contact details bytes array has zero length.
     */
    error ZeroLengthContactDetails();

    /**
     * @notice The amount of ether sent is not enough or too large.
     */
    error IncorrectPaymentAmount(address sender, uint256 sent, uint256 needed);

    /**
     * @notice The `participant` has already registered in the lottery.
     */
    error AlreadyRegistered(address participant);

    /**
     * @notice `caller` requested zero tickets to buy or return.
     */
    error ZeroTicketsRequested(address caller);

    /**
     * @notice `caller` already has GuideDAO NFT.
     */
    error AlreadyHasToken(address caller);

    /**
     * @notice The `caller` has not entered the lottery before.
     */
    error HasNotRegistered(address caller);

    /**
     * @notice The `caller` tried to return more tickets than they have.
     */
    error InsufficientTicketsNumber(
        address caller,
        uint256 has,
        uint256 requested
    );

    /**
     * @notice The `caller` has zero refund balance.
     */
    error ZeroRefundBalance(address caller);

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

    /**
     * @notice Unable to call some function at the `receiver` contract.
     */
    error CallFailed(address callable);

    /**
     * @notice Unable to change organizer address to zero.
     */
    error ZeroOrganizerAddress();

    /**
     * @notice Unable to change NFT fallback recipient address to zero.
     */
    error ZeroNftFallbackRecipientAddress();

    /**
     * @notice Unable to change ticket price to zero.
     */
    error ZeroTicketPrice();
}

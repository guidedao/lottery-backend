//SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/**
 * @notice Essential types related to lottery contract.
 */
library Types {
    /**
     * @notice Enum values describing current lottery status.
     * @dev Statuses desription:
     * - Closed: there is no active lottery event at the moment.
     * - OpenedForRegistration: users can enter and quit the lottery only during this phase.
     * - RegistrationEnded: registration time has ended, but winner reveal is not pending yet.
     * That actually means that registration is closed, but Chainlink VRF
     * {requestRandomWords} has not been called yet.
     * - WaitingForReveal: that means that {requestRandomWords} is called,
     * and we are waiting for the oracle response.
     * - Invalid: Lottery is invalid as there were not enough
     * participants after registration.
     */
    enum LotteryStatus {
        Closed,
        OpenedForRegistration,
        RegistrationEnded,
        WaitingForReveal,
        Invalid
    }
}

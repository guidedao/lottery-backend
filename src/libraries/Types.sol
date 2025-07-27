//SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/**
 * @notice Essential types related to lottery contract.
 */
library Types {
    /**
     * @notice Enum values describing current lottery status.
     */
    enum LotteryStatus {
        /**
         * @notice There is no active lottery event at the moment.
         */
        Closed,
        /**
         * @notice Users can enter and quit the lottery only during this phase.
         */
        OpenedForRegistration,
        /**
         * @notice Registration time has ended, but winner reveal is not pending yet.
         * @dev That actually means that registration is closed, but Chainlink VRF
         * {requestRandomWords} has not been called yet.
         */
        RegistrationEnded,
        /**
         * @notice Waiting for winner reveal.
         * @dev That means that {requestRandomWords} is called,
         * and we are waiting for the oracle response.
         */
        WaitingForReveal,
        /**
         * @notice Lottery is invalid as there were not enough
         * participants after registration.
         */
        Invalid
    }
}

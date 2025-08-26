// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/**
 * @dev Configuration that includes all the necessary
 * information to deploy mock VRF coordinator for local testing.
 *
 * Adjust if needed.
 *
 * See details here: https://docs.chain.link/vrf/v2-5/subscription/test-locally
 */
library VRFCoordinatorMockConfig {
    uint96 constant BASE_FEE = 100000000000000000;
    uint96 constant GAS_PRICE_LINK = 1000000000;
    int256 constant WEI_PER_UNIT_LINK = 5000000000000000;
}

/**
 * @notice Configuration that includes all the necessary
 * information for interaction with the Chainlink VRF oracle.
 * @dev Lottery contract is using subscription method to
 * receive random numbers, and this config provides
 * all the data required to call {requestRandomWords} on the VRF coordinator.
 *
 * If using on production or public testnets, `VRF_COORDINATOR`,
 * `SUBSCRIPTION_ID` and `KEY_HASH` are taken from Chainlink Subscription Manager.
 *
 * If running locally, values of `VRF_COORDINATOR` and `SUBSCRIPTION_ID` are shown
 * after mocks deployment and subscription funding respectively.
 * `KEY_HASH` in this case is just an arbibtrary bytes32.
 *
 * See details here: https://docs.chain.link/vrf/v2-5/overview/subscription
 */
library VRFConsumerConfig {
    bytes32 constant KEY_HASH =
        0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae;
    uint32 constant CALLBACK_GAS_LIMIT = 1500000;
    uint16 constant REQUEST_CONFIRMATIONS = 3;
}

/**
 * @dev Initial lottery configuration for deployment with
 * essential business logic variables.
 */
library LotteryConfig {
    uint256 constant INITIAL_TICKET_PRICE = 0.02 ether;
    uint8 constant TARGET_PARTICIPANTS_NUMBER = 20;
    uint16 constant MAX_PARTICIPANTS_NUMBER = 200;
    uint256 constant REGISTRATION_DURATION = 21 days;
    uint256 constant MAX_EXTENSION_TIME = 7 days;
    uint256 constant REFUND_WINDOW = 14 days;
}

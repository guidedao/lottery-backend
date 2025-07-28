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
    uint96 constant BASE_FEE = 1000000000;
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
 * If using locally, values of `VRF_COORDINATOR` and `SUBSCRIPTION_ID` are shown
 * after mocks deployment. `KEY_HASH` in this case is just an arbibtrary bytes32.
 *
 * See details here: https://docs.chain.link/vrf/v2-5/overview/subscription
 */
library VRFConsumerConfig {
    address constant VRF_COORDINATOR =
        0xCf7Ed3AccA5a467e9e704C703E8D87F634fB0Fc9;
    uint256 constant SUBSCRIPTION_ID =
        54753833497567038066716471788848271430911612990399625499085727603424022386543;
    bytes32 constant KEY_HASH =
        0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae;
    uint32 constant CALLBACK_GAS_LIMIT = 1000000;
    uint16 constant REQUEST_CONFIRMATIONS = 3;
    uint32 constant NUM_WORDS = 1;
}

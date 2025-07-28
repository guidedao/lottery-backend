// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script, console} from "forge-std/Script.sol";

import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";

import {GuideDAOTokenMock} from "test/mocks/GuideDAOTokenMock.sol";

import {VRFConsumerConfig} from "src/libraries/Configs.sol";

/**
 * @dev Script to locally add lottery contract to the consumers list of
 * VRF coordinator.
 *
 * Do not forget to deploy mocks and lottery before executing this script.
 *
 * If you are running on production or public testnets, use Chainlink
 * Subscription Manager instead.
 *
 * Note: ensure that your VRF consumer config is correctly set up at first.
 */
contract AddConsumerScript is Script {
    function run() external {
        address consumer = vm.parseAddress(
            vm.prompt("Enter mock lottery address: ")
        );

        run(consumer);
    }

    function run(address consumer) public {
        vm.startBroadcast();

        VRFCoordinatorV2_5Mock vrfCoordinatorMock = VRFCoordinatorV2_5Mock(
            VRFConsumerConfig.VRF_COORDINATOR
        );

        vrfCoordinatorMock.addConsumer(
            VRFConsumerConfig.SUBSCRIPTION_ID,
            consumer
        );

        vm.stopBroadcast();

        console.log("VRF consumer has been added!");
    }
}

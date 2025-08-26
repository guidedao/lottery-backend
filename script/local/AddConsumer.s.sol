// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script, console} from "forge-std/Script.sol";

import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";

import {VRFConsumerConfig} from "src/libraries/Configs.sol";

/**
 * @dev Only for local testing.
 *
 * Script to add lottery contract to the consumers list of
 * VRF coordinator.
 *
 * Note: your VRF consumer config should be correctly set up
 * before executing this script. Make sure that you have deployed mocks
 * along with lottery contract and funded a subscription by this time.
 */
contract AddConsumerScript is Script {
    function run() external {
        address consumer = vm.parseAddress(
            vm.prompt("Enter lottery contract address")
        );

        address vrfCoordinator = vm.parseAddress(
            vm.prompt("Enter Chainlink VRF coordinator address")
        );
        uint256 subscriptionId = vm.parseUint(
            vm.prompt("Enter Chainlink VRF subscription ID")
        );

        run(consumer, subscriptionId, vrfCoordinator);
    }

    function run(
        address _consumer,
        uint256 _subscriptionId,
        address _vrfCoordinator
    ) public {
        vm.startBroadcast();

        VRFCoordinatorV2_5Mock vrfCoordinatorMock = VRFCoordinatorV2_5Mock(
            _vrfCoordinator
        );

        vrfCoordinatorMock.addConsumer(_subscriptionId, _consumer);

        vm.stopBroadcast();

        console.log("VRF consumer has been added!");
    }
}

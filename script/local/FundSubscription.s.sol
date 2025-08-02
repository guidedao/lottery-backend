// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script, console} from "forge-std/Script.sol";

import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";

/**
 * @dev Only for local
 *
 * Script to fund (with 100 LINK) a subscription and return the active
 * subscription id.
 *
 * Note: make sure you have deployed mocks before executing this script.
 */
contract FundSubscriptionScript is Script {
    function run() external {
        address vrfCoordinatorMock = vm.parseAddress(
            vm.prompt("Enter mock VRF coordinator address")
        );

        run(vrfCoordinatorMock);
    }

    function run(address _vrfCoordinatorMock) public {
        vm.startBroadcast();

        VRFCoordinatorV2_5Mock vrfCoordinatorMock = VRFCoordinatorV2_5Mock(
            _vrfCoordinatorMock
        );

        uint256 subscriptionId = vrfCoordinatorMock.getActiveSubscriptionIds(
            0,
            1
        )[0];

        vrfCoordinatorMock.fundSubscription(
            subscriptionId,
            100000000000000000000
        );

        (uint96 balanceInLink, , , , ) = vrfCoordinatorMock.getSubscription(
            subscriptionId
        );

        vm.stopBroadcast();

        console.log("Active subscription id: ", subscriptionId);
        console.log(
            "Current consumer balance in Juels (1e-18 LINK): ",
            balanceInLink
        );
    }
}

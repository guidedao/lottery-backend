// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script, console} from "forge-std/Script.sol";

import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";

import {GuideDAOTokenMock} from "test/mocks/GuideDAOTokenMock.sol";

import {VRFCoordinatorMockConfig} from "src/libraries/Configs.sol";

/**
 * @dev Script to deploy GuideDAO token and VRF coordinator mocks
 * for local testing.
 */
contract MocksDeployScript is Script {
    function run() external {
        vm.startBroadcast();

        VRFCoordinatorV2_5Mock vrfCoordinatorMock = new VRFCoordinatorV2_5Mock(
            VRFCoordinatorMockConfig.BASE_FEE,
            VRFCoordinatorMockConfig.GAS_PRICE_LINK,
            VRFCoordinatorMockConfig.WEI_PER_UNIT_LINK
        );

        GuideDAOTokenMock tokenMock = new GuideDAOTokenMock();

        uint256 subscriptionId = vrfCoordinatorMock.createSubscription();
        vrfCoordinatorMock.fundSubscription(
            subscriptionId,
            1000000000000000000
        );
        vm.stopBroadcast();

        console.log(
            "VRF coordinator mock deployed to: ",
            address(vrfCoordinatorMock)
        );
        console.log("Subscription Id: ", subscriptionId);
        console.log("GuideDAO token mock deployed to: ", address(tokenMock));
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script, console} from "forge-std/Script.sol";

import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";

import {GuideDAOTokenMock} from "test/mocks/GuideDAOTokenMock.sol";

import {VRFCoordinatorMockConfig} from "src/libraries/Configs.sol";

/**
 * @dev Only for local testing.
 *
 * Script to deploy GuideDAO token and VRF coordinator mocks.
 *
 * Note: this script requires a valid mock VRF config, which is set initially.
 * However, you can change some values if there is a need for it.
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

        vrfCoordinatorMock.createSubscription();

        vm.stopBroadcast();

        console.log(
            "VRF coordinator mock deployed to: ",
            address(vrfCoordinatorMock)
        );
        console.log("GuideDAO token mock deployed to: ", address(tokenMock));
    }
}

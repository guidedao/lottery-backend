// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test, console} from "forge-std/Test.sol";

import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";

import {Lottery} from "src/Lottery.sol";
import {ILotteryErrors} from "src/interfaces/ILotteryErrors.sol";

import {GuideDAOTokenMock} from "./mocks/GuideDAOTokenMock.sol";

import {VRFCoordinatorMockConfig, VRFConsumerConfig, LotteryConfig} from "src/libraries/Configs.sol";

import {Types} from "src/libraries/Types.sol";

contract LotteryTest is Test {
    VRFCoordinatorV2_5Mock vrfCoordinator;
    GuideDAOTokenMock guideDAOToken;

    address[200] participants;

    Lottery lottery;

    function setUp() external {
        for (uint i = 0; i < 200; i++) {
            participants[i] = vm.addr(i + 1);
        }

        vrfCoordinator = new VRFCoordinatorV2_5Mock(
            VRFCoordinatorMockConfig.BASE_FEE,
            VRFCoordinatorMockConfig.GAS_PRICE_LINK,
            VRFCoordinatorMockConfig.WEI_PER_UNIT_LINK
        );

        uint256 subscriptionId = vrfCoordinator.createSubscription();
        vrfCoordinator.fundSubscription(subscriptionId, 100000000000000000000);

        guideDAOToken = new GuideDAOTokenMock();

        lottery = new Lottery(
            LotteryConfig.ORGANIZER,
            LotteryConfig.TICKET_PRICE,
            address(guideDAOToken),
            address(vrfCoordinator),
            subscriptionId,
            VRFConsumerConfig.KEY_HASH,
            VRFConsumerConfig.CALLBACK_GAS_LIMIT,
            VRFConsumerConfig.REQUEST_CONFIRMATIONS
        );

        vrfCoordinator.addConsumer(subscriptionId, address(lottery));

        guideDAOToken.setIsAdmin(address(lottery), true);
    }
}

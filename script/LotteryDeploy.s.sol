// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script, console} from "forge-std/Script.sol";

import {Lottery} from "src/Lottery.sol";

import {VRFConsumerConfig} from "src/libraries/Configs.sol";

/**
 * @dev Script to deploy lottery contract.
 *
 * Note: Your VRF consumer config should be correctly set up
 * before executing this script. If you are running locally,
 * make sure that you have deployed mocks and funded a subscription by this time.
 */
contract LotteryDeployScript is Script {
    function run() external {
        address guideDAOToken = vm.parseAddress(
            vm.prompt("Enter GuideDAO token address")
        );

        run(guideDAOToken);
    }

    function run(address guideDaoToken) public {
        vm.startBroadcast();

        Lottery lottery = new Lottery(
            guideDaoToken,
            VRFConsumerConfig.VRF_COORDINATOR,
            VRFConsumerConfig.SUBSCRIPTION_ID,
            VRFConsumerConfig.KEY_HASH,
            VRFConsumerConfig.CALLBACK_GAS_LIMIT,
            VRFConsumerConfig.REQUEST_CONFIRMATIONS,
            VRFConsumerConfig.NUM_WORDS
        );

        vm.stopBroadcast();

        console.log("Lottery contract deployed to: ", address(lottery));
    }
}

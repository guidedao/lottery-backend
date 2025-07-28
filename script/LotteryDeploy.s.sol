// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script, console} from "forge-std/Script.sol";

import {Lottery} from "src/Lottery.sol";

/**
 * @dev Script to deploy lottery contract.
 *
 * If you are running locally, do not forget do deploy mocks before
 * executing this script.
 *
 * Note: ensure that your VRF consumer config is correctly set up at first.
 */
contract LotteryDeployScript is Script {
    function run() external {
        address guideDaoToken = vm.parseAddress(
            vm.prompt("Enter GuideDAO token address")
        );

        run(guideDaoToken);
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

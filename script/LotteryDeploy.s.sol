// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;
pragma solidity ^0.8.30;

import {Script, console} from "forge-std/Script.sol";

import {Lottery} from "src/Lottery.sol";

import {VRFConsumerConfig, LotteryConfig} from "src/libraries/Configs.sol";

/**
 * @dev Script to deploy lottery contract.
 *
 * Note: Your VRF consumer config should be correctly set up
 * before executing this script. If you are running locally,
 * make sure that you have deployed mocks and funded a subscription by this time.
 */
contract LotteryDeployScript is Script {
    function run() external {
        address organizer = vm.parseAddress(
            vm.prompt("Enter initial organizer address")
        );
        address nftFallbackRecipient = vm.parseAddress(
            vm.prompt(
                "Enter address (with no code at account) which will be used as a fallback NFT recipient"
            )
        );
        address guideDAOToken = vm.parseAddress(
            vm.prompt("Enter GuideDAO token address")
        );

        address vrfCoordinator = vm.parseAddress(
            vm.prompt("Enter Chainlink VRF coordinator address")
        );
        uint256 subscriptionId = vm.parseUint(
            vm.prompt("Enter Chainlink VRF subscription ID")
        );

        run(
            organizer,
            nftFallbackRecipient,
            guideDAOToken,
            vrfCoordinator,
            subscriptionId
        );
    }

    function run(
        address _organizer,
        address _nftFallbackRecipient,
        address _guideDAOToken,
        address _vrfCoordinator,
        uint256 _subscriptionId
    ) public {
        vm.startBroadcast();

        Lottery lottery = new Lottery(
            _organizer,
            _nftFallbackRecipient,
            _guideDAOToken,
            _vrfCoordinator,
            _subscriptionId
        );

        vm.stopBroadcast();

        console.log("Lottery contract deployed to:", address(lottery));
    }
}

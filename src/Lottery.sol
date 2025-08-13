// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";

import {ILottery} from "./interfaces/ILoterry.sol";
import {ILotteryErrors} from "./interfaces/ILotteryErrors.sol";

import {Types} from "./libraries/Types.sol";

/**
 * @notice Main lottery contract.
 */
contract Lottery is ILottery, ILotteryErrors, VRFConsumerBaseV2Plus {
    /**
     * @dev A set of state variables used
     * to derive current lottery status and defining its lifecycle.
     */
    struct LotteryState {
        uint256 registrationEndTime;
        bool waitingForOracleResponse;
        // To be done
    }

    LotteryState private _state;

    uint256 private immutable SUBSCRIPTION_ID;
    bytes32 private immutable KEY_HASH;
    uint32 private immutable CALLBACK_GAS_LIMITS;
    uint16 private immutable REQUEST_CONFIRMATIONS;
    uint32 private immutable NUM_WORDS;

    address public immutable _guideDAOToken;

    address public lastWinner;

    constructor(
        address guideDAOToken,
        address _vrfCoordinator,
        uint256 subscriptionId,
        bytes32 keyHash,
        uint32 callbackGasLimit,
        uint16 requestConfirmations,
        uint32 numWords
    ) VRFConsumerBaseV2Plus(_vrfCoordinator) {
        _guideDAOToken = guideDAOToken;
        SUBSCRIPTION_ID = subscriptionId;
        KEY_HASH = keyHash;
        CALLBACK_GAS_LIMITS = callbackGasLimit;
        REQUEST_CONFIRMATIONS = requestConfirmations;
        NUM_WORDS = numWords;
    }

    function registrationEndTime() external view returns (uint256) {
        return _state.registrationEndTime;
    }

    function status() external view returns (Types.LotteryStatus) {}

    function enter(bytes calldata _encryptedContactDetails) external payable {}

    function quit() external {}

    function refund() external {}

    function start() external {}

    function extendRegistrationTime(uint256 _duration) external {}

    function closeInvalidLottery() external {}

    function requestWinner() external {}

    function withdrawOrganizerFunds() external {}

    function collectExpiredRefunds() external {}

    function ticketPrice() external view override returns (uint256) {}

    function fulfillRandomWords(
        uint256 requestId,
        uint256[] calldata randomWords
    ) internal virtual override {}
}

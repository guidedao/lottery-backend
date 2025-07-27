// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {ILottery} from "./interfaces/ILoterry.sol";
import {ILotteryErrors} from "./interfaces/ILotteryErrors.sol";

abstract contract Lottery is ILottery, ILotteryErrors {}

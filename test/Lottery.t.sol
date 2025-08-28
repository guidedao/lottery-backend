// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test, console} from "forge-std/Test.sol";

import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";

import {ILottery} from "src/interfaces/ILottery.sol";
import {ILotteryErrors} from "src/interfaces/ILotteryErrors.sol";
import {Lottery} from "src/Lottery.sol";

import {GuideDAOTokenMock} from "./mocks/GuideDAOTokenMock.sol";
import {NonPayable} from "./mocks/NonPayable.sol";

import {VRFCoordinatorMockConfig, VRFConsumerConfig, LotteryConfig} from "src/libraries/Configs.sol";

import {Types} from "src/libraries/Types.sol";

contract LotteryTest is Test {
    /* Contract without receive() function */
    NonPayable nonPayable;

    VRFCoordinatorV2_5Mock vrfCoordinator;
    GuideDAOTokenMock guideDAOToken;

    address nftFallbackRecipient = makeAddr("nftFallbackRecipient");

    address[] participants;

    Lottery lottery;

    /* receive() function to withdraw funds from successful lotteries
    and expired refunds for the sake of convenience. */
    receive() external payable {}

    function setUp() external {
        nonPayable = new NonPayable();

        for (uint i = 0; i < LotteryConfig.MAX_PARTICIPANTS_NUMBER; i++) {
            participants.push(vm.addr(i + 1));
        }

        vrfCoordinator = new VRFCoordinatorV2_5Mock(
            VRFCoordinatorMockConfig.BASE_FEE,
            VRFCoordinatorMockConfig.GAS_PRICE_LINK,
            VRFCoordinatorMockConfig.WEI_PER_UNIT_LINK
        );

        uint256 subscriptionId = vrfCoordinator.createSubscription();
        vrfCoordinator.fundSubscription(subscriptionId, 10e22);

        guideDAOToken = new GuideDAOTokenMock();

        lottery = new Lottery(
            address(this),
            nftFallbackRecipient,
            address(guideDAOToken),
            address(vrfCoordinator),
            subscriptionId
        );

        lottery.grantRole(lottery.LOTTERY_OPERATOR_ROLE(), address(this));

        vrfCoordinator.addConsumer(subscriptionId, address(lottery));

        guideDAOToken.setIsAdmin(address(lottery), true);
    }

    function test_start_AllowsToStart() external {
        vm.assertTrue(lottery.status() == Types.LotteryStatus.Closed);

        vm.expectEmit();
        emit ILottery.LotteryStarted(1, block.timestamp);

        lottery.start();

        vm.assertTrue(
            lottery.status() == Types.LotteryStatus.OpenedForRegistration
        );
        vm.assertEq(
            lottery.registrationEndTime(),
            block.timestamp + lottery.REGISTRATION_DURATION()
        );
    }

    function test_start_RevertsIfTryingToStartActiveLottery() external {
        lottery.start();

        vm.expectRevert(
            abi.encodeWithSelector(
                ILotteryErrors.IncorrectLotteryStatus.selector,
                Types.LotteryStatus.OpenedForRegistration,
                Types.LotteryStatus.Closed
            )
        );
        lottery.start();

        uint256 ticketPrice = lottery.ticketPrice();

        for (uint i = 0; i < LotteryConfig.TARGET_PARTICIPANTS_NUMBER; i++) {
            hoax(participants[i]);
            lottery.enter{value: ticketPrice}(1, "@somecontactdetails");
        }

        vm.warp(lottery.registrationEndTime());

        vm.expectRevert(
            abi.encodeWithSelector(
                ILotteryErrors.IncorrectLotteryStatus.selector,
                Types.LotteryStatus.RegistrationEnded,
                Types.LotteryStatus.Closed
            )
        );
        lottery.start();

        lottery.requestWinner();

        vm.expectRevert(
            abi.encodeWithSelector(
                ILotteryErrors.IncorrectLotteryStatus.selector,
                Types.LotteryStatus.WaitingForReveal,
                Types.LotteryStatus.Closed
            )
        );
        lottery.start();
    }

    function test_start_RevertsIfTryingToStartAfterLotteryHasBeenConsideredInvalid()
        external
    {
        lottery.start();

        address participant = participants[0];

        uint256 ticketPrice = lottery.ticketPrice();

        hoax(participant);
        lottery.enter{value: ticketPrice}(1, "@somecontactdetails");

        vm.warp(lottery.registrationEndTime());

        vm.expectRevert(
            abi.encodeWithSelector(
                ILotteryErrors.IncorrectLotteryStatus.selector,
                Types.LotteryStatus.Invalid,
                Types.LotteryStatus.Closed
            )
        );
        lottery.start();
    }

    function test_extendRegistrationTime_AllowsToExtend() external {
        lottery.start();

        vm.expectEmit();
        emit ILottery.RegistrationTimeExtended(1, 3600);

        lottery.extendRegistrationTime(3600);

        uint256 maxExtensionTime = lottery.MAX_EXTENSION_TIME();

        vm.expectEmit();
        emit ILottery.RegistrationTimeExtended(1, maxExtensionTime - 3600);

        lottery.extendRegistrationTime(maxExtensionTime - 3600);
    }

    function test_extendRegistrationTime_RevertsIfTryingToExtendLotteryNotDuringRegistration()
        external
    {
        uint256 extensionTime = lottery.MAX_EXTENSION_TIME();

        vm.expectRevert(
            abi.encodeWithSelector(
                ILotteryErrors.IncorrectLotteryStatus.selector,
                Types.LotteryStatus.Closed,
                Types.LotteryStatus.OpenedForRegistration
            )
        );
        lottery.extendRegistrationTime(extensionTime);

        lottery.start();

        uint256 ticketPrice = lottery.ticketPrice();

        for (uint i = 0; i < LotteryConfig.TARGET_PARTICIPANTS_NUMBER; i++) {
            hoax(participants[i]);
            lottery.enter{value: ticketPrice}(1, "@somecontactdetails");
        }

        vm.warp(lottery.registrationEndTime());

        vm.expectRevert(
            abi.encodeWithSelector(
                ILotteryErrors.IncorrectLotteryStatus.selector,
                Types.LotteryStatus.RegistrationEnded,
                Types.LotteryStatus.OpenedForRegistration
            )
        );
        lottery.extendRegistrationTime(extensionTime);

        lottery.requestWinner();

        vm.expectRevert(
            abi.encodeWithSelector(
                ILotteryErrors.IncorrectLotteryStatus.selector,
                Types.LotteryStatus.WaitingForReveal,
                Types.LotteryStatus.OpenedForRegistration
            )
        );
        lottery.extendRegistrationTime(extensionTime);
    }

    function test_extendRegistrationTime_RevertsIfTryingToExtendAfterLotteryHasBeenConsideredInvalid()
        external
    {
        uint256 extensionTime = lottery.MAX_EXTENSION_TIME();

        lottery.start();

        address participant = participants[0];

        uint256 ticketPrice = lottery.ticketPrice();

        hoax(participant);
        lottery.enter{value: ticketPrice}(1, "@somecontactdetails");

        vm.warp(lottery.registrationEndTime());

        vm.expectRevert(
            abi.encodeWithSelector(
                ILotteryErrors.IncorrectLotteryStatus.selector,
                Types.LotteryStatus.Invalid,
                Types.LotteryStatus.OpenedForRegistration
            )
        );
        lottery.extendRegistrationTime(extensionTime);
    }

    function test_extendRegistrationTime_RevertsIfExtensionTooLong() external {
        lottery.start();

        uint256 maxExtensionTime = lottery.MAX_EXTENSION_TIME();

        vm.expectRevert(
            abi.encodeWithSelector(
                ILotteryErrors.ExtensionTooLong.selector,
                maxExtensionTime + 1,
                maxExtensionTime
            )
        );
        lottery.extendRegistrationTime(maxExtensionTime + 1);
    }

    function test_enter_AllowsToEnter() external {
        lottery.start();

        uint256 ticketPrice = lottery.ticketPrice();

        for (uint i = 0; i < LotteryConfig.MAX_PARTICIPANTS_NUMBER - 1; i++) {
            hoax(participants[i]);

            vm.expectEmit();
            emit ILottery.TicketsBought(1, participants[i], 1);

            lottery.enter{value: ticketPrice}(1, "@somecontactdetails");
        }

        vm.assertEq(
            lottery.participantsCount(),
            LotteryConfig.MAX_PARTICIPANTS_NUMBER - 1
        );
        vm.assertTrue(
            lottery.status() == Types.LotteryStatus.OpenedForRegistration
        );

        for (uint i = 0; i < lottery.participantsCount(); i++) {
            vm.assertTrue(lottery.isActualParticipant(participants[i]));
        }
    }

    function test_enter_ClosesRegistrationAfterReachingMaxParticipantsNumber()
        external
    {
        lottery.start();

        uint256 ticketPrice = lottery.ticketPrice();

        for (uint i = 0; i < LotteryConfig.MAX_PARTICIPANTS_NUMBER; i++) {
            hoax(participants[i]);
            lottery.enter{value: ticketPrice}(1, "@somecontactdetails");

            (uint256 ticketsBought, , ) = lottery.participantsInfo(
                lottery.lotteryNumber(),
                participants[i]
            );

            vm.assertEq(ticketsBought, 1);
        }

        vm.assertEq(
            lottery.participantsCount(),
            LotteryConfig.MAX_PARTICIPANTS_NUMBER
        );
        vm.assertTrue(
            lottery.status() == Types.LotteryStatus.RegistrationEnded
        );
    }

    function test_enter_RevertsIfTryingToEnterNotDuringRegistration() external {
        address participant = makeAddr("participant");

        uint256 ticketPrice = lottery.ticketPrice();

        vm.expectRevert(
            abi.encodeWithSelector(
                ILotteryErrors.IncorrectLotteryStatus.selector,
                Types.LotteryStatus.Closed,
                Types.LotteryStatus.OpenedForRegistration
            )
        );
        hoax(participant);
        lottery.enter{value: ticketPrice}(1, "@somecontactdetails");

        lottery.start();

        for (uint i = 0; i < LotteryConfig.TARGET_PARTICIPANTS_NUMBER; i++) {
            hoax(participants[i]);
            lottery.enter{value: ticketPrice}(1, "@somecontactdetails");
        }

        vm.warp(lottery.registrationEndTime());

        lottery.requestWinner();

        vm.expectRevert(
            abi.encodeWithSelector(
                ILotteryErrors.IncorrectLotteryStatus.selector,
                Types.LotteryStatus.WaitingForReveal,
                Types.LotteryStatus.OpenedForRegistration
            )
        );
        hoax(participant);
        lottery.enter{value: ticketPrice}(1, "@somecontactdetails");
    }

    function test_enter_RevertsIfTryingToEnterAfterLotteryHasBeenConsideredInvalid()
        external
    {
        lottery.start();

        address participant = participants[0];

        uint256 ticketPrice = lottery.ticketPrice();

        hoax(participant);
        lottery.enter{value: ticketPrice}(1, "@somecontactdetails");

        vm.warp(lottery.registrationEndTime());

        vm.expectRevert(
            abi.encodeWithSelector(
                ILotteryErrors.IncorrectLotteryStatus.selector,
                Types.LotteryStatus.Invalid,
                Types.LotteryStatus.OpenedForRegistration
            )
        );
        hoax(participant);
        lottery.enter{value: ticketPrice}(1, "@somecontactdetails");
    }

    function test_enter_RevertsIfUserAccountHasCode() external {
        lottery.start();

        uint256 ticketPrice = lottery.ticketPrice();

        vm.expectRevert(
            abi.encodeWithSelector(
                ILotteryErrors.HasCode.selector,
                /* Using this contract for simplicity */
                address(this)
            )
        );
        lottery.enter{value: ticketPrice}(1, "@somecontactdetails");
    }

    function test_enter_RevertsIfUserAlreadyHasToken() external {
        lottery.start();

        address participant = participants[0];

        guideDAOToken.mintTo(participant);

        uint256 ticketPrice = lottery.ticketPrice();

        vm.expectRevert(
            abi.encodeWithSelector(
                ILotteryErrors.AlreadyHasToken.selector,
                participant
            )
        );
        hoax(participant);
        lottery.enter{value: ticketPrice}(1, "@somecontactdetails");
    }

    function test_enter_RevertsIfTryingToEnterTwice() external {
        lottery.start();

        address participant = participants[0];

        uint256 ticketPrice = lottery.ticketPrice();

        startHoax(participant);

        lottery.enter{value: ticketPrice}(1, "@somecontactdetails");

        vm.expectRevert(
            abi.encodeWithSelector(
                ILotteryErrors.AlreadyRegistered.selector,
                participant
            )
        );
        lottery.enter{value: ticketPrice}(1, "@somecontactdetails");
    }

    function test_enter_RevertsIfTryingToBuyZeroTickets() external {
        lottery.start();

        address participant = participants[0];

        vm.expectRevert(
            abi.encodeWithSelector(
                ILotteryErrors.ZeroTicketsRequested.selector,
                participant
            )
        );
        vm.prank(participant);
        lottery.enter(0, "@somecontactdetails");
    }

    function test_enter_RevertsIfPaymentAmountIsIncorrect() external {
        lottery.start();

        address participant = participants[0];

        uint256 ticketPrice = lottery.ticketPrice();

        uint256 insufficientPaymentAmount = 2 * ticketPrice;
        uint256 correctPaymentAmount = 3 * ticketPrice;
        uint256 exceedingPaymentAmount = 4 * ticketPrice;

        vm.expectRevert(
            abi.encodeWithSelector(
                ILotteryErrors.IncorrectPaymentAmount.selector,
                participant,
                insufficientPaymentAmount,
                correctPaymentAmount
            )
        );
        hoax(participant);
        lottery.enter{value: insufficientPaymentAmount}(
            3,
            "@somecontactdetails"
        );

        vm.expectRevert(
            abi.encodeWithSelector(
                ILotteryErrors.IncorrectPaymentAmount.selector,
                participant,
                exceedingPaymentAmount,
                correctPaymentAmount
            )
        );
        hoax(participant);
        lottery.enter{value: exceedingPaymentAmount}(3, "@somecontactdetails");
    }

    function test_buyMoreTickets_AllowsToBuyMoreTickets() external {
        lottery.start();

        address participant = participants[0];

        uint256 ticketPrice = lottery.ticketPrice();

        vm.startPrank(participant);
        vm.deal(participant, ticketPrice * 3);

        lottery.enter{value: ticketPrice}(1, "@somecontactdetails");

        vm.expectEmit();
        emit ILottery.TicketsBought(1, participant, 2);

        lottery.buyMoreTickets{value: ticketPrice * 2}(2);

        vm.stopPrank();

        (uint256 ticketsBought, , ) = lottery.participantsInfo(
            lottery.lotteryNumber(),
            participant
        );

        vm.assertEq(ticketsBought, 3);
    }

    function test_buyMoreTickets_RevertsIfTryingToBuyNotDuringRegistration()
        external
    {
        address participant = makeAddr("participant");

        uint256 ticketPrice = lottery.ticketPrice();

        vm.expectRevert(
            abi.encodeWithSelector(
                ILotteryErrors.IncorrectLotteryStatus.selector,
                Types.LotteryStatus.Closed,
                Types.LotteryStatus.OpenedForRegistration
            )
        );
        hoax(participant);
        lottery.buyMoreTickets{value: ticketPrice}(1);

        lottery.start();

        for (uint i = 0; i < LotteryConfig.TARGET_PARTICIPANTS_NUMBER; i++) {
            hoax(participants[i]);
            lottery.enter{value: ticketPrice}(1, "@somecontactdetails");
        }

        vm.warp(lottery.registrationEndTime());

        lottery.requestWinner();

        vm.expectRevert(
            abi.encodeWithSelector(
                ILotteryErrors.IncorrectLotteryStatus.selector,
                Types.LotteryStatus.WaitingForReveal,
                Types.LotteryStatus.OpenedForRegistration
            )
        );
        hoax(participant);
        lottery.buyMoreTickets{value: ticketPrice}(1);
    }

    function test_buyMoreTickets_RevertsIfTryingToBuyTicketsAfterLotteryHasBeenConsideredInvalid()
        external
    {
        lottery.start();

        address participant = participants[0];

        uint256 ticketPrice = lottery.ticketPrice();

        hoax(participant);
        lottery.enter{value: ticketPrice}(1, "@somecontactdetails");

        vm.warp(lottery.registrationEndTime());

        vm.expectRevert(
            abi.encodeWithSelector(
                ILotteryErrors.IncorrectLotteryStatus.selector,
                Types.LotteryStatus.Invalid,
                Types.LotteryStatus.OpenedForRegistration
            )
        );
        hoax(participant);
        lottery.buyMoreTickets{value: ticketPrice}(1);
    }

    function test_buyMoreTickets_RevertsIfTryingToBuyMoreTicketsBeforeEnter()
        external
    {
        lottery.start();

        address participant = participants[0];

        uint256 ticketPrice = lottery.ticketPrice();

        vm.expectRevert(
            abi.encodeWithSelector(
                ILotteryErrors.HasNotRegistered.selector,
                participant
            )
        );
        hoax(participant);
        lottery.buyMoreTickets{value: ticketPrice}(1);
    }

    function test_buyMoreTickets_RevertsIfTryingToBuyZeroTickets() external {
        lottery.start();

        address participant = participants[0];

        uint ticketPrice = lottery.ticketPrice();

        startHoax(participant);

        lottery.enter{value: ticketPrice}(1, "@somecontactdetails");

        vm.expectRevert(
            abi.encodeWithSelector(
                ILotteryErrors.ZeroTicketsRequested.selector,
                participant
            )
        );
        lottery.buyMoreTickets(0);
    }

    function test_buyMoreTickets_RevertsIfPaymentAmountIsIncorrect() external {
        lottery.start();

        address participant = participants[0];

        uint256 ticketPrice = lottery.ticketPrice();

        uint256 insufficientPaymentAmount = 2 * ticketPrice;
        uint256 correctPaymentAmount = 3 * ticketPrice;
        uint256 exceedingPaymentAmount = 4 * ticketPrice;

        startHoax(participant);

        lottery.enter{value: ticketPrice}(1, "@somecontactdetails");

        vm.expectRevert(
            abi.encodeWithSelector(
                ILotteryErrors.IncorrectPaymentAmount.selector,
                participant,
                insufficientPaymentAmount,
                correctPaymentAmount
            )
        );
        lottery.buyMoreTickets{value: insufficientPaymentAmount}(3);

        vm.expectRevert(
            abi.encodeWithSelector(
                ILotteryErrors.IncorrectPaymentAmount.selector,
                participant,
                exceedingPaymentAmount,
                correctPaymentAmount
            )
        );
        lottery.buyMoreTickets{value: exceedingPaymentAmount}(3);
    }

    function test_returnTickets_AllowsToPartiallyReturn() external {
        lottery.start();

        address participant = participants[0];

        uint256 ticketPrice = lottery.ticketPrice();

        vm.startPrank(participant);
        vm.deal(participant, ticketPrice * 2);

        lottery.enter{value: ticketPrice * 2}(2, "@somecontactdetails");

        vm.expectEmit();
        emit ILottery.TicketsReturned(1, participant, 1);

        lottery.returnTickets(1);

        vm.stopPrank();

        (uint256 ticketsBought, , ) = lottery.participantsInfo(
            lottery.lotteryNumber(),
            participant
        );

        vm.assertEq(participant.balance, ticketPrice);
        vm.assertTrue(lottery.isActualParticipant(participant));
        vm.assertEq(ticketsBought, 1);

        vm.assertEq(lottery.participantsCount(), 1);
    }

    function test_returnTickets_AllowsToFullyReturnIfUserIsLast() external {
        lottery.start();

        address participant = participants[0];

        uint256 ticketPrice = lottery.ticketPrice();

        vm.startPrank(participant);
        vm.deal(participant, ticketPrice);

        lottery.enter{value: ticketPrice}(1, "@somecontactdetails");

        vm.expectEmit();
        emit ILottery.TicketsReturned(1, participant, 1);

        lottery.returnTickets(1);

        vm.stopPrank();

        vm.assertEq(participant.balance, ticketPrice);
        vm.assertFalse(lottery.isActualParticipant(participant));

        vm.assertEq(lottery.participantsCount(), 0);
    }

    function test_returnTickets_AllowsToFullyReturnIfUserIsNotLast() external {
        lottery.start();

        address firstParticipant = participants[0];
        address secondParticipant = participants[1];

        uint256 ticketPrice = lottery.ticketPrice();

        vm.deal(firstParticipant, ticketPrice);
        vm.prank(firstParticipant);
        lottery.enter{value: ticketPrice}(1, "@somecontactdetails");

        hoax(secondParticipant);
        lottery.enter{value: ticketPrice}(1, "@somecontactdetails");

        vm.prank(firstParticipant);

        vm.expectEmit();
        emit ILottery.TicketsReturned(1, firstParticipant, 1);

        lottery.returnTickets(1);

        (uint256 ticketsBought, uint256 index, ) = lottery.participantsInfo(
            lottery.lotteryNumber(),
            secondParticipant
        );

        vm.assertEq(ticketsBought, 1);
        vm.assertEq(index, 0);
        vm.assertTrue(lottery.isActualParticipant(secondParticipant));

        vm.assertEq(firstParticipant.balance, ticketPrice);
        vm.assertFalse(lottery.isActualParticipant(firstParticipant));

        vm.assertEq(lottery.participantsCount(), 1);
    }

    function test_returnTickets_RevertsIfTryingToReturnNotDuringRegistration()
        external
    {
        address participant = makeAddr("participant");

        uint256 ticketPrice = lottery.ticketPrice();

        vm.expectRevert(
            abi.encodeWithSelector(
                ILotteryErrors.IncorrectLotteryStatus.selector,
                Types.LotteryStatus.Closed,
                Types.LotteryStatus.OpenedForRegistration
            )
        );
        vm.prank(participant);
        lottery.returnTickets(1);

        lottery.start();

        for (uint i = 0; i < LotteryConfig.TARGET_PARTICIPANTS_NUMBER; i++) {
            hoax(participants[i]);
            lottery.enter{value: ticketPrice}(1, "@somecontactdetails");
        }

        vm.warp(lottery.registrationEndTime());

        lottery.requestWinner();

        vm.expectRevert(
            abi.encodeWithSelector(
                ILotteryErrors.IncorrectLotteryStatus.selector,
                Types.LotteryStatus.WaitingForReveal,
                Types.LotteryStatus.OpenedForRegistration
            )
        );
        vm.prank(participant);
        lottery.returnTickets(1);
    }

    function test_returnTickets_RevertsIfTryingToReturnTicketsAfterLotteryHasBeenConsideredInvalid()
        external
    {
        address participant = participants[0];

        lottery.start();

        uint256 ticketPrice = lottery.ticketPrice();

        hoax(participant);
        lottery.enter{value: ticketPrice}(1, "@somecontactdetails");

        vm.warp(lottery.registrationEndTime());

        vm.expectRevert(
            abi.encodeWithSelector(
                ILotteryErrors.IncorrectLotteryStatus.selector,
                Types.LotteryStatus.Invalid,
                Types.LotteryStatus.OpenedForRegistration
            )
        );
        vm.prank(participant);
        lottery.returnTickets(1);
    }

    function test_returnTickets_RevertsIfTryingToReturnZeroTickets() external {
        lottery.start();

        address participant = participants[0];

        uint256 ticketPrice = lottery.ticketPrice();

        hoax(participant);
        lottery.enter{value: ticketPrice}(1, "@somecontactdetails");

        vm.expectRevert(
            abi.encodeWithSelector(
                ILotteryErrors.ZeroTicketsRequested.selector,
                participant
            )
        );
        vm.prank(participant);
        lottery.returnTickets(0);
    }

    function test_returnTickets_RevertsIfTryingToReturnBeforeEnter() external {
        lottery.start();

        address participant = participants[0];

        uint256 wantToReturn = 1;

        vm.expectRevert(
            abi.encodeWithSelector(
                ILotteryErrors.InsufficientTicketsNumber.selector,
                participant,
                0,
                wantToReturn
            )
        );
        vm.prank(participant);
        lottery.returnTickets(wantToReturn);
    }

    function test_returnTickets_RevertsIfTryingToReturnMoreThanBought()
        external
    {
        lottery.start();

        address participant = participants[0];

        uint256 ticketPrice = lottery.ticketPrice();

        uint256 wantToBuy = 3;
        uint256 wantToReturn = 4;

        hoax(participant);
        lottery.enter{value: wantToBuy * ticketPrice}(
            wantToBuy,
            "@somecontactdetails"
        );

        vm.expectRevert(
            abi.encodeWithSelector(
                ILotteryErrors.InsufficientTicketsNumber.selector,
                participant,
                wantToBuy,
                wantToReturn
            )
        );
        vm.prank(participant);
        lottery.returnTickets(wantToReturn);
    }

    function test_returnTickets_RevertsIfTryingToWithdrawToNonPayable()
        external
    {
        lottery.start();

        (address participant, uint256 privateKey) = makeAddrAndKey(
            "participant"
        );

        uint256 ticketPrice = lottery.ticketPrice();

        uint256 wantToBuy = 2;
        uint256 wantToReturn = 1;

        startHoax(participant);

        lottery.enter{value: wantToBuy * ticketPrice}(
            wantToBuy,
            "@somecontactdetails"
        );

        vm.signAndAttachDelegation(address(nonPayable), privateKey);

        vm.expectRevert(
            abi.encodeWithSelector(
                ILotteryErrors.WithdrawFailed.selector,
                participant
            )
        );
        lottery.returnTickets(wantToReturn);
    }

    function test_requestWinner_AllowsToRequest() external {
        lottery.start();

        uint256 ticketPrice = lottery.ticketPrice();

        for (uint i = 0; i < LotteryConfig.MAX_PARTICIPANTS_NUMBER; i++) {
            hoax(participants[i]);
            lottery.enter{value: ticketPrice}(1, "@somecontactdetails");
        }

        vm.expectEmit();
        emit ILottery.WinnerRequested(1, 1, block.timestamp);

        lottery.requestWinner();

        assertTrue(lottery.status() == Types.LotteryStatus.WaitingForReveal);
    }

    function test_requestWinner_RevertsIfTryingToRequestWinnerBeforeRegistrationEnd()
        external
    {
        vm.expectRevert(
            abi.encodeWithSelector(
                ILotteryErrors.IncorrectLotteryStatus.selector,
                Types.LotteryStatus.Closed,
                Types.LotteryStatus.RegistrationEnded
            )
        );
        lottery.requestWinner();

        lottery.start();

        uint256 ticketPrice = lottery.ticketPrice();

        for (uint i = 0; i < LotteryConfig.TARGET_PARTICIPANTS_NUMBER; i++) {
            hoax(participants[i]);
            lottery.enter{value: ticketPrice}(1, "@somecontactdetails");
        }

        vm.expectRevert(
            abi.encodeWithSelector(
                ILotteryErrors.IncorrectLotteryStatus.selector,
                Types.LotteryStatus.OpenedForRegistration,
                Types.LotteryStatus.RegistrationEnded
            )
        );
        lottery.requestWinner();
    }

    function test_requestWinner_RevertsIfTryingToRequestWinnerAfterLotteryHasBeenConsideredInvalid()
        external
    {
        lottery.start();

        address participant = participants[0];

        uint256 ticketPrice = lottery.ticketPrice();

        hoax(participant);
        lottery.enter{value: ticketPrice}(1, "@somecontactdetails");

        vm.warp(lottery.registrationEndTime());

        vm.expectRevert(
            abi.encodeWithSelector(
                ILotteryErrors.IncorrectLotteryStatus.selector,
                Types.LotteryStatus.Invalid,
                Types.LotteryStatus.RegistrationEnded
            )
        );
        lottery.requestWinner();
    }

    function test_fulfillRandomWords_AllowsToRevealWinnerAndGrantPrize()
        external
    {
        lottery.start();

        uint256 ticketPrice = lottery.ticketPrice();

        for (uint i = 0; i < LotteryConfig.MAX_PARTICIPANTS_NUMBER; i++) {
            hoax(participants[i]);
            lottery.enter{value: ticketPrice}(1, "@somecontactdetails");
        }

        lottery.requestWinner();

        /* We do not check second topic since we assume that we
            do not know winner address yet. However, in this test case
            it is determenistic and we could use hard-coded value as well,
            but current approach is more suitable for possible changes,
            and we still require that winner do recieve their prize NFT. */
        vm.expectEmit(true, false, true, true);
        emit ILottery.WinnerRevealed(1, address(0), block.timestamp);

        vrfCoordinator.fulfillRandomWords(1, address(lottery));

        vm.assertTrue(lottery.status() == Types.LotteryStatus.Closed);

        address lastWinner = lottery.lastWinner();

        vm.assertNotEq(lastWinner, address(0));
        vm.assertNotEq(lastWinner, lottery.nftFallbackRecipient());
        vm.assertNotEq(lastWinner, lottery.organizer());

        vm.assertEq(guideDAOToken.balanceOf(lastWinner), 1);
        vm.assertEq(
            lottery.latestContactDetails(lastWinner),
            "@somecontactdetails"
        );
    }

    /* This test handles possible edge case: despite the fact that we
    check code length at user account when they buy tickets for the first time,
    EIP-7702 made it possible to attach delegation to smart contract whenever
    they want, so we cannot rely only on that check alone.  */
    function test_fulfillRandomWords_MintsTokenToFallbackRecipientIfWinnerHasCode()
        external
    {
        lottery.start();

        uint256 ticketPrice = lottery.ticketPrice();

        for (uint i = 0; i < LotteryConfig.MAX_PARTICIPANTS_NUMBER; i++) {
            /* Re-creating participants from private keys for clarity */
            address participant = vm.addr(i + 1);

            hoax(participant);
            lottery.enter{value: ticketPrice}(1, "@somecontactdetails");

            /* For simplicity, let them all sign and attach delegation to
            some smart contract. */
            vm.signAndAttachDelegation(address(nonPayable), i + 1);
        }

        lottery.requestWinner();
        vrfCoordinator.fulfillRandomWords(1, address(lottery));

        address lastWinner = lottery.lastWinner();

        vm.assertNotEq(lastWinner, address(0));
        vm.assertNotEq(lastWinner, nftFallbackRecipient);
        vm.assertNotEq(lastWinner, lottery.organizer());

        vm.assertEq(guideDAOToken.balanceOf(nftFallbackRecipient), 1);
        vm.assertEq(
            lottery.latestContactDetails(lastWinner),
            "@somecontactdetails"
        );
    }

    function test_closeInvalidLottery_AllowsToCorrectlyClose() external {
        lottery.start();

        uint256 ticketPrice = lottery.ticketPrice();

        for (
            uint i = 0;
            i < LotteryConfig.TARGET_PARTICIPANTS_NUMBER - 1;
            i++
        ) {
            hoax(participants[i]);
            lottery.enter{value: ticketPrice}(1, "@somecontactdetails");
        }

        vm.warp(lottery.registrationEndTime());

        vm.assertTrue(lottery.status() == Types.LotteryStatus.Invalid);

        vm.expectEmit();
        emit ILottery.InvalidLotteryClosed(1, block.timestamp);

        uint256 expectedBatchId = lottery.nextRefundBatchId();
        lottery.closeInvalidLottery();

        vm.assertTrue(lottery.status() == Types.LotteryStatus.Closed);
        vm.assertEq(lottery.nextRefundBatchId(), expectedBatchId + 1);

        (uint256 refundAssignmentTime, uint256 totalUnclaimedFunds) = lottery
            .refundBatches(expectedBatchId);

        vm.assertEq(refundAssignmentTime, block.timestamp);
        vm.assertEq(
            totalUnclaimedFunds,
            (LotteryConfig.TARGET_PARTICIPANTS_NUMBER - 1) * ticketPrice
        );

        for (
            uint i = 0;
            i < LotteryConfig.TARGET_PARTICIPANTS_NUMBER - 1;
            i++
        ) {
            vm.assertEq(lottery.refundAmount(participants[i]), ticketPrice);
        }
    }

    function test_closeInvalidLottery_RevertsIfTryingToCloseLotteryThatIsNotInvalid()
        external
    {
        vm.expectRevert(
            abi.encodeWithSelector(
                ILotteryErrors.IncorrectLotteryStatus.selector,
                Types.LotteryStatus.Closed,
                Types.LotteryStatus.Invalid
            )
        );
        lottery.closeInvalidLottery();

        lottery.start();

        uint256 ticketPrice = lottery.ticketPrice();

        for (uint i = 0; i < LotteryConfig.TARGET_PARTICIPANTS_NUMBER; i++) {
            hoax(participants[i]);
            lottery.enter{value: ticketPrice}(1, "@somecontactdetails");
        }

        vm.warp(lottery.registrationEndTime());

        vm.expectRevert(
            abi.encodeWithSelector(
                ILotteryErrors.IncorrectLotteryStatus.selector,
                Types.LotteryStatus.RegistrationEnded,
                Types.LotteryStatus.Invalid
            )
        );
        lottery.closeInvalidLottery();

        lottery.requestWinner();

        vm.expectRevert(
            abi.encodeWithSelector(
                ILotteryErrors.IncorrectLotteryStatus.selector,
                Types.LotteryStatus.WaitingForReveal,
                Types.LotteryStatus.Invalid
            )
        );
        lottery.closeInvalidLottery();
    }

    function test_clearLotteryData_AllowsToClear() external {
        uint256 maxParticipantsToClear = lottery.MAX_PARTICIPANTS_TO_CLEAR();

        /* Necessary to keep in order to avoid situations when user with
        GuideDAO NFT (i.e. one of the previous winners) tries to enter the new lottery. */
        uint256 totalParticipantsCount;
        for (uint i = 0; i < 6; i++) {
            lottery.start();

            uint256 ticketPrice = lottery.ticketPrice();

            uint256 participantsAmount = i == 0
                ? maxParticipantsToClear * 2
                : LotteryConfig.TARGET_PARTICIPANTS_NUMBER;

            for (uint j = 0; j < participantsAmount; j++) {
                address participant = participants[j + totalParticipantsCount];

                hoax(participant);
                lottery.enter{value: ticketPrice}(1, "@somecontactdetails");
            }

            totalParticipantsCount += participantsAmount;

            vm.warp(lottery.registrationEndTime());

            lottery.requestWinner();
            vrfCoordinator.fulfillRandomWords(i + 1, address(lottery));
        }

        vm.expectEmit();
        emit Lottery.LotteryDataCleared(1, 0, maxParticipantsToClear - 1);

        lottery.clearLotteryData(1, 0);

        vm.expectEmit();
        emit Lottery.LotteryDataCleared(
            1,
            maxParticipantsToClear,
            maxParticipantsToClear * 2 - 1
        );

        lottery.clearLotteryData(1, maxParticipantsToClear);

        for (uint i = 0; i < maxParticipantsToClear * 2; i++) {
            address participant = lottery.participants(1, i);
            assertEq(participant, address(0));

            (
                uint256 ticketsBought,
                uint256 participantIndex,
                bytes memory contactDetails
            ) = lottery.participantsInfo(0, participants[i]);

            assertEq(ticketsBought, 0);
            assertEq(participantIndex, 0);
            assertEq(contactDetails, "");
        }
    }

    function test_clearLotteryData_RevertsIfTryingToCleanRecentData() external {
        lottery.start();

        uint256 ticketPrice = lottery.ticketPrice();

        for (uint i = 0; i < LotteryConfig.TARGET_PARTICIPANTS_NUMBER; i++) {
            hoax(participants[i]);
            lottery.enter{value: ticketPrice}(1, "@somecontactdetails");
        }

        vm.warp(lottery.registrationEndTime());

        lottery.requestWinner();
        vrfCoordinator.fulfillRandomWords(1, address(lottery));

        uint256 lotteryNumber = lottery.lotteryNumber();

        vm.expectRevert(
            abi.encodeWithSelector(
                Lottery.TooEarlyToClearData.selector,
                lottery.lotteryNumber(),
                lottery.lotteryNumber() +
                    lottery.LOTTERY_DATA_FRESHNESS_INTERVAL()
            )
        );
        lottery.clearLotteryData(lotteryNumber, 0);
    }

    function test_clearLotteryData_RevertsIfNothingToClear() external {
        for (uint i = 0; i < 6; i++) {
            lottery.start();

            uint256 ticketPrice = lottery.ticketPrice();

            uint256 participantsOffset = i *
                LotteryConfig.TARGET_PARTICIPANTS_NUMBER;

            for (
                uint j = 0;
                j < LotteryConfig.TARGET_PARTICIPANTS_NUMBER;
                j++
            ) {
                address participant = vm.addr(j + participantsOffset + 1);

                hoax(participant);
                lottery.enter{value: ticketPrice}(1, "@somecontactdetails");
            }

            vm.warp(lottery.registrationEndTime());

            lottery.requestWinner();
            vrfCoordinator.fulfillRandomWords(i + 1, address(lottery));
        }

        lottery.clearLotteryData(1, 0);

        vm.expectRevert(
            abi.encodeWithSelector(Lottery.NothingToClear.selector, 1, 0)
        );
        lottery.clearLotteryData(1, 0);
    }

    function test_refund_AllowsToRefund() external {
        lottery.start();

        uint256 ticketPrice = lottery.ticketPrice();

        for (
            uint i = 0;
            i < LotteryConfig.TARGET_PARTICIPANTS_NUMBER - 1;
            i++
        ) {
            vm.deal(participants[i], ticketPrice * 2);
            vm.prank(participants[i]);
            lottery.enter{value: ticketPrice * 2}(2, "@somecontactdetails");
        }

        vm.warp(lottery.registrationEndTime());

        uint256 expectedBatchId = lottery.nextRefundBatchId();

        lottery.closeInvalidLottery();

        for (
            uint i = 0;
            i < LotteryConfig.TARGET_PARTICIPANTS_NUMBER - 1;
            i++
        ) {
            (, uint256 totalUnclaimedBeforeRefund) = lottery.refundBatches(
                expectedBatchId
            );
            uint256 userRefundAmount = lottery.refundAmount(participants[i]);

            vm.assertEq(userRefundAmount, 2 * ticketPrice);

            vm.expectEmit();
            emit ILottery.MoneyRefunded(participants[i], 2 * ticketPrice);

            vm.prank(participants[i]);
            lottery.refund();

            (, uint256 totalUnclaimedAfterRefund) = lottery.refundBatches(
                expectedBatchId
            );

            vm.assertEq(participants[i].balance, userRefundAmount);
            vm.assertEq(lottery.refundAmount(participants[i]), 0);
            vm.assertEq(
                totalUnclaimedAfterRefund,
                totalUnclaimedBeforeRefund - userRefundAmount
            );
        }

        (, uint256 totalUnclaimedBeforeAllRefunds) = lottery.refundBatches(
            expectedBatchId
        );

        vm.assertEq(totalUnclaimedBeforeAllRefunds, 0);
    }

    function test_refund_RevertsIfNothingToRefund() external {
        lottery.start();

        address participant = participants[0];

        vm.expectRevert(
            abi.encodeWithSelector(
                ILotteryErrors.ZeroRefundBalance.selector,
                participant
            )
        );
        vm.prank(participant);
        lottery.refund();

        uint256 ticketPrice = lottery.ticketPrice();

        for (uint i = 0; i < LotteryConfig.TARGET_PARTICIPANTS_NUMBER; i++) {
            vm.deal(participants[i], ticketPrice * 2);
            vm.prank(participants[i]);
            lottery.enter{value: ticketPrice * 2}(2, "@somecontactdetails");
        }

        vm.warp(lottery.registrationEndTime());

        lottery.requestWinner();
        vrfCoordinator.fulfillRandomWords(1, address(lottery));

        vm.expectRevert(
            abi.encodeWithSelector(
                ILotteryErrors.ZeroRefundBalance.selector,
                participant
            )
        );
        vm.prank(participant);
        lottery.refund();
    }

    function test_refund_RevertsIfTryingToWithdrawToNonPayable() external {
        lottery.start();

        (address participant, uint256 privateKey) = makeAddrAndKey(
            "participant"
        );

        uint256 ticketPrice = lottery.ticketPrice();

        hoax(participant);
        lottery.enter{value: ticketPrice}(1, "@somecontactdetails");

        vm.signAndAttachDelegation(address(nonPayable), privateKey);

        vm.warp(lottery.registrationEndTime());

        lottery.closeInvalidLottery();

        vm.expectRevert(
            abi.encodeWithSelector(
                ILotteryErrors.WithdrawFailed.selector,
                participant
            )
        );
        vm.prank(participant);
        lottery.refund();
    }

    function test_collectExpiredRefunds_AllowsToCollect() external {
        lottery.start();

        uint256 ticketPrice = lottery.ticketPrice();

        for (
            uint i = 0;
            i < LotteryConfig.TARGET_PARTICIPANTS_NUMBER - 1;
            i++
        ) {
            hoax(participants[i]);
            lottery.enter{value: ticketPrice * 2}(2, "@somecontactdetails");
        }

        vm.warp(lottery.registrationEndTime());

        uint256 expectedBatchId = lottery.nextRefundBatchId();

        lottery.closeInvalidLottery();

        vm.warp(block.timestamp + lottery.REFUND_WINDOW() + 1);

        uint balanceBeforeCollection = address(this).balance;

        vm.expectEmit();
        emit ILottery.ExpiredRefundsCollected(
            expectedBatchId,
            2 * ticketPrice * (LotteryConfig.TARGET_PARTICIPANTS_NUMBER - 1)
        );

        lottery.collectExpiredRefunds(expectedBatchId, address(this));

        uint balanceAfterCollection = address(this).balance;

        vm.assertEq(
            balanceAfterCollection,
            balanceBeforeCollection +
                2 *
                ticketPrice *
                (LotteryConfig.TARGET_PARTICIPANTS_NUMBER - 1)
        );
    }

    function test_collectExpiredRefunds_RevertsIfTryingToWithdrawToNonPayable()
        external
    {
        lottery.start();

        uint256 ticketPrice = lottery.ticketPrice();

        for (
            uint i = 0;
            i < LotteryConfig.TARGET_PARTICIPANTS_NUMBER - 1;
            i++
        ) {
            hoax(participants[i]);
            lottery.enter{value: ticketPrice * 2}(2, "@somecontactdetails");
        }

        vm.warp(lottery.registrationEndTime());

        uint256 expectedBatchId = lottery.nextRefundBatchId();

        lottery.closeInvalidLottery();

        vm.warp(block.timestamp + lottery.REFUND_WINDOW() + 1);

        vm.expectRevert(
            abi.encodeWithSelector(
                ILotteryErrors.WithdrawFailed.selector,
                address(nonPayable)
            )
        );
        lottery.collectExpiredRefunds(expectedBatchId, address(nonPayable));
    }

    function test_collectExpiredRefunds_RevertsIfRefundsNotExpired() external {
        lottery.start();

        uint256 ticketPrice = lottery.ticketPrice();

        for (
            uint i = 0;
            i < LotteryConfig.TARGET_PARTICIPANTS_NUMBER - 1;
            i++
        ) {
            hoax(participants[i]);
            lottery.enter{value: ticketPrice * 2}(2, "@somecontactdetails");
        }

        vm.warp(lottery.registrationEndTime());

        uint256 expectedBatchId = lottery.nextRefundBatchId();

        lottery.closeInvalidLottery();

        vm.expectRevert(
            abi.encodeWithSelector(ILotteryErrors.NoExpiredRefunds.selector)
        );
        lottery.collectExpiredRefunds(expectedBatchId, address(this));
    }

    function test_collectExpiredRefunds_RevertsIfNothingToRefund() external {
        lottery.start();

        uint256 ticketPrice = lottery.ticketPrice();

        for (uint i = 0; i < LotteryConfig.TARGET_PARTICIPANTS_NUMBER; i++) {
            hoax(participants[i]);
            lottery.enter{value: ticketPrice * 2}(2, "@somecontactdetails");
        }

        vm.warp(lottery.registrationEndTime());

        uint256 expectedBatchId = lottery.nextRefundBatchId();

        lottery.requestWinner();
        vrfCoordinator.fulfillRandomWords(1, address(lottery));

        vm.expectRevert(
            abi.encodeWithSelector(ILotteryErrors.NoExpiredRefunds.selector)
        );
        lottery.collectExpiredRefunds(expectedBatchId, address(this));
    }

    function test_withdrawOrganizerFunds_AllowToWithdrawFunds() external {
        lottery.start();

        uint256 ticketPrice = lottery.ticketPrice();

        for (uint i = 0; i < LotteryConfig.MAX_PARTICIPANTS_NUMBER; i++) {
            hoax(participants[i]);
            lottery.enter{value: ticketPrice * 2}(2, "@somecontactdetails");
        }

        lottery.requestWinner();

        vrfCoordinator.fulfillRandomWords(1, address(lottery));

        uint256 accessibleFunds = lottery.organizerFunds();

        vm.assertEq(
            accessibleFunds,
            2 * ticketPrice * LotteryConfig.MAX_PARTICIPANTS_NUMBER
        );

        uint256 balanceBeforeWithdraw = address(this).balance;

        vm.expectEmit();
        emit ILottery.OrganizerFundsWithdrawn(accessibleFunds);

        lottery.withdrawOrganizerFunds(address(this));

        uint256 balanceAfterWithdraw = address(this).balance;

        vm.assertEq(lottery.organizerFunds(), 0);
        vm.assertEq(
            balanceAfterWithdraw,
            balanceBeforeWithdraw + accessibleFunds
        );
    }

    function test_withdrawOrganizerFunds_RevertsIfNoFundsToWithdraw() external {
        vm.expectRevert(
            abi.encodeWithSelector(ILotteryErrors.ZeroOrganizerBalance.selector)
        );
        lottery.withdrawOrganizerFunds(address(this));
    }

    function test_withdrawOrganizerFunds_RevertsIfTryingToWithdrawToNonPayable()
        external
    {
        lottery.start();

        uint256 ticketPrice = lottery.ticketPrice();

        for (uint i = 0; i < LotteryConfig.MAX_PARTICIPANTS_NUMBER; i++) {
            hoax(participants[i]);
            lottery.enter{value: ticketPrice * 2}(2, "@somecontactdetails");
        }

        lottery.requestWinner();

        vrfCoordinator.fulfillRandomWords(1, address(lottery));

        vm.expectRevert(
            abi.encodeWithSelector(
                ILotteryErrors.WithdrawFailed.selector,
                address(nonPayable)
            )
        );
        lottery.withdrawOrganizerFunds(address(nonPayable));
    }

    function test_latestContactDetails_ReturnsLatestContactDetails() external {
        lottery.start();

        address participant = participants[0];

        uint256 ticketPrice = lottery.ticketPrice();

        hoax(participant);
        lottery.enter{value: ticketPrice}(1, "@somecontactdetails");

        vm.warp(lottery.registrationEndTime());

        lottery.closeInvalidLottery();

        vm.assertEq(
            lottery.latestContactDetails(participant),
            "@somecontactdetails"
        );

        for (
            uint i = 0;
            i < lottery.LOTTERY_DATA_FRESHNESS_INTERVAL() - 1;
            ++i
        ) {
            lottery.start();

            vm.warp(lottery.registrationEndTime());

            lottery.closeInvalidLottery();
        }

        /* Here we assure that function returns correct data after
        multiple lotteries if it is still considered fresh. */
        vm.assertEq(
            lottery.latestContactDetails(participant),
            "@somecontactdetails"
        );

        lottery.start();

        hoax(participant);
        lottery.enter{value: ticketPrice}(1, "@anothercontactdetails");

        vm.warp(lottery.registrationEndTime());

        lottery.closeInvalidLottery();

        vm.assertEq(
            lottery.latestContactDetails(participant),
            "@anothercontactdetails"
        );
    }

    function test_latestContactDetails_RevertsIfNoContactDetails() external {
        address participant = participants[0];

        vm.expectRevert(
            abi.encodeWithSelector(
                ILotteryErrors.NoContactDetails.selector,
                participant
            )
        );
        lottery.latestContactDetails(participant);

        lottery.start();

        vm.warp(lottery.registrationEndTime());

        lottery.closeInvalidLottery();

        vm.expectRevert(
            abi.encodeWithSelector(
                ILotteryErrors.NoContactDetails.selector,
                participant
            )
        );
        lottery.latestContactDetails(participant);
    }

    function test_latestContactDetails_RevertsIfDataIsStale() external {
        lottery.start();

        address participant = participants[0];

        uint256 ticketPrice = lottery.ticketPrice();

        hoax(participant);
        lottery.enter{value: ticketPrice}(1, "@somecontactdetails");

        vm.warp(lottery.registrationEndTime());

        lottery.closeInvalidLottery();

        for (uint i = 0; i < lottery.LOTTERY_DATA_FRESHNESS_INTERVAL(); ++i) {
            lottery.start();

            vm.warp(lottery.registrationEndTime());

            lottery.closeInvalidLottery();
        }

        vm.expectRevert(
            abi.encodeWithSelector(
                ILotteryErrors.NoContactDetails.selector,
                participant
            )
        );
        lottery.latestContactDetails(participant);
    }

    function test_totalTicketsCount_ReturnsCorrectTotalTicketsCount() external {
        /* Before lottery */
        vm.assertEq(lottery.totalTicketsCount(), 0);

        lottery.start();

        uint256 ticketPrice = lottery.ticketPrice();

        for (uint i = 0; i < LotteryConfig.MAX_PARTICIPANTS_NUMBER; i++) {
            hoax(participants[i]);
            lottery.enter{value: 2 * ticketPrice}(2, "@somecontactdetails");

            /* After new participant has entered */
            vm.assertEq(lottery.totalTicketsCount(), (i + 1) * 2);
        }

        lottery.requestWinner();
        vrfCoordinator.fulfillRandomWords(1, address(lottery));

        /* After lottery */
        vm.assertEq(lottery.totalTicketsCount(), 0);
    }

    function test_userTicketsAmount_ReturnsCorrectUserTicketsTotalCount()
        external
    {
        address participant = participants[0];

        /* Before lottery */
        vm.assertEq(lottery.userTicketsCount(participant), 0);

        uint256 ticketPrice = lottery.ticketPrice();

        lottery.start();

        for (uint i = 0; i < LotteryConfig.TARGET_PARTICIPANTS_NUMBER; i++) {
            hoax(participants[i]);
            lottery.enter{value: 2 * ticketPrice}(2, "@somecontactdetails");

            /* For every new participant */
            vm.assertEq(lottery.userTicketsCount(participants[i]), 2);
        }

        uint256 previousTicketsCount = lottery.userTicketsCount(participant);

        hoax(participant);
        lottery.buyMoreTickets{value: 3 * ticketPrice}(3);

        /* After buying more */
        vm.assertEq(
            lottery.userTicketsCount(participant),
            previousTicketsCount + 3
        );

        previousTicketsCount = lottery.userTicketsCount(participant);

        vm.prank(participant);
        lottery.returnTickets(2);

        /* After return */
        vm.assertEq(
            lottery.userTicketsCount(participant),
            previousTicketsCount - 2
        );

        vm.warp(lottery.registrationEndTime());

        lottery.requestWinner();
        vrfCoordinator.fulfillRandomWords(1, address(lottery));

        /* After lottery */
        vm.assertEq(lottery.userTicketsCount(participant), 0);
    }

    function test_changeOrganizer_AllowsToChange() external {
        address newOrganizer = participants[0];

        vm.expectEmit();
        emit ILottery.OrganizerChanged(address(this), newOrganizer);

        lottery.changeOrganizer(newOrganizer);

        assertTrue(
            lottery.hasRole(lottery.LOTTERY_ORGANIZER_ROLE(), newOrganizer)
        );
        assertFalse(
            lottery.hasRole(lottery.LOTTERY_ORGANIZER_ROLE(), address(this))
        );
    }

    function test_changeOrganizer_RevertsIfTryingToChangeToZeroAddress()
        external
    {
        vm.expectRevert(
            abi.encodeWithSelector(ILotteryErrors.ZeroOrganizerAddress.selector)
        );
        lottery.changeOrganizer(address(0));
    }

    function test_changeNftFallbackRecipient_AllowsToChange() external {
        address newNftFallbackRecipient = participants[0];

        vm.expectEmit();
        emit ILottery.NftFallbackRecipientChanged(
            nftFallbackRecipient,
            newNftFallbackRecipient
        );

        lottery.changeNftFallbackRecipient(newNftFallbackRecipient);

        vm.assertEq(lottery.nftFallbackRecipient(), newNftFallbackRecipient);
    }

    function test_changeNftFallbackRecipient_RevertsIfTryingToChangeToZeroAddress()
        external
    {
        vm.expectRevert(
            abi.encodeWithSelector(
                ILotteryErrors.ZeroNftFallbackRecipientAddress.selector
            )
        );
        lottery.changeNftFallbackRecipient(address(0));
    }

    function test_changeNftFallbackRecipient_RevertsIfTryingToChangeToAccountWithCode()
        external
    {
        vm.expectRevert(
            abi.encodeWithSelector(
                ILotteryErrors.HasCode.selector,
                address(this)
            )
        );
        lottery.changeNftFallbackRecipient(address(this));
    }

    function test_setTicketPrice_AllowsToSet() external {
        uint256 initialTicketPrice = lottery.ticketPrice();
        uint256 newTicketPrice = initialTicketPrice * 2;

        vm.expectEmit();
        emit ILottery.TicketPriceChanged(initialTicketPrice, newTicketPrice);

        lottery.setTicketPrice(newTicketPrice);

        vm.assertEq(lottery.ticketPrice(), newTicketPrice);
    }

    function test_setTicketPrice_RevertsIfTryingToSetDuringActiveLottery()
        external
    {
        uint256 initialTicketPrice = lottery.ticketPrice();
        uint256 newTicketPrice = initialTicketPrice * 2;

        lottery.start();

        vm.expectRevert(
            abi.encodeWithSelector(
                ILotteryErrors.IncorrectLotteryStatus.selector,
                Types.LotteryStatus.OpenedForRegistration,
                Types.LotteryStatus.Closed
            )
        );
        lottery.setTicketPrice(newTicketPrice);

        for (uint i = 0; i < LotteryConfig.TARGET_PARTICIPANTS_NUMBER; i++) {
            hoax(participants[i]);
            lottery.enter{value: initialTicketPrice}(1, "@somecontactdetails");
        }

        vm.warp(lottery.registrationEndTime());

        vm.expectRevert(
            abi.encodeWithSelector(
                ILotteryErrors.IncorrectLotteryStatus.selector,
                Types.LotteryStatus.RegistrationEnded,
                Types.LotteryStatus.Closed
            )
        );
        lottery.setTicketPrice(newTicketPrice);

        lottery.requestWinner();

        vm.expectRevert(
            abi.encodeWithSelector(
                ILotteryErrors.IncorrectLotteryStatus.selector,
                Types.LotteryStatus.WaitingForReveal,
                Types.LotteryStatus.Closed
            )
        );
        lottery.setTicketPrice(newTicketPrice);
    }

    function test_setTicketPrice_RevertsIfTryingToSetAfterLotteryHasBeenConsideredInvalid()
        external
    {
        uint256 initialTicketPrice = lottery.ticketPrice();
        uint256 newTicketPrice = initialTicketPrice * 2;

        lottery.start();

        address participant = participants[0];

        hoax(participant);
        lottery.enter{value: initialTicketPrice}(1, "@somecontactdetails");

        vm.warp(lottery.registrationEndTime());

        vm.expectRevert(
            abi.encodeWithSelector(
                ILotteryErrors.IncorrectLotteryStatus.selector,
                Types.LotteryStatus.Invalid,
                Types.LotteryStatus.Closed
            )
        );
        lottery.setTicketPrice(newTicketPrice);
    }

    function test_setTicketPrice_RevertsIfTryingToSetZeroTicketPrice()
        external
    {
        vm.expectRevert(
            abi.encodeWithSelector(ILotteryErrors.ZeroTicketPrice.selector)
        );
        lottery.setTicketPrice(0);
    }
}

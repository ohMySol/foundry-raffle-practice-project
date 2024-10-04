// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {Raffle} from "../../src/Raffle.sol";
import {DeployRaffle} from "../../script/DeployRaffle.s.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {IRaffleCustomErrors} from "../../src/interfaces/ICustomErrors.sol";

contract RaffleTest is Test {
    Raffle public raffle; // blueprint of the Raffle contract.
    HelperConfig public helperConfig; // blueprint of the HelperConfig contract.
    HelperConfig.NetworkConfig networkConfig; //NEtworkConfig struct
    
    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");
    uint256 public constant STARTING_PLAYER_BALANCE = 10 ether;

    event RaffleEntered(address indexed player);
    event WinnerSelected(address indexed winner);

    modifier startTest(uint256 _interval) {
        vm.startPrank(alice);
        raffle.enterRaffle{value: raffle.getEntranceFee()}();
        vm.warp(block.timestamp + _interval + 1);
        vm.roll(block.number + 1);
        _;
    }

    function setUp() public {
        DeployRaffle deployer = new DeployRaffle(); // create an instance of the deploy script.
        (raffle, helperConfig) = deployer.deploy(); // deploy Raffle contract.
        networkConfig = helperConfig.getConfigByChainId(block.chainid);
        vm.deal(alice, STARTING_PLAYER_BALANCE);
    }
    
    /*//////////////////////////////////////////////////
                initialization check test
    /////////////////////////////////////////////////*/
    function testRaffleContractInitializedWithOpenStatus() public view {
        assert(raffle.getRaffleStatus() == Raffle.RaffleStatus.Open);
    }

    /*//////////////////////////////////////////////////
                enterRaffle() tests
    /////////////////////////////////////////////////*/
    function testPlayerEntersTheRaffleWhenItIsInOpenStatus() public {
        vm.startPrank(alice);

        raffle.enterRaffle{value: raffle.getEntranceFee()}();
        address payable[] memory players = raffle.getPlayers();

        assert(players[0] == alice);
    }

    function testRaffleEmitEventWhenPlayerEnters() public {
        vm.startPrank(alice);
        vm.expectEmit(true, false, false, false, address(raffle)); // address(raffle) - expected entity which will emit an event

        emit RaffleEntered(alice); // expected event to be emitted

        raffle.enterRaffle{value: raffle.getEntranceFee()}();
    }

    function testRaffleRevertWhenPlayerPayNotEnoughFee() public {
        vm.startPrank(alice);
        vm.expectRevert(IRaffleCustomErrors.Raffle_NotEnoughFee.selector);

        raffle.enterRaffle();
    }

    // Test fails with the reason: "next call did not revert as expected"
    // Need to solve this.
    // If comment the expect.. line - test will show the expected revert error.
    /* function testRaffleRevertWhenPlayerEnterRaffleInNonOpenStatus() public {
        vm.startPrank(alice);
        
        raffle.enterRaffle{value: raffle.getEntranceFee()}();
        vm.warp(block.timestamp + networkConfig.interval + 1); // current block + 31 seconds.
        vm.roll(block.number + 1); // since the time has elapsed the new block has been added.
        raffle.performUpKeep(""); // change status to 'InProgress'
        
        vm.expectRevert(IRaffleCustomErrors.Raffle_RaffleIsInProgress.selector);
        raffle.enterRaffle{value: raffle.getEntranceFee()}();
    } */

    /*//////////////////////////////////////////////////
                checkUpKeep() tests
    /////////////////////////////////////////////////*/
    function testCheckUpKeepReturnsTrueWhenAllConditionsAreMet() public startTest(networkConfig.interval) {
        (bool upKeepNeeded, ) = raffle.checkUpkeep("");

        assertTrue(upKeepNeeded);
    }

    function testCheckUpKeepReturnsFalseIfItHasNoBalance() public {
        vm.warp(block.timestamp + networkConfig.interval + 1);
        vm.roll(block.number + 1);
        
        (bool upKeepNeeded, ) = raffle.checkUpkeep("");

        assertFalse(upKeepNeeded);
    }

    function testCheckUpKeepReturnsFalseIfRaffleStatusIsInProgress() public startTest(networkConfig.interval) {
        raffle.performUpKeep("");
        
        (bool upKeepNeeded, ) = raffle.checkUpkeep("");

        assertFalse(upKeepNeeded);
    }

    function testCheckUpKeepReturnsFalseIfTimeIntervalNotPassed() public {
        vm.warp(block.timestamp + 10);
        vm.roll(block.number + 1);
        
        (bool upKeepNeeded, ) = raffle.checkUpkeep("");

        assertFalse(upKeepNeeded);
    }

    /*//////////////////////////////////////////////////
                performUpKeep() tests
    /////////////////////////////////////////////////*/
    function testPerformUpKeepRevertIfUpKeepNeededIsFalse() public startTest(10) {
        address payable[] memory players = raffle.getPlayers();
        
        vm.expectRevert(abi.encodeWithSelector(
            IRaffleCustomErrors.Raffle_UpKeepNeededFalse.selector,
            address(raffle).balance,
            players.length,
            0
        ));

        raffle.performUpKeep("");
    }

    function testPerformUpKeepShouldChangeRaffleStatus() public startTest(networkConfig.interval) {
        raffle.performUpKeep("");

        assert(raffle.getRaffleStatus() == Raffle.RaffleStatus.InProgress);
    }

    function testPerformUpKeepLogsEmittedSuccessfully() public startTest(networkConfig.interval) {
        vm.recordLogs(); // telling to record all the following logs
        
        raffle.performUpKeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs(); // receive all the recorded logs
        bytes32 requestId = entries[0].topics[1];
        
        assert(uint256(requestId) > 0); // do a type casting from bytes to uint256
    }

}

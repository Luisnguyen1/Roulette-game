// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "lib/forge-std/src/Test.sol";
import "../src/Roulette.sol";


contract RouletteTest is Test {
    Roulette roulette;
    address player1;
    address player2;

    function setUp() public {
        roulette = new Roulette();
        player1 = address(1);
        player2 = address(2);
        vm.deal(player1, 100 ether);
        vm.deal(player2, 100 ether);
    }

    function testConnectWallet() public {
        vm.startPrank(player1);
        roulette.connectWallet();
        (address wallet,) = roulette.players(player1);
        assertEq(wallet, player1);
        vm.stopPrank();
    }

    function testConnectWalletTwiceShouldFail() public {
        vm.startPrank(player1);
        roulette.connectWallet();
        vm.expectRevert("Wallet already connected");
        roulette.connectWallet();
        vm.stopPrank();
    }

    function testPlaceSingleBet() public {
        vm.startPrank(player1);
        roulette.connectWallet();
        uint8[] memory choices = new uint8[](1);
        choices[0] = 5;
        roulette.placeBet{value: 1 ether}(Roulette.BetType.Single, choices);
        
        (uint256 amount, Roulette.BetType betType, uint8[] memory betChoices) = roulette.getBet(0);
        assertEq(amount, 1 ether);
        assertEq(uint(betType), uint(Roulette.BetType.Single));
        assertEq(betChoices[0], 5);
        vm.stopPrank();
    }

    function testPlaceRedBlackBet() public {
        vm.startPrank(player1);
        roulette.connectWallet();
        uint8[] memory choices = new uint8[](1);
        choices[0] = 1; // Red
        roulette.placeBet{value: 1 ether}(Roulette.BetType.RedBlack, choices);
        
        (uint256 amount, Roulette.BetType betType, uint8[] memory betChoices) = roulette.getBet(0);
        assertEq(amount, 1 ether);
        assertEq(uint(betType), uint(Roulette.BetType.RedBlack));
        assertEq(betChoices[0], 1);
        vm.stopPrank();
    }

    function testSpinWheel() public {
        vm.startPrank(player1);
        roulette.spinWheel();
        uint8 result = roulette.spinResults(0);
        assertTrue(result <= 36);
        vm.stopPrank();
    }

    function testWinningPayout() public {
        vm.startPrank(player1);
        roulette.connectWallet();
        
        // Place single number bet
        uint8[] memory choices = new uint8[](1);
        choices[0] = 5;
        roulette.placeBet{value: 1 ether}(Roulette.BetType.Single, choices);
        
        // Manipulate random number for testing
        vm.warp(1000);
        vm.roll(1000);
        
        roulette.spinWheel();
        roulette.calculatePayout(0);
        
        (, uint256 balance) = roulette.players(player1);
        assertTrue(balance >= 1 ether);
        vm.stopPrank();
    }

    function testWithdraw() public {
        vm.startPrank(player1);
        roulette.connectWallet();
        
        // Place bet
        uint8[] memory choices = new uint8[](1);
        choices[0] = 5;
        roulette.placeBet{value: 1 ether}(Roulette.BetType.Single, choices);
        
        // Manipulate block values to force result = 5
        uint256 blockNumber = 1000;
        vm.roll(blockNumber);
        vm.warp(blockNumber);
        
        // Simulate the random number generation until we get 5
        bytes32 randomHash = keccak256(abi.encodePacked(blockNumber, blockNumber));
        uint8 result = uint8(uint256(randomHash) % 37);
        
        while (result != 5) {
            blockNumber++;
            vm.roll(blockNumber);
            vm.warp(blockNumber);
            randomHash = keccak256(abi.encodePacked(blockNumber, blockNumber));
            result = uint8(uint256(randomHash) % 37);
        }
        
        roulette.spinWheel();
        roulette.calculatePayout(0);
        
        // Get player balance after win
        (, uint256 balanceAfterWin) = roulette.players(player1);
        require(balanceAfterWin > 0, "Player should have won");
        
        // Try to withdraw half of the balance
        uint256 withdrawAmount = balanceAfterWin / 2;
        uint256 initialBalance = address(player1).balance;
        roulette.withdraw(withdrawAmount);
        
        // Verify withdrawal
        assertEq(address(player1).balance, initialBalance + withdrawAmount);
        vm.stopPrank();
    }

    function test_RevertWhen_WithdrawInsufficientBalance() public {
        vm.startPrank(player1);
        roulette.connectWallet();
        roulette.placeBet{value: 1 ether}(Roulette.BetType.Single, new uint8[](1));
        
        vm.expectRevert("Insufficient balance");
        roulette.withdraw(2 ether);
        vm.stopPrank();
    }

    function testGetCurrentSpinID() public {
        // Initial spin counter should be 0
        uint256 initialSpinCounter = roulette.getCurrentSpinID();
        assertEq(initialSpinCounter, 0, "Initial spin counter should be 0");

        // After one spin, counter should be 1
        vm.startPrank(player1);
        roulette.spinWheel();
        uint256 counterAfterSpin = roulette.getCurrentSpinID();
        assertEq(counterAfterSpin, 1, "Spin counter should be 1 after first spin");
        
        // After another spin, counter should be 2
        roulette.spinWheel();
        uint256 counterAfterSecondSpin = roulette.getCurrentSpinID();
        assertEq(counterAfterSecondSpin, 2, "Spin counter should be 2 after second spin");
        vm.stopPrank();
    }
}

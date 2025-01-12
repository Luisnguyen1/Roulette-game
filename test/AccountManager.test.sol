// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/AccountManager.sol";
import "../src/Roulette.sol";

contract AccountManagerTest is Test {
    AccountManager public accountManager;
    Roulette public roulette;
    address user1;
    address user2;

    function setUp() public {
        // Deploy Roulette contract first
        roulette = new Roulette();
        // Deploy AccountManager with Roulette address
        accountManager = new AccountManager(payable(address(roulette)));
        
        // Setup test accounts
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        // Fund test accounts
        vm.deal(user1, 100 ether);
        vm.deal(user2, 100 ether);
    }

    function testAccountActivation() public {
        vm.startPrank(user1);
        // Test activation
        accountManager.activateAccount();
        (,,,,bool isActive) = accountManager.getAccountInfo();
        assertTrue(isActive, "Account should be active after activation");

        // Test deactivation
        accountManager.deactivateAccount();
        (,,,,isActive) = accountManager.getAccountInfo();
        assertFalse(isActive, "Account should be inactive after deactivation");
        vm.stopPrank();
    }

    function testDeposit() public {
        vm.startPrank(user1);
        accountManager.activateAccount();
        
        uint256 depositAmount = 1 ether;
        accountManager.deposit{value: depositAmount}();
        
        (uint256 balance,,,, ) = accountManager.getAccountInfo();
        assertEq(balance, depositAmount, "Balance should match deposit amount");
        vm.stopPrank();
    }

    function testWithdraw() public {
        vm.startPrank(user1);
        accountManager.activateAccount();
        
        uint256 depositAmount = 2 ether;
        accountManager.deposit{value: depositAmount}();
        
        uint256 withdrawAmount = 1 ether;
        uint256 balanceBefore = address(user1).balance;
        accountManager.withdraw(withdrawAmount);
        
        uint256 balanceAfter = address(user1).balance;
        assertEq(balanceAfter - balanceBefore, withdrawAmount, "Withdrawal amount should be received");
        vm.stopPrank();
    }

    function testTransferToRoulette() public {
        vm.startPrank(user1);
        accountManager.activateAccount();
        
        uint256 amount = 1 ether;
        accountManager.deposit{value: amount}();
        
        uint256 rouletteBalanceBefore = address(roulette).balance;
        accountManager.transferToRoulette(amount);
        uint256 rouletteBalanceAfter = address(roulette).balance;
        
        assertEq(rouletteBalanceAfter - rouletteBalanceBefore, amount, "Amount should be transferred to Roulette");
        vm.stopPrank();
    }

    function testReceiveWinnings() public {
        vm.startPrank(user1);
        accountManager.activateAccount();
        
        uint256 winnings = 5 ether;
        vm.deal(address(this), winnings);
        (bool success,) = address(accountManager).call{value: winnings}("");
        require(success, "Transfer failed");
        
        (uint256 balance,,,, ) = accountManager.getAccountInfo();
        assertEq(balance, winnings, "Winnings should be added to balance");
        vm.stopPrank();
    }

    function testFailWithdrawInsufficientBalance() public {
        vm.startPrank(user1);
        accountManager.activateAccount();
        accountManager.deposit{value: 1 ether}();
        accountManager.withdraw(2 ether); // Should fail
        vm.stopPrank();
    }

    function testFailInactiveAccount() public {
        vm.startPrank(user1);
        // Try to deposit without activating account
        accountManager.deposit{value: 1 ether}(); // Should fail
        vm.stopPrank();
    }

    // Receive function to allow contract to receive ETH
    receive() external payable {}
}

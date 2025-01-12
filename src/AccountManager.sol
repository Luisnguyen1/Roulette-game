// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./Roulette.sol";

contract AccountManager {
    // Struct để lưu thông tin tài khoản
    struct Account {
        uint256 balance;        // Số dư khả dụng
        uint256 totalDeposit;   // Tổng số tiền đã nạp
        uint256 totalWithdraw;  // Tổng số tiền đã rút
        uint256 lastUpdate;     // Thời gian cập nhật cuối
        bool isActive;          // Trạng thái tài khoản
    }

    // Mapping lưu thông tin tài khoản theo địa chỉ
    mapping(address => Account) public accounts;
    
    // Reference đến contract Roulette
    Roulette public roulette;

    // Events
    event Deposit(address indexed user, uint256 amount, uint256 timestamp);
    event Withdraw(address indexed user, uint256 amount, uint256 timestamp);
    event AccountActivated(address indexed user, uint256 timestamp);
    event AccountDeactivated(address indexed user, uint256 timestamp);
    event Payout(address indexed player, uint256 amount);
    event BetPlaced(address indexed player, uint256 amount);
    event WinningPaid(address indexed player, uint256 amount);
    event Debug(string message, uint256 value);

    // Constructor
    constructor(address payable _rouletteAddress) {
        roulette = Roulette(_rouletteAddress);
    }

    // Modifier kiểm tra tài khoản active
    modifier onlyActiveAccount() {
        require(accounts[msg.sender].isActive, "Account is not active");
        _;
    }

    // Add functions to handle balance updates from Roulette
    function addBalance(address player, uint256 amount) external {
        require(msg.sender == address(roulette), "Only Roulette can add balance");
        
        Account storage account = accounts[player];
        require(account.isActive, "Account not active");
        
        // Log initial state
        emit Debug("Current balance", account.balance);
        emit Debug("Adding amount", amount);
        
        // Update balance
        account.balance += amount;
        account.lastUpdate = block.timestamp;
        
        // Log final state
        emit Debug("Final balance", account.balance);
        emit WinningPaid(player, amount);
    }

    function subtractBalance(address player, uint256 amount) external {
        require(msg.sender == address(roulette), "Only Roulette can subtract balance");
        
        Account storage account = accounts[player];
        require(account.isActive, "Account not active");
        require(account.balance >= amount, "Insufficient balance");
        
        // Trừ tiền thua
        account.balance -= amount;
        emit Debug("Balance subtracted after loss", amount);
        emit Debug("New balance", account.balance);
    }

    // Thay đổi hàm handleBet thành handleInitialBet
    function handleInitialBet(address player, uint256 amount) external payable {
        require(msg.sender == address(roulette), "Only Roulette can handle bets");
        require(msg.value == amount, "Amount mismatch");
        
        Account storage account = accounts[player];
        require(account.isActive, "Account not active");
        require(account.balance >= amount, "Insufficient balance for bet");
        
        // KHÔNG cộng tiền cược vào balance
        emit BetPlaced(player, amount);
    }

    // Sửa lại hàm handleWinning để thực sự cộng tiền thắng
    function handleWinning(address player, uint256 amount) external {
        require(msg.sender == address(roulette), "Only Roulette can handle winnings");
        
        Account storage account = accounts[player];
        require(account.isActive, "Account not active");
        
        // Log initial balance
        emit Debug("Balance before win", account.balance);
        
        // Add winning amount to player's balance
        account.balance += amount;
        account.lastUpdate = block.timestamp;
        
        // Log final balance
        emit Debug("Balance after win", account.balance);
        emit Debug("Win amount", amount);
        
        // Transfer ETH from Roulette contract to AccountManager
        require(
            address(this).balance >= amount,
            "Insufficient contract balance for payout"
        );
        
        // Emit winning event
        emit WinningPaid(player, amount);
        
        // Log confirmation
        emit Debug("Winning processed successfully", amount);
    }

    // Thêm function để debug
    function getDetailedBalance(address player) external view returns (
        uint256 currentBalance,
        uint256 totalDeposited,
        uint256 totalWithdrawn,
        uint256 lastUpdateTime
    ) {
        Account storage account = accounts[player];
        return (
            account.balance,
            account.totalDeposit,
            account.totalWithdraw,
            account.lastUpdate
        );
    }

    // Hàm kích hoạt tài khoản
    function activateAccount() public {
        require(!accounts[msg.sender].isActive, "Account already active");
        accounts[msg.sender].isActive = true;
        accounts[msg.sender].lastUpdate = block.timestamp;
        emit AccountActivated(msg.sender, block.timestamp);
    }

    // Hàm vô hiệu hóa tài khoản
    function deactivateAccount() external onlyActiveAccount {
        accounts[msg.sender].isActive = false;
        emit AccountDeactivated(msg.sender, block.timestamp);
    }

    // Hàm nạp tiền
    function deposit() external payable onlyActiveAccount {
        require(msg.value > 0, "Amount must be greater than 0");
        
        Account storage account = accounts[msg.sender];
        account.balance += msg.value;
        account.totalDeposit += msg.value;
        account.lastUpdate = block.timestamp;

        emit Deposit(msg.sender, msg.value, block.timestamp);
    }

    // Hàm rút tiền
    function withdraw(uint256 amount) external onlyActiveAccount {
        Account storage account = accounts[msg.sender];
        require(account.balance >= amount, "Insufficient balance");
        
        account.balance -= amount;
        account.totalWithdraw += amount;
        account.lastUpdate = block.timestamp;
        
        payable(msg.sender).transfer(amount);
        emit Withdraw(msg.sender, amount, block.timestamp);
    }


    // Hàm lấy thông tin tài khoản
    function getAccountInfo(address user) public view returns (
        uint256 balance,
        uint256 totalDeposit,
        uint256 totalWithdraw,
        uint256 lastUpdate,
        bool isActive
    ) {
        Account storage account = accounts[user];
        return (
            account.balance,
            account.totalDeposit,
            account.totalWithdraw,
            account.lastUpdate,
            account.isActive
        );
    }

    // Fallback và receive functions để nhận ETH
    receive() external payable {
        emit Debug("Received ETH", msg.value);
    }

    fallback() external payable {
        emit Debug("Fallback called with ETH", msg.value);
    }

    // Add balance check function
    function getContractBalance() external view returns (uint256) {
        return address(this).balance;
    }
}

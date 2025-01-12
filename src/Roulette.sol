// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Move interface outside of contract
interface IAccountManager {
    function addBalance(address player, uint256 amount) external;
    function subtractBalance(address player, uint256 amount) external;
}

contract Roulette {
    // Enum để định nghĩa các loại cược
    enum BetType {
        Single,         // Cược đơn (1 ô)
        Double,         // Cược đôi (2 ô liền kề)
        Square,         // Cược vuông (4 ô)
        Row,            // Cược hàng dọc (3 ô)
        DoubleRow,      // Cược 2 hàng dọc liền kề
        Area,           // Cược khu vực (ví dụ: 1-12)
        Column,         // Cược cột (12 ô)
        RedBlack,       // Cược đỏ/đen
        EvenOdd,        // Cược chẵn/lẻ
        LowHigh,        // Cược 1-18 / 19-36
        TwoToOne        // Cược 2:1 (cột)
    }

    // Struct để lưu thông tin đặt cược
    struct Bet {
        address player;     
        uint256 amount;     
        BetType betType;    
        uint8[] choices;    
    }

    // Struct để lưu thông tin người chơi
    struct Player {
        address wallet;     // Địa chỉ ví
        uint256 balance;    // Số dư
    }

    // Mapping để lưu thông tin đặt cược và người chơi
    mapping(address => Player) public players;
    mapping(uint256 => Bet) public bets;
    mapping(uint256 => uint8) public spinResults; // Kết quả các vòng quay

    // Biến đếm
    uint256 public spinCounter;
    uint256 public betCounter;

    // Sự kiện
    event BetPlaced(address indexed player, uint256 betId, BetType betType, uint8[] choices, uint256 amount);
    event SpinResult(uint256 spinId, uint8 result);
    event Payout(address indexed player, uint256 amount);

    // Add AccountManager interface
    address public accountManagerAddress;
    
    // Add constructor to set AccountManager address
    constructor(address _accountManagerAddress) {
        accountManagerAddress = _accountManagerAddress;
    }

    // Add function to set AccountManager address
    function setAccountManager(address _accountManagerAddress) external {
        // Only allow setting once
        require(accountManagerAddress == address(0), "AccountManager already set");
        accountManagerAddress = _accountManagerAddress;
    }

    // Hàm để người chơi kết nối ví
    function connectWallet() external {
        require(players[msg.sender].wallet == address(0), "Wallet already connected");
        players[msg.sender] = Player({
            wallet: msg.sender,
            balance: 0
        });
    }

    // Sửa event GameResult để thêm choices
    event GameResult(
        address indexed player,
        uint8 result,
        uint256 betAmount,
        uint256 winAmount,
        bool isWin,
        uint8[] choices  // Thêm choices vào đây
    );

    // Move mapping to top with other state variables
    mapping(address => BetType) public specialBetTypes;

    // Thay thế hàm placeBet và spinWheel bằng hàm mới
    function placeBetAndSpin(uint8[] memory choices) external payable returns (uint8) {
        require(msg.value > 0, "Bet amount must be greater than 0");
        require(choices.length > 0, "Must specify bet choices");

        // Xác định loại cược và log
        BetType betType;
        if (choices.length == 1) {
            emit Debug("Single choice value", choices[0]);
            if (choices[0] <= 36) {
                betType = BetType.Single;
                emit Debug("Set bet type to Single", uint256(betType));
            } else {
                // Special bets với các giá trị > 36
                if (choices[0] == 37) { // Red
                    betType = BetType.RedBlack;
                    emit Debug("Set bet type to RedBlack (Red)", 1);
                } else if (choices[0] == 38) { // Black
                    betType = BetType.RedBlack;
                    emit Debug("Set bet type to RedBlack (Black)", 0);
                } else if (choices[0] == 39) { // Even
                    betType = BetType.EvenOdd;
                    emit Debug("Set bet type to EvenOdd (Even)", 1);
                } else if (choices[0] == 40) { // Odd
                    betType = BetType.EvenOdd;
                    emit Debug("Set bet type to EvenOdd (Odd)", 0);
                } else if (choices[0] == 41) { // 1-18
                    betType = BetType.LowHigh;
                    emit Debug("Set bet type to LowHigh (Low)", 1);
                } else if (choices[0] == 42) { // 19-36
                    betType = BetType.LowHigh;
                    emit Debug("Set bet type to LowHigh (High)", 0);
                }
            }
        } else if (choices.length == 2) {
            betType = BetType.Double;
        } else if (choices.length == 4) {
            betType = BetType.Square;
        } else {
            revert("Invalid number of choices");
        }

        // Store the bet type for future reference
        specialBetTypes[msg.sender] = betType;

        // Xử lý tiền cược qua AccountManager - LƯU Ý: Không cộng vào balance ngay
        (bool depositSuccess, ) = accountManagerAddress.call{value: msg.value}(
            abi.encodeWithSignature(
                "handleInitialBet(address,uint256)",  // Đổi tên function
                msg.sender,
                msg.value
            )
        );
        require(depositSuccess, "Failed to handle bet with AccountManager");

        // Lưu thông tin cược
        bets[betCounter] = Bet({
            player: msg.sender,
            amount: msg.value,
            betType: betType,
            choices: choices
        });

        // Tạo số ngẫu nhiên và kiểm tra thắng thua
        uint8 result = generateRandomNumber();
        spinResults[spinCounter] = result;
        bool isWin = isWinningBet(bets[betCounter], result);

        // Xử lý tiền thắng/thua
        uint256 winAmount = 0;
        if (isWin) {
            // Nếu thắng, tính và cộng tiền thắng
            winAmount = calculateWinningAmount(bets[betCounter]);
            try IAccountManager(accountManagerAddress).addBalance(msg.sender, winAmount) {
                emit Debug("Win amount added", winAmount);
                emit Payout(msg.sender, winAmount);
            } catch {
                revert("Failed to update winner balance");
            }
        } else {
            // Nếu thua, trừ tiền cược
            try IAccountManager(accountManagerAddress).subtractBalance(msg.sender, msg.value) {
                emit Debug("Bet amount subtracted", msg.value);
            } catch {
                revert("Failed to subtract bet amount");
            }
        }

        emit Debug("Generated result", result);
        emit Debug("Final bet type", uint256(betType));
        emit Debug("Player choice", choices[0]);

        // Emit events
        emit BetPlaced(msg.sender, betCounter, betType, choices, msg.value);
        emit SpinResult(spinCounter, result);
        emit GameResult(msg.sender, result, msg.value, winAmount, isWin, choices); // Thêm choices vào đây

        betCounter++;
        spinCounter++;

        return result;
    }

    // Thêm hàm private để tạo số ngẫu nhiên
    function generateRandomNumber() private view returns (uint8) {
        uint256 randomSeed = uint256(keccak256(abi.encodePacked(
            blockhash(block.number - 1),
            block.timestamp,
            msg.sender,
            address(this),
            spinCounter
        )));
        
        return uint8(randomSeed % 37);
    }

    // Thêm hàm getter cho bet
    function getBet(uint256 betId) public view returns (uint256 amount, BetType betType, uint8[] memory choices) {
        Bet storage bet = bets[betId];
        return (bet.amount, bet.betType, bet.choices);
    }

    // Add function to update player balance in AccountManager
    function updatePlayerBalance(address player, uint256 amount, bool isWin) private {
        // Create interface to AccountManager
        (bool success, ) = accountManagerAddress.call(
            abi.encodeWithSignature(
                isWin ? "addBalance(address,uint256)" : "subtractBalance(address,uint256)", 
                player, 
                amount
            )
        );
        require(success, "Failed to update balance in AccountManager");
    }

    function calculatePayout(uint256 betId, uint256 spinId) external {
                
        uint8 result = spinResults[spinId];
        uint256 totalPayout = 0;
        
        // Get bet information
        Bet memory currentBet = bets[betId];
        
        // Log for debugging
        emit Debug("Processing bet ID", betId);
        emit Debug("Processing spin ID", spinId);
        emit Debug("Spin result", result);
        emit Debug("Bet amount", currentBet.amount);

        require(currentBet.amount > 0, "No bet found for this ID");
        require(currentBet.player == msg.sender, "Not your bet");

        // Check if bet is winning
        if (isWinningBet(currentBet, result)) {
            // Calculate win amount based on bet type
            totalPayout = calculateWinningAmount(currentBet);
            emit Debug("Win amount calculated", totalPayout);
            
            // Process payout if player won
            if (totalPayout > 0) {
                // Transfer ETH to AccountManager
                (bool transferSuccess, ) = accountManagerAddress.call{value: totalPayout}("");
                require(transferSuccess, "Failed to transfer ETH to AccountManager");

                // Update player balance through AccountManager
                (bool success, ) = accountManagerAddress.call(
                    abi.encodeWithSignature(
                        "handleWinning(address,uint256)",
                        currentBet.player,
                        totalPayout
                    )
                );
                require(success, "Failed to process winning with AccountManager");
                
                emit Payout(currentBet.player, totalPayout);
                emit Debug("Total payout processed", totalPayout);
            }
        }
    }

    // Add debug event
    event Debug(string message, uint256 value);

    // Thêm hàm helper để kiểm tra số đỏ
    function isRedNumber(uint8 number) internal returns (bool) {
        uint8[18] memory redNumbers = [
            1,3,5,7,9,12,14,16,18,19,21,23,25,27,30,32,34,36
        ];
        
        emit Debug("Checking if number is red", number);
        
        for (uint8 i = 0; i < redNumbers.length; i++) {
            if (redNumbers[i] == number) {
                emit Debug("Found number in red numbers", number);
                return true;
            }
        }
        emit Debug("Number is not red", number);
        return false;
    }

    // Remove the old private helper functions since we're using direct mapping access
    // Remove isSpecialBet and getSpecialBetType functions

    // Hàm kiểm tra cược thắng
    function isWinningBet(Bet memory bet, uint8 result) public returns (bool) {        
        // Log tất cả các thông tin đầu vào
        emit Debug("=== WIN CHECK START ===", 0);
        emit Debug("Bet type", uint256(bet.betType));
        emit Debug("Spin result", result);
        for(uint i = 0; i < bet.choices.length; i++) {
            emit Debug("Player choice", bet.choices[i]);
        }

        // Red/Black bet
        if (bet.betType == BetType.RedBlack) {
            bool isRed = isRedNumber(result);
            bool playerChoseRed = (bet.choices[0] == 37); // 37 for Red
            
            // Log chi tiết quá trình kiểm tra Red/Black
            emit Debug("Result number", result);
            emit Debug("Is result red?", isRed ? 1 : 0);
            emit Debug("Did player choose red?", playerChoseRed ? 1 : 0);
            
            bool win = (playerChoseRed == isRed);
            emit Debug("Red/Black win check", win ? 1 : 0);
            emit Debug("=== WIN CHECK END ===", win ? 1 : 0);
            return win;
        }

        // Single number bet
        if (bet.betType == BetType.Single) {
            bool win = (bet.choices[0] == result);
            emit Debug("Single number comparison", win ? 1 : 0);
            return win;
        }

        // Even/Odd bet
        if (bet.betType == BetType.EvenOdd) {
            if (result == 0) return false;
            bool isEven = result % 2 == 0;
            bool playerChoseEven = (bet.choices[0] == 39); // 39 for Even
            
            emit Debug("Result number", result);
            emit Debug("Is result even?", isEven ? 1 : 0);
            emit Debug("Did player choose even?", playerChoseEven ? 1 : 0);
            
            bool win = (playerChoseEven == isEven);
            emit Debug("Even/Odd win check", win ? 1 : 0);
            return win;
        }

        // High/Low bet
        if (bet.betType == BetType.LowHigh) {
            if (result == 0) return false;
            bool isLow = result <= 18;
            bool playerChoseLow = (bet.choices[0] == 41); // 41 for 1-18
            
            emit Debug("Result number", result);
            emit Debug("Is result low (1-18)?", isLow ? 1 : 0);
            emit Debug("Did player choose low?", playerChoseLow ? 1 : 0);
            
            bool win = (playerChoseLow == isLow);
            emit Debug("High/Low win check", win ? 1 : 0);
            return win;
        }
        
        emit Debug("=== WIN CHECK END (Unknown bet type) ===", 0);
        return false;
    }

    // Thêm event để log các giá trị boolean
    event DebugBool(string message, bool value);

    // Sửa lại hàm tính toán số tiền thắng
    function calculateWinningAmount(Bet memory bet) internal pure returns (uint256) {
        // Special bets (1:1 payout)
        if (bet.betType == BetType.RedBlack || 
            bet.betType == BetType.EvenOdd || 
            bet.betType == BetType.LowHigh) {
            return bet.amount; // Return exactly the bet amount for 1:1 payout
        }
        
        // Other bets with their respective multipliers
        if (bet.betType == BetType.Single) return bet.amount * 35; // 35:1 payout
        if (bet.betType == BetType.Double) return bet.amount * 17; // 17:1 payout
        if (bet.betType == BetType.Square) return bet.amount * 8; // 8:1 payout
        if (bet.betType == BetType.Row) return bet.amount * 11; // 11:1 payout
        if (bet.betType == BetType.DoubleRow) return bet.amount * 5; // 5:1 payout
        if (bet.betType == BetType.Area) return bet.amount * 2; // 2:1 payout
        if (bet.betType == BetType.Column) return bet.amount * 2; // 2:1 payout
        if (bet.betType == BetType.TwoToOne) return bet.amount * 2; // 2:1 payout
        
        return 0;
    }

    // Hàm rút tiền
    function withdraw(uint256 amount) external {
        require(players[msg.sender].balance >= amount, "Insufficient balance");
        players[msg.sender].balance -= amount;
        payable(msg.sender).transfer(amount);
    }

    // Cho phép contract nhận ETH trực tiếp
    receive() external payable {
        emit Debug("Received ETH", msg.value);
    }
    
    // Fallback function cho phép contract nhận ETH khi gọi hàm không tồn tại
    fallback() external payable {
        emit Debug("Fallback called with ETH", msg.value);
    }
}
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

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
        uint256 amount;     // Số tiền đặt cược
        BetType betType;    // Loại cược
        uint8[] choices;    // Các lựa chọn (ví dụ: số cụ thể, màu, nhóm)
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

    // Hàm để người chơi kết nối ví
    function connectWallet() external {
        require(players[msg.sender].wallet == address(0), "Wallet already connected");
        players[msg.sender] = Player({
            wallet: msg.sender,
            balance: 0
        });
    }

    // Hàm đặt cược
    function placeBet(BetType betType, uint8[] memory choices) external payable {
        require(players[msg.sender].wallet != address(0), "Wallet not connected");
        require(msg.value > 0, "Bet amount must be greater than 0");

        // Kiểm tra loại cược và số lượng lựa chọn
        if (betType == BetType.Single) {
            require(choices.length == 1, "Single bet requires exactly 1 choice");
        } else if (betType == BetType.Double) {
            require(choices.length == 2, "Double bet requires exactly 2 choices");
        } else if (betType == BetType.Square) {
            require(choices.length == 4, "Square bet requires exactly 4 choices");
        } else if (betType == BetType.Row) {
            require(choices.length == 3, "Row bet requires exactly 3 choices");
        } else if (betType == BetType.DoubleRow) {
            require(choices.length == 6, "Double row bet requires exactly 6 choices");
        } else if (betType == BetType.Area) {
            require(choices.length == 1, "Area bet requires exactly 1 choice");
        } else if (betType == BetType.Column) {
            require(choices.length == 12, "Column bet requires exactly 12 choices");
        } else if (betType == BetType.RedBlack || betType == BetType.EvenOdd || betType == BetType.LowHigh || betType == BetType.TwoToOne) {
            require(choices.length == 1, "Special bet requires exactly 1 choice");
        }

        // Lưu thông tin đặt cược
        bets[betCounter] = Bet({
            amount: msg.value,
            betType: betType,
            choices: choices
        });

        players[msg.sender].balance += msg.value;
        betCounter++;

        emit BetPlaced(msg.sender, betCounter - 1, betType, choices, msg.value);
    }

    // Hàm xử lý kết quả vòng quay
    function spinWheel() external {
        uint8 result = uint8(uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao))) % 37);
        spinResults[spinCounter] = result;
        spinCounter++;

        emit SpinResult(spinCounter - 1, result);
    }

    // Hàm tính toán và trả thưởng
    function calculatePayout(uint256 spinId) external {
        require(spinId < spinCounter, "Invalid spin ID");
        uint8 result = spinResults[spinId];

        for (uint256 i = 0; i < betCounter; i++) {
            Bet memory bet = bets[i];
            if (isWinningBet(bet, result)) {
                uint256 payout = calculateWinningAmount(bet);
                players[msg.sender].balance += payout;
                emit Payout(msg.sender, payout);
            }
        }
    }

    // Hàm kiểm tra cược thắng
    function isWinningBet(Bet memory bet, uint8 result) internal pure returns (bool) {
        if (bet.betType == BetType.Single) {
            return bet.choices[0] == result;
        } else if (bet.betType == BetType.Double) {
            return bet.choices[0] == result || bet.choices[1] == result;
        } else if (bet.betType == BetType.Square) {
            for (uint8 i = 0; i < 4; i++) {
                if (bet.choices[i] == result) return true;
            }
        } else if (bet.betType == BetType.Row) {
            for (uint8 i = 0; i < 3; i++) {
                if (bet.choices[i] == result) return true;
            }
        } else if (bet.betType == BetType.DoubleRow) {
            for (uint8 i = 0; i < 6; i++) {
                if (bet.choices[i] == result) return true;
            }
        } else if (bet.betType == BetType.Area) {
            uint8 area = bet.choices[0];
            if (area == 1 && result >= 1 && result <= 12) return true;
            if (area == 2 && result >= 13 && result <= 24) return true;
            if (area == 3 && result >= 25 && result <= 36) return true;
        } else if (bet.betType == BetType.Column) {
            for (uint8 i = 0; i < 12; i++) {
                if (bet.choices[i] == result) return true;
            }
        } else if (bet.betType == BetType.RedBlack) {
            bool isRed = (result % 2 == 1 && result <= 10) || (result % 2 == 0 && result >= 11 && result <= 18) || (result % 2 == 1 && result >= 19 && result <= 28) || (result % 2 == 0 && result >= 29);
            return (bet.choices[0] == 1 && isRed) || (bet.choices[0] == 0 && !isRed);
        } else if (bet.betType == BetType.EvenOdd) {
            return (bet.choices[0] == 1 && result % 2 == 0) || (bet.choices[0] == 0 && result % 2 == 1);
        } else if (bet.betType == BetType.LowHigh) {
            return (bet.choices[0] == 1 && result >= 1 && result <= 18) || (bet.choices[0] == 0 && result >= 19 && result <= 36);
        } else if (bet.betType == BetType.TwoToOne) {
            uint8 column = result % 3;
            return bet.choices[0] == column;
        }
        return false;
    }

    // Hàm tính toán số tiền thắng
    function calculateWinningAmount(Bet memory bet) internal pure returns (uint256) {
        if (bet.betType == BetType.Single) return bet.amount * 36;
        if (bet.betType == BetType.Double) return bet.amount * 18;
        if (bet.betType == BetType.Square) return bet.amount * 9;
        if (bet.betType == BetType.Row) return bet.amount * 12;
        if (bet.betType == BetType.DoubleRow) return bet.amount * 6;
        if (bet.betType == BetType.Area) return bet.amount * 3;
        if (bet.betType == BetType.Column) return bet.amount * 3;
        if (bet.betType == BetType.RedBlack || bet.betType == BetType.EvenOdd || bet.betType == BetType.LowHigh) return bet.amount * 2;
        if (bet.betType == BetType.TwoToOne) return bet.amount * 3;
        return 0;
    }

    // Hàm rút tiền
    function withdraw(uint256 amount) external {
        require(players[msg.sender].balance >= amount, "Insufficient balance");
        players[msg.sender].balance -= amount;
        payable(msg.sender).transfer(amount);
    }
}
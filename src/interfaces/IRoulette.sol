// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
interface IRoulette {
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

    // Sự kiện
    event BetPlaced(address indexed player, uint256 betId, BetType betType, uint8[] choices, uint256 amount);
    event SpinResult(uint256 spinId, uint8 result);
    event Payout(address indexed player, uint256 amount);

    // Hàm để người chơi kết nối ví
    function connectWallet() external;

    // Hàm đặt cược
    function placeBet(BetType betType, uint8[] memory choices) external payable;

    // Hàm xử lý kết quả vòng quay
    function spinWheel() external;

    // Hàm tính toán và trả thưởng
    function calculatePayout(uint256 spinId) external;

    // Hàm rút tiền
    function withdraw(uint256 amount) external;

    // Hàm lấy thông tin người chơi
    function getPlayerBalance(address player) external view returns (uint256);

    // Hàm lấy kết quả vòng quay
    function getSpinResult(uint256 spinId) external view returns (uint8);
}
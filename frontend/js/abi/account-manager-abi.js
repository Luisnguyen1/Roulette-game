export const ACCOUNT_MANAGER_ABI = [
  {
    "inputs": [{"type": "address", "name": "_rouletteAddress"}],
    "stateMutability": "nonpayable",
    "type": "constructor"
  },
  {
    "inputs": [],
    "name": "activateAccount",
    "outputs": [],
    "stateMutability": "nonpayable",
    "type": "function"
  },
  {
    "inputs": [{"type": "address"}],
    "name": "accounts",
    "outputs": [
      {"type": "uint256", "name": "balance"},
      {"type": "uint256", "name": "totalDeposit"},
      {"type": "uint256", "name": "totalWithdraw"},
      {"type": "uint256", "name": "lastUpdate"},
      {"type": "bool", "name": "isActive"}
    ],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [],
    "name": "deposit",
    "outputs": [],
    "stateMutability": "payable",
    "type": "function"
  },
  {
    "inputs": [{"type": "uint256"}],
    "name": "withdraw",
    "outputs": [],
    "stateMutability": "nonpayable",
    "type": "function"
  },
  {
    "inputs": [{"type": "address", "name": "user"}],
    "name": "getAccountInfo",
    "outputs": [
      {"type": "uint256", "name": "balance"},
      {"type": "uint256", "name": "totalDeposit"},
      {"type": "uint256", "name": "totalWithdraw"},
      {"type": "uint256", "name": "lastUpdate"},
      {"type": "bool", "name": "isActive"}
    ],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [{"type": "uint256"}],
    "name": "transferToRoulette",
    "outputs": [],
    "stateMutability": "nonpayable",
    "type": "function"
  },
  {
    "inputs": [
      {"type": "address", "name": "player"},
      {"type": "uint256", "name": "amount"}
    ],
    "name": "handleInitialBet",
    "outputs": [],
    "stateMutability": "payable",
    "type": "function"
  },
  {
    "inputs": [
      {"type": "address", "name": "player"},
      {"type": "uint256", "name": "amount"}
    ],
    "name": "subtractBalance",
    "outputs": [],
    "stateMutability": "nonpayable",
    "type": "function"
  }
];

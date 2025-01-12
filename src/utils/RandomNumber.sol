// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
// import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";

// contract RandomNumber is VRFConsumerBaseV2 {
//     VRFCoordinatorV2Interface private immutable COORDINATOR;
    
//     // Sepolia configurations
//     address private constant COORDINATOR_ADDRESS = 0x8103B0A8A00be2DDC778e6e7eaa21791Cd364625;
//     bytes32 private constant KEY_HASH = 0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c;
    
//     uint64 private immutable s_subscriptionId;
//     uint32 private constant CALLBACK_GAS_LIMIT = 100000;
//     uint16 private constant REQUEST_CONFIRMATIONS = 3;
//     uint32 private constant NUM_WORDS = 1;

//     uint256 private s_randomResult;
//     uint256 private s_requestId;
//     address private immutable s_owner;

//     event RandomNumberRequested(uint256 indexed requestId);
//     event RandomNumberFulfilled(uint256 indexed requestId, uint256 randomNumber);

//     constructor(uint64 subscriptionId) VRFConsumerBaseV2(COORDINATOR_ADDRESS) {
//         COORDINATOR = VRFCoordinatorV2Interface(COORDINATOR_ADDRESS);
//         s_subscriptionId = subscriptionId;
//         s_owner = msg.sender;
//     }

//     function requestRandomNumber() external returns (uint256) {
//         s_requestId = COORDINATOR.requestRandomWords(
//             KEY_HASH,
//             s_subscriptionId,
//             REQUEST_CONFIRMATIONS,
//             CALLBACK_GAS_LIMIT,
//             NUM_WORDS
//         );
//         emit RandomNumberRequested(s_requestId);
//         return s_requestId;
//     }

//     function fulfillRandomWords(uint256 requestId, uint256[] memory randomWords) internal override {
//         s_randomResult = randomWords[0] % 37; // For roulette: 0-36
//         emit RandomNumberFulfilled(requestId, s_randomResult);
//     }

//     function getLatestRandomResult() external view returns (uint256) {
//         return s_randomResult;
//     }
// }
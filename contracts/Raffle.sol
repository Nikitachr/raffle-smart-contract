// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
import "@chainlink/contracts/src/v0.8/interfaces/KeeperCompatibleInterface.sol";

    error Raffle__UpkeepNotNeeded(uint256 currentBalance, uint256 numPlayers, uint256 raffleState);
    error Raffle__TransferFailed();
    error Raffle__SendMoreToEnterRaffle();
    error Raffle__RaffleNotOpen();

contract Raffle is VRFConsumerBaseV2, KeeperCompatibleInterface, Ownable {

    enum RaffleState {
        OPEN,
        CALCULATING,
        CLOSED
    }

    VRFCoordinatorV2Interface private immutable i_vrfCoordinator;
    uint64 private immutable i_subscriptionId;
    bytes32 private immutable i_gasLane;
    uint32 private immutable i_callbackGasLimit;
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private constant NUM_WORDS = 1;

    uint256 private immutable i_interval;
    uint256 private s_lastTimeStamp;
    address payable[] private s_players;
    uint256 private immutable i_entryFee;
    uint256 private s_gameId;
    address private s_recentWinner;
    uint256 private s_totalBalance;
    mapping(address => uint256) private s_depositedBalance;
    RaffleState private s_raffleState;

    event GameStarted(uint256 gameId, uint256 interval);
    event PlayerJoined(address player, uint256 totalPlayers);
    event GameCalculating();
    event PlayerAddedBalance(uint256 gameId, address player, uint256 addedBalance, uint256 currentBalance, uint256 totalBalance);
    event GameEnded(uint256 gameId, address winner, uint256 amount);

    constructor(
        address vrfCoordinatorV2,
        uint64 subscriptionId,
        bytes32 keyHash,
        uint256 interval,
        uint32 callbackGasLimit)
    VRFConsumerBaseV2(vrfCoordinatorV2) {
        i_vrfCoordinator = VRFCoordinatorV2Interface(vrfCoordinatorV2);
        i_gasLane = keyHash;
        i_interval = interval;
        i_subscriptionId = subscriptionId;
        i_entryFee = 0.1 ether;
        s_raffleState = RaffleState.CLOSED;
        i_callbackGasLimit = callbackGasLimit;
    }

    function startNewGame() public onlyOwner {
        require(s_raffleState != RaffleState.OPEN, "Game is currently running");
        delete s_players;
        s_raffleState = RaffleState.OPEN;
        s_totalBalance = 0;
        s_gameId += 1;
        emit GameStarted(s_gameId, i_interval);
    }

    function addBalance() public payable {
        require(s_raffleState == RaffleState.OPEN, "Game has not been started yet");
        require(msg.value > i_entryFee, "Value sent is less then fee");
        uint256 balanceWithoutFee = msg.value - i_entryFee;

        if (!(s_depositedBalance[msg.sender] > 0)) {
         s_players.push(payable(msg.sender));
            emit PlayerJoined(msg.sender, s_players.length);
        }
        s_depositedBalance[msg.sender] += balanceWithoutFee;
        s_totalBalance += balanceWithoutFee;
        if (s_players.length == 2) {
            s_lastTimeStamp = block.timestamp;
        }
        emit PlayerAddedBalance(s_gameId, msg.sender, balanceWithoutFee, s_depositedBalance[msg.sender], s_totalBalance);
    }

    function checkUpkeep(
        bytes memory
    )
    public
    view
    override
    returns (
        bool upkeepNeeded,
        bytes memory
    )
    {   bool atLeastTwoPlayers = s_players.length >= 2;
        bool isOpen = s_raffleState == RaffleState.OPEN;
        bool timePassed = ((block.timestamp - s_lastTimeStamp) > i_interval);
        bool hasBalance = s_totalBalance > 0;
        upkeepNeeded = (timePassed && isOpen && hasBalance && atLeastTwoPlayers);
        return (upkeepNeeded, "0x0");
    }

    function performUpkeep(
        bytes calldata
    ) external override {
        (bool upkeepNeeded, ) = checkUpkeep("");
        if (!upkeepNeeded) {
            revert Raffle__UpkeepNotNeeded(
                address(this).balance,
                s_players.length,
                uint256(s_raffleState)
            );
        }
        s_raffleState = RaffleState.CALCULATING;
        uint256 requestId = i_vrfCoordinator.requestRandomWords(
            i_gasLane,
            i_subscriptionId,
            REQUEST_CONFIRMATIONS,
            i_callbackGasLimit,
            NUM_WORDS
        );
        emit GameCalculating();
    }

    function fulfillRandomWords(uint256 requestId, uint256[] memory randomWords) internal override  {
        uint256 random = randomWords[0] % s_totalBalance;
        uint256 sum = 0;
        address payable winner;
        for (uint i = 0; i < s_players.length; i++) {
            sum += s_depositedBalance[s_players[i]];
            if (random <= sum) {
                winner = payable(s_players[i]);
            }
            delete s_depositedBalance[s_players[i]];
        }
        (bool sent,) = winner.call{value: s_totalBalance}("");
        require(sent, "Failed to send Ether");
        emit GameEnded(s_gameId, winner, s_totalBalance);
        s_recentWinner = winner;
        s_raffleState = RaffleState.CLOSED;
    }

    function withdraw() external onlyOwner {
        require(s_raffleState == RaffleState.CLOSED, "game is started");
        (bool sent,) = msg.sender.call{value: s_totalBalance}("");
        require(sent, "Failed to send Ether");
    }

    receive() external payable {}

    fallback() external payable {}

    function getEntryFee() external view returns(uint256) {
        return i_entryFee;
    }

    function getDepositedBalance() external view returns(uint256) {
        return s_depositedBalance[msg.sender];
    }

    function getTotalBalance() external view returns(uint256) {
        return s_totalBalance;
    }

    function getLastWinner() external view returns(address) {
        return s_recentWinner;
    }

    function getLastTimeStamp() external view returns(uint256) {
        return s_lastTimeStamp + i_interval - block.timestamp;
    }

    function getRaffleState() external view returns(RaffleState) {
        return s_raffleState;
    }

    function getTotalPlayers() external view returns(uint256) {
        return s_players.length;
    }

    function getContractBalance() external view onlyOwner returns(uint256) {
        return address(this).balance - s_totalBalance;
    }
}

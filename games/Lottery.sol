pragma solidity ^0.5.4;

import "./../lib/SafeMath.sol";
import "./../token/ITRC20.sol";
import "./../core/TRC20Holder.sol";
import "./../core/TRC20List.sol";
import "./../lib/Pausable.sol";
import "../core/Sender.sol";

contract Lottery is Sender {
    using SafeMath for *;

    // this event triggered when a ticket sold
    event TicketBuy(
        address indexed player,
        uint256 indexed roundId,
        bytes32 indexed ticketHash,
        uint256[5] numbers,
        uint256 totalTickets
    );

    // triggered every week
    event Drawn(
        uint256 indexed roundId,
        uint256 indexed winnerLength,
        bytes32 indexed winnerHash,
        uint256 amount,
        uint256[5] numbers,
        address payable[] winners,
        uint256[] amountsTRC20
    );

    event BlockNumber(uint256 indexed roundId, uint256 indexed blockNumber);

    event FailedPrizeTransfer(
        uint256 indexed roundId,
        uint256 indexed prize,
        address indexed player
    );

    event SetHash(
        uint256 indexed roundId,
        uint256 indexed blockNumber,
        string blockHash
    );

    // this is round ID of the lottery
    // increased every week
    uint256 public currentRoundId = 0;
    // current round
    // Round public currentRound;
    // all rounds
    Round[] public rounds;
    // if lottery cant find a winner, balance will transfer to next week
    // this shows how many weeks since last win
    uint256 public transferredWeeks;
    // last draw date based on block time
    uint256 private lastDrawAt;

    // TODO: delete this
    Round public currentRound;

    address private winrContract;
    address private routerContract;

    uint256 gasForTransferTRX = 3000;

    function setGasForTRXTransfer(uint256 _gasForTransferAmount)
        external
        onlyOwner
    {
        gasForTransferTRX = _gasForTransferAmount;
    }

    // ticket struct
    struct Ticket {
        address payable[] playersArray;
        mapping(address => bool) playersMapping;
        uint256[5] numbers;
    }

    struct Round {
        uint256 roundId;
        uint256 totalTicketCount;
        uint256 blockNumber;
        bool transferred;
        // this used for creating random
        string bitcoinBlockHash;
        uint256[5] randoms;
        address payable[] players;
        address payable[] winners;
        // this holds player's tickets.
        // players can buy multiple ticket in one week
        // ticket hash -> Ticket
        mapping(bytes32 => Ticket) tickets;
        //player -> ticket hash
        mapping(address => bytes32[]) playersToTickets;
        // uint256[5] winnerNumbers;
    }

    constructor(address _winrContract, address _routerContract) public {
        winrContract = _winrContract;
        routerContract = _routerContract;
        transferredWeeks = 0;
        lastDrawAt = now;
        //initialize first round
        rounds.push(
            Round(
                0,
                0,
                0,
                false,
                "",
                [uint256(0), 0, 0, 0, 0],
                new address payable[](0),
                new address payable[](0)
            )
        );
        // TODO: delete this
        currentRound = rounds[currentRoundId];
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function getWinrContract() public view returns (address) {
        return winrContract;
    }

    function getCurrentTicketsNumber(address _player)
        public
        view
        returns (uint256)
    {
        return rounds[currentRoundId].playersToTickets[_player].length;
    }

    function getCurrentTicket(address _player, uint256 _ticketIndex)
        public
        view
        returns (
            uint256[5] memory,
            bytes32,
            uint256
        )
    {
        bytes32 ticketHash = rounds[currentRoundId]
            .playersToTickets[_player][_ticketIndex];
        return (
            rounds[currentRoundId].tickets[ticketHash].numbers,
            ticketHash,
            rounds[currentRoundId].roundId
        );
    }

    function getTicketsNumber(address _player, uint256 _roundId)
        public
        view
        returns (uint256)
    {
        return rounds[_roundId].playersToTickets[_player].length;
    }

    function getTicket(
        address _player,
        uint256 _roundId,
        uint256 _ticketIndex
    )
        public
        view
        returns (
            uint256[5] memory,
            bytes32,
            uint256
        )
    {
        bytes32 ticketHash = rounds[_roundId]
            .playersToTickets[_player][_ticketIndex];
        return (
            rounds[_roundId].tickets[ticketHash].numbers,
            ticketHash,
            rounds[_roundId].roundId
        );
    }

    function getCurrentRound()
        public
        view
        returns (
            uint256,
            uint256,
            address payable[] memory,
            uint256,
            uint256[5] memory,
            string memory,
            address payable[] memory,
            bool
        )
    {
        return (
            rounds[currentRoundId].roundId,
            rounds[currentRoundId].totalTicketCount,
            rounds[currentRoundId].players,
            rounds[currentRoundId].blockNumber,
            rounds[currentRoundId].randoms,
            rounds[currentRoundId].bitcoinBlockHash,
            rounds[currentRoundId].winners,
            rounds[currentRoundId].transferred
        );
    }

    function getRoundById(uint256 _roundId)
        public
        view
        returns (
            uint256,
            uint256,
            address payable[] memory,
            uint256,
            uint256[5] memory,
            string memory,
            address payable[] memory,
            bool
        )
    {
        Round memory round = rounds[_roundId];
        return (
            round.roundId,
            round.totalTicketCount,
            round.players,
            round.blockNumber,
            round.randoms,
            round.bitcoinBlockHash,
            round.winners,
            round.transferred
        );
    }

    function changeWinrContract(address _contract) external onlyOwner {
        winrContract = _contract;
    }

    function getRouterContract() public view returns (address) {
        return routerContract;
    }

    function changeRouterContract(address _contract) external onlyOwner {
        routerContract = _contract;
    }

    function getLastDrawTime() public view returns (uint256 lastDrawTime) {
        lastDrawTime = lastDrawAt;
    }

    // function random() private view returns (uint256) {
    //     return
    //         uint256(
    //             keccak256(abi.encodePacked(block.difficulty, now, players))
    //         );
    // }

    // this function must be triggerred from winr contract
    function buy(uint256[5] calldata _numbers, address payable player)
        external
        whenNotPaused
    {
        require(
            rounds[currentRoundId].blockNumber == 0,
            "Ticket sales are over for this round"
        );
        require(
            msg.sender == winrContract,
            "Only winr contract can send buy request"
        );

        // we are gettin ticket hash
        // numbers must be ordered ascended
        // so we are ordering them in our frontend

        bytes32 ticketHash = keccak256(abi.encode(_numbers));
        if (
            rounds[currentRoundId].tickets[ticketHash].playersArray.length == 0
        ) {
            rounds[currentRoundId].tickets[ticketHash].numbers = _numbers;
        } else {
            require(
                !rounds[currentRoundId].tickets[ticketHash]
                    .playersMapping[player],
                "Player can't buy one ticket twice"
            );
        }

        // add player if not exists in round's player array
        if (rounds[currentRoundId].playersToTickets[player].length == 0) {
            rounds[currentRoundId].players.push(player);
        }

        rounds[currentRoundId].tickets[ticketHash].playersArray.push(player);
        rounds[currentRoundId].tickets[ticketHash]
            .playersMapping[player] = true;
        rounds[currentRoundId].playersToTickets[player].push(ticketHash);

        rounds[currentRoundId].totalTicketCount += 1;

        emit TicketBuy(
            player,
            currentRoundId,
            ticketHash,
            _numbers,
            rounds[currentRoundId].totalTicketCount
        );
    }

    /**
     * @dev Set BTC block number to the current round and stop tickets sales
     * @param _blockNumber block number whose hash will be used for generating random numbers
     */
    function setBTCBlockNumber(uint256 _blockNumber) external onlyOwner {
        rounds[currentRoundId].blockNumber = _blockNumber;
        emit BlockNumber(currentRoundId, _blockNumber);
    }

    // ticket numbers are in range [1,ticketNumberRange]
    uint256 public ticketNumberRange = 20;

    function setRange(uint256 _newRange) public {
        ticketNumberRange = _newRange;
    }

    /**
     * @dev Get unsorted array of unique random numbers in range [1,_range] from string which represents bitcoin block hash
     * @param _bitcoinBlockHash block hash which is used for generating random numbers
     * @param _range range which is used for generating random numbers
     */
    function getRandomNumbersFromHash(
        string memory _bitcoinBlockHash,
        uint256 _range
    ) public pure returns (uint256[5] memory numbers) {
        uint256 pointer = 0;
        for (uint256 i = 0; i < 5; i++) {
            bool alreadyExists;
            do {
                alreadyExists = false;
                numbers[i] = getRandomNumberFromHash(
                    _bitcoinBlockHash,
                    _range,
                    pointer
                );
                pointer++;
                // check if number already exists
                for (uint256 j = 0; j < i; j++) {
                    if (numbers[i] == numbers[j]) {
                        alreadyExists = true;
                        break;
                    }
                }
            } while (alreadyExists);
        }
    }

    /**
     * @dev Get random number from hash of the seed string in range [1,_range] and by the pointer. You can get a few different random numbers from seed passing different pointers.
     * @param _seedString seed string which is used for generating random number
     * @param _range range which is used for generating random number
     * @param _pointer pointer which is used for generating random number
     */
    function getRandomNumberFromHash(
        string memory _seedString,
        uint256 _range,
        uint256 _pointer
    ) public pure returns (uint256 number) {
        uint256 random = uint256(
            keccak256(abi.encodePacked(_seedString))
        );
        if (_pointer == 0) {
            number = random.mod(_range).add(1);
        } else {
            number = random.div(_range.mul(_pointer)).mod(_range).add(1);
        }
    }

    /**
     * @dev Calculate random numbers, draw trx to winners and create next round
     * @param _bitcoinBlockHash bitcoin block hash for generating random numbers
     */
    function draw(string calldata _bitcoinBlockHash) external onlyOwner {
        require(
            rounds[currentRoundId].blockNumber != 0,
            "Block number must be set"
        );
        //getting random numbers
        uint256[5] memory randomNumbers;
        //get unsorted array of unique random numbers
        randomNumbers = getRandomNumbersFromHash(
            _bitcoinBlockHash,
            ticketNumberRange
        );
        //sort the array (bubble sort)
        uint256 n = randomNumbers.length;
        for (uint256 i = 0; i < n - 1; i++) {
            for (uint256 j = 0; j < n - i - 1; j++) {
                if (randomNumbers[j] > randomNumbers[j + 1]) {
                    uint256 temp = randomNumbers[j];
                    randomNumbers[j] = randomNumbers[j + 1];
                    randomNumbers[j + 1] = temp;
                }
            }
        }

        rounds[currentRoundId].randoms = randomNumbers;

        rounds[currentRoundId].bitcoinBlockHash = _bitcoinBlockHash;
        emit SetHash(
            currentRoundId,
            rounds[currentRoundId].blockNumber,
            _bitcoinBlockHash
        );

        bytes32 winnerHash;

        winnerHash = keccak256(abi.encode(rounds[currentRoundId].randoms));

        rounds[currentRoundId].winners = rounds[currentRoundId]
            .tickets[winnerHash]
            .playersArray;
        uint256 winnerCount = rounds[currentRoundId].winners.length;
        uint256 totalPrize = address(this).balance;

        TRC20List trc20List = TRC20List(
            TRC20Holder(routerContract).getTRC20List()
        );

        ITRC20[] memory tokens = new ITRC20[](trc20List.getWhiteListSize());

        for (uint256 i = 0; i < tokens.length; i++) {
            tokens[i] = ITRC20(trc20List.getWhiteListAt(i));
        }

        uint256[] memory totalPrizesTRC20 = new uint256[](tokens.length);
        for (uint256 i = 0; i < tokens.length; i++) {
            totalPrizesTRC20[i] = tokens[i].balanceOf(address(this));
        }

        emit Drawn(
            currentRoundId,
            rounds[currentRoundId].winners.length,
            winnerHash,
            totalPrize,
            rounds[currentRoundId].randoms,
            rounds[currentRoundId].winners,
            totalPrizesTRC20
        );

        if (winnerCount > 0) {
            uint256 prize = address(this).balance.div(winnerCount);
            if (prize > 0) {
                for (uint256 k = 0; k < winnerCount; k++) {
                    (bool success, ) = rounds[currentRoundId].winners[k]
                        .call
                        .value(prize)
                        .gas(gasForTransferTRX)("");
                    if (!success) {
                        emit FailedPrizeTransfer(
                            currentRoundId,
                            prize,
                            rounds[currentRoundId].winners[k]
                        );
                    }
                }
            }

            //initialize tokens prizes array
            for (uint256 i = 0; i < tokens.length; i++) {
                uint256 prizeTRC20 = totalPrizesTRC20[i].div(winnerCount);
                if (prizeTRC20 > 0) {
                    for (uint256 k = 0; k < winnerCount; k++) {
                        tokens[i].transfer(
                            rounds[currentRoundId].winners[k],
                            prizeTRC20
                        );
                    }
                }
            }
            transferredWeeks = 0;
        } else {
            rounds[currentRoundId].transferred = true;
            transferredWeeks += 1;
        }

        currentRoundId++;
        rounds.push(
            Round(
                currentRoundId,
                0,
                0,
                false,
                "",
                [uint256(0), 0, 0, 0, 0],
                new address payable[](0),
                new address payable[](0)
            )
        );
        // TODO: delete this
        currentRound = rounds[currentRoundId];
        lastDrawAt = now;
    }

    function() external payable {}
}

pragma solidity ^0.5.4;

import "./Randomizer.sol";
import "./../lib/SafeMath.sol";


contract Game is Randomizer {
    using SafeMath for *;

    uint256 betFuncVarCount;
    address public treasure;
    // game stats
    uint256 public totalPlayed;
    uint256 public totalWagered;
    uint256 public totalWon;
    // house edge for game
    uint256 public houseEdge;
    // random number generation range ( 1 - 100 for dice)
    uint256 public gameRange;
    // TODO: this is temp.
    uint256 public maxWinAsPercent;
    // Option Count i.e. over - under or red - blue - black
    uint256 public optionCount;
    // Parameter count of bet function
    uint256 public parameterCount;
    enum Status {WIN, LOSE, REFUND}

    event Refund(address indexed player, uint256 indexed gameId);

    // event Result(address indexed player, uint indexed gameId, bool result, uint roll, uint var1, uint var2, uint var3);

    constructor() public {
        // TODO: this will be JUST.BET Treasure contract address
        treasure = msg.sender;
        totalWagered = 0;
        totalPlayed = 0;
        totalWon = 0;
    }

    modifier onlyRouter() {
        require(msg.sender == treasure, "Only Just.Bet contract can do this.");
        _;
    }
}

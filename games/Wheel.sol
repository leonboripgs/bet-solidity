pragma solidity ^0.5.4;

import "../core/Game.sol";
import "../lib/SafeMath.sol";


contract Wheel is Game {
    using SafeMath for *;

    uint256 public lastPlayTime = 0;
    uint256 public delay = 30; // seconds
    uint256 timeForResults = 5;
    uint256 public lastRound = 0;
    uint256 public id = 1;
    address routerAddr;
    Round public activeRound;
    event Bet(
        address indexed player,
        uint256 indexed gameId,
        uint256 choice,
        uint256 wager
    );
    event Spin(
        uint256 indexed id,
        uint256 indexed color,
        uint256 nextGameAt,
        uint256 roll
    );
    event Result(uint256 indexed id, address[] players, uint256[] revenues);

    uint256[] grayBetsArr;
    uint256[] redBetsArr;
    uint256[] greenBetsArr;
    uint256[55] numberArr;
    uint256 blueBet = 6;

    struct Round {
        uint256 id;
        address[] blueBetOwners;
        uint256[] blueBetRevenues;
        address[] grayBetOwners;
        uint256[] grayBetRevenues;
        address[] greenBetOwners;
        uint256[] greenBetRevenues;
        address[] redBetOwners;
        uint256[] redBetRevenues;
        uint256 seed;
        uint256 roll;
    }

    struct Number {
        uint8 color;
    }

    struct Option {
        address player;
        uint256 wager;
    }

    constructor(address _router) public {
        routerAddr = _router;
        houseEdge = 2;
        gameRange = 100;
        // heads - tails
        optionCount = 2;
        //TODO::this is temporary
        maxWinAsPercent = 100;
        betFuncVarCount = 2;
        parameterCount = 1;
        uint256 grayLength = grayBetsArr.length;
        uint256 greenLength = greenBetsArr.length;
        uint256 redLength = redBetsArr.length;
        for (uint256 i = 0; i < grayLength; i++) {
            numberArr[grayBetsArr[i]] = 0;
            if (i < greenLength) numberArr[greenBetsArr[i]] = 1;
            if (i < redLength) numberArr[redBetsArr[i]] = 2;
        }
        numberArr[6] = 3;
        lastPlayTime = now;
    }

    function fund() public payable {}

    modifier userChoiceVerifier(uint256 choice) {
        require(
            choice == 0 || choice == 1 || choice == 2 || choice == 3,
            "You can bet only 0, 1, 2, 3"
        );
        _;
    }

    modifier onlyRouter() {
        require(msg.sender == routerAddr, "Only Router");
        _;
    }

    modifier timeCheck(bool bt) {
        if (bt) require(lastPlayTime + delay > now, "You need some time buddy");
        else
            require(
                lastPlayTime + delay + timeForResults <= now,
                "Wait for new round"
            );
        _;
    }

    function roll()
        public
        timeCheck(false)
        returns (uint256[] memory revenues, address[] memory players)
    {
        uint256 rand = getRandom(54, activeRound.seed) + 1;
        uint256 color = numberArr[rand];
        lastPlayTime = now;
        emit Spin(id, color, (lastPlayTime + delay), rand);

        id++;
        if (color == 0) {
            revenues = activeRound.grayBetRevenues;
            players = activeRound.grayBetOwners;
        } else if (color == 1) {
            revenues = activeRound.greenBetRevenues;
            players = activeRound.greenBetOwners;
        } else if (color == 2) {
            revenues = activeRound.redBetRevenues;
            players = activeRound.redBetOwners;
        } else if (color == 3) {
            revenues = activeRound.blueBetRevenues;
            players = activeRound.blueBetOwners;
        }
        emit Result(activeRound.id, players, revenues);
        delete activeRound;
    }

    function bet(
        address sender,
        uint256 val,
        uint256 choice,
        uint256 seed
    ) public timeCheck(true) returns (bool result) {
        if (choice == 0) {
            activeRound.grayBetOwners.push(sender);
            activeRound.grayBetRevenues.push(val * 2);
        } else if (choice == 1) {
            activeRound.greenBetOwners.push(sender);
            activeRound.greenBetRevenues.push(val * 3);
        } else if (choice == 2) {
            activeRound.redBetOwners.push(sender);
            activeRound.redBetRevenues.push(val * 5);
        } else if (choice == 3) {
            activeRound.blueBetOwners.push(sender);
            activeRound.blueBetRevenues.push(val * 50);
        }
        activeRound.seed = activeRound.seed + seed + now;

        emit Bet(sender, activeRound.id, choice, val);

        result = true;
    }

    function getBetOwners()
        public
        view
        returns (
            address[] memory blueOwners,
            address[] memory redOwners,
            address[] memory greenOwners,
            address[] memory grayOwners
        )
    {
        return (
            activeRound.blueBetOwners,
            activeRound.redBetOwners,
            activeRound.greenBetOwners,
            activeRound.grayBetOwners
        );
    }

    function getBetRevenues()
        public
        view
        returns (
            uint256[] memory blueRevenues,
            uint256[] memory redRevenues,
            uint256[] memory greenRevenues,
            uint256[] memory grayRevenues
        )
    {
        return (
            activeRound.blueBetRevenues,
            activeRound.redBetRevenues,
            activeRound.greenBetRevenues,
            activeRound.grayBetRevenues
        );
    }

    function delayAndLastGame()
        public
        view
        returns (uint256 delayTime, uint256 lastGameAt)
    {
        delayTime = delay;
        lastGameAt = lastPlayTime;
    }
}

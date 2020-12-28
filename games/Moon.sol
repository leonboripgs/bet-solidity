pragma solidity ^0.5.4;
pragma experimental ABIEncoderV2;

import "../core/Game.sol";
import "../lib/SafeMath.sol";
import "../core/IRouter.sol";


contract Moon is Game {
    using SafeMath for *;

    event Fire(
        uint256 indexed gameId,
        uint256 wagerStartAt,
        uint256 beginAt,
        string resultHashLastChars
    );
    event Bet(
        address indexed player,
        uint256 indexed gameId,
        uint256 choice,
        uint256 wager
    );
    event Land(
        uint256 indexed gameId,
        uint256 beginAt,
        uint256 endAt,
        uint256 result
    );
    event Result(uint256 indexed gameId, address[] players, uint256[] revenues);

    uint256 public delay = 20;
    uint256 public id = 0;
    address admin;
    uint256[1000] seeds;
    address router;

    Round private activeRound;

    struct UserBet {
        address addr;
        uint256 wager;
        uint256 multiplier;
    }

    struct Round {
        uint256 id;
        UserBet[] bets;
        uint256 wagerStartAt;
        uint256 beginAt;
        uint256 endAt;
        uint256 result;
        uint256 seed;
        string resultHashLastChars;
        bool playable;
    }

    constructor(address _router) public {
        houseEdge = 2;
        gameRange = 100;
        // heads - tails
        optionCount = 2;
        //TODO::this is temporary
        maxWinAsPercent = 100;
        betFuncVarCount = 2;
        parameterCount = 1;
        admin = msg.sender;
        router = _router;
    }

    modifier onlyAdmin() {
        require(msg.sender == admin, "admin only");
        _;
    }

    modifier onlyRouter() {
        require(msg.sender == router, "Only Router");
        _;
    }

    function changeAdmin(address addr) public onlyAdmin {
        admin = addr;
    }

    function startTheEngines(string memory resultHashLastChars)
        public
        returns (uint256[] memory revenues, address[] memory players)
    {
        require(activeRound.wagerStartAt == 0, "Need time");
        activeRound.id = id + 1;
        // start round after 4 seconds
        activeRound.wagerStartAt = now + 4;
        // game begin after 4 secs after wager period ends
        activeRound.beginAt = activeRound.wagerStartAt + delay + 4;
        activeRound.resultHashLastChars = resultHashLastChars;
        activeRound.playable = true;
        emit Fire(
            activeRound.id,
            activeRound.wagerStartAt,
            activeRound.beginAt,
            resultHashLastChars
        );
    }

    function mixTheSeed(uint256 seed) public returns (uint256 currentSeed) {
        activeRound.seed += seed;
        currentSeed = activeRound.seed;
    }

    function land(
        address[] memory players,
        uint256[] memory revenues,
        uint256 endAt,
        uint256 result
    ) public onlyAdmin {
        require(
            activeRound.beginAt < now && activeRound.beginAt != 0,
            "A- Error"
        );
        IRouter(router).callByGame(players, revenues);
        emit Land(activeRound.id, activeRound.beginAt, endAt, result);
        emit Result(activeRound.id, players, revenues);
        id = activeRound.id;
        delete activeRound;
    }

    function bet(
        address sender,
        uint256 val,
        uint256 choice,
        uint256 seed
    ) public returns (bool result) {
        require(
            activeRound.wagerStartAt <= now &&
                now < activeRound.wagerStartAt + delay,
            "Need time"
        );
        require(activeRound.playable, "Game not playable");
        emit Bet(sender, activeRound.id, choice, val);
        // id++;

        UserBet memory ub;
        ub.addr = sender;
        ub.wager += val;
        ub.multiplier = choice;
        activeRound.seed += seed + now;
        activeRound.bets.push(ub);

        result = true;
    }

    function getActiveRound()
        public
        view
        returns (
            uint256 id,
            UserBet[] memory bets,
            uint256 wagerStartAt,
            uint256 beginAt,
            bool playable,
            uint256 ts
        )
    {
        id = activeRound.id;
        bets = activeRound.bets;
        wagerStartAt = activeRound.wagerStartAt;
        beginAt = activeRound.beginAt;
        playable = activeRound.playable;
        ts = now;
    }
}

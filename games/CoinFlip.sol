pragma solidity ^0.5.4;

import "../lib/SafeMath.sol";
import "../lib/OwnedByRouter.sol";
import "../core/Limit.sol";
import "../core/TRC20Holder.sol";
import "../core/IRouter.sol";

contract CoinFlip is TRC20Holder, Limit, OwnedByRouter {
    using SafeMath for *;
    event Result(
        address indexed player,
        uint256 indexed gameId,
        bool result,
        uint256 side,
        uint256 roll,
        uint256 wager,
        uint256 prize
    );
    event ResultTRC20(
        address indexed player,
        uint256 indexed gameId,
        bool result,
        uint256 side,
        uint256 roll,
        uint256 wager,
        uint256 prize,
        address token
    );

    uint256 public houseEdge;
    uint256 public gameRange;
    uint256 public gameId;

    constructor(address payable _routerContract) public {
        houseEdge = 200;
        gameRange = 10000;
        // heads - tails
        //TODO::this is temporary
        // maxWinAsPercent = 100;
        // betFuncVarCount = 2;
        // parameterCount = 1;
        routerContract = _routerContract;
        gameId = 0;
    }

    function emitResult(
        address player,
        uint256 gameId,
        bool result,
        uint256 side,
        uint256 roll,
        uint256 wager,
        uint256 prize,
        address token
    ) internal {
        if (token == address(0)) {
            emit Result(player, gameId, result, side, roll, wager, prize);
        } else {
            emit ResultTRC20(player, gameId, result, side, roll, wager, prize, token);
        }
    }

    function processFlip(uint256 seed, uint256 side, address ref, address token, uint256 wager)
    internal
    returns (uint256)
    {
        uint256 roll = getRandom(gameRange, seed);
        uint256 res = 0;
        bool win = false;
        uint256 prize = 0;
        gameId++;
        // this means: if user played side 0, he / she must roll under 50
        // but when we say 50 its 100 / 2 and house edge not included
        // the real limit (gameRange) is not 100, its 100 - house edge.
        // so for a win, roll must be < (100 - 2) / 2 = 49
        // same thing with side 1 but this time roll must be higher than 51
        if (
            ((gameRange - houseEdge) / 2 < roll && side == 0) ||
            ((gameRange + houseEdge) / 2 > roll && side == 1)
        ) {
            res = side;
            prize = wager.mul(gameRange.sub(houseEdge)).mul(gameRange).div(5000).div(gameRange);
            win = true;
        } else {
            // this is losing result.
            // if side 1, result 0
            // if side 0, result 1
            res = 1 - side;
        }
        IRouter(routerContract).processGameResult(win, token, wager, prize, msg.sender, ref);
        emitResult(msg.sender, gameId, win, side, roll, wager, prize, token);
        return res;
    }

    function Flip(uint256 seed, uint256 side, address ref)
    external
    payable
    betInLimits
    returns (uint256)
    {
        require(side == 0 || side == 1, "Side not 0 or 1");
        require(msg.tokenid == 0 && msg.value > 0, "Require only TRX and balance not zero");
        routerContract.transfer(msg.value);
        return processFlip(seed, side, ref, address(0), msg.value);
    }

    function FlipTRC20(uint256 seed, uint256 side, address ref, address token, uint256 amount)
    external
    betInLimitsTRC20(token, amount)
    returns (uint256)
    {
        require(side == 0 || side == 1, "Side not 0 or 1");
        getTokens(token, amount);
        withdrawToken(routerContract, token, amount);
        return processFlip(seed, side, ref, token, amount);
    }

    function getRandom(uint256 gamerange, uint256 seed)
    internal
    returns (uint256)
    {
        return
        uint256(
            keccak256(
                abi.encodePacked(
                    now +
                    block.difficulty +
                    uint256(
                        keccak256(abi.encodePacked(block.coinbase))
                    ) +
                    seed
                )
            )
        ) % gamerange;
    }
}

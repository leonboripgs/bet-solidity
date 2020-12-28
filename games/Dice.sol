pragma solidity ^0.5.4;

import "../lib/SafeMath.sol";
import "../lib/OwnedByRouter.sol";
import "../core/Limit.sol";
import "../core/TRC20Holder.sol";
import "../core/TRC20Holder.sol";
import "../core/IRouter.sol";

contract Dice is TRC20Holder, Limit, OwnedByRouter {
    using SafeMath for *;
    // result event of game.
    event Result(address indexed player, uint indexed gameId, bool result, uint roll, uint var1, uint var2, uint wager, uint prize);
    event ResultTRC20(address indexed player, uint indexed gameId, bool result, uint roll, uint var1, uint var2, uint wager, uint prize, address token);

    uint public houseEdge;
    uint public gameRange;
    uint private gameId;

    constructor(address payable _routerContract) public {
        houseEdge = 100;
        gameRange = 10000;
        // heads - tails
        //TODO::this is temporary
        // maxWinAsPercent = 100;
        // betFuncVarCount = 2;
        // parameterCount = 1;
        routerContract = _routerContract;
        gameId = 0;
    }

    function emitResult(address player, uint gameId, bool result, uint roll, uint var1, uint var2, uint wager, uint prize, address token) internal {
        if (token == address(0)) {
            emit Result(player, gameId, result, roll, var1, var2, wager, prize);
        } else {
            emit ResultTRC20(player, gameId, result, roll, var1, var2, wager, prize, token);
        }
    }

    function processGame(
        uint seed,
        uint var1,
        uint var2,
        address ref,
        address token,
        uint256 wager
    ) internal returns (uint) {
        // range is max num - min num
        // e.g. 70 - 20. so if roll between 20 and 70, player winninr.
        uint256 range = var2 - var1;
        // range can be min 100 and max 9900
        // this is player's roll limit that multiplied with 100
        // we are using this because we need decimals
        require(range >= 100 && range <= 9900, "Out of range");
        // increasing gameId
        gameId = gameId.add(1);
        // this is psuedo random, as far as we know, this can be used on tron blockchain
        // because there are validators instead of miners, and because of pos
        // its really hard to manipulate correct block everytime.
        // and if you are gonna use an oracle system,
        // i suggest that use a system to validate games on server
        uint roll = getRandom(gameRange, seed);
        bool win = false;
        uint256 prize = 0;
        // if roll between user limit..
        if (roll <= var2 && roll >= var1) {
            win = true;
            // calculate prize
            prize = wager.mul(gameRange.sub(houseEdge)).mul(gameRange).div(range).div(gameRange);
        }

        IRouter(routerContract).processGameResult(win, token, wager, prize, msg.sender, ref);
        emitResult(msg.sender, gameId, win, roll, var1, var2, wager, prize, token);
        return roll;
    }

    // this function called when player click play button on frontend
    // seed is a random seed, i'm using timestamp
    // var1: min limit
    // var2: max limit
    // ref: for reference system. if ref not empty address (0x00..)
    // we are using this to add player to reference
    function GoodLuck(uint seed, uint var1, uint var2, address ref) public payable betInLimits returns (uint) {
        require(var1 < var2);
        require(msg.tokenid == 0 && msg.value > 0, "Require only TRX and balance not zero");
        routerContract.transfer(msg.value);
        return processGame(seed, var1, var2, ref, address(0), msg.value);
    }

    // this function called when player click play button on frontend
    // seed is a random seed, i'm using timestamp
    // var1: min limit
    // var2: max limit
    // ref: for reference system. if ref not empty address (0x00..)
    // token: address for TRC20
    // amount: wager inTRC20
    // we are using this to add player to reference
    function GoodLuckTRC20(uint seed, uint var1, uint var2, address ref, address token, uint256 amount)
    external
    //    betInLimitsTRC20(token_, amount_)
    returns (uint) {
        require(var1 < var2);
        requireBetInLimitsTRC20(token, amount);
        // todo ref: many args in func, can't add modifier
        getTokens(token, amount);
        withdrawToken(routerContract, token, amount);
        return processGame(seed, var1, var2, ref, token, amount);
    }

    // random function
    function getRandom(uint256 gamerange, uint256 seed) internal returns (uint256) {
        return uint256(keccak256(abi.encodePacked(
                now +
                block.difficulty +
                uint256(
                    keccak256(
                        abi.encodePacked(
                            block.coinbase
                        )
                    )
                ) +
                seed
            ))) % gamerange;
    }
}

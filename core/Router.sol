pragma solidity ^0.5.4;

import "../lib/SafeMath.sol";
import "./TRC20List.sol";
import "./TRC20Holder.sol";
import "./../lib/Pausable.sol";
import "./Sender.sol";

/**
This contract is main contract of our ecosystem
Every game play runs lose or win function
everyday we trigger tick function and that runs winr tick function
and distribute user rewards
user referral system also in this contract
 */

interface IWINR {
    // function setRouterContract(address) external;
    function tick() external payable;

    function mine(
        address to,
        uint256 wager,
        uint256 dailyCoef,
        uint256 totalWagered
    ) external;

    function getMultiplier(address) external view returns (uint8);

    function setTopPlayers(
        address top1,
        address top2,
        address top3
    ) external;

    function setTopPlayersMultipliers(
        uint8 top1multiplier,
        uint8 top2multiplier,
        uint8 top3multiplier
    ) external;

    function getActiveRound()
        external
        view
        returns (
            uint16 allocation,
            uint256 amount,
            uint16 payout,
            uint256 minted
        );
}

contract Router is Sender, TRC20Holder {
    using SafeMath for uint256;

    address payable _winrContract;
    address payable _lotteryContract;
    // last running time of tick function
    uint256 private _lastTick;
    // yesterday
    DailyStats private _yesterday;
    // current day stats
    DailyStats private _today;
    // average stats
    DailyStats private _averageStats;
    // total stats
    DailyStats private _totalStats;
    uint256 private _tickId;

    event Tick(
        uint256 profit,
        uint256 revenue,
        uint256 lose,
        uint256 win,
        uint256 wager,
        uint256 sharedProfit,
        uint256 dailyCoefficient
    );

    // ref
    mapping(address => address payable) public refParent;
    mapping(address => uint256) public playerRefCount;
    //disabled user to parent referral
    mapping(address => address payable) public refDisabledTo;

    // winr
    // mapping(address => uint) private reservedWinr;
    // mapping(address => uint) private lastClaimTime;

    // for top players
    mapping(address => uint256) private lastWagers;
    uint256 public lastTopPlayersRewardDistributionAt;
    uint256 private TOP_PLAYERS_MULTIPLY_TIME = 300; // seconds

    mapping(address => bool) private _games;

    struct DailyStats {
        uint256 profit;
        uint256 revenue;
        uint256 lose;
        uint256 won;
        uint256 sentBack;
        uint256 wagered;
        uint256 sharedProfit;
        uint256 dailyCoefficient;
    }

    event AddReferral(address indexed parent, address indexed child);

    struct Ref {
        address payable parent;
        address payable child;
        uint256 tickId;
    }

    constructor() public {
        _tickId = 0;
        _lastTick = now;
        // WINR(winrContract).setRouterContract(address(this));
        lastTopPlayersRewardDistributionAt = now;
    }

    function() external payable {}

    modifier onceADay(uint256 baseTime) {
        require(now >= baseTime + 1 days, "This function can run once a day");
        _;
    }

    modifier onlyGame() {
        require(isGame(msg.sender), "Game Auth: Only games can do this");
        _;
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function isGame(address addr) public view returns (bool) {
        return _games[addr];
    }

    function addGame(address payable _game) external onlyOwner {
        _games[_game] = true;
        // WINR(_winrContract).addGame(_game);
    }

    function removeGame(address payable _game) external onlyOwner {
        _games[_game] = false;
        // WINR(_winrContract).removeGame(_game);
    }

    function getLastTick() public view returns (uint256 lastTick) {
        lastTick = _lastTick;
    }

    function getAverageStats()
        public
        view
        returns (
            uint256 wager,
            uint256 calculatedProfit,
            uint256 lose,
            uint256 win,
            uint256 revenue
        )
    {
        wager = _averageStats.wagered;
        calculatedProfit = _today.revenue.mul(_today.revenue).div(_averageStats.revenue);
        lose = _averageStats.lose;
        win = _averageStats.won;
        revenue = _averageStats.revenue;
    }

    function getDay()
        public
        view
        returns (
            uint256 wager,
            uint256 lose,
            uint256 win,
            uint256 sentBack,
            uint256 revenue,
            uint256 dailyCoefficient
        )
    {
        wager = _today.wagered;
        lose = _today.lose;
        win = _today.won;
        revenue = _today.revenue;
        sentBack = _today.sentBack;
        dailyCoefficient = _today.dailyCoefficient;
    }

    function getYesterday()
        public
        view
        returns (
            uint256 wager,
            uint256 lose,
            uint256 win,
            uint256 sentBack,
            uint256 revenue,
            uint256 dailyCoefficient
        )
    {
        wager = _yesterday.wagered;
        lose = _yesterday.lose;
        win = _yesterday.won;
        revenue = _yesterday.revenue;
        sentBack = _yesterday.sentBack;
        dailyCoefficient = _yesterday.dailyCoefficient;
    }

    function addReference(address payable _parent, address payable _child)
        internal
        whenNotPaused
        onlyGame
    {
        if (refParent[_child] != address(0)) {
            return;
        }
        if (_parent == _child) {
            return;
        }
        if (refDisabledTo[_child] != address(0)) {
            _parent = refDisabledTo[_child];
            refDisabledTo[_child] = address(0);
        }

        refParent[_child] = _parent;
        playerRefCount[_parent] = playerRefCount[_parent].add(1);
        emit AddReferral(_parent, _child);
    }

    // // this needs to run everyday.
    // // we need to check referrals. because every referral has a limit 90 day
    // // after that referral will not bring earnings
    // functio checkRefs() public onlyOwner {
    //     require(_tickId >= 90, "Day is lower than 90");
    //     uint256 refDay = _tickId.sub(90);
    //     Ref[] memory rfs = refs[refDay];

    //     for (uint256 i = 0; i < rfs.length; i++) {
    //         if (playerRefCount[rfs[i].parent] > 0) {
    //             playerRefCount[rfs[i].parent]--;
    //         }
    //         refParent[rfs[i].child] = address(0);
    //     }
    // }

    function deleteReferences(address[] calldata _children) external onlyOwner {
        for (uint256 i = 0; i < _children.length; i++) {
            address parent = refParent[_children[i]];
            playerRefCount[parent] = playerRefCount[parent].sub(1);
            refParent[_children[i]] = address(0);
            refDisabledTo[_children[i]] = address(0);
        }
    }

    function disableReferences(address[] calldata _children)
        external
        onlyOwner
    {
        for (uint256 i = 0; i < _children.length; i++) {
            address payable parent = refParent[_children[i]];
            playerRefCount[parent]--;
            refParent[_children[i]] = address(0);
            refDisabledTo[_children[i]] = parent;
        }
    }

    // referral multipliers taken from whitepaper. its multiplied by 100
    function refMultiplier(address payable player)
        public
        view
        returns (uint256 multiplier)
    {
        uint256 refCnt = playerRefCount[player];
        multiplier = 100;
        if (refCnt > 25) multiplier = 200;
        else if (refCnt > 20) multiplier = 180;
        else if (refCnt > 15) multiplier = 160;
        else if (refCnt > 10) multiplier = 140;
        else if (refCnt > 5) multiplier = 120;
    }

    function processGameResult(
        bool win,
        address token,
        uint256 wager,
        uint256 reward,
        address payable player,
        address refAddr
    ) public whenNotPaused onlyGame {
        _today.wagered += wager;
        uint256 trxEquivalent = 0; // todo make like in Requirements doc
        if (token == address(0)) {
            trxEquivalent = wager;
            if (win) {
                _today.won = _today.won.add(reward);
                _today.sentBack = _today.sentBack.add(wager);
                player.transfer(reward);
            } else {
                _today.lose = _today.lose.add(wager);
            }
        } else {
            trxEquivalent = whiteList.tokenToSun(token, wager);
            if (win) {
                _today.won = _today.won.add(whiteList.tokenToSun(token, reward));
                withdrawToken(player, token, reward);
            } else {
                _today.lose = _today.lose.add(whiteList.tokenToSun(token, wager));
            }
        }
        trxEquivalent = trxEquivalent.mul(refMultiplier(player)).div(100);
        // reserveWinr(wager, player);
        // mint winr
        IWINR(_winrContract).mine(player, trxEquivalent, getDailyCoef(),_yesterday.wagered);
        // add wager to top players data
        // addToTopPlayers(winrEquivalent, player);
        // add reference if player has not exists in another user's ref list
        addReference(address(uint160(refAddr)), player);
    }

    function getDailyCoef() public view returns (uint256 coef) {
        if (_yesterday.wagered == 0 || _yesterday.revenue == 0) {
            coef = 1;
        } else {
            coef = _yesterday
                .sharedProfit
                .mul(_yesterday.sharedProfit)
                .mul(_yesterday.sentBack)
                .div(_yesterday.wagered)
                .div(_yesterday.revenue);
            coef = coef == 0 ? 1 : coef;
        }
    }

    function totalStats() public view returns (uint256, uint256) {
        return (
            (_totalStats.wagered + _today.wagered),
            (_totalStats.won + _today.won)
        );
    }


    function getWinrContract() public view returns (address payable) {
        return _winrContract;
    }

    function setWinrContract(address payable _contract) external onlyOwner {
        _winrContract = _contract;
    }

    function setLottery(address payable _lottery) external onlyOwner {
        _lotteryContract = _lottery;
    }

    // This function running everyday to
    // send trx and tokens to winr and lottery contract
    function distributeProfit(
        uint256 _amount,
        uint256[] calldata _amountsTRC20,
        ITRC20[] calldata _tokens
    ) external onlyOwner {
        // _averageStats.wager = 1025000000000000000;
        // _today.wager = 10000000000000000000;
        // _today.lose = 12050000000000000000;
        if (_today.wagered <= _today.won) _today.revenue = 0;
        else _today.revenue = _today.wagered - _today.won;

        _tickId += 1;
        _totalStats.wagered += _today.wagered;
        _totalStats.won += _today.won;
        _averageStats.wagered += (_today.wagered + _averageStats.wagered) / 2;
        _averageStats.revenue += (_today.revenue + _averageStats.revenue) / 2;

        _lastTick = now;
        // if (_today.revenue != 0) {
        _today.profit = _today.revenue;
        require(
            _amount <= address(this).balance,
            "Can't send more than current contract's balance"
        );
        require(
            _amountsTRC20.length == _tokens.length,
            "tokens amounts list length must be equal to the tokens addresses list length"
        );
        // send 20% of profit to lottery
        address(_lotteryContract).transfer(_amount.mul(2).div(10));
        // send 80% of profit to winr and send day data to calculating
        IWINR(_winrContract).tick.value(_amount.mul(8).div(10))();
        for (uint256 i = 0; i < _tokens.length; i++) {
            _tokens[i].transfer(
                _lotteryContract,
                _amountsTRC20[i].mul(2).div(10)
            );
            _tokens[i].transfer(_winrContract, _amountsTRC20[i].mul(8).div(10));
        }
        // }

        _today.sharedProfit = _amount;

        emit Tick(
            _today.profit,
            _today.revenue,
            _today.lose,
            _today.won,
            _today.wagered,
            _today.sharedProfit,
            _today.dailyCoefficient
        );

        _yesterday = _today;

        _today.wagered = 0;
        _today.profit = 0;
        _today.revenue = 0;
        _today.won = 0;
        _today.lose = 0;
        _today.sharedProfit = 0;

        (, , uint256 roundPayout, ) = IWINR(_winrContract).getActiveRound();
        _today.dailyCoefficient = getDailyCoef().mul(roundPayout).div(_yesterday.wagered).div(1000);
    }

    function setTopPlayers(
        address top1,
        address top2,
        address top3
    ) external onlyOwner {
        IWINR(_winrContract).setTopPlayers(top1, top2, top3);
    }

    function setTopPlayersMultipliers(
        uint8 top1multiplier,
        uint8 top2multiplier,
        uint8 top3multiplier
    ) external onlyOwner {
        IWINR(_winrContract).setTopPlayersMultipliers(
            top1multiplier,
            top2multiplier,
            top3multiplier
        );
    }
}

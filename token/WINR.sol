pragma solidity ^0.5.4;

import "./TRC20.sol";
import "./../lib/SafeMath.sol";
import "./../lib/Pausable.sol";
import "./../lib/OwnedByRouter.sol";
import "./../core/Staking.sol";

interface ILottery {
    function buy(uint256[5] calldata, address payable) external;
}

interface IRouter{
    function getYesterday()
        external
        returns (
            uint256 wager,
            uint256 lose,
            uint256 win,
            uint256 sentBack,
            uint256 revenue,
            uint256 dailyCoefficient
        );
}

/**
Winr contract, extended from staking (TRC20)
*/

contract WINR is OwnedByRouter, Staking {
    event Set(address indexed addr, string indexed addrType);
    event RoundStart(uint256 indexed round, uint256 timestamp);
    event MintingEnd(uint256 date);
    event RewardsDistributed(uint256 amount);

    // shows max supply
    uint256 private maxSupply;
    uint256 private maxMinted;

    address private _lotteryContract;

    mapping(address => VestingData) public vestingData;

    struct VestingData {
        uint256 amount;
        uint256 vestedPeriods;
    }

    uint256 public vestingStartTime;
    uint256 public vestingPeriodsNumber = 6;
    uint256 public vestingPeriod = 90 days; //month
    // uint256 public vestingPeriod = 30; //sec

    uint256 public totalMinted = 0;
    // active round
    uint256 public activeRound;
    // checks if rounds installed
    bool private _roundsInstalled;

    // check if minting finished
    // if minting finished lottery will be activated
    // and every 1 million in lottery balance
    // will distributed through randomly selected rounds like minting
    // but without creating new tokens
    bool private _mintingFinished = false;
    uint256 public _lotteryBalanceMint = 0;

    // Top players storage
    uint256[3] public topPlayersMultiplier = [500, 300, 200];
    address[3] public topPlayers;
    mapping(address => uint8) public topPlayerIndex;

    mapping(address => uint256) public minedToUser;

    Round[] public rounds;

    struct Round {
        // percentage = allocation / 10
        uint16 allocation;
        uint256 amount;
        // real payout = payout / 1000
        uint16 payout;
        uint256 minted;
        uint256 totalBeforeRound;
        bool exists;
    }

    constructor(
        address[] memory _vestingAddresses,
        uint256[] memory _vestingAmounts,
        address[] memory _mintedAddresses,
        uint256[] memory _mintedAmounts,
        uint256 _vestingStartTime
    ) public {
        _roundsInstalled = false;
        require(
            _vestingAddresses.length != 0 && _mintedAddresses.length != 0,
            "Addressess needed"
        );
        require(
            _vestingAddresses.length == _vestingAmounts.length,
            "Vesting addresses and amounts lengths must be equal."
        );
        require(
            _mintedAddresses.length == _mintedAmounts.length,
            "Minted addresses and amounts lengths must be equal."
        );

        maxSupply = 10 * 1e9 * 1e6;
        maxMinted = 6 * 1e9 * 1e6;
        vestingStartTime = _vestingStartTime;
        _lotteryContract = address(0);

        for (uint256 i = 0; i < _mintedAddresses.length; i++) {
            _mint(_mintedAddresses[i], _mintedAmounts[i]);
        }

        for (uint256 i = 0; i < _vestingAddresses.length; i++) {
            vestingData[_vestingAddresses[i]].amount = _vestingAmounts[i];
        }

        installRounds();
        _name = "WINR";
        _symbol = "WINR";
        _decimals = 6;
    }

    function withdrawVested() external returns (uint256 amount) {
        require(
            vestingData[msg.sender].amount > 0,
            "You aren't in the vesting list"
        );

        uint256 vestedPeriods = vestingData[msg.sender].vestedPeriods;

        require(
            vestedPeriods < vestingPeriodsNumber,
            "You vested all your WINRs."
        );

        uint256 periodsToVest = now
            .sub(vestingStartTime)
            .div(vestingPeriod)
            .sub(vestedPeriods);

        require(periodsToVest > 0, "Nothing to vest now");

        if (periodsToVest.add(vestedPeriods) > vestingPeriodsNumber) {
            periodsToVest = vestingPeriodsNumber.sub(vestedPeriods);
        }

        amount = vestingData[msg.sender].amount.mul(periodsToVest).div(
            vestingPeriodsNumber
        );

        vestingData[msg.sender].vestedPeriods = vestedPeriods.add(
            periodsToVest
        );
        _mint(msg.sender, amount);
    }

    function() external payable {}

    function installRounds() public {
        require(!_roundsInstalled, "This function can be executed once");
        addRound(152, 912000000, 5000);
        addRound(133, 798000000, 2500);
        addRound(95, 570000000, 1000);
        addRound(96, 576000000, 1250);
        addRound(48, 288000000, 1000);
        addRound(96, 576000000, 500);
        addRound(95, 570000000, 250);
        addRound(133, 798000000, 125);
        addRound(152, 912000000, 250);
        addRound(0, 0, 0);
        _roundsInstalled = true;
        activeRound = 0;
        // changed 440 * 10**6
    }

    function addRound(
        uint16 allocation,
        uint256 amount,
        uint16 payout
    ) internal {
        Round memory round;
        round.allocation = allocation;
        round.amount = amount * 10**6;
        round.payout = payout;
        round.minted = 0;
        round.exists = true;
        rounds.push(round);
    }

    function getMaxSupply() public view returns (uint256) {
        return maxSupply;
    }

    function getActiveRoundID() public view returns (uint256) {
        return activeRound;
    }

    function getRound(uint256 _roundID)
        public
        view
        returns (
            uint16 allocation,
            uint256 amount,
            uint16 payout,
            uint256 minted
        )
    {
        Round memory rnd = rounds[_roundID];
        return (rnd.allocation, rnd.amount, rnd.payout, rnd.minted);
    }

    function getActiveRound()
        public
        view
        returns (
            uint16 allocation,
            uint256 amount,
            uint16 payout,
            uint256 minted
        )
    {
        return getRound(activeRound);
    }

    // get user multiplier with given index
    // you can get correct index limit with getMultiplierCountOfPlayer function
    function getTopPlayerMultiplier(
        address addr // 5, 3, 2 initially, default = 1
    ) public view returns (uint256) {
        if (topPlayerIndex[addr] != 0) {
            uint256 index = topPlayerIndex[addr];
            if (topPlayers[index] != addr) return 0;
            return topPlayersMultiplier[topPlayerIndex[addr] - 1];
        }
        return 0;
    }

    // add a multiplier to user
    // user can win top player contest etc.
    function setTopPlayers(
        address top1,
        address top2,
        address top3
    ) public onlyRouter {
        topPlayers[0] = top1;
        topPlayerIndex[top1] = 1;
        topPlayers[1] = top2;
        topPlayerIndex[top2] = 2;
        topPlayers[2] = top3;
        topPlayerIndex[top3] = 3;
    }

    function setTopPlayersMultipliers(
        uint8 top1multiplier,
        uint8 top2multiplier,
        uint8 top3multiplier
    ) public onlyRouter {
        topPlayersMultiplier = [top1multiplier, top2multiplier, top3multiplier];
    }

    event MiningData(
        uint256 wager,
        uint256 dailyCoef,
        uint256 payout,
        uint256 value
    );

    function mine(
        address to,
        uint256 wager,
        uint256 dailyCoef,
        uint256 totalWagered
    ) public onlyRouter {
        // GET ACTIVE ROUND
        Round memory round = rounds[activeRound];
        dailyCoef = dailyCoef == 0 ? 1 : dailyCoef;
        totalWagered = totalWagered == 0 ? 1 : totalWagered;
        // get token value to mint
        uint256 tokenValue = wager
            .mul(dailyCoef)
            .mul(round.payout)
            .div(1000)
            .div(totalWagered)
            .add(
                wager
                .mul(getTopPlayerMultiplier(to))
                .div(100)
            );

        emit MiningData(wager, dailyCoef,round.payout,  tokenValue);

        if (_mintingFinished) {
            mineFromLottery(to, tokenValue);
            return;
        }

        uint256 newTotal = totalMinted.add(tokenValue);
        // if new token count more then max supply we add only last tokens
        if (newTotal >= maxMinted){
            tokenValue = maxMinted.sub(totalMinted);
            _mintingFinished = true;
            _mint(to, tokenValue);
            totalMinted = totalMinted.add(tokenValue);
            rounds[activeRound].minted = round.minted.add(
                tokenValue
            );
            emit MintingEnd(now);
            activeRound++;
            return;
        }

        // // mint
        // if (round.minted + tokenValue >= round.amount && activeRound > 7) {
        //     _mintingFinished = true; 
        //     _mint(to, round.amount.sub(round.minted));
        //     rounds[activeRound].minted = round.minted.add(
        //         round.amount.sub(round.minted)
        //     );
        //     emit MintingEnd(now);
        //     activeRound++;
        // }

        _mint(to, tokenValue);
        totalMinted = totalMinted.add(tokenValue);
        minedToUser[to] = minedToUser[to].add(tokenValue);
        rounds[activeRound].minted = round.minted.add(tokenValue);

        // if minted value of round bigger than Amount
        // start new round
        if (round.minted >= round.amount) {
            activeRound++;
            emit RoundStart(activeRound, now);
        }
    }

    function mineFromLottery(address to, uint256 tokenValue) private {
        // distribute lottery balance to users (as a bonus) if minting finished
        uint256 lotteryBalance = balanceOf(_lotteryContract);
        if(tokenValue > lotteryBalance){
            tokenValue = lotteryBalance;
        }
        _transfer(_lotteryContract, to, tokenValue);
        _lotteryBalanceMint += tokenValue;
    }

    function setLotteryContract(address addr) external onlyOwner {
        require(
            _lotteryContract == address(0),
            "This function can be executed only once"
        );
        _lotteryContract = addr;
    }

    function getLotteryContract() public view returns (address) {
        return _lotteryContract;
    }

    function buyLotteryTicket(uint256[5] memory numbers) public whenNotPaused{
        ILottery(_lotteryContract).buy(numbers, msg.sender);
        transfer(_lotteryContract, lotteryTicketPrice());
    }

    function lotteryTicketPrice() public view returns (uint256 price) {
        price = totalSupply() / 1000000000;
    }

    function distributeRewards(
        address[] calldata stakeholders,
        uint256[] calldata amounts
    ) external payable onlyOwner {
        require(msg.tokenid == 0, "Require only TRX");
        require(
            stakeholders.length == amounts.length,
            "Incorrect arrays lengths"
        );
        for (uint256 i = 0; i < stakeholders.length; i++) {
            stakeholders[i].call.value(amounts[i])("");
        }
        emit RewardsDistributed(msg.value);
    }
}

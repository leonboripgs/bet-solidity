pragma solidity ^0.5.4;

import "./TRC20.sol";
import "./../lib/SafeMath.sol";
import "./../core/Randomizer.sol";

/**
 * @title WINR Token
 */
contract WINR is TRC20, Randomizer {

    event Set(address indexed addr, string indexed addrType);
    event RoundStart(uint8 indexed round, uint256 timestamp);
    event MintingEnd(uint date);
    
    uint private constant TICKET_PRICE_DIVIDER = 10000000;
    uint public maxSupply;
    address public routerContract;
    address public developmentTeamOne;
    address public developmentTeamTwo;
    address public seedInvestors;
    address public stakeContract;
    address public lotteryContract;
    uint256 public _forDevsPerRound;
    mapping (address => WinrMultiplier[]) public multipliers;

    string private _name = "WINR";
    string private _symbol = "WINR";
    uint8 private _decimals = 6;
    Round[9] public rounds;

    struct MintRate {
        uint wager;
        uint minted;
    }
    
    struct DayStat {
        uint wager;
        uint win;
        uint lose;
        uint day;
        uint minted;
    }

    struct Round {
        // percentage = allocation / 10
        uint16 allocation;
        uint256 amount;
        // real payout = payout / 100
        uint16 payout;
        uint minted;
        uint mintedForDeveloper;
        uint totalBeforeRound;
    }

    struct WinrMultiplier {
        uint multiplier;
        uint fromDate;
        uint toDate;
    }

    constructor(address _developmentTeamOne, address _developmentTeamTwo, address _seedInvestors, address _router) public {
        require(_developmentTeamOne != address(0) && _developmentTeamTwo != address(0) && _seedInvestors != address(0), "Addressess needed");
        // CHANGED
        maxSupply = 33000000000 * 10 ** 6;
        
        developmentTeamOne = _developmentTeamOne;
        developmentTeamTwo = _developmentTeamTwo;
        seedInvestors = _seedInvestors;
        routerContract = _router;
        /*developmentTeamOne = msg.sender;
        developmentTeamTwo = msg.sender;
        seedInvestors = msg.sender;
        routerContract = msg.sender;*/
        installRounds();
        _mint(developmentTeamOne, maxSupply.mul(12).div(100));
        _mint(seedInvestors, maxSupply.mul(6).div(100));
    }

        /**
     * @return the name of the token.
     */
    function name() public view returns (string memory) {
        return _name;
    }

    /**
     * @return the symbol of the token.
     */
    function symbol() public view returns (string memory) {
        return _symbol;
    }

    /**
     * @return the number of decimals of the token.
     */
    function decimals() public view returns (uint8) {
        return _decimals;
    }
    
    function installRounds() public {
        require(!roundsInstalled, "This functions can be executed only once");
        // changed 2 zero
        addRound(152, 351120000, 1000, 0);
        addRound(133, 307230000, 500, 1);
        addRound(95, 219450000, 200, 2);
        addRound(96, 221760000, 250, 3);
        addRound(48, 110880000, 200, 4);
        addRound(96, 221760000, 100, 5);
        addRound(95, 219450000, 50, 6);
        addRound(133, 307230000, 25, 7);
        addRound(152, 351120000, 50, 8);
        // changed 440 * 10**6
        _forDevsPerRound = 440000000 * 10**6;
        activeRound = 0;
        
        roundsInstalled = true;
    }

    modifier setAddrOnlyOnce(address addr) {
        require(addr == address(0), "This address can set only once");
        _;
    }

    modifier onlyRouter() {
        require(msg.sender == routerContract, "Only router contract can do this");
        _;
    }
    
    function setStakeContract(address _addr) public setAddrOnlyOnce(stakeContract) {
        stakeContract = _addr;
    }
    
    function setLotteryContract(address _addr) public setAddrOnlyOnce(lotteryContract) {
        lotteryContract = _addr;
    }
    
    function addRound(uint16 allocation, uint amount, uint16 payout, uint8 id) internal {
        Round memory round;
        round.allocation = allocation;
        round.amount = amount * 10 ** 6;
        round.payout = payout;
        round.minted = 0;
        for (uint i = 0; i < id; i++) {
            round.totalBeforeRound += rounds[i].amount;
        }

        rounds[id] = round;
    }

    function getMaxSupply() public view returns (uint) {
        return maxSupply;
    }
    
    function mint(address to, uint256 value) public onlyRouter returns (bool) {
        mintedOf[to].minted += value;
        // mint
        baseStats.minted += value;
        allTimes.minted += value;
        _mint(to, value);
        return true;
    }

    function mintMultiplayer(address[] memory addrs, uint[] memory vals) public onlyRouter returns(bool) {
        require(addrs.length == vals.length, "Array length error");

        for (uint i = 0; i < addrs.length; i++) {
            mintPlayer(addrs[i], vals[i]);
        }

        return true;
    }

    function mintPlayer(address to, uint256 value) public onlyRouter returns (bool) {
        if (totalSupply() >= maxSupply || activeRound >= 9) return false;
        // GET ACTIVE ROUND
        Round memory round = rounds[activeRound];
        // get token value to mint
        // changed
        mintedOf[to].wager += value;
        baseStats.wager += value;
        allTimes.wager += value;

        uint tokenValue = value.mul(round.payout) / 100;
        for (uint8 i = 0; i < multipliers[to].length; i++) {
            if (multipliers[to][i].multiplier != 0) {
                if ((multipliers[to][i].fromDate < now && multipliers[to][i].toDate > now)) {
                    tokenValue = tokenValue * multipliers[to][i].multiplier;
                } else {
                    multipliers[to][i] = multipliers[to][multipliers[to].length - 1];
                    multipliers[to].length -= 1;
                }
            }
        }
        uint newTotal = totalSupply().add(tokenValue);
        // if new token count more then max supply we add only last tokens
        if (newTotal > maxSupply)
            tokenValue = maxSupply - totalSupply();

        // mint
        if ( round.minted + tokenValue >= round.amount && activeRound == 8 ) {
            mint(to, round.amount.sub(round.minted));
            rounds[activeRound].minted = round.minted.add(round.amount.sub(round.minted));
            emit MintingEnd(now);
            activeRound++;
            return true;
        }
        mint(to, tokenValue);

        //add minted token count to round
        rounds[activeRound].minted = round.minted.add(tokenValue);

        // if minted value of round bigger than Amount
        // start new round
        if(round.minted >= round.amount) {
            activeRound++;
            emit RoundStart(activeRound, now);
        }

        // start minting for developer
        // we arre minting 440 m for each Round
        if(round.mintedForDeveloper < _forDevsPerRound) {
            _mint(developmentTeamOne, _forDevsPerRound.mul(3).div(4));
            _mint(developmentTeamTwo, _forDevsPerRound.div(4));

            rounds[activeRound].mintedForDeveloper = round.mintedForDeveloper.add(_forDevsPerRound);
        }

        return true;
    }

    function setMultiplier(address addr, uint multiplier, uint dateFrom, uint dateTo) public onlyRouter {
        WinrMultiplier memory mul;
        mul.multiplier = multiplier;
        mul.fromDate = dateFrom;
        mul.toDate = dateTo;
        multipliers[addr].push(mul);
    }

    function setMultiplierMultiple(address[] memory addr, uint[] memory multipliers, uint[] memory dateFrom, uint[] memory dateTo) public onlyRouter {
        for (uint i = 0; i < addr.length; i++) {
            setMultiplier(addr[i], multipliers[i], dateFrom[i], dateTo[i]);
        }
    }
    
    function stake(uint val) public {
        transfer(stakeContract, val);
        IStake(stakeContract).stake(msg.sender, val);
    }
    
    function lotteryTicketPrice() public view returns(uint) {
        return totalSupply() / TICKET_PRICE_DIVIDER;
    }
    
    function tick(uint wager, uint win, uint lose, uint day) public onlyRouter {
        DayStat memory ds = baseStats; 
        stats.push(ds);
        baseStats.wager = wager;
        baseStats.win = win;
        baseStats.lose = lose;
        baseStats.day = day;
        baseStats.minted = 0;
    }

    function getRoundDetails(bool getActiveRound, uint rnd) public view returns(uint, uint, uint, uint) {
        require(rnd < 9);
        Round memory round;
        if (getActiveRound) round = rounds[activeRound];
        else round = rounds[rnd];
        
        return (round.amount, round.minted, round.mintedForDeveloper, round.allocation);
    }
    
    
    function buyLotteryTicket(uint[NUMBER_COUNT] memory numbers) public {
        for (uint8 i = 0; i < NUMBER_COUNT; i++) {
            require(numbers[i] <= LOTTERY_LIMIT && numbers[i] > 0, "Numbers must be lower than Lottery Limit");
        }

        transfer(lotteryContract, lotteryTicketPrice());
        ILottery(lotteryContract).buy(msg.sender, lotteryTicketPrice(), numbers);
    }

    function buyMultipleLotteryTicket(uint count, uint seed) public {
        require(count > 0, "Count must be positive integer");
        require(balanceOf(msg.sender) >= count * lotteryTicketPrice(), "Balance not enough");
        uint[NUMBER_COUNT] memory nmbrs;
        uint seedT = seed;
        bool[21] memory exists;
        for (uint i = 0; i < count; i++) {
            for (uint j = count; j < count + NUMBER_COUNT; j++) {
                nmbrs[j - count] = getRandom(21, seedT % (100 + (i + count) * j));
                if(exists[nmbrs[j - count]]) {
                    j--;
                    seedT++;
                    continue;
                }
                exists[nmbrs[j - count]] = true;
            }
            delete exists;
            buyLotteryTicket(nmbrs);
        }
    }

    function payMultipleLottery(address addr, uint val) public returns(uint) {
        uint valToSend = lotteryTicketPrice() * val;
        require(balanceOf(addr) >= valToSend, "Insuffience Balance");
        _transfer(addr, lotteryContract, valToSend);
        return lotteryTicketPrice();
    }

    function getStats(address user) public view returns(
        uint balance,
        uint active,
        uint mintedRound,
        uint circulation,
        uint totalRound,
        uint userMinted,
        uint userWager,
        uint[2] memory yesterday,
        uint[2] memory lastWeek,
        uint[2] memory all
        ) {
        active = activeRound;
        mintedRound = rounds[activeRound].minted;
        circulation = totalSupply();
        balance = balanceOf(user);
        totalRound = rounds[activeRound].amount;
        userMinted = mintedOf[user].minted;
        userWager = mintedOf[user].wager;
        yesterday = [ stats[stats.length - 1].wager, stats[stats.length - 1].minted];
        uint limit = stats.length >= 7 ? 7 : stats.length;
        for (uint i = 0; i < limit; i++) {
            lastWeek[0] += stats[stats.length - i - 1].wager;
            lastWeek[1] += stats[stats.length - i - 1].minted;
        }

        all = [allTimes.wager, allTimes.minted];
    }

    // function dailyStats() public view returns() {
        
    // }
}
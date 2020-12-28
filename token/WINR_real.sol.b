// pragma solidity ^0.5.4;

// import "./TRC20.sol";
// import "./../lib/SafeMath.sol";
// import "./../core/Randomizer.sol";

// contract IStake {
//     function stake(address, uint) public;
// }

// contract ILottery {
//     function buy(address, uint, uint[5]) public;
// }

// /**
//  * @title WINR Token
//  */
// contract WINR is TRC20, Randomizer {

//     event Set(address indexed addr, string indexed addrType);
//     event RoundStart(uint8 indexed round, uint256 timestamp);
//     event MintingEnd(uint date);
    
//     uint public maxSupply;
//     address public routerContract;
//     uint8 public activeRound;
//     address public developmentTeamOne;
//     address public developmentTeamTwo;
//     address public seedInvestors;
//     address public stakeContract;
//     address public lotteryContract;
//     uint256 public _forDevsPerRound;
//     uint constant public NUMBER_COUNT = 5;
//     uint constant public LOTTERY_LIMIT = 20;
//     GameStat public baseStats;
    
//     bool public roundsInstalled = false;
    
//     Round[9] rounds;
    
//     struct GameStat {
//         uint wager;
//         uint win;
//         uint lose;
//         uint day;
//     }
    
//     struct Round {
//         // percentage = allocation / 10
//         uint16 allocation;
//         uint256 amount;
//         // real payout = payout / 100
//         uint16 payout;
//         uint minted;
//         uint mintedForDeveloper;
//     }
    
//     constructor(address _developmentTeamOne, address _developmentTeamTwo, address _seedInvestors, address _router) public {
//         require(_developmentTeamOne != address(0) && _developmentTeamTwo != address(0) && _seedInvestors != address(0), "Addressess needed");
//         maxSupply = 33 * 10**27;
        
//         developmentTeamOne = _developmentTeamOne;
//         developmentTeamTwo = _developmentTeamTwo;
//         seedInvestors = _seedInvestors;
//         routerContract = _router;
//         /*developmentTeamOne = msg.sender;
//         developmentTeamTwo = msg.sender;
//         seedInvestors = msg.sender;
//         routerContract = msg.sender;*/
        
//         _mint(developmentTeamOne, maxSupply.mul(12).div(100));
//         _mint(seedInvestors, maxSupply.mul(6).div(100));
//     }
    
//     function installRounds() public {
//         require(!roundsInstalled, "This functions can be executed only once");
//         addRound(152, 3511200000, 1000, 0);
//         addRound(133, 3072300000, 500, 1);
//         addRound(95, 2194500000, 200, 2);
//         addRound(96, 2217600000, 250, 3);
//         addRound(48, 1108800000, 200, 4);
//         addRound(96, 2217600000, 100, 5);
//         addRound(95, 2194500000, 50, 6);
//         addRound(133, 3072300000, 25, 7);
//         addRound(152, 3511200000, 50, 8);
//         _forDevsPerRound = 440 * 10**6;
//         activeRound = 0;
        
//         roundsInstalled = true;
//     }

//     modifier setAddrOnlyOnce(address addr) {
//         require(addr == address(0), "This address can set only once");
//         _;
//     }

//     modifier onlyRouter() {
//         require(msg.sender == routerContract, "Only router contract can do this");
//         _;
//     }
    
//     function setStakeContract(address _addr) public setAddrOnlyOnce(stakeContract) {
//         stakeContract = _addr;
//     }
    
//     function setLotteryContract(address _addr) public setAddrOnlyOnce(lotteryContract) {
//         lotteryContract = _addr;
//     }
    
//     function addRound(uint16 allocation, uint amount, uint16 payout, uint8 id) internal {
//         Round memory round;
//         round.allocation = allocation;
//         round.amount = amount * 10**6;
//         round.payout = payout;
//         round.minted = 0;
//         rounds[id] = round;
//     }

//     function getMaxSupply() public view returns (uint) {
//         return maxSupply;
//     }
    
//     function mint(address to, uint256 value) public onlyRouter returns (bool) {
//         require(totalSupply() < maxSupply || activeRound < 9, "Total supply achieved");

//         // mint
//         _mint(to, value);
//         return true;
//     }

//     function mintPlayer(address to, uint256 value) public onlyRouter returns (bool) {
//         require(totalSupply() < maxSupply || activeRound < 9, "Total supply achieved");
//         // get token value to mint
//         uint tokenValue = value.mul(round.payout).div(10000);

//         uint newTotal = totalSupply().add(tokenValue);
//         // if new token count more then max supply we add only last tokens
//         if (newTotal > maxSupply)
//             tokenValue = maxSupply - totalSupply();
        
//         // GET ACTIVE ROUND
//         Round memory round = rounds[activeRound];

//         // mint
//         if ( round.minted + tokenValue >= round.amount && activeRound == 8 ) {
//             _mint(to, round.amount.sub(round.minted));
//             round.minted = round.minted.add(round.amount.sub(round.minted));
//             emit MintingEnd(now);
//             activeRound++;
//             return;
//         }

//         //add minted token count to round
//         round.minted = round.minted.add(tokenValue);

//         // if minted value of round bigger than Amount
//         // start new round
//         if(round.minted >= round.amount) {
//             activeRound++;
//             emit RoundStart(activeRound, now);
//         }

//         // start minting for developer
//         // we arre minting 440 m for each Round
//         if(round.mintedForDeveloper < _forDevsPerRound) {
//             _mint(developmentTeamOne, _forDevsPerRound.mul(3).div(4));
//             _mint(developmentTeamTwo, _forDevsPerRound.div(4));

//             round.mintedForDeveloper = round.mintedForDeveloper.add(_forDevsPerRound);
//         }

//         return true;
//     }
    
//     function stake(uint val) public {
//         transfer(stakeContract, val);
//         IStake(stakeContract).stake(msg.sender, val);
//     }
    
//     function lotteryTicketPrice() public view returns(uint) {
//         return totalSupply() / 1000000;
//     }
    
//     function setBaseStats(uint wager, uint win, uint lose, uint day) public onlyRouter {
//         baseStats.wager = wager;
//         baseStats.win = win;
//         baseStats.lose = lose;
//         baseStats.day = day;
//     }

//     function getRoundDetails(bool getActiveRound, uint rnd) public view returns(uint, uint, uint, uint) {
//         require(rnd < 9);
//         Round memory round;
//         if (getActiveRound) round = rounds[activeRound];
//         else round = rounds[rnd];
        
//         return (round.amount.div(10 ** 6), round.minted.div(10 ** 6), round.mintedForDeveloper.div(10 ** 6), round.allocation);
//     }
    
    
//     function buyLotteryTicket(uint[NUMBER_COUNT] numbers) public {
//         for (uint8 i = 0; i < NUMBER_COUNT; i++) {
//             require(numbers[i] <= LOTTERY_LIMIT && numbers[i] > 0, "Numbers must be lower than Lottery Limit");
//         }

//         transfer(stakeContract, lotteryTicketPrice());
//         ILottery(lotteryContract).buy(msg.sender, lotteryTicketPrice(), numbers);
//     }

//     function buyMultipleLotteryTicket(uint count, uint seed) public {
//         require(count > 0, "Count must be positive integer");
//         require(balanceOf(msg.sender) >= count * lotteryTicketPrice(), "Balance not enough");
//         uint[NUMBER_COUNT] memory nmbrs;
//         bool[21] memory exists;
//         for (uint i = 0; i < count; i++) {
//             for (uint j = count; j < count + NUMBER_COUNT; j++) {
//                 nmbrs[j - count] = getRandom(21, seed % (100 + (i + count) * j));
//                 if(exists[nmbrs[j - count]]) {
//                     j--;
//                     seed++;
//                     continue;
//                 }
//                 exists[nmbrs[j - count]] = true;
//             }
//             delete exists;
//             buyLotteryTicket(nmbrs);
//         }
//     }
// }
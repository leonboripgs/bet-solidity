pragma solidity ^0.5.4;

import "./../lib/Ownable.sol";
import "./../token/ITRC20.sol";


interface IWINR {
    function stakeOf(address) external view returns (uint256);

    function passiveStakeOf(address) external view returns (uint256);

    function calculateReward(address, uint256) external view returns (uint256);

    function lotteryTicketPrice() external view returns (uint256);

    function getStakeID() external view returns (uint256);

    function stats() external view returns (uint256);

    function lastWeek()
        external
        view
        returns (
            uint256[7] memory,
            uint256[7] memory,
            uint256[7] memory,
            uint256[7] memory,
            uint256[7] memory
        );
}


interface ILottery {
    function getLastDrawTime() external view returns (uint256);
}


contract Stats {
    address routerContract;
    address winrContract;
    address lotteryContract;

    constructor(
        address _router,
        address _winr,
        address _lottery
    ) public {
        routerContract = _router;
        winrContract = _winr;
        lotteryContract = _lottery;
    }

    function getPlayerStats(address payable player)
        public
        view
        returns (
            uint256 winrBalance,
            uint256 activeStakes,
            uint256 passiveStakes,
            uint256 claimable,
            uint256 lotteryTime,
            uint256 lotteryTicketPrice,
            uint256 lotteryTrxBalance
        )
    {
        winrBalance = ITRC20(winrContract).balanceOf(player);
        activeStakes = IWINR(winrContract).stakeOf(player);
        passiveStakes = IWINR(winrContract).passiveStakeOf(player);
        claimable = IWINR(winrContract).calculateReward(player, 0);
        lotteryTime = ILottery(lotteryContract).getLastDrawTime();
        lotteryTicketPrice = IWINR(winrContract).lotteryTicketPrice();
        lotteryTrxBalance = address(lotteryContract).balance;
    }
}

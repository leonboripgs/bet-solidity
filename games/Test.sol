pragma solidity ^0.5.4;

import "./../lib/OwnedByRouter.sol";

import './../lib/OwnedByRouter.sol';
import "../core/IRouter.sol";


contract Test is OwnedByRouter {
    // max, min

    Day private _activeDay;
    Day private _stats;
    uint256 private _sendPercentage;
    address payable private _routerContract;
    string public name = "Dice";

    struct Day {
        uint256 lose;
        uint256 wager;
    }

    function getEstimateTrxValueToSend()
        internal
        view
        returns (
            uint256 lose,
            uint256 wager,
            uint256 valToSend
        )
    {
        lose = (_stats.lose + _activeDay.lose) / 2;
        wager = (_stats.wager + _activeDay.wager) / 2;
        valToSend = (address(this).balance * lose) / wager;
        // valToSend = wager - lose + lose ** 2 / wager
    }

    event Roll(address sender, bool win, uint256 bln);

    function play(bool win) public payable {
        // uint valToSend;
        // (_stats.lose, _stats.wager, valToSend) = getEstimateTrxValueToSend();
        // _activeDay.lose = 0;
        // _activeDay.wager = 0;
        _stats.wager += msg.value;
        require(msg.tokenid == 0 && msg.value > 0, "Require only TRX and balance not zero");
        emit Roll(msg.sender, win, msg.value);
        uint256 prize = 0;
        uint256 wager = msg.value;
        if (win) {
            prize = wager;
        } else {
            _stats.lose += msg.value;
        }
        IRouter(routerContract).processGameResult(win, address (0), wager, wager, msg.sender, address (0));
    }

    function getActiveDay() public view returns (uint256 wager, uint256 lose) {
        return (_activeDay.wager, _activeDay.lose);
    }

    // function fundRouter() public payable onlyRouter {
    //     uint valToSend;
    //     (_stats.lose, _stats.wager, valToSend) = getEstimateTrxValueToSend();
    //     _activeDay.lose = 0;
    //     _activeDay.wager = 0;
    //     uint ls = _stats.lose;
    //     uint wg = _stats.wager;

    //     IRouter(routerContract).fund.value(valToSend)(ls,wg);
    // }

    // function getFundFromRouter() {

    // }
}

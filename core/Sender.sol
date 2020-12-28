pragma solidity ^0.5.4;

import "../token/ITRC20.sol";
import "./../lib/Pausable.sol";
import "../lib/Ownable.sol";

contract Sender is Ownable, Pausable {
    function sendTRX(
        address payable _to,
        uint256 _amount,
        uint256 _gasForTransfer
    ) external whenPaused onlyOwner {
        _to.call.value(_amount).gas(_gasForTransfer)("");
    }

    function sendTRC20(
        address payable _to,
        uint256 _amount,
        ITRC20 _token
    ) external whenPaused onlyOwner {
        _token.transfer(_to, _amount);
    }
}

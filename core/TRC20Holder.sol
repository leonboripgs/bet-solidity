pragma solidity ^0.5.4;

import "../lib/Ownable.sol";
import "./ITRC20List.sol";
import "../token/ITRC20.sol";

contract TRC20Holder is Ownable {
    ITRC20List whiteList;

    function setTRC20List(address whiteList_) public onlyOwner {
        whiteList = ITRC20List(whiteList_);
    }

    function getTRC20List() external view returns (address) {
        return address(whiteList);
    }

    modifier onlyEnabledToken(address token_) {
        require(address(whiteList) != address(0), "You must set address of token");
        require(whiteList.isTokenEnabled(token_), "This token not enabled");
        _;
    }

    function getTokens(address token_, uint256 amount_) internal onlyEnabledToken(token_) {
        require(ITRC20(token_).allowance(msg.sender, address(this)) >= amount_, "Approved less than need");
        bool res = ITRC20(token_).transferFrom(msg.sender, address(this), amount_);
        require(res);
    }

    function withdrawToken(address receiver_, address token_, uint256 amount_) internal onlyEnabledToken(token_) {
        require(ITRC20(token_).balanceOf(address(this)) >= amount_, "Can't make withdraw with this amount");
        bool res = ITRC20(token_).transfer(receiver_, amount_);
        require(res);
    }
}
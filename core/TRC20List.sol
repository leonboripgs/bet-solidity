pragma solidity ^0.5.4;

import "../lib/Ownable.sol";
import "../lib/SafeMath.sol";

contract TRC20List is Ownable {
    using SafeMath for uint256;

    mapping(address => uint256) private enabled;
    mapping(address => uint256) private ratioTrx;
    address [] private whiteList;
    uint256 private ratioDecimals;

    event EnableToken(address token_, uint256 ratio_);
    event DisableToken(address token_);

    constructor() public {
        ratioDecimals = 1000 * 1000 * 1000;
    }

    /**
    For enable new token or update existing
    token_  address of TRC20 smart contract
    ratio_  multiplier for determine amount of Trx corresponding this token
     */
    function enableToken(address token_, uint256 ratio_) public onlyOwner {
        require(token_ != address(0), "You must set address");
        if (enabled[token_] == 0) {
            enabled[token_] = 1;
            whiteList.push(token_);
        }
        ratioTrx[token_] = ratio_;
        emit EnableToken(token_, ratio_);
    }

    function disableToken(address token_) public onlyOwner {
        require(token_ != address(0), "You must set address");
        enabled[token_] = 0;
        removeTokenFromList(token_);
        emit DisableToken(token_);
    }

    function getRationDecimals() public view returns (uint256) {
        return ratioDecimals;
    }

    function isTokenEnabled(address token_) public view returns (bool) {
        return enabled[token_] != 0;
    }

    function getRatioTrx(address token_) public view returns (uint256) {
        require(enabled[token_] != 0, "Token not enabled");
        return ratioTrx[token_];
    }

    function removeTokenFromList(address token_) private {
        uint i = 0;
        while (whiteList[i] != token_) {
            i++;
        }
        bool found = i < whiteList.length;
        while (i < whiteList.length - 1) {
            whiteList[i] = whiteList[i + 1];
            i++;
        }
        if (found)
            whiteList.length--;
    }

    function getWhiteListAt(uint index_) public view returns (address) {
        require(whiteList.length > 0 && index_ < whiteList.length, "Index above that exist");
        return whiteList[index_];
    }

    function getWhiteListSize() public view returns (uint256) {
        return whiteList.length;
    }

    function tokenToSun(address token_, uint256 amount_) public view returns (uint256)
    {
        return amount_.mul(getRationDecimals()).div(getRatioTrx(token_));
    }
}
pragma solidity ^0.5.4;

import "../lib/Ownable.sol";

contract ITRC20List is Ownable {
    event EnableToken(address token_, uint256 ratio_);
    event DisableToken(address token_);
    function enableToken(address token_, uint256 ratio_) public;
    function disableToken(address token_) public;
    function getRationDecimals() public view returns (uint256);
    function isTokenEnabled(address token_) public view returns (bool);
    function getRatioTrx(address token_) public view returns (uint256);
    function getElementOfEnabledList(uint index_) public view returns (address);
    function getSizeOfEnabledList() public view returns (uint256);
    function tokenToSun(address token_, uint256 amount_) public view returns (uint256);
}
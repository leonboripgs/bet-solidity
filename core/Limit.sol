pragma solidity ^0.5.4;

import "../lib/Ownable.sol";

contract Limit is Ownable {
    uint256 private minBet;
    uint256 private maxBet;
    mapping (address => uint256) private minBetTRC20;
    mapping (address => uint256) private maxBetTRC20;

    constructor() public {
        minBet = 0;
        maxBet = 0;
    }

    function setMinBet(uint256 amount_) public onlyOwner {
        minBet = amount_;
    }

    function getMinBet() public view returns (uint256) {
        return minBet;
    }

    function setMaxBet(uint256 amount_) public onlyOwner {
        maxBet = amount_;
    }

    function getMaxBet() public view returns (uint256) {
        return maxBet;
    }

    modifier betInLimits() {
        // if minBet equal maxBet, then limits disabled
        if (minBet != maxBet) {
            require(msg.value >= minBet && msg.value <= maxBet, "Bet not in limits");
        }
        _;
    }

    function setMinBetTRC20(address token_, uint256 amount_) public onlyOwner {
        minBetTRC20[token_] = amount_;
    }

    function getMinBetTRC20(address token_) public view returns (uint256) {
        return minBetTRC20[token_];
    }

    function setMaxBetTRC20(address token_, uint256 amount_) public onlyOwner {
        maxBetTRC20[token_] = amount_;
    }

    function getMaxBetTRC20(address token_) public view returns (uint256) {
        return maxBetTRC20[token_];
    }

    modifier betInLimitsTRC20(address token_, uint256 amount_) {
        // if minBetTRC20 equal maxBetTRC20, then limits disabled
        requireBetInLimitsTRC20(token_, amount_);
        _;
    }

    function requireBetInLimitsTRC20(address token_, uint256 amount_) internal {
        // if minBetTRC20 equal maxBetTRC20, then limits disabled
        if (minBetTRC20[token_] != maxBetTRC20[token_]) {
            require(amount_ >= minBetTRC20[token_] && amount_ <= maxBetTRC20[token_], "Bet not in limits");
        }
    }
}
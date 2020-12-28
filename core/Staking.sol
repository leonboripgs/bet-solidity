pragma solidity ^0.5.4;
import "./IStake.sol";
import "../lib/SafeMath.sol";
import "../lib/Ownable.sol";
import "./../token/TRC20.sol";
import "../token/TRC20Detailed.sol";
import "./Sender.sol";

// This contract is staking contract, parent contract of winr contract
contract Staking is Sender, TRC20, TRC20Detailed {
    using SafeMath for uint256;
    event Staked(address payable indexed user, uint256 amount);
    event Unstaked(address payable indexed user, uint256 amount);
    event StakeWithdrawn(address payable indexed user, uint256 amount);
    event TRXRewardsDistributed();
    event TRC20RewardsDistributed();

    // reward to distribute from last day
    uint256 private rewardToDistribute;

    uint256 public gasForTransferTRX = 3000;

    mapping(address => uint256) internal _activeStakes;
    mapping(address => uint256) internal _passiveStakes;
    mapping(address => uint256) internal _unstakedTime;

    // active stakeholders
    // address payable[] internal _activeStakeholders;
    // mapping(address => uint256) internal _activeStakeholdersIndexes;
    // passive stakeholders
    // address payable[] internal _passiveStakeholders;
    // mapping(address => uint256) internal _passiveStakeholdersIndexes;

    mapping(address => uint256) internal rewards;

    uint256 public activeStakesAmount;
    uint256 public passiveStakesAmount;
    // Freezing period after unstaking
    uint256 public freezingPeriod = 86400; //sec (24 hours)
    // uint256 public freezingPeriod = 10; //sec, 2 min for testing

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    
    function sendTRX(
        address payable _to,
        uint256 _amount,
        uint256 _gasForTransferTRX
    ) external whenPaused onlyOwner {
        _to.call.value(_amount).gas(_gasForTransferTRX)("");
    }

    // checks if given address is a stakeholder
    // returns (true if stakeholder, index, is passive)
    // is passive can be removed
    function isStakeholder(address _address) public view returns (bool) {
        return _passiveStakes[_address] > 0 || _activeStakes[_address] > 0;
    }

    // get active and passive stake of the user
    function stakeOf(address _stakeholder)
        public
        view
        returns (
            uint256,
            uint256,
            uint256
        )
    {
        return (
            _activeStakes[_stakeholder],
            _passiveStakes[_stakeholder],
            _unstakedTime[_stakeholder]
        );
    }

    function stake(uint256 _stake) external whenNotPaused() {
        require(
            _passiveStakes[msg.sender] == 0,
            "There is existing passive stake of the user"
        );
        require(_stake <= balanceOf(msg.sender), "Insufficient Balance");

        _balances[msg.sender] = _balances[msg.sender].sub(_stake);
        activeStakesAmount += _stake;

        _activeStakes[msg.sender] = _activeStakes[msg.sender].add(_stake);
        emit Staked(msg.sender, _stake);
    }

    function unstake() external whenNotPaused() {
        require(_activeStakes[msg.sender] > 0, "No stake to unstake");

        uint256 stake = _activeStakes[msg.sender];
        delete _activeStakes[msg.sender];

        _passiveStakes[msg.sender] = stake;
        _unstakedTime[msg.sender] = now;

        activeStakesAmount -= stake;
        passiveStakesAmount += stake;

        emit Unstaked(msg.sender, stake);
    }

    function withdrawStake() external whenNotPaused() {
        require(_passiveStakes[msg.sender] > 0, "No stake to withdraw.");
        require(now >= _unstakedTime[msg.sender] + freezingPeriod, "Time.");

        uint256 stake = _passiveStakes[msg.sender];
        delete _passiveStakes[msg.sender];

        passiveStakesAmount -= stake;

        _balances[msg.sender] = _balances[msg.sender].add(stake);
        emit StakeWithdrawn(msg.sender, stake);
    }

    //     constructor() public{
    // _activeStakeholdersIndexes[msg.sender] =
    //                 _activeStakeholders.push(msg.sender) -
    //                 1;
    //     }

    function setGasForTRXTransfer(uint256 _gasForTransferTRXAmount)external onlyOwner{
        gasForTransferTRX = _gasForTransferTRXAmount;
    }

    function distributeTRXRewards(
        address payable[] memory _stakeholders,
        uint256[] memory _rewards
    ) public onlyOwner {
        require(
            _stakeholders.length == _rewards.length,
            "_stakeholders and _rewards array must have equal length"
        );
        for (uint256 i = 0; i < _stakeholders.length; i++) {
            (bool success, bytes memory data) = _stakeholders[i]
                .call
                .value(_rewards[i])
                .gas(gasForTransferTRX)("");
        }
        emit TRXRewardsDistributed();
    }

    function distributeTRC20Rewards(
        address payable[] memory _stakeholders,
        uint256[] memory _rewards,
        TRC20 token
    ) public onlyOwner {
        require(
            _stakeholders.length == _rewards.length,
            "_stakeholders and _rewards array must have equal length"
        );
        for (uint256 i = 0; i < _stakeholders.length; i++) {
            token.transfer(_stakeholders[i], _rewards[i]);
        }
        emit TRC20RewardsDistributed();
    }
}

pragma solidity ^0.5.4;


interface IStaking {
    event Staked(
        address indexed user,
        uint256 amount,
        uint256 total,
        bytes data
    );
    event Unstaked(
        address indexed user,
        uint256 amount,
        uint256 total,
        bytes data
    );

    function stake(uint256 amount, bytes calldata data) external;

    function unstake(uint256 amount, bytes calldata data) external;

    function totalStaked() external view returns (uint256);

    function isStakeholder() external view returns (bool);

    function stats(uint256 dayCount)
        external
        view
        returns (uint256 staked, uint256 distributed);
}

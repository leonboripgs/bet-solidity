pragma solidity ^0.5.4;

interface IRouter {
    function processGameResult(
        bool win,
        address token_,
        uint wager,
        uint val,
        address  payable player,
        address refAddr
    ) payable external;

    function callByGame(
        address[] calldata players,
        uint[] calldata revenues
    ) external;
}

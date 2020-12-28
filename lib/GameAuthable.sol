pragma solidity ^0.5.4;

import "./../lib/Ownable.sol";


contract GameAuthable is Ownable {
    event GameAdded(address indexed game);

    mapping(address => bool) private _games;

    /**
     * @dev Throws if called by any account other than the game.
     */
    modifier onlyGame() {
        require(isGame(), "Game Ownable: caller is not authable game");
        _;
    }

    function isGame() public view returns (bool) {
        return _games[msg.sender];
        // return true;
    }

    function addGame(address _game) public onlyOwner {
        _games[_game] = true;
        emit GameAdded(_game);
    }
}

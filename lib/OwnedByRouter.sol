pragma solidity ^0.5.4;

import "./../lib/Ownable.sol";


contract OwnedByRouter is Ownable {
    address payable internal routerContract;
    modifier onlyRouter() {
        require(msg.sender == routerContract, "Router Ownable: caller is not the router");
        _;
    }

    function getRouter() public view returns (address router) {
        router = routerContract;
    }

    function setRouter(address payable _addr) public onlyOwner {
        removeOwnership(routerContract);
        routerContract = _addr;
        addOwnership(_addr);
    }
}

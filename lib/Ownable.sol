pragma solidity ^0.5.4;


/**
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 *
 * This module is used through inheritance. It will make available the modifier
 * `onlyOwner`, which can be applied to your functions to restrict their use to
 * the owner.
 */
contract Ownable {
    address payable private _owner;
    mapping(address => bool) private _owners;
    event OwnershipGiven(address indexed newOwner);
    event OwnershipTaken(address indexed previousOwner);

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor() public {
        address payable msgSender = msg.sender;
        _addOwnership(msgSender);
        _owner = msgSender;
        emit OwnershipGiven(msgSender);
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() private view returns (address payable) {
        return _owner;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(isOwner(), "Ownable: caller is not the owner 1");
        _;
    }

    /**
     * @dev Returns true if the caller is the current owner.
     */
    function isOwner() public view returns (bool) {
        return _owners[msg.sender];
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function addOwnership(address payable newOwner) public onlyOwner {
        _addOwnership(newOwner);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     */
    function _addOwnership(address payable newOwner) private {
        require(
            newOwner != address(0),
            "Ownable: new owner is the zero address"
        );
        emit OwnershipGiven(newOwner);
        _owners[newOwner] = true;
    }

    function _removeOwnership(address payable __owner) private {
        _owners[__owner] = false;
        emit OwnershipTaken(__owner);
    }

    function removeOwnership(address payable __owner) public onlyOwner {
        _removeOwnership(__owner);
    }
}

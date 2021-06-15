pragma solidity >=0.8.4;

import "./StringUtils.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Reward is Ownable{
    using StringUtils for string;

    IERC20 bns;

    event ControllerAdded(address indexed controller);
    event ControllerRemoved(address indexed controller);

    // A map of addresses that are authorised to register and renew names.
    mapping(address=>bool) public controllers;

    constructor(address _bns) public {
        bns = IERC20(_bns);
    }

    modifier onlyController {
        require(controllers[msg.sender]);
        _;
    }

     function addController(address controller) external override onlyOwner {
        controllers[controller] = true;
        emit ControllerAdded(controller);
    }

    // Revoke controller permission for an address.
    function removeController(address controller) external override onlyOwner {
        controllers[controller] = false;
        emit ControllerRemoved(controller);
    }

    function registerMining(string calldata name, address owner) external onlyController{
        uint256 len = name.strlen();
        uint256 amount = 0 ether;
        if (len >= 6) {
            amount = 0.5 ether;
        } else if (len >= 5) {
            amount = 5 ether;
        } else if (len >= 4) {
            amount = 50 ether;
        } else if (len >= 3) {
            amount = 150 ether;
        } else {
            amount = 0 ether;
        }

        bns.transferFrom(address(this), owner, amount);
    }
}

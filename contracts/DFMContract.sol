//"SPDX-License-Identifier: MIT"
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract DFMContract is Context, Ownable {

    uint256 private fund;

    constructor() {

    }
    
    receive() external payable {
        fund += msg.value;
    }

    fallback() external payable {

    }

    function donate(address token, uint256 amount) public returns (bool) {
        require(amount > 0, "DFM-Dfm: can't donate with zero");

        IERC20(token).transferFrom(_msgSender(), address(this), amount);

        return true;
    }

    function swap(address tokenA, uint256 amountA, address tokenB) public returns (bool) {
        
    }
}

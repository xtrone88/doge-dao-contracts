//"SPDX-License-Identifier: MIT"
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract DFMContract is Context, Ownable {
    address private constant WETH = 0x9876A5bc27ff511bF5dA8f58c8F93281E5BD1f21;
    address private constant DAI = 0x9876A5bc27ff511bF5dA8f58c8F93281E5BD1f21;
    address private constant WBTC = 0x9876A5bc27ff511bF5dA8f58c8F93281E5BD1f21;
    address private constant USDC = 0x9876A5bc27ff511bF5dA8f58c8F93281E5BD1f21;
    
    uint256 private fund;

    mapping(address => uint256) donations;

    constructor() {}

    modifier acceptable(address token) {
        if (token == WETH ||
            token == DAI ||
            token == WBTC ||
            token == USDC) {
            _;
        }
    }

    receive() external payable {
        fund += msg.value;
    }

    fallback() external payable {}

    function donate(address token, uint256 amount) external acceptable(token) returns (bool) {
        require(amount > 0, "DFM-Dfm: can't donate with zero");

        IERC20(token).transferFrom(_msgSender(), address(this), amount);
        donations[token] += amount;

        return true;
    }

    function swap(
        address tokenA,
        uint256 amountA,
        address tokenB
    ) public returns (uint256 amountB) {

        return 0;
    }
}

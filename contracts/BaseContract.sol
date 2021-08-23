//"SPDX-License-Identifier: MIT"
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import "./interfaces/IUniswapV2Router.sol";

contract BaseContract is Context, Ownable {
    // For MainNet
    // address internal constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    // address internal constant DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    // address internal constant WBTC = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;
    // address internal constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

    // For Kovan
    address internal constant WETH = 0x02822e968856186a20fEc2C824D4B174D0b70502;
    address internal constant DAI = 0x04DF6e4121c27713ED22341E7c7Df330F56f289B;
    address internal constant WBTC = 0x1C8E3Bcb3378a443CC591f154c5CE0EBb4dA9648;
    address internal constant USDC = 0xc2569dd7d0fd715B054fBf16E75B001E5c0C1115;

    IUniswapV2Router internal immutable uniswapRouter =
        IUniswapV2Router(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);

    address internal ddToken;

    modifier whenStartup() {
        require(ddToken != address(0), "DFM-Contracts: not set up DD token");
        _;
    }

    function setupDD(address _dd) public onlyOwner {
        ddToken = _dd;
    }
}

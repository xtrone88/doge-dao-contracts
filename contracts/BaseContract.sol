//"SPDX-License-Identifier: MIT"
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import "./interfaces/IWeightedPoolFactory.sol";
import "./interfaces/IWeightedPool.sol";
import "./interfaces/IVault.sol";
import "./interfaces/IWETH.sol";

import "./interfaces/IUniswapV2Router.sol";
import "./interfaces/IUniswapAnchorView.sol";

contract BaseContract is Context, Ownable {
    address internal constant WETH = 0x9876A5bc27ff511bF5dA8f58c8F93281E5BD1f21;
    address internal constant DAI = 0x9876A5bc27ff511bF5dA8f58c8F93281E5BD1f21;
    address internal constant WBTC = 0x9876A5bc27ff511bF5dA8f58c8F93281E5BD1f21;
    address internal constant USDC = 0x9876A5bc27ff511bF5dA8f58c8F93281E5BD1f21;

    IUniswapV2Router internal immutable uniswapRouter =
        IUniswapV2Router(0x9876A5bc27ff511bF5dA8f58c8F93281E5BD1f21);

    IUniswapAnchorView internal immutable uniswapAnchorView =
        IUniswapAnchorView(0x9876A5bc27ff511bF5dA8f58c8F93281E5BD1f21);

    IVault internal immutable vault =
        IVault(0xBA12222222228d8Ba445958a75a0704d566BF2C8);

    IWeightedPoolFactory internal immutable weightedPoolFactory =
        IWeightedPoolFactory(0x8E9aa87E45e92bad84D5F8DD1bff34Fb92637dE9);

    function _priceOf(address token) internal view returns (uint256) {
        uint256 price = uniswapAnchorView.price(IERC20Metadata(token).symbol());
        return price;
    }
}

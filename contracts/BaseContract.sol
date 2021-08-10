//"SPDX-License-Identifier: MIT"
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import "./interfaces/IUniswapAnchorView.sol";

contract BaseContract is Context, Ownable {
    IUniswapAnchorView internal immutable uniswapAnchorView =
        IUniswapAnchorView(0x9876A5bc27ff511bF5dA8f58c8F93281E5BD1f21);

    function _priceOf(address token) internal view returns (uint256) {
        uint256 price = uniswapAnchorView.price(IERC20Metadata(token).symbol());
        return price;
    }

    function _shareOf(uint256 a, uint256 b) internal pure returns(uint256) {
        return a * (10 ** 9) / b;
    }

    function _amountOf(uint256 share) internal pure returns(uint256) {
        return share / (10 ** 9);
    }
}

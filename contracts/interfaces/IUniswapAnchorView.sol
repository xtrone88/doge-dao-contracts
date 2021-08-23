//"SPDX-License-Identifier: MIT"
pragma solidity ^0.8.4;

interface IUniswapAnchorView {
    function price(string memory symbol) external view returns (uint256);
}

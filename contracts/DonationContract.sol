//"SPDX-License-Identifier: MIT"
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import "./interfaces/IDFMContract.sol";
import "./interfaces/IUniswapAnchorView.sol";

contract DonationContract is Context, Ownable {
    address private immutable dfm;

    mapping(uint256 => uint256) private totalDonation;
    mapping(uint256 => mapping(address => uint256)) private donations;
    mapping(uint256 => address[]) private donators;

    uint256 private today;

    IUniswapAnchorView private immutable uniswapAnchorView =
        IUniswapAnchorView(0x9876A5bc27ff511bF5dA8f58c8F93281E5BD1f21);

    constructor(address _dfm) {
        dfm = _dfm;
        today = _today();
    }

    function _today() private view returns (uint256) {
        return block.timestamp / 86400;
    }

    function distribute(address ddtoken) public returns (bool) {
        uint256 yesterday = today - 86400;
        uint256 total = totalDonation[yesterday];

        require(total > 0, "DFM-Don: no doantions");
        totalDonation[yesterday] = 0;

        uint256 minted = IERC20(ddtoken).balanceOf(address(this));
        require(minted > 0, "DFM-Don: not minted for daily distribution");

        for (uint256 i = 0; i < donators[yesterday].length; i++) {
            uint256 share = minted / total * donations[yesterday][donators[yesterday][i]];
            IERC20(ddtoken).approve(donators[yesterday][i], share);
        }
        totalDonation[yesterday] = total;

        return true;
    }

    function _priceOf(address token, uint256 amount)
        private
        view
        returns (uint256)
    {
        uint256 price = uniswapAnchorView.price(IERC20Metadata(token).symbol());
        return price * amount;
    }

    function donate(address token, uint256 amount) public returns (bool) {
        require(amount > 0, "DFM-Don: can't donate with zero");

        address sender = _msgSender();
        today = _today();
        
        IERC20(token).transferFrom(sender, address(this), amount);
        IERC20(token).approve(dfm, amount);
        IDFMContract(dfm).donate(token, amount);

        uint256 price = _priceOf(token, amount);
        donations[today][sender] += price;
        totalDonation[today] += price;
        donators[today].push(sender);

        return true;
    }

    function claim(address ddtoken, uint256 amount) public returns (bool) {
        IERC20(ddtoken).transferFrom(address(this), _msgSender(), amount);
        return true;
    }
}

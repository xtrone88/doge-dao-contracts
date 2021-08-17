//"SPDX-License-Identifier: MIT"
pragma solidity ^0.8.4;

import "./BaseContract.sol";
import "./DFMContract.sol";

contract DonationContract is BaseContract {
    address payable private immutable dfm;

    mapping(uint256 => uint256) private totalDonation;
    mapping(uint256 => mapping(address => uint256)) private donations;
    mapping(uint256 => address[]) private donators;
    mapping(address => uint256) private distributions;

    uint256 private today;
    uint256 private distedDate;

    constructor(address payable _dfm) {
        dfm = _dfm;
        today = _today();
    }

    function _today() private view returns (uint256) {
        return block.timestamp / 86400;
    }

    function distribute(uint256 minted) external whenStartup {
        require(ddToken == _msgSender(), "DFM-Don: caller is not DD token");
        
        uint256 yesterday = today - 86400;
        if (distedDate == yesterday) {
            return;
        }
        distedDate = yesterday;

        if (totalDonation[yesterday] > 0) {
            for (uint256 i = 0; i < donators[yesterday].length; i++) {
                uint256 share = minted * donations[yesterday][donators[yesterday][i]] / totalDonation[yesterday];
                distributions[donators[yesterday][i]] += share;
            }
        }
    }

    function donate(address token, uint256 amount) public returns (bool) {
        require(amount > 0, "DFM-Don: can't donate with zero");

        address sender = _msgSender();
        today = _today();

        IERC20(token).transferFrom(sender, address(this), amount);
        IERC20(token).approve(dfm, amount);
        DFMContract(dfm).donate(token, amount);

        if (token != WETH) {
            address[] memory path = new address[](2);
            path[0] = token;
            path[1] = WETH;
            amount = uniswapRouter.getAmountsOut(amount, path)[1];
        }
        
        donations[today][sender] += amount;
        totalDonation[today] += amount;
        donators[today].push(sender);
        
        return true;
    }

    function claim(address ddtoken, uint256 amount) public returns (bool) {
        address sender = _msgSender();
        require(distributions[sender] > amount, "DFM-Don: claim exceeds the distribution");
        distributions[sender] -= amount;
        IERC20(ddtoken).transfer(sender, amount);
        return true;
    }
}

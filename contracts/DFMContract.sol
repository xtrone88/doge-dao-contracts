//"SPDX-License-Identifier: MIT"
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "./LGEContract.sol";

contract DFMContract is LGEContract {
    mapping(address => uint256) donations;

    mapping(address => uint256) private pulledUniLps;
    mapping(address => uint256) private pulledBalLps;

    modifier whenDfmAlive() {
        require(dfmOpened, "DFM-Dfm: has not yet opened");
        _;
    }

    modifier acceptable(address token) {
        require(
            token == WETH || token == DAI || token == WBTC || token == USDC,
            "no acceptable token"
        );
        _;
    }

    function donate(address token, uint256 amount)
        external
        whenDfmAlive
        acceptable(token)
        returns (bool)
    {
        require(amount > 0, "DFM-Dfm: can't donate with zero");

        IERC20(token).transferFrom(_msgSender(), address(this), amount);
        donations[token] += amount;

        return true;
    }

    function setBalancerSwapFee(uint256 swapFeePercentage) public onlyOwner whenDfmAlive {
        IWeightedPool(balancerPool).setSwapFeePercentage(swapFeePercentage);
    }

    function uniLiuqidityOf(address account) public view returns (uint256 balance) {
        uint256 share = uniLiquidity * contributionOf(account) / totalContirbution;
        unchecked {
            balance = share - pulledUniLps[account];
        }
    }

    function balLiquidityOf(address account) public view returns (uint256 balance) {
        uint256 share = balLiquidity * contributionOf(account) / totalContirbution;
        unchecked {
            balance = share - pulledBalLps[account];
        }
    }

    function pullUniLiquidity(uint256 amount) public whenLpUnlocked returns (bool) {
        address sender = _msgSender();
        require(uniLiuqidityOf(sender) > amount, "DFM-Dfm: exceeded uniswap liquidity you contributed");

        pulledUniLps[sender] += amount;
        IERC20(UNI).transfer(sender, amount);

        return true;
    }

    function pullBalLiquidity(uint256 amount) public whenLpUnlocked returns (bool) {
        address sender = _msgSender();
        require(balLiquidityOf(sender) > amount, "DFM-Dfm: exceeded balancer liquidity you contributed");

        pulledBalLps[sender] += amount;
        IERC20(BPT).transfer(sender, amount);

        return true;
    }

    mapping(address => uint256[]) rewards;

    function withrawRewards(address token) public whenDfmAlive returns (bool) {
        address sender = _msgSender();
        uint8 quarters = uint8((block.timestamp - dfmStartTime) / 86400 / 30 - rewards[sender].length);

        require(rewards[sender].length < 4, "DFM-Dfm: no rewards");
        require(quarters > 0, "DFM-Dfm: not reached withraw time");

        if (quarters > 4) {
            quarters = 4;
        }

        uint256 uniShare = uniLiuqidityOf(sender);
        uint256 balShare = balLiquidityOf(sender);
        require(uniShare + balShare > 0, "DFM-Dfm: no locked values");

        uniShare = uniLiquidityFund * uniShare / uniLiquidity;
        balShare = balLiquidityFund * balShare / balLiquidity;

        uint256 amount = (uniShare + balShare) * 4 / 100;
        for (uint8 i = 0; i < quarters; i++) {
            rewards[sender].push(amount);
        }

        _withrawFund(token, amount * quarters);

        return true;
    }

    function _withrawFund(address token, uint256 amount) private {
        
    }
}

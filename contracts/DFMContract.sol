//"SPDX-License-Identifier: MIT"
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "./LGEContract.sol";

contract DFMContract is LGEContract {
    mapping(address => uint256) private pulledUniLps;
    mapping(address => uint256) private pulledBalLps;

    mapping(address => uint256[]) rewards;

    uint256 private rewardsPercentage = 400; // 4% of locked value rewards to LGE participants quarterly for one year
    uint256 private balLgeShare = 800; // share of Balancer rewards to LGE - 80%
    uint256 private balBarkShare = 200; // share of Balancer rewards to Barkchain - 20%

    // uint256[] private treasury = new uint256[](4);

    modifier whenDfmAlive() {
        require(dfmOpened, "DFM-Dfm: has not yet opened");
        _;
    }

    function donate(address token, uint256 amount) external whenDfmAlive {
        IERC20(token).transferFrom(_msgSender(), address(this), amount);
    }

    function setBalancerSwapFee(uint256 swapFeePercentage)
        public
        onlyOwner
        whenDfmAlive
    {
        IWeightedPool(balancerPool).setSwapFeePercentage(swapFeePercentage);
    }

    function uniLiuqidityOf(address account)
        public
        view
        returns (uint256 balance)
    {
        uint256 share = (uniLiquidity * contributionOf(account)) /
            totalContirbution;
        unchecked {
            balance = share - pulledUniLps[account];
        }
    }

    function balLiquidityOf(address account)
        public
        view
        returns (uint256 balance)
    {
        uint256 share = (balLiquidity * contributionOf(account)) /
            totalContirbution;
        unchecked {
            balance = share - pulledBalLps[account];
        }
    }

    function pullUniLiquidity(uint256 amount)
        public
        whenLpUnlocked
        returns (bool)
    {
        address sender = _msgSender();
        require(
            uniLiuqidityOf(sender) > amount,
            "DFM-Dfm: exceeded uniswap liquidity you contributed"
        );

        pulledUniLps[sender] += amount;
        IERC20(UNI).transfer(sender, amount);

        return true;
    }

    function pullBalLiquidity(uint256 amount)
        public
        whenLpUnlocked
        returns (bool)
    {
        address sender = _msgSender();
        require(
            balLiquidityOf(sender) > amount,
            "DFM-Dfm: exceeded balancer liquidity you contributed"
        );

        pulledBalLps[sender] += amount;
        IERC20(BPT).transfer(sender, amount);

        return true;
    }

    function setRewardsPercentage(uint256 percentage) public onlyOwner {
        require(
            percentage > 0 && percentage <= 1000,
            "DFM-Dfm: Rewards Percentage must be less than 10%"
        );
        rewardsPercentage = percentage;
    }

    function withrawRewards() public whenDfmAlive returns (uint256) {
        address sender = _msgSender();
        require(rewards[sender].length < 4, "DFM-Dfm: no rewards");

        uint256 quarters = (block.timestamp - dfmStartTime) / 86400 / 90;
        if (quarters > 4) {
            quarters = 4;
        }
        quarters -= rewards[sender].length;
        require(quarters > 0, "DFM-Dfm: not reached withraw time");

        uint256 uniShare = uniLiuqidityOf(sender);
        uint256 balShare = balLiquidityOf(sender);

        uniShare = (uniLiquidityFund * uniShare) / uniLiquidity;
        balShare = (balLiquidityFund * balShare) / balLiquidity;

        require(uniShare + balShare > 0, "DFM-Dfm: no locked values");

        uint256 amount = ((uniShare + balShare) * rewardsPercentage) / 10000;
        for (uint8 i = 0; i < quarters; i++) {
            rewards[sender].push(amount);
        }

        return _withrawFund(amount * quarters, false);
    }

    // function withrawTreasury() public onlyOwner whenDfmAlive returns (uint256) {
    //     require(treasury[3] == 0, "DFM-Dfm: treasury has been used fully");

    //     uint256 quarters = (block.timestamp - dfmStartTime) / 86400 / 90;
    //     if (quarters > 4) {
    //         quarters = 4;
    //     }

    //     require(quarters > 0 && treasury[quarters - 1] == 0, "DFM-Dfm: not reached withraw time");
    //     treasury[quarters - 1] = _withrawFund(8, true);

    //     return treasury[quarters - 1];
    // }

    function setBalRewardsShare(uint256 _balLgeShare, uint256 _balBarkShare)
        public
        onlyOwner
    {
        require(
            _balLgeShare + _balBarkShare == 1000,
            "DFM-Dfm: total rewards share must be 100%"
        );
        balLgeShare = _balLgeShare;
        balBarkShare = _balBarkShare;
    }

    function _balanceOfFund()
        private
        view
        returns (
            uint256,
            uint256[] memory,
            uint256[] memory
        )
    {
        uint256[] memory balances = new uint256[](4);
        uint256[] memory converted = new uint256[](4);
        uint256 total;

        address[] memory path = new address[](2);
        path[1] = WETH;

        for (uint8 i = 0; i < COINS.length; i++) {
            balances[i] = IERC20(COINS[i]).balanceOf(address(this));
            path[0] = COINS[i];
            converted[i] = COINS[i] == WETH
                ? balances[i]
                : uniswapRouter.getAmountsOut(balances[i], path)[1];
            total += converted[i];
        }

        return (total, balances, converted);
    }

    function _withrawFund(uint256 amount, bool percentage)
        private
        returns (uint256)
    {
        (uint256 total, , uint256[] memory converted) = _balanceOfFund();
        if (percentage) {
            amount = (total * amount) / 100;
        }
        require(total > amount, "DFM-Dfm: withraw exceeds the balance");

        uint256 remain = amount;
        for (uint8 i = 0; i < COINS.length; i++) {
            if (converted[i] >= remain) {
                if (COINS[i] != WETH) {
                    _swapTokenForExact(COINS[i], WETH, remain);
                }
                IERC20(WETH).transfer(_msgSender(), amount);
                return amount;
            }
            _swapTokenForExact(COINS[i], WETH, converted[i]);
            remain = amount - converted[i];
        }

        amount -= remain;
        IERC20(WETH).transfer(_msgSender(), amount);

        return amount;
    }

    function _swapTokenForExact(
        address tokenIn,
        address tokenOut,
        uint256 amountOut
    ) private {
        address[] memory path = new address[](2);
        path[0] = tokenIn;
        path[1] = tokenOut;

        uint256 amountIn = uniswapRouter.getAmountsIn(amountOut, path)[0];
        IERC20(tokenIn).approve(address(uniswapRouter), amountIn);

        uniswapRouter.swapTokensForExactTokens(
            amountOut,
            amountIn,
            path,
            address(this),
            block.timestamp + 15
        );
    }
}

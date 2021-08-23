//"SPDX-License-Identifier: MIT"
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "./LGEContract.sol";

contract DFMContract is LGEContract {
    mapping(address => uint256) private pulledLps;
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

    function setRewardsPercentage(uint256 percentage) public onlyOwner {
        require(
            percentage > 0 && percentage <= 1000,
            "DFM-Dfm: Rewards Percentage must be less than 10%"
        );
        rewardsPercentage = percentage;
    }
    
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
    
    function withrawLiquidity() public whenLpUnlocked returns (bool) {
        address sender = _msgSender();
        uint256 tvl = contributionOf(sender) - pulledLps[sender];
        require(tvl > 0, "DFM-Dfm: no locked values");

        pulledLps[sender] += tvl;
        uint256 pullAmount = uniLiquidity * tvl / totalContirbution;

        INonfungiblePositionManager.DecreaseLiquidityParams memory params =
            INonfungiblePositionManager.DecreaseLiquidityParams({
                tokenId: univ3LpTokenId,
                liquidity: uint128(pullAmount),
                amount0Min: 0,
                amount1Min: 0,
                deadline: block.timestamp + 15
            });

        (uint256 amount0, uint256 amount1) = nonfungiblePositionManager.decreaseLiquidity(params);
        IERC20(WETH).transfer(sender, amount0);
        IERC20(ddToken).transfer(sender, amount1);

        uint256[] memory pullAmounts = new uint256[](4);
        IAsset[] memory assets = new IAsset[](4);
        for (uint8 i = 0; i < 4; i++) {
            pullAmounts[i] = balLiquidity[i] * tvl / totalContirbution;
            assets[i] = IAsset(COINS[i]);
        }

        bytes memory userData = abi.encode(uint256(0), pullAmounts);
        IVault.ExitPoolRequest memory exitPoolRequest = IVault.ExitPoolRequest({
            assets: assets,
            minAmountsOut: pullAmounts,
            userData: userData,
            toInternalBalance: false
        });

        vault.exitPool(
            IWeightedPool(balancerPool).getPoolId(),
            address(this),
            payable(sender),
            exitPoolRequest
        );

        return true;
    }

    function withrawRewards() public whenDfmAlive returns (bool) {
        address sender = _msgSender();
        uint256 tvl = contributionOf(sender) - pulledLps[sender];
        require(tvl > 0, "DFM-Dfm: no locked values");

        require(rewards[sender].length < 4, "DFM-Dfm: no rewards");
        uint256 quarters = (block.timestamp - dfmStartTime) / 86400 / 90;
        if (quarters > 4) {
            quarters = 4;
        }
        quarters -= rewards[sender].length;
        require(quarters > 0, "DFM-Dfm: not reached withraw time");

        uint256 amount = (tvl * rewardsPercentage) / 10000;
        for (uint8 i = 0; i < quarters; i++) {
            rewards[sender].push(amount);
        }
        _withrawFund(amount * quarters, false);

        return true;
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
            amount = total * amount / 100;
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

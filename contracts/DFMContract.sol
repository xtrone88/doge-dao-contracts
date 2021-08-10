//"SPDX-License-Identifier: MIT"
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "./LGEContract.sol";

contract DFMContract is LGEContract {
    mapping(address => uint256) donations;

    mapping(address => uint256) private pulledUniLps;
    mapping(address => uint256) private pulledBalLps;

    mapping(address => uint256[]) rewards;

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
        uint256 share = _amountOf(uniLiquidity * _shareOf(contributionOf(account), totalContirbution));
        unchecked {
            balance = share - pulledUniLps[account];
        }
    }

    function balLiquidityOf(address account) public view returns (uint256 balance) {
        uint256 share = _amountOf(balLiquidity * _shareOf(contributionOf(account), totalContirbution));
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

    function withrawRewards() public whenDfmAlive returns (bool) {
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
        
        uniShare = _amountOf(uniLiquidityFund * _shareOf(uniShare, uniLiquidity));
        balShare = _amountOf(balLiquidityFund * _shareOf(balShare, balLiquidity));

        require(uniShare + balShare > 0, "DFM-Dfm: no locked values");

        uint256 amount = (uniShare + balShare) * 4 / 100;
        for (uint8 i = 0; i < quarters; i++) {
            rewards[sender].push(amount);
        }

        _withrawFund(amount * quarters);

        return true;
    }

    function _balanceOfFund() private view returns (uint256, uint256[] memory, uint256[] memory) {
        uint256[] memory balances = new uint256[](4);
        uint256[] memory converted = new uint256[](4);
        uint256 total;

        address[] memory path = new address[](2);
        path[1] = WETH;

        balances[0] = IERC20(WETH).balanceOf(address(this));
        converted[0] = balances[0];
        total += balances[0];

        balances[1] = IERC20(DAI).balanceOf(address(this));
        path[0] = DAI;
        converted[1] = uniswapRouter.getAmountsOut(balances[1], path)[1];
        total += converted[1];

        balances[2] = IERC20(WBTC).balanceOf(address(this));
        path[0] = WBTC;
        converted[2] = uniswapRouter.getAmountsOut(balances[2], path)[1];
        total += converted[2];

        balances[3] = IERC20(USDC).balanceOf(address(this));
        path[0] = USDC;
        converted[3] = uniswapRouter.getAmountsOut(balances[3], path)[1];
        total += converted[3];

        return (total, balances, converted);
    }

    function _withrawFund(uint256 amount) private {
        (uint256 total, , uint256[] memory converted) = _balanceOfFund();
        require(total > amount, "DFM-Dfm: withraw exceeds the balance");
        
        if (converted[0] >= amount) {
            IERC20(WETH).transfer(_msgSender(), amount);
            return;
        }
        
        uint256 remain = amount - converted[0];
        if (converted[1] >= remain) {
            _swapTokenForExact(DAI, WETH, remain);
            IERC20(WETH).transfer(_msgSender(), amount);
            return;
        } else {
            _swapTokenForExact(DAI, WETH, converted[1]);
        }

        remain = remain - converted[1];
        if (converted[2] >= remain) {
            _swapTokenForExact(WBTC, WETH, remain);
            IERC20(WETH).transfer(_msgSender(), amount);
            return;
        } else {
            _swapTokenForExact(WBTC, WETH, converted[2]);
        }

        remain = remain - converted[2];
        if (converted[3] >= remain) {
            _swapTokenForExact(USDC, WETH, remain);
            IERC20(WETH).transfer(_msgSender(), amount);
            return;
        } else {
            _swapTokenForExact(USDC, WETH, converted[3]);
        }
    }

    function _swapTokenForExact(address tokenIn, address tokenOut, uint256 amountOut) private {
        address[] memory path = new address[](2);
        path[0] = tokenIn;
        path[1] = tokenOut;
        
        uint256 amountIn = uniswapRouter.getAmountsIn(amountOut, path)[0];
        IERC20(tokenIn).approve(address(uniswapRouter), amountIn);

        uniswapRouter.swapTokensForExactTokens(amountOut, amountIn, path, address(this), block.timestamp + 15);
    }
}

//"SPDX-License-Identifier: MIT"
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "./interfaces/IWeightedPoolFactory.sol";
import "./interfaces/IWeightedPool.sol";
import "./interfaces/IVault.sol";
import "./interfaces/IWETH.sol";

import "./BaseContract.sol";

contract DFMContract is BaseContract {
    address private constant WETH = 0x9876A5bc27ff511bF5dA8f58c8F93281E5BD1f21;
    address private constant DAI = 0x9876A5bc27ff511bF5dA8f58c8F93281E5BD1f21;
    address private constant WBTC = 0x9876A5bc27ff511bF5dA8f58c8F93281E5BD1f21;
    address private constant USDC = 0x9876A5bc27ff511bF5dA8f58c8F93281E5BD1f21;

    IVault private immutable vault =
        IVault(0xBA12222222228d8Ba445958a75a0704d566BF2C8);
    IWeightedPoolFactory private immutable weightedPoolFactory =
        IWeightedPoolFactory(0x8E9aa87E45e92bad84D5F8DD1bff34Fb92637dE9);

    uint256 private fund;

    mapping(address => uint256) donations;

    address private balancerPool;

    modifier acceptable(address token) {
        require (token == WETH || token == DAI || token == WBTC || token == USDC, "no acceptable token");
        _;
    }

    receive() external payable {
        fund += msg.value;
    }

    fallback() external payable {}

    function donate(address token, uint256 amount)
        external
        acceptable(token)
        returns (bool)
    {
        require(amount > 0, "DFM-Dfm: can't donate with zero");

        IERC20(token).transferFrom(_msgSender(), address(this), amount);
        donations[token] += amount;
        
        return true;
    }

    function setupBalancer() public payable onlyOwner returns (bool) {
        require(address(this).balance > 0, "DFM-Dfm: can't setup balancer with zero remain");

        uint256 total = address(this).balance;
        IWETH(WETH).deposit{value: total}();

        uint256 share = total / 4;
        address[] memory path = new address[](2);
        uint256[] memory amounts = new uint256[](4);

        path[0] = WETH;
        amounts[0] = share;

        path[1] = DAI;
        amounts[1] = uniswapRouter.swapExactETHForTokens{value:share}(0, path, address(this), block.timestamp + 15)[1];

        path[1] = WBTC;
        amounts[2] = uniswapRouter.swapExactETHForTokens{value:share}(0, path, address(this), block.timestamp + 15)[1];

        path[1] = USDC;
        amounts[3] = uniswapRouter.swapExactETHForTokens{value:share}(0, path, address(this), block.timestamp + 15)[1];
    
        IERC20[] memory tokens = new IERC20[](4);
        tokens[0] = IERC20(WETH);
        tokens[1] = IERC20(DAI);
        tokens[2] = IERC20(WBTC);
        tokens[3] = IERC20(USDC);

        uint256[] memory weights = new uint256[](4);
        weights[0] = 0.25e18;
        weights[1] = 0.25e18;
        weights[2] = 0.25e18;
        weights[3] = 0.25e18;
        balancerPool = weightedPoolFactory.create(
            "DogeFundMe",
            "DFM",
            tokens,
            weights,
            0.04e16,
            address(this)
        );

        bytes32 poolId = IWeightedPool(balancerPool).getPoolId();
        IAsset[] memory assets = new IAsset[](4);
        assets[0] = IAsset(WETH);
        assets[1] = IAsset(DAI);
        assets[2] = IAsset(WBTC);
        assets[3] = IAsset(USDC);

        bytes memory userData = abi.encode(uint256(0), amounts);
        IVault.JoinPoolRequest memory joinPoolRequest = IVault.JoinPoolRequest({
            assets: assets,
            maxAmountsIn: amounts,
            userData: userData,
            fromInternalBalance: false
        });

        tokens[0].approve(address(vault), amounts[0]);
        tokens[1].approve(address(vault), amounts[1]);
        tokens[2].approve(address(vault), amounts[2]);
        tokens[3].approve(address(vault), amounts[3]);

        vault.joinPool(poolId, address(this), address(this), joinPoolRequest);

        return true;
    }
}

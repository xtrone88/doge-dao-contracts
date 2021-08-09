//"SPDX-License-Identifier: MIT"
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "./interfaces/IWeightedPoolFactory.sol";
import "./interfaces/IWeightedPool.sol";
import "./interfaces/IVault.sol";
import "./interfaces/IWETH.sol";

import "./interfaces/IUniswapV2Router.sol";

import "./BaseContract.sol";
import "./DFMContract.sol";

contract LGEContract is BaseContract {
    address internal constant WETH = 0x9876A5bc27ff511bF5dA8f58c8F93281E5BD1f21;
    address internal constant DAI = 0x9876A5bc27ff511bF5dA8f58c8F93281E5BD1f21;
    address internal constant WBTC = 0x9876A5bc27ff511bF5dA8f58c8F93281E5BD1f21;
    address internal constant USDC = 0x9876A5bc27ff511bF5dA8f58c8F93281E5BD1f21;

    address internal constant UNI = 0xB4e16d0168e52d35CaCD2c6185b44281Ec28C9Dc;
    address internal constant BPT = 0x0e511Aa1a137AaD267dfe3a6bFCa0b856C1a3682;

    IUniswapV2Router internal immutable uniswapRouter =
        IUniswapV2Router(0x9876A5bc27ff511bF5dA8f58c8F93281E5BD1f21);

    IVault internal immutable vault =
        IVault(0xBA12222222228d8Ba445958a75a0704d566BF2C8);

    IWeightedPoolFactory internal immutable weightedPoolFactory =
        IWeightedPoolFactory(0x8E9aa87E45e92bad84D5F8DD1bff34Fb92637dE9);

    bool private lgeClosed;
    bool internal dfmOpened;

    uint256 internal totalContirbution;
    mapping(address => uint256) internal contirbutions;

    uint256 private lockLpUntil;

    uint256 internal uniLiquidityFund;
    uint256 internal uniLiquidity;
    uint256 internal balLiquidityFund;
    uint256 internal balLiquidity;
    address internal balancerPool;

    uint256 internal dfmStartTime;
    
    function totalContirbuted() public view returns (uint256) {
        return totalContirbution;
    }

    function contributionOf(address account) public view returns (uint256) {
        return contirbutions[account];
    }

    modifier whenLgeAlive() {
        require(!lgeClosed, "DFM-Lge: has already closed");
        _;
    }

    modifier whenLpUnlocked() {
        require(block.timestamp > lockLpUntil, "DFM-Lge: locked for 6 months");
        _;
    }

    function conclude(address token)
        public
        payable
        onlyOwner
        whenLgeAlive
        returns (bool)
    {
        require(
            address(this).balance > 0,
            "DFM-Lge: can't conclude with zero balance"
        );

        lgeClosed = true;

        // send balance to DFM contract
        uint256 total = address(this).balance;
        balLiquidityFund = (total * 8) / 100;
        uniLiquidityFund = total - balLiquidityFund;

        // provide liquidity to Uniswap with dd token
        _setupUniswapLiquidity(uniLiquidityFund, token);

        // provide weighted pool to Balancer V2
        _setupBalancerPool(balLiquidityFund);

        lockLpUntil = block.timestamp + 180 * 1 days;

        emit LgeClosed(block.timestamp);

        dfmOpened = true;
        dfmStartTime = block.timestamp;

        return true;
    }

    function contribute() public payable whenLgeAlive {
        require(msg.value > 0, "DFM-Lge: can't contribute zero ether");

        address sender = _msgSender();
        uint256 amount = msg.value;

        totalContirbution += amount;
        contirbutions[sender] += amount;

        emit Contributed(sender, amount);
    }

    function _setupUniswapLiquidity(uint256 uniShare, address token) private {
        require(
            address(this).balance > uniShare,
            "DFM-Dfm: can't setup uniswap liquidity with zero remain"
        );
        uniswapRouter.addLiquidityETH{
            value: uniShare
        }(
            token,
            IERC20(token).balanceOf(address(this)),
            0,
            0,
            address(this),
            block.timestamp + 15
        );
        
        uniLiquidity = IERC20(UNI).balanceOf(address(this));
    }

    function _setupBalancerPool(uint256 dfmShare) private {
        require(
            address(this).balance > dfmShare,
            "DFM-Dfm: can't setup balancer pool with zero remain"
        );
        require(
            balancerPool == address(0),
            "DFM-Dfm: has already setup balancer"
        );

        uint256 total = address(this).balance;
        IWETH(WETH).deposit{value: total}();

        uint256 share = total / 4;
        address[] memory path = new address[](2);
        uint256[] memory amounts = new uint256[](4);

        path[0] = WETH;
        amounts[0] = share;

        path[1] = DAI;
        amounts[1] = uniswapRouter.swapExactETHForTokens{value: share}(
            0,
            path,
            address(this),
            block.timestamp + 15
        )[1];

        path[1] = WBTC;
        amounts[2] = uniswapRouter.swapExactETHForTokens{value: share}(
            0,
            path,
            address(this),
            block.timestamp + 15
        )[1];

        path[1] = USDC;
        amounts[3] = uniswapRouter.swapExactETHForTokens{value: share}(
            0,
            path,
            address(this),
            block.timestamp + 15
        )[1];

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

        balLiquidity = IERC20(BPT).balanceOf(address(this));
    }

    event Contributed(address indexed from, uint256 amount);
    event LgeClosed(uint256 time);
}

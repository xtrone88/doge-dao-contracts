//"SPDX-License-Identifier: MIT"
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "./BaseContract.sol";
import "./DFMContract.sol";

contract LGEContract is BaseContract {
    
    bool private concluded;
    
    uint256 private totalContirbution;
    mapping(address => uint256) private contirbutions;

    uint256 internal uniLiquidity;
    uint256 internal lockLpUntil;
    
    address private balancerPool;

    function ended() public view returns (bool) {
        return concluded;
    }

    function totalContirbuted() public view returns (uint256) {
        return totalContirbution;
    }

    function contributionOf(address account) public view returns (uint256) {
        return contirbutions[account];
    }

    modifier isOpened() {
        require(!concluded, "DFM-Lge: has already concluded");
        _;
    }

    function conclude(address token)
        public
        payable
        onlyOwner
        isOpened
        returns (bool)
    {
        require(
            address(this).balance > 0,
            "DFM-Lge: can't conclude with zero balance"
        );

        concluded = true;

        // send balance to DFM contract
        uint256 total = address(this).balance;
        uint256 dfmShare = (total * 8) / 100;
        
        // provide liquidity to Uniswap
        _setupUniswapLiquidity(total - dfmShare, token);
        // provide weighted pool to Balancer V2
        _setupBalancerPool(dfmShare);
        
        lockLpUntil = block.timestamp + 180 * 1 days;

        emit Concluded(block.timestamp);

        return true;
    }

    function contribute() public payable isOpened {
        require(msg.value > 0, "DFM-Lge: can't contribute zero ether");

        address sender = _msgSender();
        uint256 amount = msg.value;

        totalContirbution += amount;
        contirbutions[sender] += amount;

        emit Contributed(sender, amount);
    }

    function withrawReward() public payable {
        require(block.timestamp > lockLpUntil, "DFM-Lge: locked for 6 months");
    }

    function _setupUniswapLiquidity(uint256 uniShare, address token) private {
        require(
            address(this).balance > uniShare,
            "DFM-Dfm: can't setup uniswap liquidity with zero remain"
        );
        (, , uint256 liquidity) = uniswapRouter.addLiquidityETH{
            value: uniShare
        }(
            token,
            IERC20(token).balanceOf(address(this)),
            0,
            0,
            address(this),
            block.timestamp + 15
        );
        uniLiquidity += liquidity;
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
    }

    event Contributed(address indexed from, uint256 amount);
    event Concluded(uint256 time);
}

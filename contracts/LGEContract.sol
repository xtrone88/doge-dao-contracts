//"SPDX-License-Identifier: MIT"
pragma solidity ^0.8.4;
pragma abicoder v2;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@uniswap/v3-periphery/contracts/interfaces/INonfungiblePositionManager.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

import "./interfaces/IWeightedPoolFactory.sol";
import "./interfaces/IWeightedPool.sol";
import "./interfaces/IVault.sol";
import "./interfaces/IWETH.sol";

import "./BaseContract.sol";
import "./DFMContract.sol";

contract LGEContract is IERC721Receiver, BaseContract {
    INonfungiblePositionManager internal immutable nonfungiblePositionManager =
        INonfungiblePositionManager(0xC36442b4a4522E871399CD717aBDD847Ab11FE88);

    IVault internal immutable vault =
        IVault(0xBA12222222228d8Ba445958a75a0704d566BF2C8);

    address[] internal COINS = [WETH, DAI, WBTC, USDC];

    uint256 internal totalContirbution;
    mapping(address => uint256) internal contirbutions;

    uint256 internal univ3LpTokenId;
    uint256 internal uniLiquidity;
    uint256 internal uniLiquidityFund;

    address internal balancerPool;
    uint256[] internal balLiquidity = new uint256[](4);
    uint256 internal balLiquidityFund;

    bool private lgeClosed;
    uint256 private lockLpUntil;
    uint256 internal dfmStartTime;

    address internal rwd;

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

    function concludeLge()
        public
        payable
        onlyOwner
        whenStartup
        whenLgeAlive
        returns (bool)
    {
        require(
            totalContirbution > 0 && address(this).balance > totalContirbution,
            "DFM-Lge: can't conclude with not enough balance"
        );
        lgeClosed = true;

        balLiquidityFund = (totalContirbution * 8) / 100;
        uniLiquidityFund = totalContirbution - balLiquidityFund;

        // provide liquidity to Uniswap with dd token
        _setupUniswapLiquidity();

        // provide weighted pool to Balancer V2
        _setupBalancerPool();

        lockLpUntil = block.timestamp + 180 * 1 days;

        emit LgeClosed(
            totalContirbution,
            uniLiquidityFund,
            balLiquidityFund,
            block.timestamp
        );
        dfmStartTime = block.timestamp;

        (bool success, ) = rwd.delegatecall(
            abi.encodeWithSignature("setDfmStartTime(uint256)", dfmStartTime)
        );
        require(success, "DFM-Lge: interaction with RewardsContract failed");

        return true;
    }

    function contribute() public payable whenLgeAlive returns (bool) {
        require(msg.value > 0, "DFM-Lge: can't contribute zero ether");

        address sender = _msgSender();
        uint256 amount = msg.value;

        totalContirbution += amount;
        contirbutions[sender] += amount;

        emit Contributed(sender, amount);

        return true;
    }

    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external pure override returns (bytes4) {
        return this.onERC721Received.selector;
    }

    function _setupUniswapLiquidity() private {
        uint256 ddAmount = IERC20(ddToken).balanceOf(address(this));
        IWETH(WETH).deposit{value: uniLiquidityFund}();

        // IERC20(ddToken).approve(address(uniswapRouter), ddAmount);
        // uniswapRouter.addLiquidityETH{value: uniLiquidityFund}(
        //     ddToken,
        //     ddAmount,
        //     0,
        //     0,
        //     address(this),
        //     block.timestamp + 15
        // );

        IERC20(WETH).approve(
            address(nonfungiblePositionManager),
            uniLiquidityFund
        );
        IERC20(ddToken).approve(address(nonfungiblePositionManager), ddAmount);

        INonfungiblePositionManager.MintParams memory params = INonfungiblePositionManager
            .MintParams({
                token0: WETH,
                token1: ddToken,
                fee: 10000, // 1%
                tickLower: -887272,
                tickUpper: 887272,
                amount0Desired: uniLiquidityFund,
                amount1Desired: ddAmount,
                amount0Min: 0,
                amount1Min: 0,
                recipient: address(this),
                deadline: block.timestamp + 15
            });

        (univ3LpTokenId, uniLiquidity, , ) = nonfungiblePositionManager.mint(
            params
        );
    }

    function _setupBalancerPool() private {
        uint256 share = balLiquidityFund / 4;
        IWETH(WETH).deposit{value: share}();

        address[] memory path = new address[](2);
        IERC20[] memory tokens = new IERC20[](4);
        uint256[] memory weights = new uint256[](4);
        IAsset[] memory assets = new IAsset[](4);

        path[0] = WETH;
        for (uint8 i = 0; i < 4; i++) {
            path[1] = COINS[i];
            balLiquidity[i] = COINS[i] == WETH
                ? share
                : uniswapRouter.swapExactETHForTokens{value: share}(
                    0,
                    path,
                    address(this),
                    block.timestamp + 15
                )[1];

            tokens[i] = IERC20(COINS[i]);
            weights[i] = 0.25e18;
            assets[i] = IAsset(COINS[i]);
        }

        IWeightedPoolFactory weightedPoolFactory = IWeightedPoolFactory(
            0x8E9aa87E45e92bad84D5F8DD1bff34Fb92637dE9
        );
        balancerPool = weightedPoolFactory.create(
            "DogeFundMe",
            "DFM",
            tokens,
            weights,
            0.04e16,
            address(this)
        );

        bytes memory userData = abi.encode(uint256(0), balLiquidity);
        IVault.JoinPoolRequest memory joinPoolRequest = IVault.JoinPoolRequest({
            assets: assets,
            maxAmountsIn: balLiquidity,
            userData: userData,
            fromInternalBalance: false
        });
        for (uint8 i = 0; i < 4; i++) {
            tokens[i].approve(address(vault), balLiquidity[i]);
        }

        vault.joinPool(
            IWeightedPool(balancerPool).getPoolId(),
            address(this),
            address(this),
            joinPoolRequest
        );
    }

    event Contributed(address indexed from, uint256 amount);
    event LgeClosed(
        uint256 total,
        uint256 uniswap,
        uint256 balancer,
        uint256 time
    );
}

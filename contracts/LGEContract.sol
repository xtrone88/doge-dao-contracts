//"SPDX-License-Identifier: MIT"
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "./interfaces/IUniswapV2Router.sol";

contract LGEContract is Context, Ownable {
    uint256 private totalContirbution;
    mapping(address => uint256) private contirbutions;

    bool private concluded;
    uint256 private immutable endtime;

    IUniswapV2Router private immutable uniswapRouter =
        IUniswapV2Router(0x9876A5bc27ff511bF5dA8f58c8F93281E5BD1f21);
    uint256 private totalLiquidity;
    uint256 private lockLpUntil;

    constructor(uint8 weeksAfter) {
        endtime = block.timestamp + weeksAfter * 1 weeks;
    }

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
        require(
            block.timestamp >= endtime,
            "DFM-Lge: can't conclude before ending time"
        );
        _;
    }

    function conclude(address token, address payable dfm)
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
        uint256 dfmShare = (totalContirbution * 8) / 100;
        bool sent = dfm.send(dfmShare);
        require(sent, "DFM-Lge: Failed to send eth to DFM Contract");

        // provide liquidity to Uniswap
        (, , uint256 liquidity) = uniswapRouter.addLiquidityETH(
            token,
            IERC20(token).balanceOf(address(this)),
            0,
            0,
            address(this),
            block.timestamp
        );
        totalLiquidity += liquidity;
        lockLpUntil = block.timestamp + 180 * 1 days;

        emit Concluded(block.timestamp, endtime);

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

    function reward() public payable {
        require(block.timestamp > lockLpUntil, "DFM-Lge: locked for 6 months");

    }

    event Contributed(address indexed from, uint256 amount);
    event Concluded(uint256 time, uint256 endtime);
}

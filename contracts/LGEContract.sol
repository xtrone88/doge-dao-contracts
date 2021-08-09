//"SPDX-License-Identifier: MIT"
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "./BaseContract.sol";

contract LGEContract is BaseContract {
    uint256 private totalContirbution;
    mapping(address => uint256) private contirbutions;

    bool private concluded;
    uint256 private immutable endtime;

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
            block.timestamp >= endtime,
            "DFM-Lge: can't conclude before ending time"
        );
        require(
            address(this).balance > 0,
            "DFM-Lge: can't conclude with zero balance"
        );
        
        concluded = true;

        // send balance to DFM contract
        uint256 total = address(this).balance;
        uint256 dfmShare = (total * 8) / 100;
        bool sent = dfm.send(dfmShare);
        require(sent, "DFM-Lge: Failed to send eth to DFM Contract");

        // provide liquidity to Uniswap
        uint256 uniShare = total - dfmShare;
        (, , uint256 liquidity) = uniswapRouter.addLiquidityETH{value:uniShare}(
            token,
            IERC20(token).balanceOf(address(this)),
            0,
            0,
            address(this),
            block.timestamp + 15
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

    function withrawReward() public payable {
        require(block.timestamp > lockLpUntil, "DFM-Lge: locked for 6 months");
    }

    event Contributed(address indexed from, uint256 amount);
    event Concluded(uint256 time, uint256 endtime);
}

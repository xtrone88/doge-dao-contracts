//"SPDX-License-Identifier: MIT"
pragma solidity ^0.8.4;

import "./BaseContract.sol";

contract RewardsContract is BaseContract {
    address private ddToken;

    uint256 private totalStakes;
    mapping(address => uint256[3]) private stakes;
    mapping(address => uint256[3]) private votes;

    function setupDD(address _dd) public onlyOwner {
        ddToken = _dd;
    }

    modifier whenStartup() {
        require(ddToken != address(0), "DFM-Rewards: not set up DD token");
        _;
    }

    function stake(uint256 amount, uint256 period) public whenStartup returns (uint256) {
        address sender = _msgSender();
        IERC20(ddToken).transferFrom(sender, address(this), amount);

        period = period == 0 ? 1 : (period > 100 ? 100 : period);
        stakes[sender][0] += amount;
        stakes[sender][1] = period;
        stakes[sender][2] = block.timestamp;
        totalStakes += amount;
        
        return _calcDailyVotes(sender);
    }

    function unstake(uint256 amount) public whenStartup returns (uint256) {
        address sender = _msgSender();
        require(stakes[sender][0] >= amount, "DFM-Rewards: exceeds the staked amount");

        uint256 fee = amount * 8 / 100;
        stakes[sender][0] -= amount;
        totalStakes -= amount;

        IERC20(ddToken).transfer(sender, amount - fee);

        return _calcDailyVotes(sender);
    }

    function _calcDailyVotes(address sender) private returns (uint256 dailyVotes) {
        dailyVotes = stakes[sender][0] * (stakes[sender][1] * 30 > ((block.timestamp - stakes[sender][2]) / 86400) ? stakes[sender][1] : 1); 
        votes[sender][0] += votes[sender][1] * (votes[sender][2] == 0 ? 0 : ((block.timestamp - votes[sender][2]) / 86400));
        votes[sender][1] = dailyVotes;
        votes[sender][2] = block.timestamp;
    }
}
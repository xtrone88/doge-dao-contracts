//"SPDX-License-Identifier: MIT"
pragma solidity ^0.8.4;

import "./BaseContract.sol";

contract RewardsContract is BaseContract {
    address private ddToken;

    uint256 private totalStakes;
    mapping(address => uint256[3]) private stakes;
    mapping(address => uint256[3]) private credits;
    mapping(address => uint256[7]) private bundles;
    mapping(uint256 => mapping(address => uint256)) private rounds;

    uint256[7] private fees;

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
        
        return _calcDailyCredits(sender);
    }

    function unstake(uint256 amount) public whenStartup returns (uint256) {
        address sender = _msgSender();
        require(stakes[sender][0] >= amount, "DFM-Rewards: exceeds the staked amount");

        uint256 fee = amount * 8 / 100;
        stakes[sender][0] -= amount;
        totalStakes -= amount;

        IERC20(ddToken).transfer(sender, amount - fee);

        return _calcDailyCredits(sender);
    }

    function breakCredit(uint256 amount, uint8 unit) public whenStartup returns (bool) {
        address sender = _msgSender();
        require(unit > 0 && unit < 6 && bundles[sender][unit] > amount, "DFM-Rewards: unit exceeds range");

        amount *= 1000;
        uint256 fee = amount * 2 / 10;
        credits[sender][0] -= fee * 1000 ** (unit - 1);
        bundles[sender][unit - 1] += amount - fee;
        fees[unit - 1] += fee;

        return true;
    }

    function voteRound(uint256 round, uint256 credit) public whenStartup returns (bool) {
        address sender = _msgSender();
        require(credit > 0 && credits[sender][0] > credit, "DFM-Rewards: credit exceeds range");

        credits[sender][0] -= credit;
        uint256 fee = credit * 2 / 10;
        credit -= fee;

        rounds[round][sender] += credit;

        for (uint8 i = 0; i < fees.length; i++) {
            uint256 unit = 1000 * (i + 1);
            uint256 remain = (credit % unit) / (unit / 1000);
            bundles[sender][i] -= remain;
            credit -= remain;

            remain = (fee % unit) / (unit / 1000);
            fees[i] += remain;
            fee -= remain;
        }

        return true;
    }

    function _calcDailyCredits(address sender) private returns (uint256 dailyCredits) {
        dailyCredits = stakes[sender][0] * (stakes[sender][1] * 30 > ((block.timestamp - stakes[sender][2]) / 86400) ? stakes[sender][1] : 1);
        
        uint256 newly = credits[sender][1] * (credits[sender][2] == 0 ? 0 : ((block.timestamp - credits[sender][2]) / 86400));
        credits[sender][0] += newly;
        credits[sender][1] = dailyCredits;
        credits[sender][2] = block.timestamp;

        for (uint8 i = 0; i < bundles[sender].length; i++) {
            if (newly == 0) {
                break;
            }
            uint256 unit = 1000 * (i + 1);
            uint256 remain = (newly % unit) / (unit / 1000);
            bundles[sender][i] += remain;
            newly -= remain;
        }
    }
}
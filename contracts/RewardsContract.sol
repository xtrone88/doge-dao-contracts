//"SPDX-License-Identifier: MIT"
pragma solidity ^0.8.4;

import "./BaseContract.sol";
import "./ERC20F.sol";

contract RewardsContract is BaseContract {
    uint256 private totalStakes;
    mapping(address => uint256[3]) private stakes;
    mapping(address => uint256[3]) private credits;
    mapping(address => uint256[7]) private bundles;
    mapping(uint256 => mapping(address => uint256)) private rounds;

    uint256 private unstakeFee;
    uint256 private breakVoteFee;
    uint256 private castVoteFee;
    
    uint256 private shareForNextRound;
    uint16 private percentageForNextRound = 200; // 20%

    function setNextPercentageForRound(uint16 _percentageForNextRound) public onlyOwner {
        require(_percentageForNextRound <= 500, "DFM-Rewards: exceeds the limit 50%");
        percentageForNextRound = _percentageForNextRound;
    }

    function stake(uint256 amount, uint256 period)
        public
        whenStartup
        returns (uint256)
    {
        address sender = _msgSender();
        IERC20(ddToken).transferFrom(sender, address(this), amount);

        (uint256 ramount, ) = ERC20F(ddToken).calculateFee(amount);
        period = period == 0 ? 1 : (period > 100 ? 100 : period);
        stakes[sender][0] += ramount;
        stakes[sender][1] = period;
        stakes[sender][2] = block.timestamp;
        totalStakes += ramount;

        return _calcDailyCredits(sender);
    }

    function unstake(uint256 amount) public whenStartup returns (uint256) {
        address sender = _msgSender();
        require(
            stakes[sender][0] >= amount,
            "DFM-Rewards: exceeds the staked amount"
        );

        uint256 fee = (amount *
            (stakes[sender][1] -
                (block.timestamp - stakes[sender][2]) /
                (86400 * 30))) / 100;
        stakes[sender][0] -= amount;
        totalStakes -= amount;

        IERC20(ddToken).transfer(sender, amount - fee);
        unstakeFee += fee;

        return _calcDailyCredits(sender);
    }

    function breakVote(uint256 amount, uint8 unit)
        public
        whenStartup
        returns (bool)
    {
        address sender = _msgSender();
        require(
            unit > 0 && unit <= 6 && bundles[sender][unit] > amount,
            "DFM-Rewards: unit or amount exceeds range"
        );

        uint256 fee = (amount * 2) / 10;
        bundles[sender][unit - 1] += (amount - fee) * 1000;

        fee *= 1000**unit;
        credits[sender][0] -= fee;
        breakVoteFee += fee;

        return true;
    }

    function castVote(uint256 round, uint256 credit)
        public
        whenStartup
        returns (bool)
    {
        address sender = _msgSender();
        require(
            credit > 0 && credits[sender][0] > credit,
            "DFM-Rewards: credit exceeds range"
        );
        credits[sender][0] -= credit;
        
        uint256 fee = credit * 2 / 10;
        credit -= fee;
        castVoteFee += fee;
        
        uint256 forNextRound = credit * percentageForNextRound / 1000;
        credit -= forNextRound;
        shareForNextRound += forNextRound;

        rounds[round][sender] += credit;
        
        for (uint8 i = 0; i < bundles[sender].length; i++) {
            if (credit == 0) {
                break;
            }
            uint256 unit = 1000**i;
            uint256 bundle = (credit % (unit * 1000)) / unit;
            bundles[sender][i] -= bundle;
            credit -= bundle * unit;
        }

        return true;
    }

    function _calcDailyCredits(address sender)
        private
        returns (uint256 dailyCredits)
    {
        dailyCredits =
            stakes[sender][0] *
            (
                stakes[sender][1] * 30 >
                    ((block.timestamp - stakes[sender][2]) / 86400)
                    ? stakes[sender][1]
                    : 1
            );

        uint256 newly = credits[sender][1] *
            (
                credits[sender][2] == 0
                    ? 0
                    : ((block.timestamp - credits[sender][2]) / 86400)
            );
        credits[sender][0] += newly;
        credits[sender][1] = dailyCredits;
        credits[sender][2] = block.timestamp;

        for (uint8 i = 0; i < bundles[sender].length; i++) {
            if (newly == 0) {
                break;
            }
            uint256 unit = 1000**i;
            uint256 bundle = (newly % (unit * 1000)) / unit;
            bundles[sender][i] += bundle;
            newly -= bundle * unit;
        }
    }
}

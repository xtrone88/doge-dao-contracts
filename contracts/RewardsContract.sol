//"SPDX-License-Identifier: MIT"
pragma solidity ^0.8.4;

import "./BaseContract.sol";
import "./ERC20F.sol";

contract RewardsContract is BaseContract {
    uint256 private dfmStartTime;

    uint256 private totalStakes;
    mapping(address => uint256[3]) private stakes;
    mapping(address => uint256[3]) private credits;
    mapping(address => uint256[7]) private bundles;
    
    uint256 public currentRoundId;
    struct Round {
        uint256 id;
        uint256 voters;
        uint256 votes;
        uint256 transfered;
        bool active;
        bool closed;
    }
    mapping(uint256 => Round) rounds;
    mapping(uint256 => mapping(address => uint256)) private votesPerRound;
    
    uint256 private shareForNextRound;
    uint16 private percentageForNextRound = 200; // 20%

    uint256 private unstakeFee;
    uint256 private breakVoteFee;
    uint256 private castVoteFee;
    
    // for distribution every 6 hours
    mapping(uint256 => uint256) private totalVotes;
    mapping(uint256 => mapping(address => uint256)) private votes;
    mapping(uint256 => address[]) private voters;
    mapping(address => uint256) private distributions;
    uint256 private allowedDistribution;
    uint256 private currentPeriod;
    uint256 private distedPeriod;


    modifier whenDfmAlive() {
        require(dfmStartTime > 0, "DFM-Dfm: has not yet opened");
        _;
    }

    function setDfmStartTime(uint256 _dfmStartTime) external onlyOwner {
        dfmStartTime = _dfmStartTime;
    }

    function setNextPercentageForRound(uint16 _percentageForNextRound)
        public
        onlyOwner
    {
        require(
            _percentageForNextRound <= 500,
            "DFM-Rewards: exceeds the limit 50%"
        );
        percentageForNextRound = _percentageForNextRound;
    }

    function stake(uint256 amount, uint256 period)
        public
        whenStartup
        whenDfmAlive
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

    function unstake(uint256 amount)
        public
        whenStartup
        whenDfmAlive
        returns (uint256)
    {
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

    function breakVote(uint256 amount, uint8 unit) public returns (bool) {
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

    function createRound() public onlyOwner returns (uint256) {
        currentRoundId++;
        return currentRoundId;
    }

    function castVote(uint256 credit)
        public
        whenDfmAlive
        returns (bool)
    {
        Round memory round = rounds[currentRoundId];
        require(!round.closed, "DFM-Rewards: can't cast vote to closed round");

        address sender = _msgSender();
        require(
            credit > 0 && credits[sender][0] > credit,
            "DFM-Rewards: credit exceeds range"
        );
        credits[sender][0] -= credit;

        currentPeriod = (block.timestamp - dfmStartTime) / 21600;
        if (votes[currentPeriod][sender] == 0) {
            voters[currentPeriod].push(sender);
        }
        votes[currentPeriod][sender] += credit;
        totalVotes[currentPeriod] += credit;

        if (round.active == false) {
            round = Round({id:currentRoundId, votes:credit, voters:1, transfered:0, active:true, closed:false});
        } else {
            round.voters++;
            round.votes += credit;
        }
        rounds[currentRoundId] = round;
        votesPerRound[currentRoundId][sender] += credit;        

        uint256 fee = (credit * 2) / 10;
        credit -= fee;
        castVoteFee += fee;

        uint256 forNextRound = (credit * percentageForNextRound) / 1000;
        credit -= forNextRound;
        shareForNextRound += forNextRound;
        
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

    function concludeRound() public onlyOwner {
        Round memory round = rounds[currentRoundId];
        require(round.closed, "DFM-Rewards: already closed round");

        round.closed = true;
        round.transfered = shareForNextRound;
        shareForNextRound = 0;
    }

    // must be called from scheduled service every 6 hour since the DFM was setup
    function distribute() public onlyOwner whenStartup whenDfmAlive {
        uint256 prevPeriod = currentPeriod - 21600;
        if (distedPeriod == prevPeriod) {
            return;
        }
        distedPeriod = prevPeriod;

        uint256 total = IERC20(ddToken).balanceOf(address(this)) -
            totalStakes -
            unstakeFee -
            allowedDistribution;
        if (total == 0) {
            return;
        }

        if (totalVotes[prevPeriod] > 0) {
            for (uint256 i = 0; i < voters[prevPeriod].length; i++) {
                uint256 share = (total *
                    votes[prevPeriod][voters[prevPeriod][i]]) /
                    totalVotes[prevPeriod];
                distributions[voters[prevPeriod][i]] += share;
                allowedDistribution += share;
            }
        }
    }

    function distributionOf() public view returns (uint256) {
        return distributions[_msgSender()];
    }

    function claim(uint256 amount) public returns (bool) {
        address sender = _msgSender();
        require(
            distributions[sender] > amount,
            "DFM-Rwd: claim exceeds the distribution"
        );
        allowedDistribution -= amount;
        distributions[sender] -= amount;
        IERC20(ddToken).transfer(sender, amount);
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

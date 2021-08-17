// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "./ERC20F.sol";
import "./DonationContract.sol";

contract DDToken is ERC20F {
    address private immutable lge; // LGE Contract's address
    address private immutable dfm; // DFM Contract's address
    address private immutable rwd; // Reward Contract's address
    address private immutable don; // Donation Contract's address
    address private immutable mkt; // Market Wallet's address

    // fee share per wallet
    uint256 private devShare = 400; // 40%
    uint256 private mktShare = 200; // 20%
    uint256 private rwdShare = 200; // 20%
    uint256 private dfmShare = 200; // 20%

    uint256 private totalFee;
    uint256 private mintedDate;

    constructor(
        address _lge,
        address _dfm,
        address _rwd,
        address _don,
        address _mkt
    ) ERC20F("DogeFundMe", "DD", 500) {
        // 500 means 5% for fee expression, 2 equals 0.02%
        lge = _lge;
        dfm = _dfm;
        rwd = _rwd;
        don = _don;
        mkt = _mkt;
        // mint 9.125 trillion
        uint256 initialSupply = 9.125e12 * 10**decimals();
        _mint(_lge, initialSupply * 95 / 100);
        _mint(owner(), initialSupply * 5 / 100);
    }

    function decimals() public pure override returns (uint8) {
        return 8;
    }

    function mintDaily() public onlyOwner returns (bool) {
        uint256 today = block.timestamp / 86400;
        require(mintedDate != today, "DFM-DD: today has already minted");
        mintedDate = today;

        uint256 minted = balanceOf(don);
        if (minted > 0) {
            DonationContract(don).distribute(minted);
        }
        
        uint256 amount = 500e6 * 10 ** decimals();
        uint256 fee;
        (, fee) = _calculateFee(amount);
        _mint(don, amount);
        _balances[don] -= fee;
        _storeFee(fee);

        return true;
    }

    function transfer(address recipient, uint256 amount)
        public
        override
        returns (bool)
    {
        uint256 fee = _transfer(_msgSender(), recipient, amount);
        _storeFee(fee);
        return true;
    }

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public override returns (bool) {
        uint256 fee = _transfer(sender, recipient, amount);
        _storeFee(fee);

        uint256 currentAllowance = allowance(sender, _msgSender());
        require(
            currentAllowance >= amount,
            "DDToken: transfer amount exceeds allowance"
        );
        unchecked {
            _approve(sender, _msgSender(), currentAllowance - amount);
        }

        return true;
    }

    function setFeeShares(uint256 _devShare, uint256 _dfmShare, uint256 _rwdShare, uint256 _mktShare) public onlyOwner {
        require(_devShare + _dfmShare + _rwdShare + _mktShare == 1000, "DDToken: total fee share must be 100%");
        devShare = _devShare;
        dfmShare = _dfmShare;
        rwdShare = _rwdShare;
        mktShare = _mktShare;
    }
    
    function _storeFee(uint256 fee) private {
        _balances[rwd] += fee * rwdShare / 1000;
        _balances[dfm] += fee * dfmShare / 1000;
        _balances[mkt] += fee * mktShare / 1000;
        _balances[owner()] += fee * devShare / 1000;
        totalFee += fee;
    }
}

pragma solidity ^0.8.4;

import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import "./interfaces/IDFMContract.sol";
import "./interfaces/IUniswapAnchorView.sol";

contract DonationContract is Context, Ownable {

    IUniswapAnchorView private immutable uniswapAnchorView = IUniswapAnchorView(0x9876A5bc27ff511bF5dA8f58c8F93281E5BD1f21);
    address private immutable dfm;

    uint256 private totalDonation;
    mapping(address => uint256) private donations;
    address[] private donators = new address[]();

    uint256 private today;
    bool private paused = false;
            
    constructor(address _dfm) {
        dfm = _dfm;
        today = _today();
    }

    function _today() private pure returns (uint256) {
        return block.timestamp / 86400;
    }

    function resume() public onlyOwner {
        paused = false;
        emit Resume(today);
    }

    function pause() public onlyOwner {
        paused = true;
        emit Paused(today);
    }

    function distribute(address ddtoken) public returns (bool) {
        require(paused, "DFM-Don: donating isn't paused");
        require(totalDonation > 0, "DFM-Don: no doantions");

        uint256 minted = IERC20(ddtoken).balanceOf(address(this));
        require(minted > 0, "DFM-Don: not minted for daily distribution");
        
        for (uint i = 0; i < donators.length; i++) {
            uint256 share = minted / totalDonation * donations[donators[i]];
            IERC20(ddtoken).approve(donators[i], share);
            donations[donators[i]] = 0;
        }

        totalDonation = 0;
        delete donators;

        return true;
    }

    function _priceOf(address token, uint256 amount) private returns (uint256) {
        uint price = uniswapAnchorView.price(IERC20Metadata(token).symbol());
        return price * amount;
    }

    function donate(address token, uint256 amount) public returns (bool) {
        uint256 date = _today();
        if (today != date) {
            today = date;
            paused = true;
            emit Paused(today);
        }

        require(!paused, "DFM-Don: paused temporarily");
        require(amount > 0, "DFM-Don: can't donate with zero");

        address sender = _msgSender();
        IERC20(token).transferFrom(sender, address(this), amount);
        IERC20(token).approve(dfm, amount);
        IDFMContract(dfm).donate(token, amount);
        
        uint256 price = _priceOf(token, amount);
        donations[sender] += price;
        totalDonation += price;
        donators.push(sender);

        return true;
    }

    function claim(address ddtoken, uint256 amount) public returns(bool) {
        IERC20(ddtoken).transferFrom(address(this), _msgSender(), amount);
        return true;
    }

    event Resume(uint256 today);
    event Paused(uint256 today);
}
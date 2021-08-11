//"SPDX-License-Identifier: MIT"
pragma solidity ^0.8.4;

import "truffle/Assert.sol";
import "truffle/DeployedAddresses.sol";
import "../contracts/DFMContract.sol";

contract TestDFMContract {

    address internal constant WETH = 0x02822e968856186a20fEc2C824D4B174D0b70502;
    address internal constant DAI = 0x04DF6e4121c27713ED22341E7c7Df330F56f289B;
    address internal constant WBTC = 0x1C8E3Bcb3378a443CC591f154c5CE0EBb4dA9648;
    address internal constant USDC = 0xc2569dd7d0fd715B054fBf16E75B001E5c0C1115;

    DFMContract dfmContract = DFMContract(DeployedAddresses.DFMContract());

    function testDonate() public {
        uint256 amount = 0.0001e18;
        dfmContract.donate(WETH, amount);
        Assert.equal(IERC20(WETH).balanceOf(address(dfmContract)), amount, "DFM contract should have 0.0001 ETHER donated");
    }

}
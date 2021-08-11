//"SPDX-License-Identifier: MIT"
pragma solidity ^0.8.4;

import "truffle/Assert.sol";
import "truffle/DeployedAddresses.sol";

import "../contracts/DDToken.sol";

contract TestDDToken {

    DDToken ddToken = DDToken(DeployedAddresses.DDToken());

    function testIntialSupply() public {
        uint256 totalSupply = 9.125e12 * 10 ** ddToken.decimals();
        uint256 lgeSupply = totalSupply * 95 / 100;
        uint256 teamSupply = totalSupply * 5 / 100;

        Assert.equal(ddToken.totalSupply(), totalSupply, "The totalSupply of DD Token isn't 9.125 trillion");
        Assert.equal(ddToken.balanceOf(DeployedAddresses.DFMContract()), lgeSupply, "The LGE's supplied DD token isn't 95%");
        Assert.equal(ddToken.balanceOf(tx.origin), teamSupply, "The Team's supplied DD token isn't 5%");
    }

}
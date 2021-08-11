pragma solidity ^0.8.4;

import "truffle/Assert.sol";
import "truffle/DeployedAddresses.sol";
import "../contracts/DFMContract.sol";

contract TestDFMContract {

    DFMContract dfmContract = DFMContract(DeployedAddresses.DFMContract());

    function testDonate() {
        
    }

}
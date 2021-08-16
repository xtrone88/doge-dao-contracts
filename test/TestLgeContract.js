const DDToken = artifacts.require("DDToken");
const DFMContract = artifacts.require("DFMContract");

const BN = web3.utils.toBN;

contract('TestLgeContract', (accounts) => {   
    let ddToken, dfmContract;

    before(async () => {
        ddToken = await DDToken.deployed();
        dfmContract = await DFMContract.deployed();
    });

    it ("Test contribution to LGE", async () => {
        let account0_contribution = await dfmContract.contributionOf(accounts[0]);
        account0_contribution = account0_contribution.toString();
        console.log("Balance of Account[0]", account0_contribution);

        await dfmContract.contribute({value:web3.utils.toWei('1.25', 'ether'),from:accounts[0]});

        account0_contribution = await dfmContract.contributionOf(accounts[0]);
        account0_contribution = account0_contribution.toString();
        console.log("Balance of Account[0]", account0_contribution);
    });
});
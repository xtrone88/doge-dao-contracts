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
        await web3.eth.sendTransaction({from:accounts[3], to:dfmContract.address, value:web3.utils.toWei('1', 'ether')});

        let expectedTotal = 0;
        let account0_contribution = await dfmContract.contributionOf(accounts[0]);
        account0_contribution = account0_contribution.toString();
        console.log("Balance of Account[0]", account0_contribution);

        expectedTotal += 125;
        await dfmContract.contribute({value:web3.utils.toWei('1.25', 'ether'),from:accounts[0]});

        account0_contribution = await dfmContract.contributionOf(accounts[0]);
        account0_contribution = account0_contribution.toString();
        console.log("Balance of Account[0]", account0_contribution);

        let account1_contribution = await dfmContract.contributionOf(accounts[1]);
        account1_contribution = account1_contribution.toString();
        console.log("Balance of Account[1]", account1_contribution);

        expectedTotal += 250;
        await dfmContract.contribute({value:web3.utils.toWei('2.5', 'ether'),from:accounts[1]});

        account1_contribution = await dfmContract.contributionOf(accounts[1]);
        account1_contribution = account1_contribution.toString();
        console.log("Balance of Account[1]", account1_contribution);

        expectedTotal = BN(expectedTotal).mul(BN(10).pow(BN(18))).div(BN(100));
        let totalContribution = await dfmContract.totalContirbuted();
        assert(expectedTotal, totalContribution.toString(), "Total Contribution isn't correct");

        let etherBalance = await web3.eth.getBalance(dfmContract.address);
        console.log("Balance of DFM", etherBalance.toString());
    });
});
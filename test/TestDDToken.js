const DDToken = artifacts.require("DDToken");
const DFMContract = artifacts.require("DFMContract");
const DonationContract = artifacts.require("DonationContract");
const RewardsContract = artifacts.require("RewardsContract");

const BN = web3.utils.toBN;

contract('DDToken', (accounts) => {   
    let ddToken, dfmContract, donationContract, rewardsContract;
    let tokenDecimals;

    before(async () => {
        ddToken = await DDToken.deployed();
        dfmContract = await DFMContract.deployed();
        donationContract = await DonationContract.deployed();
        rewardsContract = await RewardsContract.deployed();

        tokenDecimals = await ddToken.decimals();
        tokenDecimals = tokenDecimals.toNumber();
    });

    it ("Test fee acurues", async () => {
        let teamS = await ddToken.balanceOf(accounts[0]);
        let dfmS = await ddToken.balanceOf(dfmContract.address);
        let rwdS = await ddToken.balanceOf(rewardsContract.address);
        console.log("Team:", teamS.toString(), "MainFundingPool:", dfmS.toString(), "RewardsPool:", rwdS.toString());
    });

    it("Test total supply and distribution of DDToken", async () => {
        let expTotalSupply = BN(9125).mul(BN(10).pow(BN(12 + tokenDecimals))).div(BN(1000));
        let expLgeSupply = expTotalSupply.mul(BN(95)).div(BN(100));
        let expTeamSupply = expTotalSupply.sub(expLgeSupply);

        let totalSupply = await ddToken.totalSupply();
        assert.equal(expTotalSupply, totalSupply.toString(), "Intial supplied tokens aren't equal to 9.125 trillion");

        let lgeSupply = await ddToken.balanceOf(dfmContract.address);
        assert.equal(expLgeSupply, lgeSupply.toString(), "95% of Intial supplied tokens aren't distributed to LGE Contract");

        let teamSupply = await ddToken.balanceOf(accounts[0]);
        assert.equal(expTeamSupply, teamSupply.toString(), "Intial supplied tokens aren't distributed to Team Account");
    });

    it("Test mint daily for distribution to Donators", async () => {
        let expMinted = BN(500).mul(BN(10).pow(BN(6 + tokenDecimals))).mul(BN(95)).div(BN(100));
        await ddToken.mintDaily();

        let donSupply = await ddToken.balanceOf(donationContract.address);
        assert.equal(expMinted, donSupply.toString(), "Daily minted tokens aren't distributed to Donation Contract");
    });

    it("Test re-mint daily", async () => {
        // await ddToken.mintDaily();
    });

    it ("Test fee acurues", async () => {
        let teamS = await ddToken.balanceOf(accounts[0]);
        let dfmS = await ddToken.balanceOf(dfmContract.address);
        let rwdS = await ddToken.balanceOf(rewardsContract.address);
        console.log("Team:", teamS.toString(), "MainFundingPool:", dfmS.toString(), "RewardsPool:", rwdS.toString());
    });

    it ("Test pausable", async () => {
        await ddToken.pause();
        // await ddToken.transfer(accounts[1], 100000000);
        await ddToken.unpause();
    });

    it ("Test transfer", async () => {
        await ddToken.transfer(accounts[1], 100000000);
        await ddToken.approve(accounts[1], 200000000);
        await ddToken.transferFrom(accounts[0], accounts[2], 200000000, {from:accounts[1]});
    });
});
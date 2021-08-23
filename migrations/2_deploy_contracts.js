const DFMContract = artifacts.require("DFMContract");
const DonationContract = artifacts.require("DonationContract");
const RewardsContract = artifacts.require("RewardsContract");
const DDToken = artifacts.require("DDToken");

module.exports = function (deployer, network, accounts) {
    var dfm, don, rwd;
    deployer.deploy(RewardsContract)
    .then(() => RewardsContract.deployed())
    .then((instance) => {
        rwd = instance;
        return deployer.deploy(DFMContract, RewardsContract.address);
    })
    .then(() => DFMContract.deployed())
    .then((instance) => {
        dfm = instance;
        return deployer.deploy(DonationContract, DFMContract.address);
    })
    .then(() => DonationContract.deployed())
    .then((instance) => {
        don = instance;
        return deployer.deploy(DDToken, DFMContract.address, DFMContract.address, RewardsContract.address, DonationContract.address, accounts[0]);
    })
    .then(() => {
        dfm.setupDD(DDToken.address);
        don.setupDD(DDToken.address);
        rwd.setupDD(DDToken.address);
    });
};

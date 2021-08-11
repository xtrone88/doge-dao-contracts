const DFMContract = artifacts.require("DFMContract");

module.exports = function (deployer, network) {
    deployer.deploy(DFMContract);
};

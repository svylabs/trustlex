const BitcoinTransactionUtils = artifacts.require("BitcoinTransactionUtils");

module.exports = function (deployer) {
  deployer.deploy(BitcoinTransactionUtils);
};
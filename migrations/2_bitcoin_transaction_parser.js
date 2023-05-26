const BitcoinTransactionParser = artifacts.require("BitcoinTransactionParser");

module.exports = function (deployer) {
  deployer.deploy(BitcoinTransactionParser);
};
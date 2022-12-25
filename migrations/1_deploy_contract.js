var BitcoinUtils = artifacts.require("BitcoinUtils");
var SafeMath = artifacts.require('SafeMath');

module.exports = function(deployer) {
  // Deploy the SolidityContract contract as our only task
  deployer.deploy(BitcoinUtils);
  deployer.deploy(SafeMath);
};
var BitcoinUtils = artifacts.require("BitcoinUtils");
var BitcoinTransactionUtils = artifacts.require("BitcoinTransactionUtils");
var SafeMath = artifacts.require('SafeMath');
var TrustedBitcoinSPVChain = artifacts.require('TrustedBitcoinSPVChain');
var TrustlexPerAssetOrderBook = artifacts.require('TrustlexPerAssetOrderBook');

module.exports = async function(deployer, network, accounts) {
  // Deploy the SolidityContract contract as our only task
  console.log(accounts[5]);
  await deployer.deploy(BitcoinUtils, {from: accounts[5]}); // 0xaf3DDb0bCd251aA75D90a7412C43b7126Cfb0358
  TrustedBitcoinSPVChain.link(await BitcoinUtils.deployed());
  await deployer.deploy(TrustedBitcoinSPVChain,  {from: accounts[5]}); // 0xb0Ce2d7Ec616608EE2E48603Bee64C1765826145
  await deployer.deploy(SafeMath,  {from: accounts[5]});
  await deployer.deploy(BitcoinTransactionUtils,  {from: accounts[5]});
  TrustlexPerAssetOrderBook.link(await BitcoinTransactionUtils.deployed());
  TrustlexPerAssetOrderBook.link(await SafeMath.deployed());
  //console.log((await TrustedBitcoinSPVChain.deployed()).address);
  await deployer.deploy(TrustlexPerAssetOrderBook, '0x0000000000000000000000000000000000000000', (await TrustedBitcoinSPVChain.deployed()).address,  {from: accounts[5]});
};
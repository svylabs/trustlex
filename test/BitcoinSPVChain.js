
var BitcoinUtils = artifacts.require("BitcoinUtils");
var SafeMath = artifacts.require('SafeMath');
const spvchain = artifacts.require("BitcoinSPVChain");



contract("BitcoinSPVChain", (accounts) => {
    const [owner, user1, user2] = accounts;
    const txParams = { from: owner };
    beforeEach(async function() {
        spvchain.link(await BitcoinUtils.deployed());
        spvchain.link(await SafeMath.deployed());
        this.bitcoinSPVChain = await spvchain.new('0x0000a0203d0b88d3fded0b806262f5889ce83b3b21b2f0db0097080000000000000000006516022a0c1902642fc1f1d76084dea42770a2c572694d1af44e872a19400743f2f84363aef90817923155bf', 758015, 1664333794, txParams);
        console.log(this.bitcoinSPVChain);
    });

    it ('submit block', async function(){
        const res = await this.bitcoinSPVChain.submitBlock('0x00e07e2e56f4bfdfb9d72f106f29dcae91b7ca375221f201f3090000000000000000000023f4af32986fd85064522a5a8fa6b96fec66be9c6fcf16c3aca58cfd52dba250d2fa436372e707170acc1b27', txParams);
        console.log(res);
    });
})

module.exports = function(deployer) {
  // Deploy the SolidityContract contract as our only task
  deployer.deploy(BitcoinUtils);
  deployer.deploy(SafeMath);
};
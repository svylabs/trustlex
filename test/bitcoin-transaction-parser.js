const BitcoinTransactionUtils = artifacts.require('BitcoinTransactionUtils');
const Web3 = require('web3');
const BN = require('bn.js');

contract('BitcoinTransactionParser', (accounts) => {
  const [owner, user1, user2] = accounts;
  const txParams = { from: owner };

  before(async () => {
    this.parser = await BitcoinTransactionUtils.deployed();
  });

  it('should parse a Bitcoin transaction', async () => {
    // Example Bitcoin transaction data (raw hexadecimal format)
    
    const parsedTx = await this.parser.hasOutput('0x0100000001c997a5e56e104102fa209c6a852dd90660a20b2d9c352423edce25857fcd3704000000004847304402204e45e16932b8af514961a1d3a1a25fdf3f4f7732e9d624c6c61548ab5fb8cd410220181522ec8eca07de4860a4acdd12909d831cc56cbbac4622082221a8768d1d0901ffffffff0200ca9a3b00000000434104ae1a62fe09c5f51b13905f07f06b99a2f7159b2225f374cd378d71302fa28414e7aab37397f554a7df5f142c21c1b7303b8a0626f1baded5c72a704f7e6cd84cac00286bee0000000043410411db93e1dcdb8a016b49840f8c53bc1eb68a382e97b1482ecad7b148a6909a5cb2e0eaddfb84ccf9744464f82e160bfa9b8b64f9d4c03f999b8643f656b412a3ac00000000', 
                1000000000, 
                '0x4104ae1a62fe09c5f51b13905f07f06b99a2f7159b2225f374cd378d71302fa28414e7aab37397f554a7df5f142c21c1b7303b8a0626f1baded5c72a704f7e6cd84cac'
                );
    console.log(parsedTx);

    // Assert the parsed transaction data
    // You can add more assertions based on your specific transaction data
    //assert.equal(parsedTx.inputs.length, 1);
    //assert.equal(parsedTx.outputs.length, 2);
  });

  it('should generate trustlex output correctly', async() => {
     const output = await this.parser.getTrustlexScript('0x0000000000000000000000000000000000000000', 
        0, 
        0, 
        '0x0000000000000000000000000000000000000000', 
        0
     );
     assert.equal('0x00202c62b767d34b5444d2a181e3651f82cad623cb20926637258e058faf48dae585', output);
  });


  it('should generate trustlex v1 output correctly', async() => {
    //console.log(parseInt('0x0fffffff', 16));
    const output = await this.parser.getTrustlexScriptV1('0x0000000000000000000000000000000000000000', 
        0, 
        0, 
        '0x0000000000000000000000000000000000000000', 
        0, 
        '0x0000000000000000000000000000000000000000', 
        500000001
    );
    console.log(output);
    assert.equal(output, '0x0020ff2fafd919ab4997ed06f5a18980df76a09ecc3876e256f02d32b868aab5780e');
    //assert.equal(output, '0x043a5912a77576a91400000000000000000000000000000000000000008764040165cd1db17576a91400000000000000000000000000000000000000008868ac');
    // 043a5912a77576a91400000000000000000000000000000000000000008764040165cd1db17576a91400000000000000000000000000000000000000008868ac
    // 043a5912a77576a914000000000000000000000000000000000000000087637caa2000000000000000000000000000000000000000000000000000000000000000008867040165cd1db17576a91400000000000000000000000000000000000000008868ac
 });
 


 it('should generate trustlex v2 output correctly', async() => {
  //console.log(parseInt('0x0fffffff', 16));
  const output = await this.parser.getTrustlexScriptV2('0x0000000000000000000000000000000000000000', 
      0,
      '0x0000000000000000000000000000000000000000', 
      0, 
      '0x0000000000000000000000000000000000000000', 
      500000001,
      '0x0000000000000000000000000000000000000000000000000000000000000000'
  );
  console.log(output);
  assert.equal(output, '0x0020c6bc84fc2c42880e41d407a6f31b990ea0cfe6db0bc8b913721d051aea727720');
  //assert.equal(output, '0x043a5912a77576a914000000000000000000000000000000000000000087637caa2000000000000000000000000000000000000000000000000000000000000000008867040165cd1db17576a91400000000000000000000000000000000000000008868ac');
});

it('should generate trustlex v3 output correctly', async() => {
  console.log("OrderFulfillment Id", (BigInt(1) << BigInt(160)) | BigInt("0xf72b8291b10ec381e55de4788f6ebbb7425cf34e"));
  console.log(BigInt(await this.parser.getOfferFulfillmentId(1, '0xf72b8291b10ec381e55de4788f6ebbb7425cf34e')).toString());
  const offerFulfillmentId = (BigInt("0xf72b8291b10ec381e55de4788f6ebbb7425cf34e") | (BigInt(1) << BigInt(160))).toString();
  const offFulfillId = await this.parser.getOfferFulfillmentId(1, '0xf72b8291b10ec381e55de4788f6ebbb7425cf34e');
  const offSettleId = Web3.eth.abi.encodeParameter('uint256',offerFulfillmentId);
  console.log("OrderFul", await this.parser.getOfferFulfillmentId1(offSettleId));
  console.log("OfferFulfillmentId: ", offerFulfillmentId, offSettleId);
  console.log("OrderData: ", await this.parser.getOrderData('0xbfB3f873e412214E31801f0178f5945c6EF9e148', 1, '0xf72b8291b10ec381e55de4788f6ebbb7425cf34e', '0x5dc01d1e963e4adc1613734882a1b365bb9f6adc', (BigInt(1690528579) << BigInt(32) | BigInt(1690182979))));
  //console.log(parseInt('0x0fffffff', 16));
  const output = await this.parser.getTrustlexScriptV3('0xbfB3f873e412214E31801f0178f5945c6EF9e148', 
      1, 
      '0x5dc01d1e963e4adc1613734882a1b365bb9f6adc', 
      '0xf72b8291b10ec381e55de4788f6ebbb7425cf34e',
      '0x5dc01d1e963e4adc1613734882a1b365bb9f6adc', 
      (BigInt(1690528579) << BigInt(32) | BigInt(1690182979)),
      '0xd211d5267e30db3379db6d1fd58054721c70ab74e5fabe0caf1d504319e2d16f'
  );
  console.log(output);
  assert.equal(output, '0x0020cad5740a5a72a2d9e4cad45860a72d650efc28cc7e159c89613e88364cf3f88a');
  //assert.equal(output, '0x043a5912a77576a914000000000000000000000000000000000000000087637caa2000000000000000000000000000000000000000000000000000000000000000008867040165cd1db17576a91400000000000000000000000000000000000000008868ac');
});

});

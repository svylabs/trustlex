const BitcoinTransactionUtils = artifacts.require('BitcoinTransactionUtils');

contract('BitcoinTransactionParser', (accounts) => {
  let parser;

  before(async () => {
    parser = await BitcoinTransactionUtils.new();
  });

  it('should parse a Bitcoin transaction', async () => {
    // Example Bitcoin transaction data (raw hexadecimal format)
    
    const parsedTx = await parser.hasOutput('0x0100000001c997a5e56e104102fa209c6a852dd90660a20b2d9c352423edce25857fcd3704000000004847304402204e45e16932b8af514961a1d3a1a25fdf3f4f7732e9d624c6c61548ab5fb8cd410220181522ec8eca07de4860a4acdd12909d831cc56cbbac4622082221a8768d1d0901ffffffff0200ca9a3b00000000434104ae1a62fe09c5f51b13905f07f06b99a2f7159b2225f374cd378d71302fa28414e7aab37397f554a7df5f142c21c1b7303b8a0626f1baded5c72a704f7e6cd84cac00286bee0000000043410411db93e1dcdb8a016b49840f8c53bc1eb68a382e97b1482ecad7b148a6909a5cb2e0eaddfb84ccf9744464f82e160bfa9b8b64f9d4c03f999b8643f656b412a3ac00000000', 
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
     const output = await parser.getTrustlexScript('0x0000000000000000000000000000000000000000', 
        0, 
        0, 
        '0x0000000000000000000000000000000000000000', 
        0
     );
     assert.equal('0x00202c62b767d34b5444d2a181e3651f82cad623cb20926637258e058faf48dae585', output);
  });


  it('should generate trustlex v1 output correctly', async() => {
    //console.log(parseInt('0x0fffffff', 16));
    const output = await parser.getTrustlexScriptV1('0x0000000000000000000000000000000000000000', 
        0, 
        0, 
        '0x0000000000000000000000000000000000000000', 
        0, 
        '0x0000000000000000000000000000000000000000', 
        parseInt('0x0fffffff', 16)
    );
    assert.equal('0x00209e176d8b94322f4554540d16bea20d114b1562257b189483df09f282e2ca8e23', output);
 });
});

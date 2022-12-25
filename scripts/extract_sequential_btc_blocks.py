import asyncio
from bitcoinrpc import BitcoinRPC

async def getblock(rpc: BitcoinRPC, height):
    blockhash = await rpc.getblockhash(height)
    block_header = await rpc.getblockheader(blockhash, verbose = False)
    block_header_detail = await rpc.getblockheader(blockhash, verbose = True)
    return (blockhash, block_header, block_header_detail)

async def main():
    async with BitcoinRPC("http://umbrel.local:8332", "umbrel", "iATsnG2w5yLkcAkyQT4s8r2ndCchB7D11urnVKa1ND8=") as rpc:
        for i in range(700000, 700050):
            (blockhash, blockheader, blockheaderdetail) = await getblock(rpc, i)
            print ('0x' + blockhash, '0x' + blockheader, blockheaderdetail['height'], blockheaderdetail['time'], '0x' + blockheaderdetail['merkleroot'], '0x' + blockheaderdetail['previousblockhash'])
            

if __name__ == "__main__":
    asyncio.run(main())
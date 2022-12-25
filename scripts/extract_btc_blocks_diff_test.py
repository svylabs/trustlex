import asyncio
from bitcoinrpc import BitcoinRPC

async def getblock(rpc: BitcoinRPC, height):
    blockhash = await rpc.getblockhash(height)
    block_header = await rpc.getblockheader(blockhash, verbose = False)
    block_header_detail = await rpc.getblockheader(blockhash, verbose = True)
    return (blockhash, block_header, block_header_detail)

async def main():
    async with BitcoinRPC("http://umbrel.local:8332", "umbrel", "iATsnG2w5yLkcAkyQT4s8r2ndCchB7D11urnVKa1ND8=") as rpc:
        for i in range(16, 382):
            start_block_nr = i * 2016 - 1
            first_block_nr = i * 2016 - 2016
            last_block_nr = i * 2016
            (start_blockhash, start_blockheader, start_blockheaderdetail) = await getblock(rpc, start_block_nr)
            (first_blockhash, first_blockheader, first_blockheaderdetail) = await getblock(rpc, first_block_nr)
            (last_blockhash, last_blockheader, last_blockheaderdetail) = await getblock(rpc, last_block_nr)
            print ('0x' + start_blockheader, start_blockheaderdetail['height'], first_blockheaderdetail['time'], '0x' + last_blockheader, '0x' + last_blockhash, '0x' + last_blockheaderdetail['merkleroot'], '0x' + last_blockheaderdetail['previousblockhash'])
            

if __name__ == "__main__":
    asyncio.run(main())
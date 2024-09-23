import asyncio
import argparse
from web3 import AsyncWeb3, AsyncHTTPProvider
from web3.contract import AsyncContract
from eth_account import Account
from eth_account.signers.local import LocalAccount
from web3.middleware.signing import async_construct_sign_and_send_raw_middleware

parser = argparse.ArgumentParser()
parser.add_argument('-l1_url')
parser.add_argument('-l2_url')
args = parser.parse_args()
print(args)


class Relayer:
    def __init__(self, 
                 w3: AsyncWeb3, 
                 src_contract: AsyncContract, 
                 dst_contract: AsyncContract, 
                 ) -> None:
        self._w3 = w3
        self._src_chain_id = -1
        self._src_contract = src_contract
        self._dst_chain_id = -1
        self._dst_contract = dst_contract
        self._last_processed_block_number = -1
    
    async def _init(self):
        self._src_chain_id = await self._w3.eth.chain_id
        self._dst_chain_id = await self._dst_contract.w3.eth.chain_id
        self._last_processed_block_number = (await self._w3.eth.get_block('latest')).number
        self.end = False

    def kill(self):
        self.end = True

    async def run(self):
        await self._init()
        while True and not self.end:
            try:
                latest_block_number = (await self._w3.eth.get_block('latest')).number
                if self._last_processed_block_number > latest_block_number:
                    print("WTF")
                    self._last_processed_block_number = latest_block_number

                print(self._src_chain_id, self._last_processed_block_number + 1, latest_block_number + 1)
                for i in range(self._last_processed_block_number + 1, latest_block_number + 1):
                    self._last_processed_block_number = i
                    found = False
                    for tx_hash in (await self._w3.eth.get_block(i)).transactions:
                        if (await self._w3.eth.get_transaction(tx_hash))['to'] == self._src_contract.address:
                            found = True
                            break
                    if found:
                        for event in self._src_contract.events:
                            for log in await event.get_logs({"fromBlock": i, "toBlock": i}):
                                await self.event_log_handler(log)
            except:
                pass
            finally:
                await asyncio.sleep(1)

    async def event_log_handler(self, log):
        print(f"{self._src_chain_id} : {log.event} {log.args}")
        if log.event == 'SendRemoteMessage':
            try:
                if self._dst_chain_id == log.args['targetChainId']:
                    tx_hash = await self._dst_contract.functions.relayMessage(
                        log.args['targetAddress'],
                        self._src_chain_id,
                        log.args['sourceAddress'],
                        log.args['msgValue'],
                        log.args['msgNonce'],
                        log.args['msgData'],
                    ).transact()
                    await self._dst_contract.w3.eth.wait_for_transaction_receipt(tx_hash)
                    await asyncio.sleep(1)
            except Exception as e:
                print(e)

    
async def main():
    account: LocalAccount = Account.from_key('0x44871d0798f97d79848a013d4936a73bf4cc922c825d31c1cf7033dff6d40987')
    l1 = AsyncWeb3(AsyncHTTPProvider(args.l1_url))
    l2 = AsyncWeb3(AsyncHTTPProvider(args.l2_url))
    l1.middleware_onion.add(await async_construct_sign_and_send_raw_middleware(account))
    l2.middleware_onion.add(await async_construct_sign_and_send_raw_middleware(account))
    l1.eth.default_account = account.address
    l2.eth.default_account = account.address
    l1_bridge = l1.eth.contract(address='0x15c4cA379fce93A279ac49222116A443B972C777', abi=open("abi.json", "r").read())
    l2_bridge = l2.eth.contract(address='0x15c4cA379fce93A279ac49222116A443B972C777', abi=open("abi.json", "r").read())
    r1 = Relayer(l1, l1_bridge, l2_bridge)
    r2 = Relayer(l2, l2_bridge, l1_bridge)
    t1 = asyncio.create_task(r1.run())
    t2 = asyncio.create_task(r2.run())
    await t1
    await t2

if __name__ == "__main__":
    asyncio.run(main())

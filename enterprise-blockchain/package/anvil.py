import aiohttp
import asyncio
import ctypes
import fcntl
import hashlib
import hmac
import json
import os
import shutil
import signal
import socket
import sys
import typing

from ctypes.util import find_library
from requests import RequestException

from config import (
    CONFIG,
    WORKDIR,
    L1_ANVIL_PATH,
    L2_ANVIL_PATH,
    CAST_PATH,
    SECRET_KEY,
    ORIGINAL_L1_PATH,
    ORIGINAL_L2_PATH,
)

from web3 import AsyncWeb3, AsyncHTTPProvider
from web3.contract import AsyncContract
from eth_account import Account
from eth_account.signers.local import LocalAccount
from web3.middleware.signing import async_construct_sign_and_send_raw_middleware



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



__all__ = ("AnvilInstance",)

bind_lock = asyncio.Lock()

os.umask(0o000)
try:
    shutil.rmtree(WORKDIR)
except FileNotFoundError:
    pass
os.mkdir(WORKDIR)
os.chmod(WORKDIR, 0o777)


class AnvilInstance:
    @staticmethod
    async def assign_port(user_id):
        s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        async with bind_lock:
            for port in range(1024, 1024 + 30000):
                try:
                    if AnvilInstance.get_port_owner_id(port) == user_id:
                        return port
                    else:
                        continue
                except FileNotFoundError:
                    try:
                        s.bind(("127.0.0.1", port))
                        s.close()
                        AnvilInstance.set_port_owner_id(port, user_id)
                        return port
                    except socket.error:
                        continue
            raise Exception("assign_port: failed")

    @staticmethod
    def get_port_owner_id(port):
        return open(WORKDIR + "port_owner.%d" % port, "r").read()

    @staticmethod
    def set_port_owner_id(port, user_id):
        return open(WORKDIR + "port_owner.%d" % port, "w").write(user_id)

    def db_path(self):
        return os.path.join(self._base_path, "db.json")

    def load_db(self):
        return json.load(open(self.db_path(), "r"))

    def save_db(self, db):
        with open(self.db_path(), "w") as f:
            json.dump(db, f)

    def exists(self, key):
        return key in self.load_db()

    def read(self, key):
        return self.load_db()[key]

    def write(self, key, value):
        db = self.load_db()
        db[key] = value
        self.save_db(db)

    @property
    def port(self):
        value = int(self.read("port"))
        if self.get_port_owner_id(value) != self._user_id:
            raise Exception("port.getter: port mapping is broken")
        return value

    @port.setter
    def port(self, value):
        if self.get_port_owner_id(value) != self._user_id:
            raise Exception("port.setter: port mapping is broken")
        self.write("port", "%d" % value)

    @property
    def pid(self):
        try:
            return int(self.read("pid"))
        except (FileNotFoundError, KeyError):
            return 0

    @pid.setter
    def pid(self, value):
        self.write("pid", "%d" % value)

    def __init__(self, access_token, kind="L1", meta={}):
        self.meta = meta
        self.kind = kind
        self._user_id = hmac.new(
            bytes(SECRET_KEY, "utf-8"),
            msg=bytes(access_token, "utf-8"),
            digestmod=hashlib.sha256,
        ).hexdigest() + kind
        self._base_path = WORKDIR + self._user_id

        try:
            os.mkdir(self._base_path)
            os.chmod(self._base_path, 0o711)
            self.save_db({})
        except FileExistsError:
            pass

    async def ready(self, start_if_not=False):
        with open(self._base_path + "/status", "a+") as lock_f:
            lock_f.seek(0, os.SEEK_SET)
            try:
                fcntl.flock(lock_f, fcntl.LOCK_EX | fcntl.LOCK_NB)
            except OSError:
                # anvil is running
                # is it ready?
                return lock_f.read(6) == "READY\n"

            if not start_if_not:
                return False

            # start...
            self.save_db({})

            try:
                open(f"{self._base_path}/l1-state.json" if self.kind == "L1" else f"{self._base_path}/l2-state.json")
            except FileNotFoundError:
                with open(f"{self._base_path}/l1-state.json" if self.kind == "L1" else f"{self._base_path}/l2-state.json", "w") as f:
                    f.write(open(ORIGINAL_L1_PATH if self.kind == "L1" else ORIGINAL_L2_PATH).read())


            os.ftruncate(lock_f.fileno(), 0)
            try:
                _ = self.port
            except KeyError:
                self.port = await self.assign_port(self._user_id)
            os.set_inheritable(lock_f.fileno(), True)
            await self._start(lock_f)
            return True

    def _run_anvil(self, lock_f):
        port = self.port

        os.setsid()
        if os.getuid() == 0:
            uid = 30000 + port - 1024
            os.setgroups([])
            os.setresgid(uid, uid, uid)
            os.setresuid(uid, uid, uid)
        os.closerange(0, lock_f.fileno() - 1)
        os.open("/dev/null", os.O_RDWR)
        os.open("/dev/null", os.O_RDWR)
        os.open("/dev/null", os.O_RDWR)
        libc = ctypes.CDLL(find_library("c"))
        libc.prctl(
            # PR_SET_PDEATHSIG
            1,
            signal.SIGKILL,
            0,
            0,
            0,
        )
        libc.prctl(
            # PR_SET_PDEATHSIG
            1,
            signal.SIGTERM,
            0,
            0,
            0,
        )
        os.nice(10)
        argv = [
            L1_ANVIL_PATH if self.kind == "L1" else L2_ANVIL_PATH,
            "--balance",
            "0",
            "-a",
            "0",
            "--state",
            f"{self._base_path}/l1-state.json" if self.kind == "L1" else f"{self._base_path}/l2-state.json",
            "--state-interval",
            "5",
            "--chain-id",
            "78704" if self.kind == "L1" else "78705",
            "--port",
            "%d" % port,
        ]
        if self.kind == "RELAYER":
            async def run_relayer(l1p, l2p, token):
                account: LocalAccount = Account.from_key(CONFIG['RELAYER_PVKEY'])
                relayer_l1 = AsyncWeb3(AsyncHTTPProvider(f"http://127.0.0.1:{l1p}/"))
                relayer_l2 = AsyncWeb3(AsyncHTTPProvider(f"http://127.0.0.1:{l2p}/"))
                relayer_l1.middleware_onion.add(await async_construct_sign_and_send_raw_middleware(account))
                relayer_l2.middleware_onion.add(await async_construct_sign_and_send_raw_middleware(account))
                relayer_l1.eth.default_account = account.address
                relayer_l2.eth.default_account = account.address
                l1_bridge = relayer_l1.eth.contract(address=CONFIG['BRIDGE'], abi=open("abi.json", "r").read())
                l2_bridge = relayer_l2.eth.contract(address=CONFIG['BRIDGE'], abi=open("abi.json", "r").read())
                r1 = Relayer(relayer_l1, l1_bridge, l2_bridge)
                r2 = Relayer(relayer_l2, l2_bridge, l1_bridge)
                t1 = asyncio.create_task(r1.run())
                t2 = asyncio.create_task(r2.run())
                await t1
                await t2

            # print(self.meta)
            asyncio.run(run_relayer(self.meta['L1P'], self.meta['L2P'], self.meta['token']))
        else:
            os.execve(argv[0], argv, {})
        sys.exit(-1)

    async def _start(self, lock_f):
        pid = os.fork()
        if not pid:
            self._run_anvil(lock_f)
        else:
            self.pid = pid
            ready = await self._wait_until_ready()

            if not ready:
                self.kill()
                raise Exception("Could not start anvil node")

            lock_f.write("READY\n")


    async def _wait_until_ready(self, retry_count=20) -> bool:
        if 'token' in self.meta:
            return True

        ready = False
        for _ in range(retry_count):
            await asyncio.sleep(0.5)
            try:
                res = await self.rpc(
                    {
                        "jsonrpc": "2.0",
                        "method": "web3_clientVersion",
                        "params": [],
                        "id": 1,
                    },
                )
                ready = res["result"].startswith("anvil/")
                if ready:
                    break
            except (IndexError, RequestException):
                continue
        return ready

    def kill(self):
        pid = self.pid
        # print("pid", pid)
        self.pid = 0
        if pid > 0:
            os.kill(pid, signal.SIGKILL)
            with open(f"{self._base_path}/l1-state.json" if self.kind == "L1" else f"{self._base_path}/l2-state.json", "w") as f:
                f.write(open(ORIGINAL_L1_PATH if self.kind == "L1" else ORIGINAL_L2_PATH).read())
            
            try:
                os.waitpid(pid, 0)
            except ChildProcessError:
                pass

    async def rpc(self, data):
        if not self.pid > 0:
            raise EOFError
        method = data["method"]
        if method == "eth_sendUnsignedTransaction" or (
            not method.startswith("eth_")
            and not method.startswith("web3_")
            and not method.startswith("net_")
        ):
            raise PermissionError
        async with aiohttp.ClientSession() as session:
            async with session.post(
                "http://localhost:%d" % self.port, json=data
            ) as resp:
                return await resp.json()

    def lock(self, key):
        lock_f = open(os.path.join(self._base_path, key), "w+")
        try:
            fcntl.flock(lock_f, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except OSError:
            lock_f.close()
            return None
        return lock_f

    async def check_solve(self):
        raise NotImplementedError()

    async def call(
        self,
        address,
        sig: str,
        *call_args,
        block_number: typing.Optional[typing.Union[int, str]] = None,
    ) -> str:
        if block_number is None:
            raise Exception("block number should be specified for cast call!")

        common_options = [
            "--legacy",
            "--rpc-url",
            f"http://localhost:{self.port}/",
        ]

        if block_number is not None:
            block_options = ["-b", str(block_number)]
        else:
            block_options = []

        args = [
            CAST_PATH,
            "call",
            *block_options,
            *common_options,
            address,
            sig,
            *call_args,
        ]
        proc = await asyncio.create_subprocess_exec(
            *args,
            stdout=asyncio.subprocess.PIPE,
        )
        stdout, _ = await proc.communicate()
        return stdout.decode()[:-1]

    async def get_block_number(self) -> int:
        common_options = [
            "--rpc-url",
            f"http://localhost:{self.port}/",
        ]

        args = [CAST_PATH, "block-number", *common_options]
        proc = await asyncio.create_subprocess_exec(
            *args,
            stdout=asyncio.subprocess.PIPE,
        )
        comm = await proc.communicate()
        stdout, _ = comm
        return int(stdout)

    async def get_address_from_private_key(self, private_key: str) -> str:
        args = [CAST_PATH, "wallet", "address", "--private-key", private_key]
        proc = await asyncio.create_subprocess_exec(
            *args,
            stdout=asyncio.subprocess.PIPE,
        )
        comm = await proc.communicate()
        stdout, _ = comm
        return stdout.decode().strip()

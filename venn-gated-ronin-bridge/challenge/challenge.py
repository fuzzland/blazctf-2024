from typing import Dict
import os

from ctf_launchers.pwn_launcher import PwnChallengeLauncher
from ctf_launchers.utils import deploy
from ctf_server.types import LaunchAnvilInstanceArgs, DaemonInstanceArgs, UserData, get_privileged_web3, get_system_account, get_player_account
from foundry.anvil import check_error

BRIDGE = "0x64192819Ac13Ef72bF6b5AE239AC672B43a9AF08"
ADMIN_SLOT = "0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103"
HTTP_PROXY_HOST = os.getenv("HTTP_PROXY_HOST", "http://127.0.0.1:8080")

class Challenge(PwnChallengeLauncher):
    def deploy(self, user_data: UserData, mnemonic: str) -> str:
        web3 = get_privileged_web3(user_data, "main")

        player = get_player_account(mnemonic)

        player_address_padded = '0x' + player.address[2:].zfill(64)
        check_error(web3.provider.make_request("anvil_setStorageAt", [BRIDGE, ADMIN_SLOT, player_address_padded]))

        challenge_addr = deploy(
            web3,
            self.project_location,
            mnemonic,
            env=self.get_deployment_args(user_data),
        )

        check_error(web3.provider.make_request("anvil_setStorageAt", [BRIDGE, ADMIN_SLOT, "0x000000000000000000000000000000000000000000000000000000000000dead"]))

        return challenge_addr

    def get_anvil_instances(self) -> Dict[str, LaunchAnvilInstanceArgs]:
        return {
            "main": self.get_anvil_instance(fork_block_num=20468579),
        }

    def get_daemon_instances(self) -> Dict[str, DaemonInstanceArgs]:
        return {
            "agent": DaemonInstanceArgs(
                image="us.gcr.io/blaz-ctf-435008/venn-server:latest"
            )
        }

    def after_deployed(self, user_data: UserData):
        for _ in range(5):
            print()

        print("    In this challenge, you need to submit implment a Policy contract like DummyPolicy.sol.")
        print("    Then you need to submit the runtime code of the Policy contract to the API below to evaluate your policy.")
        print("    Your policy should be able to protect the Ronin Bridge from being exploited.")
        print("    Test cases will be run against your Policy contract. You need to pass all test cases to get the flag.")

        for _ in range(5):
            print()

        print(f"curl {HTTP_PROXY_HOST}/{user_data['external_id']}/agent/")


Challenge().run()


Challenge().run()
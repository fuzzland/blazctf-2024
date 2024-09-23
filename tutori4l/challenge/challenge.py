from typing import Dict

from ctf_launchers.pwn_launcher import PwnChallengeLauncher
from ctf_server.types import LaunchAnvilInstanceArgs, UserData, get_privileged_web3
from foundry.anvil import anvil_setBalance


class Challenge(PwnChallengeLauncher):
    def deploy(self, user_data: UserData, mnemonic: str) -> str:
        web3 = get_privileged_web3(user_data, "main")
        anvil_setBalance(
            web3, "0xF39FD6E51AAD88F6F4CE6AB8827279CFFFB92266", hex(int(10e18))
        )

        challenge_addr = super().deploy(user_data, mnemonic)

        anvil_setBalance(web3, "0xF39FD6E51AAD88F6F4CE6AB8827279CFFFB92266", hex(0))

        return challenge_addr

    def get_anvil_instances(self) -> Dict[str, LaunchAnvilInstanceArgs]:
        return {
            "main": self.get_anvil_instance(fork_url=None, accounts=0, balance=0),
        }


Challenge().run()

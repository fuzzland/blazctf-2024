from typing import Dict

from ctf_launchers.pwn_launcher import PwnChallengeLauncher
from ctf_server.types import LaunchAnvilInstanceArgs, UserData, get_privileged_web3


class Challenge(PwnChallengeLauncher):

    def deploy(self, user_data: UserData, mnemonic: str) -> str:
        r = super().deploy(user_data, mnemonic)
        web3 = get_privileged_web3(user_data, "main")
        web3.provider.make_request("eth_sendRawTransaction", ["0xf86880843b9aca00837cc8cc9412d49f0179ca93c34ca57916c6b30e72b2b9d39880840397b65225a08c1274686a84c5d07aeed038ee64f290ffe5ee3bbf332a832aafadbfeb6e3699a04e11e57b268fd28fc5a6beb3edc06cb52444a5fe5ea134756d6420c02871d1af"])
        return r

    def get_anvil_instances(self) -> Dict[str, LaunchAnvilInstanceArgs]:
        return {
            "main": self.get_anvil_instance(fork_url=None),
        }

Challenge().run()

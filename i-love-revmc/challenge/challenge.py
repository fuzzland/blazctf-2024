import os

from eth_abi import abi
import requests
from ctf_launchers.launcher import Launcher, ORCHESTRATOR_HOST, TIMEOUT, PUBLIC_HOST
from ctf_launchers.team_provider import get_team_provider
from ctf_server.types import (
    CreateInstanceRequest,
    get_player_account,
)

FLAG = os.getenv("FLAG", "flag{this_is_a_test_flag}")

class RevmcLauncher(Launcher):
    def __init__(self):
        super().__init__(
            project_location= None,
            provider=get_team_provider(),
            actions=[]
        )

    def get_anvil_instances(self):
        return {
            "main": self.get_anvil_instance(
                balance=100000000000,
                fork_url=None,
                image="ghcr.io/fuzzland/blaz-ctf-2024-revmc-anvil:latest",
                flag=FLAG,
            ),
        }

    def launch_instance(self) -> int:
        print("creating private blockchain...")
        body = requests.post(
            f"{ORCHESTRATOR_HOST}/instances",
            json=CreateInstanceRequest(
                instance_id=self.get_instance_id(),
                timeout=TIMEOUT,
                anvil_instances=self.get_anvil_instances(),
                daemon_instances=self.get_daemon_instances(),
            ),
        ).json()

        if body["ok"] == False:
            raise Exception(body["message"])

        user_data = body["data"]


        print()
        print(f"your private blockchain has been set up")
        print(f"it will automatically terminate in {TIMEOUT} minutes")
        print(f"---")
        print(f"rpc endpoints:")
        for id in user_data["anvil_instances"]:
            print(f"    - {PUBLIC_HOST}/{user_data['external_id']}/{id}")

        print(f"private key:        {get_player_account(self.mnemonic).key.hex()}")
        return 0

RevmcLauncher().run()
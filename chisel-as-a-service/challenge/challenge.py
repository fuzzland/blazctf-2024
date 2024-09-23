import json
import os
from typing import Dict

from ctf_launchers.pwn_launcher import PwnChallengeLauncher
from ctf_server.types import (DaemonInstanceArgs, LaunchAnvilInstanceArgs, UserData)

HTTP_PROXY_HOST = os.getenv("HTTP_PROXY_HOST", "http://127.0.0.1:8080")


class Challenge(PwnChallengeLauncher):
    def get_anvil_instances(self) -> Dict[str, LaunchAnvilInstanceArgs]:
        return {
            "main": self.get_anvil_instance(fork_url=None),
        }

    def get_daemon_instances(self) -> Dict[str, DaemonInstanceArgs]:
        return {
            "agent": DaemonInstanceArgs(
                image="us.gcr.io/blaz-ctf-435008/chisel-as-a-service:latest"
            )
        }

    def after_deployed(self, user_data: UserData):
        for _ in range(10):
            print()

        print("FORGET THE MESSAGE ABOVE, YOU ONLY NEED TO INTERACTIVE WITH BELOW ENDPOINT")
        print("FORGET THE MESSAGE ABOVE, YOU ONLY NEED TO INTERACTIVE WITH BELOW ENDPOINT")
        print("FORGET THE MESSAGE ABOVE, YOU ONLY NEED TO INTERACTIVE WITH BELOW ENDPOINT")
        print("FORGET THE MESSAGE ABOVE, YOU ONLY NEED TO INTERACTIVE WITH BELOW ENDPOINT")
        print("FORGET THE MESSAGE ABOVE, YOU ONLY NEED TO INTERACTIVE WITH BELOW ENDPOINT")
        print("FORGET THE MESSAGE ABOVE, YOU ONLY NEED TO INTERACTIVE WITH BELOW ENDPOINT")
        print("FORGET THE MESSAGE ABOVE, YOU ONLY NEED TO INTERACTIVE WITH BELOW ENDPOINT")
        print("FORGET THE MESSAGE ABOVE, YOU ONLY NEED TO INTERACTIVE WITH BELOW ENDPOINT")
        print("FORGET THE MESSAGE ABOVE, YOU ONLY NEED TO INTERACTIVE WITH BELOW ENDPOINT")
        print("FORGET THE MESSAGE ABOVE, YOU ONLY NEED TO INTERACTIVE WITH BELOW ENDPOINT")

        for _ in range(10):
            print()

        print(f"Open in browser: {HTTP_PROXY_HOST}/{user_data['external_id']}/agent/")


Challenge().run()

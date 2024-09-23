import yaml
import codecs
import os

CONFIG = yaml.safe_load(open("config.yaml", "r"))
SECRET_KEY = codecs.encode(os.urandom(32), "base64").decode("ascii")
WORKDIR = "/tmp/workdir/"

L1_ANVIL_PATH = "/opt/foundry/bin/anvil"
L2_ANVIL_PATH = "/app/anvil"
CAST_PATH = "/opt/foundry/bin/cast"
FORGE_PATH = "/opt/foundry/bin/forge"

ORIGINAL_L1_PATH = "/app/l1-state.json"
ORIGINAL_L2_PATH = "/app/l2-state.json"

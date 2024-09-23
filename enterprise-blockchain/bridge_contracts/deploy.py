#!/usr/bin/env python3
import argparse
import subprocess

parser = argparse.ArgumentParser()
parser.add_argument('-l1_url')
parser.add_argument('-l2_url')
args = parser.parse_args()
print(args)

RELAYER_PRIVATE_KEY = '0x44871d0798f97d79848a013d4936a73bf4cc922c825d31c1cf7033dff6d40987'
RELAYER_ADDR = '0xb9a68a7a11af75c553f85689095da256cb8c987c'

def deploy_bridge(url):
    return subprocess.check_output(
    f'forge create ./src/Bridge.sol:Bridge --rpc-url "{url}" --private-key {RELAYER_PRIVATE_KEY} --constructor-args {RELAYER_ADDR}',
        shell=True,
    ).split(b"Deployed to: ")[1].split(b"\n")[0].decode('ascii')

l1_bridge = deploy_bridge(args.l1_url)
l2_bridge = deploy_bridge(args.l2_url)
subprocess.check_output(f'cast send --rpc-url {args.l1_url} --private-key {RELAYER_PRIVATE_KEY} {l1_bridge} \'registerRemoteBridge(uint256,address)\' 78705 {l2_bridge}', shell=True)
subprocess.check_output(f'cast send --rpc-url {args.l2_url} --private-key {RELAYER_PRIVATE_KEY} {l2_bridge} \'registerRemoteBridge(uint256,address)\' 78704 {l1_bridge}', shell=True)

print('l1_bridge deployed to', l1_bridge)
print('l2_bridge deployed to', l2_bridge)

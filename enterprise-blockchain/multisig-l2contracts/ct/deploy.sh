#!/bin/bash
rm -rf /tmp/x.json
PVKEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
# forge create --rpc-url http://127.0.0.1:8545 --private-key $PVKEY src/Counter.sol:A
# cast send --rpc-url http://127.0.0.1:8545 --private-key $PVKEY 0x5FbDB2315678afecb367f032d93F642f64180aa3 'juno()'
# cast call --rpc-url http://127.0.0.1:8545 --from 0x0000000000000000000000000000000000031337 0x5FbDB2315678afecb367f032d93F642f64180aa3 'kill()'

# just for the test
cast call --rpc-url http://127.0.0.1:8545 --from 0x0000000000000000000000000000000000031337 0x0000000000000000000000000000000000000539 --data '00'

python3 test.py

#!/bin/bash

PORT=$1 
RPC_URL="http://localhost:$PORT"
PRIVATE_KEY="0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d"

if [ -z "$PORT" ]; then
    echo "Usage: $0 <port>"
    exit 1
fi

cd challenge/project

forge script script/Deploy.s.sol --rpc-url $RPC_URL --broadcast --private-key $PRIVATE_KEY --legacy


echo ""
echo ""
echo ""
echo ""
echo "====================== Challenge Deployment =========================="
echo "Funded Private Key:"
echo -n "* "
echo $PRIVATE_KEY
echo ""
echo "Deployed contracts:"
cat broadcast/Deploy.s.sol/31337/run-latest.json | jq -r  '.transactions[] | "\(.contractName // "Unknown"): \(.contractAddress)"' | grep -v Unknown | sort -u

cd ../..
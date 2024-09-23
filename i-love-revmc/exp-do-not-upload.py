from web3 import Web3
import time

# JIT_COMPILER_PATH=/build/jit-compiler ./anvil --balance 100000000000 --host 0.0.0.0

url = "http://localhost:8545"
w3 = Web3(Web3.HTTPProvider(url))

pk = "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"
addr = w3.eth.account.from_key(pk).address # 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266

deploy_code = "6008600a5f3960095ff35f495f5260205fa000"

tx = {
    "from": addr,
    # to is none because we are deploying a contract
    "value": 0,
    "gas": 1000000,
    "gasPrice": w3.eth.gas_price,
    "data": deploy_code,
    "nonce": w3.eth.get_transaction_count(addr)
}

signed = w3.eth.account.sign_transaction(tx, pk)
tx_hash = w3.eth.send_raw_transaction(signed.raw_transaction)
tx_receipt = w3.eth.wait_for_transaction_receipt(tx_hash)

print(f"Contract address: {tx_receipt.contractAddress}")

resp = w3.provider.make_request("blaz_jitCompile", [tx_receipt.contractAddress])
print(resp)

input()

tx = {
    "from": addr,
    "to": tx_receipt.contractAddress,
    "value": 0,
    "gas": 30000000,
    # "gasPrice": 0x0001002000300040005,
    'maxFeePerGas': 0x00010002000300040005,
    'maxPriorityFeePerGas': 0x00010000000013370000,
    "chainId": w3.eth.chain_id,
    "maxFeePerBlobGas": 2000000000,
    "blobVersionedHashes": (
        "0x01a915e4d060149eb4365960e6a7a45f334393093061116b197e3240065ff2d8",
    ),
    "nonce": w3.eth.get_transaction_count(addr)
}

signed = w3.eth.account.sign_transaction(tx, pk)
tx_hash = w3.eth.send_raw_transaction(signed.raw_transaction)

print(tx_hash.hex())

import os
from fastapi import FastAPI, HTTPException, Request
from web3 import Web3

import uuid
from threading import Lock
import threading

POLICY_ADDRESS = "0xA0E38C68beaaEF97a571C6Ca44a090f9C64275e8"
RPC_URL = os.getenv("RPC_URL", "http://localhost:8545")

def read_test_case(name):
    with open(f"{name}.txt", "r") as file:
        lines = file.readlines()

    test_cases = []
    for line in lines:
        from_addr, to_addr, value, input_data = line.strip().split(',')
        test_cases.append({
            "from": from_addr,
            "to": to_addr,
            "value": hex(int(value)),
            "input": input_data
        })

    return test_cases


BENIGN_TEST_CASES = read_test_case("benign")
ATTACK_TEST_CASES = read_test_case("attack")

app = FastAPI()

# Lock to prevent duplicate submissions
submission_lock = Lock()

# In-memory storage for results (in a real-world scenario, you'd use a database)
results = {}

@app.get("/")
async def root():
    return """
POST /submit
    body = {"code": "0x..."}
    submit your runtime code of policy contract

GET /result/{guid}
    check submission status
"""


@app.post("/submit")
async def submit_code(request: Request):

    submission = await request.json()
    code = submission.get('code')
    if not code:
        raise HTTPException(status_code=400, detail="Code is required")

    if not code.startswith('0x') or not all(c in '0123456789ABCDEFabcdef' for c in code[2:]):
        raise HTTPException(status_code=400, detail="Code must be a valid hexadecimal string starting with '0x'")

    if submission_lock.locked():
        raise HTTPException(status_code=429, detail="Another submission is in progress")

    guid = str(uuid.uuid4())
    results[guid] = "not ready"

    submission_lock.acquire()

    thread = threading.Thread(target=process_submission, args=(guid, submission['code']))
    thread.start()

    return {"guid": guid}


@app.get("/result/{guid}")
async def get_result(guid: str):
    if guid not in results:
        raise HTTPException(status_code=404, detail="Result not found")

    return {"result": results[guid]}


def process_submission(guid: str, code: str):
    try:
        r = {
            'passed_benign_cases': 0,
            'total_benign_cases': len(BENIGN_TEST_CASES),
            'passed_attack_cases': 0,
            'total_attack_cases': len(ATTACK_TEST_CASES),
        }

        web3 = Web3(Web3.HTTPProvider(RPC_URL))
        result = web3.provider.make_request("anvil_setCode", [POLICY_ADDRESS, code])
        print("set code to", code)
        print("set code result", result)

        for case in BENIGN_TEST_CASES:
            try:
                # Perform eth_call for each benign case
                web3.eth.call({
                    'from': case['from'],
                    'to': case['to'],
                    'value': case['value'],
                    'data': case['input']
                })
                r['passed_benign_cases'] += 1

            except Exception:
                print(f"benign case failed: {case}")
                break

        passed = r['passed_benign_cases'] == r['total_benign_cases']
        if not passed:
            results[guid] = r
            return

        for case in ATTACK_TEST_CASES:
            try:
                # Perform eth_call for each attack case
                web3.eth.call({
                    'from': case['from'],
                    'to': case['to'],
                    'value': case['value'],
                    'data': case['input']
                })
                print(f"attack case failed: {case}")
                # break
            except Exception as e:
                if "revert" in str(e).lower():
                    r['passed_attack_cases'] += 1
                else:
                    print(f"attack case failed but not reverted: {case}")
                    break

        passed = r['passed_benign_cases'] == r['total_benign_cases'] and r['passed_attack_cases'] == r['total_attack_cases']

        # Set dead address with code 0xdead so that judger can detect it
        dead_address = "0x000000000000000000000000000000000000dead"
        dead_code = "0xdead"
        web3.provider.make_request("anvil_setCode", [dead_address, dead_code])

        if passed:
            results[guid] = "solved, go back to nc and get flag"
        else:
            results[guid] = r

    finally:
        # Explicitly release the lock after processing
        submission_lock.release()

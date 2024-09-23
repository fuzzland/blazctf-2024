import json

from challenge import ChallengeInstance
from fastapi import FastAPI, Request

app = FastAPI()


@app.get("/")
async def root():
    return {
        "message": (
            """
GET /reset/{access_token}
POST /rpc/{L1|L2}{access_token}
GET /flag/{access_token}
"""
        ).strip()
    }

@app.post("/rpc/{lx}/{access_token}")
async def rpc(lx: str, access_token: str, request: Request):
    l1 = ChallengeInstance(access_token)
    l2 = ChallengeInstance(access_token, kind="L2")

    await l1.ready(start_if_not=True)
    await l2.ready(start_if_not=True)

    relayer = ChallengeInstance(access_token, kind="RELAYER", meta={"L1P": l1.port, "L2P": l2.port, "token": access_token})
    await relayer.ready(start_if_not=True)

    if lx == "L1" and await l1.ready(start_if_not=True):
        try:
            return await l1.rpc(json.loads(await request.body()))
        except Exception as e:
            return {"error": str(e)}
    elif lx == "L2" and await l2.ready(start_if_not=True):
        try:
            return await l2.rpc(json.loads(await request.body()))
        except Exception as e:
            return {"error": str(e)}
    else:
        return {"error": "node not ready"}


@app.get("/reset/{access_token}")
async def reset(access_token: str):
    l1 = ChallengeInstance(access_token)
    l2 = ChallengeInstance(access_token, kind="L2")
    relayer = ChallengeInstance(access_token, kind="RELAYER")

    ret = []
    if await l1.ready():
        l1.kill()
        ret.append({"message": "OK1"})
    else:
        l1.kill()
        ret.append({"message": "OK2"})
    
    if await l2.ready():
        l2.kill()
        ret.append({"message": "OK1"})
    else:
        l2.kill()
        ret.append({"message": "OK2"})

    if await relayer.ready():
        relayer.kill()
        ret.append({"message": "OK1"})
    else:
        relayer.kill()
        ret.append({"message": "OK2"})

    return ret


@app.get("/flag/{access_token}")
async def consume_flag(access_token: str):
    a = ChallengeInstance(access_token)
    if await a.ready():
        return await a.check_solve()
    else:
        return {"error": "node not ready"}

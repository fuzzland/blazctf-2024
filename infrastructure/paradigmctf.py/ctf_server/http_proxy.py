import logging
from contextlib import asynccontextmanager

import aiohttp
from fastapi import FastAPI, Request, Response

from .utils import load_database

# Set up logger
logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)
handler = logging.StreamHandler()
handler.setFormatter(logging.Formatter('%(asctime)s - %(name)s - %(levelname)s - %(message)s'))
logger.addHandler(handler)

@asynccontextmanager
async def lifespan(app: FastAPI):
    global session, database
    session = aiohttp.ClientSession()
    database = load_database()

    yield

    await session.close()

app = FastAPI(lifespan=lifespan)

@app.get("/")
async def root():
    return "http proxy running"

@app.get("/{external_id}/{daemon_id}/{path:path}")
@app.post("/{external_id}/{daemon_id}/{path:path}")
async def route_post(external_id: str, daemon_id: str, path: str, request: Request):
    user_data = database.get_instance_by_external_id(external_id)
    if user_data is None:
        return "invalid rpc url, instance not found"

    daemon_instance = user_data.get("daemon_instances", {}).get(daemon_id, None)
    if daemon_instance is None:
        return "invalid rpc url, chain not found"

    instance_host = f"http://{daemon_instance['ip']}:8080/" + path

    logger.info(f"Proxying request to {instance_host}")

    body = None
    try:
        body = await request.body()
    except Exception as e:
        logger.error("Failed to read request body", exc_info=e)
        return "failed to read request body"

    try:
        async with session.request(
            url=instance_host,
            method=request.method,
            data=None if request.method == "GET" else body,
            params=request.query_params,  # Add query parameters to the request
        ) as resp:
            content = await resp.text()
            response = Response(content=content)
            for header, value in resp.headers.items():
                response.headers[header] = value
            return response

    except Exception as e:
        logger.error(f"Failed to proxy HTTP request to {external_id}", exc_info=e)
        return "internal server error"
from contextlib import asynccontextmanager
from pathlib import Path

from fastapi import FastAPI
from fastapi.responses import FileResponse, JSONResponse
from pydantic import BaseModel

from . import providers
from .accounts import Manager
from .openai_compat import make_router

mgr = Manager()
WEB = Path(__file__).resolve().parent.parent / "web"


@asynccontextmanager
async def lifespan(app):
    await mgr.start()
    yield
    await mgr.stop()


app = FastAPI(lifespan=lifespan)
app.include_router(make_router(mgr))


@app.exception_handler(KeyError)
async def not_found(request, exc):
    return JSONResponse({"error": "unknown account"}, status_code=404)


class AddReq(BaseModel):
    provider: str = providers.CLAUDE


class SendReq(BaseModel):
    text: str
    new_chat: bool = True


@app.get("/")
async def index():
    return FileResponse(WEB / "static" / "index.html")


@app.get("/api/accounts")
async def list_accounts():
    return [a.to_json() for a in mgr.accs.load()]


@app.post("/api/accounts")
async def add_account(req: AddReq):
    return mgr.accs.add(req.provider).to_json()


@app.post("/api/accounts/{id}/open")
async def open_account(id: str):
    p = await mgr.open(id)
    return {"url": p.url}


@app.get("/api/accounts/{id}/info")
async def info(id: str):
    return await mgr.info(id)


@app.post("/api/accounts/{id}/send")
async def send(id: str, req: SendReq):
    return await mgr.send(id, req.text, req.new_chat)


@app.get("/api/accounts/{id}/reply")
async def reply(id: str, timeout: int = 300):
    return await mgr.reply(id, timeout)


@app.get("/api/accounts/{id}/bridge")
async def bridge(id: str):
    return mgr.bridge.get(id, [])

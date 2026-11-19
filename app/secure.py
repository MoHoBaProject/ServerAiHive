"""قفل کلید API (middleware ASGI).

هدر Authorization: Bearer <کلید>  یا  Basic با کلید به‌جای رمز (برای مرورگر).
اگه فایل کلید نباشه یا کوتاه باشه، اپ بالا نمی‌آد (بسته می‌مونه، باز نمی‌شه).
"""
import base64
import hmac
import os
from pathlib import Path

from app.main import app as _inner

KEY_FILE = Path(os.environ.get("AIHIVE_KEY_FILE", str(Path.home() / "aihive-secrets" / "api.key")))


def _load_key() -> bytes:
    key = KEY_FILE.read_text().strip()
    if len(key) < 32:
        raise RuntimeError("کلید API کوتاه یا خالیه: " + str(KEY_FILE))
    return key.encode()


class KeyGuard:
    def __init__(self, app, key: bytes):
        self.app = app
        self.key = key

    def _ok(self, auth: str) -> bool:
        token = b""
        low = auth.lower()
        if low.startswith("bearer "):
            token = auth[7:].strip().encode()
        elif low.startswith("basic "):
            try:
                raw = base64.b64decode(auth[6:].strip()).decode("utf-8")
                token = raw.split(":", 1)[1].encode() if ":" in raw else b""
            except Exception:
                return False
        else:
            return False
        return hmac.compare_digest(token, self.key)

    async def __call__(self, scope, receive, send):
        if scope["type"] not in ("http", "websocket"):
            await self.app(scope, receive, send)
            return
        headers = dict(scope.get("headers") or [])
        auth = headers.get(b"authorization", b"").decode("latin-1")
        if self._ok(auth):
            await self.app(scope, receive, send)
            return
        if scope["type"] == "websocket":
            await send({"type": "websocket.close", "code": 1008})
            return
        body = b"Unauthorized"
        await send({
            "type": "http.response.start",
            "status": 401,
            "headers": [
                (b"content-type", b"text/plain; charset=utf-8"),
                (b"content-length", str(len(body)).encode()),
                (b"www-authenticate", b'Basic realm="AiHive", charset="UTF-8"'),
            ],
        })
        await send({"type": "http.response.body", "body": body})


app = KeyGuard(_inner, _load_key())

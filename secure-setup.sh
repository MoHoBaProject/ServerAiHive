#!/usr/bin/env bash
# قفل کلید API برای AiHive
# مسیر: ~/AiHive/aihive-py/aihive-py/secure-setup.sh
# نصب قفل:   bash secure-setup.sh
# تست قفل:   bash secure-setup.sh test      (اپ باید روشن باشه)
#
# کاری که نصب می‌کنه:
#   1) کلید ۶۴ حرفی تصادفی توی ~/aihive-secrets/api.key (دسترسی ۶۰۰؛ اگه بود، دست نمی‌خوره)
#   2) فایل app/secure.py (middleware: بدون کلید درست، جواب ۴۰۱)
#   3) توی run.sh عبارت app.main:app رو به app.secure:app عوض می‌کنه (بکاپ: run.sh.bak)
# کلید فقط توی فایل api.key می‌مونه؛ توی ریپو و چت نباید بره.
set -u

cd "$(dirname "$0")" || exit 1

SECRETS="$HOME/aihive-secrets"
KEYFILE="$SECRETS/api.key"
URL="http://127.0.0.1:8000/api/accounts"

if [ "${1:-}" = "test" ]; then
  if [ ! -f "$KEYFILE" ]; then
    echo "خطا: $KEYFILE نیست. اول بدون آرگومان اجرا کن: bash secure-setup.sh"
    exit 1
  fi
  KEY="$(tr -d '\r\n ' < "$KEYFILE")"
  C1="$(curl -s -o /dev/null -w '%{http_code}' --max-time 10 "$URL")"
  C2="$(curl -s -o /dev/null -w '%{http_code}' --max-time 10 -H "Authorization: Bearer $KEY" "$URL")"
  C3="$(curl -s -o /dev/null -w '%{http_code}' --max-time 10 -H "Authorization: Bearer wrong-key" "$URL")"
  echo "بدون کلید:   $C1   (باید 401 باشه)"
  echo "کلید غلط:    $C3   (باید 401 باشه)"
  echo "با کلید:     $C2   (باید 200 باشه)"
  if [ "$C1" = "401" ] && [ "$C3" = "401" ] && [ "$C2" = "200" ]; then
    echo "نتیجه: قفل درست کار می‌کنه."
    exit 0
  fi
  if [ "$C1" = "000" ]; then
    echo "نتیجه: اپ روشن نیست یا جواب نمی‌ده (000). اول bash run.sh"
  else
    echo "نتیجه: قفل درست کار نمی‌کنه. هیچ route عمومی نساز."
  fi
  exit 1
fi

if [ ! -f app/main.py ] || [ ! -f run.sh ]; then
  echo "خطا: این فایل باید کنار run.sh و پوشه‌ی app باشه (الان توی $(pwd))."
  exit 1
fi

umask 077
mkdir -p "$SECRETS"
chmod 700 "$SECRETS"

if [ -s "$KEYFILE" ]; then
  echo "کلید از قبل هست و دست نخورد: $KEYFILE"
else
  python3 -c 'import secrets; print(secrets.token_hex(32))' > "$KEYFILE"
  echo "کلید جدید ساخته شد: $KEYFILE"
fi
chmod 600 "$KEYFILE"

cat > app/secure.py <<'PYEOF'
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
PYEOF
echo "نوشته شد: app/secure.py"

if grep -q "app.secure:app" run.sh; then
  echo "run.sh از قبل روی app.secure:app هست."
else
  [ -f run.sh.bak ] || cp run.sh run.sh.bak
  sed -i 's/app\.main:app/app.secure:app/' run.sh
  if grep -q "app.secure:app" run.sh; then
    echo "run.sh عوض شد (بکاپ: run.sh.bak)."
  else
    echo "خطا: عبارت app.main:app توی run.sh پیدا نشد. محتوای run.sh رو بفرست."
    exit 1
  fi
fi

echo
echo "تموم شد. قدم بعدی: bash run.sh و بعد bash secure-setup.sh test"
echo "برای دیدن کلید (فقط برای خودت و دوستت، نه توی چت): cat $KEYFILE"

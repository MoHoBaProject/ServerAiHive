#!/usr/bin/env bash
# مرحله ۲ تونل با کانفیگ محلی: ساخت تونل، فایل کانفیگ و رکورد DNS
# مسیر: ~/AiHive/aihive-py/aihive-py/tunnel-create.sh
# اجرا:  bash tunnel-create.sh
# کاری که می‌کنه:
#   1) تونل جدید به اسم aihive-local می‌سازه (اگه بود، همون رو استفاده می‌کنه)
#   2) ~/.cloudflared/aihive.yml رو می‌نویسه (ingress به 127.0.0.1:8000)
#   3) رکورد DNS برای ساب‌دامین رو می‌سازه
# به تونل قبلی (سرویس aihive-cloudflared) دست نمی‌زنه و سرویس جدیدی راه نمی‌اندازه.
# همه‌ی فایل‌ها توی ~/.cloudflared هستن (بیرون از ریپو؛ هرگز commit نشن).
set -u

NAME="aihive-local"
HOST="${AIHIVE_HOST:-aihive.vertasquad.ir}"
CF_DIR="$HOME/.cloudflared"
CONF="$CF_DIR/aihive.yml"

BIN="$(command -v cloudflared || true)"
if [ -z "$BIN" ]; then
  echo "خطا: cloudflared پیدا نشد."
  exit 1
fi

if [ ! -f "$CF_DIR/cert.pem" ]; then
  echo "خطا: $CF_DIR/cert.pem نیست. اول tunnel-login.sh رو اجرا کن."
  exit 1
fi

PROXY="${AIHIVE_PROXY:-socks5://127.0.0.1:10808}"
if [ "$PROXY" != "none" ]; then
  if ! (echo > /dev/tcp/127.0.0.1/10808) 2>/dev/null; then
    echo "خطا: پروکسی روی 127.0.0.1:10808 جواب نمی‌ده."
    echo "بررسی کن: sudo systemctl status aihive-v2ray"
    exit 1
  fi
  export HTTPS_PROXY="$PROXY"
  export HTTP_PROXY="$PROXY"
  export ALL_PROXY="$PROXY"
  echo "از پروکسی استفاده می‌شه: $PROXY"
fi

get_id() {
  "$BIN" tunnel list --name "$NAME" --output json 2>/dev/null \
    | python3 -c 'import sys,json
try:
    d=json.load(sys.stdin)
except Exception:
    d=[]
print(d[0]["id"] if d else "")'
}

ID="$(get_id)"
if [ -z "$ID" ]; then
  echo "ساخت تونل $NAME ..."
  "$BIN" tunnel create "$NAME"
  rc=$?
  if [ "$rc" -ne 0 ]; then
    echo "ناموفق (کد خروج $rc): ساخت تونل خطا داد. خروجی بالا رو بفرست."
    exit 1
  fi
  ID="$(get_id)"
else
  echo "تونل $NAME از قبل هست."
fi

if [ -z "$ID" ]; then
  echo "خطا: شناسه‌ی تونل پیدا نشد."
  exit 1
fi

CRED="$CF_DIR/$ID.json"
if [ ! -f "$CRED" ]; then
  echo "خطا: فایل اعتبار $CRED نیست."
  echo "تونل قبلاً ساخته شده ولی فایلش اینجا نیست. بگو تا یه تونل با اسم دیگه بسازیم."
  exit 1
fi
chmod 600 "$CRED"

cat > "$CONF" <<EOF
tunnel: $ID
credentials-file: $CRED
ingress:
  - hostname: $HOST
    service: http://127.0.0.1:8000
  - service: http_status:404
EOF
chmod 600 "$CONF"
echo "کانفیگ نوشته شد: $CONF"

echo "ساخت رکورد DNS برای $HOST ..."
"$BIN" tunnel route dns "$NAME" "$HOST"
rc=$?
if [ "$rc" -ne 0 ]; then
  echo "هشدار (کد خروج $rc): ساخت DNS خطا داد. اگه نوشته 'already exists' مشکلی نیست."
  echo "وگرنه خروجی بالا رو بفرست."
fi

echo
echo "تموم شد."
echo "شناسه‌ی تونل: $ID"
echo "آدرس: https://$HOST"
echo "هنوز سرویسی برای این تونل راه نیفتاده؛ قدم بعدی همینه."

#!/usr/bin/env bash
# مرحله ۱ تونل با کانفیگ محلی: لاگین cloudflared برای دامنه‌ی vertasquad.ir
# مسیر: ~/AiHive/aihive-py/aihive-py/tunnel-login.sh
# اجرا:  bash tunnel-login.sh
# خروجی: فایل ~/.cloudflared/cert.pem (بیرون از ریپو؛ هرگز commit نشه)
set -u

BIN="$(command -v cloudflared || true)"
if [ -z "$BIN" ]; then
  echo "خطا: cloudflared پیدا نشد."
  exit 1
fi

CERT="$HOME/.cloudflared/cert.pem"
if [ -f "$CERT" ]; then
  echo "cert.pem از قبل هست: $CERT"
  echo "این مرحله لازم نیست. بگو تا قدم بعدی."
  exit 0
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

echo
echo "یه لینک چاپ می‌شه. کامل کپی کن، توی مرورگر گوشی باز کن،"
echo "وارد Cloudflare شو و دامنه‌ی vertasquad.ir رو انتخاب و Authorize کن."
echo "این پنجره رو نبند تا تموم بشه."
echo

"$BIN" tunnel login
rc=$?

echo
if [ -f "$CERT" ]; then
  chmod 600 "$CERT"
  echo "موفق: $CERT ساخته شد."
else
  echo "ناموفق (کد خروج $rc): cert.pem ساخته نشد. خروجی بالا رو بفرست."
  exit 1
fi

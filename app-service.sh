#!/usr/bin/env bash
# سرویس systemd برای خود اپ AiHive (با دسکتاپ مجازی Xvfb)
# مسیر: ~/AiHive/aihive-py/aihive-py/app-service.sh
# اجرا:  bash app-service.sh        (sudo رمز می‌خواد)
# کاری که می‌کنه:
#   1) اپ فعلی که با nohup بالا اومده (uvicorn) و دسکتاپ مجازی قدیمی (desktop.sh stop) رو می‌بنده
#   2) دو سرویس می‌سازه و enable و start می‌کنه:
#        aihive-xvfb  : فقط نمایشگر مجازی :99 (برای Chromium)
#        aihive-app   : خود اپ (bash run.sh) با ری‌استارت خودکار و شروع بعد از بوت
#   3) تست قفل رو اجرا می‌کنه
# به تونل، پروکسی و بقیه‌ی سرویس‌ها دست نمی‌زنه.
# لاگ اپ بعد از این: sudo journalctl -u aihive-app -n 50 --no-pager
# برای لاگین اولیه‌ی اکانت جدید همچنان: bash desktop.sh start  (Xvfb رو دوباره راه نمی‌اندازه، چون سرویس بالاست)
set -u

cd "$(dirname "$0")" || exit 1
DIR="$(pwd)"
RUNNER="$(id -un)"

if [ ! -f run.sh ] || [ ! -d .venv ] || [ ! -f app/secure.py ]; then
  echo "خطا: این فایل باید کنار run.sh و .venv و app/secure.py باشه (الان توی $DIR)."
  exit 1
fi

XVFB="$(command -v Xvfb || true)"
if [ -z "$XVFB" ]; then
  echo "خطا: Xvfb نصب نیست (install-desktop.sh رو اجرا کن)."
  exit 1
fi

echo "بستن اپ و دسکتاپ مجازی فعلی ..."
pkill -u "$RUNNER" -f "uvicorn app.secure:app" 2>/dev/null
sleep 3
if ss -ltn 2>/dev/null | grep -q '127.0.0.1:8000 '; then
  echo "خطا: پورت 8000 هنوز اشغاله. یه بار دیگه اجرا کن؛ اگه تکرار شد بگو."
  exit 1
fi
bash desktop.sh stop >/dev/null 2>&1
sleep 2
if pgrep -f "Xvfb :99" >/dev/null; then
  echo "هشدار: Xvfb :99 هنوز بالاست (احتمالاً خودش سرویسه). ادامه می‌دم."
fi
LEFT="$(pgrep -u "$RUNNER" -fc 'data/profiles' || true)"
if [ "${LEFT:-0}" != "0" ]; then
  echo "هشدار: $LEFT پروسه‌ی Chromium از قبل باز مونده؛ ممکنه قفل پروفایل بده. اگه اکانتی باز نشد بگو."
fi

sudo tee /etc/systemd/system/aihive-xvfb.service > /dev/null <<EOF
[Unit]
Description=AiHive virtual display (Xvfb :99)
After=network.target

[Service]
Type=simple
User=$RUNNER
ExecStart=$XVFB :99 -screen 0 1280x800x24
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

sudo tee /etc/systemd/system/aihive-app.service > /dev/null <<EOF
[Unit]
Description=AiHive app (uvicorn on 127.0.0.1:8000)
After=network-online.target aihive-v2ray.service aihive-xvfb.service
Wants=network-online.target aihive-v2ray.service aihive-xvfb.service

[Service]
Type=simple
User=$RUNNER
WorkingDirectory=$DIR
ExecStart=/usr/bin/bash $DIR/run.sh
Restart=on-failure
RestartSec=5
TimeoutStopSec=20

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable --now aihive-xvfb
sleep 2
sudo systemctl enable --now aihive-app
sleep 8

echo
echo "--- وضعیت:"
echo -n "aihive-xvfb: "; systemctl is-active aihive-xvfb
echo -n "aihive-app:  "; systemctl is-active aihive-app
echo "--- آخرین لاگ اپ:"
sudo journalctl -u aihive-app -n 8 --no-pager
echo
echo "--- تست قفل:"
bash secure-setup.sh test

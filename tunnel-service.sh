#!/usr/bin/env bash
# مرحله ۳ تونل: سرویس systemd برای تونل aihive-local
# مسیر: ~/AiHive/aihive-py/aihive-py/tunnel-service.sh
# اجرا:  bash tunnel-service.sh        (sudo رمز می‌خواد)
# کاری که می‌کنه:
#   1) سرویس aihive-local-tunnel رو می‌سازه و enable و start می‌کنه
#   2) وضعیت و آخرین لاگ رو نشون می‌ده
# به سرویس‌های قبلی (aihive-cloudflared و بقیه) و به ~/.cloudflared/config.yml دست نمی‌زنه.
# اتصال به لبه‌ی Cloudflare از راه ورودی cf-edge (127.0.0.1:7844) توی پروکسی v2ray انجام می‌شه.
set -u

NAME="aihive-local"
SVC="aihive-local-tunnel"
CONF="$HOME/.cloudflared/aihive.yml"

BIN="$(command -v cloudflared || true)"
if [ -z "$BIN" ]; then
  echo "خطا: cloudflared پیدا نشد."
  exit 1
fi

if [ ! -f "$CONF" ]; then
  echo "خطا: $CONF نیست. اول tunnel-create.sh رو اجرا کن."
  exit 1
fi

if ! (echo > /dev/tcp/127.0.0.1/7844) 2>/dev/null; then
  echo "خطا: ورودی cf-edge روی 127.0.0.1:7844 جواب نمی‌ده."
  echo "بررسی کن: sudo systemctl status aihive-v2ray"
  exit 1
fi

UNIT="/etc/systemd/system/$SVC.service"
sudo tee "$UNIT" > /dev/null <<EOF
[Unit]
Description=AiHive Cloudflare Tunnel (aihive-local)
After=network-online.target aihive-v2ray.service
Wants=network-online.target

[Service]
Type=simple
User=$USER
ExecStart=$BIN tunnel --no-autoupdate --protocol http2 --edge 127.0.0.1:7844 --config $CONF run $NAME
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable --now "$SVC"
sleep 8

echo
echo "--- وضعیت:"
systemctl is-active "$SVC"
echo "--- آخرین لاگ:"
sudo journalctl -u "$SVC" -n 15 --no-pager
echo
echo "اگه توی لاگ 'Registered tunnel connection' دیدی، تونل وصله."
echo "قدم بعدی: تست از بیرون شبکه (مرورگر گوشی با دیتای موبایل)."

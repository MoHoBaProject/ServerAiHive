#!/usr/bin/env bash
# نصب سرویس Tunnel جدید AiHive (جدا از تونل قدیمی vertasquad.ir)
# توکن روی همین سرور پرسیده می‌شه؛ توی چت و ریپو نرو.
set -euo pipefail

CF_BIN="$(command -v cloudflared)"
SECRETS="$HOME/aihive-secrets"
ENV_FILE="$SECRETS/cloudflared.env"
UNIT="/etc/systemd/system/aihive-cloudflared.service"

mkdir -p "$SECRETS"
chmod 700 "$SECRETS"

read -rsp "توکن تونل aihive رو paste کن (دیده نمی‌شه) و Enter بزن: " TOKEN
echo
if [[ ! "$TOKEN" == eyJ* ]]; then
  echo "خطا: توکن معتبر به نظر نمی‌رسه (باید با eyJ شروع بشه)." >&2
  exit 1
fi

umask 077
printf 'TUNNEL_TOKEN=%s\n' "$TOKEN" > "$ENV_FILE"
chmod 600 "$ENV_FILE"
unset TOKEN

sudo tee "$UNIT" >/dev/null <<EOF
[Unit]
Description=AiHive Cloudflare Tunnel
After=network-online.target
Wants=network-online.target

[Service]
User=$USER
EnvironmentFile=$ENV_FILE
ExecStart=$CF_BIN tunnel --no-autoupdate run
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable --now aihive-cloudflared
sleep 8

echo
echo "== وضعیت =="
systemctl is-active aihive-cloudflared || true
echo
echo "== آخرین لاگ‌ها =="
journalctl -u aihive-cloudflared -n 12 --no-pager | sed -E 's/eyJ[A-Za-z0-9_=-]+/***/g'

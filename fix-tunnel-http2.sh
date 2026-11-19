#!/usr/bin/env bash
# تغییر پروتکل تونل از QUIC (UDP) به HTTP/2 (TCP) چون UDP از ایران timeout می‌ده.
set -euo pipefail

UNIT="/etc/systemd/system/aihive-cloudflared.service"

sudo chmod 644 "$UNIT"

if sudo grep -q -- '--protocol http2' "$UNIT"; then
  echo "از قبل http2 هست."
else
  sudo sed -i 's|tunnel --no-autoupdate run|tunnel --no-autoupdate --protocol http2 run|' "$UNIT"
fi

grep ExecStart "$UNIT"

sudo systemctl daemon-reload
sudo systemctl restart aihive-cloudflared
sleep 10

echo
echo "== وضعیت =="
systemctl is-active aihive-cloudflared || true
echo
echo "== آخرین لاگ‌ها =="
journalctl -u aihive-cloudflared -n 10 --no-pager | sed -E 's/eyJ[A-Za-z0-9_=-]+/***/g'

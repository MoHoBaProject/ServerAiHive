#!/usr/bin/env bash
# تونل AiHive رو از راه پروکسی v2ray به لبه‌ی Cloudflare می‌رسونه.
# 1) به v2ray یه ورودی 127.0.0.1:7844 -> 198.41.192.167:7844 اضافه می‌کنه (با بکاپ)
# 2) سرویس aihive-cloudflared رو روی --edge 127.0.0.1:7844 می‌ذاره
# توجه: ری‌استارت aihive-v2ray چند ثانیه اتصال Chromiumهای باز رو قطع می‌کنه.
set -euo pipefail

CFG="$HOME/aihive-secrets/v2ray.json"
UNIT="/etc/systemd/system/aihive-cloudflared.service"
EDGE_IP="198.41.192.167"

cp -p "$CFG" "$CFG.bak"

python3 - "$CFG" "$EDGE_IP" <<'PY'
import json, sys
p, edge = sys.argv[1], sys.argv[2]
c = json.load(open(p))
ins = c.setdefault("inbounds", [])
if any(i.get("port") == 7844 for i in ins):
    print("ورودی 7844 از قبل هست.")
else:
    ins.append({
        "tag": "cf-edge",
        "listen": "127.0.0.1",
        "port": 7844,
        "protocol": "dokodemo-door",
        "settings": {"address": edge, "port": 7844, "network": "tcp"},
    })
    json.dump(c, open(p, "w"), indent=2)
    print("ورودی 7844 اضافه شد.")
PY

echo "== تست کانفیگ v2ray =="
if ! v2ray -test -config "$CFG" >/dev/null 2>&1; then
  echo "کانفیگ نامعتبره؛ بکاپ برگردونده شد." >&2
  cp -p "$CFG.bak" "$CFG"
  exit 1
fi
echo "OK"

sudo systemctl restart aihive-v2ray
sleep 4

echo
echo "== تست محلی 127.0.0.1:7844 (56 یا 35 = وصل شد، 28/7 = خراب) =="
set +e
curl -sk -o /dev/null --connect-timeout 12 https://127.0.0.1:7844
echo "exit code: $?"
set -e

if ! sudo grep -q -- '--edge' "$UNIT"; then
  sudo sed -i 's|--protocol http2 run|--protocol http2 --edge 127.0.0.1:7844 run|' "$UNIT"
fi
grep ExecStart "$UNIT"

sudo systemctl daemon-reload
sudo systemctl restart aihive-cloudflared
sleep 25

echo
echo "== وضعیت =="
systemctl is-active aihive-cloudflared || true
echo
echo "== لاگ تونل (Registered یعنی موفق) =="
journalctl -u aihive-cloudflared --since "1 min ago" --no-pager \
  | grep -E "Registered|ERR|WRN" \
  | grep -v "DNS local resolver" \
  | sed -E 's/eyJ[A-Za-z0-9_=-]+/***/g' \
  | tail -10 || echo "(چیزی پیدا نشد)"

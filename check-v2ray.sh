#!/usr/bin/env bash
# فقط می‌خونه. شناسه/آدرس خصوصی چاپ نمی‌شه.
echo "== تست: رسیدن به پورت 7844 لبه‌ی Cloudflare از راه پروکسی =="
curl -sk -o /dev/null --connect-timeout 12 \
  --socks5 127.0.0.1:10808 https://104.16.133.229:7844
echo "exit code: $?  (28 = timeout/بسته؛ هر عدد دیگه معمولاً یعنی اتصال TCP برقرار شده)"

echo
echo "== ساختار کانفیگ v2ray (بدون اطلاعات خصوصی) =="
python3 - <<'PY'
import json, os
p = os.path.expanduser("~/aihive-secrets/v2ray.json")
c = json.load(open(p))
print("کلیدهای اصلی:", list(c.keys()))
print("inbounds:")
for i in c.get("inbounds", []):
    print("  ", {k: i.get(k) for k in ("tag", "listen", "port", "protocol")})
print("outbounds:")
for o in c.get("outbounds", []):
    ss = o.get("streamSettings", {}) or {}
    print("  ", {"tag": o.get("tag"), "protocol": o.get("protocol"), "network": ss.get("network"), "security": ss.get("security")})
r = c.get("routing")
print("routing:", json.dumps(r, ensure_ascii=False) if r else "ندارد")
PY

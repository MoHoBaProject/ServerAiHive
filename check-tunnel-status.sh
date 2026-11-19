#!/usr/bin/env bash
# فقط می‌خونه. بعد از ۲۰ ثانیه صبر، خطوط مهم لاگ تونل رو نشون می‌ده.
sleep 20
echo "== وضعیت سرویس =="
systemctl is-active aihive-cloudflared

echo
echo "== خطوط مهم (Registered / ERR / WRN) از ۳ دقیقه‌ی اخیر =="
journalctl -u aihive-cloudflared --since "3 min ago" --no-pager \
  | grep -E "Registered|ERR|WRN" \
  | grep -v "DNS local resolver" \
  | sed -E 's/eyJ[A-Za-z0-9_=-]+/***/g' \
  | tail -15 || echo "(چیزی پیدا نشد)"

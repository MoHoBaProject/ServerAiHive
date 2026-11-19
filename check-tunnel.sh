#!/usr/bin/env bash
# فقط می‌خونه، چیزی تغییر نمی‌ده. محتوای json و cert.pem چاپ نمی‌شه.
echo "== ~/.cloudflared/config.yml =="
cat ~/.cloudflared/config.yml

echo
echo "== لیست Tunnelها =="
timeout 40 cloudflared tunnel list 2>&1 | head -30

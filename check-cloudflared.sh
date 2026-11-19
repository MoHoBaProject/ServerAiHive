#!/usr/bin/env bash
# فقط می‌خونه، چیزی تغییر نمی‌ده. توکن/اعتبارنامه چاپ نمی‌کنه.
echo "== نسخه =="
cloudflared --version 2>&1 | head -1

echo
echo "== سرویس‌های cloudflared =="
systemctl list-units --all --type=service 2>/dev/null | grep -i cloudflared || echo "هیچ سرویسی پیدا نشد"
systemctl list-unit-files 2>/dev/null | grep -i cloudflared || true

echo
echo "== پروسه‌های در حال اجرا =="
pgrep -a cloudflared | sed -E 's/(--token|tunnel run)[[:space:]]+[^[:space:]]+/\1 ***/g' || echo "هیچ پروسه‌ای نیست"

echo
echo "== /etc/cloudflared (فقط اسم فایل‌ها) =="
ls -la /etc/cloudflared 2>&1

echo
echo "== ~/.cloudflared (فقط اسم فایل‌ها) =="
ls -la ~/.cloudflared 2>&1

echo
echo "== پورت 8000 =="
ss -ltnp 2>/dev/null | grep ':8000' || echo "چیزی روی 8000 گوش نمی‌ده (run.sh خاموشه)"

#!/usr/bin/env bash
# فقط تست می‌کنه. اگه exit code برابر 28 باشه یعنی timeout (بسته)، هر عدد دیگه یعنی TCP وصل شده.
PROXY="127.0.0.1:10808"

t() {
  curl -sk -o /dev/null --connect-timeout 8 --socks5-hostname "$PROXY" "https://$1"
  echo "$1  ->  exit $?"
}

echo "== شاهد: پورت 443 از راه پروکسی (باید وصل بشه) =="
t 104.16.133.229:443
t cloudflare.com:443

echo
echo "== پورت 7844 روی هاست‌های مختلف لبه =="
t region1.v2.argotunnel.com:7844
t region2.v2.argotunnel.com:7844
t 198.41.192.167:7844
t 198.41.200.113:7844
t 104.16.133.229:7844

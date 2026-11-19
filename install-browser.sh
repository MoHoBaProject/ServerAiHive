#!/usr/bin/env bash
set -e
cd "$(dirname "$0")"
source .venv/bin/activate
# cdn.playwright.dev answers 403 from Iran; this mirror answered 200 in net-test.sh
export PLAYWRIGHT_DOWNLOAD_HOST=https://cdn.npmmirror.com/binaries/playwright
playwright install --no-shell chromium
echo "BROWSER DONE"

#!/usr/bin/env bash
set -e
cd "$(dirname "$0")"
# The server's /etc/apt/apt.conf.d/95proxy points to 127.0.0.1:1080, where nothing listens.
# Bypass that proxy for this run only; the system file is not touched.
NP="-o Acquire::http::Proxy=false -o Acquire::https::Proxy=false"
# docker.com and tailscale.com repos answer 403 from Iran, which makes "apt update" exit with an error.
# The Ubuntu lists still update, so the error is ignored here.
sudo apt $NP update || echo "WARN: apt update had errors (docker/tailscale repos), continuing"
sudo apt $NP install -y python3-venv git
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
export PLAYWRIGHT_DOWNLOAD_HOST=https://cdn.npmmirror.com/binaries/playwright
playwright install --no-shell chromium
playwright install-deps chromium || echo "DEPS_FAILED"
echo "SETUP DONE"

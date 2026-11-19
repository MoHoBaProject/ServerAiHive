#!/usr/bin/env bash
cd "$(dirname "$0")"
source .venv/bin/activate
# Chromium windows open on the virtual desktop started by desktop.sh
export DISPLAY=:99
uvicorn app.secure:app --host 127.0.0.1 --port 8000

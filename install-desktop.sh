#!/usr/bin/env bash
set -e
# Virtual desktop packages for the first login of each account (Xvfb + openbox + x11vnc + noVNC).
# Bypasses the dead apt proxy for this run only; docker/tailscale repo errors are ignored (they answer 403 from Iran).
NP="-o Acquire::http::Proxy=false -o Acquire::https::Proxy=false"
sudo apt $NP update || echo "WARN: apt update had errors, continuing"
sudo apt $NP install -y xvfb openbox x11vnc novnc websockify
echo "DESKTOP PACKAGES DONE"

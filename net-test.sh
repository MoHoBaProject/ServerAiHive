#!/usr/bin/env bash
# Prints the HTTP status of each address (000 = no answer, 403 = blocked for this location).
t() { printf "%-14s %s\n" "$1" "$(curl -s -o /dev/null -m 12 -w '%{http_code}' -I "$2")"; }
t github         https://github.com
t github-raw     https://raw.githubusercontent.com/
t github-objects https://objects.githubusercontent.com/
t pypi           https://pypi.org/simple/
t npmjs          https://registry.npmjs.org/
t google-chrome  https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
t cft-google     https://storage.googleapis.com/chrome-for-testing-public/159.0.8154.6/linux64/chrome-linux64.zip
t cft-npmmirror  https://cdn.npmmirror.com/binaries/playwright/builds/cft/159.0.8154.6/linux64/chrome-linux64.zip
t snap-store     https://api.snapcraft.io/
t cloudflare     https://api.cloudflare.com/
t claude-ai      https://claude.ai/
t chatgpt        https://chatgpt.com/

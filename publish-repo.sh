#!/usr/bin/env bash
# publish-repo.sh — push safe project files to GitHub (via local proxy)
# Place in the project root (the folder that contains app/), then: bash publish-repo.sh
set -euo pipefail

REPO_URL="https://github.com/MoHoBaProject/ServerAiHive.git"
PROXY="${AIHIVE_GIT_PROXY:-socks5h://127.0.0.1:10808}"

cd "$(dirname "$0")"
[ -d app ] || { echo "ERROR: app/ not found in $(pwd)"; exit 1; }

# 1) make sure secrets are ignored
touch .gitignore
for p in 'data/' '.venv/' '__pycache__/' '*.pyc' '*.key' '*.pem' '*.pem.old' '*.bak' \
         'AiHive-API.md' 'v2ray*.json' 'api.key' '.env'; do
  grep -qxF "$p" .gitignore || echo "$p" >> .gitignore
done

# 2) git init + identity (local only)
[ -d .git ] || git init -q
git checkout -q -B main
git config user.name  >/dev/null 2>&1 || git config user.name  "AiHive Server"
git config user.email >/dev/null 2>&1 || git config user.email "aihive@localhost"

git add -A

# 3) safety checks on what will be published
BAD=$(git ls-files | grep -Ei '(^|/)(data/|api\.key|.*\.pem|.*\.pem\.old|v2ray.*\.json|AiHive-API\.md|\.env)' || true)
if [ -n "$BAD" ]; then
  echo "ABORT: sensitive files are tracked:"; echo "$BAD"; exit 1
fi
KEYFILE="$HOME/aihive-secrets/api.key"
if [ -f "$KEYFILE" ]; then
  if git ls-files -z | xargs -0 grep -I -l -F -- "$(cat "$KEYFILE")" 2>/dev/null | grep -q .; then
    echo "ABORT: the API key text was found inside a tracked file."; exit 1
  fi
fi

echo "---- files to publish ----"
git ls-files
echo "--------------------------"
read -r -p "Looks right? Type yes to continue: " OK
[ "$OK" = "yes" ] || { echo "Cancelled."; exit 1; }

git commit -q -m "AiHive Python server: initial commit" || echo "(nothing new to commit)"

# 4) push (token is typed here, never stored)
read -r -s -p "GitHub token (hidden): " TOKEN; echo
AUTH=$(printf 'x-access-token:%s' "$TOKEN" | base64 -w0)
git -c http.proxy="$PROXY" -c "http.extraHeader=Authorization: Basic $AUTH" \
    push -u "$REPO_URL" main
unset TOKEN AUTH
echo "DONE: https://github.com/MoHoBaProject/ServerAiHive"

# First login of an account on the virtual desktop (start it first: bash desktop.sh start).
# Usage:  python login.py claude          -> creates a new account and opens its browser
#         python login.py claude acc1     -> reopens an existing account (acc1)
# Log in through noVNC on the phone, then close the browser window. Cookies stay in data/profiles/<id>.
# Chromium goes through a local SOCKS proxy (v2ray on 127.0.0.1:10808). Override with AIHIVE_PROXY,
# or set AIHIVE_PROXY=none to disable the proxy.
import os
import sys

from playwright.sync_api import sync_playwright

from app import providers
from app.store import DATA, Accounts, Store

os.environ.setdefault("DISPLAY", ":99")

PROXY = os.environ.get("AIHIVE_PROXY", "socks5://127.0.0.1:10808")

prov = providers.norm(sys.argv[1] if len(sys.argv) > 1 else providers.CLAUDE)
accs = Accounts(Store())
acc = accs.get(sys.argv[2]) if len(sys.argv) > 2 else accs.add(prov)
print("ACCOUNT:", acc.id, "|", acc.provider)

opts = {}
if PROXY and PROXY.lower() != "none":
    opts["proxy"] = {"server": PROXY}
    print("PROXY:", PROXY)

with sync_playwright() as p:
    ctx = p.chromium.launch_persistent_context(
        str(DATA / "profiles" / acc.id),
        headless=False,
        viewport=None,
        args=["--disable-blink-features=AutomationControlled"],
        ignore_default_args=["--enable-automation"],
        **opts,
    )
    page = ctx.pages[0] if ctx.pages else ctx.new_page()
    page.goto(providers.new_chat_url(acc.provider), wait_until="domcontentloaded")
    print("OPEN: log in through noVNC, then close the browser window.")
    ctx.wait_for_event("close", timeout=0)
print("DONE")

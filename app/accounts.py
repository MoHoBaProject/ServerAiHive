# Replaces the per-account WebView (MainActivity.newWeb) with a Playwright persistent Chromium context.
# One context per account = separate cookies/profile in data/profiles/<id>. inject.js is used unchanged.
import asyncio
import json
import os
import time
from pathlib import Path

from playwright.async_api import Error as PWError
from playwright.async_api import async_playwright

from . import providers
from .store import DATA, Accounts, Store

ASSETS = Path(__file__).resolve().parent.parent / "assets"

# Chromium goes through a local SOCKS proxy (v2ray service aihive-v2ray on 127.0.0.1:10808).
# Override with AIHIVE_PROXY, or set AIHIVE_PROXY=none to disable.
PROXY = os.environ.get("AIHIVE_PROXY", "socks5://127.0.0.1:10808")

# inject.js talks to window.AiHiveBridge.postMessage(...) (the old Android bridge); this maps it to Python.
SHIM = """
(() => {
  if (!['https://claude.ai', 'https://chatgpt.com'].includes(location.origin)) return;
  window.AiHiveBridge = { postMessage: (s) => { try { window.__aihive_post(String(s)); } catch (e) {} } };
})();
"""

EMPTY = {"found": False, "streaming": False, "text": "", "blocks": [], "thoughts": []}


class Manager:
    def __init__(self):
        self.store = Store()
        self.accs = Accounts(self.store)
        self.pw = None
        self.ctxs = {}
        self.bridge = {}  # account id -> messages posted by the page (EFFORT:..., LIMIT:...)
        self.seen = {}    # account id -> last reply text before the latest send

    async def start(self):
        self.pw = await async_playwright().start()

    async def stop(self):
        for c in list(self.ctxs.values()):
            try:
                await c.close()
            except PWError:
                pass
        self.ctxs.clear()
        if self.pw:
            await self.pw.stop()

    async def context(self, id):
        ctx = self.ctxs.get(id)
        if ctx:
            return ctx
        self.accs.get(id)  # KeyError if unknown
        opts = {}
        if PROXY and PROXY.lower() != "none":
            opts["proxy"] = {"server": PROXY}
        ctx = await self.pw.chromium.launch_persistent_context(
            str(DATA / "profiles" / id),
            headless=False,
            viewport=None,
            args=["--disable-blink-features=AutomationControlled"],
            ignore_default_args=["--enable-automation"],
            **opts,
        )

        async def on_msg(source, msg):
            url = source["page"].url or ""
            if any(url.startswith(o) for o in providers.ORIGINS):
                lst = self.bridge.setdefault(id, [])
                lst.append(msg)
                del lst[:-100]

        await ctx.expose_binding("__aihive_post", on_msg)
        await ctx.add_init_script(SHIM)
        await ctx.add_init_script(path=str(ASSETS / "inject.js"))
        ctx.on("close", lambda *_: self.ctxs.pop(id, None))
        self.ctxs[id] = ctx
        return ctx

    async def page(self, id):
        ctx = await self.context(id)
        pages = [p for p in ctx.pages if not p.is_closed()]
        return pages[0] if pages else await ctx.new_page()

    async def _ev(self, p, expr, arg=None):
        try:
            return await (p.evaluate(expr, arg) if arg is not None else p.evaluate(expr))
        except PWError:
            return None  # page navigating / not ready

    async def open(self, id, new_chat=True):
        prov = self.accs.get(id).provider
        p = await self.page(id)
        if not providers.is_site(p.url, prov) or (new_chat and not providers.is_new_chat(p.url, prov)):
            await p.goto(providers.new_chat_url(prov), wait_until="domcontentloaded")
        return p

    async def info(self, id):
        p = await self.page(id)
        raw = await self._ev(p, "window.__mc ? window.__mc.info() : null")
        return json.loads(raw) if raw else {"url": p.url, "hasComposer": False}

    async def _reply_raw(self, p):
        raw = await self._ev(p, "window.__mc ? window.__mc.lastReplyText() : null")
        try:
            return json.loads(raw) if raw else dict(EMPTY)
        except ValueError:
            return dict(EMPTY)

    async def _wait_composer(self, p, timeout=30):
        t0 = time.monotonic()
        while time.monotonic() - t0 < timeout:
            if await self._ev(p, "!!(window.__mc && window.__mc.composer())"):
                await asyncio.sleep(1.0)  # let the page finish hydrating
                return True
            await asyncio.sleep(0.5)
        return False

    async def send(self, id, text, new_chat=True):
        p = await self.open(id, new_chat)
        if not await self._wait_composer(p):
            return {"ok": False, "step": "composer", "error": "composer not found (not logged in?)"}
        self.seen[id] = "" if new_chat else (await self._reply_raw(p)).get("text", "")
        res = None
        for _ in range(4):
            res = await self._ev(p, "t => window.__mc.insert(t)", text)
            await asyncio.sleep(0.4)
            filled = await self._ev(p, "(() => { const c = window.__mc.composer(); return !!c && (c.innerText || '').trim().length > 0; })()")
            if res == "OK" and filled:
                break
        else:
            return {"ok": False, "step": "insert", "error": str(res)}
        await asyncio.sleep(0.9)
        for _ in range(6):
            res = await self._ev(p, "window.__mc.send()")
            if res == "SENT":
                return {"ok": True}
            await asyncio.sleep(0.5)
        return {"ok": False, "step": "send", "error": str(res)}

    async def reply(self, id, timeout=300, poll=1.0):
        p = await self.page(id)
        base = self.seen.get(id, "")
        t0 = time.monotonic()
        started, stable, last, r = False, 0, None, dict(EMPTY)
        while time.monotonic() - t0 < timeout:
            r = await self._reply_raw(p)
            text = r.get("text", "")
            if r.get("found") and (r.get("streaming") or text != base):
                started = True
            if started:
                stable = stable + 1 if (not r.get("streaming") and text == last) else 0
                last = text
                if stable >= 2 and text.strip():
                    return {"ok": True, **r}
            await asyncio.sleep(poll)
        return {"ok": False, "error": "timeout", **r}

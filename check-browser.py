# Checks that the installed Chromium can start on this server (new headless mode, no display needed).
from playwright.sync_api import sync_playwright

with sync_playwright() as p:
    b = p.chromium.launch(channel="chromium", headless=True)
    page = b.new_page()
    page.goto("data:text/html,<title>ok</title>")
    print("OK", b.version, page.title())
    b.close()

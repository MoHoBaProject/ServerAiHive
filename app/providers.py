# Port of Provider.kt (without the Android UI parts).
CLAUDE = "claude"
CHATGPT = "chatgpt"
ALL = [CLAUDE, CHATGPT]

# origins allowed to talk to the app through the AiHiveBridge channel
ORIGINS = {"https://claude.ai", "https://chatgpt.com"}


def norm(p):
    return CHATGPT if p == CHATGPT else CLAUDE


def label(p):
    return "ChatGPT" if p == CHATGPT else "Claude"


def host(p):
    return "chatgpt.com" if p == CHATGPT else "claude.ai"


def base(p):
    return "https://" + host(p)


def new_chat_url(p):
    return "https://chatgpt.com/" if p == CHATGPT else "https://claude.ai/new"


def is_site(url, p):
    return bool(url) and url.startswith(base(p))


def is_new_chat(url, p):
    if not url:
        return False
    n = new_chat_url(p)
    if url == n or url.startswith(n + "?") or url.startswith(n + "#"):
        return True
    b = base(p)
    return p == CHATGPT and (url == b or url.startswith(b + "/?") or url.startswith(b + "/#"))


def is_chat(url, p):
    return bool(url) and ("chatgpt.com/c/" if p == CHATGPT else "claude.ai/chat/") in url

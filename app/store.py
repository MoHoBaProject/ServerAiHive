# Port of Store.kt + the account list (accounts.json keeps the same keys as the Android app).
import json
import os
from dataclasses import dataclass
from pathlib import Path

from . import providers

DATA = Path(__file__).resolve().parent.parent / "data"


class Store:
    def __init__(self, root=DATA):
        self.root = Path(root)
        self.root.mkdir(parents=True, exist_ok=True)

    def _f(self, name):
        return self.root / name

    def exists(self, name):
        return self._f(name).exists()

    def read(self, name):
        return self._f(name).read_text(encoding="utf-8")

    def write(self, name, text):
        f = self._f(name)
        f.parent.mkdir(parents=True, exist_ok=True)
        tmp = f.with_suffix(f.suffix + ".tmp")
        tmp.write_text(text, encoding="utf-8")
        os.replace(tmp, f)


@dataclass
class Account:
    id: str
    name: str
    auto: bool = True
    email: str = ""
    custom: bool = False
    tokens: str = "unknown"  # ok | limited | unknown
    tokenNote: str = ""
    checkedAt: int = 0
    group: str = ""
    provider: str = providers.CLAUDE

    def to_json(self):
        return dict(self.__dict__)

    @staticmethod
    def from_json(o):
        return Account(
            id=o["id"], name=o["name"], auto=o.get("auto", True), email=o.get("email", ""),
            custom=o.get("custom", False), tokens=o.get("tokens", "unknown"),
            tokenNote=o.get("tokenNote", ""), checkedAt=o.get("checkedAt", 0),
            group=o.get("group", ""), provider=providers.norm(o.get("provider")),
        )


class Accounts:
    FILE = "accounts.json"

    def __init__(self, store):
        self.store = store

    def load(self):
        try:
            if self.store.exists(self.FILE):
                return [Account.from_json(o) for o in json.loads(self.store.read(self.FILE))]
        except Exception:
            pass
        return []

    def save(self, accs):
        self.store.write(self.FILE, json.dumps([a.to_json() for a in accs], ensure_ascii=False))

    def get(self, id):
        for a in self.load():
            if a.id == id:
                return a
        raise KeyError(id)

    def add(self, provider=providers.CLAUDE):
        accs = self.load()
        n = 1
        while any(a.id == f"acc{n}" for a in accs):
            n += 1
        acc = Account(f"acc{n}", f"Account {n}", provider=providers.norm(provider))
        accs.append(acc)
        self.save(accs)
        return acc

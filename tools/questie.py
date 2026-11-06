"""Read QuestieDB's WoW Forever data (quests, NPCs) from data/questie.

QuestieDB: https://github.com/Questie/QuestieDB (GPL-3.0). Files are Lua tables, one entry per line.
Usage:
    py tools\\questie.py fetch                  download the Forever quest and NPC files
    py tools\\questie.py givers <zoneID> [min] [max]   quests started by NPCs standing in a zone
"""
from __future__ import annotations

import re
import sys
import urllib.request
from pathlib import Path

DIR = Path(__file__).resolve().parent.parent / "data" / "questie"
RAW = "https://raw.githubusercontent.com/Questie/QuestieDB/master/data/Forever/{name}.lua"
FILES = ("foreverQuestDB", "foreverNpcDB", "foreverObjectDB", "foreverItemDB")
ENTRY = re.compile(r"^\[(\d+)\] = (\{.*\}),\s*$")
TROLL, ROGUE = 128, 8


class LuaReader:
    """Parses Lua literal tables: strings, numbers, nil, true/false, {..} with [k]= keys."""

    def __init__(self, text: str) -> None:
        self.s, self.i = text, 0

    def ws(self) -> None:
        while self.i < len(self.s) and self.s[self.i] in " \t\r\n":
            self.i += 1

    def value(self):
        self.ws()
        c = self.s[self.i]
        if c == "{":
            return self.table()
        if c in "'\"":
            return self.string(c)
        m = re.compile(r"-?[0-9.eE+-]+|nil|true|false").match(self.s, self.i)
        self.i = m.end()
        tok = m.group()
        if tok == "nil":
            return None
        if tok in ("true", "false"):
            return tok == "true"
        return float(tok) if any(ch in tok for ch in ".eE") else int(tok)

    def string(self, q: str) -> str:
        self.i += 1
        out = []
        while self.s[self.i] != q:
            if self.s[self.i] == "\\":
                self.i += 1
            out.append(self.s[self.i])
            self.i += 1
        self.i += 1
        return "".join(out)

    def table(self) -> dict:
        self.i += 1
        out, n = {}, 1
        while True:
            self.ws()
            if self.s[self.i] == "}":
                self.i += 1
                return out
            if self.s[self.i] == "[":
                self.i += 1
                key = self.value()
                self.ws()
                self.i += 1  # ]
                self.ws()
                self.i += 1  # =
                out[key] = self.value()
            else:
                out[n] = self.value()
                n += 1
            self.ws()
            if self.s[self.i] == ",":
                self.i += 1


def load(name: str) -> dict[int, dict]:
    out = {}
    for line in (DIR / f"{name}.lua").read_text(encoding="utf-8").splitlines():
        m = ENTRY.match(line)
        if m:
            out[int(m.group(1))] = LuaReader(m.group(2)).value()
    return out


def fetch() -> None:
    DIR.mkdir(parents=True, exist_ok=True)
    for name in FILES:
        req = urllib.request.Request(RAW.format(name=name), headers={"User-Agent": "SoloAddons (personal)"})
        with urllib.request.urlopen(req, timeout=120) as r:
            (DIR / f"{name}.lua").write_bytes(r.read())
        print(f"{name}.lua downloaded")


def ids(v) -> list:
    return [x for _, x in sorted(v.items())] if isinstance(v, dict) else []


def givers(zone: int, lo: int, hi: int) -> None:
    npcs, quests = load("foreverNpcDB"), load("foreverQuestDB")
    for nid, n in npcs.items():
        spawns = n.get(7) or {}
        if zone not in spawns:
            continue
        x, y = (spawns[zone].get(1) or {}).get(1), (spawns[zone].get(1) or {}).get(2)
        for qid in ids(n.get(10)):
            q = quests.get(qid)
            if not q:
                continue
            lvl, req = q.get(5) or 0, q.get(4) or 0
            races, classes = q.get(6) or 0, q.get(7) or 0
            if not (lo <= lvl <= hi) or (races and not races & TROLL) or (classes and not classes & ROGUE):
                continue
            pre = ids(q.get(12)) + ([q[13]] if isinstance(q.get(13), int) else ids(q.get(13)))
            nxt = q.get(22)
            obj = " ".join(ids(q.get(8)))[:160]
            print(f"{qid}|{q.get(1)}|lvl {lvl} req {req}|zoneSort {q.get(17)}|giver {n.get(1)} ({x}, {y})"
                  f"|pre {pre}|next {nxt}|{obj}")


if __name__ == "__main__":
    if sys.argv[1:2] == ["fetch"]:
        fetch()
    elif sys.argv[1:2] == ["givers"]:
        a = sys.argv[2:]
        givers(int(a[0]), int(a[1]) if len(a) > 1 else 1, int(a[2]) if len(a) > 2 else 60)
    else:
        print(__doc__)

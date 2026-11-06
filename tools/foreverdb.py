"""ForeverDB API client (https://foreverdb.net/developers). Data from ForeverDB.net: credit it wherever shown.

Key in tools/foreverdb.json as {"key": "fdb_..."} (git-ignored; never print or share it).
Answers are cached in data/foreverdb/ so each path is fetched once; --fresh refetches.
Limits: 60 a minute, 10,000 a day. This client waits 1.1 s between requests.
Usage:
    py tools\\foreverdb.py get <path> [--fresh]     e.g. meta, dungeons, dungeons/36, quests/924
    py tools\\foreverdb.py all <path>               every page of a list (limit 100, offset ...)
"""
from __future__ import annotations

import json
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

BASE = "https://foreverdb.net/api/v1/"
ROOT = Path(__file__).resolve().parent.parent
KEY_FILE = Path(__file__).with_name("foreverdb.json")
CACHE = ROOT / "data" / "foreverdb"
_last = 0.0


def _key() -> str:
    return json.loads(KEY_FILE.read_text(encoding="utf-8"))["key"]


def _cache_file(path: str) -> Path:
    safe = path.strip("/").replace("/", "__").replace("?", "_").replace("&", "_").replace("=", "-")
    return CACHE / f"{safe}.json"


def get(path: str, fresh: bool = False) -> dict:
    """GET /api/v1/<path>, cached. Raises on HTTP errors except 429, which waits and retries."""
    global _last
    cache = _cache_file(path)
    if cache.exists() and not fresh:
        return json.loads(cache.read_text(encoding="utf-8"))
    while True:
        wait = 1.1 - (time.time() - _last)
        if wait > 0:
            time.sleep(wait)
        _last = time.time()
        req = urllib.request.Request(BASE + path.lstrip("/"),
                                     headers={"X-API-Key": _key(), "User-Agent": "SoloAddons (personal, github.com/Protowind/solo-addons)"})
        try:
            with urllib.request.urlopen(req, timeout=60) as r:
                data = json.loads(r.read().decode("utf-8"))
                left = r.headers.get("X-Daily-Remaining")
            break
        except urllib.error.HTTPError as e:
            if e.code == 429:
                time.sleep(int(e.headers.get("Retry-After", "30")))
                continue
            raise
    CACHE.mkdir(parents=True, exist_ok=True)
    cache.write_text(json.dumps(data, indent=1, ensure_ascii=False), encoding="utf-8")
    if left is not None and int(left) < 500:
        print(f"warning: {left} ForeverDB requests left today", file=sys.stderr)
    return data


def get_all(path: str, fresh: bool = False) -> list:
    """Every page of a list endpoint."""
    out, offset = [], 0
    sep = "&" if "?" in path else "?"
    while True:
        page = get(f"{path}{sep}limit=100&offset={offset}", fresh)
        items = page.get("data") or []
        out.extend(items)
        total = (page.get("meta") or {}).get("total")
        offset += len(items)
        if not items or (total is not None and offset >= total):
            return out


def main() -> None:
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    fresh = "--fresh" in sys.argv
    if len(args) == 2 and args[0] == "get":
        print(json.dumps(get(args[1], fresh), indent=1, ensure_ascii=False)[:6000])
    elif len(args) == 2 and args[0] == "all":
        items = get_all(args[1], fresh)
        print(f"{len(items)} items")
        print(json.dumps(items[:3], indent=1, ensure_ascii=False)[:3000])
    else:
        print(__doc__)


if __name__ == "__main__":
    main()

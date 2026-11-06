"""Test client for Blizzard's WoW Game Data API.

Keys live in tools/blizzard_api.json (never commit or share):
    {"client_id": "...", "client_secret": "..."}

Usage:
    py tools/blizzard_api.py item 25
    py tools/blizzard_api.py item 25 --namespace static-classic1x   (Classic Era)
    py tools/blizzard_api.py raw /data/wow/quest/924
    py tools/blizzard_api.py raw /data/wow/item-class/index
"""

import argparse
import base64
import json
import urllib.parse
import urllib.request
from pathlib import Path

KEYS_FILE = Path(__file__).with_name("blizzard_api.json")
REGION = "eu"
LOCALE = "en_GB"
# WoW Forever (undocumented, found working 2026-11-06; serves data build 1.60.1_70399, older than live,
# so newer Forever items 404). Use static-classic1x for Classic Era.
DEFAULT_NAMESPACE = "static-forever"


def get_token() -> str:
    keys = json.loads(KEYS_FILE.read_text(encoding="utf-8"))
    auth = base64.b64encode(f"{keys['client_id']}:{keys['client_secret']}".encode()).decode()
    request = urllib.request.Request(
        "https://oauth.battle.net/token",
        data=b"grant_type=client_credentials",
        headers={"Authorization": f"Basic {auth}"},
    )
    with urllib.request.urlopen(request, timeout=15) as response:
        return json.load(response)["access_token"]


def get(path: str, namespace: str, token: str) -> dict:
    query = urllib.parse.urlencode({"namespace": f"{namespace}-{REGION}", "locale": LOCALE})
    url = f"https://{REGION}.api.blizzard.com{path}?{query}"
    request = urllib.request.Request(url, headers={"Authorization": f"Bearer {token}"})
    with urllib.request.urlopen(request, timeout=15) as response:
        return json.load(response)


def summarise_item(item: dict) -> str:
    preview = item.get("preview_item", {})
    lines = [
        f"{item['id']}: {item['name']} ({item['quality']['name']})",
        f"  {item['item_class']['name']} / {item['item_subclass']['name']}, "
        f"{item['inventory_type']['name']}, item level {item['level']}, "
        f"required level {item['required_level']}",
        f"  sells for {item.get('sell_price', 0)} copper",
    ]
    if "armor" in preview:
        lines.append(f"  {preview['armor']['display']['display_string']}")
    for stat in preview.get("stats", []):
        lines.append(f"  {stat['display']['display_string']}")
    return "\n".join(lines)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("kind", choices=["item", "raw"])
    parser.add_argument("target", help="item ID, or an API path for raw")
    parser.add_argument("--namespace", default=DEFAULT_NAMESPACE)
    args = parser.parse_args()

    token = get_token()
    if args.kind == "item":
        print(summarise_item(get(f"/data/wow/item/{args.target}", args.namespace, token)))
    else:
        print(json.dumps(get(args.target, args.namespace, token), indent=2))


if __name__ == "__main__":
    main()

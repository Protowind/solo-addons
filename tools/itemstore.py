"""Local WoW Forever item store, one snapshot per build, with an item changelog between builds.

Data comes from wago.tools (the game's own ItemSparse + Item tables per build).
Store: data/items.db (SQLite). Raw CSVs: data/raw/<build>/. Changelogs: data/changelog/.

Usage:
    py tools/itemstore.py fetch 1.60.1.70450
    py tools/itemstore.py builds
    py tools/itemstore.py diff 1.60.1.70425 1.60.1.70450
    py tools/itemstore.py find "Footman Tunic"
"""

import argparse
import csv
import sqlite3
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DATA = ROOT / "data"
DB_PATH = DATA / "items.db"
CSV_URL = "https://wago.tools/db2/{table}/csv?build={build}"
USER_AGENT = "SoloAddons item store (personal)"

STAT_NAMES = {
    0: "Mana", 1: "Health", 3: "Agility", 4: "Strength", 5: "Intellect", 6: "Spirit", 7: "Stamina",
    12: "Defense", 13: "Dodge", 14: "Parry", 15: "Block", 31: "Hit", 32: "Crit", 35: "Resilience",
    36: "Haste", 37: "Expertise", 38: "Attack Power", 40: "Versatility", 45: "Spell Power", 49: "Mastery",
}
SLOT_NAMES = {
    0: "", 1: "Head", 2: "Neck", 3: "Shoulder", 4: "Shirt", 5: "Chest", 6: "Waist", 7: "Legs", 8: "Feet",
    9: "Wrist", 10: "Hands", 11: "Finger", 12: "Trinket", 13: "One-Hand", 14: "Shield", 15: "Ranged",
    16: "Back", 17: "Two-Hand", 18: "Bag", 19: "Tabard", 20: "Chest", 21: "Main Hand", 22: "Off Hand",
    23: "Held In Off-hand", 24: "Ammo", 25: "Thrown", 26: "Ranged", 28: "Relic",
}
QUALITY_NAMES = {0: "Poor", 1: "Common", 2: "Uncommon", 3: "Rare", 4: "Epic", 5: "Legendary", 6: "Artifact", 7: "Heirloom"}

# Columns compared between builds, in report order
FIELDS = ["name", "quality", "item_level", "required_level", "slot", "class_id", "subclass_id",
          "sell_price", "buy_price", "allowable_class", "stats", "item_set", "bonding"]

SCHEMA = f"""
CREATE TABLE IF NOT EXISTS builds (build TEXT PRIMARY KEY, fetched_at TEXT DEFAULT CURRENT_TIMESTAMP, items INTEGER);
CREATE TABLE IF NOT EXISTS items (
    build TEXT, id INTEGER, {", ".join(f + (" INTEGER" if f not in ("name", "slot", "stats", "quality") else " TEXT") for f in FIELDS)},
    PRIMARY KEY (build, id)
);
"""


def download(table: str, build: str) -> Path:
    out = DATA / "raw" / build / f"{table}.csv"
    if out.exists():
        return out
    out.parent.mkdir(parents=True, exist_ok=True)
    request = urllib.request.Request(CSV_URL.format(table=table, build=build), headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(request, timeout=300) as response:
        out.write_bytes(response.read())
    return out


def read_csv(path: Path) -> list[dict]:
    with path.open(encoding="utf-8", newline="") as f:
        return list(csv.DictReader(f))


def stats_text(row: dict) -> str:
    # Stat amounts scale with item level; the table stores each stat's share of the budget
    parts = []
    for i in range(10):
        stat = int(row[f"StatModifier_bonusStat_{i}"])
        share = int(row[f"StatPercentEditor_{i}"])
        if stat >= 0 and share:
            parts.append(f"{STAT_NAMES.get(stat, f'stat {stat}')} {share / 100:g}%")
    return ", ".join(parts)


def fetch(build: str) -> None:
    sparse = read_csv(download("ItemSparse", build))
    base = {r["ID"]: r for r in read_csv(download("Item", build))}
    db = connect()
    db.execute("DELETE FROM items WHERE build = ?", (build,))
    rows = []
    for r in sparse:
        b = base.get(r["ID"], {})
        rows.append((
            build, int(r["ID"]), r["Display_lang"],
            QUALITY_NAMES.get(int(r["OverallQualityID"]), r["OverallQualityID"]),
            int(r["ItemLevel"]), int(r["RequiredLevel"]),
            SLOT_NAMES.get(int(r["InventoryType"]), r["InventoryType"]),
            int(b.get("ClassID", -1)), int(b.get("SubclassID", -1)),
            int(r["SellPrice"]), int(r["BuyPrice"]), int(r["AllowableClass"]),
            stats_text(r), int(r["ItemSet"]), int(r["Bonding"]),
        ))
    db.executemany(f"INSERT INTO items VALUES ({', '.join('?' * (len(FIELDS) + 2))})", rows)
    db.execute("INSERT OR REPLACE INTO builds (build, items) VALUES (?, ?)", (build, len(rows)))
    db.commit()
    print(f"{build}: {len(rows)} items stored in {DB_PATH}")


def connect() -> sqlite3.Connection:
    DATA.mkdir(parents=True, exist_ok=True)
    db = sqlite3.connect(DB_PATH)
    db.executescript(SCHEMA)
    return db


def load(db: sqlite3.Connection, build: str) -> dict[int, dict]:
    cur = db.execute(f"SELECT id, {', '.join(FIELDS)} FROM items WHERE build = ?", (build,))
    items = {row[0]: dict(zip(FIELDS, row[1:])) for row in cur}
    if not items:
        raise SystemExit(f"Build {build} not in the store. Run: fetch {build}")
    return items


def diff(old: str, new: str) -> None:
    db = connect()
    before, after = load(db, old), load(db, new)
    added = sorted(set(after) - set(before))
    removed = sorted(set(before) - set(after))
    changed = []
    for item_id in sorted(set(before) & set(after)):
        changes = [(f, before[item_id][f], after[item_id][f]) for f in FIELDS
                   if before[item_id][f] != after[item_id][f]]
        if changes:
            changed.append((item_id, changes))

    lines = [f"# Item changes {old} to {new}", "",
             f"- Added: {len(added)}", f"- Removed: {len(removed)}", f"- Changed: {len(changed)}", ""]
    if added:
        lines += ["## Added", ""]
        lines += [f"- {i} {after[i]['name']} ({after[i]['quality']}, {after[i]['slot'] or 'no slot'}, "
                  f"ilvl {after[i]['item_level']})" for i in added] + [""]
    if removed:
        lines += ["## Removed", ""]
        lines += [f"- {i} {before[i]['name']}" for i in removed] + [""]
    if changed:
        lines += ["## Changed", ""]
        for item_id, changes in changed:
            lines.append(f"- {item_id} {after[item_id]['name']}")
            lines += [f"  - {f}: {a!r} -> {b!r}" for f, a, b in changes]
        lines.append("")

    out = DATA / "changelog" / f"{old}_to_{new}.md"
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text("\n".join(lines), encoding="utf-8")
    print("\n".join(lines[:5]))
    print(f"Written to {out}")


def builds() -> None:
    for build, fetched, count in connect().execute("SELECT build, fetched_at, items FROM builds ORDER BY build"):
        print(f"{build}  {count} items  (fetched {fetched})")


def find(name: str) -> None:
    cur = connect().execute(
        f"SELECT build, id, {', '.join(FIELDS)} FROM items WHERE name LIKE ? ORDER BY id, build",
        (f"%{name}%",))
    for row in cur:
        print(row[0], row[1], dict(zip(FIELDS, row[2:])))


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = parser.add_subparsers(dest="cmd", required=True)
    sub.add_parser("fetch").add_argument("build")
    sub.add_parser("builds")
    d = sub.add_parser("diff")
    d.add_argument("old")
    d.add_argument("new")
    sub.add_parser("find").add_argument("name")
    args = parser.parse_args()

    if args.cmd == "fetch":
        fetch(args.build)
    elif args.cmd == "builds":
        builds()
    elif args.cmd == "diff":
        diff(args.old, args.new)
    else:
        find(args.name)


if __name__ == "__main__":
    main()

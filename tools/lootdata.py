"""Write SoloLoot/Data.lua: dungeon and raid bosses with their drops, and item sets.

Instances: Map + AreaTable from wago.tools (live build). Bosses and drops: QuestieDB's Forever NPC
and item data (who drops what). Item quality and levels: data/items.db (live build).
A boss here is an NPC in the instance that drops at least one uncommon-or-better item that at most
MAX_DROPPERS creatures drop (so world drops and trash loot are left out).
Usage: py tools\\lootdata.py [build]   (run tools\\questie.py fetch first for fresh QuestieDB data)
"""
from __future__ import annotations

import sqlite3
import sys
from collections import defaultdict
from pathlib import Path

from itemstore import download, read_csv
from questie import load, ids

BUILD = "1.60.1.70790"
ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "SoloLoot" / "Data.lua"
MAX_DROPPERS = 6        # dungeons
MAX_DROPPERS_RAID = 20  # raid bosses share loot tables
# QuestieDB gives these no zone; Questie zone IDs some maps use that the game tables do not link
ZONE_FIX = {11502: 2717, 3654: 718, 8443: 1477, 11519: 2437}
MAP_ZONES = {230: {1585}}
# New Forever dungeons have no entrance in the game files: where Blizzard's dungeon post puts them
# (news.blizzard.com/en-us/article/24301455, Nov 2026)
WHERE = {
    3065: "Beneath Ironforge, Dun Morogh (Alliance land)",
    2999: "Ruins above the Undercity, Tirisfal Glades",
    2998: "Above Whelgar's Excavation, southern Wetlands",
    2959: "Dalaran, Alterac Mountains (attunement quest first)",
}
MIN_OWN = 2
NEIGHBOURS = 12
QUALITY = {"Poor": 0, "Common": 1, "Uncommon": 2, "Rare": 3, "Epic": 4, "Legendary": 5}
SKIP_MAPS = {13, 29, 44, 169, 269}  # test and unused maps


def lua_str(s: str) -> str:
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'


def live_items(build: str) -> dict[int, tuple]:
    db = sqlite3.connect(ROOT / "data" / "items.db")
    rows = db.execute("SELECT id, name, quality, item_level, required_level, allowable_class, item_set "
                      "FROM items WHERE build = ?", (build,))
    return {r[0]: (r[1], QUALITY.get(r[2], 1), r[3], r[4], r[5], r[6]) for r in rows}


def instances(build: str) -> list[dict]:
    areas = read_csv(download("AreaTable", build))
    out = []
    for m in read_csv(download("Map", build)):
        if m["InstanceType"] not in ("1", "2") or int(m["ID"]) in SKIP_MAPS:
            continue
        zones = {int(a["ID"]) for a in areas if a["ContinentID"] == m["ID"] and a["ParentAreaID"] == "0"}
        zones |= {int(a["ID"]) for a in areas if a["AreaName_lang"] == m["MapName_lang"]}
        zones |= MAP_ZONES.get(int(m["ID"]), set())
        if m["AreaTableID"] != "0":
            zones.add(int(m["AreaTableID"]))
        grew = True
        while grew:   # sub-areas of those zones
            more = {int(a["ID"]) for a in areas if int(a["ParentAreaID"] or 0) in zones} - zones
            zones |= more
            grew = bool(more)
        corpse = None
        if m["CorpseMapID"] not in ("-1", "") and (float(m["Corpse_0"]) or float(m["Corpse_1"])):
            corpse = (int(m["CorpseMapID"]), float(m["Corpse_0"]), float(m["Corpse_1"]))
        out.append({"map": int(m["ID"]), "name": m["MapName_lang"],
                    "raid": m["InstanceType"] == "2", "zones": set(zones), "corpse": corpse})
    return out


def foreverdb_dungeons() -> dict[int, dict]:
    """ForeverDB dungeon details by map ID (cached in data/foreverdb), or {} without a key."""
    if not (Path(__file__).with_name("foreverdb.json")).exists():
        return {}
    import foreverdb
    out = {}
    for d in foreverdb.get_all("dungeons"):
        out[d["id"]] = foreverdb.get(f"dungeons/{d['id']}")["data"]
    return out


def main() -> None:
    build = sys.argv[1] if len(sys.argv) > 1 else BUILD
    items = live_items(build)
    insts = instances(build)
    npcs, qitems = load("foreverNpcDB"), load("foreverItemDB")

    droppers: dict[int, list[int]] = {}
    drops_by_npc: dict[int, list[int]] = defaultdict(list)
    for iid, it in qitems.items():
        who = ids(it.get(2))
        droppers[iid] = who
        for nid in who:
            drops_by_npc[nid].append(iid)

    all_zones = set().union(*(i["zones"] for i in insts))

    def Quality(i: int) -> int:
        return items[i][1] if i in items else 2

    def Gear(i: int) -> bool:
        it = qitems.get(i) or {}
        if i in items:
            return items[i][1] >= 2
        return it.get(12) in (2, 4)   # weapon or armour; quality unknown (item not in the client)

    # Zone of each NPC; NPCs with none take the instance of their ID neighbours (Classic IDs come in
    # blocks per dungeon) when every neighbour within NEIGHBOURS that has an instance zone agrees.
    known = {}
    for nid, n in npcs.items():
        z = n.get(9) or next(iter((n.get(7) or {}).keys()), None)
        if z and z > 0:
            known[nid] = z
    zone_of = {nid: z for nid, z in known.items() if z in all_zones}
    zone_of.update(ZONE_FIX)
    for nid in npcs:
        if nid in known or nid in ZONE_FIX or not drops_by_npc.get(nid):
            continue
        near = {known[k] for k in range(nid - NEIGHBOURS, nid + NEIGHBOURS + 1) if k in known}
        if len(near) == 1 and (z := near.pop()) in all_zones:
            zone_of[nid] = z

    fdb = foreverdb_dungeons()
    entries = []
    for inst in insts:
        bosses = []
        for nid, n in npcs.items():
            if zone_of.get(nid) not in inst["zones"]:
                continue
            cap = MAX_DROPPERS_RAID if inst["raid"] else MAX_DROPPERS
            loot = [i for i in drops_by_npc.get(nid, ()) if Gear(i) and len(droppers[i]) <= cap]
            own = sum(1 for i in loot if len(droppers[i]) == 1)
            rank = n.get(6) or 0
            if rank != 3 and (not loot or (rank < 2 and own < MIN_OWN and nid not in ZONE_FIX)):
                continue   # trash: no loot of its own (rank 3 bosses stay, even with no known loot)
            loot.sort(key=lambda i: (-Quality(i), -(qitems[i].get(9) or 0), i))
            bosses.append((n.get(5) or 0, nid, n.get(1), loot))
        bosses.sort(key=lambda b: (b[0], b[2]))
        d = fdb.get(inst["map"])
        announced = bool(d.get("announced")) if d else True
        if not bosses and not (d and announced and d.get("bosses")):
            continue
        # ForeverDB's boss list (Forever order, every boss) with QuestieDB's loot matched by name;
        # bosses only QuestieDB knows follow; ForeverDB's notable loot goes last
        if d and d.get("bosses"):
            by_name = {b[2]: b for b in bosses}
            merged = [by_name.pop(name, (0, 0, name, [])) for name in d["bosses"]]
            merged += [b for b in bosses if b[2] in by_name]
        else:
            merged = bosses
        notable = [x["itemId"] for x in (d or {}).get("notableLoot") or [] if x.get("itemId")]
        if notable:
            merged.append((0, 0, "Notable loot (ForeverDB)", notable))
        levels = [b[0] for b in bosses if b[0]]
        lr = d.get("levelRange") if d else None
        lo, hi = (lr[0], lr[1]) if lr else (min(levels or [0]), max(levels or [0]))
        entries.append({"name": inst["name"], "raid": inst["raid"], "min": lo, "max": hi, "bosses": merged,
                        "corpse": inst["corpse"], "where": WHERE.get(inst["map"]),
                        "announced": announced, "new": bool(d and d.get("newInForever")),
                        "loot": sum(len(b[3]) for b in merged)})

    seen, result = set(), []
    for e in sorted(entries, key=lambda e: -e["loot"]):   # same instance under two map IDs: keep one
        if e["name"] not in seen:
            seen.add(e["name"])
            result.append(e)
    result.sort(key=lambda e: (e["raid"], not e["announced"], e["min"], e["name"]))

    lines, count_b, count_i = [], 0, 0
    for e in result:
        lines.append(f'    {{ name = {lua_str(e["name"])}, raid = {str(e["raid"]).lower()}, min = {e["min"]}, '
                     f'max = {e["max"]}, announced = {str(e["announced"]).lower()}, new = {str(e["new"]).lower()}, '
                     + (f'entrance = {{ {e["corpse"][0]}, {e["corpse"][1]:.1f}, {e["corpse"][2]:.1f} }}, ' if e["corpse"] else "")
                     + (f'where = {lua_str(e["where"])}, ' if e["where"] else "")
                     + "bosses = {")
        for lvl, nid, name, loot in e["bosses"]:
            lines.append(f'        {{ {nid}, {lua_str(name)}, {lvl}, {{ {", ".join(map(str, loot))} }} }},')
            count_b += 1
            count_i += len(loot)
        lines.append("    } },")

    sets = []
    for s in read_csv(download("ItemSet", build)):
        pieces = [int(s[f"ItemID_{k}"]) for k in range(17) if s.get(f"ItemID_{k}", "0") not in ("0", "")]
        pieces = [p for p in pieces if p in items]
        if len(pieces) < 2:
            continue
        req = max(items[p][3] for p in pieces)
        cls = items[pieces[0]][4] or 0
        if cls < 0 or cls >= 2047:
            cls = 0
        sets.append((req, s["Name_lang"], int(s["ID"]), cls, pieces))
    sets.sort()
    set_lines = [f'    {{ {sid}, {lua_str(name)}, {req}, {cls}, {{ {", ".join(map(str, p))} }} }},'
                 for req, name, sid, cls, p in sets]

    OUT.parent.mkdir(exist_ok=True)
    OUT.write_text(
        f"-- Written by tools\\lootdata.py: instances from wago.tools build {build}, bosses and drops from\n"
        "-- QuestieDB's Forever data (github.com/Questie/QuestieDB, GPL-3.0). Do not edit by hand.\n"
        "-- Instances: { name, raid, min, max, bosses = { { npcID, name, level, { itemIDs } } } }\n"
        "SoloLootInstances = {\n" + "\n".join(lines) + "\n}\n\n"
        "-- Item sets: { setID, name, required level, class mask (0 = any), { itemIDs } }\n"
        "SoloLootSets = {\n" + "\n".join(set_lines) + "\n}\n",
        encoding="utf-8",
    )
    print(f"{OUT}: {len(result)} instances, {count_b} bosses, {count_i} drops, {len(sets)} sets")


if __name__ == "__main__":
    main()

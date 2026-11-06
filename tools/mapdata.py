"""Write SoloMap/Data.lua from the game's own tables on wago.tools.

Flight masters from TaxiNodes, unexplored map overlays from WorldMapOverlay + WorldMapOverlayTile.
Usage: py tools\\mapdata.py [build]   (default: the live build below)
"""
from __future__ import annotations

import math
import sys
from collections import defaultdict
from pathlib import Path

from itemstore import download, read_csv

BUILD = "1.60.1.70790"
OUT = Path(__file__).resolve().parent.parent / "SoloMap" / "Data.lua"
SKIP = ("Transport", "Generic", "Quest Path", "zzOLD", "Programmer Isle", "Naxxramas")
EXTRA = {3205, 3274, 3275}  # Forever flight masters with no faction flag (faction from the mount)


def lua_str(s: str) -> str:
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'


def taxi_lines(build: str) -> list[str]:
    lines = []
    for r in read_csv(download("TaxiNodes", build)):
        name, flags, nid = r["Name_lang"], int(r["Flags"]), int(r["ID"])
        if name.startswith(SKIP) or not (flags & 3 or nid in EXTRA):
            continue
        horde = bool(flags & 2) or r["MountCreatureID_0"] != "0"
        alliance = bool(flags & 1) or r["MountCreatureID_1"] != "0"
        side = "B" if horde and alliance else "H" if horde else "A"
        x, y = float(r["Pos_0"]), float(r["Pos_1"])
        lines.append(f'    {{ {nid}, {lua_str(name)}, {r["ContinentID"]}, {x:.1f}, {y:.1f}, "{side}" }},')
    return lines


def reveal_lines(build: str) -> tuple[list[str], int]:
    tiles = defaultdict(list)
    for t in read_csv(download("WorldMapOverlayTile", build)):
        tiles[t["WorldMapOverlayID"]].append((int(t["RowIndex"]), int(t["ColIndex"]), t["FileDataID"]))
    by_art = defaultdict(list)
    bad = 0
    for o in read_csv(download("WorldMapOverlay", build)):
        w, h = int(o["TextureWidth"]), int(o["TextureHeight"])
        files = [f for _, _, f in sorted(tiles[o["ID"]])]
        if len(files) != math.ceil(w / 256) * math.ceil(h / 256):
            bad += 1
            continue
        key = f'{w}:{h}:{o["OffsetX"]}:{o["OffsetY"]}'
        by_art[int(o["UiMapArtID"])].append(f'        ["{key}"] = "{",".join(files)}",')
    lines = []
    for art in sorted(by_art):
        lines.append(f"    [{art}] = {{")
        lines.extend(by_art[art])
        lines.append("    },")
    return lines, bad


def main() -> None:
    build = sys.argv[1] if len(sys.argv) > 1 else BUILD
    taxi = taxi_lines(build)
    reveal, bad = reveal_lines(build)
    OUT.write_text(
        f"-- Written by tools\\mapdata.py from wago.tools build {build}. Do not edit by hand.\n"
        "-- Flight masters: { nodeID, name, continentID, worldX, worldY, side (H/A/B) }\n"
        "SoloMapTaxi = {\n" + "\n".join(taxi) + "\n}\n\n"
        "-- Map overlays by UiMapArtID: [\"width:height:offsetX:offsetY\"] = \"fileDataIDs, row by row\"\n"
        "SoloMapReveal = {\n" + "\n".join(reveal) + "\n}\n",
        encoding="utf-8",
    )
    print(f"{OUT}: {len(taxi)} flight masters, {sum(l.startswith('        ') for l in reveal)} overlays, {bad} skipped (tile count mismatch)")


if __name__ == "__main__":
    main()

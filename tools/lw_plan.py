"""Leatherworking 1-150 plan for WoW Forever: level up while earning the most (or losing the least)
at the vendor.

Data (all live Forever, nothing from Classic):
- Recipe colours (orange / yellow / green / grey), reagents and products: the game's own DB2 tables
  SkillLineAbility, SpellReagents, SpellEffect, SpellName for the build below, from wago.tools,
  saved in data/raw/<build>/spell/. Fetch with:  py tools/lw_plan.py --fetch
- Learn level and source of each recipe: Wowhead's Forever leatherworking spell list
  (wowhead.com/forever/spells/professions/leatherworking, read 2026-11-05). Its colour ranges match
  the DB2 exactly. Only trainer recipes (and the ones you start with) are used.
- Prices: data/items.db for the same build (tools/itemstore.py).

Model
- Skill-up chance: 1 while orange, then (grey - skill) / (grey - yellow) until grey.
- Leather and hides are farmed, so they cost what the vendor would pay for them raw. Thread, salt,
  dye and bleach are bought. Cured hides and other crafted reagents are expanded into their mats.
  Net per craft = product sell price - bought reagents - raw value of the leather used.
- At each skill point: among recipes with at least a 50% chance, the best net per craft
  (ties: higher chance, then less leather).

Usage: py tools/lw_plan.py [--fetch]     writes LEATHERWORKING.md and SoloPlus/Leatherworking.lua
"""

from __future__ import annotations

import csv
import sqlite3
import sys
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
BUILD = "1.60.1.70790"
RAW = ROOT / "data" / "raw" / BUILD / "spell"
DB = ROOT / "data" / "items.db"
MD = ROOT / "LEATHERWORKING.md"
LUA = ROOT / "SoloPlus" / "Leatherworking.lua"
TABLES = ["SpellName", "SkillLineAbility", "SpellReagents", "SpellEffect"]
LEATHERWORKING = "165"
MIN_CHANCE = 0.5
TOP_SKILL = 150

# Learn level of every trainer recipe (and starting recipe, level 1), by spell ID, from Wowhead Forever
LEARN = {
    2149: 1, 2152: 1, 2881: 1, 7126: 1, 9058: 1, 9059: 1,
    2153: 15, 3753: 25, 9060: 25, 9062: 25, 3816: 30, 2160: 35, 2162: 40, 3756: 40, 9065: 45,
    2159: 50, 2161: 50, 3759: 50, 3763: 55, 3761: 60, 9068: 70, 2165: 75, 2167: 75, 3817: 75,
    20648: 75, 2168: 85, 7135: 90, 2166: 95, 9074: 95, 3766: 100, 9145: 100, 3768: 105,
    3770: 110, 3764: 120, 3760: 125, 3780: 125, 3818: 125, 9193: 125, 9194: 125, 20649: 125,
    3774: 135, 7147: 135, 7151: 150, 9196: 150,
}

# Trainer cost in copper per recipe, and the rank spells, from Wowhead Forever (read 2026-11-05)
TRAIN = {
    2153: 50, 2159: 250, 2160: 100, 2161: 100, 2162: 100, 2165: 250, 2166: 450, 2167: 350, 2168: 350,
    3753: 75, 3756: 150, 3759: 200, 3760: 600, 3761: 350, 3763: 300, 3764: 500, 3766: 400, 3768: 500,
    3770: 500, 3774: 1000, 3780: 750, 3816: 50, 3817: 200, 3818: 500, 7135: 400, 7147: 1000, 7151: 1200,
    9060: 100, 9062: 100, 9065: 150, 9068: 400, 9074: 500, 9145: 500, 9193: 500, 9194: 500, 9196: 1500,
    20648: 500, 20649: 1000,
}
RANKS = [("Apprentice", 1, 10), ("Journeyman", 50, 500), ("Expert", 125, 5000)]   # name, skill to learn, copper
RANK_CAP = {"Apprentice": 75, "Journeyman": 150, "Expert": 225}

FARMED = {"Light Leather", "Medium Leather", "Heavy Leather", "Light Hide", "Medium Hide", "Heavy Hide",
          "Ruined Leather Scraps"}
BOUGHT = {"Coarse Thread", "Fine Thread", "Silken Thread", "Salt", "Gray Dye", "Black Dye", "Bleach"}


def fetch() -> None:
    RAW.mkdir(parents=True, exist_ok=True)
    for table in TABLES:
        url = f"https://wago.tools/db2/{table}/csv?build={BUILD}"
        req = urllib.request.Request(url, headers={"User-Agent": "SoloAddons-lwplan/1.0"})
        with urllib.request.urlopen(req, timeout=300) as r:
            (RAW / f"{table}.csv").write_bytes(r.read())
        print(f"fetched {table}")


def rows(table: str):
    with open(RAW / f"{table}.csv", encoding="utf-8", newline="") as f:
        yield from csv.DictReader(f)


def load():
    con = sqlite3.connect(DB)
    items = {i: (n, s, b) for i, n, s, b in
             con.execute("select id, name, sell_price, buy_price from items where build=?", (BUILD,))}
    names = {int(r["ID"]): r["Name_lang"] for r in rows("SpellName")}
    reagents = {int(r["SpellID"]): [(int(r[f"Reagent_{i}"]), int(r[f"ReagentCount_{i}"]))
                                    for i in range(8) if int(r[f"Reagent_{i}"]) > 0]
                for r in rows("SpellReagents")}
    product = {}
    for r in rows("SpellEffect"):
        if r["Effect"] == "24":   # create item
            product.setdefault(int(r["SpellID"]), int(r["EffectItemType"]))
    colours = {}
    for r in rows("SkillLineAbility"):
        if r["SkillLine"] == LEATHERWORKING:
            colours[int(r["Spell"])] = (int(r["TrivialSkillLineRankLow"]), int(r["TrivialSkillLineRankHigh"]))
    return items, names, reagents, product, colours


def build_recipes(items, names, reagents, product, colours):
    by_product = {}   # item name -> recipe that makes it (for crafted reagents like cured hides)
    recipes = []
    for spell, learn in LEARN.items():
        if spell not in colours or spell not in product or product[spell] not in items:
            continue
        yellow, grey = colours[spell]
        name, sell, _ = items[product[spell]]
        mats = {items[i][0]: c for i, c in reagents.get(spell, []) if i in items}
        r = {"spell": spell, "name": names.get(spell, name), "product": name, "sell": sell,
             "learn": learn, "yellow": yellow, "grey": grey, "green": (yellow + grey) // 2, "mats": mats}
        recipes.append(r)
        by_product[name] = r
    return recipes, by_product


def expand(mats, by_product, depth=0):
    """Crafted reagents become their own mats until only farmed and bought items are left."""
    out = {}
    for name, n in mats.items():
        if name not in FARMED and name not in BOUGHT and name in by_product and depth < 4:
            for k, v in expand(by_product[name]["mats"], by_product, depth + 1).items():
                out[k] = out.get(k, 0) + v * n
        else:
            out[name] = out.get(name, 0) + n
    return out


def costs(r, by_product, price):
    bought = raw = 0.0
    usable = True
    for name, n in expand(r["mats"], by_product).items():
        sell, buy = price.get(name, (0, 0))
        if name in BOUGHT:
            bought += n * buy
        elif name in FARMED:
            raw += n * sell
        else:
            usable = False   # needs something we neither farm nor buy (elixirs, silk, dyes made by others)
    return r["sell"] - bought - raw, bought, raw, usable


def chance(r, skill):
    if skill < r["learn"] or skill >= r["grey"]:
        return 0.0
    if skill < r["yellow"]:
        return 1.0
    return (r["grey"] - skill) / (r["grey"] - r["yellow"])


def money(c: float) -> str:
    sign = "-" if c < 0 else ""
    c = abs(int(round(c)))
    g, s, cc = c // 10000, c // 100 % 100, c % 100
    if g:
        return f"{sign}{g}g {s}s {cc}c"
    if s:
        return f"{sign}{s}s {cc}c"
    return f"{sign}{cc}c"


def mats_text(r):
    return ", ".join(f"{n} {k}" for k, n in r["mats"].items())


def main():
    if "--fetch" in sys.argv:
        fetch()
    items, names, reagents, product, colours = load()
    price = {n: (s, b) for n, s, b in items.values()}
    recipes, by_product = build_recipes(items, names, reagents, product, colours)
    scored = []
    for r in recipes:
        net, bought, raw, usable = costs(r, by_product, price)
        r.update(net=net, bought=bought, raw=raw, usable=usable)
        scored.append(r)
    pool = [r for r in scored if r["usable"] and (r["sell"] > 0 or r["product"].startswith("Cured"))]

    def crafts_left(r, skill):
        n, s = 0.0, skill
        while s < TOP_SKILL and chance(r, s) >= MIN_CHANCE:
            n += 1 / chance(r, s)
            s += 1
        return max(n, 1.0)

    learned = set()
    steps, skill = [], 1
    while skill < TOP_SKILL:
        best, key = None, None
        for r in pool:
            ch = chance(r, skill)
            if ch < MIN_CHANCE:
                continue
            leather = sum(v for k, v in expand(r["mats"], by_product).items() if k in FARMED)
            # A recipe not learned yet pays its trainer cost, spread over the crafts it would still give
            learn_cost = 0 if r["spell"] in learned else TRAIN.get(r["spell"], 0) / crafts_left(r, skill)
            k = (r["net"] - learn_cost, ch, -leather)
            if key is None or k > key:
                best, key = r, k
        if best is not None:
            learned.add(best["spell"])
        if best is None:
            steps.append({"from": skill, "to": skill + 1, "r": None, "crafts": 0})
        elif steps and steps[-1]["r"] is best:
            steps[-1]["to"] = skill + 1
            steps[-1]["crafts"] += 1 / chance(best, skill)
        else:
            steps.append({"from": skill, "to": skill + 1, "r": best, "crafts": 1 / chance(best, skill)})
        skill += 1

    totals, cash, training = {}, 0.0, 0
    md = ["# Leatherworking 1-150 for WoW Forever: level up, earn the most at the vendor", "",
          f"Made by `tools\\lw_plan.py` from live Forever data (build {BUILD}): recipe colours, reagents and "
          "products from the game's own tables (wago.tools), learn levels from Wowhead Forever, sell and buy "
          "prices from `data\\items.db`. Leather and hides count at their raw vendor value, so a positive net "
          "means the crafted item sells for more than its leather would have. Trainer recipes only; recipes "
          "needing elixirs, silk or other bought-from-players items are left out. Crafts are expected values.",
          "", "In game: `/sp lw` shows the step for your current skill.", "",
          "Profession ranks: Apprentice (cap 75), Journeyman at skill 50 for 5s (cap 150), Expert at 125 for 50s "
          "(needed only to go past 150). Wowhead lists no character level for the ranks; if the trainer refuses "
          "Journeyman, your level is the limit (it was level 10 in Classic).", "",
          "| Skill | Recipe | Learn at | Training | Crafts | Mats per craft | Net per craft | Net for the step |",
          "|---|---|---|---|---|---|---|---|"]
    seen_spells = set()
    lua = []
    for st in steps:
        r = st["r"]
        if r is None:
            md.append(f"| {st['from']}-{st['to']} | nothing at 50%+: make the cheapest yellow recipe | | | | | |")
            continue
        for k, v in expand(r["mats"], by_product).items():
            totals[k] = totals.get(k, 0) + v * st["crafts"]
        cash += r["net"] * st["crafts"]
        cost = 0 if r["spell"] in seen_spells else TRAIN.get(r["spell"], 0)
        seen_spells.add(r["spell"])
        training += cost
        md.append(f"| {st['from']}-{st['to']} | {r['name']} | {r['learn']} | {money(cost) if cost else 'known'} | "
                  f"{st['crafts']:.0f} | {mats_text(r)} | {money(r['net'])} | {money(r['net'] * st['crafts'])} |")
        lua.append(f'    {{ from = {st["from"]}, to = {st["to"]}, recipe = "{r["name"]}", crafts = {st["crafts"]:.0f}, '
                   f'mats = "{mats_text(r)}", net = {int(round(r["net"]))} }},')
    md += ["", "## Shopping and farming list (raw mats, cured hides expanded)", ""]
    for k, v in sorted(totals.items(), key=lambda kv: -kv[1]):
        md.append(f"- {k}: {v:.0f} ({'buy' if k in BOUGHT else 'farm'})")
    ranks = sum(c for _, at, c in RANKS if at < TOP_SKILL and at > 1) + RANKS[0][2]
    ranks -= next(c for n, at, c in RANKS if n == "Expert")   # Expert is not needed below 150
    md += ["", f"Crafting against vendoring the leather raw: **{money(cash)}**. Recipe training: {money(training)}. "
           f"Ranks (Apprentice, Journeyman): {money(ranks)}. **Net after training: {money(cash - training - ranks)}**.", "",
           "## Every trainer recipe to 150, best to worst per craft", "",
           "| Recipe | Learn / yellow / green / grey | Mats | Sells for | Bought mats | Leather raw value | Net |",
           "|---|---|---|---|---|---|---|"]
    for r in sorted(scored, key=lambda r: -r["net"]):
        if r["learn"] > TOP_SKILL:
            continue
        note = "" if r["usable"] else " (needs mats from other players)"
        md.append(f"| {r['name']}{note} | {r['learn']} / {r['yellow']} / {r['green']} / {r['grey']} | {mats_text(r)} | "
                  f"{money(r['sell'])} | {money(r['bought'])} | {money(r['raw'])} | {money(r['net'])} |")
    md += ["", "## Forever changes worth knowing", "",
           "- Medium Leather can be made from 4 Light Leather (trainer, 75), Heavy Leather from 5 Medium (125).",
           "- Toughened Leather Armor needs 2 Cured Light Hide (6 in Classic).",
           "- Most recipes are learned earlier and go grey earlier than in Classic. Light Leather Pants: learn 70, grey at 130.",
           "- Vendor prices can be 1c off in game (hotfixes).", ""]
    MD.write_text("\n".join(md), encoding="utf-8")
    LUA.write_text("\n".join([
        "-- Leatherworking plan, written by tools\\lw_plan.py. Do not edit by hand.",
        f"-- Live Forever data, build {BUILD}. net = copper gained (or lost) per craft against vendoring the leather.",
        "SoloPlusLeatherworking = {"] + lua + ["}", ""]), encoding="utf-8")
    return cash
    print(f"{len(steps)} steps, crafting {money(cash)}, training {money(training)}, ranks {money(ranks)}, "
          f"net {money(cash - training - ranks)}")
    for st in steps:
        r = st["r"]
        print(f"  {st['from']}-{st['to']}: {r['name'] if r else '-'} x{st['crafts']:.0f} {money(r['net']) if r else ''}")


if __name__ == "__main__":
    main()

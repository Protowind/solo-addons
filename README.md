# WoW Addons

Personal WoW Forever addon suite and data tools for my own characters, built with Claude.

## Data sources and credits

- [ForeverDB.net](https://foreverdb.net): WoW Forever items, quests and vendors (ForeverDB API). Data from ForeverDB is credited to https://foreverdb.net wherever it is shown.
- [QuestieDB](https://github.com/Questie/QuestieDB) (GPL-3.0): Forever quests and NPC spawn points.
- [wago.tools](https://wago.tools): the game's own data tables per build (items, flight masters, map overlays).
- Blizzard Game Data API (Forever namespace).
- World of Warcraft and its data are owned by Blizzard Entertainment. This project is not affiliated with Blizzard or ForeverDB.

## About

Own addons. Source lives here; each addon is linked into the game with a junction, so edits here show up in game after `/reload`. History in `CHANGELOG.md`.

## Layout

- `H:\WoW Addons\<AddonName>\` holds `<AddonName>.toc` + Lua files
- Linked into `H:\World of Warcraft\_forever_\Interface\AddOns\<AddonName>` (junction)
- Link a new addon: `.\link.ps1 <AddonName>` (add `-Flavour _retail_` for retail)
- A new addon loads with a /reload in game; no logout to character select needed (live, tested 2026-11-06)
- Interface numbers: Forever `16001` (all addons load on live 1.60.1.70790 with it; exact number not yet confirmed), retail `120105`. Check in game: `/dump select(4, GetBuildInfo())`

## Addons

| Addon | What it does | Status |
|---|---|---|
| SoloStats | FPS, home/world latency, level and XP, XP/h, time to level, kills to level (last 10 kills), rested XP, session totals, plus gold, bag space, durability, time, date, zone, coordinates (SoloLevel merged in). Layouts: Stacked, Row, Top bar (full width, text left, centre or right; a Guides menu at its left end opens Claude's notes and the SoloCoach guides). Options panel (`/ss` or right-click): each item on/off, layout, show/hide, background, lock, text size, 4 themes (Blizzard classic, Forsaken, Minimal dark, Horde). Shift-drag; Ctrl-click the readout or `/ss copy`: your zone and coordinates in a box, selected for Ctrl+C. `/ss pos\|copy\|session\|size <6-32\|reset>\|layout <stack\|row\|bar>\|align <left\|centre\|right>\|theme <name>\|hide\|show` | Working (all tested) |
| SoloQuest | Auto accept quests, auto turn in when no reward choice and no gold cost; Shift pauses, `/sq on\|off` | Working (tested) |
| SoloGear | Green "+" on bag upgrades (armour, jewellery, shields, off-hands, weapons), score line in tooltips, class armour type, weapon type and required level checks; weapons scored by damage per second plus stats (two-handers against both hands); quest reward pick (biggest upgrade, else highest sell price) labelled on the reward and printed at turn-in; `/sg primary str\|agi\|int\|auto`; auto-equip: out of combat, after your bags change, the biggest bound armour or jewellery upgrade goes on with a chat line; weapons and bind-on-equip items ask first (popup); items you take off yourself are left alone for the session (`/sg auto`, `/sg autoweapons`); `/sg bis` lists your slots weakest first with upgrade sources near your level from `SoloGear\Upgrades.lua` (rogue seed list, Claude extends it) | Working (tooltip, reward pick, bag "+" tested; weapons and gear with stats not yet) |
| SoloSwing | Melee swing timer: main hand bar, off hand bar when dual wielding, haste and parry haste; warrior extras: orange while Heroic Strike/Cleave queued, green Slam window; `/sw test\|scale <0.5-3>\|reset\|debug`. Reads swings from UNIT_COMBAT (combat log is forbidden to addons on this client). Planned: rogue energy tick, shaman Windfury flash, hunter Auto Shot, target swing bar | Working (swing timing tested; Heroic Strike colour and Slam window not yet) |

| SoloCombo | Rogue strip under the SoloSwing bars: five combo point pips with a big count, energy bar, and timers for Slice and Dice (own buff), Rupture, Garrote and Expose Armor (your debuffs on the target). Secret values in combat: the energy bar is fed the value directly and a secret aura time falls back to a Blizzard Cooldown frame. Shift-drag; `/sc test\|scale <0.5-3>\|reset\|energy\|debug` | Not yet tested in game |
| SoloRoute | Levelling route one step at a time (`SoloRoute\Routes.lua`, written by Claude: Durotar 1-10 and Tirisfal Glades 1-10 so far). Accept / do / turn-in steps tick off from the quest log; note steps need Done. Each step drops the game's own map pin (arrow at the top of the screen). `/route` toggle, `next\|back\|step <n>\|pin\|auto\|reset\|list\|use <key>` | Not yet tested in game |
| SoloPlus | Vendor: sells greys when a merchant opens, with a chat line; auto repair is off by default (`/sp repair` turns it on, `/sp sell` toggles selling). `/sp lw` prints the leatherworking plan step for your skill (from `LEATHERWORKING.md`, made by `tools\lw_plan.py`), and again when the skill reaches the next step. Warns on logout outside an inn or city | Not yet tested in game |
| SoloCoach | Bridge to Claude. Game -> Claude: snapshot (level, XP, gold, zone, position, gear, bags, quest log with objectives, professions (no weapon skills on this client), session deaths/gold) taken every minute and a few seconds after quests, level, gold, gear or bags change; the game saves it on /reload or logout to `WTF\Account\<acc>\93\<char>-<realm>\SavedVariables\SoloCoach.lua`. A blank snapshot (logout on this client) never replaces the last good one. Claude -> game: `SoloCoach\Advice.lua`, shown in a notes panel after /reload; lasting guides (rogue talents, rotation, gear, milestones; leatherworking 1-150) in `SoloCoach\Guides.lua`, never replaced by new notes. `/coach`, `/coach snap`, `/coach guide [n]` | Loads on live. Timed snapshot (v1.1) not yet tested in game. Notes panel opens with `/coach` |
| SoloMap | World map extras. Coordinates (you and the cursor) under the map. Every flight master for your faction from the game's TaxiNodes table (`SoloMap\Data.lua`, made by `tools\mapdata.py`): coloured when known, grey when not; known ones are learned when you open a flight map or discover a path. Services saved account-wide each time you use one (vendor, repair, trainer, innkeeper, stable, bank, auction house, mailbox, other titled NPCs) and shown on that map. Unexplored areas drawn dimmed (WorldMapOverlay tables). Click the coordinate bar to copy your position, right-click for the cursor's last spot on the map (selected in a box, Ctrl+C). `/smap`, `coords\|flights\|services\|fog\|copy\|list\|clear` | Loads with /reload; coordinates and flight icons seen in game. Rest not yet tested |
| SoloLoot | AtlasLoot-style window. Dungeons tab: every dungeon and raid (level range) > its bosses > their own drops (icon, quality colour, item level, required level, slot; green + when SoloGear calls it an upgrade). Item sets tab: the game's item sets with their pieces, "My class only" filter. Hover for the tooltip (set bonuses included), Shift-click to link, Ctrl-click to preview. Data from `tools\lootdata.py`: instances from wago.tools; boss lists, level ranges, new and not-yet-announced instances and notable loot from ForeverDB.net (credited in the window); drops from QuestieDB (no drop rates; raid loot partly missing, those bosses show "?"). Entrance under the boss list: zone and coordinates (the game's Map corpse point, just outside) with a Show on map button that sets the game's map pin; new Forever dungeons show Blizzard's description. Framed panels (Instances with Dungeons/Raids headings, Bosses, Loot), tab buttons, minimap button (click to open, drag to move). `/sloot` or `/loot`, `/sloot minimap` hides or shows the button | Not yet tested in game |
| SoloPlates | Flat, ElvUI-style skin for the game's own nameplates: flat bar texture, 1 px black edge, dark background, outlined name and level, flat cast bar. Only restyles Blizzard's plate (never reads health, so secret combat values do not matter); Blizzard's colours stay; forbidden plates (friendly ones in instances) untouched. `/splates`, `height <4-20>`, `size <8-16>`, `on\|off`, `dump` (saves the target plate's layout for Claude) | Not yet tested in game |
| SoloErrors | Error catcher for all addons: `seterrorhandler` takes every uncaught Lua error, plus the `ADDON_ACTION_FORBIDDEN` and `ADDON_ACTION_BLOCKED` events (taint, protected functions). Each distinct error saved once with a count, times, addon name and stack in `SoloErrorsDB.errors` (account-wide SavedVariables, written on /reload), one chat line per new error (at most 10 per session), Blizzard's error popup off unless `/errors popup`. Every other Solo addon lists it in `OptionalDeps` so it loads first and catches their load errors. `/errors` list, `/errors <n>` stack, `clear`, `popup`, `test`. Syntax errors never reach Lua: those stay in `Logs\FrameXML.log` | Working (`/errors test` caught with stack, saved after /reload) |
| SoloMeter | Damage meter read from the game's own meter (`C_DamageMeter`; the combat log is forbidden to addons, so Details and Skada cannot work here). Flat class-coloured bars: rank, name, total (per second, share). Modes Damage, Healing, Damage taken, Interrupts, Deaths; current fight, overall, or one of the last six past fights (by mob name and length, from the game's session list). Click the header for the menu (modes, session, past fights, reset, hide), right-click it to swap current and overall, mouse wheel to cycle modes; click a bar for that player's spells (icons, totals; in Damage taken each spell names the mob that cast it), right-click or click the header to go back. Bosses show red in the past-fights list. In combat the numbers are secret values: shown as the client formats them, no percentages or sorting until the fight ends; your own bar is always readable and sits on the last row when you are further down. `/meter` toggle, `mode <damage\|healing\|taken\|interrupts\|deaths>`, `current\|overall`, `reset`, `test` (fake bars), `scale`, `rows`, `width`, `height`, `pos`, `class`, `debug` (raw API values to chat and `SoloMeterDB.debug`). Fight capture: 3 s after every fight the raw meter data (every mode's sources, your spells with names, session list, field names, secret values marked) is saved to `SoloMeterDB.fights` (last 20), plus one in-combat probe per login in `SoloMeterDB.probe` showing which fields are secret while fighting; Claude reads them after a /reload to improve the meter. `/meter fights` lists them, `capture` on/off, `capture now`, `capture clear` | Loads and captures in game (5 group fights in Ragefire Chasm, no errors); bars, menu and past fights not yet confirmed by eye |
| SoloUI | Flat ElvUI-style unit frames: player, target (level, Elite/Rare tag, your debuffs first above it), target of target, 4 party frames. Secure buttons (click to target, right-click menu, also in combat); class or reaction colours; health numbers when the client allows (secret values in combat leave the bar working). Hides Blizzard's player, target and party frames (option); the target's cast bar and the pet frame are kept and re-anchored under the SoloUI frames. Shift-drag to move, scale, reset. Also the "Solo addons" window: every Solo addon with loaded state, notes, a button for its own options and an on/off tick per character; a Guides menu at the top right opens Claude's notes or a SoloCoach guide. `/sui` | Not yet tested in game |

In-game tests still to do: `TESTING.md`. Rogue levelling spec and talent order: `ROGUE.md`. Leatherworking plan: `LEATHERWORKING.md`.

## Client limits found (Forever beta, 12.x engine; live 2026-11-05: all five addons load and save their variables)

- Live: `PLAYER_LOGOUT` fires after the character data is gone on logout. `GetMoney`, `UnitXP`, `UnitXPMax`, `GetInventoryItemLink`, container slots, quest levels and objectives all return 0 / nil then. Snapshots must be taken while playing.

- Addons may not register `COMBAT_LOG_EVENT_UNFILTERED` (ADDON_ACTION_FORBIDDEN popup)
- `UnitAttackSpeed` is a "secret value" in combat: cannot compare or do maths; cache it out of combat
- `UNIT_COMBAT` and `PLAYER_ENTER_COMBAT` / `PLAYER_LEAVE_COMBAT` work
- `/chatlog` does not record addon `print` output; write debug lines to SavedVariables instead
- Lua errors: SoloErrors saves them to `SavedVariables\SoloErrors.lua` (read after a /reload); file syntax errors are in `Logs\FrameXML.log`

## Tools

- `tools\blizzard_api.py`: test client for Blizzard's Game Data API (Python standard library only). Keys in `tools\blizzard_api.json`, never shared. Default namespace WoW Forever (`static-forever`, EU; undocumented by Blizzard, works since 2026-11-06). It serves data build 1.60.1_70399, older than live, so newer Forever items return 404: `itemstore.py` stays the main item source. Quests work too (`raw /data/wow/quest/<id>`). `--namespace static-classic1x` for Classic Era.
- `tools\lw_plan.py`: leatherworking 1-150 plan that earns the most at the vendor, all from live Forever data: recipe colours, reagents and products from the game tables on wago.tools (`--fetch`), learn levels from Wowhead Forever, prices from `data\items.db`. Writes `LEATHERWORKING.md` and `SoloPlus\Leatherworking.lua`.
- `tools\questie.py`: QuestieDB WoW Forever data (quests, NPCs with spawn points, objects, items). `fetch`, `givers <zoneID> [min] [max]`. Data in `data\questie\`.
- `tools\foreverdb.py`: ForeverDB API client (`get <path>`, `all <path>`), key in `tools\foreverdb.json` (git-ignored), answers cached in `data\foreverdb\`, 1.1 s between requests. Data from ForeverDB.net must be credited with a link to https://foreverdb.net wherever it is shown.
- `tools\lootdata.py`: writes `SoloLoot\Data.lua` (instances, bosses, drops, item sets) from wago.tools, QuestieDB (`questie.py fetch` first) and `data\items.db`.
- `tools\mapdata.py`: writes `SoloMap\Data.lua` (flight masters and map overlays) from the game tables on wago.tools. Rerun after a new build: `py tools\mapdata.py <build>`.
- `tools\itemstore.py`: local WoW Forever item store from wago.tools (ItemSparse + Item tables per build).
  - `fetch <build>` downloads CSVs to `data\raw\<build>\` (about 6 MB per build) and stores items in `data\items.db` (SQLite)
  - `builds` lists stored builds; `find "<name>"` shows an item in every build
  - `diff <old> <new>` writes `data\changelog\<old>_to_<new>.md` (added, removed, changed fields)
  - Stats are stored as each stat's share of the item's budget (e.g. "Stamina 66.67%"), not final values
  - No hotfixes applied: sell prices can differ slightly from in game (Flimsy Chain Pants: 2 copper in data, 1 in game)
  - Stored: 1.60.1.70425, 1.60.1.70450 (23 items added, none changed), 1.60.1.70790 (live, 50 added, 40 changed)
  - Dungeon loot is not in the client tables, so dungeon items cannot be looked up here

## Ideas

Levelling
- Quest mob counter on the mob's nameplate (e.g. "3/6 Duskbat Wing")
- Session summary on logout: XP, gold, kills, deaths, time played

Gold and bags
- Auto-sell grey items and auto-repair at vendors, with a chat summary
- Loot log with vendor value per item and gold per hour
- Bag space counter on screen, red when nearly full
- Durability warning before it hits 0

Combat and UI
- Cursor ring or highlight in combat (easy to find the mouse)
- Low health / low mana flash at screen edge
- Buff reminder: missing self-buffs, food, poisons
- Cooldown text in big numbers for chosen spells

Social and chat
- Chat timestamps and clickable copy for URLs
- Whisper history window
- Guild member online/offline toasts

Extend SoloStats
- FPS and latency mini graph over the last 60 s
- Memory use per addon on hover
- Coordinates and zone under the readout

## Limits

- No file or internet access; data saves only through `## SavedVariables`
- No combat automation: casting, targeting and moving need a key press
- Some frames are protected in combat (cannot be moved or shown/hidden then)

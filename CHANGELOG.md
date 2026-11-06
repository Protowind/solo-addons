# Changelog

Own WoW addons and data tools. Newest first.

## 2026-11-06

### SoloMeter attackers and bosses
- 17 fights captured (Searing Blade packs, boss Bazzalan). `combatSpellDetails` read: one record per spell with amount, unitName, unitClassFilename, classification ("elite"), isMob, isPet; in damage taken it names who hit you with that spell, blank for your own damage. The spell view now shows it in grey after the spell name ("Curse of Agony  Searing Blade Cultist (elite)") with a tooltip (From, Avoidable, Deadly). Boss sessions are named "(!) Bazzalan" by the game: the past-fights menu shows them in red without the mark. Kick confirmed in the interrupts mode ("Shadow Bolt 1").

### SoloMeter from live data
- First captures read (5 group fights in Ragefire Chasm, build 16001): the API matches the plan. Confirmed `Enum.DamageMeterType`: DamageDone 0, Dps 1, HealingDone 2, Hps 3, Absorbs 4, Interrupts 5, Dispels 6, DamageTaken 7, AvoidableDamageTaken 8, Deaths 9, EnemyDamageTaken 10. Source fields: name, classFilename, classification, totalAmount, amountPerSecond, sourceGUID, isLocalPlayer, deathRecapID, deathTimeSeconds, sourceDisplayType, specIconID (secret even after the fight). Spell fields: spellID, totalAmount, amountPerSecond, overkillAmount, isAvoidable, isDeadly, creatureName, combatSpellDetails (table). Session list: sessionID, name (the mob), durationSeconds. In combat only `classFilename` and `isLocalPlayer` are readable; names, GUIDs, totals, per second, durations and spell IDs are secret. After the fight everything is readable. The current session's duration keeps running after the fight (40 s for a 27 s fight) and the API's own per-second uses it.
- Past fights: the header menu lists the last six sessions by mob name and length (`GetAvailableCombatSessions`, newest first, out of combat only); choosing one reads it with `GetCombatSessionFromID` / `GetCombatSessionSourceFromID`, the header shows its name and length, right-click or Current/Overall go back; a reset drops it. Not saved between reloads.
- Spell view in combat shows one line "spells readable after the fight" (the spell IDs are secret, so no names or icons). Menu widened for the fight names.
- Capture: `combatSpellDetails` copied two levels deep (contents still unknown) with its field names; the fight's target, secret in dungeons, is taken from the newest session's name and its ID saved too.
- SoloErrors confirmed working: `/errors test` logged with count and stack, written to `SoloErrorsDB` on /reload; no other addon errors in the five fights.

### SoloErrors (new)
- Automatic error capture for every addon, so errors no longer depend on a screenshot of the popup. `seterrorhandler` receives every uncaught Lua error (message plus `debugstack`, both through pcall in case of secret values); `ADDON_ACTION_FORBIDDEN` and `ADDON_ACTION_BLOCKED` are logged too, since taint and protected calls fire events instead of errors. Stored once per distinct message with a count, first and last time, addon name (from the path) and stack, 50 at most, in `SoloErrorsDB.errors`; errors raised before its own SavedVariables load are held and moved in at `ADDON_LOADED`. One chat line per new error, 10 per session at most; Blizzard's popup stays off unless `/errors popup`. `/errors`, `/errors <n>`, `clear`, `popup`, `test` (raises one on purpose).
- Every Solo addon toc now has `## OptionalDeps: SoloErrors` (SoloLoot: `SoloGear, SoloErrors`) so it loads first. Row in the SoloUI window. Linked with `link.ps1`. Not yet tested in game: whether `seterrorhandler` exists on this client is the first thing to check (`/errors` says so if not).

### SoloMeter fight capture
- Automatic capture of the game's meter data after every fight, so the meter can be improved from real Forever data instead of another addon's reading of the API. 3 s after `PLAYER_REGEN_ENABLED` (values turn readable by then), for the seven `Enum.DamageMeterType` values (damage, healing, absorbs, interrupts, dispels, damage taken, deaths): the current session's duration, total and max, up to 10 sources with every field, your own source and up to 15 of your spells (with names), `GetSessionDurationSeconds` for both sessions, `GetAvailableCombatSessions` (10), the API's function list, the enum and every table's field names. Secret values are stored as "(secret)", numbers rounded to 3 decimals. Last 20 fights in `SoloMeterDB.fights` with time, zone, target, length and level; a fight with no damage data is skipped. One in-combat probe per login (2 s into the first fight) in `SoloMeterDB.probe` records which fields are secret in combat. `/meter fights` lists them (time, zone, target, length, your total and per second), `/meter capture` toggles, `capture now` saves at once, `capture clear` wipes. Not yet tested in game.

### SoloMeter (new)
- Own damage meter on the game's server-side meter (`C_DamageMeter`), the only source left since the combat log is forbidden to addons. One file, flat bars in the SoloUI style (WHITE8X8, 1 px black edge, class colours, outlined text). Modes Damage (type 0), Healing (2), Damage taken (7), Interrupts (5), Deaths (9); sessions current (1) and overall (0). Header menu is an own popup (no EasyMenu or MenuUtil, which differ between clients): modes, current or overall, reset (`ResetAllCombatSessions`), hide. Right-click the header swaps the session, mouse wheel cycles modes, Shift-drag moves. Click a bar for that source's spells (`GetCombatSessionSourceFromType`, icons from `C_Spell.GetSpellTexture`), right-click back.
- Secret values in combat: totals and per-second go straight to `StatusBar:SetValue` and `AbbreviateNumbers` / `string.format("%.0f")`, texts are built with `string.format` only (concatenation of a secret fails), no sorting or percentage until the fight ends, class colour only when the class name is readable. `isLocalPlayer` is never secret, so your own bar is found and highlighted in combat and takes the last row when you are below the visible rows. Redraw at most 4 times a second, and for 3 s after combat while values turn readable (`ADDON_RESTRICTION_STATE_CHANGED`).
- `/meter test` draws fake bars for the layout; `/meter debug` dumps the API's fields and raw values (secret ones marked) to chat and `SoloMeterDB.debug`, since the Forever field list is only known from other meters' code. Events are registered with pcall so an unknown event is reported, not fatal. API learnt from Forever Meter's source (GPL-3.0, read only; own code). Row in the SoloUI window. Linked with `link.ps1`. Not yet tested in game.

### SoloGear auto-equip
- Out of combat, 0.6 s after `BAG_UPDATE_DELAYED` (also after combat, login and level up): finds the biggest upgrade in the bags (`Compare`, gain over 0.5) and equips it into the slot it beats (`PickupContainerItem` + `EquipCursorItem`), one item per pass, with a chat line. `Compare` now also returns that slot (rings, trinkets, either hand). Weapons and unbound (bind-on-equip) items show a Yes/No popup instead, once per item per session; `/sg autoweapons` lets weapons go on alone. Items you swap yourself (`PLAYER_EQUIPMENT_CHANGED` not caused by SoloGear) are not re-equipped this session. `/sg auto` toggles; saved per character. Not yet tested in game.

### SoloLoot entrances
- Fix: the entrance text for new dungeons had a real line break inside a Lua string, a syntax error that stopped SoloLoot loading at all. Now `
`. All addon files scanned for other broken strings: none.
- Entrance for 25 instances from the game's Map table (corpse point just outside, continent world coordinates); the client turns it into zone and coordinates (`C_Map.GetMapPosFromWorldPos`, narrowed to the zone with `GetMapInfoAtPosition`). Show on map sets the game's user waypoint and tracks it. The four new Forever dungeons have no entrance in the game files or ForeverDB: their location text is from Blizzard's dungeon post (news.blizzard.com article 24301455).

### ForeverDB API
- Access approved (developer ID dev-0143). New `tools\foreverdb.py`: key from `tools\foreverdb.json` (git-ignored), cached answers in `data\foreverdb\`, waits 1.1 s between requests, retries on 429. Data build 1.60.1.70790 (same as live): 22,403 items, 6,614 quests, 946 vendors, 47 dungeons, 545 sets.
- Found: `/dungeons/{id}` gives boss names, level ranges, announced and new-in-Forever flags and up to 3 notable items, not per-boss loot (the items are server-side; `/items/17076` is "hidden").
- **SoloLoot 1.1**: `lootdata.py` merges ForeverDB into Data.lua: 30 instances, 354 bosses, 1,136 items. ForeverDB's boss order and every boss (QuestieDB loot matched by name, extra QuestieDB bosses after), ForeverDB level ranges (Ragefire Chasm 13-18), a "Notable loot (ForeverDB)" row, the four new Forever dungeons marked "new", raids Blizzard has not announced for Forever (Molten Core, Blackwing Lair, AQ, Naxxramas, Zul'Gurub) greyed under their own heading. Window credits "Data from ForeverDB.net (https://foreverdb.net)" as their terms require.

### SoloUI (new)
- Fix for an error flood reported in game (addon not named yet): target name joined with `..` (a secret creature name refuses `..`, now `string.format`), aura source compared while secret, level, reaction and classification used without a secret check. All frame updates now run through `ns.Safe`: each distinct error shows once in chat and is saved in `SoloUIDB.errors` instead of the error popup repeating.
- Flat ElvUI-style unit frames (player, target, target of target, party 1-4) on secure unit buttons: click to target, right-click menu, `RegisterUnitWatch` shows and hides them. Bars take raw health and power (secret-safe); text only when it can be formatted. Target shows level (difficulty colour), Elite/Rare/Boss tag and up to 8 debuffs above it, yours first, with a Cooldown spiral (skipped if aura times are secret). Blizzard's PlayerFrame, TargetFrame, TargetFrameToT and party frames reparented to a hidden frame (option). Built only out of combat.
- "Solo addons" window (`/sui`): one row per Solo addon with on/off tick (per character, after reload), loaded state, its notes and a button that runs its slash command; unit frame settings (on/off, hide Blizzard, health numbers, class colours, scale, reset positions). Separate addons kept on purpose (option 2: one panel, not one addon). Linked with `link.ps1`. Not yet tested in game.

### SoloPlates (new)
- Flat ElvUI-style nameplate skin over Blizzard's own plates: WHITE8X8 bar texture, 1 px black edge and dark fill drawn on the bar, Blizzard border pieces faded to alpha 0, outlined name and level, flat cast bar. Height applied only out of combat. `/splates dump` saves the target plate's frame layout to SavedVariables, since the Forever plate structure is not known yet. Linked with `link.ps1`. Not yet tested in game.

### SoloLoot (new)
- Tested in game, all checks pass (minimap button, item sets, Shift-click link, Ctrl-click preview too): window, panels, Ragefire Chasm > Taragaman with three rare drops, icons, item lines and SoloGear's + all work.
- New look: dark dialog frame, three framed panels with gold title strips (Instances, Bosses, Loot), Dungeons and Raids headings, striped rows, item icons with a quality-coloured edge, highlighted tab buttons. Minimap button (click to open, drag round the edge, `/sloot minimap` to hide).
- AtlasLoot-style window (`/sloot`, `/loot`): dungeons and raids > bosses > their own drops, and an Item sets tab with a "My class only" filter. Tooltips, Shift-click link, Ctrl-click preview, green + from SoloGear (`SoloGear_Compare` now global). Linked with `link.ps1`. Not yet tested in game.
- `tools\lootdata.py` writes `SoloLoot\Data.lua`: 26 instances (Map + AreaTable, build 1.60.1.70790), 232 bosses, 1,075 drops, 150 item sets. A boss is an NPC in the instance with loot of its own (gear dropped by at most 6 creatures, 20 in raids, and at least 2 items only it drops) or a rank 3 boss. NPCs with no zone in QuestieDB take the zone of their ID neighbours when all agree; four fixed by hand (Ragnaros, Mutanus, Avatar of Hakkar, Bazzalan).
- Found: the game files leave out many old dungeon drops (their item data stays on Blizzard's servers), so drops come from QuestieDB, which also lacks much raid loot (Magmadar, Nefarian, Chromaggus show "loot unknown"). ForeverDB's `/dungeons/{id}` can fill this once API access is approved; its data must then be credited in the window.

### SoloCoach
- Gold misread in the Thunder Bluff notes: the first `money` in the snapshot file is gold at login (5s 52c), not current gold (30s 37c). Notes fixed; `CLAUDE.md` now says which field to read. The addon itself was right.

### QuestieDB
- New `tools\questie.py`: reads QuestieDB's WoW Forever data (GPL-3.0, github.com/Questie/QuestieDB) into Python. `fetch` downloads the quest, NPC, object and item files to `data\questie\` (not in git); `givers <zoneID> [min] [max]` lists quests started by NPCs in a zone, filtered to Troll Rogue. Base data is build 1.60.1.69893 (26 Oct), corrections daily.
- SoloCoach notes: Thunder Bluff quests worth taking at level 13 (Ragefire Chasm pair from Rahauro, Journeyman leatherworking), later (Serpentbloom at 14, Leaders of the Fang chain) and skip. Checked against the Blizzard API (Forever) for rewards; two new Forever quests (Traditions of the Bluff, Never Coming Back) are in the API but not in QuestieDB.

### GitHub
- Project now a git repository, pushed to https://github.com/Protowind/solo-addons (public; needed for the ForeverDB API access form). `.gitignore` keeps out API keys (`tools/*.json`), local data (`data/`), `CLAUDE.md` and `_retired/`. README starts with a data sources and credits section (ForeverDB.net, wago.tools, Blizzard).
- Personal details taken out of the tracked files (real name, email, location, local paths, character and realm names); addon authors now Protowind; commits use the GitHub no-reply email. History rewritten to one clean commit.

### Blizzard API
- WoW Forever is in the Blizzard Game Data API after all (undocumented, found by players). Tested with the existing keys: `static-forever-eu` works for items, quests (924 The Demon Seed) and classes; it serves data build 1.60.1_70399 (live is 70790), so the newer Forever item 287060 returns 404. The versioned `static-1.60.1_70790-forever` returns 403. `blizzard_api.py` now defaults to `static-forever`; `static-classic1x` still works for Classic Era. Sources: Blizzard API forum threads and GitHub issues of Forever projects.

### Copy coordinates
- WoW has no clipboard access for addons, so both addons show the text selected in a small box: Ctrl+C copies and closes it. Format "The Barrens 50.1, 39.9".
- **SoloMap v1.1**: click the coordinate bar (or `/smap copy`) for your position, right-click for the cursor's last spot on the map. The bar stays alongside the map's own bottom-left coordinates. Tested in game: click to copy works.
- **SoloStats**: Ctrl-click the readout or `/ss copy`. Tested in game: copy and paste work. The Coordinates readout item already existed (off by default, tick it in `/ss`).

### SoloMap (new)
- Loads in game after a /reload (no logout needed): coordinates under the map and flight master icons show. README, CLAUDE.md and TESTING.md updated to say a /reload is enough for a new addon.
- World map extras: player and cursor coordinates; every flight master for your faction (coloured when known, grey when not); NPC services saved as you use them (account-wide) and shown on that map; unexplored areas drawn dimmed. `/smap`. Linked with `link.ps1`. Not yet tested in game.
- `tools\mapdata.py` writes `SoloMap\Data.lua` from wago.tools build 1.60.1.70790: TaxiNodes (76 flight masters after dropping transports, quest paths and old Riverglades nodes; faction from the flags, or from the mount for the 3 new Forever nodes without one) and WorldMapOverlay + WorldMapOverlayTile (1,080 overlays on 84 map arts, 1 skipped for a tile count mismatch).
- `CLAUDE.md`: new rule to always check for the latest WoW Forever changes (build, patch notes, Forever sources) before answering or changing anything; `mapdata.py` listed under data tools.
- World to map positions are worked out in game from `C_Map.GetWorldPosFromMapPos`, so no map ID table is needed.

### SoloCoach
- `Advice.lua`: notes for The Demon Seed (924) added above the rogue guide: Altar of Fire on Dreadmist Peak 47,19, stone timer, hand-in at Ak'Zeloth 62,20. Source: Classic quest databases (Forever page on metaforge.app refused the fetch, 403).

## 2026-11-05

### Leatherworking recheck
- Reagents and products of every trainer recipe on Wowhead Forever match the game tables exactly. Wowhead's own craft counts match the planner's skill-up formula (35 Embossed Leather Gloves for 55-85 on both).
- Added what the plan left out: trainer cost of each recipe (from Wowhead Forever) and the ranks (Apprentice 10c, Journeyman 5s at skill 50, cap 75 until then; Expert 50s at 125 only needed past 150). A recipe not learned yet now pays its training cost spread over the crafts it would still give. Route unchanged; recipe training 19s, ranks 5s 10c, net after training about +2g 3s.
- Hillman's Cloak (143-150) only breaks even after its 6s training; it stays because nothing else at that skill sells better.
- Wowhead shows no character level for the ranks. If the trainer refuses Journeyman, the level is the limit (Classic: 10).

### Live data check (all addons against today's web and game data)
- Item data refreshed to the live build: `itemstore.py fetch 1.60.1.70790` (19,307 items; 50 added, 40 changed since 70450, diff in `data\changelog`).
- **SoloSwing, SoloCombo**: every spell ID checked against the live SpellName table (wago.tools, build 70790). All exist with the right names. Forever adds new ranks (e.g. Rupture 1271514), but both addons match auras by name, so those work too.
- **SoloGear**: weapon types, shields and the level 40 mail and plate rule checked for all nine classes against senseos.gg's Forever weapon skills table: all match (rogue axes already added). `Upgrades.lua` rewritten: the old seed list was partly from memory and wrong (Cruel Barb is a Deadmines drop, not a Wailing Caverns quest reward). Now Mobalytics' Forever dungeon weapon list plus leatherworking crafts with live required levels. Found: Blade of Cunning is a dagger.
- **Leatherworking plan** rebuilt from live data. `tools\lw_plan.py` now reads Forever's own recipe colours, reagents and products (SkillLineAbility, SpellReagents, SpellEffect, build 70790) and Wowhead Forever learn levels; the Classic numbers are gone. Forever changed a lot: Light Leather Pants learn 70 and grey at 130 (Classic 95 / 155), Toughened Leather Armor needs 2 Cured Light Hide (6), Medium Leather from 4 Light Leather and Heavy Leather from 5 Medium are new trainer recipes. New plan: Light Armor Kit to 15, Handstitched Pants to 30, Cured Light Hide to 35, Embossed Vest to 50, Embossed Pants to 70, Light Leather Pants to 116, Hillman's Shoulders to 143, Hillman's Cloak to 150. About +2g 27s against vendoring the leather; 837 Light Leather, 127 Medium, 77 Light Hide, 38 Heavy, 32 Medium Hide.
- **SoloRoute** `Routes.lua` rewritten from Wowhead Forever (quest IDs, givers, turn-in NPCs, coordinates) and warcraft.wiki.gg Forever pages (objectives). Fixes: Thazz'ril's Pick is 6394 (was 6461); Cook Torka, Furl Scornbrow and Lar Prowltusk positions were wrong; Break a Few Eggs is given in Razor Hill; A New Plague part 1 is Darkhound Blood (not murloc scales); Hides for the Forsaken and Tomb Weed have real quest IDs and givers in east Tirisfal. Added the Forever quests: Wayward Weapons, Legging It, For Honor, This Fruit Could Bite Back, Lost in the Shadows, Bloodtalon Matriarch, Forgotten Loa Idols, A Missing Hand, Threat from Below, Stormy Potential (Durotar); A Light in the Darkness, Patience, Discipline, Sticks and Bones (6-slot bag), Seeking Refuge, Hides for the Forsaken, Tomb Weed, Shadowvale Green Elixir (Tirisfal). Steps without a verified position now have no pin instead of a guessed one. "Do" step titles keep inner colons ("WANTED: Maggot Eye").
- Interface 16001: Wowhead tags new Forever quests "first seen in patch 16001", and all addons load with it.
- Wowhead started showing a human-verification page after about 100 quick reads. It was not completed, so objective text came from warcraft.wiki.gg instead. Not found anywhere: objectives for Threat from Below, Stormy Potential, A Simmering Storm, Halikor's Hoof (their steps say "follow the quest text").
- `ROGUE.md`: Blade of Cunning noted as a dagger; dungeon weapon list now the Mobalytics Forever one.

### Rogue
- `ROGUE.md`: weapon trainers corrected. One-Handed Swords only from Archibald in Undercity (57.3, 32.8); Orgrimmar (Sayoc, Hanashi, 81.5, 19.6) teaches One-Handed Axes but not swords. Source: Warcraft Tavern Forever weapon trainer guide.
- **SoloGear**: one-handed axes allowed for rogues (Forever change; the Classic table marked them "can't wear yet"). Not yet tested in game.
- `ROGUE.md`: levelling spec checked against Icy Veins (updated 3 Nov, talent order read from its level slider in the browser) and Mobalytics (4 Nov). Both pick Combat, 16/35/0, Blade Flurry at 30, Adrenaline Rush at 40, with Forever's new talents (Efficient Strikes, Coup de Grace, Composure, Hack and Slash, Flash of Steel). The two orders differ only on Endurance (21-22 or 24) and Dual Wield Specialization before or after Hack and Slash. Rotation, gear, milestones and Troll racials included.
- **SoloCoach**: `Advice.lua` replaced (the 18 Oct beta notes are gone) with the talent order, rotation and gear notes; the panel opens by itself after the next /reload.

### Addons
- **SoloPlus**: auto repair now off by default (low levels rarely need it); `/sp repair` turns it on. Selling greys stays on.
- **SoloRoute v1.0** (new): levelling route panel, our own ForeverWisp. `Routes.lua` holds Durotar 1-10 (79 steps) and Tirisfal Glades 1-10 (75 steps) from Classic quest data (warcraft.wiki.gg, fetched today), with Forever's extra quests as notes. Steps are accept / do / turn in / note with a quest ID, a text and zone coordinates; accept and do steps tick off from the quest log (by ID or title), turn-ins by the completed flag or by the quest leaving the log, notes by the Done button. Each new step sets the game's map waypoint (`C_Map.SetUserWaypoint`, map ID resolved by zone name since Classic and retail IDs differ). Route picked by race, `/route use <key>` to change. Not yet tested in game.
- **SoloPlus v1.0** (new): the useful part of Leatrix Plus. Sells greys and repairs at any merchant with a chat summary, `/sp lw` leatherworking plan step for the current skill (and a line each time the skill reaches a new step), red warning on logout outside an inn or city. Not yet tested in game.
- **SoloGear v1.1**: `/sg bis` lists equipped slots weakest first with their scores, then upgrade sources near your level from the new `Upgrades.lua` (rogue seed: Wailing Caverns set pieces, Cruel Barb, Ragefire Chasm cuffs and cape, Deviate Scale patterns, leatherworking pants). Our own Forever Leveling BiS, filled in by Claude rather than a database. Not yet tested.
- **SoloCombo v1.0** (new): rogue strip under the SoloSwing bars. Five combo point pips with a big count (red at 5), an energy bar, and timers for Slice and Dice, Rupture, Garrote and Expose Armor from the aura lists (own buffs, own debuffs on the target, matched by name across ranks). Every read is pcall-wrapped for the 12.x secret values: energy is fed to the StatusBar as is and the number hidden when secret; a secret aura time goes to a Blizzard Cooldown frame (`SetCooldownFromExpirationTime`), else "?". `/sc test|scale|reset|energy|debug`; debug log in `SoloComboDB.log`. Linked into `_forever_`. Not yet tested in game: needs a logout to character select.
- **SoloCoach v1.1**: snapshot taken while playing instead of only at `PLAYER_LOGOUT`: 5 s after login, then every 60 s, and 3 s after a level, gold, gear, bag, quest, zone or skill change (one snapshot per burst). A blank snapshot (no XP max, no gold, no gear: what logout gives on live) is thrown away so the last good one is what the game saves. `/coach snap` says when the client gave no data. Not yet tested in game.

### Tools
- `tools\lw_plan.py` + `LEATHERWORKING.md`: leatherworking 1-150 plan that loses the least at the vendor. Classic thresholds and reagents (warcraft.wiki.gg), Forever prices from `items.db` build 70450. Rule: among recipes with at least a 50% skill-up chance, make the one with the best net cash per craft (sell price minus bought reagents minus the leather's raw vendor value). Result: Light Armor Kit to 15, Handstitched Pants to 35, Cured Light Hide to 40, Embossed Vest to 55, Embossed Boots to 75, Embossed Pants to 95, Light Leather Pants to 141 (+2s 49c each), Dark Leather Pants to 150. About 1,017 Light Leather, 137 Medium Leather, 79 Light Hide, 220 Coarse Thread, 79 Salt, 62 Fine Thread, 11 Gray Dye; net about +1g 77s over selling the leather raw. Forever's Dark Leather Boots is a new rare item with no vendor price, so it is skipped.

### Findings (live rescan)
- WoW Forever is live. Client patched to 1.60.1.70790. All five addons load on live with `## Interface: 16001` (every one wrote its SavedVariables; `AddOns.txt` lists them enabled). Exact interface number still unconfirmed.
- Two characters: a Troll Rogue (level 5, Durotar, main) and an Undead Rogue (level 1, Tirisfal). `GetRealmName` returns a placeholder realm name.
- **SoloCoach**: every live snapshot (4 saves, all on logout) is blank: gear all "empty", bags 0 items / 0 free, money 0, xp 0, xpMax 0, rested 0, quest levels 0 with no objectives, position "not available". The session block saved at login is right (425 copper at the main character's login), so the API works while playing and is gone by `PLAYER_LOGOUT` on this client. Beta tests only used /reload. Fix to do: take the snapshot on a timer and on quest/level/money events while playing, and skip the logout one when `UnitXPMax` is 0.
- **SoloCoach**: `Advice.lua` still holds the 18 Oct notes for the beta level 8 Forsaken; `SoloCoachDB.seen` matches, so the panel does not pop. Replace when the first live advice is written.
- **SoloStats**: XP tracking works on live (main character: 5,696 XP, 10 kill samples of 56-82 XP). Settings saved: Top bar, Forsaken theme, centred.
- **SoloQuest**: enabled on live; the main character holds 15 quests, so accept works. New Forever quest IDs seen (96822 For Honor, 96825 This Fruit Could Bite Back, 97223 Bloodtalon Matriarch, 97225 Forgotten Loa Idols, 96875 Beasts of Thunder Ridge, 97906 Camping 101: Leatherworking) next to Classic ones (805, 818, 784).
- **SoloGear**, **SoloSwing**: load, no settings changed yet. Both characters are rogues: the Heroic Strike / Slam parts of SoloSwing are not in use; the dual-wield off-hand bar will matter from level 10.
- Code review against the 12.x engine found no new errors. Unverified risks: `C_Spell.IsCurrentSpell` and `UnitAffectingCombat` in SoloSwing's `OnUpdate` are not pcall-protected, so a secret value there would error every frame; SoloGear's item stats maths has no pcall either.
- Docs: `CLAUDE.md` and README updated with the build, the character folders and the logout finding. `TESTING.md` unchanged.

## 2026-11-02

### Project
- Moved to the live client: junctions for SoloCoach, SoloGear, SoloQuest, SoloStats and SoloSwing now in `_forever_\Interface\AddOns`, removed from `_classic_beta_`. `link.ps1` defaults to `_forever_`. `CLAUDE.md` and README updated (paths, account folder). Not yet loaded or tested in game.
- `_classic_beta_` no longer has a `WTF` folder, so beta addon settings and SoloCoach data are gone from there.

### Findings
- Launch: 4 Nov 2026 23:00 UTC. Beta characters do not carry over. Live build on this PC: 1.60.1.70707.

## 2026-10-18

### Addons
- **SoloStats v2**: SoloLevel merged in. One readout: FPS, latency, level and XP, XP/h and time to level, kills to level, rested XP, session.
  - Options panel (`/ss` or right-click the readout, Esc closes): each line on/off, show readout, background, lock position, text size (-/+), reset position, reset session.
  - Four themes, switchable: Blizzard classic (default), Forsaken, Minimal dark, Horde. Background panel uses the theme colours.
  - Files: `Themes.lua`, `SoloStats.lua`, `Options.lua`. Session now per character in `SoloStatsSession`. Old position and text size kept.
  - Commands: `/ss pos` (or `reset`) position, `/ss session`, `/ss size`, `/ss theme <classic|forsaken|minimal|horde>`, `/ss hide|show`. `/sl` removed.
  - Not yet tested in game.
- **SoloStats v2.1**: layouts and info items.
  - Layouts: Stacked (one item per line), Row (one line, movable), Top bar (full screen width at the top, text centred, not movable). Buttons in the panel or `/ss layout stack|row|bar`.
  - New info items (own column in the panel): gold, bag space (free / total, special bags skipped), durability (lowest equipped item), time, date, zone, coordinates. Gold, bags, durability and time on by default; date, zone and coordinates off.
  - Row and Top bar use short forms (e.g. "Kills: 12", "Rested: 28%") with "|" separators.
  - Coordinates show "--, --" in instances or if the client hides them.
  - Tested in game (screenshot, Tirisfal Glades, level 8): top bar loads, centred across the top, clear of the minimap. FPS, latency, level, XP/h, time to level, kills, rested, session, gold, bags (3 / 26 in red), durability and time all show. Options panel, other layouts and themes not yet checked.
  - Found: compact "Kills: 84" reads like a kill count (it is kills to level); latency is ~190 ms from here, so it is always red with the 80/150 ms limits.
  - Fixed: compact label now "Kills to level: 84"; latency green up to 150 ms, yellow up to 250 ms, red above.
  - Fully tested in game (5 screenshots, Brill): options panel, all toggles, Stacked / Row / Top bar, background, lock, text size, themes (Forsaken in use), reset position and session. Coordinates match the minimap (not hidden by the client). Bags show 0 / 26 in red when full.
  - Found: with every item on, the top bar is wider than the space left of the buffs, so zone and coordinates run under the buff icons at the top right. Fix on the user's side: move the minimap and buffs down in Edit Mode.
  - Added: top bar text alignment Left / Centre / Right (panel row "Top bar text", `/ss align left|centre|right`), for different UI setups. Default Centre. Not yet tested in game.
- **SoloLevel** retired: junction removed from AddOns, source moved to `_retired\SoloLevel`.

- **SoloQuest**: tested in game, works.
- **SoloGear**: bag "+" tested on early gear (no stats); gear with stats still to test.
- **SoloCoach**: snapshot tested (taken 11:34): gear, bags (5 free), quests with objectives, position, session all saved. "skills" failed: `GetNumSkillLines` does not exist on this client. Fix: falls back to `GetProfessions` (professions only; weapon skills have no API here). A part that returns nothing now says "not available on this client" instead of "error: nil". Fix not yet tested.
- Screenshot 11:37: SoloStats top bar left-aligned works; SoloCoach notes panel opens with `/coach`.
- **SoloGear**: weapons scored. Found because the crafted Copper Claymore (7.7 DPS) got no "+" against the Forsaken Bastard Sword (2.7 DPS).
  - Score adds weapon damage per second x 5 for strength and agility classes (about 7 Strength per DPS in Classic), x 0.3 for casters. Ranged slot: x 5 hunters, x 2 casters (wands), x 0.5 others.
  - DPS from item stats, or read from the tooltip if the stats leave it out.
  - Two-handers compare against main hand plus off hand. Off-hand items while wielding a two-hander compare against the two-hander. One-handers compare against the weaker hand once you can dual wield.
  - New checks: weapon types per class (Classic rules), shields only for warriors, paladins and shamans, required level for every item.
  - Shields, off-hands and ranged weapons now scored too.
  - Tested in game: Copper Claymore shows "SoloGear: +26.5 upgrade" (exactly the predicted 7.7 x 5 + 1.5 - 2.7 x 5) and a green "+" in the bags. Shields, off-hands, ranged, class and level checks not yet tested.
- **SoloCoach**: first real advice written to `Advice.lua` (11:45): levelling route for the 12 quests in the log, gear and bag tips. Snapshot 11:38 still had the skills error because a /reload saves with the old code; fix shows from the next /reload.

### Project
- `TESTING.md`: checklist of every in-game test still to do, per addon. Linked from the README.

### Tools
- Claude Code side pane "WoW addons" (mod `wow-addons` in the local Claude Code dev-mods folder): reads the addon table in this README and lists each addon with its status (green when working, yellow when not fully tested) and features. Redraws after file edits; Refresh button; `/addons` reopens it. Validated and tests pass; not type-checked (no TypeScript on the PC). Loads only for the session that made it, after hot reloading is enabled.

## 2026-10-17

### Project
- Project folder `H:\WoW Addons` created. Addons linked into `_classic_beta_\Interface\AddOns` by junction (`link.ps1 <Name> [-Flavour _retail_]`).
- README with addon list, ideas, tools and client limits.
- `CLAUDE.md` with setup, client limits, file paths, the SoloCoach loop and the logging rule, so a new Claude chat started in this folder has the context.

### Addons
- **SoloStats**: FPS and home/world latency, top-left corner. Shift-drag, `/ss reset|size|hide|show`. Text size option added. Tested.
- **SoloLevel**: XP/h, time to level, kills to level (last 10 kills), rested XP, session totals. Sticks under SoloStats. Text size option added. Tested.
- **SoloQuest**: auto accept quests, auto turn in when there is no reward choice or gold cost. Shift pauses, `/sq on|off`. Not confirmed in game.
- **SoloGear**: green "+" on bag armour/jewellery upgrades, tooltip score by class primary stat, armour type by class and level. Quest reward pick: biggest upgrade, else highest sell price. Tooltip and reward pick tested; bag marks not confirmed. Weapons not scored.
- **SoloSwing**: melee swing timer, main and off hand, warrior extras (Heroic Strike/Cleave queued colour, Slam window).
  - v1 used the combat log: blocked by the client (ADDON_ACTION_FORBIDDEN).
  - v2 read swings from UNIT_COMBAT, but the auto attack check dropped every hit.
  - v3 hit the "secret value" error: `UnitAttackSpeed` is hidden in combat. Speeds now cached out of combat, tooltip "Speed" as fallback.
  - Debug lines saved to `SoloSwingDB.log` (WoW's /chatlog skips addon output).
  - Tested with 1H (1.9 s): swings within -0.12 to +0.15 s.
  - 2H test (3.3 s) showed ability hits taken as swings and target swaps restarting the bar. Fixed: hits within 0.5 s of an instant cast ignored unless a swing was due; timers kept across target changes; tolerance 0.3 s. Not yet retested.
- **SoloCoach**: bridge to Claude. Snapshot (gear, bags, quests, level, gold, zone, session) saved on /reload or logout; Claude's notes from `Advice.lua` shown in a panel (`/coach`). Not yet tested.

### Tools and data
- `tools\blizzard_api.py`: Blizzard Game Data API test client. API client "SoloAddons" created; keys in `tools\blizzard_api.json`. Classic Era namespace works; WoW Forever is not in the API.
- `tools\itemstore.py`: Forever item store from wago.tools. Builds 1.60.1.70425 and 1.60.1.70450 stored in `data\items.db`. First item changelog: 23 items added, none changed (`data\changelog\`).

### Findings
- Forever beta 60 fps cap is a client bug (thermal state misread from NVIDIA `API_TRIGGERED`), confirmed by Blizzard; not caused by addons or settings.
- Client limits for addons: no combat log, secret values in combat, `/chatlog` skips addon prints. See README.

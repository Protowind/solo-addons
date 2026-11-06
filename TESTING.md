# In-game tests pending

Tick each box when done. Tell Claude what failed (a screenshot helps). Updated 2026-10-18.

## SoloStats (v2.1)

All tested 2026-10-18 (screenshots: every layout, background, lock, text size, themes, both resets, coordinates match the minimap, bags 0 / 26 red when full).

- [x] /reload: top bar now says "Kills to level: N", and latency around 190 ms is yellow (not red)
- [x] Right-click the readout: options panel opens. `/ss` opens it too. Esc closes it
- [x] Panel can be dragged. Close button (X) works
- [x] Untick and tick each readout item and each info item: the readout changes at once
- [x] Turn on Date, Zone, Coordinates: they show. Coordinates update as you walk
- [x] Coordinates in an instance show "--, --" (no error)
- [x] Layout Stacked: one item per line, Shift-drag moves it
- [x] Layout Row: one line, Shift-drag moves it, position kept after /reload
- [x] Layout Top bar: back across the top, cannot be dragged
- [x] Lock position ticked: Shift-drag does nothing
- [x] Background off and on: box disappears and comes back
- [x] Show readout unticked: readout hides; `/ss` still opens the panel
- [x] Text size - / + / Default: text resizes, background fits it
- [x] Each theme button: readout and panel change colour; the chosen button stays highlighted
- [x] Reset session: XP/h and session time restart
- [x] Reset position: readout goes back to the top-left corner (Stacked or Row)
- [x] Bags: loot an item, bag count drops; sell it, count rises
- [x] Durability: drops after a death or long fights; goes red under 20%
- [x] Gold: changes when you loot or sell
- [x] Log out and back in: settings kept, session restarts
- [x] /reload, Top bar layout: "Top bar text" Left works (screenshot 11:37); Centre already seen
- [ ] Top bar text Right
- [ ] `/ss align left`, `/ss align right`, `/ss align centre` do the same

## SoloQuest

All tested 2026-10-18: works.

- [x] Talk to a quest giver: quest accepted without clicking Accept
- [x] Hand in a quest with no reward choice: turned in automatically
- [x] Hand in a quest with a reward choice: NOT turned in automatically
- [x] Hold Shift while talking: nothing automatic happens
- [x] `/sq off`: nothing automatic. `/sq on`: works again

## SoloGear

Already tested: tooltip score line, quest reward pick label, bag "+" on early gear (no stats).

- [x] Green "+" shows on a better armour or jewellery piece in your bags
- [ ] Upgrades with stats (Strength, Stamina, Agility): "+" and tooltip score look right
- [x] Weapons: before equipping the Copper Claymore, it shows a green "+" in bags and about "+26 upgrade" in its tooltip (screenshot: "+26.5 upgrade", "+" on the bag icon)
- [ ] Weapons: the old Forsaken Bastard Sword shows "worse" once the Claymore is on
- [ ] Weapons you can't use (wands) or above your level say "can't wear yet"
- [ ] No "+" on items you can't wear (wrong armour type, level too high)
- [ ] Quest reward pick is printed in chat at turn-in
- [ ] `/sg primary str`, then `/sg primary auto`: scores change, then go back

## SoloSwing

Already tested: 1H swing timing (within 0.15 s).

- [ ] 2H weapon: Heroic Strike and Rend hits no longer restart the bar
- [ ] 2H weapon: changing target mid-fight does not restart the bar
- [ ] Bar turns orange while Heroic Strike or Cleave is queued
- [ ] Green Slam window shows near the end of the swing (once you have Slam)
- [ ] Turn on `/sw debug` for a few fights, then /reload so the log saves for Claude

## SoloRoute (new 2026-11-05)

- [ ] Panel shows at login with the Durotar route (Troll) or Tirisfal (Undead) and the first step not yet done
- [ ] Accepting a quest named in the current step moves the route on by itself (chat line "step N (done)")
- [ ] A map pin appears for the new step (arrow at the top of the screen); `/route pin` sets it again
- [ ] Done / Back buttons and `/route step 12` work; Shift-drag moves the panel
- [ ] Any step that never ticks off by itself: tell Claude which (wrong quest ID or title)
- [ ] Coordinates that are wrong by more than a few points: tell Claude the right ones

## SoloPlus (new 2026-11-05)

- [ ] Open a vendor with grey items in the bags: they are sold, chat says how many and for how much
- [ ] Open a vendor with damaged gear: NOT repaired (off by default). `/sp repair`, open again: repaired, chat says the cost
- [ ] `/sp lw` with Leatherworking: prints the current step and the next one
- [ ] Log out in the open: red warning line; log out in an inn: nothing

## SoloGear v1.1

- [ ] `/sg bis`: slots listed weakest first with scores; upgrade sources shown near level 13-18

## SoloCombo (new 2026-11-05)

- [ ] Strip shows under the SoloSwing bars; `/sc test` shows all four timer bars for 8 s; Shift-drag moves it
- [ ] Combo points: pips fill as you build, count goes red at 5, clears on a new target
- [ ] Energy bar moves out of combat and shows the number
- [ ] In combat: does the energy number vanish (secret) while the bar still moves? Tell Claude
- [ ] Slice and Dice bar counts down when you use it; Rupture / Garrote / Expose Armor bars appear on the target
- [ ] In combat: do the timer bars count down, or show a Blizzard cooldown sweep (secret time), or "?" (both failed)?
- [ ] `/sc debug` on for a fight, then /reload: the log in `SavedVariables\SoloCombo.lua` says what was secret

## SoloCoach

- [ ] v1.2: `/coach guide` lists 5 guides in chat; `/coach guide 1` opens the rogue talents; `/coach` still opens Claude's notes
- [ ] v1.1 (2026-11-05): play a few minutes, log out, log back in: Claude can read gear, bags, gold, XP and quest objectives from the logout save (the live saves before this were blank)
- [ ] `/coach snap` right after login says "snapshot taken" (not "kept the last snapshot")
- [x] /reload: no errors
- [x] Ask Claude a question: Claude can read your snapshot (gear, bags, quests, level, gold, zone)
- [ ] After Claude writes advice and you /reload: notes panel opens by itself
- [x] `/coach` opens the panel (screenshot 11:37); close button shown
- [x] `/coach snap` saves a new snapshot (Claude read it: gear, bags, quests, position, session all there)
- [ ] /reload once more: snapshot "skills" now lists professions (Mining) instead of an error. (The 11:38 snapshot still had the error: a /reload saves with the code loaded before it, so the fix shows from the next one.)

## SoloMap (new 2026-11-06)

- [x] Open the map: "You: x, y   Cursor: x, y" under the map (screenshot 2026-11-06)
- [x] Click the coordinate bar: box with the position selected; Ctrl+C closes it and pastes elsewhere (pasted "Mulgore 46.1, 95.8", 2026-11-06)
- [ ] Right-click the bar: box with the last spot the cursor was on the map
- [ ] `/smap copy`: same as clicking the bar
- [ ] Barrens map: flight master icons at Crossroads, Camp Taurajo, Ratchet; Crossroads coloured, Thunder Bluff and Taurajo grey
- [ ] Hover an icon: name, "Flight Master", Known / Not known yet, coordinates
- [ ] Open a flight master's map once: every path you know turns coloured
- [ ] Discover Camp Taurajo: chat "flight path added", icon turns coloured
- [ ] Talk to a vendor, repair NPC, trainer, innkeeper, open a mailbox: an icon appears there on the map
- [ ] Unexplored parts of the Barrens and Mulgore show dimmed (not black)
- [ ] `/smap fog`, `/smap flights`, `/smap services`, `/smap coords` each hide and show their part
- [ ] `/smap list`: flight paths known and places per zone
- [ ] No Lua errors when opening the map in a city, an instance, and the continent view

## SoloStats copy (2026-11-06)

- [x] Ctrl-click the readout: box with your zone and coordinates selected; Ctrl+C copies and closes it (pasted "The Barrens 41.7, 58.6", 2026-11-06)
- [ ] `/ss copy` does the same; Esc closes the box
- [ ] Plain left-click and Shift-drag still behave as before

## SoloLoot (new 2026-11-06)

- [x] `/sloot` (or `/loot`) opens the window; Esc closes it; it can be dragged and stays put after /reload
- [x] Opens on Ragefire Chasm or Wailing Caverns (fits level 13) (screenshot 2026-11-06)
- [x] Click Ragefire Chasm > Taragaman: Cursed Felblade, Crystalline Cuffs, Subterranean Cape with icons and green/blue names (screenshot 2026-11-06)
- [x] Items that show "Loading item ..." fill in after a second
- [x] Hover an item: normal item tooltip
- [x] Shift-click an item with the chat box open: link goes into chat
- [x] Ctrl-click: preview window
- [x] Green + on an item SoloGear rates as an upgrade (screenshot 2026-11-06)
- [x] Mouse wheel scrolls each column
- [x] Item sets tab: list of sets; "My class only" on shows rogue and all-class sets; untick shows all; pieces show tooltips with set bonuses
- [x] Raid boss with no loot data shows "?" and "No loot for this boss in the data yet."
- [x] Minimap button: shows on the minimap edge, click opens and closes the window, drag moves it round the edge, position kept after /reload
- [x] `/sloot minimap` hides the button; again shows it
- [x] Look: three framed panels with gold title strips; Dungeons and Raids headings in the instance list; selected tab highlighted (screenshot 2026-11-06)

## SoloPlates (new 2026-11-06)

- [ ] /reload: enemy nameplates are flat bars with a thin black edge and dark background; names outlined
- [ ] Bars keep Blizzard's colours (red hostile, yellow neutral) and drain as the mob loses health
- [ ] The flat look stays during and after a fight (Blizzard does not put the old texture back)
- [ ] Cast bar of a casting mob (Razormane Thornweaver) is flat too
- [ ] `/splates height 12` and `/splates size 12` change the plates (height only out of combat)
- [ ] No Lua errors in combat or in a dungeon
- [ ] If anything looks wrong: target the mob, `/splates dump`, /reload, tell Claude

## SoloUI (new 2026-11-06)

- [ ] `/sui`: Guides button top right (left of the close button); click lists Claude's latest notes and 5 guides; a pick opens it in the SoloCoach panel, scrolled to the top; menu closes
- [ ] /reload: flat player frame left of centre, Blizzard's player frame gone; no Lua errors
- [ ] Target a mob: flat target frame right of centre with level, name, health and power; Elite/Rare tag on elites
- [ ] Your debuffs (Rupture, Garrote) show above the target frame with a timer spiral
- [ ] Target of target small frame under the target frame when the mob targets you
- [ ] Health numbers in and out of combat (in combat they may vanish if the client keeps them secret: bars must still move)
- [ ] Left-click a frame targets it; right-click opens the unit menu; works in combat
- [ ] Party: join a group, 4 party frames top-left with class colours
- [ ] Shift-drag moves a frame; position kept after /reload; Reset positions puts them back
- [ ] `/sui`: Solo addons window lists every addon, loaded state and notes; each button opens that addon's options or status
- [ ] Untick an addon, Reload to apply: it is off; tick it again to bring it back
- [ ] Untick "Hide Blizzard's frames", reload: Blizzard's frames come back alongside

## SoloLoot 1.1 (ForeverDB data)

- [ ] Instance list: Dungeons, Raids, then "Not announced for Forever yet" (greyed: Molten Core, Blackwing Lair, AQ, Naxxramas, Zul'Gurub)
- [ ] New Forever dungeons marked green "new": The Hall of Thanes, Ruins of Lordaeron, Excavation Site: Wetlands, City of Dalaran
- [ ] Ragefire Chasm 13-18 lists Oggleflint, Taragaman, Jergosh, Bazzalan and a blue "Notable loot (ForeverDB)" row
- [ ] Footer shows the ForeverDB.net credit with the link, on two lines without overlapping the panels
- [ ] Ragefire Chasm: "Entrance  Orgrimmar x, y" under the boss list; Show on map sets a pin (arrow at the top of the screen) at the Cleft of Shadow entrance
- [ ] Wailing Caverns entrance in The Barrens near the Lushwater Oasis; Deadmines in Westfall
- [ ] The Hall of Thanes shows "Beneath Ironforge, Dun Morogh" and no map button

## SoloGear auto-equip (new 2026-11-06)

- [ ] Loot or get a quest reward that is a bound armour upgrade: it goes on by itself out of combat, chat says "equipped X (+n) instead of Y"
- [ ] A weapon upgrade: popup "equip X? Upgrade +n"; Yes equips it, No leaves it (asks once per session)
- [ ] A bind-on-equip upgrade: popup first; Yes then shows the game's own "bind this item?" question
- [ ] Take an item off yourself and put the old one on: SoloGear does not swap it back
- [ ] Nothing happens in combat; it catches up when combat ends
- [ ] `/sg auto` turns it off and on; `/sg autoweapons` lets weapons equip without asking; `/sg` shows both settings

## SoloMeter (new 2026-11-06)

- [ ] /reload: a small dark window bottom right says "Damage · current" with "no data yet"; if it says "meter not available", run `/meter debug` and check the game's own meter is on (Options > Advanced > Damage Meter)
- [ ] `/meter test`: eight class-coloured bars, your name in gold on the first, numbers like "18.2k (61.2, 25%)"; `/meter test` again turns it off
- [ ] Fight a mob: your bar appears while fighting with a total and per-second figure (no % in combat); after the fight the % appears
- [ ] Click the header: menu with the five modes, Current fight, Overall, Reset data, Hide. Pick Healing, then Damage again
- [ ] Right-click the header: swaps current and overall (header text changes). Mouse wheel on the header cycles the modes
- [ ] After a fight, click your bar: spell list with icons (Sinister Strike, melee...), numbers per spell; right-click a bar or click the header goes back
- [ ] In a group: the other players' bars show with their class colours; your bar stays on the last row when you are further down
- [ ] Reset button (top right) or `/meter reset`: bars clear, "no data yet"
- [ ] Shift-drag the header to move; position kept after /reload. `/meter pos` puts it back bottom right
- [ ] `/meter rows 5`, `/meter scale 1.3`, `/meter width 300`, `/meter height 22`: window resizes; `/meter class` greys the bars
- [ ] `/meter debug` after a fight, then /reload: `SoloMeterDB.debug` in `WTF\Account\<account>\SavedVariables\SoloMeter.lua` lists the session, source and spell field names (tell Claude what it says)
- [ ] `/sui`: SoloMeter row shows loaded, its `/meter` button toggles the window
- [ ] Out of combat, click the header: under Overall a "past fights" list with the last six mobs and fight lengths. Pick one: header shows "Damage · <mob> 0:33" and that fight's bars; right-click the header goes back to current
- [ ] In combat, click your bar: one line "spells readable after the fight" instead of rows of "?"
- [ ] After a dungeon pull, Damage taken mode, click your bar: each spell row names the mob in grey, e.g. "Curse of Agony  Searing Blade Cultist (elite)"; hover shows "From ...". Past fights: the boss line is red without the "(!)"

## SoloErrors (new 2026-11-06)

- [x] (2026-11-06) /reload: no chat line from SoloErrors (nothing saved yet), or "N saved errors" if something errored. `/errors` says "no errors saved"; if it adds "no seterrorhandler on this client", tell Claude
- [x] (2026-11-06, logged x6 with stack) `/errors test`: chat line "new error in SoloErrors (1 so far, /errors to list): ...test error"; no Blizzard popup
- [ ] `/errors`: the test error listed with x1; `/errors 1` shows it with a stack; `/errors test` again then `/errors`: x2
- [ ] `/errors popup`, then `/errors test`: Blizzard's error window also opens; `/errors popup` again turns it off
- [ ] /reload: "1 saved error" line at login; `WTF\Account\<account>\SavedVariables\SoloErrors.lua` holds it; `/errors clear` empties it
- [ ] Play for a while: any addon error shows as one chat line, not a repeating popup; after /reload Claude reads the file
- [ ] `/sui`: SoloErrors row shows loaded

## SoloMeter fight capture (2026-11-06)

- [ ] Fight a mob to the end, wait 3 s, `/meter fights`: one line "1. <time> <zone> vs <mob>: <n>s, you <total> (<n>/s)"
- [ ] Two more fights: three lines. `/meter capture now` adds one more
- [ ] /reload, then tell Claude: `SoloMeterDB.fights` and `SoloMeterDB.probe` in `WTF\Account\<account>\SavedVariables\SoloMeter.lua` are read for the real field names and which values are secret in combat
- [ ] `/meter capture` says "fight capture off"; a fight adds no line; `/meter capture` again turns it on
- [ ] `/meter capture clear`: `/meter fights` says none saved

## Sweep fixes (2026-11-06)

- [ ] SoloUI: target a caster mob: its cast bar still shows (now under the target of target frame, or at Blizzard's old spot if the game re-anchors it)
- [ ] SoloUI: with SoloErrors loaded, a SoloUI frame error appears in `/errors` (not only in chat)
- [ ] SoloSwing: swing bars still restart on each hit after a /reload, also after swapping weapons (`/sw debug` log shows speeds after equip)
- [ ] SoloCombo: `/sc debug`, fight with Slice and Dice and Rupture up: timers show in combat; if the log says "aura id and name are secret in combat", tell Claude
- [ ] SoloMeter: `/meter test` first bar shows your character's name

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

# Leatherworking 1-150 for WoW Forever: level up, earn the most at the vendor

Made by `tools\lw_plan.py` from live Forever data (build 1.60.1.70790): recipe colours, reagents and products from the game's own tables (wago.tools), learn levels from Wowhead Forever, sell and buy prices from `data\items.db`. Leather and hides count at their raw vendor value, so a positive net means the crafted item sells for more than its leather would have. Trainer recipes only; recipes needing elixirs, silk or other bought-from-players items are left out. Crafts are expected values.

In game: `/sp lw` shows the step for your current skill.

Profession ranks: Apprentice (cap 75), Journeyman at skill 50 for 5s (cap 150), Expert at 125 for 50s (needed only to go past 150). Wowhead lists no character level for the ranks; if the trainer refuses Journeyman, your level is the limit (it was level 10 in Classic).

| Skill | Recipe | Learn at | Training | Crafts | Mats per craft | Net per craft | Net for the step |
|---|---|---|---|---|---|---|---|
| 1-15 | Light Armor Kit | 1 | known | 14 | 1 Light Leather | 0c | 0c |
| 15-30 | Handstitched Leather Pants | 15 | 50c | 15 | 4 Light Leather, 1 Coarse Thread | 1c | 15c |
| 30-35 | Cured Light Hide | 30 | 50c | 5 | 1 Light Hide, 1 Salt | 10c | 50c |
| 35-50 | Embossed Leather Vest | 35 | 1s 0c | 15 | 8 Light Leather, 4 Coarse Thread | 32c | 4s 80c |
| 50-70 | Embossed Leather Pants | 50 | 2s 0c | 20 | 1 Cured Light Hide, 6 Light Leather, 2 Coarse Thread | 1s 37c | 27s 40c |
| 70-116 | Light Leather Pants | 70 | 4s 0c | 52 | 10 Light Leather, 1 Cured Light Hide, 1 Fine Thread | 2s 49c | 1g 30s 23c |
| 116-143 | Hillman's Shoulders | 105 | 5s 0c | 32 | 1 Cured Medium Hide, 4 Medium Leather, 1 Fine Thread | 1s 84c | 58s 55c |
| 143-150 | Hillman's Cloak | 125 | 6s 0c | 8 | 5 Heavy Leather, 2 Fine Thread | 77c | 5s 84c |

## Shopping and farming list (raw mats, cured hides expanded)

- Light Leather: 837 (farm)
- Medium Leather: 127 (farm)
- Coarse Thread: 115 (buy)
- Salt: 109 (buy)
- Fine Thread: 99 (buy)
- Light Hide: 77 (farm)
- Heavy Leather: 38 (farm)
- Medium Hide: 32 (farm)

Crafting against vendoring the leather raw: **2g 27s 47c**. Recipe training: 19s 0c. Ranks (Apprentice, Journeyman): 5s 10c. **Net after training: 2g 3s 37c**.

## Every trainer recipe to 150, best to worst per craft

| Recipe | Learn / yellow / green / grey | Mats | Sells for | Bought mats | Leather raw value | Net |
|---|---|---|---|---|---|---|
| Dusky Leather Armor (needs mats from other players) | 150 / 170 / 180 / 190 | 10 Heavy Leather, 1 Shadow Oil, 2 Fine Thread | 37s 60c | 2s 0c | 15s 0c | 20s 60c |
| Barbaric Shoulders | 150 / 170 / 180 / 190 | 8 Heavy Leather, 1 Cured Heavy Hide, 2 Fine Thread | 26s 9c | 3s 50c | 14s 0c | 8s 59c |
| Guardian Pants (needs mats from other players) | 135 / 155 / 165 / 175 | 12 Heavy Leather, 2 Bolt of Silk Cloth, 2 Fine Thread | 27s 94c | 2s 0c | 18s 0c | 7s 94c |
| Light Leather Pants | 70 / 100 / 115 / 130 | 10 Light Leather, 1 Cured Light Hide, 1 Fine Thread | 5s 99c | 1s 50c | 2s 0c | 2s 49c |
| Toughened Leather Gloves (needs mats from other players) | 110 / 135 / 147 / 160 | 4 Medium Leather, 2 Cured Medium Hide, 2 Elixir of Lesser Defense, 2 Spider's Silk, 2 Fine Thread | 9s 62c | 3s 0c | 4s 50c | 2s 12c |
| Nimble Leather Gloves (needs mats from other players) | 95 / 120 / 132 / 145 | 1 Elixir of Minor Agility, 6 Medium Leather, 1 Fine Thread | 5s 88c | 1s 0c | 3s 0c | 1s 88c |
| Hillman's Shoulders | 105 / 130 / 142 / 155 | 1 Cured Medium Hide, 4 Medium Leather, 1 Fine Thread | 6s 59c | 1s 50c | 3s 25c | 1s 84c |
| Embossed Leather Pants | 50 / 80 / 95 / 110 | 1 Cured Light Hide, 6 Light Leather, 2 Coarse Thread | 3s 47c | 70c | 1s 40c | 1s 37c |
| Green Leather Belt (needs mats from other players) | 135 / 155 / 165 / 175 | 1 Cured Heavy Hide, 5 Heavy Leather, 1 Fine Thread, 1 Green Dye, 1 Iron Buckle | 13s 11c | 2s 50c | 9s 50c | 1s 11c |
| Fletcher's Gloves (needs mats from other players) | 100 / 125 / 137 / 150 | 8 Medium Leather, 4 Long Tail Feather, 2 Fine Thread | 6s 90c | 2s 0c | 4s 0c | 90c |
| Hillman's Cloak | 125 / 145 / 155 / 165 | 5 Heavy Leather, 2 Fine Thread | 10s 27c | 2s 0c | 7s 50c | 77c |
| Embossed Leather Boots | 50 / 80 / 95 / 110 | 8 Light Leather, 5 Coarse Thread | 2s 17c | 50c | 1s 20c | 47c |
| Dark Leather Pants | 90 / 115 / 127 / 140 | 12 Medium Leather, 1 Gray Dye, 1 Fine Thread | 10s 89c | 4s 50c | 6s 0c | 39c |
| Embossed Leather Vest | 35 / 65 / 80 / 95 | 8 Light Leather, 4 Coarse Thread | 1s 92c | 40c | 1s 20c | 32c |
| Fine Leather Tunic | 60 / 90 / 105 / 120 | 3 Cured Light Hide, 6 Light Leather, 4 Coarse Thread | 4s 61c | 1s 90c | 2s 40c | 31c |
| Cured Medium Hide | 75 / 90 / 97 / 105 | 1 Medium Hide, 1 Salt | 2s 0c | 50c | 1s 25c | 25c |
| Embossed Leather Cloak | 40 / 70 / 85 / 100 | 5 Light Leather, 2 Coarse Thread | 1s 12c | 20c | 75c | 17c |
| Fine Leather Belt | 55 / 85 / 100 / 115 | 6 Light Leather, 2 Coarse Thread | 1s 25c | 20c | 90c | 15c |
| Cured Light Hide | 30 / 50 / 60 / 70 | 1 Light Hide, 1 Salt | 1s 10c | 50c | 50c | 10c |
| Embossed Leather Gloves | 40 / 70 / 85 / 100 | 3 Light Leather, 2 Coarse Thread | 71c | 20c | 45c | 6c |
| Handstitched Leather Pants | 15 / 45 / 60 / 75 | 4 Light Leather, 1 Coarse Thread | 71c | 10c | 60c | 1c |
| Light Armor Kit | 1 / 30 / 45 / 60 | 1 Light Leather | 15c | 0c | 15c | 0c |
| Light Leather | 1 / 20 / 30 / 40 | 3 Ruined Leather Scraps | 15c | 0c | 21c | -6c |
| Handstitched Leather Cloak | 1 / 40 / 55 / 70 | 2 Light Leather, 1 Coarse Thread | 34c | 10c | 30c | -6c |
| Medium Armor Kit | 75 / 90 / 97 / 105 | 4 Medium Leather, 1 Coarse Thread | 2s 0c | 10c | 2s 0c | -10c |
| Medium Leather | 75 / 75 / 80 / 85 | 4 Light Leather | 50c | 0c | 60c | -10c |
| Handstitched Leather Boots | 1 / 40 / 55 / 70 | 2 Light Leather, 1 Coarse Thread | 29c | 10c | 30c | -11c |
| Handstitched Leather Vest | 1 / 40 / 55 / 70 | 3 Light Leather, 1 Coarse Thread | 40c | 10c | 45c | -15c |
| Handstitched Leather Bracers | 1 / 40 / 55 / 70 | 2 Light Leather, 3 Coarse Thread | 28c | 30c | 30c | -32c |
| Light Leather Bracers | 45 / 75 / 90 / 105 | 6 Light Leather, 4 Coarse Thread | 84c | 40c | 90c | -46c |
| Hillman's Leather Gloves | 120 / 145 / 157 / 170 | 14 Medium Leather, 4 Fine Thread | 10s 49c | 4s 0c | 7s 0c | -51c |
| Light Leather Quiver | 25 / 55 / 70 / 85 | 4 Light Leather, 2 Coarse Thread | 25c | 20c | 60c | -55c |
| Small Leather Ammo Pouch | 25 / 55 / 70 / 85 | 3 Light Leather, 4 Coarse Thread | 25c | 40c | 45c | -60c |
| Handstitched Leather Belt | 25 / 55 / 70 / 85 | 6 Light Leather, 1 Coarse Thread | 34c | 10c | 90c | -66c |
| Fine Leather Cloak | 50 / 70 / 85 / 100 | 10 Light Leather, 2 Fine Thread | 2s 67c | 2s 0c | 1s 50c | -83c |
| Heavy Leather | 125 / 125 / 130 / 135 | 5 Medium Leather | 1s 50c | 0c | 2s 50c | -1s 0c |
| Cured Heavy Hide | 125 / 135 / 140 / 145 | 1 Heavy Hide, 3 Salt | 2s 25c | 1s 50c | 2s 0c | -1s 25c |
| Dark Leather Belt | 100 / 125 / 137 / 150 | 1 Fine Leather Belt, 1 Cured Medium Hide, 2 Fine Thread, 1 Gray Dye | 7s 3c | 6s 20c | 2s 15c | -1s 32c |
| Toughened Leather Armor | 95 / 120 / 132 / 145 | 10 Medium Leather, 2 Cured Light Hide, 2 Fine Thread | 7s 43c | 3s 0c | 6s 0c | -1s 57c |
| Heavy Armor Kit | 125 / 145 / 155 / 165 | 5 Heavy Leather, 1 Fine Thread | 6s 50c | 1s 0c | 7s 50c | -2s 0c |
| Dark Leather Cloak | 85 / 110 / 122 / 135 | 8 Medium Leather, 1 Fine Thread, 1 Gray Dye | 4s 8c | 4s 50c | 4s 0c | -4s 42c |
| Gray Leather Boots | 75 / 100 / 112 / 125 | 4 Medium Leather, 2 Fine Thread, 1 Gray Dye | 3s 7c | 5s 50c | 2s 0c | -4s 43c |
| Heavy Quiver | 125 / 145 / 155 / 165 | 8 Heavy Leather, 2 Fine Thread | 5s 0c | 2s 0c | 12s 0c | -9s 0c |
| Heavy Leather Ammo Pouch | 125 / 145 / 155 / 165 | 8 Heavy Leather, 2 Fine Thread | 5s 0c | 2s 0c | 12s 0c | -9s 0c |

## Forever changes worth knowing

- Medium Leather can be made from 4 Light Leather (trainer, 75), Heavy Leather from 5 Medium (125).
- Toughened Leather Armor needs 2 Cured Light Hide (6 in Classic).
- Most recipes are learned earlier and go grey earlier than in Classic. Light Leather Pants: learn 70, grey at 130.
- Vendor prices can be 1c off in game (hotfixes).

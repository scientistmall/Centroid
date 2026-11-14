# THE CENTROID — Weapon Bible

Approved designs (Part One). **Every image or model of an armed character uses the approved sheet:**
story panels, power cut-ins, the title wallpaper, the 3D weapons in fights, and anything made later.

Rules:
- The sheet `assets/weapons/sheets/sheet_<id>.png` is the source of truth. To change a weapon, make and approve a new sheet first, then redraw everything that shows it.
- Prompts never describe a weapon freely. They use the one-line `look` from `tools/models/art_prompts.py` (`WEAPON_SHEETS`), worded by `weapon_clause()` in `tools/models/kaggle_run.py`, with the character's `views/<c>_armed.png` reference (character + sheet side by side).
- Practice and wooden swords in flashbacks are not the character's weapon and are left as they are.
- `python3 tests/check_weapons.py` checks that every weapon has its sheet and look, and every 3D weapon names its sheet.

| Weapon | Owner | Look |
|---|---|---|
| **Lightning Sword** (`kael_sword`) | Kael | a straight longsword with a dark steel blade crackling with glowing light-blue lightning lines, a round silver disc guard and a navy cord-wrapped grip with a silver pommel |
| **Black Flame Axe** (`rhex_axe`) | Rhex | a heavy two-handed battle axe with a large blackened-steel crescent blade, a glowing ember-red edge and a long dark wooden haft wrapped in red leather |
| **Crescent Whip-Sword** (`mira_blade`) | Mira | a slim silver whip-sword made of crescent-moon plates with pink light in the seams, which can extend into a long segmented whip, white hilt with a crescent guard |
| **Wind Spear** (`tala_spear`) | Tala | a long spear taller than her, with a broad leaf-shaped steel head inlaid with jade-green wind patterns, green ribbons and a pale ash-wood shaft |
| **Stone Gauntlets** (`darin_gauntlets`) | Darin | massive gauntlets up to the elbows made of pale grey cracked stone plates with gold trim, fingerless, with matching stone knee guards |
| **Steel Bracers** (`mael_knuckles`) | Mael | polished steel forearm bracers over fingerless black gloves with riveted steel knuckle plates |
| **Twin Mist Blades** (`vaska_blades`) | Vaska | twin short curved blades of pale grey-blue steel that fade into mist at the edges, with grey tassels |
| **Venom Whip** (`nyra_whip`) | Nyra | a long black whip with a braided black and toxic-green handle, the end of the lash barbed and dripping glowing green venom |
| **Constellation Blade** (`veyr_blade`) | Veyr | a long, nearly straight single-edged sword with a violet-black blade dotted with tiny glowing stars like a constellation, a silver star-shaped guard and a violet cord-wrapped grip |
| **Officer Sabre** (`seran_sword`) | Seran | a straight officer's sabre with a polished steel blade, a sage-green and brass basket hilt and a dark leather grip |
| **Shadow Swords** (`thane_swords`) | Thane | twin straight black swords edged with deep purple smoky shadow, angular black guards |

3D models in fights: `assets/weapons/<id>.glb`, grip and axis measured into `assets/weapons/weapons.json` by `tools/models/weapon_grip.py`.

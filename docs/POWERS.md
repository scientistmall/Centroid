# THE CENTROID — Power Design (Draft 1)

Enemy powers come from the story team's list. Player (guardian) powers are designed
as **answers** to the enemy each guardian faces, so every story fight has its own
"key" to learn. Each fighter gets: a weapon style (light/heavy combos), **2 powers**
(energy cost), and later a **finisher**.

Energy: builds from landing hits, blocking, taking hits, and slowly over time. Max 100.

Status: ✅ in game · 🔜 next builds

---

## Traitors (enemies)

| Fighter | Weapon | Power theme | Personality | Power 1 | Power 2 |
|---|---|---|---|---|---|
| **Rhex** ✅ | Fire axe | Explosive black flames | Arrogant, aggressive | **Black Flame Wave**: a slow ground wave of black fire | **Hellfire Burst**: an armoured explosion around him (can't be interrupted while charging) |
| **Vaska** ✅ | Twin blades | Mist manipulation, illusions | Deceptive, calculating | **Veil of Mist**: she turns almost invisible for 3 s and her attacks hit 20% harder | **Mirror Double**: spawns an illusion clone that fights beside her (deals no damage, vanishes when hit) |
| **Mael** 🔜 | Earth-breaking fists | Gravity manipulation | Disciplined, ruthless | **Gravity Well**: pulls the opponent toward him and slows jumps | **Rising Stones**: rock fragments orbit him, then launch |
| **Nyra** 🔜 | Poison-coated whip | Energy-draining curses | Cruel, patient | **Venom Lash**: a long whip that poisons (damage over time) | **Withering Curse**: drains the opponent's energy into her own |
| **Zerin** 🔜 | Storm spear | Accelerated electric bursts | Conflicted, proud | **Overcharge**: speeds himself up for a few seconds | **Storm Lance**: a lightning-fast spear dash |
| **Corvin** 🔜 | Crystal blades | Regenerating cosmic shards | Cold, obsessive | **Shard Field**: crystal shards on the floor that damage on contact | **Crystal Regrowth**: heals while the shards are intact |
| **Thane** 🔜 | Dual swords | Shadow portals, void attacks | Charismatic, strongest traitor | **Shadow Portal**: teleports behind the opponent | **Void Rend**: a slash that tears space and can't be blocked from the front |
| **Veyr** 🔜 | Blade | Master swordsmanship + cosmic power | — | **Starfall**: cosmic shards rain down around the opponent | **Severing Draw**: a lightning-fast sword-draw slash (pure technique) |

Veyr also has the fastest light and heavy chains of any fighter. When the Centroid
shatters (post-fight scene), Starfall is gone and only his swordsmanship remains.

## Guardians (playable) — designed against their opponents

| Fighter | Weapon | Element | Faces | Power 1 | Power 2 | Why it counters |
|---|---|---|---|---|---|---|
| **Kael** ✅ | Sword | Lightning | Rhex, Thane, Veyr | **Arc Bolt**: a fast lightning projectile | **Thunder Step**: an invulnerable lightning dash through the enemy | Speed beats Rhex's slow, heavy axe. Lightning lights up Thane's shadow portals (later upgrade). His finisher **Stormbreaker** channels everything into the resonator (story). |
| **Tala** ✅ | Spear | Wind / keen senses | Vaska | **Clear Sight**: for 4 s, mist and illusions vanish and the real Vaska is revealed | **Piercing Gale**: a long wind lance | Her story is "trust your senses", so Clear Sight is the key to beating illusions. |
| **Darin** | Gauntlets | Stone | Mael | **Stone Bulwark**: a barrier wall that stops projectiles and anchors him (immune to pull) | **Quake Fist**: a ground shockwave that knocks floating rocks down | Gravity can't move an anchored wall. It is also the barrier he raises to save Mira. |
| **Mira** | Flexible blade (whip-sword) | Moonlight / purification | Nyra | **Purify**: cleanses poison and curses, small heal | **Ribbon Lash**: a long whip-blade that pulls the enemy in | Purify undoes her sister's poison and curses; Ribbon Lash outreaches the whip. |
| **Iren** | Twin daggers | Wind speed | Zerin | **Afterimage**: a quick dodge that leaves a decoy | **Grounding Blades**: thrown daggers that discharge Zerin's Overcharge | Matches speed with speed and "grounds" the storm. |
| **Lyra** | Bow | Sonic | Corvin | **Resonant Arrow**: shatters crystal shards (stops regeneration) | **Sonic Barrier**: a shield that reflects projectiles | The story's key discovery: the right frequency breaks the crystals and the Centroid. |
| **Oren** | Resonance gloves (gadgets) | Sound / tech | Veyr (tag partner with Kael) | **Damper Field**: Starfall shards are cancelled inside it | **Resonance Pulse**: a shockwave that drains Veyr's energy | His gadgets answer Veyr's cosmic power while Kael's swordsmanship matches Veyr's blade. |

## Mechanics
In game now:
- **Power types:** projectile, dash, burst, **buff** (timed status), **summon** (clone).
- **Statuses:** `veil`, `clear_sight`.
- **Fog** arenas.
- **Team modes:** tag mode is used by Fight 8 (Kael + Oren); relay mode exists but is
  unused.

Still to add:
- Statuses: poison, energy drain, slow, haste.
- Pull and gravity zones.
- Shields that block projectiles.
- Floor hazards and regeneration.
- Teleport.
- Starfall (falling projectiles).

All numbers (damage, cost, speed) live in `data/fighters/*.json`, so balancing
needs no code changes.

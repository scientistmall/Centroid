# THE CENTROID — Power Design (Draft 1)

Enemy powers come from the story team's list. Player (guardian) powers are designed
as **answers** to the enemy each guardian faces, so every story fight has its own
"key" to learn. Each fighter gets: a weapon style (light/heavy combos), **2 powers**
(energy cost), and later a **finisher**.

Energy: builds from landing hits, blocking, taking hits, and slowly over time. Max 100.

Status: ✅ in game · 🔜 next builds (needs new mechanics noted below)

---

## Traitors (enemies)

| Fighter | Weapon | Power theme | Personality | Power 1 | Power 2 |
|---|---|---|---|---|---|
| **Rhex** ✅ | Fire axe | Explosive black flames | Arrogant, aggressive | **Black Flame Wave** — slow ground wave of black fire | **Hellfire Burst** — armoured explosion around him (can't be interrupted while charging) |
| **Vaska** 🔜 | Twin blades | Mist manipulation, illusions | Deceptive, calculating | **Veil of Mist** — turns semi-invisible, attacks hit from the wrong side | **Mirror Double** — spawns an illusion clone that mimics her |
| **Mael** 🔜 | Earth-breaking fists | Gravity manipulation | Disciplined, ruthless | **Gravity Well** — pulls the opponent toward him, slows jumps | **Rising Stones** — floating rock fragments orbit then launch |
| **Nyra** 🔜 | Poison-coated whip | Energy-draining curses | Cruel, patient | **Venom Lash** — long whip, poisons (damage over time) | **Withering Curse** — drains the opponent's energy into her own |
| **Zerin** 🔜 | Storm spear | Accelerated electric bursts | Conflicted, proud | **Overcharge** — speeds himself up for a few seconds | **Storm Lance** — lightning-fast spear dash |
| **Corvin** 🔜 | Crystal blades | Regenerating cosmic shards | Cold, obsessive | **Shard Field** — crystal shards on the floor that damage on contact | **Crystal Regrowth** — heals while shards are intact |
| **Thane** 🔜 | Dual swords | Shadow portals, void attacks | Charismatic, strongest traitor | **Shadow Portal** — teleports behind the opponent | **Void Rend** — slash that tears space; unblockable from the front |
| **Veyr** 🔜 | Blade | Cosmic power from the Voice *(proposal — not in the list yet)* | — | **Starfall** — cosmic shards rain from above | **Eclipse** — darkens the arena; only his attacks are visible. Phase 2 after the Centroid breaks: no powers, pure swordsmanship |

## Guardians (playable) — designed against their opponents

| Fighter | Weapon | Element | Faces | Power 1 | Power 2 | Why it counters |
|---|---|---|---|---|---|---|
| **Kael** ✅ | Sword | Lightning | Rhex, Corvin, Thane, Veyr | **Arc Bolt** — fast lightning projectile | **Thunder Step** — invulnerable lightning dash through the enemy | Speed beats Rhex's slow, heavy axe and flames. Lightning lights up Thane's shadow portals (later upgrade). Final finisher **Stormbreaker** channels everything into the resonator (story). |
| **Tala** | Spear | Wind / keen senses | Vaska | **Clear Sight** — for 4 s, mist and illusions vanish and the real Vaska glows | **Piercing Gale** — long-reach wind lunge | Her whole story is "trust your senses"; Clear Sight is the key to beating illusions. |
| **Darin** | Gauntlets | Stone | Mael | **Stone Bulwark** — barrier wall that stops projectiles and anchors him (immune to pull) | **Quake Fist** — shockwave along the ground that knocks floating rocks down | Gravity can't move an anchored wall; his barrier is also the one he raises to save Mira. |
| **Mira** | Flexible blade (whip-sword) | Moonlight / purification | Mael (with Darin), Thane (with Kael), Veyr (final phase) | **Purify** — cleanses curses and poison, small heal | **Ribbon Lash** — long whip-blade that pulls the enemy in | Light against void and darkness; she finishes the Veyr fight after the Centroid breaks. |
| **Oren** | Resonance gloves (gadgets) | Sound / tech | Nyra | **Damper Field** — curses and energy drain don't work inside it | **Resonance Pulse** — shockwave that drains *enemy* energy | Turns Nyra's energy-drain against her. Sets up his resonator from the story. |
| **Iren** | Twin daggers | Wind speed | Zerin | **Afterimage** — quick dodge that leaves a decoy | **Grounding Blades** — thrown daggers that discharge Zerin's Overcharge | Matches speed with speed and "grounds" the storm. |
| **Lyra** | Bow | Sonic | Corvin | **Resonant Arrow** — shatters crystal shards (stops regeneration) | **Sonic Barrier** — shield that reflects projectiles | The story's key discovery: the right frequency breaks the crystals and the Centroid. |

## New mechanics the later chapters need
- **Status effects:** poison (damage over time), energy drain, slow, haste.
- **Invisibility and clones** for Vaska. **Pull and gravity zones** for Mael.
- **Shields and barriers** that block projectiles (Darin, Lyra).
- **Floor hazards and regeneration** (Corvin).
- **Teleport** (Thane), **arena darkness** (Veyr).
- **Team fights:** `"mode": "relay"` (next fighter enters when one falls) and
  `"mode": "tag"` (SWAP button) already exist in the arena code.

All numbers (damage, cost, speed) live in `data/fighters/*.json`, so balancing
needs no code changes.

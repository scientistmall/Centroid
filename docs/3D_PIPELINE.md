# THE CENTROID — Making the 3D Characters (step by step)

You create the character **models** with AI 3D tools, and Mixamo adds the **skeleton**
and **motion-captured fight animations**. I then import everything into the game,
connect it to the fight system, and add effects, lighting and camera work.

**Start with the pilot: Kael, Rhex, and the animation pack (Part 3).** Send those
first. Once they look right in the game, we do the rest.

You need:
- **Meshy** (meshy.ai) or **Tripo** (tripo3d.ai), free tiers available;
- **Mixamo** (mixamo.com), free with an Adobe account;
- optionally an AI image tool (any you like) for concept art.

---

## Part 1 — Make one character model (repeat per character)

### Step 1. Concept image (recommended — gives far better models)
In any AI image tool, generate a **front view, full body, A-pose** image on a plain
light-grey background. Use the character brief from Part 4 and add:

> full body, front view, A-pose (arms angled down ~45°), standing straight, plain light grey background, character design sheet, stylized realistic, game character, even lighting, no shadows, no weapon in hands

Pick the best result. Make sure the hands are open, the feet are visible and nothing
overlaps the body.

### Step 2. Image to 3D (Meshy or Tripo)
1. Choose **Image to 3D** and upload the concept image. Or use **Text to 3D** and paste
   the brief plus "A-pose, full body, game character".
2. Settings:
   - **Topology:** quad or triangle; **target polycount 15,000–30,000** (good for
     phones).
   - **Texture:** on, **PBR** if offered, **2K (2048)** resolution.
   - **Symmetry:** on, if offered.
3. Generate, then check that the model has **two clear arms, two legs, separate
   fingers or mitten hands, and no fused parts**. Regenerate if needed.
4. Download as **FBX** (preferred) or **GLB**.
5. Make the **weapon separately** as its own Text-to-3D model (e.g. "single-edged sword,
   game asset, isolated"). Download it as FBX/GLB too.

### Step 3. Rig it on Mixamo
1. On mixamo.com, click **Upload Character** and choose your FBX.
2. In the auto-rigger, place the markers on the **chin, wrists, elbows, knees and
   groin**. Leave Skeleton LOD at **Standard**.
3. Check the preview animates correctly, then press **Next**.
4. Click **Download** with these settings:
   - **Format:** FBX Binary (.fbx)
   - **Pose:** T-pose
   - **Skin:** With Skin
5. Rename the file to the character's name, e.g. `kael.fbx`.

---

## Part 2 — Upload to the game repository

The files go into the repository **scientistmall/Centroid**:

```
assets/characters/kael/kael.fbx           (rigged model from Mixamo)
assets/characters/kael/kael_weapon.fbx    (weapon model)
assets/characters/kael/concept.png        (your concept image, optional)
assets/animations/idle.fbx                (animation pack, Part 3)
...
```

**On a PC:**
1. Open the repository on github.com and go to the `assets` folder.
2. Click **Add file → Upload files** and drag the files in. Before uploading, type the
   folder path into the file name box (e.g. `characters/kael/`).
3. Click **Commit changes**.

**Notes:**
- Web uploads allow **25 MB per file**. For bigger files, use **GitHub Desktop**, which
  allows up to 100 MB.
- On a phone, the GitHub app can't upload files, so use the browser in
  "desktop site" mode.
- Then just tell me "Kael uploaded" (or similar) and I'll take it from there.

---

## Part 3 — The animation pack (download ONCE, works for every character)

All characters share these animations. I retarget them onto each model in Godot.

**How to download each clip:**
1. On Mixamo, keep **any one rigged character** selected (Kael is fine).
2. Search for the clip name and pick the closest match.
3. If the clip has an **In Place** checkbox, tick it. This matters: the game moves the
   characters itself.
4. Click **Download** with:
   - **Format:** FBX Binary;
   - **Skin:** **Without Skin**;
   - **Frames per second:** 30;
   - **Keyframe Reduction:** none.
5. **Rename** the file to the name in the left column and upload it to
   `assets/animations/`.

Names change on Mixamo over time, so the right column gives search words. Pick
whichever result looks best.

| Save as | Search on Mixamo for | Used for |
|---|---|---|
| `idle.fbx` | "Fighting Idle" / "Sword And Shield Idle" | standing in fight stance |
| `walk_forward.fbx` | "Fighting Walk Forward" / "Sword And Shield Walk" (In Place) | moving toward the enemy |
| `walk_back.fbx` | "Fighting Walk Backward" / "Sword And Shield Walk Back" (In Place) | moving away |
| `jump.fbx` | "Jump" (In Place) | jumping |
| `light_1.fbx` | "Sword And Shield Slash" / "Standing Melee Attack Horizontal" | 1st light hit |
| `light_2.fbx` | "Standing Melee Attack Backhand" / "Sword And Shield Attack" | 2nd light hit |
| `light_3.fbx` | "Mma Kick" / "Roundhouse Kick" | 3rd light hit (kick finisher) |
| `heavy_1.fbx` | "Standing Melee Attack Downward" / "Great Sword Slash" | heavy overhead |
| `heavy_2.fbx` | "Great Sword High Spin Attack" / "Standing Melee Combo Attack" | heavy finisher |
| `air_attack.fbx` | "Jump Attack" / "Flying Kick" | attack while jumping |
| `block.fbx` | "Sword And Shield Block" / "Center Block" | holding block |
| `block_hit.fbx` | "Sword And Shield Impact" / "Body Block" | blocking a hit |
| `hit_light.fbx` | "Head Hit" / "Hit Reaction" | taking a light hit |
| `hit_heavy.fbx` | "Big Side Hit" / "Stomach Hit" | taking a heavy hit |
| `knockdown.fbx` | "Flying Back Death" / "Knocked Out" | K.O. / knocked down |
| `get_up.fbx` | "Getting Up" / "Stand Up" | getting up between rounds |
| `cast_1.fbx` | "Standing 1H Magic Attack 01" | projectile powers (bolt, wave, lash) |
| `cast_2.fbx` | "Standing 2H Magic Area Attack 01" | area powers (burst, curse, wall) |
| `buff.fbx` | "Standing 2H Cast Spell 01" / "Power Up" | self powers (purify, veil, clear sight) |
| `dash.fbx` | "Sprinting Forward Roll" / "Dodging" / "Running Slide" | dash powers (Thunder Step) |
| `victory.fbx` | "Victory" / "Fist Pump" / "Sword And Shield Power Up" | winning a round |
| `defeat.fbx` | "Defeated" / "Kneeling" | losing |
| `intro.fbx` | "Sword And Shield Draw" / "Taunt" | fight intro |

Weapon styles differ (spear, whip, gauntlets), but this pack covers everyone for now. I
make each fighter look distinct with timing, effects and weapon trails. Later we can
add a few style-specific clips (e.g. "spear thrust" for Tala).

---

## Part 4 — Character briefs (paste into the image or 3D tool)

Common style line to add to every brief:
> stylized realistic dark-fantasy martial artist, anime-inspired proportions, detailed costume, game-ready character, PBR materials

### Pilot
**KAEL** (hero, about 19) — *colour: electric blue*
> Young man, lean athletic build, spiky dark navy-black hair, light blue eyes, determined face. Short dark navy fitted jacket with split coat tails and glowing light-blue trim, long pale blue-white scarf, black fitted trousers, leather bracers, light armored boots, light-blue belt.

Weapon:
> slightly curved single-edged sword, dark steel blade with faint blue edge glow, round guard, wrapped grip

**RHEX** (traitor, about 25) — *colour: red*
> Young adult man, broad muscular build, dark red spiky mohawk hair with shaved sides, scar across left cheek, red eyes, arrogant smirk. Sleeveless dark leather battle armor, layered steel shoulder pauldron on the left shoulder, cloth wraps on forearms, heavy boots, red belt.

Weapon:
> large single-bladed battle axe, blackened steel head with glowing red edge, long dark handle

### Part One fighters
**TALA** (mentor, about 30) — *colour: jade green*
> Athletic woman, dark hair in a high ponytail, calm focused eyes, light leather armor with jade-green cloth panels, arm wraps, practical boots.

Weapon:
> long spear with leaf-shaped blade and green cloth tassel

**VASKA** (traitor, about 20) — *colour: grey-blue*
> Slim young woman, grey-blue hooded cloak, lower face scarf, fitted dark clothing, misty pale colors, light boots.

Weapon:
> pair of short curved twin blades

**DARIN** (guardian, about 28) — *colour: amber*
> Very big powerful man, shaved head, short beard, sleeveless brown and amber fighting gear, thick belt, heavy stone-like armored gauntlets on both forearms and fists.

Weapon: none (the gauntlets are part of the model).

**MAEL** (traitor, about 28) — *colour: violet*
> Muscular disciplined man, short dark hair, stern face, dark violet monk-style fighting robes, armored fists, floating rock motif embroidery.

Weapon: none (armored fists).

**MIRA** (guardian, about 20) — *colour: rose pink*
> Young woman, long dark hair with rose-pink tint, gentle but strong face, elegant fitted light armor in white and rose pink with moon motifs, flowing half-cape.

Weapon:
> segmented flexible whip-sword, silver blade segments

**NYRA** (traitor, Mira's older sister, about 25) — *colour: poison green*
> Elegant woman, long dark hair, cold expression, black and poison-green fitted outfit with thorn motifs, long gloves.

Weapon:
> long leather whip with green metal tip

### Story characters (needed later, for story scenes and future fights)
- **AUREN** (founder, about 60, gold):
  > older man, long greying hair and short beard, wise kind face, layered gold-trimmed dark robes
- **SERAN** (deputy, about 45, green):
  > calm man, swept-back hair, long green-trimmed leader coat
- **VEYR** (deputy turned villain, about 45, violet):
  > tall intense man, long dark hair, scholar-warrior long coat in black and violet, sword
- **THANE** (Kael's older brother, about 24, violet-black):
  > tall man, spiky dark hair like Kael's, black and violet armor, two swords
- **IREN** (Kael's best friend, about 19, orange):
  > cheerful young man, messy brown hair, orange-accented light armor, twin daggers
- **LYRA** (about 19, pale cyan):
  > young woman, long light hair, pale cyan and white archer outfit, bow
- **OREN** (inventor, about 30, yellow):
  > short hair, goggles on forehead, yellow-accented work gear, mechanical resonance gloves

---

## Checklist for the pilot
- [ ] `assets/characters/kael/kael.fbx` (+ `kael_weapon.fbx`)
- [ ] `assets/characters/rhex/rhex.fbx` (+ `rhex_weapon.fbx`)
- [ ] `assets/animations/*.fbx` — the 23 clips from Part 3
- [ ] Tell me it's uploaded

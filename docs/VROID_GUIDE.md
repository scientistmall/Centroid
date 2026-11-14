# VRoid fighter sheets

How to build Kael, Rhex, Mira and Tala in VRoid Studio. You build bodies, hair, faces and outfits; the game adds weapons (fitted to the hand), animation, physics and anime shading. A visual version of this guide with images is published as an artifact.

## Shared settings

| Setting | Value |
|---|---|
| Proportions | About 7.5 heads tall: shrink VRoid's default head, lengthen legs |
| Export | VRM 1.0 (VRM 0.0 also works) |
| Polygons | 30,000–40,000 |
| Textures | Atlas at 2048 × 2048 (keeps the file under GitHub's 25 MB web upload) |
| File | `assets/characters/<name>/<name>.vrm` |

## Build steps

1. **Base:** male base for Kael and Rhex, female for Mira and Tala. Keep the default A-pose and default hands (finger bones are needed for the weapon grip).
2. **Body:** height and build, then head size, shoulders, arms, legs. Check the silhouette from front and side.
3. **Face:** eye shape and iris colour, brows, mouth, skin tone. Paint marks (Rhex's scar) on the face texture.
4. **Hair:** closest preset, then hand-drawn guide strands for the signature shape; colour and highlight from the palette.
5. **Outfit:** tops, bottoms, shoes, accessories, recoloured with the hex codes. Paint trims, piping, buttons and emblems on the texture layers.
6. **Sway check:** long hair, scarves, coat tails and sashes move; spikes and the mohawk stay stiff.
7. **Export and upload** to the path above (GitHub: Add file → Upload files, commit to main).

## Rules

- Silhouette first: each fighter has one shape you can spot across the arena.
- When the 3D concept views and the manga disagree, follow the manga (Mira's hair is dark violet).
- No weapons, no posed fingers, no oversized accessories that swing through the body.
- Keep sleeves and gloves slim at the wrist so the grip doesn't clip.
- Finish the body before the outfit.

## Kael

*Guardian · 19 · lightning · sword* · Male base · Lean athletic · Height: tall-average

**Silhouette:** Spiky swept-back hair, a scarf at the throat, and split coat tails that flare when he moves.

Views: `assets/characters/kael/views/kael_front.png`, `_back.png`, `_face.png`; manga look: `assets/cutins/cutin_kael_1.webp`

| Part | Hex |
|---|---|
| Hair | `#1c2233` |
| Hair highlight | `#3b4f7a` |
| Eyes | `#8fd3ff` |
| Skin | `#ecc8ae` |
| Coat | `#232a45` |
| Piping / trim | `#4fa8d8` |
| Coat-tail lining | `#6fb3d9` |
| Scarf | `#c3dbe0` |
| Trousers | `#16171c` |
| Boots | `#1b1b20` |
| Bracers / belt | `#3a2c22` |
| Buttons | `#b8c0cc` |

**Hair**
- Short, spiky, swept up and back; 12–16 drawn spikes pointing back and up
- Two loose bangs over the forehead
- High stiffness: the spikes barely move

**Face**
- Light blue eyes, slightly narrowed upper lid
- Straight, angled brows: focused, not angry
- Neutral, closed mouth

**Outfit**
- Fitted navy coat: stand collar, double row of silver buttons, light-blue piping
- Coat tails split at the back, knee length, blue lining
- Slim black trousers, black lace-up boots
- Brown belt, leather forearm bracers

**Accessories and sway**
- Pale blue-white scarf wrapped once, one end hanging over the left chest
- Sway on: scarf end and coat tails

## Rhex

*Traitor · 25 · black flame · axe* · Male base · Heavy muscular · Height: tallest

**Silhouette:** A tall red mohawk, bare muscled arms, and one big riveted pauldron on his left shoulder.

Views: `assets/characters/rhex/views/rhex_front.png`, `_back.png`, `_face.png`; manga look: `assets/cutins/cutin_rhex_1.webp`

| Part | Hex |
|---|---|
| Mohawk | `#7a1428` |
| Mohawk tips | `#b02a3a` |
| Shaved sides | `#5a4a44` |
| Eyes | `#e0302a` |
| Skin | `#d9a882` |
| Vest | `#1b1d22` |
| V-neck trim | `#6e1a22` |
| Pauldron steel | `#4a4d55` |
| Rivets | `#8a8d95` |
| Sash | `#6e1a22` |
| Belt / pouch | `#4a2c1e` |
| Trousers | `#1e2230` |
| Arm wraps | `#5a5a48` |
| Boots | `#1a1a1e` |

**Hair**
- Tall mohawk fan from forehead to nape, in 6–8 stiff spikes
- Sides shaved: paint a stubble shadow on the scalp
- Very high stiffness

**Face**
- Red eyes, heavy low brows, a permanent scowl
- Scar across the left cheek, painted on the skin texture
- Strong jaw (lower jaw width up)

**Outfit**
- Sleeveless black vest, deep V-neck with dark red trim
- Dark red sash under a brown leather belt with a pouch
- Loose dark trousers tucked into heavy boots
- Olive cloth wraps on the forearms

**Accessories and sway**
- One riveted steel pauldron on the LEFT shoulder (if VRoid has nothing close, leave it off and I'll add it as a separate piece)
- Sway on: sash tails only

## Mira

*Guardian · 18 · moonlight · whip-blade* · Female base · Slender · Height: shortest

**Silhouette:** Waist-length straight violet hair, a crescent-moon clip, and long white sash tails over a dark coat-dress.

Views: `assets/characters/mira/views/mira_front.png`, `_back.png`, `_face.png`; manga look: `assets/cutins/cutin_mira_1.webp`

| Part | Hex |
|---|---|
| Hair | `#3d2350` |
| Hair highlight | `#7a4fa0` |
| Eyes | `#ff7fbf` |
| Skin | `#f1d4c4` |
| Moon clip | `#d8dce6` |
| Coat-dress | `#1f2236` |
| Pink trim | `#f29ac4` |
| Moon emblem | `#f29ac4` |
| Sash | `#f4f4f6` |
| Tights | `#e8e8ee` |
| Gloves / boots | `#1f2236` |
| Buttons | `#c9ced8` |

**Hair**
- Long, straight, to the waist, with side-swept bangs
- Silver crescent-moon clip on her left side
- Low stiffness: the long hair should flow

**Face**
- Pink eyes, soft rounded eye shape
- Gentle brows, calm mouth
- Lighter blush than the default

**Outfit**
- Dark navy coat-dress to mid-calf: mandarin collar, double-breasted silver buttons, soft pink piping
- Pink crescent-moon emblem on the chest
- Dark fingerless gloves, white tights, navy boots

**Accessories and sway**
- White sash belt with two long tails hanging at the front
- Sway on: hair, sash tails and the coat-dress hem

## Tala

*Guardian · 30 · wind · spear* · Female base · Tall athletic · Height: tall

**Silhouette:** A high black ponytail, a thick jade scarf, and bare strong arms with steel bands.

Views: `assets/characters/tala/views/tala_front.png`, `_back.png`, `_face.png`; manga look: `assets/cutins/cutin_tala_1.webp`

| Part | Hex |
|---|---|
| Skin | `#6b4430` |
| Hair | `#111318` |
| Hair tie | `#c9a35e` |
| Eyes | `#e8a33a` |
| Scarf | `#3aa58a` |
| Tunic | `#2f5a45` |
| Mint trim | `#8fe0c4` |
| Trousers | `#d6c9a8` |
| Straps / belt | `#6a4128` |
| Arm bands | `#6b6f75` |
| Boots / wraps | `#4a2e1e` |

**Hair**
- Pulled up into a high ponytail reaching the shoulder blades
- Bronze hair tie, a few loose strands at the temples
- Medium stiffness: the ponytail swings

**Face**
- Amber eyes, sharp and steady
- Strong, straight brows
- Mature face: less round cheeks than the default

**Outfit**
- Sleeveless green wrap tunic with a diagonal mint trim, ragged hem at mid-thigh
- Cream loose trousers
- Brown leather belt, pouches and a strap across the chest
- Steel bands on the upper arms, leather bracers, brown wrapped boots

**Accessories and sway**
- Thick jade scarf wrapped high around the neck
- Sway on: ponytail and tunic hem

## After upload

- Mixamo fight clips are retargeted to the VRM humanoid skeleton.
- VRM spring bones drive hair and cloth; MToon shading and outlines replace the current shader.
- Weapons are rebuilt per hand: fingers close on the handle, grip centred in the fist.
- The current models stay in the game until the VRoid files arrive.

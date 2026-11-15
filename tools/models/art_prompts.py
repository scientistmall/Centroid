"""Prompts for the v2 art pipeline (FLUX.2 [klein] 4B on Kaggle).

VIEWS   : edits of each character's picked concept (reference image) -> turnaround views
          + a face close-up, used for multi-view 3D shape and sharp texture projection.
WEAPONS : one weapon per character -> 3D (Hunyuan3D-2) -> held in the right hand.
PROPS   : the Centroid stone and the Solar Altar (main menu + finale).
BACKDROPS: wide paintings behind each arena.
"""

_SAME = ("Same character as in the reference image: identical face, hairstyle, hair colour, eye colour, "
         "outfit, colours, accessories and body proportions. ")
_SHEET = (" Plain light grey background, even soft studio lighting, no shadows, sharp focus, highly detailed "
          "stylized realistic game character, character turnaround sheet, single character, no weapon.")

VIEWS = {
    # name: (prompt, width, height)
    "front": (_SAME + "Full body, front view, standing in A-pose with arms angled down and away from the body, "
              "both hands clenched into fists, feet visible, crisp detailed face looking at the viewer." + _SHEET,
              832, 1216),
    "back": (_SAME + "Full body, seen from directly behind, back view, standing in A-pose with arms angled down "
             "and away from the body, both hands clenched into fists, feet visible, back of the outfit and hair "
             "clearly shown." + _SHEET, 832, 1216),
    "left": (_SAME + "Full body, side profile view seen from the character's left side, standing straight, arms "
             "down slightly away from the body, hands clenched into fists, feet visible." + _SHEET, 832, 1216),
    "right": (_SAME + "Full body, side profile view seen from the character's right side, standing straight, arms "
              "down slightly away from the body, hands clenched into fists, feet visible." + _SHEET, 832, 1216),
    "face": (_SAME + "Close-up portrait of this character's face, front view, head and shoulders only, looking "
             "straight at the viewer, determined expression, sharp detailed eyes, eyebrows and lips, clean skin, "
             "plain light grey background, even soft studio lighting.", 1024, 1024),
}

_ASSET = (", isolated game weapon asset, the entire weapon fully visible, horizontal side view, plain light grey "
          "background, even studio lighting, highly detailed, sharp focus")

WEAPONS = {
    # weapon id: (owner, prompt)
    "kael_sword": ("kael", "a single-edged slightly curved longsword, dark steel blade with a thin glowing light-blue "
                   "lightning edge and faint lightning engravings, round silver guard, grip wrapped in dark navy "
                   "leather with a silver pommel" + _ASSET),
    "rhex_axe": ("rhex", "a large single-bladed battle axe, blackened steel head with an ember-red glowing cutting "
                 "edge and black flame engravings, short back spike, long dark wooden handle wrapped in red "
                 "leather near the bottom" + _ASSET),
    "mira_blade": ("mira", "an elegant flexible whip-sword, a slim segmented silver blade made of linked "
                   "crescent-moon shaped plates with a soft pink glow between the segments, white wrapped hilt with "
                   "a small crescent-moon guard" + _ASSET),
    "tala_spear": ("tala", "a long wind spear, slim leaf-shaped polished steel spearhead with jade-green inlay, long "
                   "pale ash wood shaft, green cloth ribbons tied below the spearhead, bronze butt cap" + _ASSET),
}

# manga-style design sheets: the look every story panel and title pose follows
_SHEET = (", manga weapon design sheet, modern anime key art style, clean confident ink line art, cel shading with "
          "soft painted gradients, the complete weapon drawn large across the sheet, plus a detailed close-up of the "
          "grip and guard in one corner, plain warm off-white paper background, no people, no hands, no text, no "
          "labels, no letters, no watermark, highly detailed, sharp")

WEAPON_SHEETS = {
    # id: (owner, short look used in panel prompts, sheet prompt)
    "kael_sword": ("kael",
        "a straight longsword with a dark steel blade crackling with glowing light-blue lightning lines, a round "
        "silver disc guard and a navy cord-wrapped grip with a silver pommel",
        "Kael's sword: a single-edged, slightly curved longsword, the blade three times as long as the grip, dark "
        "gunmetal steel with a bright light-blue glowing cutting edge and thin forked lightning engravings along the "
        "flat, a round polished silver disc guard, a long grip wrapped in dark navy leather with light-blue cord, a "
        "silver pommel shaped like a small lightning spark"),
    "rhex_axe": ("rhex",
        "a heavy two-handed battle axe with a large blackened-steel crescent blade, a glowing ember-red edge and a "
        "long dark wooden haft wrapped in red leather",
        "Rhex's battle axe: a heavy two-handed war axe, one large crescent blade of blackened steel with a glowing "
        "ember-red cutting edge and black flame engravings, a short spike on the back, a long thick dark wooden haft "
        "bound with iron rings and wrapped in red leather at the grip, an iron butt spike"),
    "mira_blade": ("mira",
        "a slim silver whip-sword made of crescent-moon plates with pink light in the seams, which can extend into a "
        "long segmented whip, white hilt with a crescent guard",
        "Mira's whip-sword drawn twice: at the top, its sword form, a slim straight elegant silver sword built from "
        "overlapping crescent-moon shaped blade plates fitted tightly together with soft pink light glowing in the "
        "seams; below it, the same sword extended into a long flexible whip of separated crescent plates linked by a "
        "thin glowing pink cable, curving in an S shape; a white wrapped hilt with a small silver crescent-moon guard "
        "and a short pink tassel"),
    "tala_spear": ("tala",
        "a long spear taller than her, with a broad leaf-shaped steel head inlaid with jade-green wind patterns, "
        "green ribbons and a pale ash-wood shaft",
        "Tala's wind spear: a long spear taller than a person, a broad leaf-shaped polished steel spearhead with "
        "jade-green inlaid swirling wind patterns, a bronze collar with two green cloth ribbons fluttering, a "
        "straight pale ash-wood shaft with dark leather grip bands, a bronze butt cap"),
    "darin_gauntlets": ("darin",
        "massive gauntlets up to the elbows made of pale grey cracked stone plates with gold trim, fingerless, "
        "with matching stone knee guards",
        "Darin's pair of stone gauntlets: massive armoured gauntlets covering the hand and forearm up to the elbow, "
        "built from heavy pale grey stone plates with fine cracks across them, trimmed with thin gold edging, "
        "fingerless with dark leather gloves underneath, thick stone knuckle blocks, leather straps; the pair shown "
        "side by side, one from the front and one from the side"),
    "mael_knuckles": ("mael",
        "polished steel forearm bracers over fingerless black gloves with riveted steel knuckle plates",
        "Mael's fighting gauntlets: a pair of polished steel forearm bracers with riveted steel knuckle plates over "
        "fingerless black leather gloves, purple cloth wrapping at the wrists, a faint violet gravity glow on the "
        "knuckles; the pair shown side by side"),
    "vaska_blades": ("vaska",
        "twin short curved blades of pale grey-blue steel that fade into mist at the edges, with grey tassels",
        "Vaska's twin blades: a matching pair of short slim curved blades, each about as long as a forearm, pale "
        "grey-blue steel that fades into translucent mist along the edges, dark grey wrapped grips, small hooked "
        "guards, ragged grey cloth tassels; the pair crossed in an X"),
    "nyra_whip": ("nyra",
        "a long black whip with a braided black and toxic-green handle, the end of the lash barbed and dripping "
        "glowing green venom",
        "Nyra's venom whip: a long black leather whip laid in loose loops, a braided black and toxic-green handle "
        "with a silver snake-head pommel, the last third of the lash studded with small green thorn barbs dripping "
        "glowing green venom"),
    "veyr_blade": ("veyr",
        "a long, nearly straight single-edged sword with a violet-black blade dotted with tiny glowing stars like "
        "a constellation, a silver star-shaped guard and a violet cord-wrapped grip",
        "Veyr's sword: a long elegant single-edged katana-style sword, a mirror-dark violet-black steel blade with "
        "tiny glowing star points along it like a constellation, a silver star-shaped guard, a black grip with "
        "violet cord wrap; its matching black lacquered scabbard with silver constellation inlay drawn below it"),
    "seran_sword": ("seran",
        "a straight officer's sabre with a polished steel blade, a sage-green and brass basket hilt and a dark "
        "leather grip",
        "Seran's sword: a straight single-edged officer's sabre, a long polished steel blade with a narrow fuller, "
        "a brass basket hilt with sage-green enamel inlay, a dark leather grip bound with brass wire, and its dark "
        "grey leather scabbard with brass fittings drawn below it"),
    "thane_swords": ("thane",
        "twin straight black swords edged with deep purple smoky shadow, angular black guards",
        "Thane's twin swords: a matching pair of straight double-edged swords with black blades edged in deep purple "
        "smoky shadow, angular black guards, grips wrapped in dark purple leather; the pair crossed in an X"),
}

PROPS = {
    "centroid": ("the Centroid, a sacred floating star-shaped crystal stone with many sharp facets, glowing with "
                 "warm golden-white light from inside, faint orbiting sparks, isolated game asset, centered, plain "
                 "light grey background, even studio lighting, highly detailed", 1024, 1024),
    "solar_altar": ("the Solar Altar, an ancient round stone altar pedestal on three circular steps, carved golden sun "
                    "rays and runes on its sides, a shallow golden cradle on top for a sacred stone, worn marble, "
                    "isolated game asset, front three-quarter view, plain light grey background, even studio "
                    "lighting, highly detailed", 1216, 832),
}

_BG = (", the sky is dark night during an eternal eclipse: a black disc where the sun should be, ringed by a thin "
       "cold silver corona, dim stars, no daylight, no sunlight, lit only by fire, glowing crystals and mist; wide "
       "cinematic background painting for a 2.5D fighting game arena, no characters, no people, empty ground in the "
       "foreground, epic atmosphere, highly detailed anime background art")

BACKDROPS = {
    "training_ground": ("the stone training courtyard of a mountain fortress, wooden training posts and weapon racks, "
                        "tattered banners, iron braziers burning with orange fire along the walls, distant snowy peaks "
                        "under the eclipsed sky" + _BG, 1664, 704),
    "silent_forest": ("a silent ancient forest of giant mossy trees, drifting blue-grey mist between the trunks, "
                      "hundreds of fireflies, faint cold light from the eclipse corona through the canopy" + _BG, 1664, 704),
    "broken_pass": ("a broken mountain pass, shattered cliffs, rock fragments floating in the air defying gravity, "
                    "violet storm clouds with flickers of violet lightning around the eclipsed sun, dust in the air"
                    + _BG, 1664, 704),
    "underground_sanctuary": ("an underground sanctuary cavern, carved stone pillars, veins of glowing green crystal in "
                              "the walls, still water pools reflecting the green light, ancient statues, an opening in "
                              "the ceiling showing the eclipsed sun far above" + _BG, 1664, 704),
    "solar_altar": ("the sacred Solar Altar plateau above the clouds, a ring of ancient stone pillars with golden sun "
                    "carvings, the glowing star-shaped Centroid crystal on the altar casting golden light, the "
                    "eclipsed sun directly above" + _BG, 1664, 704),
}

# ----------------------------------------------------------------------------- manga panels
PANEL_STYLE = ("full colour manga panel, modern anime and webtoon key art style, clean confident ink line art, "
               "cel shading with soft painted gradients, cinematic composition and lighting, expressive faces, "
               "detailed background, high quality illustration. One single continuous image (not a comic page, not "
               "split into several panels, no mirrored halves); every named character appears exactly once. No text, "
               "no letters, no writing or signs on objects, no speech bubbles, no captions, no sound effects, no "
               "watermark, no signature, no panel borders, no frame")

# short identity lines (the concept image of each character is also passed as a reference)
LOOKS = {
    "kael": "Kael, a lean young man of 19 with spiky dark navy-black hair, light blue eyes, a fitted navy jacket "
            "with light-blue trim and split coat tails, a pale blue-white scarf",
    "rhex": "Rhex, a tall muscular young man of 25 with a dark red spiky mohawk and shaved sides, a scar on his "
            "cheek, red eyes, a sleeveless black vest with red V-neck trim and one riveted steel pauldron",
    "mira": "Mira, a slender young woman of 18 with long straight dark violet hair, a silver crescent-moon hair "
            "clip, pink eyes, a dark navy coat-dress with soft pink trim and a white sash",
    "tala": "Tala, a tall athletic woman of 30 with dark brown skin, a high black ponytail, amber eyes, a "
            "sleeveless green wrap tunic with mint trim and a jade-green scarf",
    "darin": "Darin, a very big strong man of 28 with brown skin, a shaved head, a short dark beard and massive "
             "stone-plated gauntlets",
    "iren": "Iren, a slim young man of 20 with messy orange-brown hair, freckles and a light grey hooded jacket "
            "with an orange scarf",
    "lyra": "Lyra, a slim young woman of 20 with long silver-white hair, ice-blue eyes and a white and ice-blue "
            "archer outfit with a short cape",
    "oren": "Oren, a young man of 22 with short sandy-blond hair, brass goggles on his forehead, a dark utility "
            "vest and mechanical glowing resonance gloves",
    "auren": "Auren, a tall dignified elderly man of 70 with long white hair and a long white beard, wise kind "
             "eyes, cream and gold robes with a golden sun emblem",
    "seran": "Seran, a man of 50 with swept-back dark hair streaked with grey, a neat short beard and a long dark "
             "grey officer coat with sage-green trim",
    "veyr": "Veyr, a tall lean man of 45 with long straight black hair with one silver streak, pale skin, cold "
            "violet eyes and a long violet-black high-collared coat embroidered with glowing constellations",
    "thane": "Thane, a tall muscular man of 25, Kael's older brother, with long spiky dark navy-black hair swept "
             "back, a confident smirk and a black and deep purple armoured long coat",
    "vaska": "Vaska, a slim young woman of 22 in a deep grey-blue hooded cloak with a ragged misty hem and a sheer "
             "veil over the lower half of her face",
    "mael": "Mael, a tall heavily muscled man of 35 with olive skin, a short dark military haircut, a black "
            "martial-arts gi with a purple sash and iron knuckle plates",
    "nyra": "Nyra, a tall elegant woman of 24, Mira's older sister, with long dark violet hair in one long braid, "
            "venom-green eyes and a black leather coat with toxic-green trim",
    "zerin": "Zerin, a lean young man of 20 with spiky golden-blond hair and a sleeveless black jacket with "
             "glowing yellow lightning trim",
    "corvin": "Corvin, a tall thin man of 35 with swept-back silver-blue hair, cold cyan eyes and a long dark teal "
              "coat with glowing cyan crystal growths on the shoulders",
}

# where each story backdrop id is (added to panel prompts for consistent places)
SETTINGS = {
    "training_ground": "an abandoned stone training courtyard of a mountain fortress, cracked flagstones, wooden "
                       "training posts, stone pillars, eternal night under a black sky",
    "hq_night": "the organization's mountain fortress headquarters at night, stone terraces, warm lanterns",
    "hq_siege": "the mountain fortress headquarters under attack at night, fire and smoke",
    "crater": "a smoking meteor impact crater in a dark forest at night",
    "research_chamber": "a stone research chamber full of scrolls, books and instruments, daylight from tall windows",
    "research_dark": "a stone research chamber at night lit only by eerie glows",
    "balcony_sunset": "a stone fortress balcony overlooking a training yard at golden sunset",
    "forbidden_chamber": "a hidden underground stone chamber with arcane markings",
    "centroid_chamber": "the vaulted chamber that holds the Centroid stone on an altar of glowing green Asterite",
    "solar_altar": "the Solar Altar, a ring of ancient sun-carved stone pillars on a mountain plateau above the clouds",
    "graves": "a lonely hillside with memorial stones under a black sky, lit by torches",
    "silent_forest": "a silent ancient forest of giant mossy trees at night, blue-grey mist drifting between the trunks",
    "broken_pass": "a broken mountain pass with shattered cliffs and floating rock fragments under violet storm clouds",
    "underground_sanctuary": "an underground sanctuary cavern with carved pillars, glowing green crystal veins and "
                             "still water pools",
}

PANEL_SIZE = {"wide": (1344, 768), "action": (1344, 768), "square": (1024, 1024), "tall": (768, 1152),
              "strip": (1536, 512), "splash": (1536, 688)}

# ----------------------------------------------------------------------------- power cut-in splash art
SPLASH_STYLE = ("dynamic full colour manga splash illustration, anime key art, dramatic low camera angle, "
                "intense expression, motion lines and energy, cinematic rim lighting, the character large in frame "
                "from the waist up, dark background lit by the power. No text, no letters, no watermark, no frame")

# (character, power index 1-based) -> what the art shows
SPLASH = {
    ("kael", 1): "Kael thrusting his straight lightning longsword forward as a crackling bolt of blue-white lightning blasts from its tip",
    ("kael", 2): "Kael dashing forward in a blur, his body wrapped in blue lightning, afterimages streaking behind him",
    ("rhex", 1): "Rhex slamming his heavy two-handed battle axe down with both hands, unleashing a roaring wave of black flames with ember-red edges",
    ("rhex", 2): "Rhex roaring with his heavy two-handed battle axe raised high as a dome of black fire explodes around him, embers flying",
    ("tala", 1): "Tala holding her long wind spear upright beside her in one hand, her amber eyes glowing green as a ring of wind blows the mist away",
    ("tala", 2): "Tala lunging and thrusting her long wind spear with both hands, the leaf-shaped jade head leading, as a spiralling green wind lance tears forward with leaves",
    ("vaska", 1): "Vaska fading into swirling grey mist, only her eyes and her two short curved blades, one in each hand, visible through the fog",
    ("vaska", 2): "Vaska stepping out of the mist beside a ghostly translucent mirror image of herself, each holding a short curved blade in each hand",
    ("darin", 1): "Darin slamming his stone gauntlets into the ground as a massive wall of rock erupts before him",
    ("darin", 2): "Darin punching the ground with a stone gauntlet, cracks and rock spikes racing forward, dust exploding",
    ("mael", 1): "Mael raising one hand as a black sphere of crushing gravity forms, rocks orbiting it, purple light",
    ("mael", 2): "Mael hurling glowing purple boulders that rise and launch from the shattered ground",
    ("mira", 1): "Mira with her eyes closed, bathed in a pillar of soft pink-white moonlight, crescent symbols glowing around her",
    ("mira", 2): "Mira lashing her whip-sword in its extended whip form, a long chain of silver crescent plates on a glowing pink cable curving across the frame from the white hilt in her hand",
    ("nyra", 1): "Nyra cracking her long black whip with the silver snake-head pommel, its barbed end dripping glowing green venom, a cruel smile",
    ("nyra", 2): "Nyra reaching out with a clawed hand as dark green curse tendrils drain glowing energy toward her",
    ("kael", 3): "Kael leaping high and driving his straight lightning longsword down with both hands as a colossal pillar of blue-white lightning crashes from the black sky",
    ("rhex", 3): "Rhex spinning forward like a wheel of black fire, his heavy two-handed battle axe sweeping a burning ember-red arc",
    ("mira", 3): "Mira sweeping her whip-sword in its extended whip form into a vast glowing pink crescent moon arc of light around her",
    ("tala", 3): "Tala driving her long wind spear forward with both hands at the tip of a huge spiralling green tornado, leaves whirling",
    ("darin", 3): "Darin slamming both massive stone gauntlets into the ground as a ring of jagged rock pillars erupts around him, dust exploding",
    ("mael", 3): "Mael with both fists clenched at the centre of a collapsing black sphere of gravity, rocks and debris spiralling into it, violet light",
    ("vaska", 3): "Vaska surrounded by many translucent mist copies of herself, each slashing with two short curved blades from every side",
    ("nyra", 3): "Nyra cracking her long black barbed whip as a thicket of glowing green venom thorns bursts from the ground",
}

# ----------------------------------------------------------------------------- title wallpaper
# The title screen is built in layers: an empty plate, the altar, and one cut-out per character.
TITLE_PLATE = ("the sacred Solar Altar plateau high above a sea of clouds at night during an eternal eclipse: a huge "
               "black disc where the sun should be, ringed by a cold silver-white corona, dim stars, a wide ring of "
               "ancient stone pillars carved with golden suns standing far back on both sides, small fires and "
               "glowing crystals at the pillar bases, an EMPTY open flagstone floor in the centre and foreground (no "
               "altar, no statue, nothing in the middle), symmetrical composition, wide cinematic anime background "
               "painting, no characters, no people, no text, highly detailed", 1536, 704)

TITLE_ALTAR = ("the Solar Altar, an ancient round stone altar on three circular steps, worn pale marble with carved "
               "golden sun rays and runes, a shallow golden cradle on top, warm golden light falling on it from "
               "above, front view, centered, isolated on a plain flat light grey background, anime key art style, "
               "clean ink line art, cel shading, highly detailed, no text")

_POSE = ("full colour anime key art, clean confident ink line art, cel shading with soft painted gradients, the "
         "ENTIRE body visible from head to feet with space around, standing in a strong, confident heroic stance, "
         "isolated on a plain flat light grey background, no floor shadow, no text, no other people")

# per character: (side the light comes from, extra pose/weapon description for those without a design sheet)
TITLE_CAST = {
    # traitors stand left of the altar and face right; guardians stand right and face left
    "veyr": ("right", "holding his sheathed sword at his hip, cold and commanding, a leader"),
    "rhex": ("right", "resting his battle axe on his shoulder, smirking"),
    "vaska": ("right", "a twin blade in each hand held low, half veiled in mist"),
    "mael": ("right", "fists clenched in his gauntlets, small stones floating around him"),
    "nyra": ("right", "her venom whip coiled in one hand, poised"),
    "zerin": ("right", "holding a long storm spear crackling with yellow lightning"),
    "corvin": ("right", "a curved cyan crystal blade in each hand, glowing crystal shards floating around him"),
    "thane": ("right", "his twin black swords crossed in front of him, shadows curling off them"),
    "seran": ("left", "one hand on the hilt of his sheathed sabre, steady and protective, a leader"),
    "kael": ("left", "holding his lightning sword ready at his side, determined"),
    "tala": ("left", "holding her long wind spear upright beside her"),
    "darin": ("left", "massive stone gauntlets raised, calm and strong"),
    "mira": ("left", "holding her whip-sword lowered, a ribbon of pink light curling from it"),
    "iren": ("left", "a short dagger in each hand in a quick, low stance"),
    "lyra": ("left", "holding a tall white and ice-blue bow with an arrow nocked, pointed down"),
    "oren": ("left", "his glowing mechanical resonance gloves raised, faint sound-wave rings around them"),
    "auren": ("front", "standing tall and serene facing the viewer, hands folded before him, a wise elder"),
}


def title_pose(c: str) -> str:
    side, extra = TITLE_CAST[c]
    if side == "front":
        turn = "facing the viewer, warm golden light from below"
    else:
        other = "left" if side == "right" else "right"
        turn = (f"body turned three-quarters toward the {side} of the picture, looking toward the {side}, warm golden "
                f"rim light from the {side}, cool violet light from the {other}")
    look = LOOKS[c]
    weapon = ""
    for wid, (owner, wlook, _p) in WEAPON_SHEETS.items():
        if owner == c:
            weapon = (f" {c.capitalize()}'s weapon is {wlook}, exactly like the weapon beside them in reference "
                      f"image 1; it appears once, held naturally.")
    return (f"{_POSE}. {look}, {extra}, {turn}. Keep the face, hair and outfit exactly like reference image 1."
            f"{weapon}")

# ----------------------------------------------------------------------------- armed concept art
# Each fighter holding their approved weapon: the look the 3D fighter and its grip must match.
ARMED_CONCEPTS = {
    "kael": [("stance", "full body, Kael in a two-handed sword guard, both hands gripping the hilt of his "
              "straight lightning longsword, blade raised diagonally before him, feet planted wide, determined"),
             ("grip", "close-up of Kael's two hands gripping the long navy cord-wrapped hilt of his straight "
              "lightning longsword one above the other, below the round silver disc guard, light-blue lightning "
              "crackling up the dark steel blade")],
    "rhex": [("stance", "full body, Rhex in a heavy two-handed stance, both hands on the long red-wrapped haft "
              "of his black-flame battle axe, the crescent blade raised over his shoulder, smirking"),
             ("grip", "close-up of Rhex's two muscular hands gripping the long dark wooden haft of his battle "
              "axe one above the other, red leather wrap, the blackened crescent blade with its ember-red edge "
              "above them")],
}
ARMED_STYLE = ("full colour anime key art, clean confident ink line art, cel shading with soft painted gradients, "
               "dramatic lighting, plain dark grey-blue background, no text, no other people")

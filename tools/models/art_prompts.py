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

PROPS = {
    "centroid": ("the Centroid, a sacred floating star-shaped crystal stone with many sharp facets, glowing with "
                 "warm golden-white light from inside, faint orbiting sparks, isolated game asset, centered, plain "
                 "light grey background, even studio lighting, highly detailed", 1024, 1024),
    "solar_altar": ("the Solar Altar, an ancient round stone altar pedestal on three circular steps, carved golden sun "
                    "rays and runes on its sides, a shallow golden cradle on top for a sacred stone, worn marble, "
                    "isolated game asset, front three-quarter view, plain light grey background, even studio "
                    "lighting, highly detailed", 1216, 832),
}

_BG = (", wide cinematic background painting for a 2.5D fighting game arena, no characters, no people, "
       "empty ground in the foreground, epic atmosphere, volumetric light, highly detailed digital painting")

BACKDROPS = {
    "training_ground": ("the stone training courtyard of a mountain fortress at dawn, wooden training posts and "
                        "weapon racks, banners, distant snowy peaks under a pale golden sky" + _BG, 1664, 704),
    "silent_forest": ("a silent ancient forest at night, giant mossy trees, drifting blue-grey mist between the "
                      "trunks, faint moonlight beams, fireflies" + _BG, 1664, 704),
    "broken_pass": ("a broken mountain pass at dusk, shattered cliffs, floating rock fragments defying gravity, "
                    "violet storm clouds, dust in the air" + _BG, 1664, 704),
    "underground_sanctuary": ("an underground sanctuary cavern, carved stone pillars, glowing green crystal "
                              "veins, still water pools reflecting light, ancient statues" + _BG, 1664, 704),
    "solar_altar": ("the sacred Solar Altar plateau above the clouds at the dawn of a new day, a ring of ancient "
                    "stone pillars with golden sun carvings, rays of warm sunrise light breaking through, stars "
                    "fading in the deep blue sky" + _BG, 1664, 704),
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
    ("kael", 1): "Kael thrusting his sword forward as a crackling bolt of blue-white lightning blasts from its tip",
    ("kael", 2): "Kael dashing forward in a blur, his body wrapped in blue lightning, afterimages streaking behind him",
    ("rhex", 1): "Rhex slamming his battle axe down, unleashing a roaring wave of black flames with ember-red edges",
    ("rhex", 2): "Rhex roaring with his axe raised as a dome of black fire explodes around him, embers flying",
    ("tala", 1): "Tala with her spear held across her body, her amber eyes glowing green as a ring of wind blows the mist away",
    ("tala", 2): "Tala lunging and thrusting her spear as a spiralling green wind lance tears forward with leaves",
    ("vaska", 1): "Vaska fading into swirling grey mist, only her eyes and twin blades visible through the fog",
    ("vaska", 2): "Vaska stepping out of the mist beside a ghostly mirror image of herself, both with twin blades raised",
    ("darin", 1): "Darin slamming his stone gauntlets into the ground as a massive wall of rock erupts before him",
    ("darin", 2): "Darin punching the ground with a stone gauntlet, cracks and rock spikes racing forward, dust exploding",
    ("mael", 1): "Mael raising one hand as a black sphere of crushing gravity forms, rocks orbiting it, purple light",
    ("mael", 2): "Mael hurling glowing purple boulders that rise and launch from the shattered ground",
    ("mira", 1): "Mira with her eyes closed, bathed in a pillar of soft pink-white moonlight, crescent symbols glowing around her",
    ("mira", 2): "Mira whipping her segmented silver blade like a ribbon of pink moonlight across the frame",
    ("nyra", 1): "Nyra cracking her long whip which drips glowing green venom, a cruel smile",
    ("nyra", 2): "Nyra reaching out with a clawed hand as dark green curse tendrils drain glowing energy toward her",
}

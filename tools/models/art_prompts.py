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

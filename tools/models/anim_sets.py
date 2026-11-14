"""The fight animation set of each fighting style: one Mixamo clip per move slot, all exported
on Mixamo's standard skeleton (Y Bot), then built into assets/animations/<set>/<set>_anims.res
by tools/models/build_anims.gd and retargeted onto each fighter's body in the game.

    python3 tools/models/anim_sets.py greatsword        # download that set's clips
    godot --headless --path . -s tools/models/build_anims.gd -- greatsword

Slots (what the game plays): idle, walk_forward, walk_back, run, jump, air_attack, block,
block_hit, hit_light, hit_heavy, knockdown, victory, light_1..3, heavy_1..2, cast_1, cast_2,
buff, dash. walk_back may be "reverse:walk_forward" (the walk played backwards).
Picked by previewing every candidate on the fighter (tools/models/anim_preview.gd).
"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
sys.path.insert(0, HERE)

# slot: (Mixamo product id, export in place)
SETS = {
    # Kael: a two-handed sword (Mixamo "Great Sword" moves)
    "greatsword": {
        "idle": ("c9cc7140-b96c-11e4-a802-0aaa78deedf9", False),
        "walk_forward": ("c9cc7257-b96c-11e4-a802-0aaa78deedf9", True),
        "walk_back": "reverse:walk_forward",
        "run": ("c9ce86d8-b96c-11e4-a802-0aaa78deedf9", True),   # rifle sprint: hands together, leaning in
        "jump": ("c9cc7c0e-b96c-11e4-a802-0aaa78deedf9", False),
        "air_attack": ("c9cc8bd6-b96c-11e4-a802-0aaa78deedf9", False),
        "block": ("c9cc815e-b96c-11e4-a802-0aaa78deedf9", False),
        "block_hit": ("c9cc82f0-b96c-11e4-a802-0aaa78deedf9", False),
        "hit_light": ("c9cc83b2-b96c-11e4-a802-0aaa78deedf9", False),
        "hit_heavy": ("c9cc8471-b96c-11e4-a802-0aaa78deedf9", False),
        "knockdown": ("c9cc9aaa-b96c-11e4-a802-0aaa78deedf9", False),   # Two Handed Sword Death
        "victory": ("c9ccc0b3-b96c-11e4-a802-0aaa78deedf9", False),     # sheathes the sword
        "light_1": ("c9cc7d9c-b96c-11e4-a802-0aaa78deedf9", False),
        "light_2": ("c9cc7fdc-b96c-11e4-a802-0aaa78deedf9", False),
        "light_3": ("c9cc7f1e-b96c-11e4-a802-0aaa78deedf9", False),
        "heavy_1": ("c9cc8d52-b96c-11e4-a802-0aaa78deedf9", False),     # high spin attack
        "heavy_2": ("c9cc7e5c-b96c-11e4-a802-0aaa78deedf9", False),     # overhead cleave
        "cast_1": ("c9cc7fdc-b96c-11e4-a802-0aaa78deedf9", False),      # forward slash: Arc Bolt leaves the blade
        "cast_2": ("c9cc975d-b96c-11e4-a802-0aaa78deedf9", False),      # casting: the kneeling slam
        "buff": ("c9cc9819-b96c-11e4-a802-0aaa78deedf9", False),        # power up
        "dash": ("c9cc8c95-b96c-11e4-a802-0aaa78deedf9", False),        # slide attack: Thunder Step
    },
    # Rhex: a heavy two-handed battle axe. Mixamo's axe pack is one-handed, so the two-handed
    # great-weapon moves carry it, heavier and more brutal, with the axe pack's reactions/taunt.
    "greataxe": {
        "idle": ("c9cc946d-b96c-11e4-a802-0aaa78deedf9", False),
        "walk_forward": ("c9cc73a7-b96c-11e4-a802-0aaa78deedf9", True),
        "walk_back": "reverse:walk_forward",
        "run": ("c9ce86d8-b96c-11e4-a802-0aaa78deedf9", True),   # rifle sprint: hands together, leaning in
        "jump": ("c9cc7cd9-b96c-11e4-a802-0aaa78deedf9", False),
        "air_attack": ("c9cc8bd6-b96c-11e4-a802-0aaa78deedf9", False),
        "block": ("c9cc8232-b96c-11e4-a802-0aaa78deedf9", False),
        "block_hit": ("c9cecdb9-b96c-11e4-a802-0aaa78deedf9", False),   # axe: block react large
        "hit_light": ("c9cedd30-b96c-11e4-a802-0aaa78deedf9", False),   # axe: react large from left
        "hit_heavy": ("c9cedebd-b96c-11e4-a802-0aaa78deedf9", False),   # axe: react large gut
        "knockdown": ("c9cc9aaa-b96c-11e4-a802-0aaa78deedf9", False),
        "victory": ("c9cee10b-b96c-11e4-a802-0aaa78deedf9", False),     # axe: battle cry
        "light_1": ("c9cc7e5c-b96c-11e4-a802-0aaa78deedf9", False),     # overhead chop
        "light_2": ("c9cc8764-b96c-11e4-a802-0aaa78deedf9", False),     # low sweep
        "light_3": ("c9cc98d6-b96c-11e4-a802-0aaa78deedf9", False),
        "heavy_1": ("c9cc8d52-b96c-11e4-a802-0aaa78deedf9", False),     # spinning cleave
        "heavy_2": ("c9cc92cb-b96c-11e4-a802-0aaa78deedf9", False),     # kick into the haft
        "cast_1": ("c9cc975d-b96c-11e4-a802-0aaa78deedf9", False),      # slam: Black Flame Wave
        "cast_2": ("c9cc9819-b96c-11e4-a802-0aaa78deedf9", False),      # power up: Hellfire Burst
        "buff": ("c9cee1d2-b96c-11e4-a802-0aaa78deedf9", False),        # axe: chest thump
        "dash": ("c9cc8c95-b96c-11e4-a802-0aaa78deedf9", False),
    },
}


def download(set_name):
    import mixamo
    spec = SETS[set_name]
    out = os.path.join(ROOT, "assets", "animations", set_name)
    os.makedirs(out, exist_ok=True)
    char = mixamo.ybot()
    for slot, v in spec.items():
        if isinstance(v, str):
            continue
        pid, inplace = v
        f = os.path.join(out, slot + ".fbx")
        if os.path.exists(f):
            continue
        mixamo.fetch(mixamo.export(pid, char, inplace), f)
        print("saved", f, flush=True)
    with open(os.path.join(out, "set.txt"), "w") as fh:
        for slot, v in spec.items():
            fh.write(f"{slot}={v}\n" if isinstance(v, str) else f"{slot}=mixamo:{v[0]}\n")


if __name__ == "__main__":
    for s in sys.argv[1:]:
        download(s)


# ----------------------------------------------------------------------------- AI motion (HY-Motion 1.0)
# Text prompts per move slot, generated on Kaggle (tools/models/kaggle/motion/motion.py), then picked
# against the Mixamo clips by previewing both on the fighter. Under 30 words each; both hands stay
# together as on a two-handed hilt or haft (the model can't see the weapon).
_SW = "A swordsman gripping a long sword hilt with both hands together"
_AX = "A strong warrior gripping a heavy two-handed axe haft with both hands together"
MOTION_PROMPTS = {
    "greatsword": {
        "idle": (_SW + ", standing upright in a confident fighting guard, knees slightly bent, chest open, breathing.", 3.0),
        "walk_forward": (_SW + " in front, stepping forward steadily in a fighting guard.", 2.0),
        "light_1": (_SW + " swings a fast diagonal slash from upper right to lower left, then returns to guard.", 1.6),
        "light_2": (_SW + " swings a quick horizontal slash from left to right, stepping forward.", 1.6),
        "light_3": (_SW + " thrusts forward with a lunge, arms extending, then recovers to guard.", 1.6),
        "heavy_1": (_SW + " raises both hands high above the head and slams down in a powerful overhead strike.", 2.0),
        "heavy_2": (_SW + " spins around once with a wide powerful horizontal slash.", 2.2),
        "air_attack": (_SW + " jumps and slashes downward while in the air, then lands.", 1.8),
        "block": (_SW + " raises both hands in front of the face to block, bracing.", 1.5),
        "cast_1": (_SW + " thrusts both hands forward sharply, releasing a blast.", 1.6),
        "dash": (_SW + " dashes forward fast with a low slash passing through.", 1.4),
        "victory": ("A swordsman lowers his long sword, plants it point down and stands tall, proud.", 3.0),
    },
    "greataxe": {
        "idle": (_AX + ", standing upright and broad, shoulders squared, weight shifting menacingly.", 3.0),
        "walk_forward": (_AX + ", stomping forward heavily and confidently.", 2.0),
        "light_1": (_AX + " chops down diagonally with force, then pulls back.", 1.7),
        "light_2": (_AX + " swings a heavy horizontal chop from right to left.", 1.7),
        "light_3": (_AX + " rams forward with the haft, then swings upward.", 1.7),
        "heavy_1": (_AX + " raises both hands high overhead and smashes straight down into the ground.", 2.2),
        "heavy_2": (_AX + " spins a full turn with a sweeping horizontal swing.", 2.4),
        "air_attack": (_AX + " leaps and chops downward hard while landing.", 1.8),
        "block": (_AX + " holds both hands up across the chest to block, bracing.", 1.5),
        "cast_1": (_AX + " slams both hands down to the ground in a powerful strike.", 1.8),
        "victory": ("A strong warrior raises both fists overhead and roars in triumph.", 3.0),
    },
}

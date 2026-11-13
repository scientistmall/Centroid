#!/usr/bin/env python3
"""Find how to hold each weapon model: its long axis, handle end, grip point and blade side.

  python3 tools/models/weapon_grip.py            # all assets/weapons/*.glb -> assets/weapons/weapons.json

The weapon concepts are drawn horizontally with the handle on the RIGHT, so after Hunyuan3D the
handle end is the +X end of the long axis. The grip sits a weapon-specific fraction of the length
in from that end (a sword is held just below the guard, a spear around its middle). The second
principal axis, signed toward the heavier side, is the "edge" direction (an axe head's side).

The game (scripts/fight3d/model3d.gd) puts the grip in the fist, the axis along the forearm
direction it already uses, and scales the model to LENGTH metres.
"""
import glob
import json
import os

import numpy as np
import trimesh

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..")
WEAPONS = os.path.join(ROOT, "assets", "weapons")

# weapon id -> (grip position as a fraction of length from the handle end, real length in metres)
SPEC = {
    "kael_sword": (0.09, 1.0),
    "rhex_axe": (0.12, 1.05),
    "mira_blade": (0.07, 1.05),
    "tala_spear": (0.38, 1.95),
}
OWNER = {"kael_sword": "kael", "rhex_axe": "rhex", "mira_blade": "mira", "tala_spear": "tala"}


def analyse(path, grip_frac):
    scene = trimesh.load(path, force="scene", process=False)
    geoms = [g for g in scene.dump() if isinstance(g, trimesh.Trimesh)]
    mesh = trimesh.util.concatenate(geoms)
    pts = mesh.sample(20000) if len(mesh.faces) else mesh.vertices
    c = pts.mean(0)
    u, s, vt = np.linalg.svd(pts - c, full_matrices=False)
    axis, side = vt[0], vt[1]
    if axis[0] < 0:          # point the axis at the handle (+X) end
        axis = -axis
    proj = (pts - c) @ axis
    lo, hi = proj.min(), proj.max()
    length = hi - lo
    handle_end = c + axis * hi
    grip = handle_end - axis * (grip_frac * length)
    # edge/side direction toward where more of the mass sits (axe head, sword edge)
    sp = (pts - c) @ side
    if np.mean(sp ** 3) < 0:
        side = -side
    blade_dir = -axis  # from the grip toward the tip
    return {
        "grip": [round(float(x), 5) for x in grip],
        "axis": [round(float(x), 5) for x in blade_dir],
        "side": [round(float(x), 5) for x in side],
        "length": round(float(length), 5),
        "tip_from_grip": round(float((1.0 - grip_frac) * length), 5),
    }


def main():
    out = {}
    for path in sorted(glob.glob(os.path.join(WEAPONS, "*.glb"))):
        wid = os.path.basename(path)[:-4]
        if wid.endswith("_shape") or wid not in SPEC:
            continue
        frac, metres = SPEC[wid]
        info = analyse(path, frac)
        info.update({"file": f"res://assets/weapons/{wid}.glb", "metres": metres, "owner": OWNER.get(wid, "")})
        out[wid] = info
        print(wid, json.dumps(info))
    with open(os.path.join(WEAPONS, "weapons.json"), "w") as f:
        json.dump(out, f, indent=1)
    print("wrote", os.path.join(WEAPONS, "weapons.json"))


if __name__ == "__main__":
    main()

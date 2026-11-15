"""HY-Motion candidates (.npz) -> JSON the game's clip builder reads (tools/models/ai_clips.gd).

    python3 tools/models/motion_to_json.py assets/animations/greatsword/ai

For each <slot>_k<i>.npz: quaternions (x, y, z, w) per joint per frame (22 SMPL-H body joints,
local to the parent; joint 0 = the pelvis, in world space) and the pelvis position per frame.
skeleton.npz gives the rest joint positions and parents (identity rest rotations, T-pose).
"""
import glob
import json
import os
import sys

import numpy as np

NAMES = ["Pelvis", "L_Hip", "R_Hip", "Spine1", "L_Knee", "R_Knee", "Spine2", "L_Ankle", "R_Ankle", "Spine3",
         "L_Foot", "R_Foot", "Neck", "L_Collar", "R_Collar", "Head", "L_Shoulder", "R_Shoulder", "L_Elbow",
         "R_Elbow", "L_Wrist", "R_Wrist"]


def rot6d_to_mat(x):
    x = x.reshape(*x.shape[:-1], 3, 2)
    a1, a2 = x[..., 0], x[..., 1]
    b1 = a1 / np.linalg.norm(a1, axis=-1, keepdims=True)
    b2 = a2 - (b1 * a2).sum(-1, keepdims=True) * b1
    b2 /= np.linalg.norm(b2, axis=-1, keepdims=True)
    b3 = np.cross(b1, b2)
    return np.stack([b1, b2, b3], axis=-1)


def mat_to_quat(m):
    q = np.empty(m.shape[:-2] + (4,))
    t = np.trace(m, axis1=-2, axis2=-1)
    flat_m, flat_q, flat_t = m.reshape(-1, 3, 3), q.reshape(-1, 4), t.reshape(-1)
    for i in range(flat_m.shape[0]):
        r, tr = flat_m[i], flat_t[i]
        if tr > 0:
            s = np.sqrt(tr + 1.0) * 2
            w, x, y, z = 0.25 * s, (r[2, 1] - r[1, 2]) / s, (r[0, 2] - r[2, 0]) / s, (r[1, 0] - r[0, 1]) / s
        elif r[0, 0] > r[1, 1] and r[0, 0] > r[2, 2]:
            s = np.sqrt(1.0 + r[0, 0] - r[1, 1] - r[2, 2]) * 2
            w, x, y, z = (r[2, 1] - r[1, 2]) / s, 0.25 * s, (r[0, 1] + r[1, 0]) / s, (r[0, 2] + r[2, 0]) / s
        elif r[1, 1] > r[2, 2]:
            s = np.sqrt(1.0 + r[1, 1] - r[0, 0] - r[2, 2]) * 2
            w, x, y, z = (r[0, 2] - r[2, 0]) / s, (r[0, 1] + r[1, 0]) / s, 0.25 * s, (r[1, 2] + r[2, 1]) / s
        else:
            s = np.sqrt(1.0 + r[2, 2] - r[0, 0] - r[1, 1]) * 2
            w, x, y, z = (r[1, 0] - r[0, 1]) / s, (r[0, 2] + r[2, 0]) / s, (r[1, 2] + r[2, 1]) / s, 0.25 * s
        flat_q[i] = (x, y, z, w)
    return q


def main(d):
    sk = np.load(os.path.join(d, "skeleton.npz"))
    joints = sk["joints"][:22].astype(float)
    # the clips are in floor space (feet at y = 0); lift the rest skeleton onto the same floor
    floor = joints[:, 1].min()
    parents = sk["parents"][:22].astype(int)
    json.dump({"names": NAMES, "rest": (joints - [0.0, floor, 0.0]).round(5).tolist(), "parents": parents.tolist()},
              open(os.path.join(d, "skeleton.json"), "w"))
    for f in sorted(glob.glob(os.path.join(d, "*_k*.npz"))):
        z = np.load(f)
        r6 = z["rot6d"][:, :22]
        q = mat_to_quat(rot6d_to_mat(r6))
        pel = joints[0] + z["transl"]
        json.dump({"fps": int(z["fps"]), "prompt": str(z["prompt"]), "quats": q.round(5).tolist(),
                   "pelvis": pel.round(5).tolist()}, open(f[:-4] + ".json", "w"))
        print("wrote", f[:-4] + ".json", q.shape[0], "frames")


if __name__ == "__main__":
    for d in sys.argv[1:]:
        main(d)

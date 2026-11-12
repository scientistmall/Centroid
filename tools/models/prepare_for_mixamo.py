#!/usr/bin/env python3
"""Turn an AI-generated character model into a Mixamo-ready ZIP (OBJ + MTL + texture).

Mixamo only accepts FBX / OBJ / ZIP, and AI models (e.g. Tencent Hunyuan3D) are often
GLB and very heavy. This script:
  1. loads GLB / GLTF / OBJ (with its texture),
  2. merges everything into one mesh,
  3. stands it on the ground (feet at y=0), centres it, scales it to the real height,
  4. decimates it to a phone-friendly triangle count (keeping UVs / texture),
  5. writes  <out_dir>/<name>_mixamo.zip  (+ a small report).

Usage:
  python3 tools/models/prepare_for_mixamo.py assets/characters/kael/raw/kael.glb \
      --name kael --height 1.78 [--tris 30000] [--rotate 0] [--out assets/characters/kael]

Needs: pip install trimesh pymeshlab pillow numpy
"""
import argparse
import json
import os
import shutil
import tempfile
import zipfile

import numpy as np
import pymeshlab
import trimesh


def load_single_mesh(path: str) -> trimesh.Trimesh:
    loaded = trimesh.load(path, force="scene", process=False)
    geoms = [g for g in loaded.dump() if isinstance(g, trimesh.Trimesh)] if isinstance(loaded, trimesh.Scene) else [loaded]
    if not geoms:
        raise SystemExit("No mesh found in %s" % path)
    mesh = geoms[0] if len(geoms) == 1 else trimesh.util.concatenate(geoms)
    return mesh


def normalise(mesh: trimesh.Trimesh, height: float, rotate_deg: float) -> trimesh.Trimesh:
    if rotate_deg:
        mesh.apply_transform(trimesh.transformations.rotation_matrix(np.radians(rotate_deg), [0, 1, 0]))
    lo, hi = mesh.bounds
    size_y = hi[1] - lo[1]
    if size_y <= 0:
        raise SystemExit("Model has no height?")
    s = height / size_y
    mesh.apply_scale(s)
    lo, hi = mesh.bounds
    centre = (lo + hi) / 2.0
    mesh.apply_translation([-centre[0], -lo[1], -centre[2]])
    return mesh


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("model")
    ap.add_argument("--name", required=True)
    ap.add_argument("--height", type=float, default=1.8, help="character height in metres")
    ap.add_argument("--tris", type=int, default=30000, help="target triangle count")
    ap.add_argument("--rotate", type=float, default=0.0, help="extra rotation around Y (degrees) so the model faces +Z")
    ap.add_argument("--out", default=None, help="output folder (default: the model's character folder)")
    a = ap.parse_args()

    out_dir = a.out or os.path.dirname(os.path.dirname(os.path.abspath(a.model)))
    os.makedirs(out_dir, exist_ok=True)
    mesh = load_single_mesh(a.model)
    tris_before = len(mesh.faces)
    mesh = normalise(mesh, a.height, a.rotate)

    with tempfile.TemporaryDirectory() as tmp:
        src_obj = os.path.join(tmp, "src.obj")
        # trimesh writes OBJ + MTL + texture PNG next to it when the mesh is textured
        mesh.export(src_obj, include_texture=True)
        ms = pymeshlab.MeshSet()
        ms.load_new_mesh(src_obj)
        has_tex = ms.current_mesh().has_wedge_tex_coord() or ms.current_mesh().has_vertex_tex_coord()
        if ms.current_mesh().has_vertex_tex_coord() and not ms.current_mesh().has_wedge_tex_coord():
            ms.apply_filter("compute_texcoord_transfer_vertex_to_wedge")
            has_tex = True
        if ms.current_mesh().face_number() > a.tris:
            if has_tex:
                ms.apply_filter("meshing_decimation_quadric_edge_collapse_with_texture",
                                targetfacenum=a.tris, preserveboundary=True, optimalplacement=True)
            else:
                ms.apply_filter("meshing_decimation_quadric_edge_collapse",
                                targetfacenum=a.tris, preserveboundary=True, preservenormal=True, optimalplacement=True)
        tris_after = ms.current_mesh().face_number()
        pack = os.path.join(tmp, "pack")
        os.makedirs(pack)
        out_obj = os.path.join(pack, a.name + ".obj")
        ms.save_current_mesh(out_obj, save_wedge_texcoord=has_tex, save_textures=True)
        # make sure every texture referenced by the MTL is in the pack
        for f in os.listdir(tmp):
            if f.lower().endswith((".png", ".jpg", ".jpeg")) and not os.path.exists(os.path.join(pack, f)):
                shutil.copy(os.path.join(tmp, f), pack)
        zip_path = os.path.join(out_dir, a.name + "_mixamo.zip")
        with zipfile.ZipFile(zip_path, "w", zipfile.ZIP_DEFLATED) as z:
            for f in sorted(os.listdir(pack)):
                z.write(os.path.join(pack, f), f)
        files = sorted(os.listdir(pack))

    report = {
        "source": a.model, "zip": zip_path, "height_m": a.height,
        "triangles_before": int(tris_before), "triangles_after": int(tris_after),
        "textured": bool(has_tex), "files": files,
        "zip_mb": round(os.path.getsize(zip_path) / 1e6, 2),
    }
    with open(os.path.join(out_dir, a.name + "_mixamo_report.json"), "w") as f:
        json.dump(report, f, indent=2)
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    main()

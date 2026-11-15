"""A thin weapon (a sword) built straight from its approved design art, in Blender (bpy).

    <bpy venv>/bin/python tools/models/weapon_from_art.py assets/weapons/raw/kael_sword_v2.png \
        assets/weapons/kael_sword.glb --thickness 0.014 --bevel 0.004

Image-to-3D can't make blades: they come out as two hollow shells. A blade is a flat shape, so
this traces the weapon's outline from the design image (plain background), fills it, gives it
real thickness with bevelled edges, and paints both faces with the design itself, so the 3D
weapon is the approved weapon, exactly. Output is about 1 unit long; weapon_grip.py measures it.
"""
import argparse
import os
import sys

import bpy
import bmesh
import cv2
import numpy as np


def outline(path):
    img = cv2.imread(path, cv2.IMREAD_COLOR)
    h, w = img.shape[:2]
    bg = np.median(np.concatenate([img[:8].reshape(-1, 3), img[-8:].reshape(-1, 3)]), axis=0)
    mask = (np.abs(img.astype(int) - bg).sum(2) > 36).astype(np.uint8) * 255
    mask = cv2.morphologyEx(mask, cv2.MORPH_CLOSE, np.ones((5, 5), np.uint8))
    cs, _ = cv2.findContours(mask, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_NONE)
    c = max(cs, key=cv2.contourArea)
    c = cv2.approxPolyDP(c, 0.8, True)[:, 0, :].astype(float)
    # texture: the design with its background made transparent
    rgba = cv2.cvtColor(img, cv2.COLOR_BGR2BGRA)
    keep = np.zeros_like(mask)
    cv2.drawContours(keep, [c.astype(np.int32)], -1, 255, -1)
    rgba[:, :, 3] = keep
    tex = os.path.splitext(path)[0] + "_tex.png"
    cv2.imwrite(tex, rgba)
    return c, w, h, tex


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
    ap = argparse.ArgumentParser()
    ap.add_argument("src")
    ap.add_argument("out")
    ap.add_argument("--thickness", type=float, default=0.014)
    ap.add_argument("--bevel", type=float, default=0.004)
    a = ap.parse_args(argv)
    pts, w, h, tex = outline(a.src)
    span = max(np.ptp(pts[:, 0]), np.ptp(pts[:, 1]))
    cx, cy = pts[:, 0].mean(), pts[:, 1].mean()
    bpy.ops.wm.read_factory_settings(use_empty=True)
    me = bpy.data.meshes.new("blade")
    ob = bpy.data.objects.new("Weapon", me)
    bpy.context.scene.collection.objects.link(ob)
    bm = bmesh.new()
    vs = [bm.verts.new(((x - cx) / span, -(y - cy) / span, 0.0)) for x, y in pts]
    es = [bm.edges.new((vs[i], vs[(i + 1) % len(vs)])) for i in range(len(vs))]
    bmesh.ops.triangle_fill(bm, use_beauty=True, use_dissolve=False, edges=es)
    # UVs: front projection onto the design image
    uv = bm.loops.layers.uv.new("UVMap")
    for f in bm.faces:
        for lp in f.loops:
            x = lp.vert.co.x * span + cx
            y = -lp.vert.co.y * span + cy
            lp[uv].uv = (x / w, 1.0 - y / h)
    bm.to_mesh(me)
    bm.free()
    bpy.context.view_layer.objects.active = ob
    ob.select_set(True)
    sol = ob.modifiers.new("thick", "SOLIDIFY")
    sol.thickness = a.thickness
    sol.offset = 0.0
    bev = ob.modifiers.new("edge", "BEVEL")
    bev.width = a.bevel
    bev.segments = 2
    bev.limit_method = "ANGLE"
    bpy.ops.object.modifier_apply(modifier="thick")
    bpy.ops.object.modifier_apply(modifier="edge")
    bpy.ops.object.shade_auto_smooth(angle=0.6) if hasattr(bpy.ops.object, "shade_auto_smooth") else None
    mat = bpy.data.materials.new("design")
    mat.use_nodes = True
    nt = mat.node_tree
    bsdf = nt.nodes.get("Principled BSDF")
    texn = nt.nodes.new("ShaderNodeTexImage")
    texn.image = bpy.data.images.load(tex)
    texn.interpolation = "Cubic"
    nt.links.new(texn.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Metallic"].default_value = 0.6
    bsdf.inputs["Roughness"].default_value = 0.35
    me.materials.append(mat)
    bpy.ops.export_scene.gltf(filepath=a.out, export_format="GLB", use_selection=True, export_yup=True)
    print("wrote", a.out, os.path.getsize(a.out) // 1024, "KB,", len(me.polygons), "faces")


main()

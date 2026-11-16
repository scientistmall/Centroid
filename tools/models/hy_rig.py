"""Hunyuan 3D character -> game-ready rigged GLB (runs inside Blender's Python, bpy).

    <bpy venv>/bin/python tools/models/hy_rig.py in.fbx assets/characters/kael/kael_hy.glb \
        --height 1.78 [--tris 60000] [--tex 2048] [--debug out_dir]

A Hunyuan 3D export is one very dense, unrigged, textured mesh in an A-pose with sculpted fists.
This script:
  1. scales it to the fighter's height, feet on the ground, facing -Y (glTF / Godot +Z);
  2. decimates it to a phone-friendly triangle count (UVs kept) and shrinks the textures;
  3. finds the joints from the body's shape (fists, shoulders, legs, spine) and builds a
     humanoid skeleton with VRM bone names, so the game retargets the shared fight clips onto
     it exactly as it does for VRM models (scripts/fight3d/vrm_retarget.gd);
  4. skins it with Blender's automatic (heat) weights, then makes the head and the fists rigid;
  5. paints vertex colours for secondary motion: R = coat / cloth flex, G = hair flex
     (read by assets/shaders/character.gdshader);
  6. exports a GLB.
"""
import argparse
import math
import os
import sys

import bpy
import numpy as np
from mathutils import Vector

BONES = []  # (name, head, tail, parent, deform)


def log(*a):
    print("[hy_rig]", *a, flush=True)


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def import_mesh(path):
    ext = os.path.splitext(path)[1].lower()
    if ext == ".fbx":
        bpy.ops.import_scene.fbx(filepath=path)
    elif ext in (".glb", ".gltf"):
        bpy.ops.import_scene.gltf(filepath=path)
    else:
        sys.exit("unsupported " + ext)
    meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    for o in bpy.context.scene.objects:
        o.select_set(o in meshes)
    bpy.context.view_layer.objects.active = meshes[0]
    if len(meshes) > 1:
        bpy.ops.object.join()
    ob = bpy.context.view_layer.objects.active
    # drop parents / empties, bake every transform into the vertices
    bpy.ops.object.parent_clear(type="CLEAR_KEEP_TRANSFORM")
    for o in list(bpy.context.scene.objects):
        if o is not ob:
            bpy.data.objects.remove(o, do_unlink=True)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    return ob


def verts(ob):
    n = len(ob.data.vertices)
    co = np.empty(n * 3, dtype=np.float64)
    ob.data.vertices.foreach_get("co", co)
    return co.reshape(-1, 3)


def normalise(ob, height):
    v = verts(ob)
    lo, hi = v.min(0), v.max(0)
    s = height / (hi[2] - lo[2])
    centre = Vector(((lo[0] + hi[0]) / 2, (lo[1] + hi[1]) / 2, lo[2]))
    for vtx in ob.data.vertices:
        vtx.co = (vtx.co - centre) * s
    ob.data.update()
    # face -Y: the nose is the most forward point near the top of the head
    v = verts(ob)
    head = v[v[:, 2] > height * 0.86]
    hx = np.abs(head[:, 0]) < height * 0.03
    front = head[hx]
    if len(front) and abs(front[:, 1].min()) < abs(front[:, 1].max()):
        log("model faces +Y, turning it around")
        for vtx in ob.data.vertices:
            vtx.co.x, vtx.co.y = -vtx.co.x, -vtx.co.y
        ob.data.update()


def _collapse(ob, ratio, keep=None, factor=1.0):
    m = ob.modifiers.new("dec", "DECIMATE")
    m.decimate_type = "COLLAPSE"
    m.ratio = min(1.0, ratio)
    m.use_collapse_triangulate = True
    if keep:
        m.vertex_group = keep
        m.invert_vertex_group = True    # weighted = protected
        m.vertex_group_factor = factor
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.modifier_apply(modifier=m.name)
    return sum(len(p.vertices) - 2 for p in ob.data.polygons)


def decimate(ob, target, keep=None):
    """Collapse to about `target` triangles. With `keep` (a vertex group over the face), the last
    step favours the face: it keeps more of its detail and hair spikes and clothes give up more.
    The even first pass keeps the silhouette (feet, hair tips) from being collapsed away."""
    tris = sum(len(p.vertices) - 2 for p in ob.data.polygons)
    if tris <= target:
        return tris
    if keep is None:
        out = _collapse(ob, target / tris)
    else:
        mid = _collapse(ob, target * 3.0 / tris)
        out = _collapse(ob, target / mid, keep, 1.0)
        if out > target * 1.08:
            out = _collapse(ob, target / out)
        face = sum(1 for p in ob.data.polygons
                   if all(ob.vertex_groups[keep].index in [g.group for g in ob.data.vertices[i].groups] for i in p.vertices))
        log(f"face keeps {face} triangles")
    log(f"decimated {tris} -> {out} triangles")
    return out


def shrink_textures(ob, size):
    for slot in ob.material_slots:
        if not slot.material or not slot.material.node_tree:
            continue
        nt = slot.material.node_tree
        # the game's toon shader reads only the base colour: drop normal / roughness / metal maps
        for n in list(nt.nodes):
            if n.type == "TEX_IMAGE" and n.image and any(k in n.image.name.lower() for k in ("normal", "rough", "metal")):
                nt.nodes.remove(n)
        for n in nt.nodes:
            if n.type == "NORMAL_MAP":
                nt.nodes.remove(n)
                break
        for n in nt.nodes:
            if n.type == "TEX_IMAGE" and n.image and max(n.image.size) > size:
                n.image.scale(size, size)
                n.image.pack()
                log("texture", n.image.name, "->", size)


# ----------------------------------------------------------------------------- joints from shape
def central_span(xs, bin_w):
    """Half-width of the contiguous cluster of x values around 0 (the torso in a slice)."""
    if len(xs) == 0:
        return 0.0
    edges = np.arange(xs.min(), xs.max() + bin_w, bin_w)
    hist, edges = np.histogram(xs, edges)
    i0 = int(np.searchsorted(edges, 0.0)) - 1
    i0 = min(max(i0, 0), len(hist) - 1)
    l = r = i0
    # grow while there is mesh within two bins (a decimated surface has small gaps)
    while l > 0 and (hist[l - 1] > 0 or (l > 1 and hist[l - 2] > 0)):
        l -= 1
    while r < len(hist) - 1 and (hist[r + 1] > 0 or (r < len(hist) - 2 and hist[r + 2] > 0)):
        r += 1
    return max(abs(edges[l]), abs(edges[r + 1]))


def slab(v, z0, z1):
    return v[(v[:, 2] >= z0) & (v[:, 2] < z1)]


def neck_and_chin(v, H):
    """Shoulder line, neck and chin heights from the body's shape.
    Neck: the first slice above the shoulders that is much narrower than them. Chin: walking down
    the middle of the face, the point where the front surface falls back (under the jaw). The neck
    joint must sit below the chin, or the jaw is skinned to the neck and shears when the head turns
    (a short thick neck under wide shoulders, as on Rhex, puts the narrow slice inside the jaw)."""
    def span_at(z, dz=0.006):
        sl = slab(v, z - dz * H, z + dz * H)
        return central_span(sl[:, 0], H * 0.006) if len(sl) else 0.0
    zs = np.arange(0.66, 0.95, 0.005) * H
    raw = np.array([span_at(z) for z in zs])
    widths = np.array([np.median(raw[max(0, i - 2):i + 3]) for i in range(len(raw))])
    band = (zs >= 0.68 * H) & (zs <= 0.88 * H)
    peak_i = int(np.argmax(np.where(band, widths, 0.0)))
    neck_z = 0.84 * H
    for i in range(peak_i + 1, len(zs)):
        if widths[i] < 0.6 * widths[peak_i]:
            neck_z = float(zs[i])
            break
    sh_z = neck_z - 0.035 * H

    def front_y(z):
        s = slab(v, z - 0.004 * H, z + 0.004 * H)
        s = s[np.abs(s[:, 0]) < 0.025 * H]
        return float(np.percentile(s[:, 1], 1)) if len(s) > 4 else None
    # the face's front at mouth height, then down until the surface recedes under the jaw
    z = neck_z + 0.05 * H
    face = front_y(z)
    chin_z = neck_z
    while face is not None and z > sh_z:
        fy = front_y(z)
        if fy is None or fy > face + 0.02 * H:
            break
        face = min(face, fy)
        chin_z = z
        z -= 0.0025 * H
    return neck_z, sh_z, chin_z, span_at


def face_group(ob, H):
    """Vertex group 'keep' over the face (front of the head between the chin and the brow)."""
    v = verts(ob)
    neck_z, sh_z, chin_z, _ = neck_and_chin(v, H)
    g = ob.vertex_groups.new(name="keep")
    head = slab(v, chin_z, chin_z + 0.15 * H)
    head = head[np.abs(head[:, 0]) < 0.07 * H]
    yc = float(np.median(head[:, 1])) if len(head) else 0.0
    idx = [i for i, co in enumerate(v)
           if chin_z - 0.015 * H < co[2] < chin_z + 0.15 * H and abs(co[0]) < 0.075 * H and co[1] < yc + 0.01 * H]
    g.add(idx, 1.0, "REPLACE")
    log(f"face group: {len(idx)} vertices (chin z {chin_z / H:.3f}H)")
    return "keep"


def joints(ob, H):
    v = verts(ob)
    J = {}
    # fists: the outermost points to each side in the arm band
    band = slab(v, 0.30 * H, 0.75 * H)
    for side, sgn in (("Left", 1.0), ("Right", -1.0)):
        x = band[:, 0] * sgn
        far = band[x > x.max() - 0.05 * H]
        J[side + "Fist"] = Vector(far.mean(0))
    # neck: the narrowest point of the central body between the shoulders and the head
    # (found, not assumed, so tall hair like a mohawk doesn't move the shoulders)
    neck_z, sh_z, chin_z, span_at = neck_and_chin(v, H)
    # shoulder joints: the outer edge of the shoulders just below their top, less the deltoid
    sh_span = span_at(sh_z - 0.02 * H, 0.008)
    sh_x = max(sh_span - 0.045 * H, 0.08 * H)
    half_w = max(0.7 * sh_x, 0.06 * H)
    chest = slab(v, sh_z - 0.12 * H, sh_z - 0.08 * H)
    chest_c = chest[np.abs(chest[:, 0]) < half_w]
    y_chest = float(np.percentile(chest_c[:, 1], 2) + 0.56 * (np.percentile(chest_c[:, 1], 98) - np.percentile(chest_c[:, 1], 2))) if len(chest_c) else 0.0
    # the neck joint below the chin, the head joint at it: the whole jaw moves with the head
    neck_j = max(min(neck_z, chin_z - 0.016 * H), sh_z + 0.01 * H)
    head_j = max(chin_z - 0.004 * H, neck_j + 0.015 * H)
    if neck_j < neck_z:
        log(f"chin at {chin_z / H:.3f}H: neck joint lowered {neck_z / H:.3f}H -> {neck_j / H:.3f}H")
    else:
        head_j = neck_z + 0.035 * H
    log(f"neck z {neck_j / H:.3f}H  head z {head_j / H:.3f}H  shoulder z {sh_z / H:.3f}H  shoulder x {sh_x:.3f}  torso half-width {half_w:.3f}")
    # spine, centred front-to-back on each slice
    def yc(z):
        """Depth centre of the body at height z: a little behind the middle of front and back
        (scarves, collars and coat fronts sit on the front, so a plain average is too far forward)."""
        s = slab(v, z - 0.012 * H, z + 0.012 * H)
        s = s[np.abs(s[:, 0]) < half_w * 0.6]
        if len(s) < 10:
            return y_chest
        lo, hi = np.percentile(s[:, 1], 2), np.percentile(s[:, 1], 98)
        return float(lo + 0.56 * (hi - lo))
    body = sh_z / 0.815          # height the body would have without hair above the skull
    J["Hips"] = Vector((0, yc(0.53 * body), 0.53 * body))
    J["Spine"] = Vector((0, yc(0.59 * body), 0.59 * body))
    J["Chest"] = Vector((0, yc(0.665 * body), 0.665 * body))
    J["UpperChest"] = Vector((0, yc(0.74 * body), 0.74 * body))
    head_y = yc(neck_z + 0.07 * H)   # above the collar and scarf
    J["Neck"] = Vector((0, 0.5 * (yc(sh_z - 0.04 * H) + head_y), neck_j))
    J["Head"] = Vector((0, head_y, head_j))
    J["HeadTop"] = Vector((0, J["Head"].y, H))
    # legs: the two clusters in a thigh slice
    thigh = slab(v, 0.36 * body, 0.42 * body)
    for side, sgn in (("Left", 1.0), ("Right", -1.0)):
        leg = thigh[(thigh[:, 0] * sgn > 0.01 * H) & (thigh[:, 0] * sgn < half_w * 1.6)]
        lx = float(np.median(leg[:, 0])) if len(leg) else sgn * 0.06 * H
        ly = float(np.median(leg[:, 1])) if len(leg) else 0.0
        foot = slab(v, 0.0, 0.06 * H)
        foot = foot[(foot[:, 0] * sgn > 0) & (np.abs(foot[:, 0] - lx) < 0.07 * H)]
        toe_y = float(foot[:, 1].min()) if len(foot) else ly - 0.12 * H
        heel_y = float(foot[:, 1].max()) if len(foot) else ly + 0.04 * H
        ankle_y = heel_y - 0.25 * (heel_y - toe_y)
        J[side + "UpperLeg"] = Vector((lx * 0.85, ly, 0.505 * body))
        J[side + "LowerLeg"] = Vector((lx, ly - 0.012 * H, 0.285 * body))
        J[side + "Foot"] = Vector((lx, ankle_y, 0.055 * H))
        J[side + "Toes"] = Vector((lx, toe_y + 0.35 * (ankle_y - toe_y), 0.018 * H))
        J[side + "ToeTip"] = Vector((lx, toe_y, 0.018 * H))
        # arms: shoulder -> elbow -> wrist -> fist
        sgnx = sgn
        # the arm hangs in a plane: the shoulder joint sits between the chest centre and the fist
        arm_y = 0.5 * (y_chest + J[side + "Fist"].y)
        J[side + "Shoulder"] = Vector((sgnx * 0.025 * H, y_chest, sh_z - 0.01 * H))
        J[side + "UpperArm"] = Vector((sgnx * sh_x, arm_y, sh_z))
        fist = J[side + "Fist"]
        up = J[side + "UpperArm"]
        to_fist = fist - up
        wrist = fist - to_fist.normalized() * 0.04 * H
        elbow = up + (wrist - up) * 0.5 + Vector((0, 0.01 * H, 0))
        J[side + "LowerArm"] = elbow
        J[side + "Hand"] = wrist
        J[side + "Knuckle"] = fist + to_fist.normalized() * 0.015 * H
    return J


def build_armature(J, H):
    arm = bpy.data.armatures.new("Armature")
    rig = bpy.data.objects.new("Armature", arm)
    bpy.context.scene.collection.objects.link(rig)
    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.mode_set(mode="EDIT")
    eb = arm.edit_bones

    def bone(name, head, tail, parent=None, deform=True, connect=False):
        b = eb.new(name)
        b.head, b.tail = head, tail
        if parent:
            b.parent = eb[parent]
            b.use_connect = connect
        b.use_deform = deform
        return b

    bone("Hips", J["Hips"], J["Spine"])
    bone("Spine", J["Spine"], J["Chest"], "Hips", connect=True)
    bone("Chest", J["Chest"], J["UpperChest"], "Spine", connect=True)
    bone("UpperChest", J["UpperChest"], J["Neck"], "Chest", connect=True)
    bone("Neck", J["Neck"], J["Head"], "UpperChest", connect=True)
    bone("Head", J["Head"], J["HeadTop"], "Neck", connect=True)
    for s in ("Left", "Right"):
        bone(s + "Shoulder", J[s + "Shoulder"], J[s + "UpperArm"], "UpperChest")
        bone(s + "UpperArm", J[s + "UpperArm"], J[s + "LowerArm"], s + "Shoulder", connect=True)
        bone(s + "LowerArm", J[s + "LowerArm"], J[s + "Hand"], s + "UpperArm", connect=True)
        bone(s + "Hand", J[s + "Hand"], J[s + "Knuckle"], s + "LowerArm", connect=True)
        # marks the knuckles for the weapon grip; the fists are sculpted, so it doesn't deform
        kd = (J[s + "Knuckle"] - J[s + "Hand"]).normalized() * 0.03 * H
        bone(s + "MiddleProximal", J[s + "Knuckle"], J[s + "Knuckle"] + kd, s + "Hand", deform=False)
        bone(s + "UpperLeg", J[s + "UpperLeg"], J[s + "LowerLeg"], "Hips")
        bone(s + "LowerLeg", J[s + "LowerLeg"], J[s + "Foot"], s + "UpperLeg", connect=True)
        bone(s + "Foot", J[s + "Foot"], J[s + "Toes"], s + "LowerLeg", connect=True)
        bone(s + "Toes", J[s + "Toes"], J[s + "ToeTip"], s + "Foot", connect=True)
    # rolls: z axis forward-ish for limbs keeps Blender's auto weights well behaved
    for b in eb:
        b.align_roll(Vector((0, -1, 0)) if abs((b.tail - b.head).normalized().y) < 0.8 else Vector((0, 0, 1)))
    bpy.ops.object.mode_set(mode="OBJECT")
    return rig


def skin(ob, rig):
    bpy.ops.object.select_all(action="DESELECT")
    ob.select_set(True)
    rig.select_set(True)
    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.parent_set(type="ARMATURE_AUTO")
    names = [g.name for g in ob.vertex_groups]
    weighted = sum(1 for vtx in ob.data.vertices if any(g.weight > 0.01 for g in vtx.groups))
    log(f"auto weights: {weighted}/{len(ob.data.vertices)} vertices weighted, groups {len(names)}")
    if weighted < 0.9 * len(ob.data.vertices):
        log("heat weighting left vertices bare; filling with envelope weights")
        for g in list(ob.vertex_groups):
            ob.vertex_groups.remove(g)
        ob.parent = None
        bpy.ops.object.select_all(action="DESELECT")
        ob.select_set(True)
        rig.select_set(True)
        bpy.context.view_layer.objects.active = rig
        bpy.ops.object.parent_set(type="ARMATURE_ENVELOPE")


def rigid_regions(ob, J, H):
    """Above the jaw moves 100% with Head; past the wrist 100% with Hand (fists are rigid)."""
    groups = {g.name: g for g in ob.vertex_groups}
    for name in ("Head", "LeftHand", "RightHand"):
        if name not in groups:
            groups[name] = ob.vertex_groups.new(name=name)
    jaw_z = J["Neck"].z + 0.55 * (J["Head"].z - J["Neck"].z)
    head_r = 0.09 * H
    for vtx in ob.data.vertices:
        co = vtx.co
        target = None
        if co.z > jaw_z and math.hypot(co.x - J["Head"].x, co.y - J["Head"].y) < head_r * 1.4:
            blend = min(1.0, (co.z - jaw_z) / (0.012 * H))
            target, w = "Head", blend
        else:
            for s in ("Left", "Right"):
                wrist, fist = J[s + "Hand"], J[s + "Fist"]
                d = fist - wrist
                t = (co - wrist).dot(d) / d.length_squared
                if t > 0.0 and (co - fist).length < 0.075 * H:
                    target, w = s + "Hand", min(1.0, t * 3.0)
        if target is None:
            continue
        for g in vtx.groups:
            gname = ob.vertex_groups[g.group].name
            if gname != target:
                ob.vertex_groups[g.group].add([vtx.index], g.weight * (1.0 - w), "REPLACE")
        cur = 0.0
        for g in vtx.groups:
            if ob.vertex_groups[g.group].name == target:
                cur = g.weight
        groups[target].add([vtx.index], cur + (1.0 - cur) * w, "REPLACE")


def flex_colours(ob, J, H):
    """R = cloth flex (coat tails hanging free of the legs), G = hair flex (spikes)."""
    me = ob.data
    if "flex" in me.color_attributes:
        me.color_attributes.remove(me.color_attributes["flex"])
    attr = me.color_attributes.new(name="flex", type="FLOAT_COLOR", domain="POINT")
    lx = {s: (J[s + "LowerLeg"].x, J[s + "LowerLeg"].y) for s in ("Left", "Right")}
    head = J["Head"]
    cols = np.zeros((len(me.vertices), 4), dtype=np.float32)
    cols[:, 3] = 1.0
    for i, vtx in enumerate(me.vertices):
        co = vtx.co
        if co.z < 0.52 * H:
            d = min(math.hypot(co.x - lx[s][0], co.y - lx[s][1]) for s in lx)
            free = max(0.0, min(1.0, (d - 0.075 * H) / (0.05 * H)))
            hang = max(0.0, min(1.0, (0.52 * H - co.z) / (0.3 * H)))
            cols[i, 0] = free * hang
        r = math.hypot(co.x - head.x, co.y - head.y)
        if co.z > 0.93 * H or (co.z > 0.88 * H and r > 0.075 * H):
            cols[i, 1] = max(0.0, min(1.0, (co.z - 0.9 * H) / (0.08 * H) + (r - 0.07 * H) / (0.05 * H)))
    attr.data.foreach_set("color", cols.ravel())
    me.color_attributes.active_color = attr
    log("flex: cloth verts %d, hair verts %d" % ((cols[:, 0] > 0.05).sum(), (cols[:, 1] > 0.05).sum()))


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
    ap = argparse.ArgumentParser()
    ap.add_argument("src")
    ap.add_argument("out")
    ap.add_argument("--height", type=float, required=True)
    ap.add_argument("--tris", type=int, default=60000)
    ap.add_argument("--tex", type=int, default=2048)
    ap.add_argument("--build", type=float, default=1.0, help="widen the body (x and depth) by this factor")
    ap.add_argument("--keep-face", action="store_true", help="decimate the face less than the rest")
    a = ap.parse_args(argv)
    reset()
    ob = import_mesh(a.src)
    ob.name = "Body"
    normalise(ob, a.height)
    if a.build != 1.0:
        for vtx in ob.data.vertices:
            vtx.co.x *= a.build
            vtx.co.y *= a.build
        ob.data.update()
        log("build x", a.build)
    decimate(ob, a.tris, face_group(ob, a.height) if a.keep_face else None)
    shrink_textures(ob, a.tex)
    J = joints(ob, a.height)
    for k in sorted(J):
        log(f"  {k:16s} {tuple(round(c, 3) for c in J[k])}")
    rig = build_armature(J, a.height)
    skin(ob, rig)
    rigid_regions(ob, J, a.height)
    flex_colours(ob, J, a.height)
    os.makedirs(os.path.dirname(os.path.abspath(a.out)), exist_ok=True)
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.gltf(filepath=a.out, export_format="GLB", use_selection=True,
                              export_animations=False, export_skins=True,
                              export_vertex_color="ACTIVE", export_all_vertex_colors=False,
                              export_yup=True)
    log("wrote", a.out, os.path.getsize(a.out) // 1024, "KB")


main()

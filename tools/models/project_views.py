#!/usr/bin/env python3
"""Sharpen an AI 3D character's texture by projecting its 2D concept views onto it.

Hunyuan3D's own texture is painted at low resolution, so faces and outfit details blur and the back is
guessed. This projects the crisp concept art straight onto the model:
  * front / back / left / right views onto the surfaces that face each camera (orthographic),
  * a face close-up onto the face at higher resolution,
blending by how squarely each surface faces each view and skipping hidden surfaces. Where no view
sees the surface (under the arms, soles) the original texture stays.

  python3 tools/models/project_views.py assets/characters/kael/raw/kael.glb \\
      --views assets/characters/kael/views --name kael [--tex 4096] [--out ...glb] [--debug dir]

Views are found as <views>/<name>_{front,back,left,right,face}.png (any may be missing; front is
required). Alignment: each view is fitted to the mesh's own silhouette (scale + offset search, and
for side views the facing direction), so the views don't need to be perfectly framed.
"""
import argparse
import os

import cv2
import numpy as np
import trimesh
from PIL import Image

# view -> (direction toward the camera, screen-right axis); model faces +Z with Y up
VIEWS = {
    "front": (np.array([0.0, 0.0, 1.0]), np.array([1.0, 0.0, 0.0])),
    "back": (np.array([0.0, 0.0, -1.0]), np.array([-1.0, 0.0, 0.0])),
    "left": (np.array([1.0, 0.0, 0.0]), np.array([0.0, 0.0, -1.0])),
    "right": (np.array([-1.0, 0.0, 0.0]), np.array([0.0, 0.0, 1.0])),
}
POWER = 3.0       # how strongly a surface must face a view to take its colour
FRONT_BOOST = 1.6  # the front concept is the most reliable view


# ----------------------------------------------------------------------------- loading
def load(path):
    scene = trimesh.load(path, force="scene", process=False)
    geoms = scene.dump() if isinstance(scene, trimesh.Scene) else [scene]
    geoms = [g for g in geoms if isinstance(g, trimesh.Trimesh)]
    mesh = geoms[0] if len(geoms) == 1 else trimesh.util.concatenate(geoms)
    mat = mesh.visual.material
    img = getattr(mat, "baseColorTexture", None) or getattr(mat, "image", None)
    if img is None or mesh.visual.uv is None:
        raise SystemExit("mesh has no texture / UVs")
    return mesh, np.asarray(img.convert("RGB"))


def fg_mask(img):
    """Foreground of a concept on a plain light background."""
    h, w = img.shape[:2]
    border = np.concatenate([img[:8].reshape(-1, 3), img[-8:].reshape(-1, 3), img[:, :8].reshape(-1, 3),
                             img[:, -8:].reshape(-1, 3)]).astype(np.float32)
    bg = np.median(border, axis=0)
    fg_mask.last_bg = bg
    d = np.linalg.norm(cv2.GaussianBlur(img, (5, 5), 0).astype(np.float32) - bg, axis=2)
    m = (d > 22).astype(np.uint8)
    m = cv2.morphologyEx(m, cv2.MORPH_CLOSE, np.ones((7, 7), np.uint8))
    n, lab, stats, _ = cv2.connectedComponentsWithStats(m)
    if n > 1:
        keep = 1 + np.argmax(stats[1:, cv2.CC_STAT_AREA])
        m = (lab == keep).astype(np.uint8)
    # fill only small holes (specks inside clothing); real gaps between legs/arms stay background
    inv = (1 - m).astype(np.uint8)
    n2, lab2, stats2, _ = cv2.connectedComponentsWithStats(inv)
    full = m.copy()
    limit = 0.002 * h * w
    for i in range(1, n2):
        x, y, bw, bh, area = stats2[i]
        touches = x == 0 or y == 0 or x + bw >= w or y + bh >= h
        if not touches and area < limit:
            full[lab2 == i] = 1
    return full.astype(bool)


# ----------------------------------------------------------------------------- views
class View:
    """An orthographic camera fitted so the mesh silhouette matches the concept's silhouette."""

    def __init__(self, name, img, mesh, mirror=False):
        self.name, self.img = name, img
        self.toward, right = VIEWS[name]
        self.right = -right if mirror else right
        self.h, self.w = img.shape[:2]
        self.mask = fg_mask(img)
        self.bg = fg_mask.last_bg
        # sample only well inside the drawing, so edge texels never pick up background
        self.inner = cv2.erode(self.mask.astype(np.uint8), np.ones((7, 7), np.uint8)).astype(bool)
        v = mesh.vertices
        self.u = v @ self.right
        self.y = v[:, 1]
        self.depth = v @ self.toward  # bigger = closer to this camera
        ys, xs = np.nonzero(self.mask)
        self.fg_box = (xs.min(), ys.min(), xs.max(), ys.max())
        self.faces = mesh.faces
        self.s, self.ox, self.oy = self._fit()

    def to_px(self, u, y, s=None, ox=None, oy=None):
        s = self.s if s is None else s
        return (u * s + (self.ox if ox is None else ox), -y * s + (self.oy if oy is None else oy))

    def silhouette(self, s, ox, oy, scale=1.0):
        px, py = self.to_px(self.u, self.y, s, ox, oy)
        pts = np.stack([px * scale, py * scale], 1)[self.faces].round().astype(np.int32)
        m = np.zeros((int(self.h * scale), int(self.w * scale)), np.uint8)
        cv2.fillPoly(m, list(pts), 1)
        return m.astype(bool)

    def _fit(self):
        x0, y0, x1, y1 = self.fg_box
        s0 = (y1 - y0) / (self.y.max() - self.y.min())
        cu = (self.u.max() + self.u.min()) / 2
        ox0 = (x0 + x1) / 2 - cu * s0
        oy0 = y1 + self.y.min() * s0
        small = cv2.resize(self.mask.astype(np.uint8), None, fx=0.25, fy=0.25, interpolation=cv2.INTER_NEAREST).astype(bool)
        best = (-1, s0, ox0, oy0)
        for ds in np.linspace(0.94, 1.06, 7):
            s = s0 * ds
            for dx in np.linspace(-0.03, 0.03, 7) * self.w:
                for dy in np.linspace(-0.03, 0.03, 7) * self.h:
                    sil = self.silhouette(s, ox0 + dx, oy0 + dy, 0.25)
                    hh, ww = min(sil.shape[0], small.shape[0]), min(sil.shape[1], small.shape[1])
                    a, b = sil[:hh, :ww], small[:hh, :ww]
                    iou = (a & b).sum() / max((a | b).sum(), 1)
                    if iou > best[0]:
                        best = (iou, s, ox0 + dx, oy0 + dy)
        self.iou = best[0]
        return best[1], best[2], best[3]

    def refine_head(self, H):
        """Fit the head on its own (drawings often place the head slightly differently from the
        body); stores self.head = (s, ox, oy). Texels on the head use it, blended at the neck."""
        top = self.y.max()
        sel = self.y > top - 0.17 * H
        fsel = self.faces[np.all(sel[self.faces], axis=1)]
        self.head = (self.s, self.ox, self.oy)
        if len(fsel) < 50:
            return
        px, py = self.to_px(self.u[sel], self.y[sel])
        pad = 0.25 * (px.max() - px.min())
        x0, x1 = int(max(0, px.min() - pad)), int(min(self.w, px.max() + pad))
        y0, y1 = int(max(0, py.min() - pad)), int(min(self.h, py.max() + pad))
        target = self.mask[y0:y1, x0:x1]
        hw = px.max() - px.min()
        best = (-1.0, self.head)
        for ds in np.linspace(0.92, 1.08, 9):
            s = self.s * ds
            # keep the neck where it was: scale about the head's bottom-centre
            cx, cy = (px.min() + px.max()) / 2, py.max()
            for dx in np.linspace(-0.12, 0.12, 13) * hw:
                for dy in np.linspace(-0.12, 0.12, 13) * hw:
                    ox = cx + dx - (cx - self.ox) * ds
                    oy = cy + dy - (cy - self.oy) * ds
                    hx, hy = self.u * s + ox, -self.y * s + oy
                    pts = np.stack([hx - x0, hy - y0], 1)[fsel].round().astype(np.int32)
                    m = np.zeros(target.shape, np.uint8)
                    cv2.fillPoly(m, list(pts), 1)
                    m = m.astype(bool)
                    iou = (m & target).sum() / max((m | target).sum(), 1)
                    if iou > best[0]:
                        best = (iou, (s, ox, oy))
        self.head = best[1]
        self.head_iou = best[0]

    def px_blend(self, pos, H):
        """Image coordinates of 3D points: body fit, head fit on the head, blended at the neck."""
        bx, by = self.to_px(pos @ self.right, pos[:, 1])
        s, ox, oy = getattr(self, "head", (self.s, self.ox, self.oy))
        hx, hy = (pos @ self.right) * s + ox, -pos[:, 1] * s + oy
        top = self.y.max()
        t = np.clip((pos[:, 1] - (top - 0.2 * H)) / (0.04 * H), 0, 1)
        return bx * (1 - t) + hx * t, by * (1 - t) + hy * t

    def occluder_depth(self):
        """Per-pixel depth of the nearest surface (painter's algorithm, far to near)."""
        px, py = self.to_px(self.u, self.y)
        tri_depth = self.depth[self.faces].mean(1)
        order = np.argsort(tri_depth)
        pts = np.stack([px, py], 1)[self.faces].round().astype(np.int32)
        zb = np.full((self.h, self.w), -np.inf, np.float32)
        ids = np.full((self.h, self.w), -1, np.int32)
        for t in order:
            cv2.fillPoly(ids, [pts[t]], int(t))
        valid = ids >= 0
        zb[valid] = tri_depth[ids[valid]]
        return zb, ids


def make_view(name, path, mesh):
    img = np.asarray(Image.open(path).convert("RGB"))
    v = View(name, img, mesh)
    if name in ("left", "right"):  # the model may face either way in a side view
        vm = View(name, img, mesh, mirror=True)
        if vm.iou > v.iou:
            v = vm
    return v


# ----------------------------------------------------------------------------- texels
def texel_samples(mesh, tex):
    """3D position, normal and triangle id of every texel covered by the UV layout."""
    uv = mesh.visual.uv
    tuv = np.stack([uv[:, 0] * tex, (1.0 - uv[:, 1]) * tex], 1)
    ids = np.full((tex, tex), -1, np.int32)
    tri = tuv[mesh.faces]
    pts = tri.round().astype(np.int32)
    for t in range(len(mesh.faces)):
        cv2.fillPoly(ids, [pts[t]], t)
    ys, xs = np.nonzero(ids >= 0)
    t = ids[ys, xs]
    # barycentric coordinates in UV space
    a, b, c = tri[t, 0], tri[t, 1], tri[t, 2]
    p = np.stack([xs + 0.5, ys + 0.5], 1)
    v0, v1, v2 = b - a, c - a, p - a
    d00 = (v0 * v0).sum(1)
    d01 = (v0 * v1).sum(1)
    d11 = (v1 * v1).sum(1)
    d20 = (v2 * v0).sum(1)
    d21 = (v2 * v1).sum(1)
    den = d00 * d11 - d01 * d01
    den[np.abs(den) < 1e-12] = 1e-12
    w1 = (d11 * d20 - d01 * d21) / den
    w2 = (d00 * d21 - d01 * d20) / den
    w0 = 1 - w1 - w2
    bary = np.clip(np.stack([w0, w1, w2], 1), 0, 1)
    bary /= bary.sum(1, keepdims=True)
    fv = mesh.vertices[mesh.faces[t]]
    pos = (fv * bary[:, :, None]).sum(1)
    vn = mesh.vertex_normals[mesh.faces[t]]
    nrm = (vn * bary[:, :, None]).sum(1)
    nrm /= np.linalg.norm(nrm, axis=1, keepdims=True) + 1e-9
    return ys, xs, t, pos, nrm


def sample(img, px, py):
    """Bilinear colour lookup at many points at once."""
    h, w = img.shape[:2]
    x = np.clip(px, 0, w - 1.001)
    y = np.clip(py, 0, h - 1.001)
    x0, y0 = x.astype(np.int32), y.astype(np.int32)
    fx, fy = (x - x0)[:, None], (y - y0)[:, None]
    im = img.astype(np.float32)
    c00, c10 = im[y0, x0], im[y0, x0 + 1]
    c01, c11 = im[y0 + 1, x0], im[y0 + 1, x0 + 1]
    return (c00 * (1 - fx) + c10 * fx) * (1 - fy) + (c01 * (1 - fx) + c11 * fx) * fy


# ----------------------------------------------------------------------------- face pass
def face_mapping(front, face_img, mesh):
    """Match the face close-up to the head in the front view: front px -> close-up px."""
    v = mesh.vertices
    H = v[:, 1].max() - v[:, 1].min()
    head = v[v[:, 1] > v[:, 1].max() - 0.13 * H]
    px, py = front.px_blend(head, H)
    x0, x1, y0, y1 = px.min(), px.max(), py.min(), py.max()
    pad = 0.15 * (x1 - x0)
    x0, x1 = int(max(0, x0 - pad)), int(min(front.w, x1 + pad))
    y0, y1 = int(max(0, y0 - pad)), int(min(front.h, y1 + pad))
    crop = cv2.cvtColor(front.img[y0:y1, x0:x1], cv2.COLOR_RGB2GRAY)
    big = cv2.cvtColor(face_img, cv2.COLOR_RGB2GRAY)
    best = (-1, None, None)
    for f in np.linspace(2.0, 9.0, 36):
        tpl = cv2.resize(crop, None, fx=f, fy=f, interpolation=cv2.INTER_CUBIC)
        if tpl.shape[0] >= big.shape[0] or tpl.shape[1] >= big.shape[1]:
            break
        r = cv2.matchTemplate(big, tpl, cv2.TM_CCOEFF_NORMED)
        _, mv, _, loc = cv2.minMaxLoc(r)
        if mv > best[0]:
            best = (mv, f, loc)
    score, f, loc = best
    return score, (x0, y0, f, loc), (x0, y0, x1, y1)


# ----------------------------------------------------------------------------- main
def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("glb")
    ap.add_argument("--views", required=True)
    ap.add_argument("--name", required=True)
    ap.add_argument("--tex", type=int, default=4096)
    ap.add_argument("--out", default="")
    ap.add_argument("--debug", default="")
    a = ap.parse_args()

    mesh, base = load(a.glb)
    tex = a.tex
    base_up = cv2.resize(base, (tex, tex), interpolation=cv2.INTER_CUBIC).astype(np.float32)
    ys, xs, tri, pos, nrm = texel_samples(mesh, tex)
    print("texels:", len(xs))
    H = mesh.vertices[:, 1].max() - mesh.vertices[:, 1].min()
    eps = 0.012 * H

    acc = np.zeros((len(xs), 3), np.float32)
    wsum = np.zeros(len(xs), np.float32)
    views = {}
    for name in ("front", "back", "left", "right"):
        p = os.path.join(a.views, f"{a.name}_{name}.png")
        if not os.path.exists(p):
            continue
        v = make_view(name, p, mesh)
        need = 0.6 if name in ("front", "back") else 0.55
        if v.iou < need and name != "front":
            print(f"view {name}: fit IoU {v.iou:.3f} too low, skipped")
            continue
        views[name] = v
        zb, _ = v.occluder_depth()
        if name in ("front", "back"):
            v.refine_head(H)
            print(f"view {name}: head fit IoU {getattr(v, 'head_iou', 0):.3f}")
            px, py = v.px_blend(pos, H)
        else:
            px, py = v.to_px(pos @ v.right, pos[:, 1])
        inside = (px >= 0) & (px < v.w - 1) & (py >= 0) & (py < v.h - 1)
        ix, iy = np.clip(px.astype(int), 0, v.w - 1), np.clip(py.astype(int), 0, v.h - 1)
        depth = pos @ v.toward
        visible = inside & (zb[iy, ix] - depth < eps) & v.inner[iy, ix]
        # only surfaces that face the camera well (grazing surfaces smear features sideways)
        facing = np.clip((nrm @ v.toward - 0.4) / 0.45, 0, 1) ** 2
        # on the head only surfaces facing almost straight at the camera take the drawing: drawn
        # faces are often wider than the model's head, and their edges would land on the cheeks
        top_y = mesh.vertices[:, 1].max()
        head_t = np.clip((pos[:, 1] - (top_y - 0.2 * H)) / (0.04 * H), 0, 1)
        strict = np.clip((nrm @ v.toward - 0.78) / 0.17, 0, 1) ** 2
        facing = facing * (1 - head_t) + strict * head_t
        if name in ("left", "right"):
            # side views drift most on the head (profiles): keep them off it
            top = mesh.vertices[:, 1].max()
            facing = facing * np.clip((top - 0.24 * H - pos[:, 1]) / (0.03 * H), 0, 1)
        col = sample(v.img, px, py)
        not_bg = np.linalg.norm(col - v.bg, axis=1) > 30.0
        w = facing * visible * not_bg * (FRONT_BOOST if name == "front" else 1.0)
        acc += col * w[:, None]
        wsum += w
        print(f"view {name}: fit IoU {v.iou:.3f}, scale {v.s:.1f}px/u, covers {(w > 0.05).mean() * 100:.1f}% of texels")
    if "front" not in views:
        raise SystemExit("front view is required")

    # face close-up: replaces the front colour on the front of the head
    fp = os.path.join(a.views, f"{a.name}_face.png")
    if os.path.exists(fp):
        face_img = np.asarray(Image.open(fp).convert("RGB"))
        score, (cx0, cy0, f, loc), (hx0, hy0, hx1, hy1) = face_mapping(views["front"], face_img, mesh)
        print(f"face close-up match {score:.2f} (scale x{f:.1f})")
        if score >= 0.6:
            v = views["front"]
            px, py = v.px_blend(pos, H)
            zb, _ = v.occluder_depth()
            ix, iy = np.clip(px.astype(int), 0, v.w - 1), np.clip(py.astype(int), 0, v.h - 1)
            in_head = (px >= hx0) & (px < hx1) & (py >= hy0) & (py < hy1)
            vis = in_head & (zb[iy, ix] - pos @ v.toward < eps)
            facing = np.clip(nrm @ v.toward, 0, 1)
            fx = (px - cx0) * f + loc[0]
            fy = (py - cy0) * f + loc[1]
            ok = vis & (fx >= 0) & (fx < face_img.shape[1] - 1) & (fy >= 0) & (fy < face_img.shape[0] - 1)
            # feather toward the head-box edges so the close-up blends into the body texture
            ex = np.minimum(px - hx0, hx1 - px) / max(1.0, 0.08 * (hx1 - hx0))
            ey = np.minimum(py - hy0, hy1 - py) / max(1.0, 0.08 * (hy1 - hy0))
            feather = np.clip(np.minimum(ex, ey), 0, 1)
            wf = np.clip((facing - 0.55) / 0.3, 0, 1) * ok * feather
            fcol = sample(face_img, fx, fy)
            cur = acc / np.maximum(wsum, 1e-6)[:, None]
            blend = np.where(wsum[:, None] > 1e-6, cur, base_up[ys, xs])
            mixed = blend * (1 - wf[:, None]) + fcol * wf[:, None]
            acc = mixed * np.maximum(wsum, 1e-6)[:, None]
            wsum = np.maximum(wsum, 1e-6) * (wf > 0) + wsum * (wf <= 0)
            print(f"face pass: {(wf > 0.1).sum()} texels")

    proj = acc / np.maximum(wsum, 1e-6)[:, None]
    alpha = np.clip(wsum / 0.35, 0, 1)[:, None]
    out = base_up.copy()
    out[ys, xs] = base_up[ys, xs] * (1 - alpha) + proj * alpha
    out = np.clip(out, 0, 255).astype(np.uint8)
    print(f"projected colour on {(alpha[:, 0] > 0.5).mean() * 100:.1f}% of the surface")

    mesh.visual = trimesh.visual.TextureVisuals(
        uv=mesh.visual.uv,
        material=trimesh.visual.material.PBRMaterial(baseColorTexture=Image.fromarray(out), metallicFactor=0.0,
                                                     roughnessFactor=0.85))
    dst = a.out or a.glb.replace(".glb", "_v2.glb")
    mesh.export(dst)
    print("saved", dst)
    if a.debug:
        os.makedirs(a.debug, exist_ok=True)
        Image.fromarray(out).resize((1024, 1024)).save(os.path.join(a.debug, f"{a.name}_texture.png"))
        for n, v in views.items():
            sil = v.silhouette(v.s, v.ox, v.oy)
            dbg = v.img.copy()
            dbg[sil & ~v.mask] = (255, 0, 0)
            dbg[~sil & v.mask] = (0, 0, 255)
            Image.fromarray(dbg).save(os.path.join(a.debug, f"{a.name}_fit_{n}.png"))


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Run the character jobs on Kaggle's free GPUs and download the results.

  python3 tools/models/kaggle_run.py concepts darin iren --n 2     # FLUX concept images
  python3 tools/models/kaggle_run.py concepts --missing --n 2      # every character without a concept
  python3 tools/models/kaggle_run.py model kael rhex               # Hunyuan3D-2 textured GLBs
  python3 tools/models/kaggle_run.py depth training_ground         # arena depth maps (CPU)
  python3 tools/models/kaggle_run.py panels ch01_post:2,4 ch02_pre:3 --n 2   # redo chosen panels

Needs: pip install kaggle ; a Kaggle API credential (the network proxy injects it) ;
KAGGLE_USERNAME set (or --user). Jobs: tools/models/kaggle/{concepts,hunyuan3d}/.
Outputs: assets/characters/<name>/concepts/<name>_k<i>.png and raw/<name>.glb (+ _shape.glb).
"""
import argparse
import re
import glob
import json
import os
import shutil
import subprocess
import sys
import tempfile
import time

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
CHARS = os.path.join(ROOT, "assets", "characters")
sys.path.insert(0, HERE)
import art_prompts as ap_  # noqa: E402
import generate_character as gc  # noqa: E402  (prompts live there)

DATASET = "centroid-inputs"


def kaggle(*args, check=True) -> str:
    r = subprocess.run(["kaggle", *args], stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
    if check and r.returncode != 0:
        raise SystemExit("kaggle %s failed:\n%s" % (" ".join(args), r.stdout))
    return r.stdout


def picked_concept(name: str) -> str:
    files = sorted(f for f in glob.glob(os.path.join(CHARS, name, "concepts", "*.png")) if "_weapon" not in f)
    if not files:
        raise SystemExit(f"{name}: no concept image in assets/characters/{name}/concepts/")
    return files[0]


def story_panels(scene: str) -> list:
    """The @panel lines of a story file with their running @bg and panel number."""
    path = os.path.join(ROOT, "data", "story", scene + ".story")
    out, bg, n = [], "black", 0
    for raw in open(path, encoding="utf-8"):
        line = raw.strip()
        if line.startswith("@bg "):
            bg = line[4:].strip()
        elif line.startswith("@panel"):
            n += 1
            parts = [x.strip() for x in line[len("@panel"):].split("|")]
            cast = [c.strip().lower() for c in parts[1].split(",")] if len(parts) > 1 else []
            cast = [c for c in cast if c and c != "-"]
            out.append({"n": n, "shape": parts[0].lower() if parts else "wide", "cast": cast,
                        "dir": parts[2] if len(parts) > 2 else "", "bg": bg})
    return out


def char_ref(c: str) -> str:
    """Reference image for a character: the turnaround front view if made, else the picked concept."""
    v = os.path.join(CHARS, c, "views", f"{c}_front.png")
    return v if os.path.exists(v) else picked_concept(c)


WEAPON_WORDS = re.compile(r"sword|blade|axe|spear|whip|lash|gauntlet|knuckle|dagger|weapon|lance|scabbard", re.I)
WEAPON_OF = {owner: wid for wid, (owner, _look, _p) in ap_.WEAPON_SHEETS.items()}


def weapon_sheet(wid: str) -> str:
    """The approved design sheet of a weapon (assets/weapons/sheets/sheet_<id>.png)."""
    f = os.path.join(ROOT, "assets", "weapons", "sheets", f"sheet_{wid}.png")
    if not os.path.exists(f):
        raise SystemExit(f"{wid}: no approved sheet at {f}")
    return f


def char_weapon_ref(c: str) -> str:
    """Character reference with their weapon sheet beside it, one image (views/<c>_armed.png)."""
    from PIL import Image
    out = os.path.join(CHARS, c, "views", f"{c}_armed.png")
    sheet = weapon_sheet(WEAPON_OF[c])
    body = char_ref(c)
    if os.path.exists(out) and os.path.getmtime(out) > max(os.path.getmtime(sheet), os.path.getmtime(body)):
        return out
    a = Image.open(body).convert("RGB")
    b = Image.open(sheet).convert("RGB")
    h = 1024
    a = a.resize((int(a.width * h / a.height), h))
    b = b.resize((int(b.width * h / b.height), h))
    canvas = Image.new("RGB", (a.width + b.width + 24, h), (236, 234, 230))
    canvas.paste(a, (0, 0))
    canvas.paste(b, (a.width + 24, 0))
    os.makedirs(os.path.dirname(out), exist_ok=True)
    open(os.path.join(os.path.dirname(out), ".gdignore"), "a").close()
    canvas.save(out)
    return out


def panel_job(scene: str, p: dict, n_images: int) -> tuple:
    """One panel's prompt and references. A cast entry may also be a weapon id (e.g. veyr_blade) for a
    panel that shows a weapon without its owner. When the direction is about weapons (not practice ones)
    or the panel is an action shot, armed characters are drawn from <c>_armed.png with their weapon."""
    w, h = ap_.PANEL_SIZE.get(p["shape"], (1344, 768))
    cast = [c for c in p["cast"] if c in ap_.LOOKS or c in ap_.WEAPON_SHEETS][:3]
    d = p["dir"]
    armed = (bool(WEAPON_WORDS.search(d)) or p["shape"] in ("action", "splash")) and not re.search(r"practice|wooden", d, re.I)
    who, refs, wield = [], [], []
    for i, c in enumerate(cast):
        n = i + 1
        if c in ap_.WEAPON_SHEETS:
            refs.append(weapon_sheet(c))
            wield.append(f"the weapon is {ap_.WEAPON_SHEETS[c][1]}, exactly like the weapon design in reference image {n}")
            continue
        who.append(f"{ap_.LOOKS[c]} (reference image {n})")
        if armed and c in WEAPON_OF:
            refs.append(char_weapon_ref(c))
            look = ap_.WEAPON_SHEETS[WEAPON_OF[c]][1]
            wield.append(f"{c.capitalize()}'s weapon is {look}, exactly like the weapon beside them in reference image {n}")
        else:
            refs.append(char_ref(c))
    prompt = f"{ap_.PANEL_STYLE}. Scene: {d}. Setting: {ap_.SETTINGS.get(p['bg'], p['bg'].replace('_', ' '))}."
    if who:
        prompt += f" Characters: {'; '.join(who)}. Keep each character's face, hair and outfit exactly like their reference image."
    if wield:
        prompt += " Weapons: " + "; ".join(wield) + ". Each weapon appears once, held naturally in the hand, at the correct size."
    return {"out": f"{scene}_p{p['n']:02d}", "prompt": prompt, "refs": [os.path.basename(r) for r in refs],
            "w": w, "h": h, "n": n_images}, refs


def upload_inputs(user: str, names: list, files: list = None) -> None:
    """Private dataset with the given files (default: the picked concept of each character)."""
    files = files or [picked_concept(n) for n in names]
    with tempfile.TemporaryDirectory() as d:
        for f in files:
            shutil.copy(f, os.path.join(d, os.path.basename(f)))
        meta = {"title": DATASET, "id": f"{user}/{DATASET}", "licenses": [{"name": "CC0-1.0"}]}
        json.dump(meta, open(os.path.join(d, "dataset-metadata.json"), "w"))
        exists = DATASET in kaggle("datasets", "list", "--mine", "-s", DATASET, check=False)
        if exists:
            print(kaggle("datasets", "version", "-p", d, "-m", "inputs " + time.strftime("%Y-%m-%d %H:%M"), "-r", "skip"))
        else:
            print(kaggle("datasets", "create", "-p", d, "-r", "skip"))
    time.sleep(20)  # a new version takes a moment to replace the old one
    for _ in range(60):
        s = kaggle("datasets", "status", f"{user}/{DATASET}", check=False).strip().lower()
        if "ready" in s:
            return
        time.sleep(10)
    raise SystemExit("dataset not ready: " + s)


ATTACH = False   # --attach: wait for and download the version already pushed, push nothing


def push_and_wait(user: str, kind: str, jobs: list, use_dataset: bool, slug: str = "", gpu: bool = True) -> str:
    src = os.path.join(HERE, "kaggle", kind, kind + ".py")
    slug = slug or f"centroid-{kind}"
    if ATTACH:
        print("attaching to the version already pushed:", slug)
    with tempfile.TemporaryDirectory() as d:
        code = open(src).read().replace("JOBS = []", "JOBS = " + json.dumps(jobs), 1)
        open(os.path.join(d, kind + ".py"), "w").write(code)
        meta = {"id": f"{user}/{slug}", "title": slug, "code_file": kind + ".py", "language": "python",
                "kernel_type": "script", "is_private": True, "enable_gpu": gpu, "enable_internet": True,
                "dataset_sources": [f"{user}/{DATASET}"] if use_dataset else [],
                "competition_sources": [], "kernel_sources": []}
        if gpu:
            meta["machine_shape"] = "NvidiaTeslaT4"
        json.dump(meta, open(os.path.join(d, "kernel-metadata.json"), "w"), indent=1)
        if not ATTACH:
            print(kaggle("kernels", "push", "-p", d))
    t0 = time.time()
    last = ""
    while True:
        time.sleep(60)
        s = kaggle("kernels", "status", f"{user}/{slug}", check=False).strip()
        if "429" in s or "rate limit" in s.lower() or "too many requests" in s.lower():
            time.sleep(120)   # Kaggle throttles status polling: wait, the job keeps going
            continue
        if s != last:
            print("[%4.0f min] %s" % ((time.time() - t0) / 60, s), flush=True)
            last = s
        low = s.lower()
        if any(k in low for k in ("complete", "error", "cancel")):
            return low


def download(user: str, slug: str) -> str:
    out = tempfile.mkdtemp(prefix="kaggle_out_")
    print(kaggle("kernels", "output", f"{user}/{slug}", "-p", out, check=False)[-500:])
    logs = glob.glob(os.path.join(out, "*.log"))
    for lf in logs:
        lines = [l for l in open(lf, errors="ignore").read().splitlines() if "CENTROID" in l]
        print("\n".join(lines[-40:]))
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("kind", choices=["concepts", "model", "views", "art", "panels", "splash", "depth", "cutout", "title"])
    ap.add_argument("names", nargs="*")
    ap.add_argument("--missing", action="store_true", help="concepts: every character without a concept yet")
    ap.add_argument("--n", type=int, default=2)
    ap.add_argument("--only", default="", help="panels: comma separated panel numbers (one scene)")
    ap.add_argument("--user", default=os.environ.get("KAGGLE_USERNAME", ""))
    ap.add_argument("--attach", action="store_true", help="wait for the job already pushed instead of pushing")
    a = ap.parse_args()
    global ATTACH
    ATTACH = a.attach
    if not a.user:
        sys.exit("set KAGGLE_USERNAME or pass --user")
    names = a.names
    if a.kind == "concepts" and a.missing:
        names = [n for n in gc.PROMPTS if not glob.glob(os.path.join(CHARS, n, "concepts", "*.png"))]
    if not names:
        sys.exit("no characters given")
    print("characters:", " ".join(names))

    if a.kind == "depth":
        # arena paintings -> depth maps, on a CPU kernel (no GPU queue). The images travel inside
        # the script, so the shared input dataset other jobs may be using is left alone.
        import base64
        import io
        from PIL import Image
        bd = os.path.join(ROOT, "assets", "backdrops")
        jobs = []
        for n in names:
            im = Image.open(os.path.join(bd, n + ".png")).convert("RGB")
            im.thumbnail((1280, 1280))
            buf = io.BytesIO()
            im.save(buf, "JPEG", quality=92)
            jobs.append({"name": n, "b64": base64.b64encode(buf.getvalue()).decode()})
        push_and_wait(a.user, "depth", jobs, use_dataset=False, slug="centroid-depth", gpu=False)
        out = download(a.user, "centroid-depth")
        for f in glob.glob(os.path.join(out, "*_depth.png")):
            shutil.copy(f, bd)
            print("saved", os.path.join(bd, os.path.basename(f)))
        return

    if a.kind == "cutout":
        # image paths -> background removed (RGBA) next to them as <name>_cut.png, CPU kernel, images inline
        import base64
        import io
        from PIL import Image
        jobs, where = [], {}
        for n in names:
            im = Image.open(n).convert("RGB")
            buf = io.BytesIO()
            im.save(buf, "PNG")
            key = os.path.basename(n)[:-4]
            jobs.append({"name": key, "b64": base64.b64encode(buf.getvalue()).decode()})
            where[key] = os.path.dirname(os.path.abspath(n))
        push_and_wait(a.user, "cutout", jobs, use_dataset=False, slug="centroid-cutout", gpu=False)
        out = download(a.user, "centroid-cutout")
        for f in glob.glob(os.path.join(out, "*_cut.png")):
            key = os.path.basename(f)[:-8]
            if key in where:
                shutil.copy(f, where[key])
                print("saved", os.path.join(where[key], os.path.basename(f)))
        return

    if a.kind in ("concepts", "views", "art", "panels", "splash", "title"):
        dest = {}   # out prefix -> folder
        refs = []
        if a.kind == "concepts":
            jobs = [{"out": n, "prompt": gc.PROMPTS[n] + ", " + gc.STYLE, "n": a.n} for n in names]
            dest = {n: os.path.join(CHARS, n, "concepts") for n in names}
        elif a.kind == "views":
            jobs = []
            for n in names:
                ref = picked_concept(n)
                refs.append(ref)
                for v, (prompt, w, h) in ap_.VIEWS.items():
                    jobs.append({"out": f"{n}_{v}", "prompt": prompt, "refs": [os.path.basename(ref)],
                                 "w": w, "h": h, "n": a.n})
                    dest[f"{n}_{v}"] = os.path.join(CHARS, n, "views")
        elif a.kind == "splash":
            jobs = []
            for (c, i), what in ap_.SPLASH.items():
                if names and names != ["all"] and c not in names:
                    continue
                ref = char_ref(c)
                if ref not in refs:
                    refs.append(ref)
                out_id = f"cutin_{c}_{i}"
                jobs.append({"out": out_id, "prompt": f"{ap_.SPLASH_STYLE}. {what}. Character: {ap_.LOOKS[c]} "
                             f"(reference image 1), keep the face, hair and outfit exactly like the reference.",
                             "refs": [os.path.basename(ref)], "w": 1344, "h": 768, "n": a.n})
                dest[out_id] = os.path.join(ROOT, "assets", "cutins", "candidates")
        elif a.kind == "title":
            # the wallpaper: an empty plate (no refs) and one full-body pose per character (own reference)
            jobs = []
            tdir = os.path.join(ROOT, "assets", "title", "candidates")
            for c in names:
                if c == "plate":
                    pr, w, h = ap_.TITLE_PLATE
                    jobs.append({"out": "title_plate", "prompt": pr, "w": w, "h": h, "n": a.n})
                    dest["title_plate"] = tdir
                    continue
                if c == "altar":
                    jobs.append({"out": "title_altar", "prompt": ap_.TITLE_ALTAR, "w": 1216, "h": 832, "n": a.n})
                    dest["title_altar"] = tdir
                    continue
                ref = char_weapon_ref(c) if c in WEAPON_OF else char_ref(c)
                if ref not in refs:
                    refs.append(ref)
                jobs.append({"out": f"title_{c}", "prompt": ap_.title_pose(c), "refs": [os.path.basename(ref)],
                             "w": 832, "h": 1216, "n": a.n})
                dest[f"title_{c}"] = tdir
        elif a.kind == "panels":
            jobs = []
            # names are scenes, or scene:3,7,12 to pick panels per scene (several scenes, one run)
            for name in names:
                scene, _, picked = name.partition(":")
                sel = picked or a.only
                only = {int(x) for x in sel.split(",") if x.strip()} if sel else set()
                for p in story_panels(scene):
                    if only and p["n"] not in only:
                        continue
                    final = os.path.join(ROOT, "assets", "manga", scene, f"{scene}_p{p['n']:02d}.webp")
                    if a.missing and os.path.exists(final):
                        continue
                    job, rf = panel_job(scene, p, a.n)
                    jobs.append(job)
                    refs += [r for r in rf if r not in refs]
                    dest[job["out"]] = os.path.join(ROOT, "assets", "manga", scene, "candidates")
            print(len(jobs), "panels")
        else:  # art: weapons / props / backdrops by id (or all)
            table = {}
            for k, (owner, prompt) in ap_.WEAPONS.items():
                table[k] = (prompt, 1216, 832, os.path.join(ROOT, "assets", "weapons", "concepts"))
            for k, (owner, look, prompt) in ap_.WEAPON_SHEETS.items():
                table["sheet_" + k] = (prompt + ap_._SHEET, 1344, 768, os.path.join(ROOT, "assets", "weapons", "sheets"))
            for k, (prompt, w, h) in ap_.PROPS.items():
                table[k] = (prompt, w, h, os.path.join(ROOT, "assets", "props", "concepts"))
            for k, (prompt, w, h) in ap_.BACKDROPS.items():
                table["bg_" + k] = (prompt, w, h, os.path.join(ROOT, "assets", "backdrops", "candidates"))
            if names == ["sheets"]:
                names = [k for k in table if k.startswith("sheet_")]
            ids = [i for i in names if i != "all"] or list(table)
            if "all" in names:
                ids = list(table)
            jobs = [{"out": i, "prompt": table[i][0], "w": table[i][1], "h": table[i][2], "n": a.n} for i in ids]
            dest = {i: table[i][3] for i in ids}
        if refs and not ATTACH:
            upload_inputs(a.user, [], refs)
        slug = f"centroid-{a.kind}"
        status = push_and_wait(a.user, "concepts", jobs, use_dataset=bool(refs), slug=slug)
        out = download(a.user, slug)
        for f in glob.glob(os.path.join(out, "*_k*.png")):
            key = os.path.basename(f).rsplit("_k", 1)[0]
            d = dest.get(key)
            if not d:
                continue
            os.makedirs(d, exist_ok=True)
            open(os.path.join(d, ".gdignore"), "a").close()
            shutil.copy(f, d)
            print("saved", os.path.join(d, os.path.basename(f)))
            if a.kind == "panels" and f.endswith("_k1.png"):
                from PIL import Image
                final = os.path.join(os.path.dirname(d), os.path.basename(f).replace("_k1.png", ".webp"))
                Image.open(f).convert("RGB").save(final, "WEBP", quality=90, method=6)
    else:
        # characters: multi-view if views/<name>_{front,back,left,right}.png are picked, else the concept;
        # *.png paths (weapon / prop concepts): single image, saved next to their concepts/ folder
        jobs, files, dest = [], [], {}
        for n in names:
            if n.endswith(".png"):
                p = os.path.abspath(n)
                key = os.path.basename(p)[:-4].rsplit("_k", 1)[0]
                files.append(p)
                jobs.append({"name": key, "image": os.path.basename(p), "faces": 20000})
                dest[key] = os.path.dirname(os.path.dirname(p))
                continue
            vdir = os.path.join(CHARS, n, "views")
            vf = {v: os.path.join(vdir, f"{n}_{v}.png") for v in ("front", "back", "left", "right")}
            if all(os.path.exists(f) for f in vf.values()):
                files += list(vf.values())
                jobs.append({"name": n, "image": os.path.basename(vf["front"]),
                             "views": {v: os.path.basename(f) for v, f in vf.items()}})
            else:
                files.append(picked_concept(n))
                jobs.append({"name": n, "image": os.path.basename(picked_concept(n))})
            dest[n] = os.path.join(CHARS, n, "raw")
        upload_inputs(a.user, [], files)
        status = push_and_wait(a.user, "hunyuan3d", jobs, use_dataset=True)
        out = download(a.user, "centroid-hunyuan3d")
        for f in glob.glob(os.path.join(out, "*.glb")):
            key = os.path.basename(f)[:-4].replace("_shape", "")
            d = dest.get(key)
            if not d:
                continue
            os.makedirs(d, exist_ok=True)
            if d.endswith("raw"):
                open(os.path.join(d, ".gdignore"), "a").close()
            shutil.copy(f, d)
            print("saved", os.path.join(d, os.path.basename(f)))
    print("status:", status)
    if "complete" not in status:
        sys.exit(1)


if __name__ == "__main__":
    main()

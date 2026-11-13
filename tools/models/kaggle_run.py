#!/usr/bin/env python3
"""Run the character jobs on Kaggle's free GPUs and download the results.

  python3 tools/models/kaggle_run.py concepts darin iren --n 2     # FLUX concept images
  python3 tools/models/kaggle_run.py concepts --missing --n 2      # every character without a concept
  python3 tools/models/kaggle_run.py model kael rhex               # Hunyuan3D-2 textured GLBs

Needs: pip install kaggle ; a Kaggle API credential (the network proxy injects it) ;
KAGGLE_USERNAME set (or --user). Jobs: tools/models/kaggle/{concepts,hunyuan3d}/.
Outputs: assets/characters/<name>/concepts/<name>_k<i>.png and raw/<name>.glb (+ _shape.glb).
"""
import argparse
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


def panel_job(scene: str, p: dict, n_images: int) -> tuple:
    w, h = ap_.PANEL_SIZE.get(p["shape"], (1344, 768))
    cast = [c for c in p["cast"] if c in ap_.LOOKS][:3]
    who = "; ".join(f"{ap_.LOOKS[c]} (reference image {i + 1})" for i, c in enumerate(cast))
    prompt = f"{ap_.PANEL_STYLE}. Scene: {p['dir']}. Setting: {ap_.SETTINGS.get(p['bg'], p['bg'].replace('_', ' '))}."
    if who:
        prompt += f" Characters: {who}. Keep each character's face, hair and outfit exactly like their reference image."
    refs = [char_ref(c) for c in cast]
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


def push_and_wait(user: str, kind: str, jobs: list, use_dataset: bool, slug: str = "") -> str:
    src = os.path.join(HERE, "kaggle", kind, kind + ".py")
    slug = slug or f"centroid-{kind}"
    with tempfile.TemporaryDirectory() as d:
        code = open(src).read().replace("JOBS = []", "JOBS = " + json.dumps(jobs), 1)
        open(os.path.join(d, kind + ".py"), "w").write(code)
        meta = {"id": f"{user}/{slug}", "title": slug, "code_file": kind + ".py", "language": "python",
                "kernel_type": "script", "is_private": True, "enable_gpu": True, "enable_internet": True,
                "dataset_sources": [f"{user}/{DATASET}"] if use_dataset else [],
                "competition_sources": [], "kernel_sources": [], "machine_shape": "NvidiaTeslaT4"}
        json.dump(meta, open(os.path.join(d, "kernel-metadata.json"), "w"), indent=1)
        print(kaggle("kernels", "push", "-p", d))
    t0 = time.time()
    last = ""
    while True:
        time.sleep(30)
        s = kaggle("kernels", "status", f"{user}/{slug}", check=False).strip()
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
    ap.add_argument("kind", choices=["concepts", "model", "views", "art", "panels", "splash"])
    ap.add_argument("names", nargs="*")
    ap.add_argument("--missing", action="store_true", help="concepts: every character without a concept yet")
    ap.add_argument("--n", type=int, default=2)
    ap.add_argument("--only", default="", help="panels: comma separated panel numbers (one scene)")
    ap.add_argument("--user", default=os.environ.get("KAGGLE_USERNAME", ""))
    a = ap.parse_args()
    if not a.user:
        sys.exit("set KAGGLE_USERNAME or pass --user")
    names = a.names
    if a.kind == "concepts" and a.missing:
        names = [n for n in gc.PROMPTS if not glob.glob(os.path.join(CHARS, n, "concepts", "*.png"))]
    if not names:
        sys.exit("no characters given")
    print("characters:", " ".join(names))

    if a.kind in ("concepts", "views", "art", "panels", "splash"):
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
        elif a.kind == "panels":
            jobs = []
            only = {int(x) for x in a.only.split(",") if x.strip()} if a.only else set()
            for scene in names:
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
            for k, (prompt, w, h) in ap_.PROPS.items():
                table[k] = (prompt, w, h, os.path.join(ROOT, "assets", "props", "concepts"))
            for k, (prompt, w, h) in ap_.BACKDROPS.items():
                table["bg_" + k] = (prompt, w, h, os.path.join(ROOT, "assets", "backdrops", "candidates"))
            ids = [i for i in names if i != "all"] or list(table)
            if "all" in names:
                ids = list(table)
            jobs = [{"out": i, "prompt": table[i][0], "w": table[i][1], "h": table[i][2], "n": a.n} for i in ids]
            dest = {i: table[i][3] for i in ids}
        if refs:
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

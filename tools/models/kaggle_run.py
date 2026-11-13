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


def upload_inputs(user: str, names: list) -> None:
    """Private dataset with the picked concept image of each character."""
    with tempfile.TemporaryDirectory() as d:
        for n in names:
            shutil.copy(picked_concept(n), os.path.join(d, os.path.basename(picked_concept(n))))
        meta = {"title": DATASET, "id": f"{user}/{DATASET}", "licenses": [{"name": "CC0-1.0"}]}
        json.dump(meta, open(os.path.join(d, "dataset-metadata.json"), "w"))
        exists = DATASET in kaggle("datasets", "list", "--mine", "-s", DATASET, check=False)
        if exists:
            print(kaggle("datasets", "version", "-p", d, "-m", "inputs " + time.strftime("%Y-%m-%d %H:%M"), "-r", "skip"))
        else:
            print(kaggle("datasets", "create", "-p", d, "-r", "skip"))
    for _ in range(60):
        s = kaggle("datasets", "status", f"{user}/{DATASET}", check=False).strip().lower()
        if "ready" in s:
            return
        time.sleep(10)
    raise SystemExit("dataset not ready: " + s)


def push_and_wait(user: str, kind: str, jobs: list, use_dataset: bool) -> str:
    src = os.path.join(HERE, "kaggle", kind, kind + ".py")
    slug = f"centroid-{kind}"
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


def download(user: str, kind: str) -> str:
    out = tempfile.mkdtemp(prefix="kaggle_out_")
    print(kaggle("kernels", "output", f"{user}/centroid-{kind}", "-p", out, check=False)[-500:])
    logs = glob.glob(os.path.join(out, "*.log"))
    for lf in logs:
        lines = [l for l in open(lf, errors="ignore").read().splitlines() if "CENTROID" in l]
        print("\n".join(lines[-40:]))
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("kind", choices=["concepts", "model"])
    ap.add_argument("names", nargs="*")
    ap.add_argument("--missing", action="store_true", help="concepts: every character without a concept yet")
    ap.add_argument("--n", type=int, default=2)
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

    if a.kind == "concepts":
        jobs = [{"name": n, "prompt": gc.PROMPTS[n] + ", " + gc.STYLE, "n": a.n} for n in names]
        status = push_and_wait(a.user, "concepts", jobs, use_dataset=False)
        out = download(a.user, "concepts")
        for f in glob.glob(os.path.join(out, "*_k*.png")):
            n = os.path.basename(f).rsplit("_k", 1)[0]
            dst = os.path.join(CHARS, n, "concepts")
            os.makedirs(dst, exist_ok=True)
            open(os.path.join(dst, ".gdignore"), "a").close()
            shutil.copy(f, dst)
            print("saved", os.path.join(dst, os.path.basename(f)))
    else:
        upload_inputs(a.user, names)
        jobs = [{"name": n, "image": os.path.basename(picked_concept(n))} for n in names]
        status = push_and_wait(a.user, "hunyuan3d", jobs, use_dataset=True)
        out = download(a.user, "hunyuan3d")
        for f in glob.glob(os.path.join(out, "*.glb")):
            n = os.path.basename(f)[:-4].replace("_shape", "")
            dst = os.path.join(CHARS, n, "raw")
            os.makedirs(dst, exist_ok=True)
            open(os.path.join(dst, ".gdignore"), "a").close()
            shutil.copy(f, dst)
            print("saved", os.path.join(dst, os.path.basename(f)))
    print("status:", status)
    if "complete" not in status:
        sys.exit(1)


if __name__ == "__main__":
    main()

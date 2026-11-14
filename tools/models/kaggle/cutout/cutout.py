"""Kaggle job: background removal for the title wallpaper cut-outs.

rembg (MIT) with the isnet-anime model (Apache-2.0), on CPU. JOBS is filled in by kaggle_run.py:
[{"name": "kael", "b64": "<png>"}, ...]. Writes <name>_cut.png (RGBA) at the input size.
"""
import base64
import io
import subprocess
import sys

from PIL import Image

JOBS = []


def log(*a):
    print("CENTROID", *a, flush=True)


def main():
    subprocess.run([sys.executable, "-m", "pip", "install", "-q", "rembg", "onnxruntime"], check=True)
    from rembg import new_session, remove
    session = new_session("isnet-anime")
    for j in JOBS:
        img = Image.open(io.BytesIO(base64.b64decode(j["b64"]))).convert("RGB")
        out = remove(img, session=session, alpha_matting=True, alpha_matting_foreground_threshold=240,
                     alpha_matting_background_threshold=12, alpha_matting_erode_size=8)
        out.save(f"{j['name']}_cut.png")
        log("cut", j["name"], img.size)


main()

"""Kaggle job: depth maps for the arena paintings (Depth Anything V2 Small, Apache-2.0).

JOBS is filled in by kaggle_run.py: [{"name": "training_ground", "b64": "<jpeg>"}, ...].
Writes <name>_depth.png (8-bit, white = near) at the input image's size.
"""
import base64
import io

import numpy as np
from PIL import Image

JOBS = []


def log(*a):
    print("CENTROID", *a, flush=True)


def main():
    import torch
    from transformers import pipeline
    pipe = pipeline("depth-estimation", model="depth-anything/Depth-Anything-V2-Small-hf", device=-1)
    for j in JOBS:
        img = Image.open(io.BytesIO(base64.b64decode(j["b64"]))).convert("RGB")
        with torch.no_grad():
            pred = pipe(img)["predicted_depth"]
        d = torch.nn.functional.interpolate(pred.unsqueeze(0) if pred.dim() == 3 else pred[None, None],
                                            size=img.size[::-1], mode="bicubic", align_corners=False)[0, 0].numpy()
        lo, hi = np.percentile(d, 1), np.percentile(d, 99)
        d = np.clip((d - lo) / max(hi - lo, 1e-6), 0, 1)
        Image.fromarray((d * 255).astype(np.uint8)).save(f"{j['name']}_depth.png")
        log("depth", j["name"], img.size)


main()

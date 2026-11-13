# Kaggle GPU job: image -> textured 3D GLB with Tencent Hunyuan3D-2 (shape + paint).
# Pushed and run by tools/models/kaggle_run.py, which fills in JOBS below.
# Inputs: concept PNGs in the attached private dataset (searched under /kaggle/input).
# Outputs: /kaggle/working/<name>.glb (+ <name>_shape.glb), log lines prefixed "CENTROID".
import gc
import glob
import os
import subprocess
import sys
import time
import traceback

JOBS = []  # filled in by kaggle_run.py: [{"name": "kael", "image": "kael_1.png"}, ...]
OCTREE = 256
STEPS = 30
FACES = 60000

WORK = "/kaggle/working"
SRC = "/kaggle/tmp/Hunyuan3D-2"


def log(*a):
    print("CENTROID", *a, flush=True)


def sh(cmd, cwd=None):
    log("$", cmd)
    r = subprocess.run(cmd, shell=True, cwd=cwd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
    tail = "\n".join(r.stdout.splitlines()[-25:])
    if r.returncode != 0:
        log("FAILED", r.returncode, "\n" + tail)
        raise SystemExit(1)
    return r.stdout


def setup():
    t = time.time()
    os.makedirs("/kaggle/tmp", exist_ok=True)
    if not os.path.isdir(SRC):
        sh(f"git clone --depth 1 https://github.com/Tencent/Hunyuan3D-2 {SRC}")
    # the Kaggle image already has torch/torchvision; install the rest without touching torch
    reqs = [l.strip() for l in open(f"{SRC}/requirements.txt") if l.strip() and not l.startswith("#")]
    reqs = [r for r in reqs if not r.lower().startswith(("torch", "torchvision", "gradio", "fastapi", "uvicorn"))]
    sh("pip install -q " + " ".join(f"'{r}'" for r in reqs))
    sh("pip install -q .", cwd=SRC)
    sh("pip install -q --no-build-isolation .", cwd=f"{SRC}/hy3dgen/texgen/custom_rasterizer")
    sh("bash compile_mesh_painter.sh", cwd=f"{SRC}/hy3dgen/texgen/differentiable_renderer")
    sys.path.insert(0, SRC)
    log("setup done in %.0fs" % (time.time() - t))


def find_image(fname):
    hits = glob.glob(f"/kaggle/input/**/{fname}", recursive=True)
    if not hits:
        raise FileNotFoundError(fname)
    return hits[0]


def main():
    import torch
    log("GPUs:", [torch.cuda.get_device_name(i) for i in range(torch.cuda.device_count())])
    setup()
    from PIL import Image
    from hy3dgen.rembg import BackgroundRemover
    from hy3dgen.shapegen import (DegenerateFaceRemover, FaceReducer, FloaterRemover,
                                  Hunyuan3DDiTFlowMatchingPipeline)
    from hy3dgen.texgen import Hunyuan3DPaintPipeline

    rembg = BackgroundRemover()
    images = {}
    for job in JOBS:
        img = Image.open(find_image(job["image"])).convert("RGBA")
        images[job["name"]] = rembg(img.convert("RGB"))

    # ---- stage 1: shapes (then free the GPU for texturing)
    t = time.time()
    shape = Hunyuan3DDiTFlowMatchingPipeline.from_pretrained("tencent/Hunyuan3D-2",
                                                             subfolder="hunyuan3d-dit-v2-0")
    meshes = {}
    for name, img in images.items():
        try:
            m = shape(image=img, num_inference_steps=STEPS, octree_resolution=OCTREE,
                      generator=torch.manual_seed(1234))[0]
            m = FloaterRemover()(m)
            m = DegenerateFaceRemover()(m)
            m = FaceReducer()(m, max_facenum=FACES)
            m.export(f"{WORK}/{name}_shape.glb")
            meshes[name] = m
            log("shape ok", name, len(m.faces), "faces")
        except Exception:
            log("shape FAILED", name, traceback.format_exc()[-1500:])
    del shape
    gc.collect()
    torch.cuda.empty_cache()
    log("shapes done in %.0fs" % (time.time() - t))

    # ---- stage 2: textures
    t = time.time()
    paint = Hunyuan3DPaintPipeline.from_pretrained("tencent/Hunyuan3D-2")
    if hasattr(paint, "enable_model_cpu_offload"):
        paint.enable_model_cpu_offload()
        log("paint: cpu offload on")
    for name, m in meshes.items():
        try:
            tm = paint(m, image=images[name])
            tm.export(f"{WORK}/{name}.glb")
            log("texture ok", name)
        except Exception:
            log("texture FAILED", name, traceback.format_exc()[-1500:])
        torch.cuda.empty_cache()
    log("textures done in %.0fs" % (time.time() - t))
    log("outputs:", sorted(os.listdir(WORK)))


if __name__ == "__main__":
    main()

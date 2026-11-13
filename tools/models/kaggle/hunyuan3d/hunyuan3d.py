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
#   multi-view: {"name": "kael", "image": "front.png", "views": {"front": f, "back": f, "left": f, "right": f}}
#   "faces": per-job face budget (default FACES), e.g. 20000 for weapons
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
    if "versions:" in r.stdout:
        log(r.stdout.strip().splitlines()[-1])
    if r.returncode != 0:
        log("FAILED", r.returncode, "\n" + tail)
        raise SystemExit(1)
    return r.stdout


MISSING = ["rembg", "onnxruntime", "xatlas", "trimesh", "pymeshlab", "einops", "omegaconf", "pygltflib",
           "accelerate", "diffusers", "pybind11", "ninja"]


def setup():
    """Install only what Kaggle's image lacks, pinned to its existing versions
    (a blanket requirements.txt install breaks Kaggle's numpy/OpenCV)."""
    import importlib
    import importlib.util
    t = time.time()
    os.makedirs("/kaggle/tmp", exist_ok=True)
    # big model downloads stay out of /kaggle/working (everything there becomes job output)
    os.environ["HF_HOME"] = "/kaggle/tmp/hf"
    os.environ["HY3DGEN_MODELS"] = "/kaggle/tmp/hf"
    if not os.path.isdir(SRC):
        sh(f"git clone --depth 1 https://github.com/Tencent/Hunyuan3D-2 {SRC}")
    # pin only the core packages a careless install would break (pinning everything leaves
    # no installable rembg); everything else resolves freely
    # pin to the version each module actually imports as (Kaggle's image has stray duplicate
    # dist-infos, e.g. two numpys, which make metadata-based pins contradict each other)
    core = {"numpy": "numpy", "torch": "torch", "torchvision": "torchvision", "torchaudio": "torchaudio",
            "scipy": "scipy", "pillow": "PIL"}
    pins = []
    for dist, mod in core.items():
        try:
            pins.append(f"{dist}=={importlib.import_module(mod).__version__}")
        except Exception:
            pass
    open("/kaggle/tmp/constraints.txt", "w").write("\n".join(pins))
    log("pinned:", ", ".join(pins))
    need = [p for p in MISSING if importlib.util.find_spec(p.replace("-", "_")) is None]
    for p in need:  # one at a time, so one bad package names itself
        sh(f"pip install -q -c /kaggle/tmp/constraints.txt {p}")
    # Hunyuan3D-2's checkpoints use the transformers 4.x DINOv2 weight names
    # (5.x renamed attention.query/key/value to q_proj/k_proj/v_proj)
    # ...and a diffusers/huggingface_hub of the same generation, resolved together
    sh("pip install -q -c /kaggle/tmp/constraints.txt 'transformers>=4.48,<5' 'diffusers>=0.32,<0.36' "
       "'huggingface_hub>=0.30,<1.0'")
    sh("python3 -c \"import transformers, diffusers, huggingface_hub as h; "
       "print('versions: transformers', transformers.__version__, 'diffusers', diffusers.__version__, 'hub', h.__version__)\"")
    sh("pip install -q --no-deps -e .", cwd=SRC)
    sh("python3 setup.py install", cwd=f"{SRC}/hy3dgen/texgen/custom_rasterizer")
    sh("python3 setup.py install", cwd=f"{SRC}/hy3dgen/texgen/differentiable_renderer")
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
    images = {}   # name -> front image (also the texture reference)
    mviews = {}   # name -> {view: image} for multi-view jobs
    for job in JOBS:
        img = Image.open(find_image(job["image"])).convert("RGB")
        images[job["name"]] = rembg(img)
        if job.get("views"):
            mviews[job["name"]] = {v: rembg(Image.open(find_image(f)).convert("RGB"))
                                   for v, f in job["views"].items()}

    # ---- stage 1: shapes (then free the GPU for texturing)
    t = time.time()
    meshes = {}

    def post(name, m, job):
        m = FloaterRemover()(m)
        m = DegenerateFaceRemover()(m)
        m = FaceReducer()(m, max_facenum=job.get("faces", FACES))
        m.export(f"{WORK}/{name}_shape.glb")
        meshes[name] = m
        log("shape ok", name, len(m.faces), "faces", "(multi-view)" if name in mviews else "")

    groups = [("tencent/Hunyuan3D-2mv", "hunyuan3d-dit-v2-mv", [j for j in JOBS if j["name"] in mviews]),
              ("tencent/Hunyuan3D-2", "hunyuan3d-dit-v2-0", [j for j in JOBS if j["name"] not in mviews])]
    for repo, sub, jobs in groups:
        if not jobs:
            continue
        shape = Hunyuan3DDiTFlowMatchingPipeline.from_pretrained(repo, subfolder=sub)
        for job in jobs:
            name = job["name"]
            try:
                inp = mviews.get(name) or images[name]
                m = shape(image=inp, num_inference_steps=STEPS, octree_resolution=OCTREE,
                          generator=torch.manual_seed(1234))[0]
                post(name, m, job)
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

# Kaggle GPU job: images with FLUX.2 [klein] 4B (Apache-2.0, not gated).
# Text-to-image, or reference-image editing when a job lists "refs" (files in the attached
# private dataset). Pushed and run by tools/models/kaggle_run.py, which fills in JOBS below.
# Outputs: /kaggle/working/<out>_k<i>.png, log lines prefixed "CENTROID".
import glob
import os
import random
import subprocess
import time
import traceback

# filled in by kaggle_run.py: [{"out": "kael_front", "prompt": "...", "refs": ["kael_1.png"],
#                               "w": 832, "h": 1216, "n": 2}, ...]
JOBS = []
STEPS = 4
REPO = "black-forest-labs/FLUX.2-klein-4B"
WORK = "/kaggle/working"


def log(*a):
    print("CENTROID", *a, flush=True)


def load(dtype):
    from diffusers import Flux2KleinPipeline
    pipe = Flux2KleinPipeline.from_pretrained(REPO, torch_dtype=dtype)
    pipe.enable_model_cpu_offload()
    return pipe


def find(fname):
    hits = glob.glob(f"/kaggle/input/**/{fname}", recursive=True)
    if not hits:
        raise FileNotFoundError(fname)
    return hits[0]


def render(pipe, job, seed):
    import torch
    from PIL import Image
    refs = [Image.open(find(r)).convert("RGB") for r in job.get("refs", [])]
    kw = dict(prompt=job["prompt"], width=job.get("w", 832), height=job.get("h", 1216),
              num_inference_steps=STEPS, guidance_scale=1.0,
              generator=torch.Generator("cpu").manual_seed(seed))
    if refs:
        kw["image"] = refs if len(refs) > 1 else refs[0]
    return pipe(**kw).images[0]


def main():
    t = time.time()
    os.environ["HF_HOME"] = "/kaggle/tmp/hf"  # keep model downloads out of the job output
    subprocess.run("pip install -q -U diffusers transformers accelerate", shell=True, check=True)
    import numpy as np
    import torch
    log("GPUs:", [torch.cuda.get_device_name(i) for i in range(torch.cuda.device_count())])
    for j in JOBS:  # backwards compatible: {"name": ...} means out = name
        j.setdefault("out", j.get("name", "img"))

    dtype = torch.bfloat16
    pipe = load(dtype)
    # T4s have no native bf16: if the first image comes out blank, switch to fp16
    if JOBS and np.asarray(render(pipe, dict(JOBS[0], refs=[]), 1)).std() < 2:
        log("bf16 gave a blank image, reloading in fp16")
        del pipe
        torch.cuda.empty_cache()
        dtype = torch.float16
        pipe = load(dtype)
    log("ready (%s) in %.0fs" % (dtype, time.time() - t))

    for job in JOBS:
        for i in range(job.get("n", 2)):
            seed = random.randint(1, 2_000_000_000)
            try:
                t1 = time.time()
                img = render(pipe, job, seed)
                if np.asarray(img).std() < 2:
                    log("blank image", job["out"], i + 1)
                    continue
                img.save(f"{WORK}/{job['out']}_k{i + 1}.png")
                log("image ok", job["out"], i + 1, "seed", seed, "%.0fs" % (time.time() - t1))
            except Exception:
                log("image FAILED", job["out"], traceback.format_exc()[-1500:])
    log("outputs:", sorted(os.listdir(WORK)))


if __name__ == "__main__":
    main()

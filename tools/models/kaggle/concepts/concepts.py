# Kaggle GPU job: character concept images with FLUX.2 [klein] 4B (Apache-2.0, not gated).
# (FLUX.1-schnell is now gated on Hugging Face, so it can't be downloaded anonymously here.)
# Pushed and run by tools/models/kaggle_run.py, which fills in JOBS below.
# Outputs: /kaggle/working/<name>_k<i>.png, log lines prefixed "CENTROID".
import os
import random
import subprocess
import time
import traceback

JOBS = []  # filled in by kaggle_run.py: [{"name": "darin", "prompt": "...", "n": 2}, ...]
WIDTH, HEIGHT, STEPS = 832, 1216, 4
REPO = "black-forest-labs/FLUX.2-klein-4B"
WORK = "/kaggle/working"


def log(*a):
    print("CENTROID", *a, flush=True)


def load(dtype):
    import torch  # noqa: F401
    from diffusers import Flux2KleinPipeline
    pipe = Flux2KleinPipeline.from_pretrained(REPO, torch_dtype=dtype)
    pipe.enable_model_cpu_offload()
    return pipe


def render(pipe, prompt, seed):
    import torch
    return pipe(prompt=prompt, width=WIDTH, height=HEIGHT, num_inference_steps=STEPS, guidance_scale=1.0,
                generator=torch.Generator("cpu").manual_seed(seed)).images[0]


def main():
    t = time.time()
    os.environ["HF_HOME"] = "/kaggle/tmp/hf"  # keep model downloads out of the job output
    subprocess.run("pip install -q -U diffusers transformers accelerate", shell=True, check=True)
    import numpy as np
    import torch
    log("GPUs:", [torch.cuda.get_device_name(i) for i in range(torch.cuda.device_count())])

    dtype = torch.bfloat16
    pipe = load(dtype)
    # T4s have no native bf16: if the first image comes out blank, switch to fp16
    probe = render(pipe, JOBS[0]["prompt"], 1) if JOBS else None
    if probe is not None and np.asarray(probe).std() < 2:
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
                img = render(pipe, job["prompt"], seed)
                if np.asarray(img).std() < 2:
                    log("blank image", job["name"], i + 1)
                    continue
                img.save(f"{WORK}/{job['name']}_k{i + 1}.png")
                log("concept ok", job["name"], i + 1, "seed", seed, "%.0fs" % (time.time() - t1))
            except Exception:
                log("concept FAILED", job["name"], traceback.format_exc()[-1500:])
    log("outputs:", sorted(os.listdir(WORK)))


if __name__ == "__main__":
    main()

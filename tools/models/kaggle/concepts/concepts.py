# Kaggle GPU job: character concept images with FLUX.1-schnell (Apache-2.0).
# Pushed and run by tools/models/kaggle_run.py, which fills in JOBS below.
# 4-bit quantized so the 12B model fits a 16 GB T4 and Kaggle's ~29 GB RAM.
# Outputs: /kaggle/working/<name>_k<i>.png, log lines prefixed "CENTROID".
import os
import random
import subprocess
import time
import traceback

JOBS = []  # filled in by kaggle_run.py: [{"name": "darin", "prompt": "...", "n": 2}, ...]
WIDTH, HEIGHT, STEPS = 832, 1216, 4
WORK = "/kaggle/working"


def log(*a):
    print("CENTROID", *a, flush=True)


def main():
    t = time.time()
    subprocess.run("pip install -q -U diffusers transformers accelerate bitsandbytes sentencepiece protobuf",
                   shell=True, check=True)
    import numpy as np
    import torch
    from diffusers import BitsAndBytesConfig as DBnb
    from diffusers import FluxPipeline, FluxTransformer2DModel
    from transformers import BitsAndBytesConfig as TBnb
    from transformers import T5EncoderModel

    repo = "black-forest-labs/FLUX.1-schnell"
    dtype = torch.bfloat16
    q_d = DBnb(load_in_4bit=True, bnb_4bit_quant_type="nf4", bnb_4bit_compute_dtype=dtype)
    q_t = TBnb(load_in_4bit=True, bnb_4bit_quant_type="nf4", bnb_4bit_compute_dtype=dtype)
    transformer = FluxTransformer2DModel.from_pretrained(repo, subfolder="transformer",
                                                         quantization_config=q_d, torch_dtype=dtype)
    t5 = T5EncoderModel.from_pretrained(repo, subfolder="text_encoder_2", quantization_config=q_t, torch_dtype=dtype)
    pipe = FluxPipeline.from_pretrained(repo, transformer=transformer, text_encoder_2=t5, torch_dtype=dtype)
    pipe.enable_model_cpu_offload()
    log("loaded in %.0fs" % (time.time() - t))

    for job in JOBS:
        for i in range(job.get("n", 2)):
            seed = random.randint(1, 2_000_000_000)
            try:
                t1 = time.time()
                img = pipe(job["prompt"], width=WIDTH, height=HEIGHT, num_inference_steps=STEPS,
                           guidance_scale=0.0, max_sequence_length=256,
                           generator=torch.Generator("cpu").manual_seed(seed)).images[0]
                if np.asarray(img).std() < 2:  # black / NaN image
                    log("blank image", job["name"], i + 1)
                    continue
                path = f"{WORK}/{job['name']}_k{i + 1}.png"
                img.save(path)
                log("concept ok", job["name"], i + 1, "seed", seed, "%.0fs" % (time.time() - t1))
            except Exception:
                log("concept FAILED", job["name"], traceback.format_exc()[-1500:])
    log("outputs:", sorted(os.listdir(WORK)))


if __name__ == "__main__":
    main()

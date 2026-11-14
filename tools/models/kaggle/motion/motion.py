"""Kaggle job: text-to-motion with Tencent HY-Motion 1.0 (Tencent Hunyuan Community License).

JOBS is filled in by kaggle_run.py: [{"name": "kael_light_1", "prompt": "...", "seconds": 1.8, "n": 3}, ...]
Writes <name>_k<i>.npz per candidate: rot6d (T,22,6) local joint rotations, transl (T,3), fps,
plus skeleton.npz once (rest joint positions, parents, joint names) for building the clips.

Fits a 16 GB T4: the Qwen3-8B text encoder is the 4-bit pre-quantized build, everything on GPU 0.
"""
import glob
import json
import os
import subprocess
import sys
import time
import traceback

JOBS = []
WORK = "/kaggle/working"
REPO = "/kaggle/tmp/hymo"


def log(*a):
    print("CENTROID", *a, flush=True)


def sh(cmd):
    log("$", cmd)
    subprocess.run(cmd, shell=True, check=True)


def main():
    t0 = time.time()
    os.makedirs("/kaggle/tmp", exist_ok=True)
    os.environ["HF_HOME"] = "/kaggle/tmp/hf"
    os.environ["USE_HF_MODELS"] = "1"   # text encoders straight from Hugging Face
    if not os.path.isdir(REPO):
        sh("apt-get -qq install -y git-lfs >/dev/null 2>&1 || true")
        sh(f"git clone -q --depth 1 https://github.com/Tencent-Hunyuan/HY-Motion-1.0.git {REPO}")
        sh(f"cd {REPO} && git lfs install && git lfs pull --include 'scripts/gradio/static/assets/dump_wooden/*'")
    sh("pip install -q torchdiffeq==0.2.5 einops omegaconf transforms3d bitsandbytes 'transformers==4.53.3' "
       "'accelerate>=0.30' 'diffusers==0.26.3' 'huggingface_hub>=0.30,<0.35' safetensors")
    # 4-bit Qwen3-8B (same weights, quantized) so the text encoder fits next to the motion model
    tp = f"{REPO}/hymotion/network/text_encoders/text_encoder.py"
    src = open(tp).read()
    src = src.replace('QWEN_PATH = "Qwen/Qwen3-8B"', 'QWEN_PATH = "unsloth/Qwen3-8B-bnb-4bit"')
    src = src.replace("torch_dtype=torch.bfloat16,", "torch_dtype=torch.float16, device_map={'': 0},")
    open(tp, "w").write(src)
    sys.path.insert(0, REPO)
    os.chdir(REPO)
    import numpy as np
    import torch
    import yaml
    from huggingface_hub import snapshot_download
    snapshot_download("tencent/HY-Motion-1.0", allow_patterns=["HY-Motion-1.0/*"], local_dir=f"{REPO}/ckpts/tencent")
    from hymotion.utils.loaders import load_object
    cfg_path = f"{REPO}/ckpts/tencent/HY-Motion-1.0/config.yml"
    cfg = yaml.load(open(cfg_path), Loader=yaml.FullLoader)
    pipe = load_object(cfg["train_pipeline"], cfg["train_pipeline_args"],
                       network_module=cfg["network_module"], network_module_args=cfg["network_module_args"])
    pipe.load_in_demo(f"{REPO}/ckpts/tencent/HY-Motion-1.0/latest.ckpt", build_text_encoder=False)
    pipe.to(torch.device("cuda:0"))
    from hymotion.network.text_encoders.text_encoder import HYTextModel
    te = load_object(pipe._text_encoder_module, pipe._text_encoder_cfg)
    if getattr(te, "sentence_emb_text_encoder", None) is not None:
        te.sentence_emb_text_encoder.to("cuda:0")
    enc = te.encode

    def encode32(*a, **k):   # the motion model runs in fp32; the 4-bit LLM hands back fp16
        out = enc(*a, **k)
        return tuple(o.float() if torch.is_tensor(o) and o.is_floating_point() else o for o in out)
    te.encode = encode32
    te.to = lambda *a, **k: te   # already placed; .to() on a 4-bit model is not allowed
    pipe.text_encoder = te
    log("ready in %.0fs, GPU mem %.1f GB" % (time.time() - t0, torch.cuda.memory_allocated() / 1e9))
    bm = pipe.body_model
    np.savez(f"{WORK}/skeleton.npz", parents=bm.parents.cpu().numpy(),
             joints=(bm.j_template if hasattr(bm, "j_template") else bm.joints).cpu().numpy(),
             names=np.array(getattr(bm, "joint_names", []) or []))
    for j in JOBS:
        for i in range(j.get("n", 3)):
            seed = 1000 + i * 7919 + abs(hash(j["name"])) % 997
            try:
                t1 = time.time()
                with torch.no_grad():
                    out = pipe.generate(j["prompt"], [seed], j.get("seconds", 2.0), cfg_scale=j.get("cfg", 5.0))
                np.savez(f"{WORK}/{j['name']}_k{i + 1}.npz", rot6d=out["rot6d"][0].float().cpu().numpy(),
                         transl=out["transl"][0].float().cpu().numpy(), fps=30, prompt=j["prompt"])
                log("motion ok", j["name"], i + 1, "%.0fs" % (time.time() - t1))
            except Exception:
                log("motion FAILED", j["name"], traceback.format_exc()[-1500:].replace("\n", " | "))
                torch.cuda.empty_cache()
    log("outputs:", sorted(os.listdir(WORK)))


main()

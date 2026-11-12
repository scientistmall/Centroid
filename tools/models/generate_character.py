#!/usr/bin/env python3
"""Generate character concept art and textured 3D models with free Hugging Face Spaces.

  concept : text -> image   (black-forest-labs/FLUX.1-schnell, Apache-2.0)
  model   : image -> textured 3D GLB  (tencent/Hunyuan3D-2, Tencent Hunyuan Community License)

Usage:
  python3 tools/models/generate_character.py concept kael --n 3
  python3 tools/models/generate_character.py model kael assets/characters/kael/concepts/kael_2.png
  python3 tools/models/generate_character.py weapon kael            # concept + model of the weapon

Outputs go to assets/characters/<name>/{concepts,raw}/. Prompts live in PROMPTS below
(written from the design sheets in docs/3D_PIPELINE.md, Part 0).
Needs: pip install gradio_client ; network access to huggingface.co and the Space hosts.
"""
import argparse
import os
import shutil
import sys

from gradio_client import Client, handle_file

STYLE = ("full body character concept art, front view, standing in A-pose with arms angled down "
         "and clearly apart from the body, hands open and empty, feet visible, plain light grey "
         "background, even studio lighting, no shadows, stylized realistic game character, "
         "detailed costume, sharp focus, single character, centered")

PROMPTS = {
    "kael": ("young man 19 years old, lean athletic slim build, spiky dark navy-black hair swept backward, "
             "light blue eyes, serious determined face, short fitted dark navy jacket with high collar and thin "
             "glowing light-blue trim, split coat tails to mid-thigh, long pale blue-white scarf wrapped around the "
             "neck with one end hanging behind, light-blue belt, black fitted trousers, leather bracers with thin blue "
             "bands, slim black armored boots"),
    "rhex": ("young adult man about 25, very broad heavily muscled build, square jaw, dark red spiky mohawk crest "
             "with shaved sides, scar across the left cheek, red eyes, arrogant half smirk, sleeveless near-black "
             "leather battle armor vest with red V-neck trim, three overlapping riveted steel shoulder plates on the "
             "left shoulder only with red edges, bare muscular upper arms, grey-brown cloth wraps on both forearms, "
             "wide red belt, heavy dark trousers, chunky black strapped boots"),
}

WEAPONS = {
    "kael": ("a single slightly curved single-edged sword, dark steel blade with a faint glowing blue edge, "
             "round guard, wrapped grip, isolated game asset, side view, plain light grey background"),
    "rhex": ("a large single-bladed battle axe, blackened steel head with glowing red cutting edge and a short back "
             "spike, long dark wooden handle wrapped near the bottom, isolated game asset, side view, plain light grey background"),
}

# The Hugging Face token is injected by the network proxy into this header (never stored here).
HDR = {"x-hf-authorization": "Bearer proxy-injected"}

ROOT = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "characters")


def _dir(name: str, sub: str) -> str:
    d = os.path.abspath(os.path.join(ROOT, name, sub))
    os.makedirs(d, exist_ok=True)
    return d


def concept(name: str, n: int, prompt: str = "", tag: str = "", width=832, height=1216) -> list:
    flux = Client("black-forest-labs/FLUX.1-schnell", verbose=False, headers=HDR)
    text = prompt or (PROMPTS[name] + ", " + STYLE)
    out = []
    for i in range(n):
        res, seed = flux.predict(text, 0, True, width, height, 4, api_name="/infer")
        path = res["path"] if isinstance(res, dict) else res
        dst = os.path.join(_dir(name, "concepts"), f"{name}{tag}_{i + 1}.png" if not path.endswith(".webp") else f"{name}{tag}_{i + 1}.webp")
        shutil.copy(path, dst)
        print("concept:", dst, "seed", int(seed))
        out.append(dst)
    return out


def model(name: str, image: str, out_name: str = "", steps: int = 30, octree: int = 256) -> str:
    hy = Client("tencent/Hunyuan3D-2", verbose=False, headers=HDR)
    res = hy.predict(None, handle_file(image), None, None, None, None, steps, 5.0, 1234, octree, True, 8000, True,
                     api_name="/generation_all")
    white, textured, _html, stats, seed = res
    src = textured or white
    dst = os.path.join(_dir(name, "raw"), (out_name or name) + os.path.splitext(src)[1])
    shutil.copy(src, dst)
    print("model:", dst, "| stats:", stats, "| seed", seed)
    return dst


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("cmd", choices=["concept", "model", "weapon"])
    ap.add_argument("name")
    ap.add_argument("image", nargs="?")
    ap.add_argument("--n", type=int, default=3)
    a = ap.parse_args()
    if a.cmd == "concept":
        concept(a.name, a.n)
    elif a.cmd == "model":
        if not a.image:
            sys.exit("model needs an image path")
        model(a.name, a.image)
    else:
        imgs = concept(a.name, 1, prompt=WEAPONS[a.name], tag="_weapon", width=1024, height=1024)
        model(a.name, imgs[0], out_name=a.name + "_weapon")


if __name__ == "__main__":
    main()

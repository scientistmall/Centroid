#!/usr/bin/env python3
"""Generate character concept art and textured 3D models with free Hugging Face Spaces.

  concept : text -> image   (black-forest-labs/FLUX.1-schnell, Apache-2.0)
  model   : image -> textured 3D GLB  (tencent/Hunyuan3D-2.1, Tencent Hunyuan Community License)

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
    "rhex": ("tall young adult man about 25, 188 cm, heroic proportions with long legs, broad shoulders and "
             "a muscular athletic build, square jaw, clean shaven, dark red spiky mohawk crest "
             "with shaved sides, scar across the left cheek, red eyes, arrogant half smirk, sleeveless near-black "
             "leather battle armor vest with red V-neck trim, one asymmetric pauldron of three overlapping riveted steel plates "
             "with red edges on his left shoulder only, right shoulder bare, bare muscular upper arms, grey-brown cloth wraps on both forearms, "
             "wide red belt, heavy dark trousers, chunky black strapped boots"),
    # ---- Guardians ----
    "mira": ("young woman 18 years old, slender and graceful, long straight dark violet hair falling to her waist "
             "with a small silver crescent-moon hair clip, soft pink eyes, gentle but brave expression, fitted "
             "dark navy and white combat coat-dress with glowing soft pink trim and a crescent moon emblem on the chest, "
             "long white ribbon sash at the waist, fingerless navy gloves, white leggings, knee-high navy boots"),
    "tala": ("woman about 30, tall athletic warrior, dark brown skin, black hair tied in a high ponytail wrapped with "
             "jade-green cloth, calm focused amber eyes, sleeveless wrap tunic in forest green and cream with glowing "
             "mint-green trim, a light flowing green scarf, leather shoulder guard on one side, jade-beaded bracers, "
             "loose cream trousers tucked into wrapped shin guards, sturdy sandal-boots"),
    "darin": ("man about 28, very big and strong, broad shoulders and thick arms, warm brown skin, shaved head, short "
              "dark beard, kind steady eyes, sleeveless earth-brown armored vest with grey stone-like plates and amber "
              "trim, massive stone-plated gauntlets covering both hands and forearms, wide leather belt, dark brown "
              "trousers, heavy armored boots"),
    "iren": ("young man 20 years old, slim agile build, messy orange-brown hair, freckles, cheerful confident grin, "
             "short light-grey hooded jacket with orange trim and rolled sleeves, orange scarf pulled down around the "
             "neck, fingerless gloves, empty dagger sheaths strapped to both thighs, fitted dark trousers with leg "
             "wraps, light running boots"),
    "lyra": ("young woman 20 years old, slim elegant archer, long silver-white hair in a loose half-up style, pale "
             "ice-blue eyes, serene thoughtful expression, white and ice-blue fitted archer outfit with glowing "
             "sound-wave pattern trim, a leather arm guard on the left forearm, empty quiver strap across the chest, "
             "short cape on one shoulder, slim white trousers, light blue knee boots"),
    "oren": ("young man 22 years old, average build, short sandy-blond hair, brass goggles pushed up on the forehead, "
             "curious clever smile, inventor look, dark utility vest over a white shirt with glowing yellow trim, "
             "bulky mechanical resonance gloves with small tuning-fork coils glowing yellow on both hands, tool belt "
             "with pouches, olive cargo trousers, sturdy work boots"),
    # ---- Founders ----
    "auren": ("elderly man about 70, tall and dignified, long white hair and long white beard, wise kind eyes, "
              "flowing cream and gold robes with a golden sun emblem on the chest, gold trim, a deep blue inner robe, "
              "a worn leather journal hanging from the belt, simple sandals"),
    "seran": ("man about 50, upright military bearing, swept-back dark hair streaked with grey, neat short beard, "
              "sharp loyal eyes, long dark grey officer coat with sage-green trim and high collar, green sash, black "
              "gloves, dark trousers, polished tall boots"),
    # ---- Traitors ----
    "veyr": ("man about 45, tall lean and imposing master swordsman, long straight black hair with a single silver "
             "streak, pale skin, cold violet eyes, calm cruel expression, long high-collared violet-black coat "
             "embroidered with glowing purple constellation patterns, dark armored shoulder mantle, an empty sword "
             "scabbard at the left hip, black trousers, elegant black boots"),
    "thane": ("man about 25, tall and muscular, charismatic confident smirk, spiky dark navy-black hair longer than "
              "shoulder length swept back, dark blue eyes, black and deep purple armored long coat with torn split "
              "tails and glowing violet trim, two empty sword sheaths crossed on his back, black gloves, dark trousers, "
              "black armored boots"),
    "vaska": ("young woman about 22, slim and light, pale skin, misty grey eyes, a deep grey-blue hooded cloak "
              "with a ragged hem that looks like fading mist, a sheer veil covering the lower half of her face, fitted "
              "grey-blue leather outfit with silver trim, two empty short-blade sheaths on the lower back, wrapped "
              "forearms, soft grey boots"),
    "mael": ("man about 35, tall and heavily muscled, olive skin, short dark military haircut, stern ruthless face, "
             "black martial-artist armored gi with a heavy purple sash, iron knuckle plates over bandaged fists, iron "
             "bracers, purple trim, dark loose trousers, black wrapped boots"),
    "nyra": ("woman about 24, tall and elegant, long dark violet hair in one long braid over the shoulder, sharp "
             "beautiful cold face, venom-green eyes, black leather corset outfit with toxic-green trim and a snake "
             "motif, long black coat with tattered hem, a coiled whip hanging at the hip, black gloves, thigh-high "
             "black boots"),
    "zerin": ("young man 20 years old, lean athletic build, spiky golden-blond hair, tense proud expression, "
              "sleeveless black jacket with glowing yellow lightning trim, one armored left arm with a yellow-edged "
              "pauldron, storm-grey scarf, dark grey trousers, black boots with yellow straps"),
    "corvin": ("man about 35, tall and thin, pale skin, swept-back silver-blue hair, cold obsessive cyan eyes, "
               "scholar warrior, long dark teal coat with a crystal-shard pattern, glowing cyan crystal growths on the "
               "shoulders and forearms, high collar, black gloves, dark trousers, tall black boots"),
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
        path = _path(res)
        dst = os.path.join(_dir(name, "concepts"), f"{name}{tag}_{i + 1}.png" if not path.endswith(".webp") else f"{name}{tag}_{i + 1}.webp")
        shutil.copy(path, dst)
        print("concept:", dst, "seed", int(seed))
        out.append(dst)
    return out


def _path(f):
    """Gradio returns files either as a path or as a {"path"/"value": ...} dict."""
    if isinstance(f, dict):
        f = f.get("path") or f.get("value") or f.get("name")
        if isinstance(f, dict):
            return _path(f)
    return f


def concept_pollinations(name: str, n: int, prompt: str = "", tag: str = "", width=832, height=1216) -> list:
    """Same as concept(), via the free image.pollinations.ai FLUX service (no GPU quota, no token)."""
    import random
    import time
    import urllib.parse
    import urllib.request
    text = prompt or (PROMPTS[name] + ", " + STYLE)
    out = []
    for i in range(n):
        seed = random.randint(1, 2_000_000_000)
        url = ("https://image.pollinations.ai/prompt/" + urllib.parse.quote(text) + "?" +
               urllib.parse.urlencode({"width": width, "height": height, "model": "flux", "nologo": "true",
                                       "seed": seed}))
        dst = os.path.join(_dir(name, "concepts"), f"{name}{tag}_{i + 1}.png")
        for attempt in range(5):
            try:
                with urllib.request.urlopen(url, timeout=240) as r:
                    data = r.read()
                break
            except Exception as e:  # rate limit / busy: back off
                print("  retry", attempt + 1, e)
                time.sleep(15 * (attempt + 1))
        else:
            raise SystemExit("pollinations failed for " + name)
        from PIL import Image
        import io
        Image.open(io.BytesIO(data)).convert("RGB").save(dst)
        print("concept:", dst, "seed", seed)
        out.append(dst)
        time.sleep(6)
    return out


def model(name: str, image: str, out_name: str = "", steps: int = 30, octree: int = 256) -> str:
    # Hunyuan3D-2.1: shape + PBR texture. (The older tencent/Hunyuan3D-2 Space has texturing disabled.)
    hy = Client("tencent/Hunyuan3D-2.1", verbose=False, headers=HDR)
    res = hy.predict(handle_file(image), None, None, None, None, steps, 5.0, 1234, octree, True, 8000, False,
                     api_name="/generation_all")
    white, textured, _html, stats, seed = res
    src = _path(textured) or _path(white)
    dst = os.path.join(_dir(name, "raw"), (out_name or name) + os.path.splitext(src)[1])
    shutil.copy(src, dst)
    print("model:", dst, "| stats:", stats, "| seed", seed)
    return dst


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("cmd", choices=["concept", "model", "weapon", "all"])
    ap.add_argument("name", nargs="?", default="")
    ap.add_argument("image", nargs="?")
    ap.add_argument("--n", type=int, default=3)
    ap.add_argument("--backend", choices=["hf", "pollinations"], default="hf",
                    help="concept images: hf = FLUX Space (uses ZeroGPU quota), pollinations = free web service")
    a = ap.parse_args()
    global concept
    if a.backend == "pollinations":
        concept = concept_pollinations
    if a.cmd == "all":
        # one concept for every character that has none yet
        for name in PROMPTS:
            d = os.path.join(ROOT, name, "concepts")
            if os.path.isdir(d) and any(f.endswith((".png", ".webp")) for f in os.listdir(d)):
                continue
            concept(name, a.n)
        return
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

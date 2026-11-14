"""Mixamo from the command line (search, export, download), through the session's network proxy,
which adds the user's Mixamo login token to requests for www.mixamo.com.

    python3 tools/models/mixamo.py search "great sword" [--packs]
    python3 tools/models/mixamo.py download <product_id> <out.fbx> [--character <id>] [--inplace]

Clips are exported FBX, without skin, 30 fps, no keyframe reduction, on the standard Mixamo
character (Y Bot) unless --character is given, so every clip shares one skeleton.
"""
import argparse
import json
import sys
import time
import urllib.parse
import urllib.request

API = "https://www.mixamo.com/api/v1"
HEAD = {"X-Api-Key": "mixamo2", "X-Requested-With": "XMLHttpRequest",
        "Authorization": "Bearer proxy-injected",   # the proxy replaces this with the real token
        "Accept": "application/json", "Content-Type": "application/json"}


def call(method, path, body=None):
    req = urllib.request.Request(API + path if path.startswith("/") else path, method=method, headers=HEAD,
                                 data=json.dumps(body).encode() if body is not None else None)
    with urllib.request.urlopen(req, timeout=120) as r:
        return json.loads(r.read() or b"{}")


def search(query, kind="Motion,MotionPack", limit=96, page=1):
    q = urllib.parse.urlencode({"page": page, "limit": limit, "order": "", "type": kind, "query": query})
    return call("GET", f"/products?{q}")


def product(pid, character):
    return call("GET", f"/products/{pid}?similar=0&character_id={character}")


def ybot():
    for r in search("y bot", kind="Character")["results"]:
        if r["name"].lower() in ("y bot", "ybot"):
            return r["id"]
    raise SystemExit("Y Bot not found")


def export(pid, character, inplace=False, skin=False, mirror=False):
    p = product(pid, character)
    details = p["details"]
    gms = details.get("gms_hash") or {}
    params = ",".join(str(v[1]) for v in gms.get("params", []))
    entry = {"model-id": gms["model-id"], "mirror": mirror, "trim": gms.get("trim", [0, 100]),
             "overdrive": 0, "params": params, "arm-space": gms.get("arm-space", 0),
             "inplace": bool(inplace and gms.get("inplace") is not None) or bool(inplace)}
    body = {"character_id": character, "gms_hash": [entry],
            "preferences": {"format": "fbx7_2019", "skin": "true" if skin else "false", "fps": "30", "reducekf": "0"},
            "product_name": p["name"], "type": p.get("type", "Motion")}
    call("POST", "/animations/export", body)
    for _ in range(120):
        time.sleep(2)
        m = call("GET", f"/characters/{character}/monitor")
        if m.get("status") == "completed":
            return m["job_result"]
        if m.get("status") == "failed":
            raise RuntimeError(f"export failed: {m}")
    raise RuntimeError("export timed out")


def fetch(url, out):
    with urllib.request.urlopen(urllib.request.Request(url), timeout=300) as r, open(out, "wb") as f:
        f.write(r.read())


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("cmd", choices=["search", "download", "ybot"])
    ap.add_argument("args", nargs="*")
    ap.add_argument("--packs", action="store_true")
    ap.add_argument("--character", default="")
    ap.add_argument("--inplace", action="store_true")
    ap.add_argument("--skin", action="store_true")
    a = ap.parse_args()
    if a.cmd == "ybot":
        print(ybot())
    elif a.cmd == "search":
        res = search(" ".join(a.args), kind="MotionPack" if a.packs else "Motion,MotionPack")
        for r in res["results"]:
            print(r["id"], "|", r["type"], "|", r["name"], "|", r.get("description", "")[:70])
        print("total", res.get("pagination", {}).get("num_results"))
    else:
        pid, out = a.args
        url = export(pid, a.character or ybot(), a.inplace, a.skin)
        fetch(url, out)
        print("saved", out)


if __name__ == "__main__":
    main()


def bulk(query, out_dir, name_filter="", inplace_words=("walk", "run", "strafe")):
    """Download every motion matching `query` (and `name_filter`) as <out_dir>/<slug>__<id8>.fbx."""
    import os
    import re
    os.makedirs(out_dir, exist_ok=True)
    char = ybot()
    got = []
    for page in (1, 2):
        res = search(query, kind="Motion", page=page)
        for r in res["results"]:
            if name_filter and name_filter.lower() not in r["name"].lower():
                continue
            slug = re.sub(r"[^a-z0-9]+", "_", r["name"].lower()).strip("_")
            out = os.path.join(out_dir, f"{slug}__{r['id'][:8]}.fbx")
            if os.path.exists(out):
                got.append(out)
                continue
            inplace = any(w in r["name"].lower() for w in inplace_words)
            try:
                fetch(export(r["id"], char, inplace), out)
                got.append(out)
                print("saved", out, flush=True)
            except Exception as e:  # keep going; report the clip that failed
                print("FAILED", r["name"], r["id"], e, flush=True)
        if res.get("pagination", {}).get("num_pages", 1) <= page:
            break
    return got

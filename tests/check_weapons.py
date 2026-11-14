"""Weapon bible check (docs/WEAPONS.md): every approved weapon has its sheet and look line, every
3D weapon names its sheet, and the art pipeline's weapon owners match the fighters' data."""
import json
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools", "models"))
import art_prompts as ap  # noqa: E402

errors = []
w = json.load(open(os.path.join(ROOT, "assets", "weapons", "weapons.json")))
for wid, (owner, look, _prompt) in ap.WEAPON_SHEETS.items():
    sheet = os.path.join(ROOT, "assets", "weapons", "sheets", f"sheet_{wid}.png")
    if not os.path.exists(sheet):
        errors.append(f"{wid}: no approved sheet at {sheet}")
    if len(look) < 30:
        errors.append(f"{wid}: look line too short")
    e = w.get(wid)
    if not e:
        errors.append(f"{wid}: missing from weapons.json")
    elif e.get("owner") != owner or not e.get("sheet", "").endswith(f"sheet_{wid}.png"):
        errors.append(f"{wid}: weapons.json owner/sheet do not match the bible")
for wid, e in w.items():
    if e.get("file") and wid not in ap.WEAPON_SHEETS:
        errors.append(f"{wid}: 3D weapon with no approved design")
owners = [o for o, _l, _p in ap.WEAPON_SHEETS.values()]
for f in os.listdir(os.path.join(ROOT, "data", "fighters")):
    c = f[:-5]
    if c not in owners:
        errors.append(f"{c}: playable fighter without an approved weapon")
print("\n".join(errors) if errors else f"weapons OK ({len(ap.WEAPON_SHEETS)} approved)")
sys.exit(1 if errors else 0)

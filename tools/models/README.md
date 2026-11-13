# Model tools

How THE CENTROID's 3D characters are made. The user-facing guide is
`docs/3D_PIPELINE.md`.

| Step | Tool | Runs on |
|---|---|---|
| Concept art (2 candidates per character) | `kaggle_run.py concepts` → `kaggle/concepts/concepts.py` (FLUX.2 [klein] 4B) | Kaggle T4 |
| Textured 3D model | `kaggle_run.py model` → `kaggle/hunyuan3d/hunyuan3d.py` (Tencent Hunyuan3D-2) | Kaggle T4 |
| 4-view preview | `preview/` (standalone Godot project) | here (Xvfb) |
| Mixamo ZIP | `prepare_for_mixamo.py` | here |
| Overview sheet | `contact_sheet.py` | here |
| Design prompts | `generate_character.py` (`PROMPTS`, `STYLE`; also a slow Hugging Face fallback) | — |

```
# Kaggle access: the Kaggle CLI reads ~/.kaggle/kaggle.json (username + placeholder key);
# the network proxy supplies the real token for api.kaggle.com.
python3 tools/models/kaggle_run.py concepts --missing --n 2 --user scientistmall
python3 tools/models/kaggle_run.py model kael rhex --user scientistmall
#   -> assets/characters/<name>/raw/<name>.glb and <name>_shape.glb
godot --path tools/models/preview --rendering-method gl_compatibility -- <model.glb> <out.png>
python3 tools/models/prepare_for_mixamo.py assets/characters/kael/raw/kael.glb --name kael --height 1.78
#   -> assets/characters/kael/kael_mixamo.zip (+ kael_mixamo_report.json)
python3 tools/models/contact_sheet.py out.png [names] [--all]
```

## Notes
- **The picked concept** is `assets/characters/<name>/concepts/<name>_1.png`; the 3D job
  uses the first PNG in that folder.
- **Kept out of the APK:** `concepts/` and `raw/` contain a `.gdignore`.
- **Kaggle image quirks** (handled in `hunyuan3d.py`):
  - only missing packages are installed, pinned to the image's numpy, torch, scipy and
    Pillow;
  - transformers stays on 4.x, which Hunyuan3D-2's DINOv2 weights need;
  - the model cache lives in `/kaggle/tmp` so it isn't downloaded as job output.
- **Output downloads** come from `www.kaggleusercontent.com`, which must be allowed in
  the network.

## prepare_for_mixamo.py options
- `--tris 30000`: target triangle count.
- `--rotate 180`: turn the model to face +Z.
- `--out <dir>`: output folder.

Heights:
- Guardians: Kael 1.78, Tala 1.75, Mira 1.62, Darin 1.90, Iren 1.72, Lyra 1.66, Oren 1.74
- Founders: Auren 1.80, Seran 1.78
- Traitors: Rhex 1.88, Vaska 1.65, Mael 1.85, Nyra 1.72, Zerin 1.76, Corvin 1.83,
  Thane 1.86, Veyr 1.85

## Licences
- **Hunyuan3D-2:** Tencent Hunyuan Community License. It doesn't cover the EU, UK or
  South Korea, and products with over 1M monthly users need a separate licence from
  Tencent.
- **FLUX.2 [klein] 4B:** Apache-2.0.

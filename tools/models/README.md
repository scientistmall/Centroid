# Model tools

## prepare_for_mixamo.py
Turns an AI-generated character (e.g. a Tencent Hunyuan3D GLB) into a Mixamo-ready ZIP
(OBJ + MTL + texture). It:
- stands the model on the ground and centres it;
- scales it to the character's real height;
- reduces it to a phone-friendly triangle count, keeping the texture.

```
pip install trimesh pymeshlab pillow numpy
python3 tools/models/prepare_for_mixamo.py assets/characters/kael/raw/kael.glb --name kael --height 1.78
#   -> assets/characters/kael/kael_mixamo.zip  (+ kael_mixamo_report.json)
```

Options:
- `--tris 30000`: target triangle count.
- `--rotate 180`: turn the model to face +Z if it comes out backwards.
- `--out <dir>`: output folder.

Heights from the design sheets: Kael 1.78 m, Rhex 1.88 m.

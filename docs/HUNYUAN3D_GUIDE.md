# Making the fighters' 3D models with Tencent Hunyuan 3D

Hunyuan 3D is Tencent's web tool that turns pictures of a character into a textured 3D model.
It runs in the browser (Mac is fine) and gives a few free generations per account.
You make the models there; Claude puts them in the game: rig, animations, toon shading,
outlines, hair and coat movement, and the approved weapon in the hand.

## What to upload

Each pilot fighter has a ready pack in the repo (square, plain background, no weapon):

| Fighter | Folder |
|---|---|
| Kael | `assets/characters/kael/hunyuan_input/` |
| Rhex | `assets/characters/rhex/hunyuan_input/` |
| Mira | `assets/characters/mira/hunyuan_input/` |
| Tala | `assets/characters/tala/hunyuan_input/` |

- `<name>_front.png`, `<name>_back.png`: front and back.
- `<name>_left.png`: the side view where the character faces to the **right** of the picture.
  This is the "left" slot on tools that ask for left/right views.
- Tala also has `tala_right.png` (she faces to the left of the picture) for the "right" slot.

**Weapons are not in these pictures on purpose.** They are separate models so the hand can grip them.

## Steps (do Kael first)

The free generations are limited, so make **Kael** first. Claude tests him in the game and
shows you before you spend generations on the others.

1. Open Hunyuan 3D in your browser and sign in.
2. Choose **image to 3D**. If it offers **multi-view** (several pictures of one character),
   use it and give it the front, back and left (and right for Tala) images. If it only takes
   one picture, use `<name>_front.png`.
3. Pick the **highest quality** geometry setting it offers, and turn **textures** on (PBR if offered).
4. If it offers **rigging / auto skeleton** for a humanoid, turn it on.
5. Before you download, look at the model:
   - the face reads clearly (eyes, nose, mouth, not a blank mannequin face);
   - the hands have separate fingers;
   - the hair and coat tails are their own shapes, not melted into the body;
   - no weapon or extra object stuck to the body.
   If one of these is badly wrong, regenerate once before moving on.
6. Download as **FBX** if it is rigged, otherwise **GLB** (with textures).
7. Upload it to the repo as `assets/characters/<name>/<name>_hy.fbx` (or `.glb`)
   and tell Claude.

## If the model comes without a skeleton

Claude will say so after testing. Then:

1. Open mixamo.com (free Adobe account), **Upload Character**, choose the GLB/FBX.
2. Place the markers (chin, wrists, elbows, knees, groin), **Use Symmetry: on**,
   **Skeleton LOD: Standard (65)** so fingers get bones.
3. Download **FBX Binary, T-pose, without skin animation**, and upload it as
   `assets/characters/<name>/<name>_hy.fbx`.

## Weapons

The approved weapon designs (`docs/WEAPONS.md`) are made into 3D separately. Claude prepares
one clean side-view picture of each pilot weapon. If you have free generations left over,
you can turn those into models on Hunyuan 3D the same way (single image, highest quality)
and upload them as `assets/weapons/<id>_hy.glb`. Otherwise Claude makes them on Kaggle.

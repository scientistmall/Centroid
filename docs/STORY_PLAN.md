# THE CENTROID — Story Plan

Full script: Draft 1 (kept by the story team). This file tracks the **current
decisions** the game is built from.

## Rules
- Exactly **8 story fights**. Each one is a pre-fight scene → playable fight → post-fight scene.
- **Losing → Retry.** The story never advances on a loss, and no one dies from losing.
- Deaths (Darin, Iren, Lyra and the traitors) happen **only in post-victory scenes**.
- The green mineral is called **Asterite**. The stone is the **Centroid**.
- Victory flags: `fight01_completed` … `fight08_completed` (saved in `user://save.json`).

## Fight table (Draft 1 matchups — final)

| # | Day | Playable | Opponent | Outcome | Mode | Built |
|---|---|---|---|---|---|---|
| 1 | 4  | Kael | Rhex | Rhex dies | single | ✅ |
| 2 | 10 | Tala | Vaska | Vaska is spared | single | ✅ |
| 3 | 14 | Darin | Mael | Mael and Darin die | single | ✅ |
| 4 | 20 | Mira | Nyra | Nyra survives and withdraws | single | |
| 5 | 27 | Iren | Zerin | Both die | single | |
| 6 | 33 | Lyra | Corvin | Corvin and Lyra die | single | |
| 7 | 36 | Kael | Thane | Thane dies | single | |
| 8 | 37 | **Kael + Oren** | Veyr | Centroid destroyed; Veyr dies | **tag** | |

**Fight 8 is the only team fight.**
- It uses tag mode (`"mode": "tag"` in the fight file).
- You start as Kael and can SWAP to Oren. Each keeps his own health.
- You lose only if both fall.

### Veyr
- **Powers:** master swordsmanship and **Starfall**.
- **Losing the power:** when the Centroid shatters in the post-fight scene, he loses
  Starfall. The final blow happens in that scene.

## Ending — "The First Sunrise" (replaces Draft 1 Part III)
The game ends right after Veyr is defeated, on Day 37:
- sunlight breaks through;
- Tala, Oren, Mira and Kael remember Iren, Lyra and Darin;
- Mira says "We're here.";
- Kael lowers his sword, the four stand in the morning light, and **THE END**.

**No story scenes come after this.** The journal reading (E02) and the memorial
epilogue (E03) are removed.

**Auren's journal** gets one line in the sunrise scene, just after "We're here.":
> Mira takes Auren's journal from her bag and holds it against her chest.
> MIRA: "He trusted us to finish this. We did."

## Build status
- ✅ Prologue (Opening, P01–P06, Day 1): `data/story/prologue.story`
- ✅ Chapter 1: `ch01_pre.story`, `fight01.json`, `ch01_post.story`
- ✅ Chapter 2: `ch02_pre.story`, `fight02.json`, `ch02_post.story`
- ✅ Chapter 3: `ch03_pre.story`, `fight03.json`, `ch03_post.story`
- Chapters 4–8: next builds

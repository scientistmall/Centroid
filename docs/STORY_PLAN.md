# THE CENTROID — Story Plan

Full script: Draft 1 (kept by the story team). This file tracks the **current
decisions** the game is built from.

## Rules
- Exactly **8 story fights**. Each one is a pre-fight scene → playable fight → post-fight scene.
- **Losing → Retry.** The story never advances on a loss, and no one dies from losing.
- Deaths (Darin, Iren, Lyra and the traitors) happen **only in post-victory scenes**.
- The green mineral is called **Asterite**. The stone is the **Centroid**.
- Victory flags: `fight01_completed` … `fight08_completed` (saved in `user://save.json`).

## Fight table (revised)

| # | Day | Playable | Opponent | Outcome | Fight mode | Built |
|---|---|---|---|---|---|---|
| 1 | 4  | Kael | Rhex | Kael defeats and kills Rhex | single | ✅ |
| 2 | 10 | Tala | Vaska | Tala defeats Vaska (spared) | single | |
| 3 | 14 | Darin + Mira | Mael | Mael dies; Darin sacrifices himself | tag (2 vs 1) | |
| 4 | 20 | Oren | Nyra | Oren defeats Nyra | single | |
| 5 | 27 | Iren | Zerin | Both die in their final clash | single | |
| 6 | 33 | Lyra, then Kael | Corvin | Lyra mortally wounded; Kael defeats Corvin | relay | |
| 7 | 36 | Mira + Kael | Thane | Thane falls defending the altar | tag (2 vs 1) | |
| 8 | 37 | Kael, then Mira | Veyr | Centroid destroyed; Veyr loses his powers and is defeated | relay (2 phases) | |

### Script changes to make when writing those chapters
- **Fight 4** was *Mira vs. Nyra* in Draft 1. It is now **Oren vs. Nyra**. The sisters'
  scene still needs a home: Mira could arrive after the fight for the necklace and map
  scene, with Oren as the fighter.
- **Fight 6:** Lyra fights first. Her mortal wound happens in the transition, then Kael
  finishes Corvin.
- **Fight 7:** Mira and Kael fight Thane together. Thane "falls defending the altar".
  The brothers' final scene stays.
- **Fight 8:** Kael fights Veyr while the Centroid powers him. After the resonator
  breaks it, Mira fights the powerless Veyr.

## Ending (revised — replaces Part III)
The game ends with **"The First Sunrise"** right after Veyr is defeated, on Day 37:
- sunlight breaks through;
- Tala, Oren, Mira and Kael remember Iren, Lyra and Darin;
- Mira says "We're here.";
- Kael lowers his sword, the four stand in the morning light, and **THE END**.

**No story scenes come after this.** The journal reading (E02) and the memorial
epilogue with Vaska and Nyra (E03) are removed.

> Open question: Mira receives **Auren's sealed journal** in the prologue and promises
> to keep it "until we finish this". Without E02 this setup has no payoff. Options:
> (a) remove the journal from the prologue; (b) let Mira hold it in the final
> sunrise scene without reading it; (c) give it one line in the ending.

## Build status
- ✅ Prologue (Opening, P01–P06, Day 1): `data/story/prologue.story`
- ✅ Chapter 1: `ch01_pre.story`, `fight01.json`, `ch01_post.story`
- Chapters 2–8: next builds

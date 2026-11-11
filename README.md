# The Centroid

An original, story-driven 2D fighting game for Android, built with **Godot 4.7**.
Thirty-seven days of darkness, eight story fights, guardians against traitors.

**Current build:** Prologue + Chapter 1 (Kael vs. Rhex). It uses silhouette
placeholder art drawn in code.

## Project layout
```
autoload/            StoryManager (flags + save), SceneRouter (scene changes, input map)
data/story/*.story   Story scenes in a plain-text script format (easy to edit)
data/fighters/*.json Fighter stats, combos, powers
data/fights/*.json   Fight setup: who fights whom, arena, AI level, victory flag
data/characters.json Names, colours and portrait styles
scenes/              Main menu, story player, arena
scripts/story/       Story parser, story player, backdrops, portraits
scripts/fight/       Fighter, poses and drawing, projectiles, AI, arena
scripts/ui/          HUD, touch controls, menu
docs/                Story plan and power design
tests/               Headless smoke test and screenshot capture
```

## Writing story scenes
See the header of `scripts/story/story_parser.gd`. Example:
```
@card DAY 4 OF DARKNESS | The Abandoned Training Ground
@bg training_ground
> Kael enters carrying a small lantern.
RHEX: I thought you'd never come.
@next fight fight01
```

## Controls
- **Phone:** joystick on the left (push up to jump), and ATK / HVY / BLK / JMP plus two
  power buttons on the right.
- **Keyboard:** A/D move, W jump, J light, K heavy, L block, U power 1, I power 2.

## Build and test (cloud or Linux)
Run the headless smoke test (plays all story scenes and a full AI-vs-AI fight):
```
godot --headless --fixed-fps 60 --disable-vsync res://tests/smoke_test.tscn
```
Build a debug APK (needs the Android SDK and export templates):
```
godot --headless --export-debug "Android" build/centroid.apk
```

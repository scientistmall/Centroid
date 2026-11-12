#!/usr/bin/env python3
"""Composes and renders the soundtrack of The Centroid.

Each track is written as note data here, saved as MIDI, rendered with FluidSynth
using the FluidR3 General MIDI SoundFont (MIT licence), and — for battle tracks —
mixed with an electronic layer synthesized in numpy (kick, clap, hats, pulsing bass).

Usage:  python3 tools/audio/music.py [out_dir] [track ...]     (default: assets/music, all tracks)
Needs:  mido, numpy, scipy, fluidsynth, ffmpeg, /usr/share/sounds/sf2/FluidR3_GM.sf2
"""
import os
import subprocess
import sys
import tempfile

import mido
import numpy as np
from scipy.io import wavfile
from scipy.signal import butter, sosfilt

SR = 44100
SF2 = "/usr/share/sounds/sf2/FluidR3_GM.sf2"
TPB = 480  # ticks per beat

# General MIDI programs
STRINGS, SLOW_STRINGS, CHOIR, PIANO, TIMPANI, TAIKO = 48, 49, 52, 0, 47, 116
HORN, BRASS, CELLO, CONTRABASS, HARP, FLUTE, CELESTA, WARM_PAD = 60, 61, 42, 43, 46, 73, 8, 89

NOTE = {"C": 0, "C#": 1, "Db": 1, "D": 2, "D#": 3, "Eb": 3, "E": 4, "F": 5, "F#": 6, "Gb": 6,
        "G": 7, "G#": 8, "Ab": 8, "A": 9, "A#": 10, "Bb": 10, "B": 11}


def n(name: str) -> int:
    """'D4' -> MIDI number."""
    pitch, octave = name[:-1], int(name[-1])
    return 12 * (octave + 1) + NOTE[pitch]


def chord(root: str, quality: str = "m", octave: int = 3) -> list:
    r = n(f"{root}{octave}")
    iv = {"m": (0, 3, 7), "M": (0, 4, 7), "sus": (0, 5, 7), "m7": (0, 3, 7, 10)}[quality]
    return [r + i for i in iv]


class Song:
    def __init__(self, bpm: float):
        self.bpm = bpm
        self.tracks = {}  # channel -> list of (start_beat, dur_beats, note, vel)
        self.programs = {}

    def inst(self, ch: int, program: int):
        self.programs[ch] = program
        self.tracks.setdefault(ch, [])
        return ch

    def add(self, ch: int, beat: float, dur: float, notes, vel: int = 80):
        if isinstance(notes, int):
            notes = [notes]
        for nt in notes:
            self.tracks[ch].append((beat, dur, nt, vel))

    def save(self, path: str):
        mid = mido.MidiFile(ticks_per_beat=TPB)
        meta = mido.MidiTrack()
        meta.append(mido.MetaMessage("set_tempo", tempo=mido.bpm2tempo(self.bpm)))
        mid.tracks.append(meta)
        for ch, events in self.tracks.items():
            tr = mido.MidiTrack()
            if ch != 9:
                tr.append(mido.Message("program_change", channel=ch, program=self.programs[ch], time=0))
            tr.append(mido.Message("control_change", channel=ch, control=91, value=70, time=0))  # reverb
            msgs = []
            for beat, dur, nt, vel in events:
                on = int(beat * TPB)
                off = int((beat + dur) * TPB)
                msgs.append((on, 1, mido.Message("note_on", channel=ch, note=nt, velocity=vel)))
                msgs.append((off, 0, mido.Message("note_off", channel=ch, note=nt, velocity=0)))
            msgs.sort(key=lambda m: (m[0], m[1]))
            last = 0
            for t, _, m in msgs:
                m.time = t - last
                last = t
                tr.append(m)
            mid.tracks.append(tr)
        mid.save(path)

    def seconds(self, beats: float) -> float:
        return beats * 60.0 / self.bpm


# ------------------------------------------------------------------ compositions

def main_theme() -> Song:
    """Slow, mournful D minor theme: strings, choir, piano arpeggios, horn melody, timpani."""
    s = Song(72)
    st, ch, pn, hr, tp, cb = s.inst(0, SLOW_STRINGS), s.inst(1, CHOIR), s.inst(2, PIANO), s.inst(3, HORN), s.inst(4, TIMPANI), s.inst(5, CONTRABASS)
    prog = [("D", "m"), ("Bb", "M"), ("F", "M"), ("C", "M"), ("D", "m"), ("Bb", "M"), ("G", "m"), ("A", "M")] * 2
    melody = [  # (beat offset in bar, dur, note) per bar, second half only
        [(0, 2, "A4"), (2, 1, "D5"), (3, 1, "C5")], [(0, 3, "D5"), (3, 1, "F5")],
        [(0, 2, "E5"), (2, 2, "C5")], [(0, 4, "G4")],
        [(0, 2, "A4"), (2, 1, "F5"), (3, 1, "E5")], [(0, 3, "D5"), (3, 1, "C5")],
        [(0, 2, "Bb4"), (2, 2, "D5")], [(0, 4, "C#5")],
    ]
    for bar, (root, q) in enumerate(prog):
        b = bar * 4
        c = chord(root, q, 3)
        s.add(st, b, 4, c + [c[0] + 12], 62 if bar < 8 else 74)
        s.add(cb, b, 4, c[0] - 12, 70)
        # piano arpeggio in eighths
        arp = [c[0] + 12, c[1] + 12, c[2] + 12, c[1] + 24]
        for k in range(8):
            s.add(pn, b + k * 0.5, 0.6, arp[k % 4], 55 if bar < 8 else 48)
        if bar >= 8:
            s.add(ch, b, 4, [x + 12 for x in c], 58)
            for off, dur, note in melody[bar - 8]:
                s.add(hr, b + off, dur, n(note) - 12, 82)
        if bar in (7, 15):
            for k in range(8):
                s.add(tp, b + 2 + k * 0.25, 0.25, n("A2"), 50 + k * 8)
        if bar in (0, 8):
            s.add(tp, b, 1, n("D2"), 100)
    s.add(st, 64, 4, chord("D", "m", 3), 60)  # resolve into the loop point
    return s


def story_calm() -> Song:
    """Gentle A minor piece for dialogue: piano melody over soft strings and harp."""
    s = Song(66)
    pn, st, hp, fl = s.inst(0, PIANO), s.inst(1, STRINGS), s.inst(2, HARP), s.inst(3, FLUTE)
    prog = [("A", "m"), ("F", "M"), ("C", "M"), ("G", "M"), ("A", "m"), ("F", "M"), ("D", "m"), ("E", "M")] * 2
    mel = ["E5", "C5", "E5", "D5", "C5", "A4", "B4", "G#4", "A4", "C5", "E5", "G5", "F5", "D5", "B4", "E5"]
    for bar, (root, q) in enumerate(prog):
        b = bar * 4
        c = chord(root, q, 3)
        s.add(st, b, 4, c, 48)
        for k, nt in enumerate([c[0], c[1] + 12, c[2] + 12, c[1] + 24]):
            s.add(hp, b + k, 1.2, nt, 50)
        s.add(pn, b, 1.5, n(mel[bar]), 66)
        s.add(pn, b + 2, 1.0, n(mel[bar]) - 3 if bar % 2 else n(mel[bar]) + 2, 54)
        if bar >= 8 and bar % 2 == 0:
            s.add(fl, b, 4, n(mel[bar]), 50)
    return s


def battle_1() -> Song:
    """Hybrid battle theme (E minor, 140 bpm): string ostinato, brass stabs, taiko, timpani.
    The electronic drums and bass are added in post (see ELECTRO below)."""
    s = Song(140)
    st, br, tk, tp, cel, ch = s.inst(0, STRINGS), s.inst(1, BRASS), s.inst(2, TAIKO), s.inst(3, TIMPANI), s.inst(4, CELLO), s.inst(5, CHOIR)
    prog = [("E", "m"), ("C", "M"), ("D", "M"), ("B", "m")] * 8  # 32 bars
    for bar, (root, q) in enumerate(prog):
        b = bar * 4
        c = chord(root, q, 3)
        # sixteenth-note ostinato
        pat = [c[0] + 12, c[0] + 12, c[2] + 12, c[0] + 12, c[1] + 12, c[0] + 12, c[2] + 12, c[1] + 12]
        if bar >= 2:
            for k in range(16):
                s.add(st, b + k * 0.25, 0.22, pat[k % 8], 78 if k % 4 == 0 else 62)
        s.add(cel, b, 4, c[0] - 12, 85)
        # taiko: big hits on 1 and the "and" of 3
        if bar >= 4:
            s.add(tk, b, 0.5, n("C3"), 120)
            s.add(tk, b + 2.5, 0.5, n("C3"), 100)
            if bar % 4 == 3:
                for k in range(4):
                    s.add(tk, b + 3 + k * 0.25, 0.25, n("C3"), 90 + k * 8)
        # brass stabs and a heroic line in the second half
        if bar >= 8:
            s.add(br, b, 0.5, c, 96)
            s.add(br, b + 1.5, 0.5, c, 84)
        if bar >= 16:
            s.add(ch, b, 4, [x + 12 for x in c], 64)
        if bar >= 16 and bar % 2 == 0:
            line = {"E": ["B4", "E5"], "C": ["C5", "G4"], "D": ["D5", "F#5"], "B": ["B4", "D5"]}[root]
            s.add(br, b + 2, 1, n(line[0]), 100)
            s.add(br, b + 3, 1, n(line[1]), 104)
        if bar % 8 == 7:
            for k in range(8):
                s.add(tp, b + 2 + k * 0.25, 0.25, n("E2"), 60 + k * 7)
    return s


def victory() -> Song:
    s = Song(100)
    br, st, tp = s.inst(0, BRASS), s.inst(1, STRINGS), s.inst(2, TIMPANI)
    for k, (beat, dur, notes) in enumerate([(0, 0.5, ["D4", "F#4", "A4"]), (0.5, 0.5, ["D4", "F#4", "A4"]),
                                           (1, 1, ["E4", "G4", "B4"]), (2, 4, ["F#4", "A4", "D5"])]):
        s.add(br, beat, dur, [n(x) for x in notes], 105)
    s.add(st, 2, 4, [n("D3"), n("A3"), n("D4"), n("F#4")], 80)
    s.add(tp, 0, 0.5, n("D2"), 110)
    s.add(tp, 2, 1, n("A2"), 110)
    return s


def defeat() -> Song:
    s = Song(60)
    st, cb = s.inst(0, SLOW_STRINGS), s.inst(1, CONTRABASS)
    for k, nt in enumerate(["A4", "G4", "F4", "E4"]):
        s.add(st, k * 1.0, 1.0, [n(nt), n(nt) - 4], 70)
    s.add(cb, 0, 5, n("A1"), 80)
    return s


# ------------------------------------------------------------------ electronic layer

def _lp(x, f):
    return sosfilt(butter(2, f, btype="low", fs=SR, output="sos"), x)


def _hp(x, f):
    return sosfilt(butter(2, f, btype="high", fs=SR, output="sos"), x)


def electro_layer(song: Song, bars: int, roots: list, start_bar: int = 4) -> np.ndarray:
    """Kick, clap, sixteenth hats and a side-chained saw bass following `roots` (MIDI notes per bar)."""
    beat = 60.0 / song.bpm
    total = int(SR * beat * 4 * bars) + SR
    out = np.zeros(total)
    rng = np.random.default_rng(5)

    def put(sig, t):
        i = int(t * SR)
        j = min(total, i + len(sig))
        out[i:j] += sig[: j - i]

    tk = np.arange(int(SR * 0.35)) / SR
    kick = np.sin(2 * np.pi * (45 + 120 * np.exp(-tk * 30)) * tk) * np.exp(-tk * 9)
    tc = np.arange(int(SR * 0.2)) / SR
    clap = _hp(rng.uniform(-1, 1, len(tc)), 1200) * np.exp(-tc * 25)
    th = np.arange(int(SR * 0.05)) / SR
    hat = _hp(rng.uniform(-1, 1, len(th)), 7000) * np.exp(-th * 80)
    for bar in range(start_bar, bars):
        t0 = bar * 4 * beat
        for b in range(4):
            put(kick * 0.9, t0 + b * beat)
            if b in (1, 3):
                put(clap * 0.22, t0 + b * beat)
        for k in range(16):
            put(hat * (0.06 if k % 2 else 0.035), t0 + k * beat / 4)
        # pulsing saw bass, ducked on each kick (side-chain feel)
        f = 440.0 * 2 ** ((roots[bar % len(roots)] - 69) / 12.0)
        tb = np.arange(int(SR * beat * 4)) / SR
        saw = 2 * ((tb * f) % 1.0) - 1
        duck = 1 - 0.85 * np.exp(-((tb % beat) / beat) * 6)
        put(_lp(saw, 400) * duck * 0.35, t0)
    return out


# ------------------------------------------------------------------ rendering

def render(song: Song, name: str, out_dir: str, electro=None, gain=1.0, loop_beats=0):
    with tempfile.TemporaryDirectory() as tmp:
        midp = os.path.join(tmp, name + ".mid")
        wavp = os.path.join(tmp, name + ".wav")
        song.save(midp)
        subprocess.run(["fluidsynth", "-ni", "-q", "-g", "0.9", "-r", str(SR), "-F", wavp, SF2, midp],
                       check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        sr, data = wavfile.read(wavp)
        x = data.astype(np.float64) / 32768.0
        if x.ndim == 1:
            x = np.stack([x, x], axis=1)
        if electro is not None:
            e = electro[: len(x)] if len(electro) >= len(x) else np.pad(electro, (0, len(x) - len(electro)))
            x = x + np.stack([e, e], axis=1)
        if loop_beats:
            # seamless loop: cut at the musical length, fold the reverb tail into the start
            L = int(round(song.seconds(loop_beats) * SR))
            if len(x) > L:
                tail = x[L:]
                x = x[:L].copy()
                k = min(len(tail), L)
                x[:k] += tail[:k]
        peak = np.max(np.abs(x)) or 1.0
        x = x / peak * 0.89 * gain
        mixp = os.path.join(tmp, name + "_mix.wav")
        wavfile.write(mixp, SR, (x * 32767).astype(np.int16))
        os.makedirs(out_dir, exist_ok=True)
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", mixp, "-c:a", "libvorbis", "-q:a", "5",
                        os.path.join(out_dir, name + ".ogg")], check=True)
    print("rendered", name)


def main():
    out = sys.argv[1] if len(sys.argv) > 1 else "assets/music"
    want = set(sys.argv[2:])
    tracks = {
        "main_theme": lambda: render(main_theme(), "main_theme", out, loop_beats=64),
        "story_calm": lambda: render(story_calm(), "story_calm", out, loop_beats=64),
        "battle_1": lambda: (lambda s: render(s, "battle_1", out, loop_beats=128,
                                                electro=electro_layer(s, 32, [n("E1"), n("C1"), n("D1"), n("B0")])))(battle_1()),
        "victory": lambda: render(victory(), "victory", out),
        "defeat": lambda: render(defeat(), "defeat", out),
    }
    for name, fn in tracks.items():
        if not want or name in want:
            fn()


if __name__ == "__main__":
    main()

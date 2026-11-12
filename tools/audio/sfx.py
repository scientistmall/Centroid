#!/usr/bin/env python3
"""Synthesizes all sound effects for The Centroid and writes them as .ogg files.

Usage:  python3 tools/audio/sfx.py [out_dir]     (default: assets/sfx)
Needs:  numpy, scipy, ffmpeg.  Deterministic (seeded), so re-running gives the same files.
Every sound is built from noise, sine/saw partials, filters and envelopes.
"""
import os
import subprocess
import sys
import tempfile

import numpy as np
from scipy.io import wavfile
from scipy.signal import butter, sosfilt

SR = 44100
rng = np.random.default_rng(37)


# ------------------------------------------------------------------ building blocks
def t_axis(dur):
    return np.arange(int(round(SR * dur))) / SR


def noise(dur):
    return rng.uniform(-1, 1, int(round(SR * dur)))


def env(n, attack=0.005, decay=0.2, curve=4.0):
    """Fast attack, exponential-ish decay over the whole length."""
    t = np.arange(n) / SR
    a = np.clip(t / max(attack, 1e-4), 0, 1)
    d = np.exp(-curve * t / max(decay, 1e-4))
    return a * d


def adsr(n, a=0.01, d=0.1, s=0.6, r=0.2):
    t = np.arange(n) / SR
    dur = n / SR
    out = np.where(t < a, t / a, np.where(t < a + d, 1 - (1 - s) * (t - a) / d, s))
    rel_start = dur - r
    out = np.where(t > rel_start, out * np.clip((dur - t) / r, 0, 1), out)
    return out


def bp(x, lo, hi, order=2):
    sos = butter(order, [lo, hi], btype="band", fs=SR, output="sos")
    return sosfilt(sos, x)


def lp(x, f, order=2):
    return sosfilt(butter(order, f, btype="low", fs=SR, output="sos"), x)


def hp(x, f, order=2):
    return sosfilt(butter(order, f, btype="high", fs=SR, output="sos"), x)


def sweep(f0, f1, dur, shape="sine"):
    t = t_axis(dur)
    f = f0 * (f1 / f0) ** (t / dur)
    ph = 2 * np.pi * np.cumsum(f) / SR
    if shape == "saw":
        return 2 * ((ph / (2 * np.pi)) % 1.0) - 1
    if shape == "square":
        return np.sign(np.sin(ph))
    return np.sin(ph)


def tone(f, dur, partials=((1, 1.0),)):
    t = t_axis(dur)
    return sum(a * np.sin(2 * np.pi * f * m * t) for m, a in partials)


def moving_bp(x, f0, f1, q=0.5, steps=24):
    """Band-pass whose centre glides from f0 to f1 (for whooshes)."""
    out = np.zeros_like(x)
    seg = len(x) // steps + 1
    for i in range(steps):
        a, b = i * seg, min(len(x), (i + 1) * seg + 400)
        if a >= len(x):
            break
        fc = f0 * (f1 / f0) ** (i / (steps - 1))
        lo, hi = max(40, fc * (1 - q)), min(SR / 2 - 100, fc * (1 + q))
        chunk = bp(x[a:b], lo, hi)
        w = np.hanning(len(chunk))
        out[a:b] += chunk * w
    return out


def reverb(x, size=0.25, mix=0.25):
    """Tiny feedback-comb reverb, enough to give space to impacts."""
    out = np.copy(x)
    for d, g in ((0.029, 0.6), (0.037, 0.55), (0.041, 0.5), (0.053, 0.45)):
        delay = int(SR * d * (1 + size))
        y = np.copy(x)
        for i in range(delay, len(y)):
            y[i] += g * y[i - delay]
        out += mix * 0.25 * y
    return out


def pad(x, tail=0.4):
    return np.concatenate([x, np.zeros(int(SR * tail))])


def norm(x, peak=0.9):
    m = np.max(np.abs(x)) or 1.0
    return x / m * peak


# ------------------------------------------------------------------ sounds
def swing_light():
    n = noise(0.22)
    return norm(moving_bp(n, 900, 3500, 0.6) * env(len(n), 0.03, 0.12, 3), 0.6)


def swing_heavy():
    n = noise(0.38)
    w = moving_bp(n, 300, 1800, 0.7) * env(len(n), 0.06, 0.25, 3)
    return norm(w + 0.3 * lp(noise(0.38), 300) * env(len(n), 0.05, 0.3, 3), 0.75)


def hit_light():
    d = 0.18
    body = sweep(220, 90, d) * env(int(SR * d), 0.001, 0.08, 5)
    crack = hp(noise(d), 2000) * env(int(SR * d), 0.0005, 0.02, 6)
    return norm(pad(body + 0.6 * crack, 0.05), 0.8)


def hit_heavy():
    d = 0.45
    body = sweep(150, 45, d) * env(int(SR * d), 0.001, 0.25, 4)
    crunch = bp(noise(d), 400, 3000) * env(int(SR * d), 0.0005, 0.06, 5)
    return norm(reverb(pad(body + 0.7 * crunch, 0.2), 0.3, 0.3), 0.9)


def block():
    d = 0.5
    t = t_axis(d)
    clang = sum(np.sin(2 * np.pi * f * t) * np.exp(-t * k) for f, k in ((1180, 9), (1730, 11), (2610, 14), (3420, 18)))
    tick = hp(noise(d), 3000) * env(len(t), 0.0005, 0.01, 6)
    return norm(reverb(pad(0.6 * clang + 0.5 * tick, 0.1), 0.2, 0.25), 0.7)


def lightning():
    d = 0.7
    n = len(t_axis(d))
    crackle = np.zeros(n)
    for _ in range(40):
        s = rng.integers(0, n - 2000)
        L = rng.integers(200, 1500)
        crackle[s:s + L] += hp(noise(L / SR), 2500) * np.hanning(L) * rng.uniform(0.3, 1.0)
    zap = sweep(2400, 300, d, "saw") * env(n, 0.002, 0.3, 4) * 0.35
    boom = lp(noise(d), 180) * env(n, 0.01, 0.4, 3)
    return norm(reverb(pad(crackle * env(n, 0.001, 0.6, 2) + zap + 1.4 * boom, 0.3), 0.4, 0.3), 0.95)


def fire_burst():
    d = 1.1
    n = len(t_axis(d))
    roar = lp(noise(d), 900) * adsr(n, 0.08, 0.3, 0.5, 0.5)
    crackle = bp(noise(d), 2000, 6000) * (rng.uniform(0, 1, n) > 0.985) * 3.0
    thump = sweep(90, 40, d) * env(n, 0.002, 0.3, 3)
    return norm(reverb(pad(roar + 0.4 * crackle + thump, 0.3), 0.5, 0.35), 0.95)


def flame_wave():
    d = 0.9
    n = len(t_axis(d))
    w = moving_bp(noise(d), 200, 1200, 0.8) * adsr(n, 0.15, 0.2, 0.7, 0.4)
    crackle = bp(noise(d), 2500, 7000) * (rng.uniform(0, 1, n) > 0.98) * 2.0
    return norm(w + 0.4 * crackle, 0.8)


def dash():
    d = 0.4
    n = len(t_axis(d))
    whoosh = moving_bp(noise(d), 600, 4000, 0.5) * env(n, 0.02, 0.2, 3)
    zap = sweep(800, 3000, d, "square") * env(n, 0.001, 0.12, 4) * 0.15
    return norm(whoosh + zap, 0.8)


def bolt_cast():
    d = 0.5
    n = len(t_axis(d))
    zap = sweep(300, 2600, d, "saw") * env(n, 0.005, 0.25, 3)
    crackle = hp(noise(d), 3000) * (rng.uniform(0, 1, n) > 0.95) * env(n, 0.001, 0.4, 2)
    return norm(lp(zap, 6000) * 0.5 + crackle, 0.75)


def ko():
    d = 1.6
    n = len(t_axis(d))
    boom = sweep(80, 30, d) * env(n, 0.002, 0.8, 3)
    crash = lp(noise(d), 2500) * env(n, 0.001, 0.5, 4)
    ring = tone(220, d, ((1, 0.4), (2.01, 0.25), (3.02, 0.12))) * env(n, 0.01, 1.2, 2.5)
    return norm(reverb(boom + 0.6 * crash + 0.3 * ring, 0.8, 0.5), 0.95)


def gong():
    d = 2.2
    t = t_axis(d)
    partials = ((1, 1.0, 1.2), (1.47, 0.6, 1.6), (2.09, 0.5, 2.0), (2.76, 0.35, 2.6), (3.6, 0.25, 3.0))
    g = sum(a * np.sin(2 * np.pi * 110 * m * t) * np.exp(-t * k) for m, a, k in partials)
    hit = lp(noise(d), 1500) * env(len(t), 0.001, 0.05, 6)
    return norm(reverb(g + 0.4 * hit, 0.6, 0.4), 0.85)


def cutin():
    d = 0.6
    n = len(t_axis(d))
    shing = sum(np.sin(2 * np.pi * f * t_axis(d)) for f in (2100, 3170, 4400)) * env(n, 0.002, 0.45, 3)
    swoosh = moving_bp(noise(d), 1200, 6000, 0.5) * env(n, 0.01, 0.2, 3)
    return norm(reverb(0.5 * shing + swoosh, 0.3, 0.3), 0.7)


def ui_click():
    d = 0.08
    n = len(t_axis(d))
    return norm(tone(1600, d, ((1, 1), (2, 0.3))) * env(n, 0.0005, 0.02, 6), 0.5)


def ui_confirm():
    d = 0.35
    a = tone(880, d / 2) * env(int(SR * d / 2), 0.002, 0.1, 4)
    b = tone(1320, d / 2) * env(int(SR * d / 2), 0.002, 0.15, 3)
    return norm(reverb(pad(np.concatenate([a, b]), 0.1), 0.3, 0.3), 0.5)


def ui_back():
    d = 0.25
    return norm(sweep(900, 500, d) * env(int(SR * d), 0.002, 0.12, 4), 0.45)


def jump():
    d = 0.2
    return norm(moving_bp(noise(d), 500, 1500, 0.6) * env(int(SR * d), 0.01, 0.1, 3), 0.4)


def land():
    d = 0.18
    return norm(lp(noise(d), 400) * env(int(SR * d), 0.001, 0.05, 5) + sweep(120, 60, d) * env(int(SR * d), 0.001, 0.06, 5), 0.5)


# -- elements used by later chapters (rolled out with their fighters)
def wind():
    d = 0.8
    n = len(t_axis(d))
    return norm(moving_bp(noise(d), 400, 2500, 0.4) * adsr(n, 0.1, 0.2, 0.6, 0.4), 0.7)


def mist():
    d = 1.2
    n = len(t_axis(d))
    shimmer = sum(np.sin(2 * np.pi * f * t_axis(d) + rng.uniform(0, 6)) for f in (660, 990, 1320)) * 0.1
    return norm(lp(noise(d), 1200) * adsr(n, 0.3, 0.3, 0.5, 0.5) + shimmer * adsr(n, 0.3, 0.2, 0.6, 0.5), 0.6)


def stone():
    d = 0.6
    n = len(t_axis(d))
    crunch = np.zeros(n)
    for _ in range(25):
        s = rng.integers(0, n - 3000)
        L = rng.integers(300, 2500)
        crunch[s:s + L] += bp(noise(L / SR), 200, 2500) * np.hanning(L)
    rumble = lp(noise(d), 150) * env(n, 0.01, 0.4, 3)
    return norm(crunch * env(n, 0.001, 0.5, 2) + 1.5 * rumble, 0.85)


def gravity():
    d = 1.2
    t = t_axis(d)
    hum = np.sin(2 * np.pi * 55 * t + 4 * np.sin(2 * np.pi * 3 * t)) + 0.5 * np.sin(2 * np.pi * 82 * t)
    return norm(hum * adsr(len(t), 0.1, 0.2, 0.8, 0.4) + 0.3 * lp(noise(d), 200), 0.8)


def whip():
    d = 0.35
    n = len(t_axis(d))
    swish = moving_bp(noise(d), 600, 5000, 0.5) * env(n, 0.05, 0.1, 3)
    crack = hp(noise(0.02), 2000)
    out = swish.copy()
    i = int(SR * 0.12)
    out[i:i + len(crack)] += crack * 2.0
    return norm(out, 0.8)


def poison():
    d = 0.9
    n = len(t_axis(d))
    out = np.zeros(n)
    for _ in range(12):
        s = rng.integers(0, n - 3000)
        L = 2500
        f0 = rng.uniform(300, 700)
        out[s:s + L] += sweep(f0, f0 * 1.8, L / SR) * np.hanning(L) * 0.5
    return norm(lp(out, 2500), 0.6)


def curse():
    d = 1.0
    t = t_axis(d)
    tones = sum(np.sin(2 * np.pi * f * t) for f in (110, 116.5, 164.8))
    return norm(reverb(tones * adsr(len(t), 0.1, 0.2, 0.7, 0.4) + 0.4 * lp(noise(d), 300), 0.6, 0.4), 0.7)


def purify():
    d = 1.0
    t = t_axis(d)
    chime = sum(np.sin(2 * np.pi * f * t) * np.exp(-t * k) for f, k in ((1046, 3), (1318, 3.5), (1568, 4), (2093, 5)))
    return norm(reverb(chime, 0.6, 0.45), 0.6)


SOUNDS = {
    "swing_light": swing_light, "swing_heavy": swing_heavy, "hit_light": hit_light, "hit_heavy": hit_heavy,
    "block": block, "lightning": lightning, "bolt_cast": bolt_cast, "fire_burst": fire_burst,
    "flame_wave": flame_wave, "dash": dash, "ko": ko, "gong": gong, "cutin": cutin,
    "ui_click": ui_click, "ui_confirm": ui_confirm, "ui_back": ui_back, "jump": jump, "land": land,
    "wind": wind, "mist": mist, "stone": stone, "gravity": gravity, "whip": whip, "poison": poison,
    "curse": curse, "purify": purify,
}


def write_ogg(x, path):
    x = np.clip(x, -1, 1)
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as f:
        tmp = f.name
    wavfile.write(tmp, SR, (x * 32767).astype(np.int16))
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", tmp, "-c:a", "libvorbis", "-q:a", "4", path], check=True)
    os.remove(tmp)


def main():
    out = sys.argv[1] if len(sys.argv) > 1 else "assets/sfx"
    os.makedirs(out, exist_ok=True)
    for name, fn in SOUNDS.items():
        write_ogg(fn(), os.path.join(out, name + ".ogg"))
        print("wrote", name)


if __name__ == "__main__":
    main()

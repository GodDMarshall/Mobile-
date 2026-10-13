#!/usr/bin/env python3
"""Synthesizes the prototype's placeholder sound effects from scratch (no samples).

Run from the project folder:  python3 tools/make_sfx.py
Writes 16-bit mono WAVs to audio/sfx/. These are stand-ins until the real
sound and announcer pass (step 4). Pure Python, no dependencies.
"""
import math
import os
import random
import struct
import wave

SR = 22050
OUT = os.path.join(os.path.dirname(__file__), "..", "audio", "sfx")


def write(name, samples):
    peak = max(1e-6, max(abs(s) for s in samples))
    scale = 0.89 / peak
    path = os.path.join(OUT, name + ".wav")
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, s * scale)) * 32767)) for s in samples))


def n(seconds):
    return int(SR * seconds)


def noise(length, rng):
    return [rng.uniform(-1, 1) for _ in range(length)]


def lowpass(x, cutoff_fn):
    """One-pole low-pass with a cutoff (Hz) that can change per sample."""
    y, out = 0.0, []
    for i, s in enumerate(x):
        c = cutoff_fn(i) if callable(cutoff_fn) else cutoff_fn
        a = 1.0 - math.exp(-2.0 * math.pi * c / SR)
        y += a * (s - y)
        out.append(y)
    return out


def highpass(x, cutoff):
    lp = lowpass(x, cutoff)
    return [a - b for a, b in zip(x, lp)]


def env(length, attack, decay_rate):
    a = max(1, n(attack))
    return [(i / a) if i < a else math.exp(-(i - a) / SR * decay_rate) for i in range(length)]


def mix(*tracks):
    length = max(len(t) for t in tracks)
    return [sum(t[i] for t in tracks if i < len(t)) for i in range(length)]


def gain(x, g):
    return [s * g for s in x]


def sine_sweep(length, f0, f1, decay):
    out, phase = [], 0.0
    for i in range(length):
        t = i / length
        f = f0 * (f1 / f0) ** t
        phase += 2 * math.pi * f / SR
        out.append(math.sin(phase) * math.exp(-i / SR * decay))
    return out


def partials(length, freqs, decays, amps):
    out = [0.0] * length
    for f, d, a in zip(freqs, decays, amps):
        for i in range(length):
            out[i] += a * math.sin(2 * math.pi * f * i / SR) * math.exp(-i / SR * d)
    return out


def swoosh(rng, dur, f_lo, f_hi):
    length = n(dur)
    x = noise(length, rng)
    peak = 0.55
    def cutoff(i):
        t = i / length
        return f_lo + (f_hi - f_lo) * math.sin(math.pi * min(1, t / (peak * 2)))
    y = highpass(lowpass(x, cutoff), 250)
    e = [math.sin(math.pi * min(1.0, i / length)) ** 2 for i in range(length)]
    return [a * b for a, b in zip(y, e)]


def main():
    os.makedirs(OUT, exist_ok=True)
    rng = random.Random(1997)

    for i in range(1, 4):
        write(f"swing_light_{i}", swoosh(rng, 0.16 + 0.03 * i, 600, 3800 + 400 * i))
    for i in range(1, 3):
        write(f"swing_heavy_{i}", swoosh(rng, 0.32 + 0.05 * i, 300, 2400 + 300 * i))
    write("dash", gain(swoosh(rng, 0.22, 400, 2000), 0.7))

    for i in range(1, 4):
        length = n(0.32)
        slice_ = [a * b for a, b in zip(highpass(noise(length, rng), 1500), env(length, 0.002, 38 + 6 * i))]
        thump = gain(sine_sweep(n(0.25), 160 + 20 * i, 55, 18), 0.9)
        squelch = [a * b for a, b in zip(lowpass(noise(length, rng), 700), env(length, 0.01, 14))]
        write(f"cut_{i}", mix(gain(slice_, 0.7), thump, gain(squelch, 1.3)))

    for i in range(1, 3):
        length = n(0.9)
        base = 900 + 140 * i
        ring = partials(length, [base, base * 2.76, base * 5.4, base * 8.93], [7, 9, 13, 18], [1, 0.7, 0.45, 0.3])
        tick = [a * b for a, b in zip(highpass(noise(length, rng), 3000), env(length, 0.001, 90))]
        write(f"clang_{i}", mix(gain(ring, 0.6), gain(tick, 0.8)))

    length = n(1.6)
    ring = partials(length, [1680, 2510, 4635, 6900, 9200], [3.2, 4, 5, 7, 9], [1, 0.8, 0.6, 0.4, 0.25])
    tick = [a * b for a, b in zip(highpass(noise(length, rng), 2500), env(length, 0.001, 60))]
    write("parry", mix(gain(ring, 0.6), tick))

    length = n(0.7)
    crunch = [a * b for a, b in zip(lowpass(noise(length, rng), 1200), env(length, 0.003, 9))]
    ring = partials(length, [520, 1390, 2210], [6, 8, 11], [1, 0.6, 0.4])
    write("guard_break", mix(crunch, gain(ring, 0.5), gain(sine_sweep(length, 120, 40, 6), 0.9)))

    length = n(0.3)
    write("kick_hit", mix(sine_sweep(length, 140, 45, 16),
                          gain([a * b for a, b in zip(lowpass(noise(length, rng), 900), env(length, 0.002, 30))], 0.8)))

    length = n(0.6)
    write("body_fall", mix(sine_sweep(length, 90, 35, 8),
                           gain([a * b for a, b in zip(lowpass(noise(length, rng), 400), env(length, 0.005, 10))], 1.2)))

    length = n(0.6)
    stab = partials(length, [700, 1830, 3100], [12, 16, 22], [1, 0.6, 0.4])
    write("spike", mix(gain(stab, 0.6), gain([a * b for a, b in zip(highpass(noise(length, rng), 1200), env(length, 0.001, 25))], 0.8),
                       sine_sweep(length, 130, 50, 10)))

    # Round-start gong: low inharmonic partials with a long tail.
    length = n(3.0)
    write("gong", partials(length, [92, 151, 233, 311, 417, 590], [1.1, 1.4, 1.8, 2.2, 2.9, 3.6], [1, 0.8, 0.7, 0.5, 0.4, 0.25]))

    # Placeholder announcer sting (stands in for the voiced callouts).
    length = n(0.7)
    out, phase = [], 0.0
    for i in range(length):
        t = i / length
        f = 110 * (1 - 0.35 * t)
        phase += 2 * math.pi * f / SR
        saw = sum(math.sin(phase * k) / k for k in range(1, 9))
        out.append(saw * math.sin(math.pi * t) ** 0.5 * math.exp(-t * 2))
    write("callout", lowpass(out, 1400))


if __name__ == "__main__":
    main()

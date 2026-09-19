#!/usr/bin/env python3
"""Generates the placeholder background music: a 30-second jazz blues loop.

Run from the repository root:

    python3 tools/generate_music.py

Writes assets/audio/jazz_loop.wav. Twelve bars of an F jazz blues at 96 BPM comes to
exactly 30 seconds, so the loop joins back on the downbeat with no gap. Everything is
synthesised here with the standard library: walking bass, comped piano chords, brushed
drums and a sparse head.
"""
import math
import os
import random
import struct
import wave

RATE = 22050
BPM = 96.0
BEAT = 60.0 / BPM
BAR = BEAT * 4
BARS = 12
LENGTH = BAR * BARS
# Swing: the second eighth of each beat lands late, which is what makes it read as jazz.
SWING = 0.62

OUT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "audio"))

A4 = 440.0
NOTES = {"C": -9, "C#": -8, "D": -7, "D#": -6, "E": -5, "F": -4, "F#": -3,
         "G": -2, "G#": -1, "A": 0, "A#": 1, "B": 2}


def hz(name, octave=4):
    return A4 * (2.0 ** ((NOTES[name] + (octave - 4) * 12) / 12.0))


# Twelve-bar jazz blues in F: chord root, and the chord tones used for comping.
PROGRESSION = [
    ("F", [("A", 3), ("D#", 4), ("G", 4)]),      # F7
    ("A#", [("G#", 3), ("D", 4), ("F", 4)]),     # Bb7
    ("F", [("A", 3), ("D#", 4), ("G", 4)]),      # F7
    ("F", [("A", 3), ("D#", 4), ("G", 4)]),      # F7
    ("A#", [("G#", 3), ("D", 4), ("F", 4)]),     # Bb7
    ("A#", [("G#", 3), ("D", 4), ("F", 4)]),     # Bb7
    ("F", [("A", 3), ("D#", 4), ("G", 4)]),      # F7
    ("D", [("F#", 3), ("C", 4), ("E", 4)]),      # D7
    ("G", [("A#", 3), ("F", 4), ("A", 4)]),      # Gm7
    ("C", [("E", 3), ("A#", 3), ("D", 4)]),      # C7
    ("F", [("A", 3), ("D#", 4), ("G", 4)]),      # F7
    ("C", [("E", 3), ("A#", 3), ("D", 4)]),      # C7
]

# Walking bass: scale degrees, in semitones from the chord root, one per beat.
WALKS = [[0, 4, 7, 9], [0, 3, 5, 6], [0, 7, 4, 2], [0, 2, 4, 5]]


class Track:
    def __init__(self, seconds):
        self.n = int(seconds * RATE)
        self.buf = [0.0] * self.n

    def add(self, at, samples, gain=1.0):
        start = int(at * RATE)
        for k, v in enumerate(samples):
            i = start + k
            if 0 <= i < self.n:
                self.buf[i] += v * gain
            elif i >= self.n:
                # Anything past the end wraps, so a note over the loop point still joins up.
                self.buf[i - self.n] += v * gain * 0.9


def env(n, attack, decay, sustain=0.0, release=0.0):
    """Simple ADSR as a list of gains of length n."""
    a = max(1, int(attack * RATE))
    d = max(1, int(decay * RATE))
    out = []
    for i in range(n):
        if i < a:
            out.append(i / a)
        elif i < a + d:
            t = (i - a) / d
            out.append(1.0 - (1.0 - sustain) * t)
        else:
            left = n - (a + d)
            t = 0.0 if left <= 0 else (i - a - d) / left
            out.append(sustain * (1.0 - t))
    return out


def tone(freq, seconds, harmonics, attack, decay, sustain=0.0, detune=0.0):
    n = int(seconds * RATE)
    e = env(n, attack, decay, sustain)
    out = [0.0] * n
    for h, amp in harmonics:
        f = freq * h
        step = 2.0 * math.pi * f / RATE
        step2 = 2.0 * math.pi * (f * (1.0 + detune)) / RATE
        for i in range(n):
            v = math.sin(step * i)
            if detune:
                v = 0.5 * v + 0.5 * math.sin(step2 * i)
            out[i] += v * amp
    return [out[i] * e[i] for i in range(n)]


def noise(seconds, decay, rng, bright=0.5):
    """Brushed-cymbal style noise: white noise through a one-pole high pass."""
    n = int(seconds * RATE)
    out = [0.0] * n
    prev = 0.0
    prev_out = 0.0
    for i in range(n):
        w = rng.uniform(-1.0, 1.0)
        # High-pass so it hisses rather than rumbles.
        hp = bright * (prev_out + w - prev)
        prev = w
        prev_out = hp
        out[i] = hp * math.exp(-i / (decay * RATE))
    return out


def kick(seconds, rng):
    n = int(seconds * RATE)
    out = [0.0] * n
    phase = 0.0
    for i in range(n):
        t = i / RATE
        f = 110.0 * math.exp(-t * 26.0) + 42.0
        phase += 2.0 * math.pi * f / RATE
        out[i] = math.sin(phase) * math.exp(-t * 11.0)
    return out


def build():
    rng = random.Random(7)
    track = Track(LENGTH)

    for bar in range(BARS):
        root_name, voicing = PROGRESSION[bar]
        bar_t = bar * BAR
        root = hz(root_name, 2)
        walk = WALKS[bar % len(WALKS)]

        for beat in range(4):
            t = bar_t + beat * BEAT

            # Walking bass, one note per beat. Notes ring a little past the next one so
            # the line is legato and, on the last beat of the last bar, so it carries over
            # the loop point instead of leaving a gap.
            step = walk[beat]
            f = root * (2.0 ** (step / 12.0))
            track.add(t, tone(f, BEAT * 1.15, [(1, 0.9), (2, 0.18), (3, 0.06)],
                              0.006, BEAT * 0.8, 0.30), 0.30)
            if beat == 3:
                # Approach note on the swung eighth, leading into the next bar.
                next_root = hz(PROGRESSION[(bar + 1) % BARS][0], 2)
                approach = next_root * (2.0 ** (1 / 12.0)) if rng.random() < 0.5 else next_root * (2.0 ** (-1 / 12.0))
                track.add(t + BEAT * SWING, tone(approach, BEAT * 0.75,
                          [(1, 0.85), (2, 0.16)], 0.006, BEAT * 0.55, 0.25), 0.26)

            # Kick on 1 and 3, brush snare on 2 and 4.
            if beat in (0, 2):
                track.add(t, kick(0.22, rng), 0.26)
            else:
                track.add(t, noise(0.20, 0.055, rng, bright=0.35), 0.14)

            # Ride pattern: the beat, then a swung eighth.
            track.add(t, noise(0.13, 0.030, rng, bright=0.9), 0.085)
            track.add(t + BEAT * SWING, noise(0.10, 0.022, rng, bright=0.9), 0.055)

            # Piano comping lands off the beat, on 2 and 4.
            if beat in (1, 3):
                for name, octave in voicing:
                    cf = hz(name, octave)
                    track.add(t + BEAT * 0.02,
                              tone(cf, BEAT * 1.1, [(1, 0.7), (2, 0.22), (3, 0.09), (5, 0.03)],
                                   0.008, BEAT * 0.8, 0.12, detune=0.0015), 0.075)

        # A sparse head over the first and last four bars, from the F blues scale.
        head = {0: [(0, 0), (1.5, 3)], 1: [(0, 5)], 2: [(2, 6), (3, 5)], 3: [(0, 3)],
                8: [(0, 10), (2, 8)], 9: [(0, 7)], 10: [(0, 5), (2, 3)], 11: [(0, 0)]}
        for beat_offset, semis in head.get(bar, []):
            f = hz("F", 4) * (2.0 ** (semis / 12.0))
            track.add(bar_t + beat_offset * BEAT,
                      tone(f, BEAT * 1.4, [(1, 0.6), (2, 0.14), (3, 0.05)],
                           0.012, BEAT * 1.1, 0.10, detune=0.002), 0.085)

    # A cymbal wash over the bar line, which wraps, so the loop joins seamlessly.
    track.add(LENGTH - 0.26, noise(0.55, 0.20, rng, bright=0.8), 0.10)

    # Normalise with a little headroom, then soft-clip anything left over.
    peak = max(abs(v) for v in track.buf) or 1.0
    scale = 0.82 / peak
    frames = bytearray()
    for v in track.buf:
        x = v * scale
        x = math.tanh(x * 1.1) * 0.92
        frames += struct.pack("<h", int(max(-1.0, min(1.0, x)) * 32000))

    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, "jazz_loop.wav")
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(bytes(frames))
    print("Wrote %s (%.1f seconds, %.1f MB)" % (path, LENGTH, len(frames) / 1e6))


if __name__ == "__main__":
    build()

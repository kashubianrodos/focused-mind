#!/usr/bin/env python3
"""Generates the app's feedback sounds procedurally.

Produces seamless loops (the end flows into the start) so just_audio can loop
them without a gap, plus a short end-of-session chime. Because the audio is
synthesized here, it carries no third-party license.

Usage: python3 tool/generate_sounds.py   (needs numpy and macOS afconvert)
"""

import os
import subprocess
import tempfile
import wave

import numpy as np

RATE = 44100
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "sounds")
rng = np.random.default_rng(20261111)


def periodic_noise(n, color):
    """Noise whose spectrum falls off as 1/f^color, built in the frequency
    domain so it is exactly periodic over n samples (a seamless loop)."""
    spectrum = rng.normal(size=n // 2 + 1) + 1j * rng.normal(size=n // 2 + 1)
    f = np.arange(n // 2 + 1)
    f[0] = 1
    spectrum /= f ** (color / 2)
    spectrum[0] = 0
    x = np.fft.irfft(spectrum, n)
    return x / np.max(np.abs(x))


def lowpass_periodic(x, cutoff_hz):
    spectrum = np.fft.rfft(x)
    freqs = np.fft.rfftfreq(len(x), 1 / RATE)
    spectrum *= 1 / (1 + (freqs / cutoff_hz) ** 4)
    return np.fft.irfft(spectrum, len(x))


def ocean(seconds=96):
    n = RATE * seconds
    t = np.arange(n) / RATE
    channels = []
    for side in range(2):
        body = lowpass_periodic(periodic_noise(n, 1.6), 900)
        hiss = lowpass_periodic(periodic_noise(n, 0.6), 6000) * 0.25
        # Waves: a sum of slow periodic swells (whole cycles per loop).
        envelope = np.zeros(n)
        for cycles, phase in [(9, 0.3 + side * 0.4), (11, 1.7), (14, 4.1 + side)]:
            envelope += 0.5 + 0.5 * np.sin(2 * np.pi * cycles * t / seconds + phase)
        envelope = (envelope / envelope.max()) ** 2.2
        channels.append((body * (0.25 + 0.75 * envelope) + hiss * envelope))
    stereo = np.stack(channels, axis=1)
    return 0.5 * stereo / np.max(np.abs(stereo))


def chirp(duration, f0, f1, vibrato_hz, vibrato_depth):
    m = int(RATE * duration)
    t = np.arange(m) / RATE
    sweep = f0 + (f1 - f0) * (t / duration) ** 0.7
    freq = sweep + vibrato_depth * np.sin(2 * np.pi * vibrato_hz * t)
    phase = 2 * np.pi * np.cumsum(freq) / RATE
    env = np.sin(np.pi * t / duration) ** 1.5
    return env * (np.sin(phase) + 0.18 * np.sin(2 * phase))


def birds(seconds=64):
    n = RATE * seconds
    out = np.zeros((n, 2))
    # A quiet bed of leaves/air so the loop never sounds empty.
    for side in range(2):
        out[:, side] = 0.04 * lowpass_periodic(periodic_noise(n, 1.0), 2500)
    singers = [
        dict(f=(3200, 4600), dur=(0.07, 0.12), notes=(3, 7), gap=0.09, pan=0.25),
        dict(f=(2400, 3400), dur=(0.15, 0.28), notes=(2, 4), gap=0.12, pan=0.75),
        dict(f=(4200, 5600), dur=(0.04, 0.07), notes=(5, 10), gap=0.05, pan=0.5),
    ]
    for bird in singers:
        t = rng.uniform(0, 3)
        while t < seconds:
            notes = rng.integers(*bird["notes"])
            base = rng.uniform(*bird["f"])
            for k in range(notes):
                dur = rng.uniform(*bird["dur"])
                f0 = base * rng.uniform(0.9, 1.1)
                f1 = f0 * rng.choice([0.7, 1.25, 1.4])
                c = 0.22 * chirp(dur, f0, f1, rng.uniform(20, 45), f0 * 0.03)
                start = int(t * RATE)
                idx = (np.arange(len(c)) + start) % n  # wrap: seamless loop
                out[idx, 0] += c * (1 - bird["pan"])
                out[idx, 1] += c * bird["pan"]
                t += dur + bird["gap"] * rng.uniform(0.6, 1.4)
            t += rng.uniform(2.5, 7.0)
    return 0.6 * out / np.max(np.abs(out))


def chime(seconds=3.5):
    n = int(RATE * seconds)
    t = np.arange(n) / RATE
    tone = np.zeros(n)
    for ratio, amp, decay in [(1, 1.0, 1.4), (2.76, 0.45, 2.2), (5.4, 0.25, 3.5), (2, 0.3, 1.8)]:
        tone += amp * np.exp(-decay * t) * np.sin(2 * np.pi * 528 * ratio * t)
    attack = np.minimum(1, t / 0.005)
    mono = 0.5 * attack * tone / np.max(np.abs(tone))
    return np.stack([mono, mono], axis=1)


def write_m4a(name, audio):
    os.makedirs(OUT, exist_ok=True)
    pcm = (np.clip(audio, -1, 1) * 32767).astype("<i2")
    with tempfile.TemporaryDirectory() as tmp:
        wav_path = os.path.join(tmp, name + ".wav")
        with wave.open(wav_path, "wb") as w:
            w.setnchannels(2)
            w.setsampwidth(2)
            w.setframerate(RATE)
            w.writeframes(pcm.tobytes())
        target = os.path.join(OUT, name + ".m4a")
        subprocess.run(
            ["afconvert", "-f", "m4af", "-d", "aac", "-b", "160000", wav_path, target],
            check=True,
        )
    print("wrote", os.path.normpath(target))


if __name__ == "__main__":
    write_m4a("ocean", ocean())
    write_m4a("birds", birds())
    write_m4a("end_chime", chime())

"""Generated ambience (no licence questions: the kit makes it). Method by fwjelaa (FWJ STUDIOS)."""
import wave
from pathlib import Path

import numpy as np


def _write(path, sig, rate):
    pcm = (sig * 32767).astype("<i2")
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(path), "wb") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(rate)
        f.writeframes(pcm.tobytes())
    return path


def _periodic_noise(rng, n, rate, lo, hi, tilt):
    # noise made in the frequency domain over exactly n samples is periodic in n: the loop has no seam
    freqs = np.fft.rfftfreq(n, 1 / rate)
    mag = np.where((freqs >= lo) & (freqs <= hi), 1.0 / np.maximum(freqs, 1.0) ** tilt, 0.0)
    spec = mag * np.exp(1j * rng.uniform(0, 2 * np.pi, len(freqs)))
    sig = np.fft.irfft(spec, n)
    return sig / np.max(np.abs(sig))


def wind_wav(path, seconds=12.0, rate=44100, seed=4):
    # outdoor night wind: a low rumble plus a whistling band, both swelling in gusts. The gust envelope is made of
    # whole cycles per loop, so it loops cleanly too.
    rng = np.random.default_rng(seed)
    n = int(round(seconds * rate))
    t = np.arange(n) / n
    gust = 0.5 + 0.22 * np.sin(2 * np.pi * 2 * t + 0.7) + 0.18 * np.sin(2 * np.pi * 3 * t + 2.1) + 0.1 * np.sin(2 * np.pi * 5 * t)
    gust = np.clip(gust, 0.08, None)
    rumble = _periodic_noise(rng, n, rate, 20, 300, 1.0)
    whistle = _periodic_noise(rng, n, rate, 350, min(1200, rate / 2 - 1), 0.5)
    sig = 0.7 * rumble * gust + 0.35 * whistle * gust ** 2
    return _write(path, sig / np.max(np.abs(sig)) * 0.7, rate)


def water_wav(path, seconds=10.0, rate=44100, seed=7):
    # small waves lapping a shore: soft swells of low noise with a little splash on each one; periodic noise and
    # whole-cycle envelopes, so the loop is seamless
    rng = np.random.default_rng(seed)
    n = int(round(seconds * rate))
    t = np.arange(n) / n
    laps = max(2, int(round(seconds / 1.6)))  # a lap every second and a half or so
    phase = rng.uniform(0, 2 * np.pi)
    swell = np.clip(np.sin(2 * np.pi * laps * t + phase), 0, None) ** 3
    swell += 0.5 * np.clip(np.sin(2 * np.pi * (laps + 1) * t + phase * 1.7), 0, None) ** 4
    body = _periodic_noise(rng, n, rate, 40, 600, 1.2)
    splash = _periodic_noise(rng, n, rate, 600, min(3000, rate / 2 - 1), 0.3)
    sig = 0.15 * body + body * swell * 0.8 + splash * swell ** 2 * 0.35
    return _write(path, sig / np.max(np.abs(sig)) * 0.6, rate)


def hum_wav(path, seconds=8.0, base=120.0, rate=44100):
    # fluorescent ballast hum at twice the mains frequency (120 Hz on 60 Hz power, research/05);
    # a whole number of base cycles, so the file loops without a click
    cycles = max(1, round(seconds * base))
    n = int(round(cycles / base * rate))
    t = np.arange(n) / rate
    w = 2 * np.pi * base * t
    sig = 0.5 * np.sin(w) + 0.25 * np.sin(2 * w) + 0.12 * np.sin(3 * w) + 0.06 * np.sin(5 * w)
    sig += 0.04 * np.sign(np.sin(w))  # magnetic ballast buzz
    sig += np.random.default_rng(1).normal(0, 0.01, n)
    sig = sig / np.max(np.abs(sig)) * 0.6
    pcm = (sig * 32767).astype("<i2")
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(path), "wb") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(rate)
        f.writeframes(pcm.tobytes())
    return path

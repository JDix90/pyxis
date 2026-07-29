#!/usr/bin/env python3
"""Procedural SFX generator for Pyxis.

Pure stdlib -> 16-bit mono WAV in audio/. Re-run to regenerate:
    python3 tools/gen_sfx.py

Every sound is synthesized here, so the whole audio set is original and
license-free. Tune the numbers, re-run, hear the difference.
"""

import math
import os
import random
import struct
import wave

SR = 44100
OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "audio")


# --- helpers ---------------------------------------------------------------

def n_samples(seconds):
    return int(SR * seconds)


def lowpass(buf, cutoff_at):
    """One-pole LP. cutoff_at(i, n) -> Hz, so sweeps are just a lambda."""
    out = [0.0] * len(buf)
    y = 0.0
    n = len(buf)
    for i, x in enumerate(buf):
        fc = max(20.0, min(cutoff_at(i, n), SR * 0.45))
        a = 1.0 - math.exp(-2.0 * math.pi * fc / SR)
        y += (x - y) * a
        out[i] = y
    return out


def lowpass_loop(buf, cutoff_at):
    """One-pole LP whose filter state is PERIODIC with the buffer.

    A plain lowpass() starts from y=0 and spends its first samples climbing to
    meet the signal. On a one-shot that is inaudible. On a loop it is a step
    discontinuity at the seam — the pad here jumped 0.2 full-scale and clicked
    once every 22.86 seconds, forever. Warming the state on the tail first means
    sample 0 continues from sample N-1 instead of starting over.
    """
    n = len(buf)
    warm = min(n, n_samples(0.25))
    y = 0.0
    for i in range(n - warm, n):
        fc = max(20.0, min(cutoff_at(i, n), SR * 0.45))
        y += (buf[i] - y) * (1.0 - math.exp(-2.0 * math.pi * fc / SR))
    out = [0.0] * n
    for i, x in enumerate(buf):
        fc = max(20.0, min(cutoff_at(i, n), SR * 0.45))
        y += (x - y) * (1.0 - math.exp(-2.0 * math.pi * fc / SR))
        out[i] = y
    return out


def seam_step(buf):
    """How far the waveform jumps when the buffer wraps. Compared against the
    signal's own typical motion, this is a click detector."""
    if len(buf) < 3:
        return 0.0, 0.0
    steps = sorted(abs(buf[i + 1] - buf[i]) for i in range(0, len(buf) - 1, 7))
    return abs(buf[0] - buf[-1]), steps[int(len(steps) * 0.99)]


def highpass(buf, cutoff):
    lp = lowpass(buf, lambda i, n: cutoff)
    return [x - y for x, y in zip(buf, lp)]


def noise(n):
    return [random.uniform(-1.0, 1.0) for _ in range(n)]


def sweep(n, f0, f1, shape="sine", curve=1.0):
    """Phase-accumulated frequency sweep (no clicks)."""
    out = [0.0] * n
    phase = 0.0
    for i in range(n):
        t = (i / max(n - 1, 1)) ** curve
        f = f0 + (f1 - f0) * t
        phase += 2.0 * math.pi * f / SR
        if shape == "sine":
            out[i] = math.sin(phase)
        elif shape == "saw":
            p = (phase / (2.0 * math.pi)) % 1.0
            out[i] = 2.0 * p - 1.0
        elif shape == "square":
            out[i] = 1.0 if math.sin(phase) >= 0 else -1.0
        elif shape == "tri":
            p = (phase / (2.0 * math.pi)) % 1.0
            out[i] = 4.0 * abs(p - 0.5) - 1.0
    return out


def env(n, attack, decay, curve=2.5):
    """Attack/decay envelope in seconds; exponential-ish decay."""
    a = max(1, n_samples(attack))
    out = [0.0] * n
    for i in range(n):
        if i < a:
            out[i] = i / a
        else:
            t = (i - a) / max(1.0, n_samples(decay))
            out[i] = math.exp(-curve * t)
    return out


def mix(*layers):
    n = max(len(x) for x in layers)
    out = [0.0] * n
    for layer in layers:
        for i, v in enumerate(layer):
            out[i] += v
    return out


def apply(buf, envelope):
    return [x * e for x, e in zip(buf, envelope)]


def gain(buf, g):
    return [x * g for x in buf]


def soft_clip(buf):
    return [math.tanh(x) for x in buf]


def normalize(buf, peak=0.85):
    m = max(abs(x) for x in buf) or 1.0
    return [x * peak / m for x in buf]


def loopify(buf, fade_seconds=0.35):
    """Crossfade the tail over the head so the buffer loops seamlessly."""
    f = n_samples(fade_seconds)
    n = len(buf)
    out = buf[: n - f]
    for i in range(f):
        w = i / f
        out[i] = buf[i] * w + buf[n - f + i] * (1.0 - w)
    return out


def env_asr(n, attack, release):
    """Attack / full sustain / release. Pads want a plateau, not a decay."""
    a = max(1, n_samples(attack))
    r = max(1, n_samples(release))
    out = [0.0] * n
    for i in range(n):
        if i < a:
            out[i] = i / a
        elif i > n - r:
            out[i] = max(0.0, (n - i) / r)
        else:
            out[i] = 1.0
    return out


def place(buf, layer, at):
    """Add `layer` into `buf` at sample `at`, wrapping the overhang back to the
    start. This is what makes an exact-length loop seamless: a pad chord whose
    release runs past the final bar continues underneath the first bar, so the
    buffer can be looped end-to-end with no crossfade and no trimming.

    Trimming (see `loopify`) is deliberately NOT used for music: it shortens the
    buffer, and the two music layers have to stay sample-aligned forever so they
    can be crossfaded against each other mid-phrase.
    """
    n = len(buf)
    for i, v in enumerate(layer):
        buf[(at + i) % n] += v


def tone(freq, seconds, shape="sine", detune=0.0):
    n = n_samples(seconds)
    f = freq * (1.0 + detune)
    return sweep(n, f, f, shape)


def write(name, buf):
    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, name)
    with wave.open(path, "w") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        frames = b"".join(
            struct.pack("<h", int(max(-1.0, min(1.0, x)) * 32000)) for x in buf
        )
        w.writeframes(frames)
    print(f"  {name}  {len(buf) / SR:.2f}s")


# --- sounds ----------------------------------------------------------------

def s_tap():
    """Designate a target: soft two-tone console chirp."""
    n = n_samples(0.09)
    body = sweep(n, 1150, 1750, "sine")
    shimmer = gain(sweep(n, 2300, 3500, "sine"), 0.25)
    click = gain(apply(noise(n_samples(0.004)), env(n_samples(0.004), 0.0002, 0.002)), 0.35)
    out = apply(mix(body, shimmer), env(n, 0.002, 0.03))
    return normalize(mix(out, click), 0.5)


def s_fire():
    """Beam discharge: descending zap with an airy tail."""
    n = n_samples(0.24)
    beam = gain(sweep(n, 1400, 260, "saw", curve=0.5), 0.5)
    air = lowpass(noise(n), lambda i, nn: 5200 - 4200 * (i / nn))
    body = mix(beam, gain(air, 0.4))
    return normalize(apply(soft_clip(body), env(n, 0.001, 0.055)), 0.42)


def s_hit():
    """Shield/hull impact: metallic tick over a short thump."""
    n = n_samples(0.13)
    tick = highpass(noise(n), 2600)
    thump = gain(sweep(n, 420, 150, "sine"), 0.7)
    return normalize(apply(mix(gain(tick, 0.8), thump), env(n, 0.0005, 0.028)), 0.5)


def s_explode():
    """Kill: sub thump + swept debris roar + crackle."""
    n = n_samples(1.5)
    sub = apply(sweep(n, 110, 34, "sine", curve=0.6), env(n, 0.004, 0.30, curve=3.0))
    roar = apply(
        lowpass(noise(n), lambda i, nn: 7000 * math.exp(-3.2 * i / nn) + 180),
        env(n, 0.003, 0.42, curve=2.2),
    )
    crackle = [0.0] * n
    for _ in range(60):
        p = random.randint(0, n - 900)
        amp = random.uniform(0.1, 0.5) * math.exp(-3.0 * p / n)
        for i in range(700):
            crackle[p + i] += random.uniform(-1, 1) * amp * math.exp(-i / 90.0)
    body = mix(gain(sub, 1.0), gain(roar, 0.85), gain(highpass(crackle, 1200), 0.5))
    return normalize(soft_clip(body), 0.92)


def s_pickup():
    """Salvage cube collected: bright bell ping."""
    n = n_samples(0.17)
    partials = [
        gain(sweep(n, 1560, 1610, "sine"), 1.0),
        gain(sweep(n, 2340, 2410, "sine"), 0.45),
        gain(sweep(n, 3120, 3220, "sine"), 0.2),
    ]
    return normalize(apply(mix(*partials), env(n, 0.001, 0.035, curve=3.0)), 0.4)


def s_count():
    """Counter tick: tiny, dry, repeatable without fatigue."""
    n = n_samples(0.035)
    return normalize(apply(sweep(n, 2400, 2100, "sine"), env(n, 0.0004, 0.008)), 0.22)


def s_crack():
    """Hold-to-crack loop: rising structural tension."""
    n = n_samples(2.2)
    groan = gain(sweep(n, 70, 190, "saw", curve=1.4), 0.45)
    stress = lowpass(noise(n), lambda i, nn: 300 + 2600 * (i / nn))
    swell = [(i / n) ** 1.6 for i in range(n)]
    trem = [1.0 + 0.25 * math.sin(2 * math.pi * (3.0 + 5.0 * i / n) * i / SR) for i in range(n)]
    body = mix(groan, gain(stress, 0.7))
    return normalize([x * s * t for x, s, t in zip(body, swell, trem)], 0.55)


def s_breach():
    """Hull gives way: deep boom with a metallic shear and shimmer tail."""
    n = n_samples(2.0)
    boom = apply(sweep(n, 130, 28, "sine", curve=0.5), env(n, 0.003, 0.45, curve=2.4))
    shear = apply(
        lowpass(noise(n), lambda i, nn: 9000 * math.exp(-2.4 * i / nn) + 140),
        env(n, 0.002, 0.5, curve=2.0),
    )
    ring = apply(
        mix(sweep(n, 640, 610, "sine"), gain(sweep(n, 960, 920, "sine"), 0.5)),
        env(n, 0.01, 0.7, curve=2.0),
    )
    return normalize(soft_clip(mix(boom, gain(shear, 0.8), gain(ring, 0.35))), 0.95)


def s_vortex():
    """Loot vortex: shimmering swirl, loops under the collection sequence."""
    n = n_samples(3.0)
    layers = []
    for base, rate, amp in [(1180, 2.7, 1.0), (1790, 3.6, 0.6), (2620, 4.9, 0.35), (880, 1.9, 0.5)]:
        tone = sweep(n, base, base * 1.18, "sine")
        trem = [0.55 + 0.45 * math.sin(2 * math.pi * rate * i / SR) for i in range(n)]
        layers.append(gain([x * t for x, t in zip(tone, trem)], amp))
    air = gain(lowpass(noise(n), lambda i, nn: 900 + 3000 * (i / nn)), 0.3)
    body = mix(*layers, air)
    return normalize(loopify(body, 0.4), 0.4)


def s_ambient():
    """System bed: cold low drone. Frequencies chosen to loop seamlessly."""
    dur = 8.0
    n = n_samples(dur)
    layers = []
    for freq, amp in [(55.0, 1.0), (82.5, 0.55), (110.0, 0.4), (165.0, 0.18), (220.0, 0.09)]:
        tone = sweep(n, freq, freq, "sine")
        lfo_hz = 1.0 / dur * random.choice([1, 2, 3])
        lfo = [0.7 + 0.3 * math.sin(2 * math.pi * lfo_hz * i / SR) for i in range(n)]
        layers.append(gain([x * l for x, l in zip(tone, lfo)], amp))
    wind = gain(lowpass(noise(n), lambda i, nn: 320), 0.5)
    body = mix(*layers, wind)
    return normalize(loopify(body, 1.2), 0.30)


def s_equip():
    """Refit console: mechanical seat-and-latch clunk."""
    n = n_samples(0.22)
    thunk = apply(sweep(n, 260, 110, "sine", curve=0.6), env(n, 0.001, 0.035, curve=3.0))
    latch = apply(highpass(noise(n), 1800), env(n, 0.0006, 0.012, curve=4.0))
    ring = apply(sweep(n, 1420, 1380, "sine"), env(n, 0.004, 0.05, curve=3.0))
    return normalize(mix(gain(thunk, 1.0), gain(latch, 0.5), gain(ring, 0.3)), 0.45)


def s_alarm():
    """Shields down: two-tone warble, urgent but not shrill."""
    n = n_samples(0.9)
    out = [0.0] * n
    phase = 0.0
    for i in range(n):
        t = i / SR
        freq = 620.0 if int(t * 6.0) % 2 == 0 else 460.0
        phase += 2.0 * math.pi * freq / SR
        out[i] = math.sin(phase) + 0.3 * math.sin(2 * phase)
    body = apply(out, env(n, 0.006, 0.5, curve=1.6))
    return normalize(soft_clip(body), 0.5)


def s_warp():
    """Emergency warp: rising whoosh into a snap."""
    n = n_samples(1.4)
    air = lowpass(noise(n), lambda i, nn: 250 + 6500 * (i / nn) ** 1.7)
    rise = gain(sweep(n, 120, 1500, "sine", curve=1.8), 0.4)
    swell = [(i / n) ** 1.3 for i in range(n)]
    body = [(a + r) * s for a, r, s in zip(air, rise, swell)]
    tail = n_samples(0.25)
    for i in range(tail):
        k = i / tail
        body[n - tail + i] *= 1.0 - k
    return normalize(soft_clip(body), 0.55)


def s_boss_wake():
    """Apex engine waking: a long sub-bass groan under a rising alarm."""
    n = n_samples(3.6)
    groan = apply(sweep(n, 26, 58, "sine", curve=1.5), env(n, 0.4, 2.4, curve=0.9))
    grind = apply(
        lowpass(noise(n), lambda i, nn: 90 + 700 * (i / nn) ** 2),
        env(n, 0.5, 2.2, curve=1.0),
    )
    siren = [0.0] * n
    phase = 0.0
    for i in range(n):
        t = i / SR
        f = 300.0 + 180.0 * math.sin(2 * math.pi * 0.7 * t)
        phase += 2.0 * math.pi * f / SR
        siren[i] = math.sin(phase) * min(1.0, (t / 2.6) ** 2) * 0.5
    body = mix(gain(groan, 1.0), gain(grind, 0.8), gain(siren, 0.55))
    return normalize(soft_clip(body), 0.9)


def s_sweep():
    """The sweep arm passing: low rotational whoosh. Loops seamlessly."""
    dur = 2.0
    n = n_samples(dur)
    air = lowpass(noise(n), lambda i, nn: 180 + 260 * (0.5 + 0.5 * math.sin(2 * math.pi * i / nn)))
    tone = gain(sweep(n, 44.0, 44.0, "sine"), 0.5)
    swellf = [0.55 + 0.45 * math.sin(2 * math.pi * i / n) for i in range(n)]
    body = [(a * 0.8 + t) * s for a, t, s in zip(air, tone, swellf)]
    return normalize(loopify(body, 0.3), 0.32)


def s_plate():
    """Iris plate moving: a heavy mechanical clank."""
    n = n_samples(0.3)
    clank = apply(highpass(noise(n), 900), env(n, 0.0008, 0.03, curve=3.5))
    body_t = apply(sweep(n, 340, 150, "sine", curve=0.7), env(n, 0.001, 0.045, curve=3.0))
    ring = apply(sweep(n, 880, 860, "sine"), env(n, 0.003, 0.08, curve=2.5))
    return normalize(mix(gain(clank, 0.9), gain(body_t, 1.0), gain(ring, 0.35)), 0.55)


def s_weld():
    """A probe clamping onto the shell: nasty electrical bite."""
    n = n_samples(0.5)
    buzz = [0.0] * n
    phase = 0.0
    for i in range(n):
        f = 150.0 + 90.0 * (1 if int(i / (SR * 0.011)) % 2 == 0 else -1)
        phase += 2.0 * math.pi * f / SR
        buzz[i] = 1.0 if math.sin(phase) >= 0 else -1.0
    zap = apply(lowpass(noise(n), lambda i, nn: 4200 - 3200 * (i / nn)), env(n, 0.002, 0.1))
    body = mix(gain(apply(buzz, env(n, 0.004, 0.12, curve=2.0)), 0.55), gain(zap, 0.7))
    return normalize(soft_clip(body), 0.5)


def s_phase():
    """Phase transition: a two-note klaxon that means 'it just got worse'."""
    n = n_samples(1.3)
    out = [0.0] * n
    phase = 0.0
    for i in range(n):
        t = i / SR
        f = 210.0 if t < 0.34 else (168.0 if t < 0.68 else 240.0)
        phase += 2.0 * math.pi * f / SR
        out[i] = math.sin(phase) + 0.4 * math.sin(3 * phase)
    body = apply(out, env(n, 0.01, 0.6, curve=1.4))
    sub = apply(sweep(n, 70, 40, "sine"), env(n, 0.01, 0.5, curve=1.8))
    return normalize(soft_clip(mix(gain(body, 0.8), gain(sub, 0.8))), 0.75)


def s_dock():
    """Docking clamps: heavy magnetic thunk followed by a pressure hiss."""
    n = n_samples(1.1)
    thunk = apply(sweep(n, 150, 52, "sine", curve=0.6), env(n, 0.004, 0.09, curve=2.6))
    clamp = apply(highpass(noise(n), 1400), env(n, 0.001, 0.02, curve=4.0))
    hiss = [0.0] * n
    start = n_samples(0.16)
    lp = lowpass(noise(n), lambda i, nn: 2600)
    for i in range(start, n):
        k = (i - start) / float(n - start)
        hiss[i] = lp[i] * math.exp(-2.6 * k) * 0.5
    seat = apply(sweep(n, 420, 380, "sine"), env(n, 0.006, 0.10, curve=2.4))
    body = mix(gain(thunk, 1.0), gain(clamp, 0.55), gain(hiss, 0.7), gain(seat, 0.3))
    return normalize(soft_clip(body), 0.6)


# --- music -----------------------------------------------------------------
#
# Two layers of the SAME eight bars, so `scripts/music.gd` can start both in
# sync and crossfade between them on threat without the harmony ever jumping.
# That is the whole architectural point: the calm and combat tracks are not two
# pieces of music, they are one piece with the top half muted.
#
# D minor, 84 BPM, i - VI - III - VII (Dm - Bb - F - C), two bars per chord.
# Minor and slow because the fiction is salvage cartography — the player is
# alone in someone else's wreckage, and the music should agree.

BPM = 84.0
BEAT = 60.0 / BPM
BAR = BEAT * 4.0
BARS = 8
LOOP_SECONDS = BAR * BARS  # 22.857s

PROGRESSION = [
    [146.83, 174.61, 220.00],  # i   Dm  (D3 F3 A3)
    [116.54, 146.83, 174.61],  # VI  Bb  (Bb2 D3 F3)
    [174.61, 220.00, 261.63],  # III F   (F3 A3 C4)
    [130.81, 164.81, 196.00],  # VII C   (C3 E3 G3)
]


def _music_bed():
    """The pad both layers share. Rendered once and mixed into each."""
    n = n_samples(LOOP_SECONDS)
    pad = [0.0] * n
    chord_seconds = BAR * 2.0

    for idx, chord in enumerate(PROGRESSION):
        at = n_samples(idx * chord_seconds)
        # Slightly longer than the chord it occupies, so each release overlaps
        # the next attack instead of leaving a seam every two bars.
        dur = chord_seconds + 0.9
        shape = env_asr(n_samples(dur), 0.9, 1.3)
        for j, f in enumerate(chord):
            # Two detuned saws per voice: the cheapest way to make an additive
            # pad sound like it has width rather than like a test tone.
            for det in (-0.0035, 0.0035):
                v = apply(tone(f, dur, "saw", det), shape)
                place(pad, gain(v, 0.30 / (j + 1.0)), at)
        # Root an octave down, sine: gives the pad a floor without mud.
        sub = apply(tone(chord[0] * 0.5, dur, "sine"), shape)
        place(pad, gain(sub, 0.55), at)

    # Dark and soft — this sits under everything and must never compete with a
    # weapon or an alarm for attention. lowpass_loop, not lowpass: this buffer
    # gets looped forever and the filter's warm-up would click at every wrap.
    return lowpass_loop(pad, lambda i, nn: 820.0)


def _music_bell(bar_index, freq):
    """One struck partial-stack bell, same voice as the salvage pickup."""
    dur = BAR * 1.6
    n = n_samples(dur)
    shape = env(n, 0.004, 0.9, curve=2.2)
    body = mix(
        gain(tone(freq, dur, "sine"), 1.0),
        gain(tone(freq * 2.01, dur, "sine"), 0.42),
        gain(tone(freq * 3.02, dur, "sine"), 0.16),
    )
    return apply(body, shape), n_samples(bar_index * BAR)


def s_music_calm():
    """Exploration bed: pad chords and two sparse bells across eight bars."""
    n = n_samples(LOOP_SECONDS)
    out = _music_bed()
    # Two bells only. A third started sounding like a melody, and a melody you
    # cannot turn off becomes the thing you hear instead of the game.
    for bar, freq in [(0, 587.33), (4, 698.46)]:   # D5 over Dm, F5 over F
        layer, at = _music_bell(bar, freq)
        place(out, gain(layer, 0.20), at)
    assert len(out) == n
    return normalize(out, 0.62)


def s_music_combat():
    """Same eight bars with the top half switched on: arpeggio + pulse."""
    n = n_samples(LOOP_SECONDS)
    out = _music_bed()

    # 16th-note arpeggio, one octave up, rolling through each chord's tones.
    step = BEAT / 4.0
    steps = int(round(LOOP_SECONDS / step))
    note_dur = step * 1.8
    for s in range(steps):
        t = s * step
        chord = PROGRESSION[int(t / (BAR * 2.0)) % len(PROGRESSION)]
        # Up-down-up figure rather than a straight run: a straight run turns
        # into an audible siren at this tempo.
        pattern = [0, 1, 2, 1]
        f = chord[pattern[s % len(pattern)]] * 2.0
        if s % 8 == 7:
            f *= 2.0                       # a small lift off the top of each beat pair
        note = apply(tone(f, note_dur, "square"), env(n_samples(note_dur), 0.002, 0.055, curve=3.2))
        place(out, gain(note, 0.085), n_samples(t))

    # Pulse percussion. Kick on 1 and 3, closed hat on the 8ths.
    for bar in range(BARS):
        for beat in (0, 2):
            kn = n_samples(0.22)
            kick = apply(sweep(kn, 128, 44, "sine", curve=0.55), env(kn, 0.001, 0.05, curve=3.0))
            place(out, gain(kick, 0.42), n_samples(bar * BAR + beat * BEAT))
        for eighth in range(8):
            hn = n_samples(0.05)
            hat = apply(highpass(noise(hn), 6000), env(hn, 0.0004, 0.010, curve=4.0))
            place(out, gain(hat, 0.10 if eighth % 2 else 0.16),
                  n_samples(bar * BAR + eighth * BEAT * 0.5))

    assert len(out) == n
    return normalize(soft_clip(out), 0.72)


def s_klaxon():
    """Raiders on intercept: a hard three-pulse alert. Distinct from `alarm`,
    which means your own shields — this one means somebody wants your cargo."""
    n = n_samples(1.5)
    out = [0.0] * n
    phase = 0.0
    for i in range(n):
        t = i / SR
        pulse = int(t / 0.36) % 2 == 0 and t < 1.15
        f = 340.0 + 120.0 * math.sin(2 * math.pi * 11.0 * t)
        phase += 2.0 * math.pi * f / SR
        out[i] = (math.sin(phase) + 0.45 * math.sin(3 * phase)) * (1.0 if pulse else 0.0)
    body = apply(out, env(n, 0.004, 0.9, curve=1.1))
    sub = apply(sweep(n, 92, 60, "sine"), env(n, 0.01, 0.6, curve=1.5))
    return normalize(soft_clip(mix(gain(body, 0.8), gain(sub, 0.7))), 0.8)


SOUNDS = {
    "music_calm.wav": s_music_calm,
    "music_combat.wav": s_music_combat,
    "klaxon.wav": s_klaxon,
    "tap.wav": s_tap,
    "dock.wav": s_dock,
    "boss_wake.wav": s_boss_wake,
    "sweep.wav": s_sweep,
    "plate.wav": s_plate,
    "weld.wav": s_weld,
    "phase.wav": s_phase,
    "equip.wav": s_equip,
    "alarm.wav": s_alarm,
    "warp.wav": s_warp,
    "fire.wav": s_fire,
    "hit.wav": s_hit,
    "explode.wav": s_explode,
    "pickup.wav": s_pickup,
    "count.wav": s_count,
    "crack.wav": s_crack,
    "breach.wav": s_breach,
    "vortex.wav": s_vortex,
    "ambient.wav": s_ambient,
}


# Buffers that get looped forever, and so must not click at the wrap. Checked
# on every regeneration rather than trusted: a seam click is the kind of defect
# that is obvious once you notice it and invisible until you do.
SEAMLESS = ("music_calm.wav", "music_combat.wav")


if __name__ == "__main__":
    random.seed(7)  # deterministic output across regenerations
    print("Generating Pyxis SFX ->", OUT)
    failures = []
    lengths = {}
    for name, fn in SOUNDS.items():
        buf = fn()
        write(name, buf)
        if name in SEAMLESS:
            lengths[name] = len(buf)
            step, typical = seam_step(buf)
            ok = step <= max(typical * 2.0, 0.01)
            print("    seam %.4f vs p99 step %.4f -> %s" % (step, typical, "OK" if ok else "CLICK"))
            if not ok:
                failures.append("%s clicks at its loop point" % name)

    # The two music layers are crossfaded against each other mid-phrase, which
    # only works while they stay sample-aligned forever.
    if len(set(lengths.values())) > 1:
        failures.append("music layers differ in length: %s" % lengths)

    if failures:
        raise SystemExit("FAILED:\n  " + "\n  ".join(failures))
    print("done")

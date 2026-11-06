#!/usr/bin/env python3
"""
Retro Swim -- procedural chiptune audio generator
=================================================

HOW TO REGENERATE
    python3 tools/gen_audio.py                # (re)write every file in game/assets/audio/
    python3 tools/gen_audio.py dive cheer     # only these sounds (names = file names w/o .wav)
    python3 tools/gen_audio.py --list         # list every sound name
    python3 tools/gen_audio.py --out /tmp/x   # write somewhere else

    Then re-import in Godot (open the editor, or `godot --headless --path game --import`).

Requirements: Python 3.8+, standard library only (numpy is NOT needed).
Output: 16-bit mono PCM .wav at 22050 Hz. Every random source uses a fixed seed, so
running the script twice gives byte-identical files.

HOW IT WORKS
  * Oscillators: band-limited (polyBLEP) pulse waves at 12.5 / 25 / 50 % duty, a
    4-bit-stepped NES-style triangle, sine, LFSR noise and white noise. Pitch glides,
    delayed vibrato and fast chord arpeggios are supported.
  * Envelopes: ADSR and percussive attack/exponential-decay.
  * Filters: one-pole low/high-pass and a TPT state-variable filter (sweepable).
  * Music is written below as tracker-style note strings, one string per channel:
        "C5:2"      C in octave 5 held for 2 sixteenth-note steps
        "-:4"       rest for 4 steps          "~:2"  tie: extend the previous note
        "E4+G4+C5"  chord, played as a fast chiptune arpeggio
        "|"         bar line (bar lengths are checked, so typos are caught)
    Drum channels use letters: K kick, S snare, H closed hat, O open hat, C crash,
    T timpani/tom, R roll (soft snare), P clap; lower case = half volume; "K+H" = both.
  * Looping tracks are rendered into a buffer of exactly the loop length; note tails,
    echoes and drum decays that run past the end wrap around to the start, and the
    looping filters run twice around the buffer. The loop point is therefore seamless.
    The Sfx autoload (src/autoload/sfx.gd) sets the loop points at runtime.
  * Levels: SFX peak at about -3 dBFS (quieter for tiny, constantly repeated sounds such
    as "stroke" and for piercing sustained tones). Music gets a gentle soft-clip on its
    rarest peaks and is then loudness-matched (RMS above 150 Hz), which lands the peaks
    at roughly -7..-10 dBFS; "race" sits 3 dB lower so SFX cut through.

All melodies here are original compositions.
"""

import argparse
import math
import os
import random
import sys
import wave
from array import array

SR = 22050
TAU = 2.0 * math.pi
HERE = os.path.dirname(os.path.abspath(__file__))
DEFAULT_OUT = os.path.normpath(os.path.join(HERE, '..', 'game', 'assets', 'audio'))


# =============================================================================
# Basic helpers
# =============================================================================

_NOTE = {'C': 0, 'D': 2, 'E': 4, 'F': 5, 'G': 7, 'A': 9, 'B': 11}
_NAMES = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B']


def midi(name):
    """'C4' -> 60, 'F#3' -> 54, 'Bb2' -> 46."""
    s = _NOTE[name[0].upper()]
    i = 1
    while i < len(name) and name[i] in '#b':
        s += 1 if name[i] == '#' else -1
        i += 1
    return 12 * (int(name[i:]) + 1) + s


def nn(m):
    """MIDI number -> note name ('C#2')."""
    return '%s%d' % (_NAMES[m % 12], m // 12 - 1)


def mtof(m):
    return 440.0 * 2.0 ** ((m - 69) / 12.0)


def hz(name):
    return mtof(midi(name))


def secs(t):
    return int(round(t * SR))


def zeros(n):
    return [0.0] * n


def mul(a, b):
    return [x * y for x, y in zip(a, b)]


def scale(a, g):
    return [x * g for x in a]


def mix_into(dst, src, at=0, gain=1.0, mode='extend'):
    """Add src*gain into dst starting at sample `at`.
    mode: 'extend' grows dst, 'clip' drops overflow, 'wrap' wraps around (loops)."""
    n = len(src)
    if n == 0:
        return dst
    if mode == 'wrap':
        L = len(dst)
        at %= L
        i = 0
        while i < n:
            j = (at + i) % L
            k = min(n - i, L - j)
            dst[j:j + k] = [p + q * gain for p, q in zip(dst[j:j + k], src[i:i + k])]
            i += k
        return dst
    if mode == 'extend' and at + n > len(dst):
        dst.extend([0.0] * (at + n - len(dst)))
    end = min(len(dst), at + n)
    if end > at:
        dst[at:end] = [p + q * gain for p, q in zip(dst[at:end], src[:end - at])]
    return dst


def peak(x):
    return max(max(x), -min(x)) if x else 0.0


def normalize(x, peak_db):
    m = peak(x) or 1.0
    g = 10.0 ** (peak_db / 20.0) / m
    return [v * g for v in x]


def fade_edges(x, fin=0.001, fout=0.006):
    n = len(x)
    a, b = min(n // 4, secs(fin)), min(n // 4, secs(fout))
    for i in range(a):
        x[i] *= i / a
    for i in range(b):
        x[n - 1 - i] *= i / b
    return x


# =============================================================================
# Oscillators
# =============================================================================

def freq_track(n, f0, f1=None, glide=None, vib=None, arp=None, arp_rate=50.0):
    """Per-sample phase increment (cycles / sample).
    f0 -> f1 exponential glide over `glide` seconds (default: whole length).
    vib = (rate_hz, depth_semitones, delay_s[, ramp_s]).
    arp = list of frequency ratios cycled at arp_rate Hz (chiptune chords)."""
    if f1 is None:
        f1 = f0
    if f1 == f0 and not vib and not arp:
        return [f0 / SR] * n
    gn = max(1, secs(glide) if glide is not None else n)
    lr = math.log(f1 / f0) / gn if f1 != f0 else 0.0
    if vib:
        vr, vd, vdel = vib[0], vib[1], vib[2]
        vramp = max(1, secs(vib[3] if len(vib) > 3 else 0.12))
        vdn = secs(vdel)
        w = TAU * vr / SR
    arp_n = max(1, int(SR / arp_rate)) if arp else 1
    out = [0.0] * n
    for i in range(n):
        f = f0 * math.exp(lr * (i if i < gn else gn)) if lr else f0
        if vib and i > vdn:
            k = (i - vdn) / vramp
            if k > 1.0:
                k = 1.0
            f *= 2.0 ** (vd * k * math.sin(w * (i - vdn)) / 12.0)
        if arp:
            f *= arp[(i // arp_n) % len(arp)]
        out[i] = f / SR
    return out


def pulse(dts, duty=0.5, phase=0.0):
    """Band-limited (polyBLEP) pulse wave with the DC offset removed."""
    out = [0.0] * len(dts)
    ph = phase
    dc = 2.0 * duty - 1.0
    for i, dt in enumerate(dts):
        v = 1.0 if ph < duty else -1.0
        if ph < dt:
            t = ph / dt
            v += t + t - t * t - 1.0
        elif ph > 1.0 - dt:
            t = (ph - 1.0) / dt
            v += t * t + t + t + 1.0
        t2 = ph - duty
        if t2 < 0.0:
            t2 += 1.0
        if t2 < dt:
            t = t2 / dt
            v -= t + t - t * t - 1.0
        elif t2 > 1.0 - dt:
            t = (t2 - 1.0) / dt
            v -= t * t + t + t + 1.0
        out[i] = v - dc
        ph += dt
        if ph >= 1.0:
            ph -= 1.0
    return out


def triangle(dts, steps=16, phase=0.25):
    """Triangle wave; steps=16 gives the NES-style 4-bit staircase, 0 = smooth."""
    out = [0.0] * len(dts)
    ph = phase
    for i, dt in enumerate(dts):
        v = 4.0 * abs(ph - 0.5) - 1.0
        if steps:
            lv = int((v + 1.0) * 0.5 * steps)
            if lv > steps - 1:
                lv = steps - 1
            v = (lv + 0.5) / steps * 2.0 - 1.0
        out[i] = v
        ph += dt
        if ph >= 1.0:
            ph -= 1.0
    return out


def sine(dts, phase=0.0):
    out = [0.0] * len(dts)
    ph = phase
    for i, dt in enumerate(dts):
        out[i] = math.sin(TAU * ph)
        ph += dt
        if ph >= 1.0:
            ph -= 1.0
    return out


def lfsr_noise(dts, short=False, seed=1):
    """NES-style 15-bit LFSR noise; the 'frequency' is the shift-register clock."""
    out = [0.0] * len(dts)
    reg = (seed * 7919) & 0x7FFF or 1
    tap = 6 if short else 1
    ph = 0.0
    v = 1.0
    for i, dt in enumerate(dts):
        ph += dt if dt < 1.0 else 1.0
        while ph >= 1.0:
            ph -= 1.0
            fb = (reg ^ (reg >> tap)) & 1
            reg = (reg >> 1) | (fb << 14)
            v = 1.0 if reg & 1 else -1.0
        out[i] = v
    return out


def white(n, seed):
    r = random.Random(seed)
    return [r.uniform(-1.0, 1.0) for _ in range(n)]


def osc(n, f0, f1=None, wave='pulse', duty=0.5, glide=None, vib=None, arp=None,
        arp_rate=50.0, seed=1, steps=16):
    dts = freq_track(n, f0, f1, glide, vib, arp, arp_rate)
    if wave == 'pulse':
        return pulse(dts, duty)
    if wave == 'tri':
        return triangle(dts, steps)
    if wave == 'sine':
        return sine(dts)
    if wave == 'noise':
        return lfsr_noise(dts, False, seed)
    if wave == 'metal':
        return lfsr_noise(dts, True, seed)
    raise ValueError('unknown wave %r' % wave)


# =============================================================================
# Envelopes & filters
# =============================================================================

def adsr(n, a, d, s, r, gate=None):
    """ADSR envelope (a, d, r in seconds). `gate` = sample index where release starts
    (default n - release). Curves are quadratic so every segment ends exactly."""
    an, dn, rn = max(1, secs(a)), max(1, secs(d)), max(1, secs(r))
    g = n - rn if gate is None else gate
    out = [0.0] * n

    def level(i):
        if i < an:
            return i / an
        j = i - an
        if j < dn:
            u = 1.0 - j / dn
            return s + (1.0 - s) * u * u
        return s

    for i in range(min(g, n)):
        out[i] = level(i)
    if g < n:
        lg = level(g) if g > 0 else 0.0
        for i in range(max(g, 0), n):
            j = i - g
            if j < rn:
                u = 1.0 - j / rn
                out[i] = lg * u * u
    return out


def perc(n, attack=0.002, tau=0.05, end_fade=0.004):
    """Linear attack then exponential decay (time constant tau); fades to 0 at the end."""
    an = max(1, secs(attack))
    k = 1.0 / (tau * SR)
    fn = max(1, min(n // 4 or 1, secs(end_fade)))
    out = [0.0] * n
    for i in range(n):
        e = i / an if i < an else math.exp(-(i - an) * k)
        if i >= n - fn:
            e *= (n - i) / fn
        out[i] = e
    return out


def lowpass(x, fc, fc1=None, wrap=False):
    """One-pole low-pass, optional exponential cutoff sweep fc -> fc1.
    wrap=True runs twice around the buffer so a loop stays seamless."""
    n = len(x)
    y = [0.0] * n
    s = 0.0
    lr = math.log(fc1 / fc) / max(1, n - 1) if fc1 else 0.0
    a = 1.0 - math.exp(-TAU * fc / SR)
    for _ in range(2 if wrap else 1):
        for i in range(n):
            if lr:
                a = 1.0 - math.exp(-TAU * fc * math.exp(lr * i) / SR)
            s += a * (x[i] - s)
            y[i] = s
    return y


def highpass(x, fc, wrap=False):
    lp = lowpass(x, fc, wrap=wrap)
    return [a - b for a, b in zip(x, lp)]


def svf(x, fc, q=0.707, mode='bp', fc1=None, wrap=False):
    """TPT state-variable filter (stable at any cutoff). mode: 'lp', 'bp' (unity peak), 'hp'."""
    n = len(x)
    y = [0.0] * n
    k = 1.0 / q
    lr = math.log(fc1 / fc) / max(1, n - 1) if fc1 else 0.0
    m = {'lp': 0, 'bp': 1, 'hp': 2}[mode]

    def coefs(f):
        g = math.tan(math.pi * min(f, SR * 0.45) / SR)
        a1 = 1.0 / (1.0 + g * (g + k))
        return a1, g * a1, g * g * a1

    a1, a2, a3 = coefs(fc)
    ic1 = ic2 = 0.0
    for _ in range(2 if wrap else 1):
        for i in range(n):
            if lr and (i & 7) == 0:
                a1, a2, a3 = coefs(fc * math.exp(lr * i))
            v0 = x[i]
            v3 = v0 - ic2
            v1 = a1 * ic1 + a2 * v3
            v2 = ic2 + a2 * ic1 + a3 * v3
            ic1 = 2.0 * v1 - ic1
            ic2 = 2.0 * v2 - ic2
            y[i] = v2 if m == 0 else (k * v1 if m == 1 else v0 - k * v1 - v2)
    return y


def periodic_lfo(n, cycles, seed):
    """Smooth random modulation in [-1, 1] that repeats exactly every n samples
    (a sum of sines with integer cycle counts), for seamless loops."""
    r = random.Random(seed)
    comps = [(c, r.uniform(0.0, TAU), r.uniform(0.5, 1.0)) for c in cycles]
    tot = sum(a for _, _, a in comps)
    w = TAU / n
    return [sum(a * math.sin(w * c * i + p) for c, p, a in comps) / tot for i in range(n)]


# =============================================================================
# Drum kit (each hit is synthesised once and cached)
# =============================================================================

def _kick():
    n = secs(0.18)
    x = mul(osc(n, 170.0, 44.0, 'tri', glide=0.08, steps=0), perc(n, 0.001, 0.07))
    m = secs(0.008)
    click = mul(lowpass(white(m, 3), 2500.0), perc(m, 0.0005, 0.002))
    return mix_into(x, click, 0, 0.5)


def _snare(tau=0.055, dur=0.18, seed=5):
    n = secs(dur)
    nz = mul(highpass(osc(n, SR * 0.8, wave='noise', seed=seed), 700.0), perc(n, 0.001, tau))
    body = mul(osc(n, 240.0, 150.0, 'tri', glide=0.05, steps=0), perc(n, 0.001, 0.03))
    return [a * 0.8 + b * 0.6 for a, b in zip(nz, body)]


def _hat(tau, dur, seed):
    n = secs(dur)
    nz = highpass(highpass(white(n, seed), 6000.0), 6000.0)
    return mul(nz, perc(n, 0.0005, tau))


def _crash():
    n = secs(1.3)
    nz = lowpass(highpass(white(n, 21), 3000.0), 9000.0)
    return mul(nz, perc(n, 0.001, 0.4))


def _tom():
    n = secs(0.8)
    x = mul(osc(n, 100.0, 80.0, 'tri', glide=0.2, steps=0), perc(n, 0.004, 0.28))
    thump = mul(lowpass(white(n, 31), 300.0), perc(n, 0.002, 0.05))
    return [a + b * 1.5 for a, b in zip(x, thump)]


def _clap():
    n = secs(0.2)
    nz = svf(white(n, 41), 1400.0, 1.0, 'bp')
    env = zeros(n)
    for t in (0.0, 0.011, 0.022):
        mix_into(env, perc(secs(0.012), 0.0005, 0.004), secs(t), 1.0, 'clip')
    mix_into(env, perc(n - secs(0.03), 0.001, 0.05), secs(0.03), 0.8, 'clip')
    return mul(nz, env)


_DRUM_DEFS = {
    'K': (_kick, 1.0),
    'S': (_snare, 0.8),
    'H': (lambda: _hat(0.012, 0.05, 11), 0.35),
    'O': (lambda: _hat(0.07, 0.25, 12), 0.35),
    'C': (_crash, 0.5),
    'T': (_tom, 0.9),
    'R': (lambda: _snare(0.03, 0.12, 9), 0.45),
    'P': (_clap, 0.6),
}
_DRUM_CACHE = {}


def drum(letter):
    if letter not in _DRUM_CACHE:
        fn, pk = _DRUM_DEFS[letter]
        _DRUM_CACHE[letter] = normalize(fn(), 20.0 * math.log10(pk))
    return _DRUM_CACHE[letter]


# =============================================================================
# Sequencer
# =============================================================================

def inst(**kw):
    """Channel / instrument definition with sensible defaults."""
    t = dict(wave='pulse', duty=0.5, a=0.004, d=0.08, s=0.7, r=0.05, vol=0.3, gate=0.9,
             vib=None, arp_rate=50.0, detune=0.0, octave=0, echo=None, scoop=None,
             steps=16, bar=16, drums=False, seq='')
    t.update(kw)
    return t


def drums(seq, vol=0.4, bar=16):
    return inst(drums=True, seq=seq, vol=vol, bar=bar)


def parse_seq(text, bar=16, is_drums=False):
    """-> ([(start_step, length_steps, [midi...] | [drum letters]), ...], total_steps)"""
    events = []
    pos = 0.0
    bars = []
    cur = 0.0
    ntok = 0
    for tok in text.replace('|', ' | ').split():
        if tok == '|':
            if ntok:
                bars.append(cur)
            cur, ntok = 0.0, 0
            continue
        name, _, ln = tok.partition(':')
        ln = float(ln) if ln else 1.0
        ntok += 1
        if name == '~':
            s, l, v = events[-1]
            events[-1] = (s, l + ln, v)
        elif name not in ('-', '.'):
            parts = name.split('+')
            events.append((pos, ln, parts if is_drums else [midi(p) for p in parts]))
        pos += ln
        cur += ln
    if ntok:
        bars.append(cur)
    for i, b in enumerate(bars[:-1]):
        if abs(b - bar) > 1e-9:
            raise ValueError('bar %d has %g steps (expected %d) in: %s...' % (i + 1, b, bar, text[:70]))
    return events, pos


def render_track(tr, sps, n_total, mode, transpose=0):
    buf = zeros(n_total)
    events, total = parse_seq(tr['seq'], tr['bar'], tr['drums'])
    vol = tr['vol']
    if tr['drums']:
        for st, _, hits in events:
            at = int(round(st * sps))
            for h in hits:
                mix_into(buf, drum(h.upper()), at, vol * (0.5 if h.islower() else 1.0), mode)
    else:
        rn = secs(tr['r'])
        det = 2.0 ** (tr['detune'] / 1200.0)
        shift = transpose + 12 * tr['octave']
        xfade = secs(0.004)
        for idx, (st, ln, notes) in enumerate(events):
            at = int(round(st * sps))
            gate_n = max(1, int(round(ln * sps * tr['gate'])))
            n = gate_n + rn
            # Channels are monophonic like real chip voices: the next note cuts this
            # note's release tail (with a tiny fade so there is no click).
            if idx + 1 < len(events):
                nxt = int(round(events[idx + 1][0] * sps))
            elif mode == 'wrap':
                nxt = int(round(events[0][0] * sps)) + n_total
            else:
                nxt = None
            cut = nxt is not None and at + n > nxt + xfade
            if cut:
                n = nxt - at + xfade
            ms = [m + shift for m in notes]
            f = mtof(ms[0]) * det
            arp = [2.0 ** ((m - ms[0]) / 12.0) for m in ms] if len(ms) > 1 else None
            f0, glide = f, None
            if tr['scoop']:
                f0 = f * 2.0 ** (-tr['scoop'][0] / 12.0)
                glide = tr['scoop'][1]
            w = osc(n, f0, f, tr['wave'], tr['duty'], glide=glide, vib=tr['vib'], arp=arp,
                    arp_rate=tr['arp_rate'], seed=idx + 1, steps=tr['steps'])
            env = adsr(gate_n + rn, tr['a'], tr['d'], tr['s'], tr['r'], gate_n)[:n]
            if cut:
                for i in range(xfade):
                    env[n - 1 - i] *= i / xfade
            mix_into(buf, mul(w, env), at, vol, mode)
    if tr['echo']:
        steps_, g = tr['echo'][0], tr['echo'][1]
        taps = tr['echo'][2] if len(tr['echo']) > 2 else 1
        dn = int(round(steps_ * sps))
        dry = buf[:]
        for t in range(1, taps + 1):
            mix_into(buf, dry, dn * t, g ** t, mode)
    return buf, total


def song(bpm, tracks, loop=False, tail=0.3, transpose=0, steps=None, stats=None):
    """Render a multi-channel sequence. One step = one 16th note."""
    sps = SR * 60.0 / bpm / 4.0
    if steps is None:
        steps = max(parse_seq(t['seq'], t['bar'], t['drums'])[1] for t in tracks)
    L = int(round(steps * sps))
    n = L if loop else L + secs(tail)
    mode = 'wrap' if loop else 'clip'
    out = zeros(n)
    for i, tr in enumerate(tracks):
        buf, total = render_track(tr, sps, n, mode, 0 if tr['drums'] else transpose)
        if loop and abs(total - steps) > 1e-9:
            raise ValueError('track %d is %g steps, loop is %g' % (i, total, steps))
        if stats is not None:
            stats.append(math.sqrt(sum(v * v for v in buf) / len(buf)))
        out = [a + b for a, b in zip(out, buf)]
    return out


# =============================================================================
# Sound registry
# =============================================================================

SOUNDS = {}   # name -> (fn, peak_db, loop, loudness_db)


def sound(name, peak_db=-3.0, loop=False, loudness=None):
    """Register a generator. peak_db = target peak (or the peak ceiling when a
    loudness target is given, which is how the music tracks are levelled)."""
    def deco(fn):
        SOUNDS[name] = (fn, peak_db, loop, loudness)
        return fn
    return deco


def layer(dur, parts):
    """parts: list of (buffer, at_seconds, gain)."""
    out = zeros(secs(dur))
    for buf, at, g in parts:
        mix_into(out, buf, secs(at), g, 'clip')
    return out


def chirp(dur, f0, f1, wave='sine', duty=0.5, tau=None, seed=1):
    n = secs(dur)
    return mul(osc(n, f0, f1, wave, duty, seed=seed), perc(n, 0.001, tau or dur / 3.0))


def bubbles(count, start, end, seed, lo=500.0, hi=900.0):
    r = random.Random(seed)
    parts = []
    for _ in range(count):
        f = r.uniform(lo, hi)
        parts.append((chirp(0.025, f, f * 2.2, 'sine', tau=0.01), r.uniform(start, end), r.uniform(0.3, 0.7)))
    return parts


# ----------------------------------------------------------------------------- UI

@sound('click', -4.0)
def s_click():
    n = secs(0.04)
    t = mul(osc(n, 1500.0, 1100.0, 'pulse', 0.125, glide=0.03), perc(n, 0.0005, 0.009))
    tick = mul(highpass(white(n, 101), 4000.0), perc(n, 0.0002, 0.002))
    return mix_into(t, tick, 0, 0.6)


@sound('back', -4.0)
def s_back():
    lead = inst(duty=0.25, a=0.002, d=0.05, s=0.5, r=0.03, vol=0.6, seq='E6:1 A5:2', echo=(1, 0.3))
    return song(220, [lead], tail=0.1)


@sound('confirm')
def s_confirm():
    lead = inst(duty=0.25, a=0.002, d=0.08, s=0.6, r=0.05, vol=0.55, seq='G5:1 C6:3', vib=(7.0, 0.15, 0.1))
    harm = inst(duty=0.125, a=0.002, d=0.08, s=0.5, r=0.05, vol=0.25, seq='E5:1 G5:3')
    return song(200, [lead, harm], tail=0.1)


@sound('error', -5.0)
def s_error():
    parts = []
    for at, ln, f in ((0.0, 0.09, 155.0), (0.13, 0.14, 131.0)):
        m = secs(ln)
        a = osc(m, f, wave='pulse', duty=0.5)
        b = osc(m, f * 1.04, wave='pulse', duty=0.25)
        env = adsr(m, 0.003, 0.02, 0.8, 0.02)
        parts.append(([(x * 0.6 + y * 0.5) * e for x, y, e in zip(a, b, env)], at, 1.0))
    return layer(0.29, parts)


@sound('card')
def s_card():
    m = secs(0.07)
    rise = mul(osc(m, 500.0, 1600.0, 'pulse', 0.125), adsr(m, 0.005, 0.02, 0.8, 0.02))
    swish = mul(svf(white(m, 7), 1500.0, 1.0, 'bp', fc1=5000.0), adsr(m, 0.02, 0.02, 0.8, 0.03))
    n = secs(0.3)
    ding1 = mul(osc(n, hz('C6'), wave='pulse', duty=0.25, vib=(6.0, 0.1, 0.08)), perc(n, 0.001, 0.09))
    ding2 = mul(osc(n, hz('G6'), wave='pulse', duty=0.125), perc(n, 0.001, 0.07))
    body = mul(osc(n, hz('C5'), wave='tri'), perc(n, 0.001, 0.06))
    return layer(0.4, [(rise, 0, 0.35), (swish, 0, 0.5), (ding1, 0.065, 0.5), (ding2, 0.065, 0.3),
                       (body, 0.065, 0.4)])


@sound('coins')
def s_coins():
    c1 = inst(duty=0.5, a=0.001, d=0.25, s=0.0, r=0.02, gate=1.0, vol=0.5, seq='B5:1 E6:5')
    c2 = inst(duty=0.25, a=0.001, d=0.22, s=0.0, r=0.02, gate=1.0, vol=0.3, seq='-:2 E6:1 B6:5')
    return song(272, [c1, c2], tail=0.12)


@sound('levelup')
def s_levelup():
    lead = inst(duty=0.25, a=0.002, d=0.1, s=0.6, r=0.12, vol=0.45, gate=0.95,
                vib=(7.0, 0.2, 0.08), echo=(2, 0.3), seq='C5 E5 G5 C6 E6 G6 C7:6')
    shim = inst(duty=0.125, a=0.002, d=0.2, s=0.4, r=0.12, vol=0.18, arp_rate=40.0,
                seq='-:6 C6+E6+G6:6')
    bass = inst(wave='tri', a=0.002, d=0.1, s=0.8, r=0.1, vol=0.5, seq='C3:6 C4:6')
    return song(300, [lead, shim, bass], tail=0.25)


@sound('commit')
def s_commit():
    lead = inst(duty=0.25, a=0.003, d=0.08, s=0.65, r=0.08, vol=0.4, gate=0.88,
                vib=(6.0, 0.18, 0.12), echo=(2, 0.25),
                seq='G5:1 A5:1 B5:1 C6:2 G5:1 E6:2 D6:1 C6:1 D6:1 E6:1 G6:4')
    harm = inst(duty=0.125, a=0.002, d=0.1, s=0.4, r=0.05, vol=0.16, gate=0.8, arp_rate=45.0,
                seq='-:3 C5+E5+G5:2 -:1 C5+E5+G5:2 B4+D5+G5:3 C5+E5+G5:5')
    bass = inst(wave='tri', a=0.002, d=0.05, s=0.9, r=0.05, vol=0.5, gate=0.85,
                seq='G3:3 C3:2 G3:1 C4:2 G2:3 C3:5')
    kit = drums('-:3 K+H:2 H:1 S:2 K:1 K:1 S:1 K+C:5', vol=0.4)
    return song(170, [lead, harm, bass, kit], tail=0.35)


@sound('injury')
def s_injury():
    lead = inst(duty=0.25, a=0.004, d=0.1, s=0.7, r=0.2, vol=0.45, gate=0.9, scoop=(0.5, 0.04),
                vib=(5.0, 0.35, 0.15), seq='E5:1 C5:1 A4:1 F4:6')
    harm = inst(duty=0.5, a=0.004, d=0.1, s=0.6, r=0.2, vol=0.18, gate=0.9,
                seq='C5:1 A4:1 E4:1 D4:6')
    bass = inst(wave='tri', a=0.003, d=0.1, s=0.8, r=0.2, vol=0.55, seq='A2:3 D2:6')
    return song(150, [lead, harm, bass], tail=0.3)


@sound('whistle', -8.0)
def s_whistle():
    n = secs(0.42)
    dts = freq_track(n, 2450.0, 2700.0, glide=0.04, vib=(32.0, 0.45, 0.0, 0.01))
    tone = [a * 0.7 + b * 0.25 for a, b in zip(sine(dts), pulse(dts, 0.5))]
    am = [0.75 + 0.25 * math.sin(TAU * 32.0 * i / SR) for i in range(n)]
    breath = scale(highpass(white(n, 9), 3000.0), 0.12)
    env = adsr(n, 0.012, 0.05, 0.85, 0.06)
    return [(t * m + b) * e for t, m, b, e in zip(tone, am, breath, env)]


# ----------------------------------------------------------------------------- race

@sound('beep_marks', -6.0)
def s_beep_marks():
    n = secs(0.42)
    a = osc(n, hz('E4'), wave='pulse', duty=0.5)
    b = osc(n, hz('E3'), wave='tri', steps=0)
    env = adsr(n, 0.005, 0.03, 0.9, 0.03)
    return [(x * 0.6 + y * 0.5) * e for x, y, e in zip(a, b, env)]


@sound('beep_start')
def s_beep_start():
    n = secs(0.35)
    f = hz('B5')
    a = osc(n, f, wave='pulse', duty=0.5)
    b = osc(n, f, wave='pulse', duty=0.25)
    c = osc(n, f * 2.0, wave='pulse', duty=0.125)
    env = adsr(n, 0.002, 0.02, 0.95, 0.02)
    return [(x * 0.5 + y * 0.35 + z * 0.15) * e for x, y, z, e in zip(a, b, c, env)]


@sound('lap', -9.0)
def s_lap():
    """Lap counter card flipping into the water at the far wall: a plastic slap + a little splash."""
    n = secs(0.16)
    knock = mul(osc(n, 420.0, 260.0, 'tri', glide=0.05), perc(n, 0.001, 0.025))
    slap = mul(svf(white(n, 31), 1800.0, 0.9, 'bp', fc1=900.0), perc(n, 0.001, 0.018))
    drip = chirp(0.05, 900.0, 1900.0, 'sine', tau=0.015)
    return layer(0.2, [(knock, 0, 0.7), (slap, 0, 0.6), (drip, 0.05, 0.25)])


@sound('bell', -6.0)
def s_bell():
    """The last-lap bell: a hand bell rung fast over the swimmer's head (inharmonic partials)."""
    def strike(dur, f0):
        m = secs(dur)
        out = zeros(m)
        for ratio, g, tau in ((1.0, 1.0, 0.35), (2.76, 0.5, 0.16), (5.40, 0.28, 0.08), (8.93, 0.14, 0.04)):
            mix_into(out, mul(osc(m, f0 * ratio, wave='sine'), perc(m, 0.001, tau)), 0, g, 'clip')
        return out
    parts = []
    for i, at in enumerate((0.0, 0.14, 0.28, 0.42, 0.56, 0.70)):
        parts.append((strike(0.6, 1318.0 if i % 2 == 0 else 1290.0), at, 0.9 if i % 2 == 0 else 0.7))
    return layer(1.3, parts)


@sound('dive')
def s_dive():
    m = secs(0.3)
    whoosh = mul(svf(white(m, 21), 400.0, 1.2, 'bp', fc1=1700.0), adsr(m, 0.24, 0.02, 1.0, 0.05))
    s = secs(0.5)
    sp = lowpass(lowpass(white(s, 22), 7000.0, fc1=600.0), 7000.0, fc1=600.0)
    splash = mul(sp, perc(s, 0.003, 0.12))
    body = mul(svf(white(s, 23), 400.0, 0.8, 'bp'), perc(s, 0.005, 0.18))
    t = secs(0.12)
    thump = mul(osc(t, 120.0, 45.0, 'tri', steps=0), perc(t, 0.001, 0.04))
    parts = [(whoosh, 0.0, 2.2), (splash, 0.28, 1.0), (body, 0.28, 0.6), (thump, 0.28, 0.7)]
    return layer(0.85, parts + bubbles(5, 0.45, 0.75, 24))


@sound('splash', -4.0)
def s_splash():
    n = secs(0.3)
    sp = lowpass(lowpass(white(n, 31), 6000.0, fc1=800.0), 6000.0, fc1=800.0)
    splash = mul(sp, perc(n, 0.002, 0.07))
    body = mul(lowpass(white(n, 32), 500.0), perc(n, 0.002, 0.05))
    drops = [(chirp(0.02, f, f * 2.0, tau=0.008), at, 0.25) for f, at in
             ((800.0, 0.06), (1050.0, 0.11), (900.0, 0.17))]
    return layer(0.32, [(splash, 0, 1.0), (body, 0, 0.8)] + drops)


@sound('stroke', -10.0)
def s_stroke():
    n = secs(0.07)
    pull = svf(white(n, 41), 1100.0, 0.9, 'bp', fc1=500.0)
    low = lowpass(white(n, 42), 400.0)
    env = adsr(n, 0.012, 0.05, 0.0, 0.004)
    return lowpass([(p + l * 1.5) * e for p, l, e in zip(pull, low, env)], 2500.0)


@sound('perfect', -4.0)
def s_perfect():
    dry = zeros(secs(0.22))
    for nm, at, ln in (('E6', 0.0, 0.035), ('B6', 0.035, 0.035), ('E7', 0.07, 0.12)):
        m = secs(ln + 0.02)
        tone = mul(osc(m, hz(nm), wave='pulse', duty=0.125), adsr(m, 0.001, 0.03, 0.5, 0.02, gate=secs(ln)))
        mix_into(dry, tone, secs(at), 1.0, 'clip')
    b = secs(0.08)
    body = mul(osc(b, hz('E5'), wave='tri'), perc(b, 0.001, 0.03))
    mix_into(dry, body, 0, 0.6, 'clip')
    return layer(0.4, [(dry, 0.0, 1.0), (dry, 0.07, 0.4), (dry, 0.14, 0.16)])


@sound('goal', -6.0)
def s_goal():
    # a goal (Retro Polo's GoalShow): a quick climb into a bright held chord, under a second
    lead = inst(duty=0.25, a=0.002, d=0.08, s=0.65, r=0.1, vol=0.45, gate=0.9,
                vib=(7.0, 0.15, 0.1), echo=(1, 0.25), seq='G5 C6 E6 G6:2 E6:1 C7:7')
    harm = inst(duty=0.125, a=0.002, d=0.1, s=0.5, r=0.1, vol=0.16, arp_rate=45.0,
                seq='-:5 C6+E6+G6:1 -:1 C6+E6+G6:6')
    bass = inst(wave='tri', a=0.002, d=0.08, s=0.85, r=0.08, vol=0.5, seq='C3:2 G3:3 C4:1 C3:7')
    kit = drums('K:2 h:3 S:1 K+C:7', vol=0.3)
    return song(300, [lead, harm, bass, kit], tail=0.2)


def _metal(dur, f0, partials, seed):
    """A struck metal bar: inharmonic partials (ratio, gain, decay) over a noise crack."""
    m = secs(dur)
    out = zeros(m)
    for ratio, g, tau in partials:
        mix_into(out, mul(osc(m, f0 * ratio, wave='sine'), perc(m, 0.0005, tau)), 0, g, 'clip')
    c = secs(0.03)
    crack = mul(highpass(white(c, seed), 2500.0), perc(c, 0.0002, 0.006))
    mix_into(out, crack, 0, 0.9, 'clip')
    return out


@sound('clang', -3.0)
def s_clang():
    # BAR-IN! (BarHit): the ball off the inside of a post, a sharp high ring
    ring = _metal(0.55, 640.0, ((1.0, 1.0, 0.22), (2.32, 0.7, 0.12), (3.87, 0.45, 0.07),
                                (5.13, 0.3, 0.05), (7.41, 0.18, 0.03)), 211)
    t = secs(0.06)
    knock = mul(osc(t, 420.0, 180.0, 'pulse', 0.25, glide=0.04), perc(t, 0.0005, 0.015))
    return layer(0.6, [(ring, 0.0, 1.0), (knock, 0.0, 0.5)])


@sound('bang', -3.0)
def s_bang():
    # BAR-DOWN! (BarHit): off the underside of the bar, deeper and heavier
    ring = _metal(0.7, 300.0, ((1.0, 1.0, 0.3), (2.11, 0.65, 0.16), (3.31, 0.45, 0.09),
                               (4.92, 0.28, 0.05), (6.7, 0.16, 0.03)), 223)
    t = secs(0.14)
    thump = mul(osc(t, 130.0, 45.0, 'tri', steps=0), perc(t, 0.001, 0.05))
    n = secs(0.12)
    body = mul(lowpass(white(n, 224), 1800.0), perc(n, 0.001, 0.03))
    return layer(0.75, [(ring, 0.0, 1.0), (thump, 0.0, 0.9), (body, 0.0, 0.5)])


@sound('score_tick', -9.0)
def s_score_tick():
    # the scoreboard's number going up: two soft blips
    c1 = inst(duty=0.25, a=0.001, d=0.06, s=0.0, r=0.02, gate=1.0, vol=0.5, seq='E6:1 A6:3')
    return song(300, [c1], tail=0.08)


@sound('good', -7.0)
def s_good():
    n = secs(0.11)
    a = osc(n, 830.0, 880.0, 'pulse', 0.5, glide=0.015)
    b = osc(n, 880.0, wave='tri', steps=0)
    return mul([x * 0.5 + y * 0.6 for x, y in zip(a, b)], perc(n, 0.002, 0.035))


@sound('miss', -4.0)
def s_miss():
    n = secs(0.24)
    a = osc(n, 140.0, 92.0, 'pulse', 0.5, glide=0.18)
    b = osc(n, 147.0, 97.0, 'pulse', 0.25, glide=0.18)
    tone = lowpass([x + y for x, y in zip(a, b)], 1500.0)
    tone = mul(tone, perc(n, 0.002, 0.1))
    m = secs(0.05)
    thud = mul(lowpass(white(m, 51), 300.0), perc(m, 0.001, 0.015))
    return layer(0.25, [(tone, 0, 1.4), (thud, 0, 0.8)])


@sound('breath', -9.0)
def s_breath():
    n = secs(0.2)
    nz = white(n, 61)
    f1 = svf(nz, 1100.0, 1.5, 'bp', fc1=2200.0)
    f2 = svf(nz, 2800.0, 2.0, 'bp')
    env = adsr(n, 0.035, 0.06, 0.7, 0.1)
    return [(a + b * 0.5) * e for a, b, e in zip(f1, f2, env)]


@sound('turn', -4.0)
def s_turn():
    t = secs(0.13)
    thud = mul(osc(t, 100.0, 42.0, 'tri', steps=0), perc(t, 0.001, 0.05))
    c = secs(0.02)
    click = mul(lowpass(white(c, 71), 1200.0), perc(c, 0.0005, 0.006))
    w = secs(0.3)
    whoosh = mul(svf(white(w, 72), 1600.0, 0.8, 'bp', fc1=450.0), adsr(w, 0.06, 0.1, 0.6, 0.12))
    return layer(0.42, [(thud, 0, 1.0), (click, 0, 0.7), (whoosh, 0.05, 1.1)] + bubbles(3, 0.2, 0.35, 73))


@sound('touch')
def s_touch():
    c = secs(0.012)
    click = mul(osc(c, 2800.0, wave='pulse', duty=0.125), perc(c, 0.0003, 0.003))
    tick = mul(highpass(white(c, 81), 3000.0), perc(c, 0.0002, 0.002))
    t = secs(0.12)
    thump = mul(osc(t, 190.0, 70.0, 'tri', steps=0), perc(t, 0.001, 0.035))
    b = secs(0.06)
    tock = mul(osc(b, 620.0, wave='sine'), perc(b, 0.001, 0.018))
    return layer(0.16, [(click, 0, 0.5), (tick, 0, 0.5), (thump, 0, 1.0), (tock, 0, 0.45)])


@sound('dq', -5.0)
def s_dq():
    n = secs(0.6)
    a = osc(n, 98.0, wave='pulse', duty=0.25)
    b = osc(n, 103.5, wave='pulse', duty=0.5)
    c = osc(n, 196.0, wave='pulse', duty=0.125)
    env = adsr(n, 0.004, 0.02, 0.95, 0.025)
    return [(x * 0.5 + y * 0.5 + z * 0.3) * e for x, y, z, e in zip(a, b, c, env)]


@sound('cheer')
def s_cheer():
    dur = 1.6
    n = secs(dur)
    r = random.Random(77)

    def amp(t):
        if t < 0.18:
            u = t / 0.18
            return u * u * (3 - 2 * u)
        if t < 0.75:
            return 1.0
        u = max(0.0, 1.0 - (t - 0.75) / (dur - 0.75))
        return u * u

    env = [amp(i / SR) for i in range(n)]
    swell = [1.0 + 0.18 * v for v in periodic_lfo(n, [3, 5, 7], 78)]
    roar = svf(white(n, 79), 700.0, 0.7, 'bp', fc1=1050.0)
    roar = [x * e * s for x, e, s in zip(roar, env, swell)]
    claps = zeros(n)
    for _ in range(900):
        t = r.uniform(0.0, dur - 0.02)
        if r.random() > amp(t):
            continue
        m = r.randint(40, 160)
        burst = [r.uniform(-1.0, 1.0) * math.exp(-j / (m * 0.3)) for j in range(m)]
        mix_into(claps, burst, secs(t), r.uniform(0.3, 1.0), 'clip')
    claps = svf(claps, 2200.0, 0.6, 'bp')
    parts = [(roar, 0, 1.0), (claps, 0, 0.9)]
    for i in range(3):   # chiptune "wooo!" voices
        ln = r.uniform(0.45, 0.7)
        m = secs(ln)
        f = r.uniform(300.0, 380.0)
        v = osc(m, f, f * 1.55, 'pulse', 0.5, glide=0.3, vib=(6.0, 0.4, 0.3))
        v = mul(lowpass(lowpass(v, 1400.0), 1400.0), adsr(m, 0.06, 0.1, 0.7, 0.2))
        parts.append((v, r.uniform(0.08, 0.4), 0.22))
    m = secs(0.35)   # a fan whistle
    wh = mul(osc(m, 1900.0, 2500.0, 'sine', glide=0.08, vib=(9.0, 0.2, 0.1)), adsr(m, 0.02, 0.05, 0.8, 0.08))
    parts.append((wh, 0.3, 0.12))
    return layer(dur, parts)


@sound('record')
def s_record():
    lead = inst(duty=0.25, a=0.006, d=0.1, s=0.75, r=0.2, vol=0.42, gate=0.92, scoop=(0.4, 0.03),
                vib=(5.5, 0.2, 0.15), seq='G4:1 C5:1 E5:1 G5:3 E5:1 G5:1 C6:8')
    harm = inst(duty=0.5, a=0.006, d=0.1, s=0.7, r=0.2, vol=0.2, gate=0.92,
                seq='E4:1 G4:1 C5:1 E5:3 C5:1 E5:1 G5:8')
    bass = inst(wave='tri', a=0.003, d=0.1, s=0.85, r=0.2, vol=0.55, seq='C3:6 G2:2 C3:8')
    kit = drums('S:1 S:1 S:1 K+S:3 S:1 S:1 K+C:8', vol=0.45)
    return song(160, [lead, harm, bass, kit], tail=0.4)


@sound('pb')
def s_pb():
    lead = inst(duty=0.125, a=0.002, d=0.06, s=0.6, r=0.1, vol=0.45, gate=0.9,
                vib=(8.0, 0.15, 0.08), echo=(1, 0.35, 2), seq='C5 E5 G5 B5 D6 E6 G6 B6 C7:4')
    bass = inst(wave='tri', a=0.002, d=0.08, s=0.8, r=0.1, vol=0.45, seq='C4:4 E4:4 G4:4')
    out = song(280, [lead, bass], tail=0.26)
    r = random.Random(91)
    for _ in range(8):
        m = secs(0.018)
        f = hz(r.choice(['C7', 'D7', 'E7', 'G7', 'A7']))
        blip = mul(osc(m, f, wave='pulse', duty=0.125), perc(m, 0.0005, 0.006))
        mix_into(out, blip, secs(r.uniform(0.15, 0.7)), 0.2, 'clip')
    return out


@sound('gear_up', -5.0)
def s_gear_up():
    lead = inst(duty=0.25, a=0.001, d=0.06, s=0.6, r=0.03, vol=0.6, seq='A5:1 E6:2', echo=(1, 0.3))
    return song(250, [lead], tail=0.08)


@sound('gear_down', -5.0)
def s_gear_down():
    lead = inst(duty=0.25, a=0.001, d=0.06, s=0.6, r=0.03, vol=0.6, seq='E6:1 A5:2', echo=(1, 0.3))
    return song(250, [lead], tail=0.08)


@sound('countdown', -5.0)
def s_countdown():
    n = secs(0.05)
    body = mul(osc(n, 1500.0, wave='tri', steps=0), perc(n, 0.0005, 0.01))
    m = secs(0.006)
    click = mul(osc(m, 3000.0, wave='pulse', duty=0.125), perc(m, 0.0003, 0.002))
    return layer(0.05, [(body, 0, 1.0), (click, 0, 0.4)])


@sound('gasp', -4.0)
def s_gasp():
    beep = song(300, [inst(duty=0.25, a=0.002, d=0.04, s=0.7, r=0.03, vol=0.5, seq='G6:1 D6:2',
                           vib=(14.0, 0.3, 0.02, 0.02))], tail=0.06)
    n = secs(0.16)
    inhale = mul(svf(white(n, 95), 1200.0, 1.8, 'bp', fc1=2600.0), adsr(n, 0.05, 0.04, 0.8, 0.05))
    return layer(0.26, [(beep, 0, 1.0), (inhale, 0.02, 0.35)])


# =============================================================================
# Music (original compositions)
# =============================================================================

@sound('music_menu', -5.0, loop=True, loudness=-21.5)
def m_menu():
    """126 BPM, 16 bars in D major (written in C, transposed +2). Bouncy, sunny."""
    lead = inst(duty=0.25, a=0.003, d=0.1, s=0.65, r=0.05, vol=0.30, gate=0.85,
                vib=(5.5, 0.18, 0.14), echo=(3, 0.3), seq='''
        | E5:2 G5:2 -:1 G5:1 A5:2 G5:2 E5:2 C5:2 D5:2
        | F5:3 E5:1 -:2 C5:2 A4:4 C5:2 D5:2
        | E5:2 E5:2 -:1 E5:1 D5:2 C5:2 A4:2 C5:2 E5:2
        | D5:6 B4:2 G4:2 -:2 G4:1 A4:1 B4:2
        | C5:2 E5:2 G5:2 C6:2 B5:2 G5:2 E5:2 G5:2
        | A5:3 G5:1 -:2 F5:2 A5:4 C6:2 A5:2
        | G5:2 F5:2 E5:2 D5:2 B4:2 D5:2 G5:2 F5:2
        | D5:8 -:4 G4:2 B4:2
        | C5:2 F5:2 -:1 F5:1 A5:2 -:1 A5:1 G5:2 F5:2 E5:2
        | D5:2 G5:2 -:1 G5:1 B5:2 -:1 B5:1 A5:2 G5:2 F5:2
        | E5:2 G5:2 B5:4 A5:2 G5:2 E5:4
        | A5:2 C6:2 -:2 B5:2 A5:2 E5:2 C5:2 E5:2
        | F5:3 F5:1 F5:2 E5:2 D5:2 F5:2 A5:4
        | G5:3 G5:1 G5:2 A5:2 B5:2 D6:2 B5:4
        | C6:4 G5:2 E5:2 G5:2 E5:2 C5:2 E5:2
        | D5:4 B4:2 D5:2 G5:4 F5:2 D5:2''')
    chords = ['C', 'F', 'Am', 'G', 'C', 'F', 'G', 'G7', 'F', 'G', 'Em', 'Am', 'Dm', 'G', 'C', 'G']
    voicing = {'C': 'E4+G4+C5', 'F': 'F4+A4+C5', 'Am': 'E4+A4+C5', 'G': 'D4+G4+B4',
               'G7': 'D4+F4+B4', 'Em': 'E4+G4+B4', 'Dm': 'D4+F4+A4'}
    root = {'C': 36, 'F': 41, 'Am': 45, 'G': 43, 'G7': 43, 'Em': 40, 'Dm': 38}
    harm = inst(duty=0.125, a=0.002, d=0.09, s=0.35, r=0.03, vol=0.2, gate=0.75, arp_rate=60.0,
                seq=' | '.join(' '.join('-:2 %s:2' % voicing[c] for _ in range(4)) for c in chords))

    def bounce(r):
        return ' '.join('%s:2' % nn(m) for m in (r, r + 12, r, r + 12, r, r + 12, r + 7, r + 12))

    bass = inst(wave='tri', a=0.002, d=0.05, s=0.9, r=0.02, vol=0.45, gate=0.8,
                seq=' | '.join(bounce(root[c]) for c in chords))
    groove = 'K+H:2 H:2 S+H:2 H:2 K+H:2 K+H:2 S+H:2 H:1 H:1'
    crash = 'K+C:2 H:2 S+H:2 H:2 K+H:2 K+H:2 S+H:2 H:1 H:1'
    fill = 'K+H:2 H:2 S+H:2 H:2 S:1 S:1 S:1 S:1 S:1 S:1 K+S:2'
    bars = [crash] + [groove] * 6 + [fill] + [crash] + [groove] * 6 + [fill]
    kit = drums(' | '.join(bars), vol=0.42)
    return song(126, [lead, harm, bass, kit], loop=True, transpose=2)


@sound('music_race', -5.0, loop=True, loudness=-24.5)
def m_race():
    """146 BPM, 16 bars in E minor. Driving and tense; mixed low so SFX cut through."""
    lead = inst(duty=0.25, a=0.003, d=0.1, s=0.7, r=0.05, vol=0.26, gate=0.88,
                vib=(6.0, 0.15, 0.15), echo=(3, 0.25), seq='''
        | B4:4 -:2 B4:2 E5:4 D5:2 B4:2
        | G4:6 A4:2 B4:8
        | C5:4 -:2 C5:2 E5:4 D5:2 C5:2
        | D5:6 E5:2 F#5:8
        | G5:4 -:2 G5:2 F#5:4 E5:2 D5:2
        | E5:6 D5:2 B4:8
        | C5:4 E5:4 G5:4 E5:4
        | D#5:8 F#5:4 B5:4
        | A5:3 A5:1 -:2 G5:2 E5:4 C5:4
        | A4:2 C5:2 E5:2 A5:2 G5:4 E5:4
        | B5:3 B5:1 -:2 A5:2 G5:4 E5:4
        | E5:2 G5:2 B5:2 E6:2 D6:4 B5:4
        | C6:4 B5:2 A5:2 G5:4 E5:4
        | D6:4 C6:2 B5:2 A5:4 F#5:4
        | F#5:2 D#5:2 B4:2 D#5:2 F#5:2 A5:2 B5:4
        | B5:8 -:4 D#5:2 F#5:2''')
    chords = ['Em', 'Em', 'C', 'D', 'Em', 'Em', 'C', 'B', 'Am', 'Am', 'Em', 'Em', 'C', 'D', 'B', 'B']
    voicing = {'Em': ['E4', 'G4', 'B4'], 'C': ['E4', 'G4', 'C5'], 'D': ['D4', 'F#4', 'A4'],
               'B': ['D#4', 'F#4', 'B4'], 'Am': ['E4', 'A4', 'C5']}
    root = {'Em': 40, 'C': 36, 'D': 38, 'B': 35, 'Am': 33}
    osti = inst(duty=0.125, a=0.001, d=0.07, s=0.2, r=0.02, vol=0.17, gate=0.7,
                seq=' | '.join(' '.join('%s:1' % voicing[c][i] for i in [0, 1, 2, 1] * 4) for c in chords))

    def gallop(r):
        a, o = nn(r), nn(r + 12)
        return '%s:2 %s:1 %s:1 %s:2 %s:2 %s:2 %s:1 %s:1 %s:2 %s:2' % (a, a, a, o, a, a, a, a, o, a)

    bass = inst(wave='tri', a=0.002, d=0.04, s=0.9, r=0.02, vol=0.5, gate=0.8,
                seq=' | '.join(gallop(root[c]) for c in chords))
    groove = 'K+H:2 H:2 K+S+H:2 H:2 K+H:2 H:1 H:1 K+S+H:2 H:2'
    crash = 'K+C:2 H:2 K+S+H:2 H:2 K+H:2 H:1 H:1 K+S+H:2 H:2'
    fill = 'K+H:2 H:2 K+S+H:2 H:2 S:1 S:1 S:1 S:1 S:1 S:1 S:1 S:1'
    bars = [crash] + [groove] * 6 + [fill] + [crash] + [groove] * 6 + [fill]
    kit = drums(' | '.join(bars), vol=0.4)
    return song(146, [lead, osti, bass, kit], loop=True)


@sound('music_dream', -5.0, loop=True, loudness=-21.5)
def m_dream():
    """84 BPM, 8 bars in Eb major (written in C, +3). Warm, hopeful, emotional."""
    lead = inst(duty=0.5, a=0.03, d=0.25, s=0.75, r=0.25, vol=0.28, gate=0.92,
                vib=(5.0, 0.22, 0.22), echo=(3, 0.3, 2), seq='''
        | C5:4 A4:2 C5:2 F5:6 E5:2
        | D5:4 B4:2 D5:2 G5:6 F5:2
        | E5:4 G5:2 B5:2 A5:4 G5:4
        | A5:10 G5:2 E5:4
        | F5:4 E5:2 D5:2 A5:6 G5:2
        | G5:4 F5:2 E5:2 D5:4 B4:4
        | C5:4 E5:4 G5:4 C6:4
        | B5:6 A5:2 G5:8''')
    # (first-half voicing, second-half voicing) per bar, 5 notes each, played 0-1-2-3-4-3-2-1
    halves = [
        ('F3 C4 F4 A4 C5',) * 2, ('G3 D4 G4 B4 D5',) * 2, ('E3 B3 E4 G4 B4',) * 2, ('A3 E4 A4 C5 E5',) * 2,
        ('D3 A3 D4 F4 A4',) * 2, ('G3 D4 G4 B4 D5',) * 2, ('C3 G3 C4 E4 G4',) * 2,
        ('G3 D4 G4 C5 D5', 'G3 D4 G4 B4 D5'),
    ]
    arp_bars = []
    for h in halves:
        cells = []
        for v in h:
            notes = v.split()
            cells.append(' '.join('%s:1' % notes[i] for i in (0, 1, 2, 3, 4, 3, 2, 1)))
        arp_bars.append(' '.join(cells))
    arp = inst(duty=0.25, a=0.002, d=0.3, s=0.0, r=0.06, vol=0.17, gate=1.0, seq=' | '.join(arp_bars))
    pad = inst(duty=0.125, a=0.4, d=0.5, s=0.8, r=0.5, vol=0.07, gate=0.95,
               seq='A4:16 | B4:16 | G4:16 | C5:16 | F4:16 | B4:16 | E4:16 | D5:16')
    bass = inst(wave='tri', a=0.01, d=0.3, s=0.75, r=0.2, vol=0.42, gate=0.95, seq='''
        | F2:6 F2:2 C3:8 | G2:6 G2:2 D3:8 | E2:6 E2:2 B2:8 | A2:6 A2:2 E3:8
        | D2:6 D2:2 A2:8 | G2:6 G2:2 D3:8 | C2:6 C2:2 G2:8 | G2:6 G2:2 D3:8''')
    soft = 'K:8 -:2 k:2 -:4'
    full = 'K:2 h:2 h:2 h:2 R:2 h:2 k:2 h:2'
    kit = drums(' | '.join([soft] * 4 + [full] * 4), vol=0.24)
    return song(84, [lead, arp, pad, bass, kit], loop=True, transpose=3)


@sound('music_victory', -5.0, loudness=-21.0)
def m_victory():
    """150 BPM, ~4 s win jingle in C major. Not looped."""
    lead = inst(duty=0.25, a=0.003, d=0.1, s=0.7, r=0.3, vol=0.38, gate=0.9, scoop=(0.3, 0.02),
                vib=(6.0, 0.2, 0.18), echo=(2, 0.25), bar=8,
                seq='G4:2 C5:2 E5:2 G5:2 | E5:2 G5:2 C6:4 | A5:2 B5:2 C6:2 D6:2 | E6:12')
    harm = inst(duty=0.125, a=0.003, d=0.1, s=0.5, r=0.3, vol=0.17, gate=0.9, arp_rate=40.0, bar=8,
                seq='E4:2 G4:2 C5:2 E5:2 | C5:2 E5:2 A5:4 | F5:2 G5:2 A5:2 B5:2 | C5+E5+G5:12')
    bass = inst(wave='tri', a=0.002, d=0.08, s=0.85, r=0.3, vol=0.45, gate=0.9, bar=8,
                seq='C3:4 C3:2 G2:2 | A2:4 A2:4 | F2:4 G2:4 | C3:4 C2:8')
    kit = drums('K+C:2 H:2 S:2 H:2 | K:2 H:2 S:2 S:1 S:1 | K:2 S:1 S:1 K:2 S:1 S:1 | K+C:12',
                vol=0.42, bar=8)
    return song(150, [lead, harm, bass, kit], tail=0.6)


@sound('music_anthem', -5.0, loudness=-21.5)
def m_anthem():
    """80 BPM, ~15.6 s stately podium/medal-ceremony theme in Bb major (written in C, -2)."""
    lead = inst(duty=0.25, a=0.02, d=0.2, s=0.8, r=0.3, vol=0.32, gate=0.94, scoop=(0.35, 0.04),
                vib=(5.0, 0.2, 0.25), echo=(2, 0.2), seq='''
        | C5:4 E5:3 D5:1 C5:4 G5:4
        | A5:4 G5:3 F5:1 E5:4 C5:4
        | D5:4 F5:3 E5:1 D5:4 B4:2 D5:2
        | E5:4 A5:4 G5:3 A5:1 B5:4
        | C6:12''')
    low = dict(lead)
    low.update(duty=0.5, vol=0.14, octave=-1, echo=None, detune=4.0)
    pad_a = inst(duty=0.5, a=0.08, d=0.3, s=0.8, r=0.35, vol=0.1, gate=0.97,
                 seq='E4:8 G4:8 | F4:8 E4:8 | F4:8 D4:8 | E4:8 D4:8 | E4:12')
    pad_b = inst(duty=0.125, a=0.08, d=0.3, s=0.8, r=0.35, vol=0.1, gate=0.97,
                 seq='G4:8 C5:8 | C5:8 G4:8 | A4:8 B4:8 | C5:8 B4:8 | G4:12')
    bass = inst(wave='tri', a=0.01, d=0.2, s=0.85, r=0.35, vol=0.45, gate=0.95,
                seq='C3:8 E2:8 | F2:8 G2:8 | D2:8 G2:8 | A2:8 G2:8 | C2:12')
    kit = drums('T:8 T:8 | T:8 T:8 | T:8 T:8 | T:8 T:4 r:1 r:1 R:1 R:1 | T+C:12', vol=0.42)
    return song(80, [lead, low, pad_a, pad_b, bass, kit], tail=1.4, transpose=-2)


@sound('crowd', -6.0, loop=True)
def m_crowd():
    """5 s seamless crowd murmur: band-limited noise, syllable-rate babble, slow swells,
    a few distinct shouts and a scattered clap cluster (all wrapped around the loop)."""
    L = secs(5.0)
    lo = svf(white(L, 101), 350.0, 0.7, 'bp', wrap=True)
    mid = svf(white(L, 102), 800.0, 1.2, 'bp', wrap=True)
    hi = svf(white(L, 103), 1800.0, 1.5, 'bp', wrap=True)
    babble1 = periodic_lfo(L, [17, 22, 27, 31], 104)   # 3.4 - 6.2 Hz
    babble2 = periodic_lfo(L, [19, 24, 29, 34], 105)
    swell = periodic_lfo(L, [1, 2, 3], 106)
    out = [(l * 0.8 + m * (0.65 + 0.35 * b1) + h * 0.4 * (0.6 + 0.4 * b2)) * (0.82 + 0.18 * s)
           for l, m, h, b1, b2, s in zip(lo, mid, hi, babble1, babble2, swell)]
    r = random.Random(107)
    for _ in range(12):   # individual voices standing out of the murmur
        ln = r.uniform(0.2, 0.5)
        n = secs(ln)
        nz = white(n, r.randint(1, 10 ** 6))
        v = [a + b for a, b in zip(svf(nz, r.uniform(550.0, 900.0), 3.0, 'bp'),
                                   svf(nz, r.uniform(1100.0, 1600.0), 3.0, 'bp'))]
        v = mul(v, adsr(n, 0.05, 0.1, 0.7, 0.15))
        mix_into(out, v, r.randint(0, L - 1), r.uniform(0.25, 0.45), 'wrap')
    for _ in range(2):   # scattered distant claps
        at = r.randint(0, L - 1)
        for _ in range(25):
            m = r.randint(40, 120)
            burst = [r.uniform(-1.0, 1.0) * math.exp(-j / (m * 0.3)) for j in range(m)]
            burst = svf(burst, 2000.0, 0.7, 'bp')
            mix_into(out, burst, at + r.randint(0, secs(0.6)), r.uniform(0.1, 0.25), 'wrap')
    return out


# =============================================================================
# Output
# =============================================================================

def write_wav(path, x):
    a = array('h', [max(-32768, min(32767, int(round(v * 32767.0)))) for v in x])
    if sys.byteorder == 'big':
        a.byteswap()
    with wave.open(path, 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(a.tobytes())


def db(v):
    return 20.0 * math.log10(v) if v > 0 else -120.0


def soft_clip(x, pct=0.999, knee=0.25):
    """Memoryless soft knee above the pct-quantile of |x| (touches ~0.1 % of samples,
    the rare coincident peaks). Memoryless, so loops stay seamless."""
    srt = sorted(abs(v) for v in x)
    t = srt[min(len(srt) - 1, int(len(srt) * pct))]
    k = knee * t
    out = []
    for v in x:
        a = abs(v)
        if a > t:
            a = t + k * math.tanh((a - t) / k)
            v = a if v > 0 else -a
        out.append(v)
    return out


def loudness(x):
    """Crude loudness: RMS of the signal above ~150 Hz (bass counts less, like the ear)."""
    h = highpass(x, 150.0)
    return math.sqrt(sum(v * v for v in h) / len(h))


def build(name):
    fn, peak_db, loop, loud_db = SOUNDS[name]
    x = fn()
    if loop:
        mean = sum(x) / len(x)
        x = [v - mean for v in x]
    else:
        x = fade_edges(x)
    if loud_db is None:
        return normalize(x, peak_db), loop
    x = soft_clip(x)
    gain = min(10.0 ** (loud_db / 20.0) / loudness(x), 10.0 ** (peak_db / 20.0) / peak(x))
    return [v * gain for v in x], loop


def main():
    ap = argparse.ArgumentParser(description='Generate Retro Swim chiptune audio.')
    ap.add_argument('names', nargs='*', help='only generate these sounds')
    ap.add_argument('--out', default=DEFAULT_OUT, help='output directory (default: %(default)s)')
    ap.add_argument('--list', action='store_true', help='list sound names and exit')
    args = ap.parse_args()
    if args.list:
        print('\n'.join(SOUNDS))
        return
    unknown = [n for n in args.names if n not in SOUNDS]
    if unknown:
        ap.error('unknown sound(s): %s' % ', '.join(unknown))
    os.makedirs(args.out, exist_ok=True)
    total = 0
    print('%-14s %7s %8s %7s %7s  %s' % ('name', 'secs', 'bytes', 'peak', 'rms', 'loop seam'))
    for name in (args.names or list(SOUNDS)):
        x, loop = build(name)
        path = os.path.join(args.out, name + '.wav')
        write_wav(path, x)
        size = os.path.getsize(path)
        total += size
        rms = math.sqrt(sum(v * v for v in x) / len(x))
        seam = ''
        if loop:
            # jump across the loop point compared with the typical sample-to-sample step
            step = sum(abs(x[i] - x[i - 1]) for i in range(1, len(x))) / (len(x) - 1)
            seam = 'jump %.4f (avg step %.4f)' % (abs(x[0] - x[-1]), step)
        print('%-14s %7.2f %8d %6.1fdB %6.1fdB  %s' % (name, len(x) / SR, size, db(peak(x)), db(rms), seam))
    print('total: %.2f MB in %s' % (total / 1048576.0, args.out))


if __name__ == '__main__':
    main()

# music.py: an original 150 BPM chiptune hype track, synthesized here (no licence needed).
# Writes build/music.wav and build/grid.json. The film is cut to this grid: beat 0.4 s, bar 1.6 s.
#
#   bars 0-3   intro: four-on-the-floor, filtered arp opening up
#   bars 4-5   build: snare roll, riser, half a beat of silence
#   bars 6-11  DROP 1 (9.6 s): the first goal
#   bars 12-15 breakdown, half-time: the coach's week
#   bars 16-19 build back: the season, the bracket, the shootout
#   bars 20-25 DROP 2 (32.0 s): achievements
#   bar  26    final slam (41.6 s), then ring-out
import json, wave
import numpy as np

SR = 48000
BPM = 150
B = 60 / BPM            # 0.4 s
BAR = 4 * B             # 1.6 s
S16 = B / 4             # 0.1 s
BARS = 29
DUR = BARS * BAR        # 46.4 s
N = int(DUR * SR)
rng = np.random.default_rng(11)

def T(d): return np.arange(int(d * SR)) / SR
def mf(m): return 440 * 2 ** ((m - 69) / 12)
def env(t, a, tau): return np.clip(t / a, 0, 1) * np.exp(-t / tau)

def noise(d, lo, hi):
    n = int(d * SR); X = np.fft.rfft(rng.standard_normal(n)); f = np.fft.rfftfreq(n, 1 / SR)
    X[(f < lo) | (f > hi)] = 0; y = np.fft.irfft(X, n); return y / (np.abs(y).max() + 1e-9)

def pulse(f, d, duty=0.25, bright=1.0, vib=0.0):
    t = T(d); ph = f * t + vib * np.sin(2 * np.pi * 5.5 * t) * np.clip(t / 0.15, 0, 1) / 5.5
    sq = np.where((ph % 1) < duty, 1.0, -1.0); sq -= sq.mean()
    return bright * sq + (1 - bright) * np.sin(2 * np.pi * ph)

def tri(f, d):
    t = T(d); ph = (f * t) % 1; return 4 * np.abs(ph - 0.5) - 1

# ---------- drums ----------
def kick():
    t = T(0.42); f = 48 + 120 * np.exp(-t / 0.028); ph = 2 * np.pi * np.cumsum(f) / SR
    return np.sin(ph) * env(t, 0.0015, 0.17) * 1.0 + 0.35 * noise(0.42, 1500, 6000) * np.exp(-t / 0.003)
def snare():
    t = T(0.3)
    return 0.75 * noise(0.3, 900, 9000) * env(t, 0.001, 0.07) + 0.55 * np.sin(2 * np.pi * 190 * t) * env(t, 0.001, 0.045)
def hat(open_=False):
    d = 0.25 if open_ else 0.06; t = T(d); return noise(d, 7000, 15000) * env(t, 0.0008, 0.07 if open_ else 0.014)
def crash():
    t = T(2.2); return noise(2.2, 3000, 14000) * env(t, 0.002, 0.7)
def riser(d):
    t = T(d); out = np.zeros(len(t)); seg = 24; L = len(t) // seg
    for k in range(seg):
        c = 300 * (9000 / 300) ** (k / (seg - 1)); y = noise(d, c * 0.6, c * 1.5)
        out[k * L:(k + 1) * L] = y[k * L:(k + 1) * L]
    # a rising pulse tone on top: the arcade "charging" sound
    f = 220 * (2 ** (3 * (t / d) ** 1.5)); ph = np.cumsum(f) / SR; sq = np.where((ph % 1) < 0.5, 1.0, -1.0)
    return (0.6 * out + 0.25 * sq) * (t / d) ** 2
def sub_drop():
    t = T(1.2); ph = 2 * np.pi * np.cumsum(np.geomspace(90, 30, len(t))) / SR; return np.sin(ph) * env(t, 0.004, 0.5)

# ---------- buses ----------
drums = np.zeros(N + 3 * SR); bass = np.zeros(N + 3 * SR); lead = np.zeros(N + 3 * SR)
arp = np.zeros(N + 3 * SR); fx = np.zeros(N + 3 * SR)
def put(bus, y, t, g=1.0):
    s = int(round(t * SR)); bus[s:s + len(y)] += g * y[:len(bus) - s]

KICK = kick(); SN = snare(); HC = hat(); HO = hat(True)
kicks = []
CH = [(57, [69, 72, 76]), (53, [65, 69, 72]), (48, [67, 72, 76]), (55, [67, 71, 74])]   # Am F C G (root midi, triad)

for bar in range(BARS):
    t0 = bar * BAR
    root, triad = CH[bar % 4]
    sec = ('intro' if bar < 4 else 'build1' if bar < 6 else 'drop1' if bar < 12 else 'break' if bar < 16
           else 'build2' if bar < 20 else 'drop2' if bar < 26 else 'end')
    # kick
    if sec in ('intro', 'build1', 'drop1', 'build2', 'drop2'):
        for b in range(4):
            if sec in ('build1', 'build2') and bar in (5, 19) and b == 3: continue   # the gap before the drop
            put(drums, KICK, t0 + b * B); kicks.append(t0 + b * B)
    elif sec == 'break':
        for b in (0, 2.5): put(drums, KICK, t0 + b * B, 0.9); kicks.append(t0 + b * B)
    elif sec == 'end' and bar == 26:
        put(drums, KICK, t0, 1.2); kicks.append(t0)
    # snare / claps
    if sec in ('drop1', 'drop2'):
        for b in (1, 3): put(drums, SN, t0 + b * B, 0.8)
    if sec == 'break': put(drums, SN, t0 + 2 * B, 0.7)
    if bar in (4, 18):
        for k in range(8): put(drums, SN, t0 + k * B / 2, 0.25 + 0.04 * k)
    if bar in (5, 19):
        for k in range(14): put(drums, SN, t0 + k * S16, 0.45 + 0.03 * k)
    # hats
    if sec in ('drop1', 'drop2'):
        for k in range(16):
            v = 0.32 if k % 2 else 0.18
            if k % 4 == 2: put(drums, HO, t0 + k * S16, 0.22)
            else: put(drums, HC, t0 + k * S16, v)
        if bar % 2 == 1:   # trap triplet roll at the end of every other bar
            for k in range(6): put(drums, HC, t0 + 3 * B + k * B / 6, 0.22)
    elif sec in ('intro', 'build2') and bar >= 2:
        for b in range(4): put(drums, HC, t0 + b * B + B / 2, 0.25)
    elif sec == 'break':
        for k in range(8): put(drums, HC, t0 + k * B / 2, 0.14)
    # crashes, risers, drops
    if bar in (6, 20, 22, 24): put(fx, crash(), t0, 0.5)
    if bar in (6, 20): put(fx, sub_drop(), t0, 0.9)
    if bar in (4, 18): put(fx, riser(2 * BAR - B / 2), t0, 0.5)
    # bass: offbeat pumping 8ths in the drops, long notes in the breakdown
    f = mf(root - 12)
    if sec in ('drop1', 'drop2'):
        for k in range(8):
            d = B / 2 * 0.9; y = (0.55 * pulse(f, d, 0.5, 0.8) + 0.9 * np.sin(2 * np.pi * f * T(d))) * env(T(d), 0.003, 0.25)
            put(bass, y, t0 + k * B / 2, 0.75 if k % 2 else 0.45)
    elif sec == 'break':
        d = BAR; y = (0.4 * tri(f, d) + 0.8 * np.sin(2 * np.pi * f * T(d))) * env(T(d), 0.01, 1.4); put(bass, y, t0, 0.8)
    elif sec in ('build1', 'build2'):
        for k in range(4):
            d = B * 0.9; y = np.sin(2 * np.pi * f * T(d)) * env(T(d), 0.003, 0.3); put(bass, y, t0 + k * B, 0.7)
    # arp: 16ths up and down the triad; the intro opens from sine to pulse
    if sec != 'end' or bar == 26:
        notes = triad + [triad[0] + 12, triad[1] + 12, triad[2], triad[1], triad[0] + 12]
        bright = {'intro': 0.15 + 0.2 * bar / 4, 'build1': 0.55 + 0.2 * (bar - 4), 'break': 0.35}.get(sec, 0.8)
        g = {'intro': 0.22, 'build1': 0.25, 'break': 0.2, 'end': 0.18}.get(sec, 0.16)
        steps = 16 if bar < 27 else 0
        for k in range(steps):
            m = notes[k % len(notes)] + (12 if sec in ('drop1', 'drop2') else 0)
            d = S16 * 0.95; y = pulse(mf(m), d, 0.125, bright) * env(T(d), 0.002, 0.05)
            put(arp, y, t0 + k * S16, g * (1.0 if bar < 26 else max(0, 1 - k / 16)))

# lead hook: 4 bars, (step, midi, length in 16ths)
HOOK = [
    [(0, 81, 2), (2, 84, 2), (4, 88, 2), (6, 86, 1), (7, 84, 1), (8, 81, 3), (11, 79, 1), (12, 81, 2), (14, 84, 2)],
    [(0, 84, 2), (2, 89, 2), (4, 88, 2), (6, 84, 2), (8, 81, 4), (12, 77, 2), (14, 79, 2)],
    [(0, 79, 2), (2, 84, 2), (4, 88, 2), (6, 91, 2), (8, 88, 3), (11, 86, 1), (12, 84, 2), (14, 86, 2)],
    [(0, 86, 2), (2, 83, 2), (4, 79, 2), (6, 83, 2), (8, 86, 4), (12, 88, 2), (14, 86, 1), (15, 83, 1)],
]
for bar in list(range(6, 12)) + list(range(20, 26)):
    for st, m, ln in HOOK[bar % 4]:
        d = ln * S16 * 0.92; t = T(d)
        y = pulse(mf(m), d, 0.25, 1.0, vib=0.25) * np.clip(t / 0.004, 0, 1) * (0.55 + 0.45 * np.exp(-t / 0.08))
        y *= np.clip((d - t) / 0.01, 0, 1)
        put(lead, y, bar * BAR + st * S16, 0.32)
        if bar >= 20: put(lead, pulse(mf(m - 12), d, 0.5, 1.0) * np.clip((d - t) / 0.01, 0, 1) * 0.6, bar * BAR + st * S16, 0.2)
# breakdown melody: slow, a sung line on a soft pulse
for bar in range(12, 16):
    root, triad = CH[bar % 4]
    for b, m in [(0, triad[2] + 12), (2, triad[1] + 12)]:
        d = 2 * B * 0.95; t = T(d)
        put(lead, pulse(mf(m), d, 0.5, 0.35, vib=0.4) * np.clip(t / 0.03, 0, 1) * np.exp(-t / 0.9), bar * BAR + b * B, 0.22)
# final slam: one big chord
for m in (57, 64, 69, 72, 76, 81):
    d = 3.5; t = T(d); put(fx, pulse(mf(m), d, 0.25, 0.7) * env(t, 0.003, 0.9), 26 * BAR, 0.09)
put(fx, crash(), 26 * BAR, 0.7); put(fx, sub_drop(), 26 * BAR, 1.0)

# sidechain: the kick ducks bass, arp and lead
duck = np.ones(len(drums))
for k in kicks:
    s = int(k * SR); L = int(0.22 * SR); duck[s:s + L] = np.minimum(duck[s:s + L], 1 - 0.65 * np.exp(-np.arange(L) / SR / 0.06))
# ping-pong dotted-8th delay on the lead
def delay(x, dt, fb, n=4):
    L = np.zeros_like(x); R = np.zeros_like(x); s = int(dt * SR)
    for i in range(1, n + 1):
        y = np.zeros_like(x); y[s * i:] = x[:len(x) - s * i] * fb ** i
        (L if i % 2 else R)[:] += y
    return L, R
dl, dr = delay(lead, 0.3, 0.38)
mono = drums * 1.0 + fx * 0.8
music_L = mono + (bass * duck) * 0.9 + (arp * duck) * 0.9 + (lead * duck) * 0.95 + dl * 0.45
music_R = mono + (bass * duck) * 0.9 + (arp * duck) * 0.75 + (lead * duck) * 0.95 + dr * 0.45
x = np.stack([music_L, music_R], 1)[:N]
fade = np.ones(N); tt = np.arange(N) / SR; m = tt > DUR - 1.4; fade[m] = np.cos(np.clip((tt[m] - (DUR - 1.4)) / 1.4, 0, 1) * np.pi / 2)
x *= fade[:, None]; x = x / (np.abs(x).max() + 1e-9) * 0.89
with wave.open('build/music.wav', 'wb') as w:
    w.setnchannels(2); w.setsampwidth(2); w.setframerate(SR); w.writeframes((x * 32767).astype(np.int16).tobytes())
peak = float(np.argmax(np.abs(KICK[:int(0.1 * SR)])) / SR)
json.dump({'bpm': BPM, 'beat': B, 'bar': BAR, 'peak': peak, 'dur': DUR, 'drops': [6 * BAR, 20 * BAR], 'slam': 26 * BAR,
           'bars': [i * BAR for i in range(BARS)]}, open('build/grid.json', 'w'), indent=1)
print('music', DUR, 's, kick peak', round(peak * 1000, 1), 'ms')

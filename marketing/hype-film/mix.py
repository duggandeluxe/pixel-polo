# mix.py: places a synthesized arcade SFX palette on the film's own cues, over music.py's track.
#   cd engine && ../.venv/bin/python ../mix.py
import json, os, sys
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), 'engine'))
from audio import *   # noqa: F401,F403  (SR, T, att, bandnoise, thump, whoosh, click, stamp, sub_drop, Mix, ...)

HERE = os.path.dirname(os.path.abspath(__file__))
B = lambda p: os.path.join(HERE, 'build', p)
grid = json.load(open(B('grid.json')))
cues = json.load(open(B('cues.json')))['cues']

def sq(f0, f1, d, duty=0.5, tau=0.08):
    t = T(d); ph = np.cumsum(np.linspace(f0, f1, len(t))) / SR
    return np.where((ph % 1) < duty, 1.0, -1.0) * np.exp(-t / tau) * att(t, 0.001)
def seq(parts, gap):
    out = np.zeros(int((gap * len(parts) + 0.4) * SR))
    for i, y in enumerate(parts): s = int(i * gap * SR); out[s:s + len(y)] += y
    return out
def crowd(d, swell=0.25):
    t = T(d); n = bandnoise(d, 280, 2600) * 0.7 + bandnoise(d, 2600, 6000) * 0.2
    wob = 1 + 0.25 * np.sin(2 * np.pi * 3.1 * t) * np.sin(2 * np.pi * 0.7 * t)
    return n * wob * np.clip(t / swell, 0, 1) * np.exp(-np.clip(t - d * 0.45, 0, None) / (d * 0.3))
def horn(d=0.9):
    t = T(d); y = sum(2 * ((f * t) % 1) - 1 for f in (233.1, 293.7, 349.2))
    return y / 3 * np.clip(t / 0.02, 0, 1) * np.clip((d - t) / 0.15, 0, 1)
def slam(big=0):
    t = T(0.5)
    y = np.pad(thump(160, 50, 0.35), (0, len(t) - int(0.35 * SR))) * 1.1 + 0.5 * bandnoise(0.5, 300, 4000) * np.exp(-t / 0.02)
    if big: y = y + 0.8 * sub_drop(100, 35, 0.5)[:len(y)] * big
    return y
def stretch(d):
    t = T(d); f = 90 + 220 * (t / d) ** 1.4; ph = np.cumsum(f) / SR
    y = (2 * (ph % 1) - 1) * (0.5 + 0.5 * np.sin(2 * np.pi * (8 + 20 * t / d) * t))
    return y * (t / d) ** 1.2 * 0.6
def splash(d=0.6):
    t = T(d); return bandnoise(d, 300, 5000) * np.exp(-t / 0.15) * att(t, 0.004)
def whistle(d):
    t = T(d); f = 500 * (1800 / 500) ** ((t / d) ** 2); return np.sin(2 * np.pi * np.cumsum(f) / SR) * (t / d) ** 1.5 * 0.6
def chiptune_unlock(k):
    base = 1046.5 * 2 ** (min(k, 9) / 24)
    return seq([sq(base * r, base * r, 0.09, 0.25, 0.05) for r in (1, 1.26, 1.5, 2)], 0.045)

m = Mix(grid['dur'])
m.song(B('music.wav'), [(0.0, 0.0, grid['dur'])])
m.grid(peak=grid['peak'])
sfx_times = []
for t, kind, v in cues:
    sfx_times.append(t)
    if kind == 'slam': m.put(slam(), t, 0.7)
    elif kind == 'big': m.put(slam(0.8), t, 0.9)
    elif kind == 'mega': m.put(slam(1.2), t, 1.0); m.put(whoosh(0.3, 800, 7000), t - 0.12, 0.4)
    elif kind == 'whoosh': m.put(whoosh(0.35, 300, 5000), t, 0.55)
    elif kind == 'splash': m.put(splash(), t + 0.2, 0.45)
    elif kind == 'swipe': m.put(whoosh(0.14, 1200, 8000), t, 0.3)
    elif kind == 'tap': m.put(click(3000 + 200 * (v or 0) % 800), t, 0.7, pan=0)
    elif kind == 'stretch': m.put(stretch(v), t, 0.55)
    elif kind == 'release': m.put(whoosh(0.18, 1500, 9000), t, 0.8); m.put(thump(300, 120, 0.08), t, 0.6)
    elif kind == 'goal': m.put(crowd(2.6), t, 0.55); m.put(horn(), t + 0.15, 0.32)
    elif kind == 'coin': m.put(seq([sq(988, 988, 0.07, 0.5, 0.05), sq(1319, 1319, 0.25, 0.5, 0.1)], 0.07), t, 0.32)
    elif kind == 'stamp': m.put(stamp(), t, 0.8)
    elif kind == 'save': m.put(thump(220, 90, 0.15), t, 0.9); m.put(crowd(1.6, 0.1), t, 0.35)
    elif kind == 'card': m.put(whoosh(0.12, 1500, 7000), t - 0.05, 0.35); m.put(click(2600 + 120 * v), t + 0.04, 0.6)
    elif kind == 'verb': m.put(slam(0.3), t, 0.6)
    elif kind == 'tick': m.put(sq(1400 if v else 420, 1400 if v else 380, 0.05, 0.5, 0.02), t, 0.28)
    elif kind == 'bracket': m.put(whoosh(0.2, 800, 6000), t, 0.4); m.put(stamp(), t + 0.02, 0.5)
    elif kind == 'incoming': m.put(whistle(v), t, 0.35)
    elif kind == 'champions': m.put(crowd(3.4, 0.08), t, 0.65); m.put(horn(1.2), t + 0.1, 0.3)
    elif kind == 'achieve': m.put(chiptune_unlock(v), t, 0.28)
    elif kind == 'logo': m.put(chiptune_unlock(12), t + 0.2, 0.3); m.put(crowd(3.0, 0.2), t, 0.35)
m.write(B('mix.wav'), music=0.62, sfx=0.55)
m.audibility(sfx_times, music=0.62, sfx=0.55)

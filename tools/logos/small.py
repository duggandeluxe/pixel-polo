"""Small-size logos (list marks): the body sampled clean, plus one ring in the logo's outline colour.

flat: index map (-1 = transparent) at working size, P: its palette. See logos.py."""
import numpy as np
from PIL import Image

PANEL = np.array([11, 23, 66])
SLIVER = 0.010     # thinner than this (relative to the logo): edge fringe, merged away
THIN = 0.042       # thinner than this and on the outside: an outline
RING_CONTRAST = 120

def roles(flat, P):
    """Per colour: thickness and how much of its edge is the logo's outside edge."""
    H, W = flat.shape
    pad = np.pad(flat, 1, constant_values=-1)
    nb = [pad[1:-1, :-2], pad[1:-1, 2:], pad[:-2, 1:-1], pad[2:, 1:-1]]
    area = np.array([(flat == c).sum() for c in range(len(P))])
    out = {}
    for c in range(len(P)):
        m = flat == c
        if not m.any():
            continue
        edge = m & np.any([n != c for n in nb], 0)
        outside = m & np.any([n == -1 for n in nb], 0)
        out[c] = {"t": 2 * m.sum() / max(1, edge.sum()) / max(H, W), "o": outside.sum() / max(1, edge.sum()), "a": m.sum()}
    return out

def merge_slivers(flat, R):
    """Each sliver pixel (edge fringe) takes the colour of the nearest pixel of a real colour."""
    from scipy import ndimage
    bad = [c for c, r in R.items() if r["t"] < SLIVER]
    if not bad:
        return flat.copy()
    sl = np.isin(flat, bad)
    good = (flat >= 0) & ~sl
    if not good.any():
        return flat.copy()
    _, idx = ndimage.distance_transform_edt(~good, return_indices=True)
    f = flat.copy()
    f[sl] = flat[idx[0][sl], idx[1][sl]]
    return f

def shell(f, outline):
    """The outline-coloured pixels reachable from outside the logo through outline colours only
    (the outer trim), not the same colours used inside it (a letter, a counter)."""
    from scipy import ndimage
    ok = np.isin(f, outline)
    lab, n = ndimage.label(ok)
    if n == 0:
        return ok
    outside = np.pad(f == -1, 1, constant_values=True)
    near = ndimage.binary_dilation(outside, structure=np.ones((3, 3)))[1:-1, 1:-1]
    touching = np.unique(lab[ok & near])
    return np.isin(lab, touching[touching > 0])

def sample(m, n_col, tw, th, ox=0.0, oy=0.0, cover=0.45):
    """Block mode of index map m into tw x th, the grid shifted by (ox, oy) blocks."""
    H, W = m.shape
    bx, by = W / tw, H / th
    o = np.full((th, tw), -1)
    for ty in range(th):
        for tx in range(tw):
            y0 = int(round((ty + oy) * by)); y1 = max(y0 + 1, int(round((ty + 1 + oy) * by)))
            x0 = int(round((tx + ox) * bx)); x1 = max(x0 + 1, int(round((tx + 1 + ox) * bx)))
            blk = m[max(0, y0):min(H, y1), max(0, x0):min(W, x1)].reshape(-1)
            if not len(blk):
                continue
            solid = blk[blk >= 0]
            if len(solid) >= cover * len(blk):
                o[ty, tx] = np.bincount(solid, minlength=n_col).argmax()
    return o

def fidelity(m, o):
    """Share of source pixels the sampled image gets right, upscaled back."""
    H, W = m.shape
    th, tw = o.shape
    up = o[(np.arange(H) * th // H)[:, None], (np.arange(W) * tw // W)[None, :]]
    return (up == m).mean()

def best_sample(m, n_col, tw, th):
    """The grid shift that keeps the most of the logo, among those that still fill all tw x th
    (a shift that drops an edge row would waste the box); unshifted if none does."""
    best = None
    for ox in (-0.33, 0.0, 0.33):
        for oy in (-0.33, 0.0, 0.33):
            o = sample(m, n_col, tw, th, ox, oy)
            ys, xs = np.nonzero(o >= 0)
            full = len(ys) and ys.min() == 0 and xs.min() == 0 and ys.max() == th - 1 and xs.max() == tw - 1
            if not full and (ox, oy) != (0.0, 0.0):
                continue
            f = fidelity(m, o)
            if best is None or f > best[0]:
                best = (f, o)
    return best[1]

def small(flat, P, bw, bh, ring_hint=None):
    """ring_hint: an RGB to use for the ring (its nearest palette colour) where the automatic pick
    is wrong (see RING_HINTS in logos.py)."""
    R = roles(flat, P)
    f = merge_slivers(flat, R)
    R = roles(f, P)
    biggest = max(R, key=lambda c: R[c]["a"])
    total = sum(r["a"] for r in R.values())
    thin = [c for c, r in R.items() if c != biggest and r["t"] < THIN]
    # the ring: the logo's trim that shows best on the navy panels (its outer outline, or when
    # that's too dark to see, the trim inside it), by contrast and how much of the logo it is
    contrast = lambda c: np.abs(P[c] - PANEL).sum()
    ring = None
    cands = [c for c in thin if contrast(c) >= RING_CONTRAST]
    if ring_hint is not None:
        ring = min(R, key=lambda c: np.abs(P[c] - np.array(ring_hint)).sum())
    elif cands:
        ring = max(cands, key=lambda c: contrast(c) * np.sqrt(R[c]["a"] / total))
    # the outer outlines go with it: the ring stands in for them
    outline = [c for c in R if c == ring or c in thin and (R[c]["o"] >= 0.15 and contrast(c) < RING_CONTRAST)]
    if ring is not None:
        body = f.copy()
        body[shell(f, outline)] = -1
        ys, xs = np.nonzero(body >= 0)
        src, edge = body[ys.min():ys.max() + 1, xs.min():xs.max() + 1], 2
    else:
        src, edge = f, 0

    def draw(tw, th):
        o = best_sample(src, len(P), tw, th)
        if ring is not None:
            o = np.pad(o, 1, constant_values=-1)
            solid = o >= 0
            grown = solid.copy()
            for dy in (-1, 0, 1):
                for dx in (-1, 0, 1):
                    grown |= np.roll(np.roll(solid, dy, 0), dx, 1)
            o[grown & ~solid] = ring
        ys, xs = np.nonzero(o >= 0)
        return o[ys.min():ys.max() + 1, xs.min():xs.max() + 1]

    # the fitted size, then a pixel bigger at a time while the finished mark (a logo's thin tips
    # can fall between pixels) still fits the box: it fills the box as nearly as it can
    H, W = src.shape
    s = min((bw - edge) / W, (bh - edge) / H)
    o = draw(max(1, round(W * s)), max(1, round(H * s)))
    for _ in range(6):
        if o.shape[1] >= bw or o.shape[0] >= bh:
            break
        s *= 1.0 + 1.0 / max(W * s, H * s)
        nxt = draw(max(1, round(W * s)), max(1, round(H * s)))
        if nxt.shape[1] > bw or nxt.shape[0] > bh:
            break
        o = nxt
    img = np.zeros(o.shape + (4,), np.uint8)
    img[o >= 0, :3] = P[o[o >= 0]]
    img[o >= 0, 3] = 255
    return Image.fromarray(img, "RGBA")

if __name__ == "__main__":
    import sys
    out = sys.argv[1]
    boxes = [b.split(":") for b in sys.argv[2].split(",")]   # tag:w:h
    ids = sys.argv[3].split(",")
    for t in ids:
        flat = np.load(f"flat/{t}.npy"); P = np.load(f"flat/{t}_P.npy")
        for tag, w, h in boxes:
            small(flat, P, int(w), int(h)).save(f"{out}/{t}_{tag}.png")

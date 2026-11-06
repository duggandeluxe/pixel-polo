"""The list marks at detail mode's density: the same on-screen boxes as `_s` and `_m`, in art pixels
two window pixels wide (two-thirds of a game pixel) instead of three. Each comes straight from the
full-resolution original in source/, like every other size.

    python3 fine.py source out      # needs numpy, pillow, scipy; then copy out/*.png"""
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import numpy as np
from PIL import Image
from scipy import ndimage
import small

BOXES = [("fs", 30, 18), ("fm", 42, 30)]
## Where the faithful reduction turns to noise even at this density (chosen side by side): the
## dedicated small variant, as logos_full.py does at the coarser sizes.
SMALL_VARIANTS = {"SJCU": ("fs", "fm"), "CCSB": ("fs", "fm"), "SMCC": ("fs",), "LBSC": ("fs",), "CULA": ("fs",)}
OUTLINES = {"MSMU": (253, 253, 253)}   # (logos_full.py: its navy edge vanishes on the navy panels)
RING_HINTS = {"CCSB": (252, 185, 16)}

def flatten(path):
    """An original's opaque pixels as its own few colours: (index map, palette)."""
    a = np.asarray(Image.open(path).convert("RGBA")).astype(np.int32)
    fg = a[..., 3] > 127
    pix = a[fg][:, :3]
    rng = np.random.default_rng(1)
    sub = pix[rng.choice(len(pix), min(len(pix), 200000), replace=False)].astype(np.uint8)
    q = Image.fromarray(sub.reshape(-1, 1, 3)).quantize(colors=10, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)
    pal = np.array(q.getpalette()[:30]).reshape(-1, 3)
    idx = np.asarray(q).reshape(-1)
    counts = np.bincount(idx, minlength=len(pal))
    keep = [i for i in np.argsort(-counts) if counts[i] > 0.004 * len(idx)]
    merged = []
    for i in keep:
        if all(np.abs(pal[i] - pal[j]).sum() > 40 for j in merged):
            merged.append(i)
    P = pal[merged]
    best = np.full(fg.shape, np.inf, np.float32)
    flat = np.zeros(fg.shape, np.int32)
    for c in range(len(P)):
        d = np.abs(a[..., :3] - P[c]).sum(2).astype(np.float32)
        m = d < best
        best[m] = d[m]
        flat[m] = c
    flat[~fg] = -1
    ys, xs = np.nonzero(fg)
    return flat[ys.min():ys.max() + 1, xs.min():xs.max() + 1], P

def sample(flat, P, bw, bh, cover=0.45):
    """Each target pixel: the most common colour of its own block of the original."""
    h, w = flat.shape
    s = min(bw / w, bh / h)
    tw, th = max(1, round(w * s)), max(1, round(h * s))
    o = np.zeros((th, tw, 4), np.uint8)
    ys = np.linspace(0, h, th + 1).astype(int)
    xs = np.linspace(0, w, tw + 1).astype(int)
    for ty in range(th):
        for tx in range(tw):
            blk = flat[ys[ty]:max(ys[ty] + 1, ys[ty + 1]), xs[tx]:max(xs[tx] + 1, xs[tx + 1])].reshape(-1)
            solid = blk[blk >= 0]
            if len(solid) < cover * len(blk):
                continue
            o[ty, tx, :3] = P[np.bincount(solid).argmax()]
            o[ty, tx, 3] = 255
    return Image.fromarray(o, "RGBA")

def outlined(im, col):
    a = np.pad(np.asarray(im).copy(), ((1, 1), (1, 1), (0, 0)))
    solid = a[..., 3] > 0
    ring = ndimage.binary_dilation(solid, structure=np.ones((3, 3))) & ~solid
    a[ring, :3] = col
    a[ring, 3] = 255
    return Image.fromarray(a, "RGBA")

def main(src, out):
    os.makedirs(out, exist_ok=True)
    for f in sorted(os.listdir(src)):
        if not f.endswith(".png"):
            continue
        id = f[:-4]
        flat, P = flatten(os.path.join(src, f))
        for tag, bw, bh in BOXES:
            if tag in SMALL_VARIANTS.get(id, ()):
                im = small.small(flat, P, bw, bh, RING_HINTS.get(id))
            elif id in OUTLINES:
                im = outlined(sample(flat, P, bw - 2, bh - 2), OUTLINES[id])
            else:
                im = sample(flat, P, bw, bh)
            im.save(f"{out}/{id}_{tag}.png")

if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])

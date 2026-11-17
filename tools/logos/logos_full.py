"""PDF logo images -> transparent pixel art at each in-game box, every size straight from the
full-resolution original (never from a reduced copy). Also archives the original crops.

    python3 logos_full.py raw pages out source"""
import sys, os, re
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import numpy as np
from PIL import Image
from scipy import ndimage
import small, fine

IDS = ["CULA", "CUSC", "ALC", "FORDU", "SJCU", "LBSC", "CUSD", "PRIN", "PPCU", "ICU", "UCDS", "CRBU",
       "LMMU", "HVRD", "UPAC", "CCSB", "BROW", "NANA", "GWU", "SCCU", "USAF", "CSFU", "SMCC",
       "BUCK", "WAGN", "MSMU", "IONA", "LIUB", "HURST"]
BOXES = [("s", 20, 12), ("m", 28, 20), ("40", 40, 40), ("48", 48, 48), ("60", 60, 60)]
SMALL_TAGS = ("s", "m")
## Every size is a faithful reduction of the original (every colour, each pixel its block's most
## common one). Only where that can't show the logo clearly at a list size does the size get its
## dedicated small variant (small.py: the body and one ring of its own trim), chosen by looking at
## each one side by side (2026-10-30): fine detail (arrows, feathers, script, outlined lettering)
## that turns to noise in 20 x 12 or 28 x 20 pixels.
SMALL_VARIANTS = {"SJCU": ("s", "m"), "CULA": ("s", "m"), "ICU": ("s", "m"), "PPCU": ("s", "m"), "PRIN": ("s", "m"), "CUSD": ("s", "m"), "LBSC": ("s", "m"), "NANA": ("s", "m"), "CCSB": ("s", "m"), "HVRD": ("s", "m"), "UPAC": ("s", "m"), "CRBU": ("s", "m"), "UCDS": ("s", "m"), "CSFU": ("s", "m"), "USAF": ("s", "m"), "SCCU": ("s", "m"), "GWU": ("s", "m"), "STAM": ("s", "m"), "CUSC": ("s", "m"), "BUCK": ("s", "m"), "HURST": ("s", "m"), "LIUB": ("s", "m"), "IONA": ("s", "m"), "MSMU": ("s", "m"), "WAGN": ("s", "m")}
## Logos whose own outer edge is too dark for the navy panels get a one-pixel outline in their own
## trim colour around them, at every size (the logo is made 2 px smaller first, so it still fits
## its box): Emmitsburg's navy EH disappeared into the background (2026-10-30, the user's call).
OUTLINES = {}   # (Emmitsburg's outline went with its EH: its Highlander has its own, 2026-11-08)

def outlined(make, bw, bh, col):
    """`make(w, h)`'s image two pixels smaller, ringed in `col` (corners too)."""
    im = np.asarray(make(bw - 2, bh - 2)).copy()
    a = np.pad(im, ((1, 1), (1, 1), (0, 0)))
    solid = a[..., 3] > 0
    grown = ndimage.binary_dilation(solid, structure=np.ones((3, 3)))
    ring = grown & ~solid
    a[ring, :3] = col
    a[ring, 3] = 255
    return Image.fromarray(a, "RGBA")
RING_HINTS = {"ICU": (252, 209, 82), "PPCU": (255, 128, 16), "PRIN": (252, 97, 1)}
## Logos supplied directly as a full-resolution original (already in source/) rather than cut from
## the PDF: built from that file, which is never overwritten. Irvine's aardvark head replaced the
## sheet's gold "A" (2026-11-08); its small sizes ring the body in its own cream border. Malibu's
## breaking wave replaced the sheet's orange "B" (2026-11-08); its list sizes are the wave alone
## (MAIN_ONLY: the spray turns to noise there) ringed in its orange. New Jersey's pixel-art Bengal
## tiger head replaced the sheet's striped "B" (2026-11-08; its fringe cleared and its colours
## snapped to its own black, orange and cream first); its list sizes ring it in that orange.
## The Bears' LA monogram, the Golden Grizzlies' bear over BV, the Redwoods' tree over PG, the
## Spartans' helmet over LAS and twenty-one pixel-art mascots replaced their sheet logos too (2026-11-08;
## the untouched files are in originals/, the backdrop or glow around each cut away in source/).
## Their list sizes ring the body in its own outline, except four whose ring would take the wrong
## colour (Bronx, Los Angeles Mountain Lions, Moraga, Providence): faithful at every size.
## Lewisburg's pixel-art buffalo head replaced the sheet's orange-and-navy "LB" (2026-11-08; the
## untouched file is originals/lewisburg_buffalo.png, its translucent white haze cut away in
## source/BUCK.png); its list sizes ring the head in its own white border.
SUPPLIED = {"ICU", "PPCU", "PRIN", "CULA", "HURST", "LIUB", "IONA", "MSMU", "WAGN", "ALC", "STAM", "CUSC", "CUSD", "LBSC", "FORDU", "NANA", "CCSB", "HVRD", "UPAC", "LMMU", "CRBU", "UCDS", "SMCC", "CSFU", "USAF", "SCCU", "GWU", "BROW", "BUCK"}
PANEL = np.array([11, 23, 66])
K = 4
raw, pages, out, src_dir = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]

def visible(page, x, y, w, h, iw, ih):
    a = np.asarray(Image.open(f"{pages}/page{page}.png").convert("RGB")).astype(int)
    H = a.shape[0]
    x0, x1 = max(0, int(x * K)), min(a.shape[1], int((x + w) * K))
    y0, y1 = max(0, int(H - (y + h) * K)), min(H, int(H - y * K))
    nw = (a[y0:y1, x0:x1] < 245).any(2)
    ys, xs = np.nonzero(nw)
    px0, px1 = x0 + xs.min(), x0 + xs.max() + 1
    py0, py1 = y0 + ys.min(), y0 + ys.max() + 1
    fx = lambda p: int(round((p / K - x) / w * iw))
    fy = lambda p: int(round(((H - p) / K - y) / h * ih))
    return max(0, fx(px0)), max(0, fy(py1)), min(iw, fx(px1)), min(ih, fy(py0))

def clean(img):
    """The original's own pixels: the backdrop (and its big enclosed pockets) transparent, the rest
    flattened to the logo's own few colours. Returns (flat index map, palette, rgba original)."""
    a = np.asarray(img).astype(np.int32)
    h, w, _ = a.shape
    border = np.concatenate([a[0], a[-1], a[:, 0], a[:, -1]])
    bg = np.median(border, 0)
    spread = np.percentile(np.abs(border - bg).sum(1), 90)
    tol = max(36, spread * 2.5)
    bgm = np.abs(a - bg).sum(2) < tol
    lab, n = ndimage.label(bgm)
    edge = np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))
    out_bg = np.isin(lab, edge[edge > 0])
    sizes = ndimage.sum(np.ones_like(lab), lab, index=np.arange(1, n + 1))
    big = np.nonzero(sizes >= 0.0015 * h * w)[0] + 1
    out_bg |= np.isin(lab, big)
    fg = ~out_bg
    pix = a[fg]
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
    best = np.full((h, w), np.inf, np.float32)
    flat = np.zeros((h, w), np.int32)
    for c in range(len(P)):
        d = np.abs(a - P[c]).sum(2).astype(np.float32)
        m = d < best
        best[m] = d[m]
        flat[m] = c
    flat[~fg] = -1
    ys, xs = np.nonzero(fg)
    y0, y1, x0, x1 = ys.min(), ys.max() + 1, xs.min(), xs.max() + 1
    rgba = np.zeros((h, w, 4), np.uint8)
    rgba[..., :3] = a.astype(np.uint8)
    rgba[..., 3] = np.where(fg, 255, 0)
    return flat[y0:y1, x0:x1], P, rgba[y0:y1, x0:x1]

def sample(flat, P, bw, bh, cover=0.45):
    """Each target pixel: the most common colour of its own block of the original (a block mostly
    backdrop is transparent). One step from the original to the box, nothing in between."""
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
            c = np.bincount(solid).argmax()
            o[ty, tx, :3] = P[c]
            o[ty, tx, 3] = 255
    return Image.fromarray(o, "RGBA")

def visibility(img):
    """How well a mark shows on the navy panels: its opaque pixels' mean contrast with them."""
    a = np.asarray(img).astype(int)
    op = a[..., 3] > 0
    if not op.any():
        return 0.0
    return float(np.abs(a[..., :3][op] - PANEL).sum(1).mean())

items = [l.split() for l in open(f"{raw}/list.txt")]
assert len(items) == len(IDS)
report = []
for tid, it in zip(IDS, items):
    n = it[0]; iw, ih = map(int, it[1].split("x"))
    page = int(re.match(r"p(\d+)_", n).group(1))
    x, y, w, h = [int(v.split("=")[1]) for v in it[5:9]]
    if tid in SUPPLIED:
        flat, P = fine.flatten(f"{src_dir}/{tid}.png")
    else:
        img = Image.open(f"{raw}/{n}.png").convert("RGB")
        img = img.crop(visible(page, x, y, w, h, iw, ih))
        flat, P, rgba = clean(img)
        Image.fromarray(rgba, "RGBA").save(f"{src_dir}/{tid}.png")
    kinds = []
    for tag, bw, bh in BOXES:
        variant = tag in SMALL_VARIANTS.get(tid, ())
        body = small.main_piece(flat) if tid in small.MAIN_ONLY else flat
        make = (lambda w2, h2, tid=tid, body=body: small.small(body, P, w2, h2, RING_HINTS.get(tid))) if variant else (lambda w2, h2: sample(flat, P, w2, h2))
        kind = "small variant" if variant else "faithful"
        if tid in OUTLINES:
            im = outlined(make, bw, bh, OUTLINES[tid])
            kind += " + outline"
        else:
            im = make(bw, bh)
        im.save(f"{out}/{tid}_{tag}.png")
        kinds.append(f"{tag}:{kind}:{visibility(im):.0f}")
    print(tid, flat.shape[::-1], len(P), " ".join(kinds))

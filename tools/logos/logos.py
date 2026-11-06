"""PDF logo images -> transparent, flat-colour pixel art at each in-game box size."""
import sys, os, re
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import small
import numpy as np
from PIL import Image
from collections import deque

IDS = ["CULA", "CUSC", "ALC", "FORDU", "SJCU", "LBSC", "CUSD", "PRIN", "PPCU", "ICU", "UCDS", "CRBU",
       "LMMU", "HVRD", "UPAC", "CCSB", "BROW", "NANA", "GWU", "SCCU", "USAF", "CSFU", "SMCC",
       "BUCK", "WAGN", "MSMU", "IONA", "LIUB", "HURST"]
## (tag, w, h): the list marks ("s", "m") go through small.py, the big ones straight through sample()
BOXES = [("s", 20, 12), ("m", 28, 20), ("40", 40, 40), ("48", 48, 48), ("60", 60, 60)]
SMALL_TAGS = ("s", "m")
## The list marks' ring colour where small.py's pick is wrong: Santa Barbara's grey-blue is the
## letters' shading, its outline is the yellow.
RING_HINTS = {"CCSB": (252, 185, 16)}
raw, pages, out = sys.argv[1], sys.argv[2], sys.argv[3]
K = 4  # page render scale

def visible(page, x, y, w, h, iw, ih):
    """The image's clip on the page, in image pixels: non-white page pixels inside its rect."""
    a = np.asarray(Image.open(f"{pages}/page{page}.png").convert("RGB")).astype(int)
    H = a.shape[0]
    x0, x1 = max(0, int(x * K)), min(a.shape[1], int((x + w) * K))
    y0, y1 = max(0, int(H - (y + h) * K)), min(H, int(H - y * K))
    sub = a[y0:y1, x0:x1]
    nw = (sub < 245).any(2)
    ys, xs = np.nonzero(nw)
    # page px -> image px
    px0, px1 = x0 + xs.min(), x0 + xs.max() + 1
    py0, py1 = y0 + ys.min(), y0 + ys.max() + 1
    fx = lambda p: int(round((p / K - x) / w * iw))
    fy = lambda p: int(round(((H - p) / K - y) / h * ih))
    return max(0, fx(px0)), max(0, fy(py1)), min(iw, fx(px1)), min(ih, fy(py0))

def flood(mask_bg, seeds):
    h, w = mask_bg.shape
    seen = np.zeros_like(mask_bg)
    q = deque()
    for (yy, xx) in seeds:
        if mask_bg[yy, xx] and not seen[yy, xx]:
            seen[yy, xx] = True; q.append((yy, xx))
    while q:
        yy, xx = q.popleft()
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            ny, nx = yy + dy, xx + dx
            if 0 <= ny < h and 0 <= nx < w and mask_bg[ny, nx] and not seen[ny, nx]:
                seen[ny, nx] = True; q.append((ny, nx))
    return seen

def components(mask):
    """Label 4-connected components of mask (small images only)."""
    lab = np.zeros(mask.shape, int); n = 0; sizes = [0]
    for yy, xx in zip(*np.nonzero(mask)):
        if lab[yy, xx]: continue
        n += 1; c = 0; q = deque([(yy, xx)]); lab[yy, xx] = n
        while q:
            a, b = q.popleft(); c += 1
            for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                p, r = a + dy, b + dx
                if 0 <= p < mask.shape[0] and 0 <= r < mask.shape[1] and mask[p, r] and not lab[p, r]:
                    lab[p, r] = n; q.append((p, r))
        sizes.append(c)
    return lab, sizes

def clean(img):
    """Flat palette + alpha at a working size (longest side 480)."""
    s = 480 / max(img.size)
    work = img.resize((max(1, round(img.size[0] * s)), max(1, round(img.size[1] * s))), Image.BOX)
    a = np.asarray(work).astype(int)
    h, w, _ = a.shape
    border = np.concatenate([a[0], a[-1], a[:, 0], a[:, -1]])
    bg = np.median(border, 0)
    dist = np.abs(a - bg).sum(2)
    spread = np.percentile(np.abs(border - bg).sum(1), 90)
    tol = max(36, spread * 2.5)
    bgm = dist < tol
    seeds = [(0, i) for i in range(w)] + [(h - 1, i) for i in range(w)] + [(i, 0) for i in range(h)] + [(i, w - 1) for i in range(h)]
    out_bg = flood(bgm, seeds)
    # enclosed backdrop (letter counters): big pockets of the backdrop colour
    lab, sizes = components(bgm & ~out_bg)
    for i, c in enumerate(sizes):
        if i and c >= 0.0015 * h * w:
            out_bg |= lab == i
    fg = ~out_bg
    # palette from the logo's own pixels
    pix = a[fg].astype(np.uint8)
    q = Image.fromarray(pix.reshape(-1, 1, 3)).quantize(colors=10, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)
    pal = np.array(q.getpalette()[:30]).reshape(-1, 3)
    idx = np.asarray(q).reshape(-1)
    counts = np.bincount(idx, minlength=len(pal))
    keep = [i for i in np.argsort(-counts) if counts[i] > 0.004 * len(idx)]
    merged = []
    for i in keep:
        if all(np.abs(pal[i] - pal[j]).sum() > 40 for j in merged):
            merged.append(i)
    P = pal[merged]
    flat = np.argmin(np.abs(a[:, :, None, :] - P[None, None]).sum(3), 2)
    flat[~fg] = -1
    ys, xs = np.nonzero(fg)
    flat = flat[ys.min():ys.max() + 1, xs.min():xs.max() + 1]
    return flat, P, bg, tol

def sample(flat, P, bw, bh):
    h, w = flat.shape
    s = min(bw / w, bh / h)
    tw, th = max(1, round(w * s)), max(1, round(h * s))
    o = np.zeros((th, tw, 4), np.uint8)
    for ty in range(th):
        for tx in range(tw):
            blk = flat[int(ty * h / th):max(int(ty * h / th) + 1, int((ty + 1) * h / th)),
                       int(tx * w / tw):max(int(tx * w / tw) + 1, int((tx + 1) * w / tw))].reshape(-1)
            solid = blk[blk >= 0]
            if len(solid) < 0.45 * len(blk):
                continue
            c = np.bincount(solid).argmax()
            o[ty, tx, :3] = P[c]; o[ty, tx, 3] = 255
    return Image.fromarray(o, "RGBA")

items = [l.split() for l in open(f"{raw}/list.txt")]
assert len(items) == len(IDS)
for tid, it in zip(IDS, items):
    n = it[0]; iw, ih = map(int, it[1].split("x"))
    page = int(re.match(r"p(\d+)_", n).group(1))
    x, y, w, h = [int(v.split("=")[1]) for v in it[5:9]]
    img = Image.open(f"{raw}/{n}.png").convert("RGB")
    cx0, cy0, cx1, cy1 = visible(page, x, y, w, h, iw, ih)
    img = img.crop((cx0, cy0, cx1, cy1))
    flat, P, bg, tol = clean(img)
    for tag, bw, bh in BOXES:
        img = small.small(flat, P, bw, bh, RING_HINTS.get(tid)) if tag in SMALL_TAGS else sample(flat, P, bw, bh)
        img.save(f"{out}/{tid}_{tag}.png")
    print(tid, n, "clip", (cx0, cy0, cx1, cy1), "bg", bg.astype(int), "tol", int(tol), "colours", len(P), "art", flat.shape[::-1])

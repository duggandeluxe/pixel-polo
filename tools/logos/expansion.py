"""The 24 Division II & III logos: original pixel art, made here rather than cut from a sheet.

Every logo is a monogram in the game's own block capitals (TeamLogo.GLYPHS) with a mascot accent
drawn from simple shapes, in the school's colours. Each size is rasterised on its own grid from the
same shapes (never rescaled art), so edges stay crisp: nothing here is anti-aliased.

    python3 expansion.py ../../game/assets/logos     # needs numpy, pillow, scipy; then --import
"""
import math, os, re, sys
import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = open(os.path.join(HERE, "..", "..", "game", "src", "ui", "team_logo.gd")).read()
GLYPHS = {m[0]: re.findall(r'"([.#]{8})"', m[1]) for m in re.findall(r'"([A-Z])": \[(.*?)\],', SRC)}
INK = (6, 16, 58)
U = 24                     # hi-res units per glyph cell
SIZES = {"s": (20, 12, 0), "m": (28, 20, 1), "40": (40, 40, 1), "48": (48, 48, 2), "60": (60, 60, 2), "fs": (30, 18, 0), "fm": (42, 30, 1)}

def hexc(h):
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))

def glyph(ch):
    g = GLYPHS[ch]
    a = np.zeros((10 * U, 8 * U), bool)
    for y, row in enumerate(g):
        for x, c in enumerate(row):
            if c == "#":
                a[y * U:(y + 1) * U, x * U:(x + 1) * U] = True
    return a

def canvas():
    return np.zeros((40 * U, 48 * U), bool)

def stamp(dst, src, x, y):
    h, w = src.shape
    dst[y:y + h, x:x + w] |= src

def poly(points, scale=1.0):
    """A filled polygon from cell coordinates (48 x 40 cells)."""
    im = Image.new("1", (48 * U, 40 * U))
    ImageDraw.Draw(im).polygon([(x * U, y * U) for x, y in points], fill=1)
    return np.asarray(im)

def disc(cx, cy, r):
    yy, xx = np.mgrid[0:40 * U, 0:48 * U]
    return (xx - cx * U) ** 2 + (yy - cy * U) ** 2 <= (r * U) ** 2

def mirror(points, axis=24):
    return [(2 * axis - x, y) for x, y in points]

# ---- the accents: in 48 x 40 cells, the monogram sitting around (24, 22)
def wings():
    w = [(13, 20), (2, 10), (4, 16), (1, 15), (5, 21), (2, 21), (7, 26), (13, 26)]
    return poly(w) | poly(mirror(w))

def crown():
    return poly([(13, 14), (11, 4), (17, 9), (24, 2), (31, 9), (37, 4), (35, 14)])

def antlers():
    a = [(21, 15), (19, 9), (14, 8), (12, 2), (15, 5), (16, 1), (18, 6), (21, 3), (21, 7), (24, 11), (24, 15)]
    return poly(a) | poly(mirror(a))

def ears():
    e = [(13, 15), (12, 4), (21, 12), (21, 15)]
    return poly(e) | poly(mirror(e))

def horns():
    h = [(15, 15), (9, 13), (6, 4), (12, 9), (19, 11), (19, 15)]
    return poly(h) | poly(mirror(h)) | poly([(19, 15), (19, 9), (24, 6), (29, 9), (29, 15)])

def flame():
    return poly([(24, 1), (29, 8), (28, 4), (36, 12), (38, 20), (41, 15), (42, 26), (38, 36), (10, 36), (6, 26), (7, 15), (10, 20), (12, 12), (20, 4), (19, 8)])

def gear():
    out = disc(24, 22, 14)
    for i in range(8):
        t = i * math.pi / 4
        c, s = math.cos(t), math.sin(t)
        out |= poly([(24 + 12 * c - 3 * s, 22 + 12 * s + 3 * c), (24 + 18 * c - 2.5 * s, 22 + 18 * s + 2.5 * c), (24 + 18 * c + 2.5 * s, 22 + 18 * s - 2.5 * c), (24 + 12 * c + 3 * s, 22 + 12 * s - 3 * c)])
    return out

def shield():
    return poly([(8, 3), (24, 6), (40, 3), (40, 22), (34, 31), (24, 38), (14, 31), (8, 22)])

def star():
    pts = []
    for i in range(10):
        r = 20 if i % 2 == 0 else 9
        t = -math.pi / 2 + i * math.pi / 5
        pts.append((24 + r * math.cos(t), 21 + r * math.sin(t)))
    return poly(pts)

def heart():
    return disc(15, 15, 10) | disc(33, 15, 10) | poly([(6, 20), (42, 20), (24, 39)])

def claws():
    out = None
    for i in range(3):
        x = 33 + i * 5
        m = poly([(x + 4, 6), (x + 6, 6), (x - 4, 36), (x - 5, 34)])
        out = m if out is None else out | m
    return out

def fangs():
    f = [(15, 31), (21, 31), (18, 39)]
    return poly(f) | poly(mirror(f))

def teeth():
    return poly([(19, 31), (23.5, 31), (23.5, 38), (19, 38)]) | poly([(24.5, 31), (29, 31), (29, 38), (24.5, 38)])

def hump():
    return poly([(11, 15), (15, 8), (20, 3), (24, 7), (28, 3), (33, 8), (37, 15)])

def quill():
    return poly([(38, 2), (45, 3), (42, 12), (36, 22), (30, 31), (28, 31), (32, 20)])

def leaf():
    l = [(24, 15), (16, 12), (12, 4), (21, 6)]
    return poly(l) | poly(mirror(l)) | poly([(22, 15), (24, 3), (26, 15)])

def leap():
    e = [(14, 15), (15, 1), (20, 13)]
    return poly(e) | poly([(22, 15), (25, 3), (28, 15)])

## id: letters, the accent, the accent behind the letters?
LOGOS = {
    "D2_01": ("LM", wings), "D2_02": ("I", wings), "D2_03": ("FP", flame), "D2_04": ("E", shield),
    "D2_05": ("LC", claws), "D2_06": ("S", fangs), "D2_07": ("M", ears),
    "D3_01": ("CP", teeth), "D3_02": ("TO", crown), "D3_03": ("O", claws), "D3_04": ("CB", antlers),
    "D3_05": ("LA", claws), "D3_06": ("CS", leaf), "D3_07": ("LV", ears), "D3_08": ("R", ears),
    "D3_09": ("W", quill), "D3_10": ("RI", horns), "D3_11": ("S", leap), "D3_12": ("NL", hump),
    "D3_13": ("B", wings), "D3_14": ("EC", ears), "D3_15": ("W", star), "D3_16": ("N", heart),
    "D3_17": ("CM", gear),
}
BEHIND = {flame, shield, gear, star, heart}

def shapes(letters, accent):
    """(the accent's mask, each letter's mask, front last)."""
    masks = []
    if len(letters) == 1:
        g = np.kron(glyph(letters), np.ones((2, 2), bool))[::1, ::1]
        k = g[:: 1, :: 1]
        scaled = np.asarray(Image.fromarray(k).resize((int(8 * 2.2 * U), int(10 * 2.2 * U)), Image.NEAREST))
        m = canvas()
        stamp(m, scaled, (48 * U - scaled.shape[1]) // 2, 11 * U - U // 2 + 0)
        masks.append(m)
    else:
        for i, ch in enumerate(letters):
            k = np.asarray(Image.fromarray(glyph(ch)).resize((int(8 * 2.0 * U), int(10 * 2.0 * U)), Image.NEAREST))
            m = canvas()
            stamp(m, k, (7 + i * 18) * U, (13 + i * 2 - 1) * U - U)
            masks.append(m)
    return accent(), masks

def reduce(mask, box, pad):
    """`mask` cropped to `box` and fitted inside (w, h) less pad: True where most of a cell is set."""
    y0, y1, x0, x1 = box
    crop = mask[y0:y1, x0:x1]
    return crop

def render(sid, c1, c2, w, h, band):
    letters, accent = LOGOS[sid]
    acc, masks = shapes(letters, accent)
    union = acc.copy()
    for m in masks:
        union |= m
    ys, xs = np.where(union)
    y0, y1, x0, x1 = ys.min(), ys.max() + 1, xs.min(), xs.max() + 1
    edge = band + 1
    k = min((w - 2 * edge) / (x1 - x0), (h - 2 * edge) / (y1 - y0))
    tw, th = max(1, round((x1 - x0) * k)), max(1, round((y1 - y0) * k))
    def fit(m):
        im = Image.fromarray((m[y0:y1, x0:x1] * 255).astype(np.uint8)).resize((tw, th), Image.BOX)
        return np.asarray(im) > 127
    W, H = tw + 2 * edge, th + 2 * edge
    def place(m):
        out = np.zeros((H, W), bool)
        out[edge:edge + th, edge:edge + tw] = m
        return out
    A = place(fit(acc))
    L = [place(fit(m)) for m in masks]
    cross = ndimage.generate_binary_structure(2, 1)
    px = np.zeros((H, W, 4), np.uint8)
    def paint(m, col):
        px[m] = (*col, 255)
    trim = c2 if sum(c2) > 110 else (255, 255, 255)
    # a list mark has no room for a band: the brighter school colour, so it reads on the navy menus
    body = c1 if band or sum(c1) >= sum(trim) or sum(c1) > 330 else trim
    letters_all = np.zeros((H, W), bool)
    for m in L:
        letters_all |= m
    grown = ndimage.binary_dilation(letters_all, cross, iterations=band) if band else letters_all
    square = np.ones((3, 3), bool)
    # the ink edge round everything; the accent; then the letters in their band, parted from it by ink
    paint(ndimage.binary_dilation(grown | A, square), INK)
    paint(A, trim if body != trim else (c1 if sum(c1) > 200 else (255, 255, 255)))
    paint(ndimage.binary_dilation(grown, square), INK)
    paint(grown, trim)
    for i, m in enumerate(L):
        if i > 0:
            paint(ndimage.binary_dilation(m, cross, iterations=1) & ~m & L[0], INK)
        paint(m, body)
    return Image.fromarray(px)

def main(out):
    rows = re.findall(r'"short": "(D[23]_\d\d)".*?"c1": "(\w+)", "c2": "(\w+)"', open(os.path.join(HERE, "..", "..", "game", "src", "data", "colleges.gd")).read())
    assert len(rows) == 24
    for sid, a, b in rows:
        for tag, (w, h, band) in SIZES.items():
            render(sid, hexc(a), hexc(b), w, h, band).save(os.path.join(out, "%s_%s.png" % (sid, tag)))

if __name__ == "__main__":
    main(sys.argv[1])

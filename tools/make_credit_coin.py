#!/usr/bin/env python3
"""Make the game's Credit coin assets from the official golden water polo coin image.

    python3 -I tools/make_credit_coin.py path/to/original_coin.png

Writes (lossless PNG, transparent background):
    game/assets/ui/credit_coin.png          the coin trimmed to itself, at the original's size
    game/assets/ui/credit_coin_<N>.png      one per size in SIZES (N px tall), each made from the
                                            original directly, never from another variant

The background is removed by a flood fill from the image's edges over near-black pixels only:
the black outlines inside the coin are never touched (the gold rim fences them off). Nothing is
recoloured, sharpened or blurred.

A size variant keeps the art's pixel-art reading at small sizes the way a pixel artist would:
each output pixel covers a block of the original; if enough of that block is black outline it
stays black outline (so the outline, the C and the ball's seams survive), otherwise it takes the
block's most common colour (no averaging: no new colours, no blur). Square, never stretched,
nothing cropped (the whole coin, centred).
"""
import os
import sys
from collections import Counter, deque

from PIL import Image

SIZES = [16, 20, 24, 32, 48]
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "game", "assets", "ui")
BG_DARK = 40          # a background pixel: every channel at or below this
OUTLINE_DARK = 70     # an outline pixel inside the coin: every channel at or below this
OUTLINE_SHARE = 0.28  # a block this much outline draws as outline


def remove_background(img: Image.Image) -> Image.Image:
    img = img.convert("RGBA")
    w, h = img.size
    px = img.load()
    seen = bytearray(w * h)
    q = deque()
    for x in range(w):
        q.append((x, 0))
        q.append((x, h - 1))
    for y in range(h):
        q.append((0, y))
        q.append((w - 1, y))
    while q:
        x, y = q.popleft()
        i = y * w + x
        if seen[i]:
            continue
        seen[i] = 1
        r, g, b, a = px[x, y]
        if a != 0 and max(r, g, b) > BG_DARK:
            continue
        px[x, y] = (0, 0, 0, 0)
        for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
            if 0 <= nx < w and 0 <= ny < h and not seen[ny * w + nx]:
                q.append((nx, ny))
    return img


def trim_square(img: Image.Image) -> Image.Image:
    box = img.getbbox()
    coin = img.crop(box)
    side = max(coin.size)
    sq = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    sq.paste(coin, ((side - coin.size[0]) // 2, (side - coin.size[1]) // 2))
    return sq


def is_outline(p) -> bool:
    return p[3] > 0 and max(p[0], p[1], p[2]) <= OUTLINE_DARK


def most_common(pixels):
    """The block's colour: the commonest family of near colours (the art's slight noise grouped),
    then that family's commonest exact colour from the original (never a mixed one)."""
    fam = Counter((p[0] // 24, p[1] // 24, p[2] // 24) for p in pixels).most_common(1)[0][0]
    return Counter(p for p in pixels if (p[0] // 24, p[1] // 24, p[2] // 24) == fam).most_common(1)[0][0]


def variant(src: Image.Image, n: int) -> Image.Image:
    side = src.size[0]
    px = src.load()
    out = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    op = out.load()
    for oy in range(n):
        y0, y1 = oy * side // n, max(oy * side // n + 1, (oy + 1) * side // n)
        for ox in range(n):
            x0, x1 = ox * side // n, max(ox * side // n + 1, (ox + 1) * side // n)
            block = [px[x, y] for y in range(y0, y1) for x in range(x0, x1)]
            opaque = [p for p in block if p[3] > 0]
            if len(opaque) * 2 < len(block):
                continue   # mostly outside the coin: clear
            dark = [p for p in opaque if is_outline(p)]
            pick = dark if len(dark) >= OUTLINE_SHARE * len(opaque) else [p for p in opaque if not is_outline(p)]
            op[ox, oy] = most_common(pick)
    return out


def main() -> None:
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    src = trim_square(remove_background(Image.open(sys.argv[1])))
    os.makedirs(OUT, exist_ok=True)
    src.save(os.path.join(OUT, "credit_coin.png"), optimize=False)
    print("credit_coin.png", src.size)
    for n in SIZES:
        variant(src, n).save(os.path.join(OUT, "credit_coin_%d.png" % n), optimize=False)
        print("credit_coin_%d.png" % n)


if __name__ == "__main__":
    main()

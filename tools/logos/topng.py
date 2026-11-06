import sys, os, re
from PIL import Image
d = sys.argv[1]
for line in open(sys.argv[2]):
    m = re.match(r"(\S+) (\d+)x(\d+)", line)
    n, w, h = m.group(1), int(m.group(2)), int(m.group(3))
    data = open(os.path.join(d, n + ".raw"), "rb").read()
    ch = len(data) // (w * h)
    mode = {1: "L", 3: "RGB", 4: "CMYK"}[ch]
    Image.frombytes(mode, (w, h), data).convert("RGB").save(os.path.join(d, n + ".png"))
    print(n, ch)

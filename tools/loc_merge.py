"""Merge new translations into Pixel Polo's language catalogs (game/locale/*.json).

    python tools/loc_merge.py batch.json [--check]

batch.json maps each Apple locale id to the strings to add or change, keyed by the English
(United States) text exactly as the code shows it:

    {"de": {"ROSTER": "KADER", "%d WINS": "%d SIEGE"},
     "ja": {"ROSTER": "ロスター", ...},
     "plurals": {"%d WINS": {"de": {"one": "%d SIEG", "other": "%d SIEGE"}, ...}}}

Every new English key is also added to en-US.json (the source catalog the game's test checks
every language against). Regional variants (en-GB, en-AU, en-CA, fr-CA, es-MX) inherit their
parent's strings; give them a key only where their wording differs.

--check only validates the catalogs: every non-English full catalog has every key, every
translation keeps the English text's %s / %d placeholders in order.
"""
import json, os, re, sys

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "game", "locale")
VARIANTS = {"en-GB", "en-AU", "en-CA", "fr-CA", "es-MX"}

def load(loc):
    with open(os.path.join(ROOT, loc + ".json"), encoding="utf-8") as f:
        return json.load(f)

def save(loc, d):
    with open(os.path.join(ROOT, loc + ".json"), "w", encoding="utf-8", newline="\n") as f:
        json.dump(d, f, ensure_ascii=False, indent="\t")
        f.write("\n")

TOK = re.compile(r"%[-+ 0#]*[0-9]*(?:\.[0-9]+)?[sdif]|%%|\{[A-Za-z_]+\}")

def slots(s):
    seq, suffix, named = [], [], []
    prev_end, prev = 0, ""
    for m in TOK.finditer(s):
        t = m.group(0)
        start = m.start()
        before = s[start - 1:start] if start > prev_end else ""   # (literal text only)
        joined = start == prev_end and prev == "%s"               # ("%s%s": a plural ending or a joined piece)
        prev_end, prev = m.end(), t
        if t.startswith("{"):
            named.append(t)
            continue
        after = s[m.end():m.end() + 1]
        if t == "%s" and ((before.isalpha() and not after.isalpha()) or joined):
            suffix.append(len(seq))
        seq.append(t)
    return seq, suffix, named
## the same rules as the game (Loc.Catalog): %x in order (an English plural ending may be left
## out), {name} slots by name, |marks| and edge spaces kept
def check_one(key, tr):
    probs = []
    if not isinstance(tr, str) or not tr.strip():
        return ["empty"]
    kseq, ksuf, knamed = slots(key)
    tseq, _, tnamed = slots(tr)
    without = [t for i, t in enumerate(kseq) if i not in ksuf]
    if tseq != kseq and tseq != without:
        probs.append(f"placeholders {kseq} (or without the plural endings: {without}) but got {tseq}")
    if sorted(knamed) != sorted(tnamed):
        probs.append(f"named slots {sorted(knamed)} but got {sorted(tnamed)}")
    if key != key.strip():
        if key.startswith(" ") and not tr.startswith(" ") and tr[:1].isalnum():   # (", ..." is fine)
            probs.append("lost the leading space")
        if key.endswith(" ") and not tr.endswith(" "):
            probs.append("lost the trailing space")
    if key.count("|") != tr.count("|"):
        probs.append("the | marks differ")
    return probs


def check():
    src = load("en-US")["strings"]
    errors = []
    for fn in sorted(os.listdir(ROOT)):
        loc = fn[:-5]
        if not fn.endswith(".json") or loc == "en-US":
            continue
        d = load(loc)
        s = d.get("strings", {})
        for k, v in s.items():
            if k not in src:
                errors.append(f"{loc}: key not in en-US.json: {k!r}")
            else:
                for prob in check_one(k, v):
                    errors.append(f"{loc}: {k!r} -> {v!r}: {prob}")
        if loc not in VARIANTS and not loc.startswith("en-"):
            for k in src:
                if k not in s:
                    errors.append(f"{loc}: missing {k!r}")
    for e in errors:
        print(e)
    print(f"{len(errors)} problem(s)")
    return not errors

def merge(path):
    with open(path, encoding="utf-8") as f:
        batch = json.load(f)
    plurals = batch.pop("plurals", {})
    src = load("en-US")
    new_keys = set()
    for loc, strings in batch.items():
        d = load(loc)
        d.setdefault("strings", {}).update(strings)
        save(loc, d)
        new_keys.update(strings)
    for k in sorted(new_keys):
        src["strings"].setdefault(k, k)
    for key, per_loc in plurals.items():
        for loc, forms in per_loc.items():
            if loc == "en-US":
                src.setdefault("plurals", {})[key] = forms
                continue
            d = load(loc)
            d.setdefault("plurals", {})[key] = forms
            save(loc, d)
    save("en-US", src)
    print(f"merged {len(new_keys)} key(s) into {len(batch)} locale(s)")

if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] != "--check":
        merge(sys.argv[1])
    sys.exit(0 if check() else 1)

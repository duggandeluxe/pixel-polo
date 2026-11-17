# Team logos from the Road to Glory logo sheet

The school logos in `game/assets/logos/` are cut from the supplied PDF (one labelled logo per
school, 29 of them; the Pacific Grove Redwoods, then Stanford, had a generated letter). Since
2026-11-08 most schools use a supplied logo instead (`SUPPLIED` in `logos_full.py`; the untouched
files in `originals/`, the Redwoods' among them). The full-resolution originals,
backdrop removed, are kept untouched in `source/` (they don't ship with the game). Irvine's
aardvark head was supplied directly as `source/ICU.png` (`SUPPLIED` in `logos_full.py`), replacing
the sheet's gold "A", and so were Malibu's wave (`source/PPCU.png`) and New Jersey's Bengal tiger
head (`source/PRIN.png`, replacing the striped "B"), and Lewisburg's buffalo head
(`source/BUCK.png`, from `originals/lewisburg_buffalo.png`, replacing the orange "LB"); the
rebuild reads them from there and never overwrites them.

On 2026-11-09 Staten Island (`WAGN`) got a full-body diving hawk and Erie (`HURST`) a symmetrical
front-facing lakehawk head, replacing their side-profile heads (the untouched references are
`originals/staten_island_hawks_diving.png` and `originals/erie_lakehawks_front.png`; the old ones
stay beside them). Their `source/` cut-outs drop the diving hawk's white speckle (largest
connected piece after a small opening) and Erie's navy backdrop and glow (flood-filled from the
edge up to its white outline). Both reduce to 24 colours before matching (`PALETTE` in `fine.py`)
so the hawk's gold talons and eye and Erie's teal and grey beak survive.

Each logo is saved once per box the screens draw it in (`_s` 20x12, `_m` 28x20, `_40`, `_48`,
`_60`), and the game draws each file 1:1 with nearest-neighbour filtering (TeamLogo), so nothing
is ever rescaled at runtime. **Every size comes straight from the full-resolution original**: no
size is made from another, reduced one.

- Faithful by default: each target pixel takes the most common colour of its block of the original
  (every colour the logo has, no blending, transparency kept).
- A dedicated small variant only where the faithful one can't show the logo clearly at a list
  size (`SMALL_VARIANTS` in `logos_full.py`, chosen by comparing them side by side): `small.py`
  draws the logo's body and one ring of its own trim colour.

Rebuild:

    swiftc -O extract.swift -o extract && swiftc -O render.swift -o render
    ./extract sheet.pdf raw > raw/list.txt     # embedded images + where each sits on its page
    python3 topng.py raw raw/list.txt          # raw RGB streams -> PNG
    ./render sheet.pdf pages 4                 # pages at 4x, to find each image's visible crop
    python3 logos_full.py raw pages out source # needs numpy, pillow, scipy; then copy out/*.png

The list marks also have fine files for detail mode screens (`_fs` 30x18, `_fm` 42x30): the same
on-screen boxes as `_s` and `_m`, in art pixels two window pixels wide. They need only `source/`:

    python3 fine.py source out                 # then copy out/*.png

The order of `IDS` in `logos_full.py` is the order the logos appear in the PDF. (`logos.py` is the
earlier pipeline, which worked from a 480 px copy; kept for reference.)

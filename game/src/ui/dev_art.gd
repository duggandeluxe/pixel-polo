class_name DevArt
## The look of a DEV RECRUIT (DevRecruits), drawn wherever his card or attributes are: the
## Recruiting Market card, his profile, the roster card, Developer Mode's DEV RECRUITS. Everything
## is keyed on PoloPlayer.dev_recruit, never his name.
##   panel()       the light icy-blue card: a darker blue pixel border with cut corners, a lit
##                 top-left rim, cyan glints in two corners and a dithered shade at the bottom
##   chip()        DEV RECRUIT: white pixel capitals on a dark navy chip with an electric-blue edge
##                 (now only the roster card's short DEV: the market card and the profile carry no
##                 label, their cards glitch instead: DevGlitch)
##   overcharge()  a CORRUPTED attribute bar, on top of the ordinary ten boxes, for an attribute past
##                 10: the boxes it fills twice over (the excess, counted from the right) charged
##                 cyan and white, offset scanline slices, dead pixels knocked out of the charged
##                 boxes, and stray pixel fragments (cyan, bright blue, white, now and then magenta)
##                 that move several times a second: twice the first version's density. Never out
##                 of the bar's rect; Reduce Motion holds it still.
##   value_text()  "12/10": always out of the normal ten

const ICE := Color("c4e9ff")          # the card's light icy blue
const ICE_HI := Color("eaf8ff")       # its lit rim
const ICE_SHADE := Color("a3d4f2")    # its pixel shade
const ICE_DEEP := Color("4d9be0")     # the portrait's panel on it
const EDGE := Color("1a4fa3")         # the darker blue pixel border
const EDGE_DARK := Color("0d2a66")
const CYAN := Color("39e8ff")
const ELECTRIC := Color("2b74ff")
const MAGENTA := Color("ff3fd8")
const LABEL_BG := Color("0a1a4a")     # the DEV RECRUIT chip's navy
const INK := Color("0a1f4f")          # text on the ice
const INK_SOFT := Color("24508f")
const LABEL := "DEV RECRUIT"
## The corrupted bar's pattern moves this many times a second (a little livelier than the first
## version's 5, still calm: small pixels inside the bar, never a flash).
const GLITCH_HZ := 7.0
## Offset scanline slices a frame (twice the first version's 2).
const SLICES := 4

static func is_dev(p: PoloPlayer) -> bool:
	return p != null and p.dev_recruit != ""

## "12/10" ("2/10"): an attribute out of the normal ten, whatever it is.
static func value_text(v: float) -> String:
	var r := snappedf(v, 0.01)
	return ("%d/10" % roundi(r)) if is_equal_approx(r, roundf(r)) else ("%s/10" % Attributes.text(r))

# ------------------------------------------------------------------ the card
## The light-blue card filling `r`: border included (1 px, cut corners).
static func panel(ci: CanvasItem, r: Rect2, hover: bool = false) -> void:
	r = Rect2(r.position.floor(), r.size.floor())
	var fill := ICE.lightened(0.06) if hover else ICE
	ci.draw_rect(r.grow(-1), fill)
	# the shade: the bottom third a step darker, a checker row of pixels where it starts
	var sy := floorf(r.position.y + r.size.y * 0.68)
	ci.draw_rect(Rect2(r.position.x + 1, sy + 1, r.size.x - 2, r.end.y - sy - 2), ICE_SHADE)
	var x := r.position.x + 1.0
	while x < r.end.x - 1.0:
		ci.draw_rect(Rect2(x, sy, 1, 1), ICE_SHADE)
		x += 2.0
	# the lit rim (top and left) and the darker one (right and bottom)
	ci.draw_rect(Rect2(r.position.x + 1, r.position.y + 1, r.size.x - 2, 1), ICE_HI)
	ci.draw_rect(Rect2(r.position.x + 1, r.position.y + 1, 1, r.size.y - 2), ICE_HI)
	ci.draw_rect(Rect2(r.end.x - 2, r.position.y + 2, 1, r.size.y - 3), Color(EDGE, 0.25))
	ci.draw_rect(Rect2(r.position.x + 2, r.end.y - 2, r.size.x - 3, 1), Color(EDGE, 0.25))
	# cyan glints: top right and bottom left
	for g in [Vector2(r.end.x - 6, r.position.y + 3), Vector2(r.position.x + 4, r.end.y - 6)]:
		ci.draw_rect(Rect2(g, Vector2(1, 1)), CYAN)
		ci.draw_rect(Rect2(g + Vector2(-1, 1), Vector2(3, 1)), Color(CYAN, 0.7))
		ci.draw_rect(Rect2(g + Vector2(0, 2), Vector2(1, 1)), CYAN)
	border(ci, r, EDGE)

## The 1 px pixel border with cut corners (and a dark pixel in each corner's notch).
static func border(ci: CanvasItem, r: Rect2, col: Color = EDGE) -> void:
	r = Rect2(r.position.floor(), r.size.floor())
	ci.draw_rect(Rect2(r.position.x + 1, r.position.y, r.size.x - 2, 1), col)
	ci.draw_rect(Rect2(r.position.x + 1, r.end.y - 1, r.size.x - 2, 1), col)
	ci.draw_rect(Rect2(r.position.x, r.position.y + 1, 1, r.size.y - 2), col)
	ci.draw_rect(Rect2(r.end.x - 1, r.position.y + 1, 1, r.size.y - 2), col)
	for cpt in [Vector2(1, 1), Vector2(r.size.x - 2, 1), Vector2(1, r.size.y - 2), Vector2(r.size.x - 2, r.size.y - 2)]:
		ci.draw_rect(Rect2(r.position + cpt, Vector2(1, 1)), EDGE_DARK)

## A Control's stylebox for the same look (the profile's card, the dev lab's panels).
static func stylebox(pad: int = 6) -> StyleBox:
	var sb := UI.chunky(ICE, EDGE, false, false, pad, pad)
	return sb

# ------------------------------------------------------------------ the label
## Its size at `size` (8: the cards; 16: the big one).
static func chip_size(size: int = 8, text: String = LABEL) -> Vector2:
	var font := "big" if size >= 16 else "caps"
	return Vector2(ceilf(Deck.text_w(text, size, font)) + 8.0, 13.0 if size >= 16 else 10.0)

## DEV RECRUIT (or `text`: the roster card's short DEV), its top left at `at`. Returns its width.
static func chip(ci: CanvasItem, at: Vector2, size: int = 8, text: String = LABEL) -> float:
	var sz := chip_size(size, text)
	var r := Rect2(at.floor(), sz)
	ci.draw_rect(r, ELECTRIC)
	ci.draw_rect(r.grow(-1), LABEL_BG)
	ci.draw_rect(Rect2(r.position + Vector2(1, 1), Vector2(r.size.x - 2, 1)), Color(CYAN, 0.55))
	Deck.ctext(ci, Rect2(r.position + Vector2(0, 1), r.size - Vector2(0, 1)), text, size, Color.WHITE, "big" if size >= 16 else "caps")
	return sz.x

## The same, centred in `w` from `x`.
static func chip_centred(ci: CanvasItem, x: float, y: float, w: float, size: int = 8) -> void:
	chip(ci, Vector2(floorf(x + (w - chip_size(size).x) * 0.5), y), size)

## A Control holding the chip, centred (the profile, the dev lab).
static func chip_control(size: int = 8) -> Control:
	var cv := UI.canvas(0, int(chip_size(size).y), func(ci: Control): chip_centred(ci, 0, 0, ci.size.x, size))
	cv.name = "DevLabel"
	cv.set_meta("text", LABEL)
	return cv

# ------------------------------------------------------------------ the corrupted bar
## The glitch over the ten boxes (`r`, Deck.attr_boxes' rect) of an attribute `v` past 10, at time
## `t` (s). Nothing for 10 or under.
static func overcharge(ci: CanvasItem, r: Rect2, v: float, t: float) -> void:
	if not Attributes.over_max(v):
		return
	var still := not Juice.enabled()
	var frame := 0 if still else int(floorf(t * GLITCH_HZ))
	var extra := clampi(ceili(v - Attributes.MAX - Attributes.PRECISION), 1, Deck.BOX_N)
	# the boxes counted twice: the last `extra`, charged
	for i in range(Deck.BOX_N - extra, Deck.BOX_N):
		var b := Deck.box_rect(r, i)
		var inner := b.grow(-1.0)
		ci.draw_rect(b, ELECTRIC)
		ci.draw_rect(inner, CYAN)
		ci.draw_rect(Rect2(inner.position, Vector2(inner.size.x, 1)), Color.WHITE)
		# a second, offset fill: the overcharge
		var half := floorf(inner.size.y * 0.5)
		var shift := 1.0 if (frame + i) % 3 != 2 else 0.0   # (two frames in three: twice the old one)
		ci.draw_rect(Rect2(inner.position + Vector2(shift, half), Vector2(maxf(1.0, inner.size.x - 1.0 - shift), 1)), ELECTRIC)
		if inner.size.x >= 4.0:
			ci.draw_rect(Rect2(inner.position + Vector2(1, inner.size.y - 2), Vector2(2, 1)), Color.WHITE)
	# scanline slices: one row of a filled box shifted a pixel, in cyan
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([frame, roundi(v * 100.0), "glitch"])
	for _s in SLICES:
		var i := rng.randi_range(0, Deck.BOX_N - 1)
		var b := Deck.box_rect(r, i)
		var y := b.position.y + 1.0 + float(rng.randi_range(1, maxi(1, int(b.size.y) - 3)))
		var dx := 1.0 if rng.randf() < 0.5 else -1.0
		var x0 := clampf(b.position.x + dx, r.position.x, r.end.x - b.size.x)
		ci.draw_rect(Rect2(x0, y, b.size.x, 1), Color(CYAN, 0.85))
	# broken segments: a dead pixel or two knocked out of the charged boxes
	for _d in extra:
		var b := Deck.box_rect(r, rng.randi_range(Deck.BOX_N - extra, Deck.BOX_N - 1)).grow(-1.0)
		if b.size.x >= 2.0 and b.size.y >= 2.0:
			var dw := float(rng.randi_range(1, 2))
			ci.draw_rect(Rect2(b.position.x + floorf(rng.randf() * (b.size.x - dw)), b.position.y + floorf(rng.randf() * (b.size.y - 1.0)), dw, 1), EDGE_DARK)
	# stray fragments, more the further past 10 it is; inside the rect, never past it
	var n := fragments(extra)
	for _f in n:
		var fw := float(rng.randi_range(1, 3))
		var fh := float(rng.randi_range(1, 2))
		var fx := r.position.x + floorf(rng.randf() * maxf(1.0, r.size.x - fw))
		var fy := r.position.y + floorf(rng.randf() * maxf(1.0, r.size.y - fh))
		var roll := rng.randf()
		var col := MAGENTA if roll < 0.16 else (Color.WHITE if roll < 0.42 else (CYAN if roll < 0.75 else ELECTRIC))
		ci.draw_rect(Rect2(fx, fy, fw, fh), col)

## How many stray fragments a bar `extra` boxes past 10 throws off each frame (twice the first version's 3 + 2 a box).
static func fragments(extra: int) -> int:
	return 6 + extra * 4

## True when anything about this attribute row needs redrawing every frame (a live glitch).
static func animates(v: float) -> bool:
	return Attributes.over_max(v) and Juice.enabled()

## "STRENGTH  12/10" beside the boxes: the value at the right of the name column, cyan when it's
## past 10, else white. `x_right` its right edge. `hot`: his HOT bonus on it (Attributes.hot_bonus),
## shown in fiery red straight after his own number ("8" + ".5" + "/10"; "8" + "+1" + "/10").
static func draw_value(ci: CanvasItem, x_right: float, y_mid: float, v: float, hot: float = 0.0) -> void:
	var over := Attributes.over_max(v)
	var s := value_text(v)
	var parts := value_parts(v, hot)
	var base: String = parts[0]
	var red: String = parts[1]
	var tail := "/10"
	var full := base + red + tail
	var x := x_right - Deck.text_w(full)
	if over:
		Deck.text(ci, x_right - Deck.text_w(s) + 1, y_mid, s, 8, Color(MAGENTA, 0.55))   # a pixel's ghost behind it
	var col := CYAN if over else UI.TEXT
	Deck.shadow_text(ci, x, y_mid, base, 8, col)
	x += Deck.text_w(base)
	if red != "":
		Deck.shadow_text(ci, x, y_mid, red, 8, PlayerForm.FIRE_RED)
		x += Deck.text_w(red)
	Deck.shadow_text(ci, x, y_mid, tail, 8, col)

## [his own number, the HOT part in red] for value `v` with HOT bonus `hot`: a whole number HOT
## reads "8" + ".5"; anything else gets a "+": "8" + "+1", "7.5" + "+.5".
static func value_parts(v: float, hot: float = 0.0) -> Array:
	var base := value_text(v).trim_suffix("/10")
	if hot <= 0.0:
		return [base, ""]
	var whole := is_equal_approx(snappedf(v, 0.01), roundf(v))
	if whole and is_equal_approx(hot, 0.5):
		return [base, ".5"]
	var h := ("%d" % roundi(hot)) if is_equal_approx(hot, roundf(hot)) else Attributes.text(hot).trim_prefix("0")
	return [base, "+" + h]

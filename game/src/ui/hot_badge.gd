extends RefCounted
## The fire on a HOT / VERY HOT man's red stars on a roster card (Roster.paint_card, and so the
## postgame HOT reveal's card too). No words: his red stars burn instead.
##   HOT       each red star sits in a yellow halo, small flame tongues licking up off it.
##   VERY HOT  the same, a little bigger: an orange ring outside the halo on the top and sides,
##             taller tongues (one connected fire, no loose embers).
## Both draw in two layers: under() before the stars (the halo, rings and tongues, so the star's
## own outline stays crisp on top), over() after them (a hot yellow core inside each red star).
## With motion on (Juice.enabled: not Reduce Motion, not in tests) the tongues flicker, each star
## a step out of time with the next; otherwise frame 0, still.

const FLICKER := 0.14      # s a flame frame
const FRAMES := 3

# the fire's colours
const FLAME_W := Color("fff6c8")   # the hottest: the core
const FLAME_Y := Color("ffd23f")   # the halo
const FLAME_R := Color("ff9a2a")   # orange: the ring, the tongues' base
const FLAME_D := Color("ff4a1a")   # red-orange: VERY HOT's outer ring, the tongues' tips
const FLAME_DARK := Color("b8240e") # the outer ring's lower edge, the tallest tips
const EMBER := Color("ffe14a")

## VERY HOT's flame (the HOT tutorial's flames use it), 6 x 9: r rim, y yellow, w core; two frames.
const FLAME_VERY := [
	["...r..", "..ry..", "..ryr.", ".ryyr.", ".ryyyr", "ryywyr", "rywwyr", "rywwyr", ".rrrr."],
	["..r...", "..yr..", ".ryr..", ".ryyr.", "ryyyr.", "ryywyr", "rywwyr", "rywwyr", ".rrrr."],
]

## Tongue heights over a star, per column -2..10 (13 columns), FRAMES frames; HOT uses them
## minus one, capped at TONGUE_HOT.
## Each frame is one connected fire: neighbouring columns step by at most one, so the tongues
## rise out of each other rather than as lone pixels.
const TONGUES := [
	[0, 0, 1, 2, 1, 2, 3, 2, 1, 2, 1, 0, 0],
	[0, 0, 1, 1, 2, 3, 2, 1, 2, 2, 1, 0, 0],
	[0, 0, 1, 2, 2, 2, 3, 3, 2, 1, 1, 0, 0],
]
const TONGUE_HOT := 2
## The star's core: lit pixels inside a red star (x, y in the 9 x 9 star).
const CORE := [Vector2i(4, 3), Vector2i(4, 4), Vector2i(3, 4), Vector2i(5, 4), Vector2i(4, 5)]
const CORE_HOT := [Vector2i(4, 4), Vector2i(4, 5)]

static var _rings := {}

## Frame `n` of the flicker now (0 still: Reduce Motion, tests, or `t` given as 0).
static func frame(t: float = -1.0) -> int:
	if t < 0.0:
		if not Juice.enabled():
			return 0
		t = Time.get_ticks_msec() / 1000.0
	return int(t / FLICKER) % FRAMES

## A changing step of the animation (a card repaints only when it changes): -1 when still.
static func anim_step() -> int:
	return frame() if Juice.enabled() else -1

## The places of a bar that show a red (HOT) star.
static func red_places(cur: float, pot: float, state: String) -> Array:
	var out: Array = []
	var n := PlayerForm.red_stars(state)
	if n <= 0:
		return out
	var fills := Deck.star_fills(cur, pot, n)
	for i in fills.size():
		var f: Dictionary = fills[i]
		if float(f.form) > float(f.gold) and Color(f.form_col) == PlayerForm.FIRE_RED:
			out.append(i)
	return out

## The box the fire covers round a bar's red stars at `at` (the bar's top left), for tests and
## the HOT tutorial's highlight. Empty for NORMAL.
static func rect(at: Vector2, cur: float, pot: float, state: String) -> Rect2:
	var places := red_places(cur, pot, state)
	if places.is_empty():
		return Rect2()
	var very := state == PlayerForm.VERY_HOT
	var pad := 2.0 if very else 1.0
	var rise := pad + float(3 if very else TONGUE_HOT)
	var x0 := at.x + Deck.star_x(places[0]) - pad
	var x1 := at.x + Deck.star_x(places[-1]) + float(Deck.STAR_SHAPE.w) + pad
	return Rect2(x0, at.y - rise, x1 - x0, float(Deck.STAR.size()) + rise + 1.0)   # (only the halo runs under a star)

## Before the stars: the halo, rings and tongues round each red star of the bar at `at`.
static func under(ci: CanvasItem, at: Vector2, cur: float, pot: float, state: String, t: float = -1.0) -> void:
	var very := state == PlayerForm.VERY_HOT
	var n := frame(t)
	for i: int in red_places(cur, pot, state):
		var o := at + Vector2(Deck.star_x(i), 0)
		var fr := (n + i) % FRAMES   # (neighbours flicker out of step)
		var top := _top_of(very)
		# the tongues, rising off the fire's top edge
		var hs: Array = TONGUES[fr]
		for c in hs.size():
			var h := int(hs[c]) if very else mini(int(hs[c]) - 1, TONGUE_HOT)
			var x := c - 2
			if h <= 0 or not top.has(x):
				continue
			var y0: int = top[x]
			for k in h:
				var col := FLAME_R if k == 0 else (FLAME_D if k < h - 1 or h < 3 else FLAME_DARK)
				ci.draw_rect(Rect2(o.x + x, o.y + y0 - 1 - k, 1, 1), col)
		if very:
			for p: Vector2i in _ring(1.5):
				ci.draw_rect(Rect2(o.x + p.x, o.y + p.y, 1, 1), FLAME_R if p.y < 6 else FLAME_D)
		for p: Vector2i in _ring(1):
			ci.draw_rect(Rect2(o.x + p.x, o.y + p.y, 1, 1), FLAME_Y)

## After the stars: a hot core glowing inside each red star.
static func over(ci: CanvasItem, at: Vector2, cur: float, pot: float, state: String) -> void:
	var very := state == PlayerForm.VERY_HOT
	for i: int in red_places(cur, pot, state):
		var o := at + Vector2(Deck.star_x(i), 0)
		for p: Vector2i in (CORE if very else CORE_HOT):
			ci.draw_rect(Rect2(o.x + p.x, o.y + p.y, 1, 1), FLAME_Y if p == Vector2i(4, 4) or not very else FLAME_R)
		ci.draw_rect(Rect2(o.x + 4, o.y + 4, 1, 1), FLAME_W)

## The pixels round the star (Deck.STAR) out to ring `d`: 1 the halo hugging it (8 neighbours),
## 1.5 VERY HOT's orange ring outside that on the top and sides (4 neighbours), 2 one more.
static func _ring(d: float) -> Array:
	if _rings.has(d):
		return _rings[d]
	var star := {}
	for y in Deck.STAR.size():
		var row: String = Deck.STAR[y]
		for x in row.length():
			if row[x] == "#":
				star[Vector2i(x, y)] = true
	var inside := star.duplicate()
	var out: Array = []
	var steps := [[1, true], [1.5, false], [2, false]]
	for s: Array in steps:
		var ring := {}
		for p: Vector2i in inside:
			for dy in [-1, 0, 1]:
				for dx in [-1, 0, 1]:
					if not bool(s[1]) and dx != 0 and dy != 0:
						continue
					var q := p + Vector2i(dx, dy)
					if not inside.has(q):
						ring[q] = true
		if float(s[0]) > 1.0:
			# the outer rings hug the top and sides only: fire rises, none along the bottom
			for q: Vector2i in ring.keys():
				if q.y > 8:
					ring.erase(q)
		for q in ring:
			inside[q] = true
		if is_equal_approx(float(s[0]), d):
			out = ring.keys()
			break
	_rings[d] = out
	return out

## The fire's top edge per column (the topmost ring pixel in it), where the tongues start.
static func _top_of(very: bool) -> Dictionary:
	var top := {}
	var rings: Array = [_ring(1)]
	if very:
		rings.append(_ring(1.5))
	for r: Array in rings:
		for p: Vector2i in r:
			if not top.has(p.x) or p.y < int(top[p.x]):
				top[p.x] = p.y
	return top

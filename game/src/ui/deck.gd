class_name Deck
extends RefCounted
## The Deck Blue menu kit (from Retro Swim): segmented bars, mood faces, coins, stripes,
## chunky caps buttons and cards that paint themselves.
## Everything is drawn with rects in the game's own pixel fonts; small textures are made once.
const _StarFlames := preload("res://src/ui/hot_badge.gd")   # the fire round red stars (HotBadge)

const RED := Color("ff4a4a")
const ORANGE := Color("f2a921")
const LIME := Color("7fe35f")
const LOCK := Color("a9bdf0")
# navy panels (school picker, dashboard): fill, header band, alternating rows, hover, edge
const NAVY := Color("0b1d5c")
const NAVY_HEAD := Color("14318c")
const ROW_A := Color("102878")
const ROW_B := Color("0d2268")
const ROW_HOVER := Color("1a3a9a")
const EDGE := Color("4a86ff")

const COIN := ["..###..", ".#####.", "#######", "###.###", "###.###", "#######", ".#####.", "..###.."]
const ICONS := {
	"home": [".....#.....", "....###....", "...#####...", "..#######..", ".#########.", "###########",
		".##.....##.", ".##.###.##.", ".##.###.##.", ".##.###.##."],
	"info": ["##", "##", "..", "##", "##", "##", "##", "##"],
	"left": ["...##", "..##.", ".##..", "##...", ".##..", "..##.", "...##"],
	"right": ["##...", ".##..", "..##.", "...##", "..##.", ".##..", "##..."],
	"plus": ["..#..", "..#..", "#####", "..#..", "..#.."],
	"x": ["#...#", ".#.#.", "..#..", ".#.#.", "#...#"],
	"gear": ["...#.#...", "..#####..", ".##...##.", "##..#..##", ".#.###.#.", "##..#..##", ".##...##.", "..#####..", "...#.#..."],
	"help": [".####.", "##..##", "....##", "...##.", "..##..", "..##..", "......", "..##..", "..##.."],
	"edit": [".....#.", "....###", "...###.", "..###..", ".###...", "#.#....", "##....."],
	"lock": [".###.", "#...#", "#...#", "#####", "##.##", "##.##", "#####"],
}

static var _tex := {}

# ------------------------------------------------------------------ positions
## A colour per position (PoloPlayer.Pos), for card stripes and tags.
const POS_COLORS := ["ff4a4a", "f2a921", "5cc8ff", "7fe35f", "c07bff", "39b44a"]

static func pos_color(pos: int) -> Color:
	return Color(POS_COLORS[clampi(pos, 0, POS_COLORS.size() - 1)])

static func pos_tag(p: PoloPlayer) -> String:
	return p.pos_text()

# ------------------------------------------------------------------ text
static func font_of(name: String) -> Font:
	match name:
		"big":
			return UI.font_big
		"body":
			return UI.font_body
	return UI.font_caps

## y_mid = the vertical middle of the line. align 0/1/2 = left/center/right inside w.
static func text(ci: CanvasItem, x: float, y_mid: float, s: String, size: int = 8, col: Color = UI.TEXT, font: String = "caps", align: int = 0, w: float = -1.0) -> void:
	s = Loc.t(s)   # (the player's LANGUAGE)
	if UI.drawn_log != null:
		UI.drawn_log.append(s)
	var f := font_of(font)
	size = UI.fit_size(f, s, size, w)   # (a longer LANGUAGE in a set width: smaller, never past it)
	var base := floorf(y_mid + (f.get_ascent(size) - f.get_descent(size)) * 0.5)
	ci.draw_string(f, Vector2(floorf(x), base), s, align, w, size, col)

static func text_w(s: String, size: int = 8, font: String = "caps") -> float:
	s = Loc.t(s)
	return font_of(font).get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x

static func ctext(ci: CanvasItem, r: Rect2, s: String, size: int = 8, col: Color = UI.TEXT, font: String = "caps") -> void:
	text(ci, r.position.x, r.position.y + r.size.y * 0.5, s, size, col, font, 1, r.size.x)

static func rtext(ci: CanvasItem, x_right: float, y_mid: float, s: String, size: int = 8, col: Color = UI.TEXT, font: String = "caps") -> void:
	text(ci, x_right - text_w(s, size, font), y_mid, s, size, col, font)

static func shadow_text(ci: CanvasItem, x: float, y_mid: float, s: String, size: int = 8, col: Color = UI.TEXT, font: String = "caps", align: int = 0, w: float = -1.0) -> void:
	text(ci, x + 1, y_mid + 1, s, size, Color(0.02, 0.06, 0.25, 0.7 * col.a), font, align, w)
	text(ci, x, y_mid, s, size, col, font, align, w)

## Keeps a long name inside w pixels (drops letters and adds a dot).
static func fit(s: String, w: float, size: int = 8, font: String = "caps") -> String:
	s = Loc.t(s)   # (the player's LANGUAGE: translated whole, then cut short if it must be)
	if text_w(s, size, font) <= w:
		return s
	var t := s
	while t.length() > 1 and text_w(t + ".", size, font) > w:
		t = t.substr(0, t.length() - 1)
	return t + "."

# ------------------------------------------------------------------ drawing
## A chunky box: 1 px border, cut corners, optional drop shadow 1 right and 2 down, and optional
## bevel (UI.BEVEL_RAISED / SUNK / SOFT: the same ring UI.chunky puts inside a stylebox).
static func frame(ci: CanvasItem, r: Rect2, fill: Color, border: Color = UI.BORDER, shadow: bool = false, bevel: int = UI.BEVEL_NONE) -> void:
	r = Rect2(r.position.floor(), r.size.floor())
	if shadow:
		_box(ci, Rect2(r.position + Vector2(1, 2), r.size), UI.SHADOW, UI.SHADOW)
	_box(ci, r, fill, border)
	bevel_ring(ci, r, fill, bevel, border)

## The bevel inside a frame drawn at `r` (UI._bevel_px, drawn on a canvas).
static func bevel_ring(ci: CanvasItem, r: Rect2, fill: Color, bevel: int, border: Color = UI.BORDER) -> void:
	if bevel == UI.BEVEL_NONE or r.size.x < 6 or r.size.y < 6:
		return
	var x0 := r.position.x + 1
	var y0 := r.position.y + 1
	var x1 := r.end.x - 2   # the ring's last column / row
	var y1 := r.end.y - 2
	if bevel == UI.BEVEL_DOUBLE:
		ci.draw_rect(Rect2(x0, y0, x1 - x0 + 1, 1), border)
		ci.draw_rect(Rect2(x0, y1, x1 - x0 + 1, 1), border)
		ci.draw_rect(Rect2(x0, y0 + 1, 1, y1 - y0 - 1), border)
		ci.draw_rect(Rect2(x1, y0 + 1, 1, y1 - y0 - 1), border)
		return
	if fill.a < 0.99:
		return
	var soft := bevel == UI.BEVEL_SOFT
	var lit := UI.bevel_light(fill, soft)
	var dark := UI.bevel_dark(fill, soft)
	if soft:
		ci.draw_rect(Rect2(x0 + 1, y0, x1 - x0 - 1, 1), lit)
		ci.draw_rect(Rect2(x0 + 1, y1, x1 - x0 - 1, 1), dark)
		return
	var top := dark if bevel == UI.BEVEL_SUNK else lit
	ci.draw_rect(Rect2(x0, y0, x1 - x0, 1), top)
	ci.draw_rect(Rect2(x0, y0 + 1, 1, y1 - y0 - 1), top)
	if bevel != UI.BEVEL_SUNK:
		ci.draw_rect(Rect2(x0 + 1, y1, x1 - x0, 1), dark)
		ci.draw_rect(Rect2(x1, y0 + 1, 1, y1 - y0), dark)

## THE POPUP drawn on a canvas (UI.popup_box's look, for screens that paint their own pop-ups):
## a hard shadow 2 right and 3 down, an ink outline, the kind's edge, the fill with its soft bevel.
static func popup(ci: CanvasItem, r: Rect2, kind: String = "info", fill: Color = UI.POPUP_FILL) -> void:
	r = Rect2(r.position.floor(), r.size.floor())
	var k := UI.popup_kind(kind)
	_box(ci, Rect2(r.position + Vector2(1, 2), r.size + Vector2(2, 2)), UI.POPUP_SHADOW, UI.POPUP_SHADOW)
	_box(ci, r.grow(1), UI.INK, UI.INK)
	ci.draw_rect(r, k.edge)
	ci.draw_rect(r.grow(-1), fill)
	bevel_ring(ci, r, fill, UI.BEVEL_SOFT)

## The popup's title plate in `r` (UI.popup_plate's look): the kind's dark band, a lit top line,
## its edge colour along the bottom.
static func popup_plate(ci: CanvasItem, r: Rect2, kind: String = "info") -> void:
	r = Rect2(r.position.floor(), r.size.floor())
	var k := UI.popup_kind(kind)
	ci.draw_rect(r, k.plate)
	ci.draw_rect(Rect2(r.position, Vector2(r.size.x, 1)), UI.bevel_light(k.plate, true))
	ci.draw_rect(Rect2(r.position.x, r.end.y - 1, r.size.x, 1), Color(k.edge, 0.7))

## A drawn button's face for a Deck.card mode ("normal", "hover", "down"): raised on its shadow,
## a step lighter with a brighter edge on hover, pressed down into the shadow's place and sunk.
## The same three looks as a stylebox button (UI.style_button). Returns the face's rect (it moves
## when pressed), for the label.
static func button_face(ci: CanvasItem, r: Rect2, fill: Color, border: Color, mode: String, shadow: bool = true) -> Rect2:
	r = Rect2(r.position.floor(), r.size.floor())
	if mode == "down":
		var at := Rect2(r.position + (Vector2(1, 2) if shadow else Vector2.ZERO), r.size)
		frame(ci, at, fill.darkened(0.1), border, false, UI.BEVEL_SUNK)
		return at
	var f := fill.lightened(0.15) if mode == "hover" else fill
	frame(ci, r, f, UI.hover_edge(border) if mode == "hover" else border, shadow, UI.BEVEL_RAISED)
	return r

static func _box(ci: CanvasItem, r: Rect2, fill: Color, border: Color) -> void:
	if fill.a > 0.0:
		ci.draw_rect(Rect2(r.position + Vector2(1, 1), r.size - Vector2(2, 2)), fill)
	ci.draw_rect(Rect2(r.position.x + 1, r.position.y, r.size.x - 2, 1), border)
	ci.draw_rect(Rect2(r.position.x + 1, r.end.y - 1, r.size.x - 2, 1), border)
	ci.draw_rect(Rect2(r.position.x, r.position.y + 1, 1, r.size.y - 2), border)
	ci.draw_rect(Rect2(r.end.x - 1, r.position.y + 1, 1, r.size.y - 2), border)

## n segments in a dark well, the first `filled` lit.
static func seg_bar(ci: CanvasItem, r: Rect2, n: int, filled: int, col: Color = UI.GOLD, well: Color = UI.INK) -> void:
	r = Rect2(r.position.floor(), r.size.floor())
	ci.draw_rect(r, well)
	var inner := Rect2(r.position + Vector2(1, 1), r.size - Vector2(2, 2))
	var sw := floorf((inner.size.x - (n - 1)) / n)
	var used := sw * n + (n - 1)
	var x0 := inner.position.x + floorf((inner.size.x - used) * 0.5)
	for i in range(n):
		ci.draw_rect(Rect2(x0 + i * (sw + 1), inner.position.y, sw, inner.size.y), col if i < filled else Color(1, 1, 1, 0.08))

static func bar(ci: CanvasItem, r: Rect2, v: float, col: Color = UI.GOLD, well: Color = UI.INK) -> void:
	r = Rect2(r.position.floor(), r.size.floor())
	ci.draw_rect(r, well)
	var inner := Rect2(r.position + Vector2(1, 1), r.size - Vector2(2, 2))
	var w := floorf(inner.size.x * clampf(v, 0.0, 1.0))
	if w > 0:
		ci.draw_rect(Rect2(inner.position, Vector2(w, inner.size.y)), col)

## 9x9 face: green smile, orange flat, red frown. `hi` / `lo`: where the smile and the frown start.
static func mood(ci: CanvasItem, p: Vector2, v: float, hi: float = 66.0, lo: float = 38.0) -> void:
	var col := LIME if v > hi else (ORANGE if v > lo else RED)
	var dk := Color(0.05, 0.05, 0.1)
	ci.draw_rect(Rect2(p.x + 1, p.y, 7, 9), col)
	ci.draw_rect(Rect2(p.x, p.y + 1, 9, 7), col)
	ci.draw_rect(Rect2(p.x + 2, p.y + 2, 1, 2), dk)
	ci.draw_rect(Rect2(p.x + 6, p.y + 2, 1, 2), dk)
	ci.draw_rect(Rect2(p.x + 2, p.y + 6, 5, 1), dk)
	if v > hi:
		ci.draw_rect(Rect2(p.x + 1, p.y + 5, 1, 1), dk)
		ci.draw_rect(Rect2(p.x + 7, p.y + 5, 1, 1), dk)
	elif v <= lo:
		ci.draw_rect(Rect2(p.x + 1, p.y + 7, 1, 1), dk)
		ci.draw_rect(Rect2(p.x + 7, p.y + 7, 1, 1), dk)

static func pat(ci: CanvasItem, p: Vector2, rows: Array, cols: Dictionary, s: float = 1.0) -> void:
	for y in range(rows.size()):
		var row: String = rows[y]
		for x in range(row.length()):
			var ch := row[x]
			if cols.has(ch):
				ci.draw_rect(Rect2(p.x + x * s, p.y + y * s, s, s), cols[ch])

## The game's one star, on every screen that shows stars (cards, pages, lists, the match, the
## labs): a five-pointed star 7 px across (STAR_INNER) inside a 1 px outline, 9 x 9 in all (STAR).
## Lit: gold (or a form's red) with a dark outline. Hollow: a dark inside with a light outline,
## fainter past his POTENTIAL. A half star is lit up to and including its centre column.
const STAR := ["....#....", "...###...", ".#######.", "#########", ".#######.", "..#####..", ".#######.", ".###.###.", "..#...#.."]
const STAR_INNER := [".........", "....#....", "....#....", ".#######.", "..#####..", "...###...", "..##.##..", "..#...#..", "........."]
const STAR_STEP := 10.0
const STAR_EDGE := UI.INK              # a lit star's outline
const STAR_HOLLOW := Color("1b2342")   # a hollow star's inside
const STAR_OPEN := Color("7886aa")     # a hollow star's outline, up to POTENTIAL...
const STAR_PAST := Color("3b4566")     # ...and past it

## `value` stars lit in `col` (half stars too) across `slots` places from (x, y) at the top left,
## the rest hollow. Returns the width drawn.
static func stars(ci: CanvasItem, x: float, y: float, value: float, slots: int, col: Color, empty: Color = Color(1, 1, 1, 0.14)) -> float:
	for i in slots:
		var lit := _fill(value - i)
		star_place(ci, Vector2(x + star_x(i), y), {"gold": 0.0, "form": lit, "form_col": col, "pot": 1.0}, empty)
	return (slots - 1) * STAR_STEP + int(STAR_SHAPE.w)

## A player's stars, the unified star bar: gold up to CURRENT, then his HOT form's red stars
## straight after the gold (one HOT, two VERY HOT), then hollow up to POTENTIAL, and nothing
## after it: the bar is only as long as he can grow (star_count), never padded out to five (a
## three-star who can't get better is three stars). Red goes straight after the gold even past
## five places (a five-star HOT: six stars, five gold then one red).
## (A team's OFF / DEF / GK and other fixed five-star rows pass POTENTIAL 5: always five places.)
## Stars aren't whole halves any more (OVERALL / 2): each value is drawn to the nearest half star
## (snap_half), the one rounding rule for every bar; the exact number is in the text beside it.
## Returns the width drawn.
const STAR_PLACES := 5
## The star's shape, as every bar draws it: the star, its width, the columns a half star fills,
## the step from one place to the next.
const STAR_SHAPE := {"star": STAR, "inner": STAR_INNER, "w": 9, "half": 5, "step": STAR_STEP}

static var _star_tex := {}

## The five-place star bar (the game's own star, gold to `stars`, half stars too, hollow after) as
## a texture, for where a picture goes in text (CreditCoin.rich's {stars:N}). The same pixels
## star_bar draws.
static func star_bar_texture(stars: float) -> Texture2D:
	var n := PlayerForm.snap_half(clampf(stars, 0.0, 5.0))
	if _star_tex.has(n):
		return _star_tex[n]
	var img := Image.create(int(star_bar_w()), STAR.size(), false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var fills := star_fills(n, float(STAR_PLACES))
	for i in fills.size():
		var x0 := int(star_x(i))
		var lit := _cols(float(fills[i].gold))
		for y in STAR.size():
			for x in int(STAR_SHAPE.w):
				if String(STAR[y])[x] == "#":
					img.set_pixel(x0 + x, y, STAR_EDGE if x < lit else STAR_PAST)
				if String(STAR_INNER[y])[x] == "#":
					img.set_pixel(x0 + x, y, PlayerForm.GOLD if x < lit else STAR_HOLLOW)
	var tex := ImageTexture.create_from_image(img)
	_star_tex[n] = tex
	return tex

## A bar's width in `shape`: `places` places (five, the longest a bar gets, by default).
static func star_bar_w(shape: Dictionary = STAR_SHAPE, places: int = STAR_PLACES) -> float:
	return maxf(0.0, (places - 1) * float(shape.step) + int(shape.w)) if places > 0 else 0.0

## A player's bar's width: as many places as star_count gives him.
static func star_bar_w_for(cur: float, pot: float, red: int = 0, shape: Dictionary = STAR_SHAPE) -> float:
	return star_bar_w(shape, star_count(cur, pot, red))

## Where place `i` of a bar starts, from the bar's left.
static func star_x(i: int, shape: Dictionary = STAR_SHAPE) -> float:
	return i * float(shape.step)

## `red`: the red stars his form shows (PlayerForm.red_stars). `gold`: the lit stars' fill (gold
## everywhere but the match HUD's holder tag, where a DEV recruit's are DEV_STAR blue).
static func star_bar(ci: CanvasItem, x: float, y: float, cur: float, pot: float, red: int = 0, empty: Color = Color(1, 1, 1, 0.14),
		shape: Dictionary = STAR_SHAPE, gold: Color = PlayerForm.GOLD) -> float:
	var fills := star_fills(cur, pot, red)
	# red stars burn the same everywhere (HotBadge, the roster card's fire)
	var state: String = PlayerForm.LEVELS[clampi(red, 0, 2)]
	var burn := red > 0 and shape == STAR_SHAPE
	if burn:
		_StarFlames.under(ci, Vector2(x, y), cur, pot, state)
	for i in fills.size():
		if gold != PlayerForm.GOLD:
			fills[i]["gold_col"] = gold
		star_place(ci, Vector2(x + star_x(i, shape), y), fills[i], empty, 0, 99, shape)
	if burn:
		_StarFlames.over(ci, Vector2(x, y), cur, pot, state)
	return star_bar_w(shape, fills.size())

const ATTR_FILL := Color("45dfff")   # an attribute bar's ticks: his rating...
const ATTR_EMPTY := Color("142a72")  # ...room under his ceiling...
const ATTR_POT := Color("1d4f9a")    # ...its lit edge...
const ATTR_DASH := Color("2a3f80")   # ...and the dash past his ceiling

## A ten-tick attribute bar (one tick a point): cyan up to the rating `v` (a part-filled tick as far
## as it reaches into it), open ticks with a lit edge up to his ceiling `pot` (what he can still
## grow into), dark ticks with a dash past it. `v` and `pot` are shares of 10. With `new_from` >= 0,
## what lies between it and `v` (an upgrade's new bit) is yellow. A `pot` below 0 is a ceiling nobody
## knows yet (the recruiting board before the third scout): every tick past the rating is a plain open
## tick, the same for everyone. The player page, the Attribute Test Lab and the recruiting board.
static func attr_bar(ci: CanvasItem, r: Rect2, v: float, pot: float, new_from: float = -1.0) -> void:
	r = Rect2(r.position.floor(), r.size.floor())
	ci.draw_rect(r, UI.INK)
	var n := 10
	var sw := floorf((r.size.x - 2.0 - (n - 1)) / n)
	for i in n:
		var cell := Rect2(r.position.x + 1 + i * (sw + 1), r.position.y + 1, sw, r.size.y - 2)
		var g := clampf(pot * n - i, 0.0, 1.0)   # how much of this tick is under his ceiling
		if pot < 0.0:
			ci.draw_rect(cell, ATTR_EMPTY)
		elif g > 0.0:
			ci.draw_rect(cell, ATTR_EMPTY)
			var gx := roundf(sw * g)
			if gx < sw:
				ci.draw_rect(Rect2(cell.position.x + gx, cell.position.y, sw - gx, cell.size.y), UI.INK)
			# the room still to grow: a lit rim along the top and bottom of the open tick
			ci.draw_rect(Rect2(cell.position, Vector2(maxf(1.0, gx), 1)), ATTR_POT)
			ci.draw_rect(Rect2(cell.position.x, cell.end.y - 1, maxf(1.0, gx), 1), ATTR_POT)
		else:
			# past his ceiling: a dash
			ci.draw_rect(Rect2(cell.position.x + 1, roundf(cell.position.y + cell.size.y * 0.5) - 1, maxf(1.0, sw - 2), 1), ATTR_DASH)
		var f := clampf(v * n - i, 0.0, 1.0)
		if f > 0.0:
			ci.draw_rect(Rect2(cell.position, Vector2(maxf(1.0, roundf(sw * f)), cell.size.y)), ATTR_FILL)
		if new_from >= 0.0 and f > 0.0:
			var f0 := clampf(new_from * n - i, 0.0, 1.0)
			if f > f0:
				var x0 := roundf(sw * f0)
				var x1 := maxf(x0 + 1.0, roundf(sw * f))
				ci.draw_rect(Rect2(cell.position.x + x0, cell.position.y, x1 - x0, cell.size.y), UI.GOLD)

## The ten-box attribute bar (the player page, read-only on the recruiting board): one box a
## point, every box in one of these states (box_state, the one rule every screen draws with):
##   "green"   YELLOW (named green from before): a point he owns for good (made with or upgraded, all the same)
##   "red"     INJURED (plain red): a point he owns that his injury takes off for now. Always the rightmost owned
##             boxes (MAX(0, attribute - penalty) of them stay green), worked out from his
##             attribute as it is now, so an upgrade moves them right and they never stick to a box
##   "buy"     FILLED CYAN: the next point, his to take now (he has an upgrade token, it's under his
##             ceiling): the only box that can be tapped, and only ever one a row
##   "hollow"  HOLLOW CYAN: a point still under his ceiling, for later
##   "grey"    GREY: past his ceiling, never his
##   "unknown" a ceiling nobody knows yet (`top` below 0: the recruiting board before the scouts)
## On top of them a Hot Star's FIRE (o.fire, fire_span): orange flames over half a box (HOT) or a
## whole one (VERY HOT) straight after his own, his in-game bonus.
## Attributes can be part-way through a box: the part he owns is drawn green (or red) from the
## left of it, and a box his ceiling only part reaches greys out past it, so the bar is always
## exactly his numbers. `o` (all optional): pen = his injury's penalty on this attribute, tokens =
## his upgrade tokens, hover (the buy box under the pointer), flash = the box just bought,
## flash_t = 0..1 through its flash, fire = his Hot Stars' bonus (burning boxes after his own:
## fire_span), t = seconds for the flames' flicker (held still under Reduce Motion).
const BOX_N := 10
const BOX_GAP := 2
const BOX_PERM := Color("ffd84a")      # YELLOW: owned (the state is still called "green")
const BOX_PERM_EDGE := Color("c08a14")
## INJURED: plain red. (The state is still called "red".)
const BOX_INJ := Color("e8213a")
const BOX_INJ_EDGE := Color("8c0f20")
## HOT FIRE: a Hot Star's attribute bonus (Attributes.hot_bonus: +0.5 HOT, +1.0 VERY HOT) drawn on
## the bar as burning boxes after his own: half a box HOT, a whole one VERY HOT.
const FIRE_EDGE := Color("b8240c")
const FIRE_BODY := Color("ff5a1f")
const FIRE_MID := Color("ff9a1f")
const FIRE_CORE := Color("ffe14a")
const FIRE_TIP := Color("fff6c8")
const FIRE_LOBE := 7      # px per flame tongue on a burning box
const FIRE_HZ := 2.5     # the flames step this many times a second: a calm, staticky crackle, never smooth
const BOX_FILL := Color("45dfff")      # FILLED CYAN: buy now
const BOX_FILL_EDGE := Color("1f9fc4")
const BOX_OPEN := Color("0b1d5c")      # HOLLOW CYAN: room under his ceiling (NAVY inside)...
const BOX_OPEN_EDGE := Color("45dfff") # ...a bright cyan outline
const BOX_OPEN_HOVER := Color("b4f4ff")
const BOX_GREY := Color("2b2f40")      # GREY: past his ceiling
const BOX_GREY_EDGE := Color("555b70")
const BOX_UNKNOWN := Color("0a1648")   # a ceiling not scouted yet
const BOX_UNKNOWN_EDGE := Color("2a3f80")
## The "+" on the buy box: a symmetric plus (both arms 2 px thick and the same even length,
## crossing at their exact middles) centred in `inner` on whole pixels. The box is a pixel
## wider than it is tall, so on an odd side the half pixel left over goes below/right.
static func buy_plus(ci: CanvasItem, inner: Rect2, col: Color) -> void:
	const T := 2
	var w := int(inner.size.x)
	var h := int(inner.size.y)
	var l := mini(w, h) - 4
	l -= l % 2                          # even, so the 2 px arms cross at its middle
	if l <= T:
		return
	var x0 := inner.position.x + floorf((w - l) / 2.0)
	var y0 := inner.position.y + floorf((h - l) / 2.0)
	var mid := (l - T) / 2.0
	ci.draw_rect(Rect2(x0, y0 + mid, l, T), col)
	ci.draw_rect(Rect2(x0 + mid, y0, T, l), col)

## Where box `i` of a ten-box bar in `r` sits (whole pixels; the boxes share the width).
static func box_rect(r: Rect2, i: int) -> Rect2:
	var bw := floorf((r.size.x - BOX_GAP * (BOX_N - 1)) / BOX_N)
	var x0 := r.position.x + floorf((r.size.x - (bw * BOX_N + BOX_GAP * (BOX_N - 1))) * 0.5)
	return Rect2(Vector2(x0 + i * (bw + BOX_GAP), r.position.y).floor(), Vector2(bw, r.size.y).floor())

## What box `i` (0-9) is for attribute `v`, ceiling `top`, injury penalty `pen` and `tokens`
## upgrade tokens: "green", "red", "buy", "hollow", "grey" or "unknown" (see attr_boxes). With P
## his attribute, C his ceiling, E = MAX(0, P - pen): past C grey; owned, green up to E and red
## after; the first box past P cyan to buy if he has a token; the rest hollow.
static func box_state(v: float, top: float, i: int, pen: float = 0.0, tokens: int = 0) -> String:
	if v - i >= 1.0 - Attributes.PRECISION:
		return "green" if maxf(0.0, v - pen) - i >= 1.0 - Attributes.PRECISION else "red"
	if top < 0.0:
		return "unknown"
	# open only while there's room left in it (a box he's part way through at his ceiling is grey)
	if top - maxf(v, float(i)) <= Attributes.PRECISION:
		return "grey"
	return "buy" if tokens > 0 and i == buy_box(v, top) else "hollow"

## All ten (box_state).
static func box_states(v: float, top: float, pen: float = 0.0, tokens: int = 0) -> Array:
	var out: Array = []
	for i in BOX_N:
		out.append(box_state(v, top, i, pen, tokens))
	return out

## The box the next upgrade fills: the first his attribute doesn't fill, if it's under his
## ceiling (-1 when he's at it). Cyan to buy only when he has a token (box_state).
static func buy_box(v: float, top: float) -> int:
	if top - v < Attributes.PRECISION:
		return -1
	return clampi(floori(v + Attributes.PRECISION), 0, BOX_N - 1)

static func attr_boxes(ci: CanvasItem, r: Rect2, v: float, top: float, o: Dictionary = {}) -> void:
	var pen := float(o.get("pen", 0.0))
	var tokens := int(o.get("tokens", 0))
	var e := maxf(0.0, v - pen)
	for i in BOX_N:
		var b := box_rect(r, i)
		var inner := b.grow(-1.0)
		var state := box_state(v, top, i, pen, tokens)
		match state:
			"green":
				ci.draw_rect(b, BOX_PERM_EDGE)
				ci.draw_rect(inner, BOX_PERM)
			"red":
				ci.draw_rect(b, BOX_INJ_EDGE)
				ci.draw_rect(inner, BOX_INJ)
			"buy":
				# a hollow box (cyan outline: still under his ceiling) with a yellow "+" (drawn
				# below); hovered, its outline lights yellow
				var lit := bool(o.get("hover", false))
				ci.draw_rect(b, BOX_PERM if lit else BOX_OPEN_EDGE)
				ci.draw_rect(inner, BOX_OPEN)
			"unknown":
				ci.draw_rect(b, BOX_UNKNOWN_EDGE)
				ci.draw_rect(inner, BOX_UNKNOWN)
			"grey":
				ci.draw_rect(b, BOX_GREY_EDGE)
				ci.draw_rect(inner, BOX_GREY)
			_:
				ci.draw_rect(b, BOX_OPEN_EDGE)
				ci.draw_rect(inner, BOX_OPEN)
				var g := clampf(top - i, 0.0, 1.0)   # how much of it is under his ceiling
				if g < 1.0:
					var gx := roundf(inner.size.x * g)
					ci.draw_rect(Rect2(inner.position.x + gx, inner.position.y, inner.size.x - gx, inner.size.y), BOX_GREY)
		# what he owns of it: green up to E, red from there to his attribute
		var own := clampf(v - i, 0.0, 1.0)
		if own > 0.0:
			var gw := clampf(e - i, 0.0, own)
			var x_g := roundf(inner.size.x * gw)
			var x_o := maxf(1.0, roundf(inner.size.x * own))
			if x_g > 0.0:
				ci.draw_rect(Rect2(inner.position, Vector2(x_g, inner.size.y)), BOX_PERM)
			if x_o > x_g:
				ci.draw_rect(Rect2(inner.position.x + x_g, inner.position.y, x_o - x_g, inner.size.y), BOX_INJ)
		if state in ["green", "red"]:
			ci.draw_rect(Rect2(inner.position, Vector2(inner.size.x, 1)), Color(1, 1, 1, 0.35))   # a lit top pixel row
		var burning := float(o.get("fire", 0.0)) > 0.0 and _fire_box(ci, b, i, v, float(o.fire), float(o.get("t", 0.0)))
		if state == "buy":
			# (the next upgrade's "+" stays on top of a Hot Star's fire, navy to read on the flames)
			buy_plus(ci, inner, BOX_OPEN if burning else BOX_PERM)
		if i == int(o.get("flash", -1)):
			var ft := float(o.get("flash_t", 1.0))
			if ft < 1.0:
				# bought: white, then gold, fading into the fill (two steps, pixel-style)
				ci.draw_rect(b, Color(1, 1, 1, 0.9) if ft < 0.35 else Color(UI.GOLD, 0.6 * (1.0 - ft)))

## Where a Hot Star's fire burns on a bar of attribute `v`: [from, to] in points, `fire` long,
## straight after his own boxes; where there's no room past them (at or near 10) it takes the
## bar's last `fire` points over his own, so the fire always shows whole.
static func fire_span(v: float, fire: float) -> Vector2:
	var f := clampf(fire, 0.0, float(BOX_N))
	var a := clampf(minf(v, BOX_N - f), 0.0, float(BOX_N))
	return Vector2(a, a + f)

## Box `i`'s share of the fire (fire_span): a burning red-orange edge, and one connected flame
## rising from the bottom: pointed orange tongues with a yellow core following their shape, pale
## points on the taller ones, which lick a pixel or two over the box's top. Stepped FIRE_HZ times a second; still under Reduce Motion.
## True when any of it burns in this box.
static func _fire_box(ci: CanvasItem, b: Rect2, i: int, v: float, fire: float, t: float) -> bool:
	var span := fire_span(v, fire)
	var f0 := clampf(span.x - i, 0.0, 1.0)
	var f1 := clampf(span.y - i, 0.0, 1.0)
	if f1 - f0 <= Attributes.PRECISION:
		return false
	var step := floorf(t * FIRE_HZ) if Juice.enabled() else 0.0
	var x0 := b.position.x + roundf(b.size.x * f0)
	var x1 := b.position.x + roundf(b.size.x * f1)
	var outer := Rect2(x0, b.position.y, x1 - x0, b.size.y)
	ci.draw_rect(outer, FIRE_EDGE)
	var inner := b.grow(-1.0).intersection(outer)
	if inner.size.x < 1.0:
		return true
	ci.draw_rect(inner, FIRE_BODY)
	var h := int(inner.size.y)
	var bottom := inner.end.y
	var base := h * 0.45                                  # the flame's body, all the way along
	var shift := int(step) % 2 * 3                         # tongues sway half a lobe each step
	for c in int(inner.size.x):
		var gx := int(inner.position.x) + c              # whole-bar column, so flames run on across boxes
		# one connected flame: pointed tongues FIRE_LOBE px wide, each its own height this step
		var lx := gx + shift
		var lobe := floori(float(lx) / FIRE_LOBE)
		var n := absi(hash(Vector3i(lobe, int(step), 7))) % 100
		var peak := h * (0.7 + 0.45 * n / 100.0)        # the tallest lick a pixel or two over the top
		var mid := (FIRE_LOBE - 1) * 0.5
		var d := absf(float(posmod(lx, FIRE_LOBE)) - mid) / (mid + 1.0)   # 0 at a tongue's point
		var flame := int(roundf(base + (peak - base) * (1.0 - d)))
		var core := int(roundf(base * 0.55 + (flame - base) * 0.45))
		var x := inner.position.x + c
		ci.draw_rect(Rect2(x, bottom - flame, 1, flame), FIRE_MID)
		ci.draw_rect(Rect2(x, bottom - core, 1, core), FIRE_CORE)
		if d < 0.25 and n > 40:
			ci.draw_rect(Rect2(x, bottom - flame, 1, 1), FIRE_TIP)   # a pale point on the taller tongues
	return true

## What each place shows: [{gold, form, form_col, pot}], each a fill from the left (0, 0.5 or
## 1): gold up to CURRENT, then exactly `red` whole red stars (his HOT level: one HOT, two VERY
## HOT) in the places straight after the gold; where the five places run out (a five-star going
## HOT) the bar grows past five, never covering a gold star (red_from). `pot` up to POTENTIAL. As many places as star_count (or
## `places`, when a caller needs two bars the same length: StarFx's transitions). The one rule
## every star bar uses.
static func star_fills(cur: float, pot: float, red: int = 0, places: int = -1) -> Array:
	var c := PlayerForm.snap_half(cur)
	var p := PlayerForm.snap_half(maxf(pot, cur))
	var n := clampi(red, 0, 2)
	var first := red_from(c, n)   # the first red place
	var gold := minf(c, float(first)) if n > 0 else c
	var out: Array = []
	for i in (places if places >= 0 else star_count(cur, pot, red)):
		var g := _fill(gold - i)
		var r := 1.0 if n > 0 and i >= first and i < first + n else 0.0
		out.append({"gold": g, "form": maxf(g, r), "form_col": PlayerForm.FIRE_RED if n > 0 else PlayerForm.GOLD,
			"pot": maxf(_fill(p - i), r)})
	return out

## How many places a player's bar has: up to his POTENTIAL (CURRENT when that's higher), a half
## star's place included, and room for his red stars after the gold; never more than five (plus
## the red stars that follow a half star: red_from), never fewer than one. No empty places just to make it five.
static func star_count(cur: float, pot: float, red: int = 0) -> int:
	var c := PlayerForm.snap_half(cur)
	var p := PlayerForm.snap_half(maxf(pot, cur))
	var n := clampi(red, 0, 2)
	var last := ceili(p)
	if n > 0:
		last = maxi(last, red_from(c, n) + n)
	return clampi(last, 1, STAR_PLACES + n)

## The place a bar's first red star goes in, for snapped CURRENT `c` and `n` red stars: always
## straight after the gold. Red never covers a gold star: where the five places run out the bar
## grows a place or two (a five-star HOT shows six stars, five gold then one red; a 3.5 VERY HOT:
## three gold, the half, then two red).
static func red_from(c: float, _n: int) -> int:
	return ceili(c)

static func _fill(v: float) -> float:
	return 1.0 if v >= 0.99 else (0.5 if v >= 0.49 else 0.0)

## One place: hollow (its outline fainter past POTENTIAL, half of it for half a star), then the form's red, then the gold over
## it, the outline dark round whatever is lit. Only the star's columns x_from..x_to-1 (a half star
## is columns 0-4).
static func star_place(ci: CanvasItem, at: Vector2, f: Dictionary, empty: Color = Color(1, 1, 1, 0.14), x_from: int = 0, x_to: int = 99,
		shape: Dictionary = STAR_SHAPE) -> void:
	var lit := _cols(maxf(float(f.form), float(f.gold)), shape)
	var open := maxi(lit, _cols(float(f.pot), shape))   # (half a star of POTENTIAL: half the outline open)
	pat_cols(ci, at, shape.star, {"#": STAR_EDGE}, x_from, mini(x_to, lit))
	pat_cols(ci, at, shape.star, {"#": STAR_OPEN}, maxi(x_from, lit), mini(x_to, open))
	pat_cols(ci, at, shape.star, {"#": STAR_PAST}, maxi(x_from, open), x_to)
	pat_cols(ci, at, shape.inner, {"#": STAR_HOLLOW}, x_from, x_to)
	if float(f.form) > float(f.gold):
		_layer(ci, at, float(f.form), f.form_col, x_from, x_to, shape)
	_layer(ci, at, float(f.gold), f.get("gold_col", PlayerForm.GOLD), x_from, x_to, shape)

## The columns a fill (0, 0.5 or 1) lights.
static func _cols(fill: float, shape: Dictionary = STAR_SHAPE) -> int:
	return shape.w if fill >= 0.99 else (shape.half if fill >= 0.49 else 0)

static func _layer(ci: CanvasItem, at: Vector2, fill: float, col: Color, x_from: int, x_to: int, shape: Dictionary = STAR_SHAPE) -> void:
	pat_cols(ci, at, shape.inner, {"#": col}, x_from, mini(x_to, _cols(fill, shape)))

## pat, columns x_from..x_to-1 only.
static func pat_cols(ci: CanvasItem, p: Vector2, rows: Array, cols: Dictionary, x_from: int, x_to: int) -> void:
	for y in rows.size():
		var row: String = rows[y]
		for x in range(maxi(x_from, 0), mini(x_to, row.length())):
			if cols.has(row[x]):
				ci.draw_rect(Rect2(p.x + x, p.y + y, 1, 1), cols[row[x]])

## The colour a place reads as: its form colour if form shows in it, else gold, else clear.
static func place_color(f: Dictionary) -> Color:
	if float(f.form) > float(f.gold):
		return f.form_col
	return PlayerForm.GOLD if float(f.gold) > 0.0 else Color(0, 0, 0, 0)

static func coin(ci: CanvasItem, p: Vector2, col: Color = UI.GOLD) -> void:
	pat(ci, p, COIN, {"#": col})
	ci.draw_rect(Rect2(p.x + 3, p.y + 3, 1, 2), col.darkened(0.35))

## Diagonal stripes, the card-header look: one tiled 8x8 texture (the canvas needs texture_repeat).
static func stripes(ci: CanvasItem, r: Rect2, base: Color, amt: float = 0.05) -> void:
	ci.draw_texture_rect(stripe_texture(base, amt), r, true)

static func stripe_texture(base: Color, amt: float = 0.05) -> Texture2D:
	var key := "stripe_%s_%.3f" % [base.to_html(), amt]
	if _tex.has(key):
		return _tex[key]
	var light := base.lightened(amt * 2.0)
	var img := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	for y in range(8):
		for x in range(8):
			img.set_pixel(x, y, light if (x + y) % 8 < 4 else base)
	var tex := ImageTexture.create_from_image(img)
	_tex[key] = tex
	return tex

static func trophy(ci: CanvasItem, p: Vector2, col: Color = UI.GOLD, s: float = 1.0) -> void:
	var dk := col.darkened(0.35)
	var lt := col.lightened(0.4)
	var R := func(x: float, y: float, w: float, h: float, c: Color):
		ci.draw_rect(Rect2(p.x + x * s, p.y + y * s, w * s, h * s), c)
	R.call(0, 0, 9, 1, dk)
	R.call(0, 1, 9, 3, col)
	R.call(1, 4, 7, 1, col)
	R.call(2, 5, 5, 1, col)
	R.call(3, 6, 3, 1, col)
	R.call(1, 1, 2, 3, lt)
	R.call(-2, 1, 2, 1, dk)
	R.call(-2, 2, 1, 2, dk)
	R.call(-1, 4, 2, 1, dk)
	R.call(9, 1, 2, 1, dk)
	R.call(10, 2, 1, 2, dk)
	R.call(8, 4, 2, 1, dk)
	R.call(4, 7, 1, 2, dk)
	R.call(2, 9, 5, 1, col)
	R.call(1, 10, 7, 2, dk)

# ------------------------------------------------------------------ textures
## dark = a brown coin that reads on a gold button.
static func coin_texture(dark: bool = false) -> Texture2D:
	return _pattern_texture("coin_dark" if dark else "coin", COIN, Color("7a4b00") if dark else UI.GOLD)

static func icon_texture(name: String, col: Color = Color.WHITE, scale: int = 1) -> Texture2D:
	return _pattern_texture("%s_%s_%d" % [name, col.to_html(), scale], ICONS[name], col, scale)

static func _pattern_texture(key: String, rows: Array, col: Color, scale: int = 1) -> Texture2D:
	if _tex.has(key):
		return _tex[key]
	var w := 0
	for r in rows:
		w = maxi(w, String(r).length())
	var img := Image.create(w * scale, rows.size() * scale, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in range(rows.size()):
		var row: String = rows[y]
		for x in range(row.length()):
			if row[x] == "#":
				img.fill_rect(Rect2i(x * scale, y * scale, scale, scale), col)
	if key.begins_with("coin"):
		img.set_pixel(3, 3, col.darkened(0.35))
		img.set_pixel(3, 4, col.darkened(0.35))
	var tex := ImageTexture.create_from_image(img)
	_tex[key] = tex
	return tex

# ------------------------------------------------------------------ widgets
static func label(t: String, size: int = 8, col: Color = UI.TEXT) -> Label:
	return UI.label(t, size, col, "caps")

## A chunky button with a caps label. Primary actions should be at least 27 px tall (44 pt).
static func button(t: String, cb: Callable, style: String = "normal", min_w: int = 0, min_h: int = 22) -> Button:
	var b := UI.button(t, cb, style, min_w, min_h)
	UI.style_button(b, style)
	b.add_theme_font_override("font", UI.font_caps)
	return b

## A chunky button showing a pixel icon (home, info, left, right, plus, x, gear, help): every back,
## forward and small directional button. The glyph sits on a hard 1 px shadow (down-right) so it
## reads on any fill; disabled, it's muted and shadowless (the button is pressed into the page).
static func icon_button(icon: String, cb: Callable, w: int = 30, h: int = 26, style: String = "normal", scale: int = 1) -> Button:
	var b := button("", cb, style, w, h)
	var ink := style in ["primary", "tab_on"]
	b.icon = icon_texture_shadowed(icon, Color.WHITE if not ink else UI.INK, scale, not ink)
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
	b.expand_icon = false
	# the icon's colour per state (the texture is the white glyph): pressed a touch dimmer, disabled muted
	b.add_theme_color_override("icon_normal_color", Color.WHITE)
	b.add_theme_color_override("icon_hover_color", Color.WHITE)
	b.add_theme_color_override("icon_pressed_color", Color(0.85, 0.89, 1.0))
	b.add_theme_color_override("icon_hover_pressed_color", Color(0.85, 0.89, 1.0))
	b.add_theme_color_override("icon_disabled_color", Color(UI.DIM2, 0.55))
	return b

## An icon with its hard pixel shadow baked in, 1 px right and 1 px down (the glyph's own size
## plus one), so arrows and icons have the same depth as the text on the buttons.
const ICON_SHADOW := Color(0.02, 0.06, 0.25, 0.75)

static func icon_texture_shadowed(name: String, col: Color = Color.WHITE, scale: int = 1, shadow: bool = true) -> Texture2D:
	if not shadow:
		return icon_texture(name, col, scale)
	var key := "sh_%s_%s_%d" % [name, col.to_html(), scale]
	if _tex.has(key):
		return _tex[key]
	var rows: Array = ICONS[name]
	var w := 0
	for r in rows:
		w = maxi(w, String(r).length())
	var img := Image.create(w * scale + 1, rows.size() * scale + 1, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for pass_i in 2:
		var off := 1 if pass_i == 0 else 0
		var c := ICON_SHADOW if pass_i == 0 else col
		for y in range(rows.size()):
			var row: String = rows[y]
			for x in range(row.length()):
				if row[x] == "#":
					img.fill_rect(Rect2i(x * scale + off, y * scale + off, scale, scale), c)
	var tex := ImageTexture.create_from_image(img)
	_tex[key] = tex
	return tex

## A button that shows an amount of coaching credits with the coin, like "290 (coin)": the
## official coin (CreditCoin), gold on any button, never shrunk to the text.
static func cost_button(amount: int, cb: Callable, min_w: int = 60, min_h: int = 22, style: String = "normal") -> Button:
	var b := button("", cb, style, min_w, maxi(min_h, CreditCoin.height(16) + 2))
	return CreditCoin.set_button(b, CreditCoin.tag(amount))

## A small tag pinned over a button's top-right corner ("NEW", a count).
static func badge(b: Control, t: String, col: Color = UI.PINK) -> Control:
	var w := int(text_w(t)) + 7
	var cv := UI.canvas(w, 11, func(ci):
		frame(ci, Rect2(0, 0, w, 11), col, UI.BORDER)
		text(ci, 4, 5.5, t, 8, UI.INK))
	cv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cv.anchor_left = 1.0
	cv.anchor_right = 1.0
	cv.offset_left = -w + 3
	cv.offset_right = 3
	cv.offset_top = -4
	cv.offset_bottom = 7
	b.add_child(cv)
	return cv

## Compact status marks. Their outlines and all pixels stay within the supplied square.
static func status_badge(ci: CanvasItem, at: Vector2, kind: String, size: int = 10) -> void:
	var fill := UI.GOLD if kind == "upgrade" else Color("f23b45")
	ci.draw_rect(Rect2(at, Vector2(size, size)), UI.INK)
	ci.draw_rect(Rect2(at + Vector2.ONE, Vector2(size - 2, size - 2)), fill)
	if kind == "upgrade":
		pat(ci, at + Vector2(2, 2), ["..#..", ".###.", "#####", "..#..", "..#..", "..#.."], {"#": UI.INK})
	else:
		pat(ci, at + Vector2(2, 2), ["..##..", "..##..", "######", "######", "..##..", "..##.."], {"#": UI.TEXT})

## A thin XP bar: a dark track, the gold fill from its left, no border.
static func xp_bar(ci: CanvasItem, r: Rect2, progress: float) -> void:
	r = Rect2(r.position.floor(), r.size.floor())
	ci.draw_rect(r, UI.INK)
	var pixels := roundi(r.size.x * clampf(progress, 0.0, 1.0))
	if pixels > 0:
		ci.draw_rect(Rect2(r.position, Vector2(pixels, r.size.y)), UI.GOLD)

## Badges occupy only the button's existing area and pass every input through to it.
static func nav_status_badges(b: Control, upgrade: bool, injury: bool) -> void:
	if not upgrade and not injury:
		return
	var cv := UI.canvas(22 if upgrade and injury else 10, 10, func(ci):
		var x := 0.0
		if upgrade:
			status_badge(ci, Vector2(x, 0), "upgrade")
			x += 12.0
		if injury:
			status_badge(ci, Vector2(x, 0), "injury"))
	cv.name = "RosterStatusBadges"
	cv.set_meta("upgrade", upgrade)
	cv.set_meta("injury", injury)
	cv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cv.anchor_left = 1.0
	cv.anchor_right = 1.0
	cv.offset_left = -cv.custom_minimum_size.x - 2.0
	cv.offset_right = -2.0
	cv.offset_top = 1.0
	cv.offset_bottom = 11.0
	b.add_child(cv)

## NEW RECRUITS AVAILABLE (Recruiting.after_game's free roll, until the Recruiting screen is
## seen): a small gold banner just above the nav button `b`, its notch pointing down at it, and a
## gold dot on the button's top-right corner. Neither moves nor resizes the button, and both pass
## every input through. `pop`: the banner's stepped pixel pop-in (once per roll; Reduce motion off).
const RECRUITS_NOTICE := "NEW RECRUITS AVAILABLE"
const NOTICE_SHADE := Color("d9a300")

static func nav_recruits_notice(b: Control, pop: bool = false) -> void:
	var tw := ceilf(text_w(RECRUITS_NOTICE)) + 8.0
	var bh := 11.0       # the banner, then its notch's 4 rows below
	var w := int(tw)
	var banner := UI.canvas(w, int(bh) + 4, func(ci):
		# a notched-corner box: INK edge, gold face, a darker gold bottom row
		ci.draw_rect(Rect2(1, 0, tw - 2, bh), UI.INK)
		ci.draw_rect(Rect2(0, 1, tw, bh - 2), UI.INK)
		ci.draw_rect(Rect2(1, 1, tw - 2, bh - 2), UI.GOLD)
		ci.draw_rect(Rect2(1, bh - 2, tw - 2, 1), NOTICE_SHADE)
		# the notch: opens through the bottom edge and narrows to one pixel
		# (notch_dx: how far nav_notices_apart slid the banner right, so the notch stays on the button)
		var cx := floorf(tw * 0.5) - float((ci as Control).get_meta("notch_dx", 0.0))
		for i in 5:
			var y := bh - 1.0 + i
			var half := 4 - i
			ci.draw_rect(Rect2(cx - half, y, half * 2 + 1, 1), UI.INK)
			if half >= 1:
				ci.draw_rect(Rect2(cx - half + 1, y, half * 2 - 1, 1), UI.GOLD)
		ctext(ci, Rect2(0, 0, tw, bh - 1), RECRUITS_NOTICE, 8, UI.INK))
	banner.name = "RecruitsNotice"
	banner.anchor_left = 0.5
	banner.anchor_right = 0.5
	banner.anchor_top = 0.0
	banner.anchor_bottom = 0.0
	banner.offset_left = -floorf(tw * 0.5)
	banner.offset_right = banner.offset_left + tw
	banner.offset_top = -(bh + 4.0) - 1.0
	banner.offset_bottom = -1.0
	banner.set_meta("base_left", banner.offset_left)
	banner.set_meta("width", tw)
	b.add_child(banner)
	var dot := UI.canvas(7, 7, func(ci):
		ci.draw_rect(Rect2(1, 0, 5, 7), UI.INK)
		ci.draw_rect(Rect2(0, 1, 7, 5), UI.INK)
		ci.draw_rect(Rect2(1, 1, 5, 5), UI.GOLD)
		ci.draw_rect(Rect2(2, 2, 1, 1), Color.WHITE)
		ci.draw_rect(Rect2(1, 5, 5, 1), NOTICE_SHADE))
	dot.name = "RecruitsDot"
	dot.anchor_left = 1.0
	dot.anchor_right = 1.0
	dot.offset_left = -9.0
	dot.offset_right = -2.0
	dot.offset_top = 2.0
	dot.offset_bottom = 9.0
	b.add_child(dot)
	if pop and Juice.enabled():
		# a stepped pop from the notch's tip: small, overshoot, settle (whole steps, pixel-art)
		banner.pivot_offset = Vector2(floorf(tw * 0.5), bh + 4.0)
		banner.scale = Vector2(0.4, 0.4)
		var t := banner.create_tween()
		for s in [0.7, 1.12, 1.0]:
			t.tween_interval(0.05)
			t.tween_callback(func(): banner.scale = Vector2(s, s))
		dot.visible = false
		t.tween_callback(func():
			dot.visible = true
			Juice.pop(dot, 0.4))

## INJURY ACTIVE: ADJUST PRACTICE? (someone on your roster is injured): a small red banner just
## above the nav button `b` (the hub's TRAINING), its notch pointing down at it, with a medical
## cross. It's the one notice that takes a tap: `cb` (the hub opens Training). Nothing else
## changes, and the button's size doesn't. nav_notices_apart keeps it clear of NEW RECRUITS
## AVAILABLE on the next button.
const INJURY_NOTICE := "INJURY ACTIVE: ADJUST PRACTICE?"
const INJURY_FACE := Color("5a0d14")
const INJURY_FACE_HI := Color("7a1420")
const INJURY_EDGE := Color("f23b45")

static func nav_injury_notice(b: Control, cb: Callable) -> Control:
	var icon_w := 9.0    # a white plate over the border rows, the cross 7 px
	var tw := ceilf(text_w(INJURY_NOTICE)) + icon_w + 9.0
	var bh := 11.0       # the banner, then its notch's 4 rows below
	var nb := card(Vector2(tw, bh + 4.0), func(ci: CanvasItem, _r: Rect2, mode: String):
		# a notched-corner box: INK edge, a bright red border, a dark red face
		ci.draw_rect(Rect2(1, 0, tw - 2, bh), UI.INK)
		ci.draw_rect(Rect2(0, 1, tw, bh - 2), UI.INK)
		ci.draw_rect(Rect2(1, 1, tw - 2, bh - 2), INJURY_EDGE)
		ci.draw_rect(Rect2(2, 2, tw - 4, bh - 4), INJURY_FACE_HI if mode != "normal" else INJURY_FACE)
		# the notch: opens through the bottom edge and narrows to one pixel
		# (notch_dx: how far nav_notices_apart slid the banner left, so the notch stays on the button)
		var cx := floorf(tw * 0.5) + float((ci as Control).get_parent().get_meta("notch_dx", 0.0))
		for i in 5:
			var y := bh - 1.0 + i
			var half := 4 - i
			ci.draw_rect(Rect2(cx - half, y, half * 2 + 1, 1), UI.INK)
			if half >= 1:
				ci.draw_rect(Rect2(cx - half + 1, y, half * 2 - 1, 1), INJURY_EDGE)
		# the medical cross: red on a small white plate
		var ix := 2.0
		ci.draw_rect(Rect2(ix + 1, 1, icon_w - 2, icon_w), UI.TEXT)
		ci.draw_rect(Rect2(ix, 2, icon_w, icon_w - 2), UI.TEXT)
		ci.draw_rect(Rect2(ix + 3, 2, 3, 7), INJURY_EDGE)
		ci.draw_rect(Rect2(ix + 1, 4, 7, 3), INJURY_EDGE)
		var tx := ix + icon_w + 2.0
		ctext(ci, Rect2(tx, 0, tw - tx - 2.0, bh - 1), INJURY_NOTICE, 8, UI.TEXT), cb)
	nb.name = "InjuryNotice"
	nb.tooltip_text = "Someone on your roster is injured: open Training to adjust practice"
	nb.anchor_left = 0.5
	nb.anchor_right = 0.5
	nb.anchor_top = 0.0
	nb.anchor_bottom = 0.0
	nb.offset_left = -floorf(tw * 0.5)
	nb.offset_right = nb.offset_left + tw
	nb.offset_top = -(bh + 4.0) - 1.0
	nb.offset_bottom = -1.0
	nb.set_meta("base_left", nb.offset_left)
	nb.set_meta("width", tw)
	b.add_child(nb)
	return nb

## Both notices up at once: the injury banner is wider than its button, so it slides left until
## it clears the recruits banner on the next button (2 px apart, never off the screen's left
## edge), its notch staying on its own button. If it can't slide far enough, the recruits banner
## slides right for the rest (never off the screen's right edge). Both stay on one row above the
## nav. Measured from the banners' laid-out homes, not their drawn rects, so the recruits
## banner's pop-in scale can't fool it. Safe to call again after a resize: it starts from both
## banners' home positions every time.
static func nav_notices_apart(injury: Control, recruits: Control) -> void:
	if not is_instance_valid(injury) or not is_instance_valid(recruits):
		return
	var btn := injury.get_parent() as Control
	var base_l: float = injury.get_meta("base_left")
	var tw: float = injury.get_meta("width")
	var home_x := btn.global_position.x + floorf(btn.size.x * 0.5) + base_l
	var rbtn := recruits.get_parent() as Control
	var r_base: float = recruits.get_meta("base_left")
	var rw: float = recruits.get_meta("width")
	var r_home := rbtn.global_position.x + floorf(rbtn.size.x * 0.5) + r_base
	var need := maxf(0.0, home_x + tw + 2.0 - r_home)
	var shift := minf(need, maxf(0.0, home_x - 2.0))
	shift = minf(shift, floorf(tw * 0.5) - 6.0)   # (the notch never leaves the banner)
	var view_w := injury.get_viewport_rect().size.x
	var r_shift := minf(need - shift, maxf(0.0, view_w - 2.0 - (r_home + rw)))
	r_shift = maxf(0.0, minf(r_shift, floorf(rw * 0.5) - 6.0))
	injury.offset_left = base_l - shift
	injury.offset_right = injury.offset_left + tw
	injury.set_meta("notch_dx", shift)
	injury.queue_redraw()
	recruits.offset_left = r_base + r_shift
	recruits.offset_right = recruits.offset_left + rw
	recruits.set_meta("notch_dx", r_shift)
	recruits.pivot_offset.x = floorf(rw * 0.5) - r_shift   # (the pop grows from the notch's tip)
	recruits.queue_redraw()

static func panel(t: String = "", fill: Color = Color(0, 0, 0, 0)) -> DeckPanel:
	return DeckPanel.new(t, fill)

static func mood_widget(v: float) -> Control:
	return UI.canvas(9, 9, func(ci): mood(ci, Vector2.ZERO, v))

## A tappable card that paints itself: paint(ci, rect, mode) where mode is "normal", "hover" or
## "down". It's a real Button, so TouchScroll can tell a tap from a drag.
static func card(min_size: Vector2, paint: Callable, cb: Callable) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = min_size
	for st in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		b.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	var cv := UI.canvas(0, 0, func(ci):
		var mode := "normal"
		match b.get_draw_mode():
			BaseButton.DRAW_PRESSED, BaseButton.DRAW_HOVER_PRESSED:
				mode = "down"
			BaseButton.DRAW_HOVER:
				mode = "hover"
		paint.call(ci, Rect2(Vector2.ZERO, ci.size), mode))
	cv.set_anchors_preset(Control.PRESET_FULL_RECT)
	cv.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED     # for Deck.stripes
	b.add_child(cv)
	# repaint whenever the button does (hover, press, and TouchScroll cancelling a press on a drag)
	b.draw.connect(cv.queue_redraw)
	b.pressed.connect(func():
		Sfx.play("click")
		cb.call())
	return b

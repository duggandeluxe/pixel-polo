class_name TeamLogo
extends RefCounted
## Universal pixel-art team logos. Every team gets one of five templates, drawn from its
## initials and its two colours on a fixed pixel grid, then scaled by whole numbers only:
##   block      one varsity letter, thick trim
##   interlock  two initials, the second tucked over the first
##   circle     one letter inside a ringed disc
##   shield     one letter inside a simple shield
##   angled     one varsity letter with a slight slant
## Colleges set `mark` and `logo` in Colleges.SCHOOLS; any other team (the quick-match clubs)
## gets a fixed template from its id, so a logo never changes between sessions.
## A school with drawn artwork (res://assets/logos/<id>_<box>.png, cut from the Road to Glory
## logo sheet by tools/logos/) shows that instead, one file per box size so it's never rescaled
## off the pixel grid; a school without (Stanford keeps its letter) falls back to the template.
## The list marks ("s", "m") are redrawn for their size: the logo's body and one ring of its trim.
## On a DETAIL MODE screen (Game.set_detail) a list mark is the same size but drawn finer: art pixels
## of FINE game pixels, two window pixels at the usual 3x, the pixel the rest of that mode's art uses.
## Matches never go there, so theirs stay as they are.
## Nothing here is saved: logos are rebuilt from the team's id, name and colours.

const STYLES := ["block", "interlock", "circle", "shield", "angled"]
const SMALL := 0     # list mark: one letter, 10 x 12, for schedules and standings
const MEDIUM := 1    # the full logo at 1x, 20 x 20, for team lists
const LARGE := 2     # the full logo at 2x, 40 x 40, for team cards and matchups
const GRID := 20
const OUTER := Color("06103a")
## Artwork boxes on disk, by file suffix: each file is its logo fitted inside that box.
## The list marks are wider than they're tall, so a wide logo ("LAS", "EH") keeps some height.
const ART_BOXES := {"s": Vector2i(20, 12), "m": Vector2i(28, 20), "40": Vector2i(40, 40), "48": Vector2i(48, 48), "60": Vector2i(60, 60)}
const ART_PATH := "res://assets/logos/%s_%s.png"
const FINE := 2.0 / 3.0                       # a fine art pixel, in game pixels
const FINE_TAGS := {"s": "fs", "m": "fm"}     # the same boxes in fine pixels: 30 x 18, 42 x 30
const FINE_UNDER := 40.0                      # a box narrower than this is a list mark

## 8 x 10 block capitals, two-pixel strokes.
const GLYPHS := {
	"A": ["..####..", ".######.", "###..###", "##....##", "##....##", "########", "########", "##....##", "##....##", "##....##"],
	"B": ["######..", "#######.", "##...###", "##....##", "#######.", "#######.", "##....##", "##...###", "#######.", "######.."],
	"C": ["..######", ".#######", "###.....", "##......", "##......", "##......", "##......", "###.....", ".#######", "..######"],
	"D": ["######..", "#######.", "##...###", "##....##", "##....##", "##....##", "##....##", "##...###", "#######.", "######.."],
	"E": ["########", "########", "##......", "##......", "######..", "######..", "##......", "##......", "########", "########"],
	"F": ["########", "########", "##......", "##......", "######..", "######..", "##......", "##......", "##......", "##......"],
	"G": ["..#####.", ".#######", "###...##", "##......", "##......", "##..####", "##..####", "###...##", ".#######", "..#####."],
	"H": ["##....##", "##....##", "##....##", "##....##", "########", "########", "##....##", "##....##", "##....##", "##....##"],
	"I": [".######.", ".######.", "...##...", "...##...", "...##...", "...##...", "...##...", "...##...", ".######.", ".######."],
	"J": ["...#####", "...#####", ".....##.", ".....##.", ".....##.", ".....##.", "##...##.", "###.###.", ".######.", "..####.."],
	"K": ["##...###", "##..###.", "##.###..", "#####...", "####....", "####....", "#####...", "##.###..", "##..###.", "##...###"],
	"L": ["##......", "##......", "##......", "##......", "##......", "##......", "##......", "##......", "########", "########"],
	"M": ["##....##", "###..###", "########", "########", "##.##.##", "##.##.##", "##....##", "##....##", "##....##", "##....##"],
	"N": ["##....##", "###...##", "####..##", "#####.##", "##.#####", "##..####", "##...###", "##....##", "##....##", "##....##"],
	"O": ["..####..", ".######.", "###..###", "##....##", "##....##", "##....##", "##....##", "###..###", ".######.", "..####.."],
	"P": ["#######.", "########", "##....##", "##....##", "########", "#######.", "##......", "##......", "##......", "##......"],
	"Q": ["..####..", ".######.", "###..###", "##....##", "##....##", "##....##", "##..#.##", "###..##.", ".######.", "..###.##"],
	"R": ["#######.", "########", "##....##", "##....##", "########", "#######.", "##..###.", "##...###", "##....##", "##....##"],
	"S": [".######.", "########", "##......", "##......", "#######.", ".#######", "......##", "......##", "########", ".######."],
	"T": ["########", "########", "...##...", "...##...", "...##...", "...##...", "...##...", "...##...", "...##...", "...##..."],
	"U": ["##....##", "##....##", "##....##", "##....##", "##....##", "##....##", "##....##", "###..###", ".######.", "..####.."],
	"V": ["##....##", "##....##", "##....##", "##....##", "##....##", "###..###", ".##..##.", ".######.", "..####..", "...##..."],
	"W": ["##....##", "##....##", "##....##", "##....##", "##.##.##", "##.##.##", "########", "########", "###..###", "##....##"],
	"X": ["##....##", "###..###", ".######.", "..####..", "...##...", "...##...", "..####..", ".######.", "###..###", "##....##"],
	"Y": ["##....##", "##....##", "###..###", ".######.", "..####..", "...##...", "...##...", "...##...", "...##...", "...##..."],
	"Z": ["########", "########", ".....###", "....###.", "...###..", "..###...", ".###....", "###.....", "########", "########"],
}
## Shield row widths, top to bottom, centred on the grid.
const SHIELD_ROWS := [18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 16, 14, 12, 10, 8, 6, 4, 2]
## Words that don't give a fallback initial.
const SKIP_WORDS := ["UNIVERSITY", "COLLEGE", "STATE", "TECH", "OF", "THE"]

static var _cache := {}

# ------------------------------------------------------------------ what a team's logo is
## {mark, style, fill, trim} for a PoloTeam or a Colleges school dictionary.
static func spec(t: Variant) -> Dictionary:
	var id := ""
	var name := ""
	var c1 := Color.WHITE
	var c2 := Color.BLACK
	if t is PoloTeam:
		id = t.id
		name = t.name
		c1 = t.c1
		c2 = t.c2
	elif t is Dictionary:
		id = String(t.get("short", t.get("id", "")))
		name = String(t.get("name", ""))
		c1 = Color(String(t.get("c1", "ffffff")))
		c2 = Color(String(t.get("c2", "000000")))
	var school := Colleges.school(id)
	var mark := String(school.get("mark", ""))
	var style := String(school.get("logo", ""))
	if school.is_empty() or String(school.name) != name:
		mark = ""
		style = ""
	if mark == "" or not style in STYLES:
		var d := _derive(id, name)
		mark = d[0]
		style = d[1]
	return {"mark": mark, "style": style, "fill": c1, "trim": trim_for(c1, c2)}

## The secondary colour, unless it's near-black (lost on the navy menus) or wouldn't read
## against the primary: then white (or ink on a light primary).
static func trim_for(c1: Color, c2: Color) -> Color:
	if c2.get_luminance() >= 0.12 and absf(c1.get_luminance() - c2.get_luminance()) >= 0.2:
		return c2
	return Color.WHITE if c1.get_luminance() < 0.55 else OUTER

## Initials and a template for a team with no entry in Colleges, fixed by its id and name.
static func _derive(id: String, name: String) -> Array:
	var initials := ""
	for w in name.to_upper().split(" ", false):
		if w in SKIP_WORDS or not GLYPHS.has(w[0]):
			continue
		initials += w[0]
	if initials == "":
		initials = id.substr(0, 1).to_upper() if id != "" else "X"
	var h := 0
	for ch in (id + name):
		h = (h * 31 + ch.unicode_at(0)) % 100003
	var style: String = STYLES[h % STYLES.size()]
	if style == "interlock" and initials.length() < 2:
		style = "block"
	return [initials.substr(0, 2) if style == "interlock" else initials.substr(0, 1), style]

# ------------------------------------------------------------------ widgets
## The box a logo fills: SMALL 20 x 12, MEDIUM 28 x 20, LARGE 40 square; scale overrides
## LARGE's 2x (whole numbers, 20 px a step).
static func box(size: int = MEDIUM, scale: int = 0) -> Vector2i:
	if size == SMALL:
		return ART_BOXES["s"]
	if size == MEDIUM and scale <= 1:
		return ART_BOXES["m"]
	var k := scale if scale > 0 else 2
	return Vector2i(GRID * k, GRID * k)

## A logo widget, box(size, scale) big.
static func widget(t: Variant, size: int = MEDIUM, scale: int = 0) -> Control:
	var b := box(size, scale)
	var c := UI.canvas(b.x, b.y, func(ci):
		draw_in(ci, Rect2(((ci.size - Vector2(b)) * 0.5).floor(), Vector2(b)), t))
	c.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return c

## Draws a logo straight onto a canvas, its box's top-left at p.
## `dense` false: the canvas is already scaled to FINE (the bracket, the postgame board), so a plain
## file is in fine pixels as it is.
static func paint(ci: CanvasItem, p: Vector2, t: Variant, size: int = MEDIUM, scale: int = 0, dense: bool = true) -> void:
	draw_in(ci, Rect2(p.floor(), Vector2(box(size, scale))), t, dense)

## Draws a logo centred in r, never off its pixel grid: the artwork file for the biggest box that
## fits r, or the template at the biggest whole-number scale that fits.
static func draw_in(ci: CanvasItem, r: Rect2, t: Variant, dense: bool = true) -> void:
	var fine := dense and minf(r.size.x, r.size.y) < FINE_UNDER and detail_on(ci)
	var tex := art(t, Vector2i(r.size), fine)
	var k := FINE if fine else 1.0
	if tex == null:
		tex = texture(t, r.size.y < GRID, fine)
		if not fine:
			k = maxi(1, mini(int(r.size.x) / tex.get_width(), int(r.size.y) / tex.get_height()))
	var dim := Vector2(tex.get_width(), tex.get_height()) * k
	ci.draw_texture_rect(tex, Rect2((r.position + (r.size - dim) * 0.5).floor(), dim), false)

## This canvas is in a detail mode window.
static func detail_on(ci: CanvasItem) -> bool:
	var win := ci.get_window()
	return win != null and win.content_scale_mode == Window.CONTENT_SCALE_MODE_CANVAS_ITEMS

## A school's drawn logo for the biggest artwork box inside `fit`, or null (no artwork: the
## quick-match clubs, Stanford, a renamed team).
static func art(t: Variant, fit: Vector2i, fine: bool = false) -> Texture2D:
	var id := ""
	var name := ""
	if t is PoloTeam:
		id = t.id
		name = t.name
	elif t is Dictionary:
		id = String(t.get("short", t.get("id", "")))
		name = String(t.get("name", ""))
	var school := Colleges.school(id)
	if school.is_empty() or String(school.name) != name:
		return null
	var best := ""
	for tag in ART_BOXES:
		var b: Vector2i = ART_BOXES[tag]
		if b.x <= fit.x and b.y <= fit.y and (best == "" or b.x * b.y > ART_BOXES[best].x * ART_BOXES[best].y):
			best = tag
	if best == "":
		best = "s"
	var path := ART_PATH % [id, FINE_TAGS.get(best, best) if fine else best]
	if not _cache.has(path):
		_cache[path] = load(path) if ResourceLoader.exists(path) else null
	return _cache[path]

## The biggest of a school's artwork files whose own pixels fit `fit` (a wide logo's 60 px file
## is short enough for a square 40 px space), drawn 1:1; null for a school with no artwork.
static func art_within(t: Variant, fit: Vector2i) -> Texture2D:
	for tag in ["60", "48", "40"]:
		var tex := art(t, ART_BOXES[tag])
		if tex == null:
			return null
		if tex.get_width() <= fit.x and tex.get_height() <= fit.y:
			return tex
	return art(t, ART_BOXES["40"])

## The template logo as a texture at 1x (cached).
static func texture(t: Variant, small: bool = false, fine: bool = false) -> Texture2D:
	var s := spec(t)
	var key := "%s|%s|%s|%s|%s|%s" % [s.mark, s.style, s.fill.to_html(), s.trim.to_html(), small, fine]
	if not _cache.has(key):
		var img: Image = _mini_fine(s) if small and fine else (_mini(s) if small else _full(s))
		if fine and not small:
			img.resize(GRID * 3 / 2, GRID * 3 / 2, Image.INTERPOLATE_NEAREST)
		_cache[key] = ImageTexture.create_from_image(img)
	return _cache[key]

# ------------------------------------------------------------------ drawing on the grid
static func _full(s: Dictionary) -> Image:
	var img := Image.create(GRID, GRID, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var mark: String = s.mark
	var fill: Color = s.fill
	var trim: Color = s.trim
	match s.style:
		"block":
			_letter(img, _glyph(mark[0], 6, 5), fill, trim, 2)
		"angled":
			_letter(img, _glyph(mark[0], 4, 5, true), fill, trim, 2)
		"interlock":
			# two staggered initials joined by one outline: both rings go down before either
			# letter, so neither letter loses a stroke
			var a := _glyph(mark[0], 2, 3)
			var b := _glyph(mark[mark.length() - 1], 10, 6)
			var ra := _dilate(a, 1)
			var rb := _dilate(b, 1)
			_paint(img, _dilate(ra, 1), OUTER)
			_paint(img, _dilate(rb, 1), OUTER)
			_paint(img, ra, trim)
			_paint(img, rb, trim)
			_paint(img, a, fill)
			_paint(img, b, fill)
		"circle":
			trim = _accent(fill, trim)
			for y in GRID:
				for x in GRID:
					var d := Vector2(x + 0.5 - 10.0, y + 0.5 - 10.0).length()
					if d <= 10.0:
						img.set_pixel(x, y, OUTER if d > 9.0 else (trim if d > 7.4 else fill))
			_letter(img, _glyph(mark[0], 6, 5), trim, OUTER, 1, false)
		"shield":
			trim = _accent(fill, trim)
			var shape := {}
			for y in SHIELD_ROWS.size():
				var w: int = SHIELD_ROWS[y]
				for x in range(10 - w / 2, 10 + w / 2):
					shape[Vector2i(x, y)] = true
			var ring := _erode(shape, 1)
			var field := _erode(ring, 2)
			_paint(img, shape, OUTER)
			_paint(img, ring, trim)
			_paint(img, field, fill)
			_letter(img, _glyph(mark[0], 6, 3), trim, OUTER, 1, false)
	return img

## An emblem's ring and letter colour: the trim, unless it's too dark to show inside the ink
## outline, then white (or ink on a light field).
static func _accent(fill: Color, trim: Color) -> Color:
	if trim.get_luminance() >= 0.3:
		return trim
	return Color.WHITE if fill.get_luminance() < 0.6 else OUTER

## The small list mark: the first initial with a 1 px trim, 10 x 12.
static func _mini(s: Dictionary) -> Image:
	var img := Image.create(10, 12, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var mark: String = s.mark
	var fill: Color = s.fill
	var trim: Color = s.trim
	var pts := _glyph(mark[0], 1, 1)
	_paint(img, _dilate(pts, 1), trim)
	_paint(img, pts, fill)
	return img

## _mini in fine pixels: the same box on screen. Its two-pixel strokes become three, its ring stays one.
static func _mini_fine(s: Dictionary) -> Image:
	var img := Image.create(15, 18, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var mark: String = s.mark
	var pts := {}
	for p: Vector2i in _glyph(mark[0], 0, 0):
		for y in range(p.y * 3 / 2, (p.y + 1) * 3 / 2):
			for x in range(p.x * 3 / 2, (p.x + 1) * 3 / 2):
				pts[Vector2i(x + 1, y + 1)] = true
	_paint(img, _dilate(pts, 1), s.trim)
	_paint(img, pts, s.fill)
	return img

## A letter's pixels at (ox, oy); `slant` leans it right, one pixel every three rows.
static func _glyph(ch: String, ox: int, oy: int, slant: bool = false) -> Dictionary:
	var rows: Array = GLYPHS.get(ch.to_upper(), GLYPHS["X"])
	var pts := {}
	for y in rows.size():
		var row: String = rows[y]
		var sx := (rows.size() - 1 - y) / 3 if slant else 0
		for x in row.length():
			if row[x] == "#":
				pts[Vector2i(ox + x + sx, oy + y)] = true
	return pts

## A letter in fill, ringed by `trim_w` pixels of trim and (optionally) one of ink outside that.
## Rings wider than a pixel round their corners so the letter keeps its shape.
static func _letter(img: Image, pts: Dictionary, fill: Color, trim: Color, trim_w: int, outer: bool = true) -> void:
	var ring := _dilate(pts, trim_w)
	if outer:
		_paint(img, _dilate(ring, 1), OUTER)
	_paint(img, ring, trim)
	_paint(img, pts, fill)

## Grows a pixel set by r: the first pixel takes the corners too, any more only the sides.
static func _dilate(pts: Dictionary, r: int) -> Dictionary:
	var out := pts.duplicate()
	for i in r:
		var grown := {}
		for p in out:
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					if i == 0 or dx == 0 or dy == 0:
						grown[p + Vector2i(dx, dy)] = true
		out = grown
	return out

static func _erode(pts: Dictionary, r: int) -> Dictionary:
	var out := {}
	for p in pts:
		var keep := true
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if not pts.has(p + Vector2i(dx, dy)):
					keep = false
		if keep:
			out[p] = true
	return out

static func _paint(img: Image, pts: Dictionary, col: Color) -> void:
	for p in pts:
		if p.x >= 0 and p.y >= 0 and p.x < img.get_width() and p.y < img.get_height():
			img.set_pixel(p.x, p.y, col)

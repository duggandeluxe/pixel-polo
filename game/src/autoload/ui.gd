extends Node
## Palette, fonts, theme and small drawing/widget helpers.

# "Deck Blue", Retro Swim's menu look: a pool-blue page, panels a step deeper, white borders.
# The match keeps its own dark scoreboard colours (Hud.CARD, Hud.LINE, Hud.DIM).
const BG := Color("2a68f5")
const BG2 := Color("1f52c9")
const BG_HI := Color("3b7bff")
const PANEL := Color("1d4ab8")
const PANEL2 := Color("163d9e")
const BORDER := Color("ffffff")
const BORDER_HI := Color("c3d4ff")
const TEXT := Color("ffffff")
const DIM := Color("c3d4ff")
const DIM2 := Color("a7bcf0")
const GOLD := Color("ffd23f")
const SILVER := Color("d3dbe6")
const BRONZE := Color("d08a4b")
const GOOD := Color("7fe35f")
const BAD := Color("ff7a7a")
const WARN := Color("ffb13b")
const ACCENT := Color("5cc8ff")
const PINK := Color("ff8cc0")
const INK := Color("06103a")         # bar wells, text on gold
const SHADOW := Color("123287")      # chunky buttons' drop shadow
const PLATE := Color("4b5068")       # name plates on cards
const PLATE_D := Color("323650")

const WATER_DEEP := Color("075ddc")
const WATER := Color("0869f5")
const WATER_LIGHT := Color("1688ff")
const WATER_SHINE := Color("8fd0f5")
const LANE_RED := Color("ff4545")
const LANE_WHITE := Color("ffffff")
const LANE_BLUE := Color("2156a8")
const LANE_YELLOW := Color("ffd83d")
const DECK := Color("e5e0d1")
const DECK_DARK := Color("c9c2ae")
const TILE_LINE := Color("0751bd")

var font_body: FontFile
var font_big: FontFile
var font_caps: FontFile
var font_system: FontVariation   # the fallback for the scripts the pixel fonts don't have
var theme: Theme

func _ready() -> void:
	font_body = _load_font("res://assets/fonts/Tiny5-Regular.ttf")
	font_big = _load_font("res://assets/fonts/Jersey10-Regular.ttf")
	font_caps = _load_font("res://assets/fonts/Silkscreen-Regular.ttf")
	# other languages' letters: Tiny5 has Latin Extended, Greek and Cyrillic, which Silkscreen
	# (caps) and Jersey 10 (big) mostly lack; every other script (Arabic, CJK, Indic, Thai...)
	# comes from the system's fonts, smoothed (they aren't pixel fonts) and with their tall line
	# boxes trimmed so a row is about as tall as in English (Loc.hires draws those languages at
	# the display's resolution)
	var sys := SystemFont.new()
	sys.font_names = PackedStringArray(["sans-serif"])
	sys.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	sys.hinting = TextServer.HINTING_LIGHT
	sys.allow_system_fallback = true
	font_system = FontVariation.new()
	font_system.base_font = sys
	font_system.spacing_top = -2
	font_system.spacing_bottom = -2
	font_body.fallbacks = [font_system]
	font_caps.fallbacks = [font_body, font_system]
	font_big.fallbacks = [font_body, font_system]
	theme = _build_theme()

func _load_font(path: String) -> FontFile:
	var f: FontFile
	if ResourceLoader.exists(path):
		f = (load(path) as FontFile).duplicate()
	else:
		f = FontFile.new()
		f.load_dynamic_font(path)
	f.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	f.hinting = TextServer.HINTING_NONE
	f.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	f.generate_mipmaps = false
	return f

func sb(bg: Color, border: Color = Color.TRANSPARENT, bw: int = 1, margin_h: int = 4, margin_v: int = 2) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw if border.a > 0.0 else 0)
	s.anti_aliasing = false
	s.content_margin_left = margin_h
	s.content_margin_right = margin_h
	s.content_margin_top = margin_v
	s.content_margin_bottom = margin_v
	return s

## A chunky pixel box as a 9-patch: a 1 px border with cut corners and, for buttons, a drop shadow
## 1 px right and 2 px down. pressed = the box sits where its shadow was (it "goes down").
## The shadow and the pressed offset draw outside the control (expand margins), so layouts don't move.
## THE BEVEL (the one depth rule, every button and panel): a 1 px ring just inside the border.
##   BEVEL_RAISED  lit top and left, shaded bottom and right: a button standing up off the page
##   BEVEL_SUNK    shaded top and left: pressed in (a pressed button, a disabled one)
##   BEVEL_SOFT    a faint lit top and a faint shaded bottom: a panel, a card
##   BEVEL_DOUBLE  the border twice (2 px): a SELECTED card or choice
##   BEVEL_NONE    flat (the old look; translucent fills are always flat)
## BEVEL_AUTO picks: raised with a shadow (a button), sunk when pressed, otherwise soft (a panel).
const BEVEL_AUTO := -9
const BEVEL_NONE := 0
const BEVEL_RAISED := 1
const BEVEL_SUNK := -1
const BEVEL_SOFT := 2
const BEVEL_DOUBLE := 3
var _chunky_cache := {}

func chunky(fill: Color, border: Color = BORDER, shadow: bool = true, pressed: bool = false, pad_h: int = 6, pad_v: int = 3, bevel: int = BEVEL_AUTO) -> StyleBoxTexture:
	if bevel == BEVEL_AUTO:
		bevel = BEVEL_SUNK if pressed else (BEVEL_RAISED if shadow else BEVEL_SOFT)
	if fill.a < 0.99 and bevel != BEVEL_DOUBLE:
		bevel = BEVEL_NONE
	var key := "%s|%s|%s|%s|%d|%d|%d" % [fill.to_html(), border.to_html(), shadow, pressed, pad_h, pad_v, bevel]
	if _chunky_cache.has(key):
		return _chunky_cache[key]
	var big := shadow or pressed
	var iw := 7 if big else 6
	var ih := 8 if big else 6
	var fx := 1 if pressed else 0
	var fy := 2 if pressed else 0
	var img := Image.create(iw, ih, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	if shadow and not pressed:
		_frame_px(img, 1, 2, SHADOW, SHADOW)
	_frame_px(img, fx, fy, fill, border)
	_bevel_px(img, fx, fy, fill, bevel, border)
	var s := StyleBoxTexture.new()
	s.texture = ImageTexture.create_from_image(img)
	# corners and edges are the frame; the middle is pure fill and stretches. With a shadow the top
	# band is 3 rows, so the shadow's cut corner (6, 2) isn't stretched down the right edge.
	s.texture_margin_left = fx + 2
	s.texture_margin_top = fy + (3 if shadow and not pressed else 2)
	s.texture_margin_right = iw - (fx + 4)
	s.texture_margin_bottom = ih - (fy + 4)
	if big:
		s.expand_margin_right = 1
		s.expand_margin_bottom = 2
	# the label rides down with the box when pressed; the totals stay equal so nothing re-lays out
	s.content_margin_left = pad_h + fx
	s.content_margin_right = pad_h - fx
	s.content_margin_top = pad_v + fy
	s.content_margin_bottom = pad_v - fy
	_chunky_cache[key] = s
	return s

func _frame_px(img: Image, x: int, y: int, fill: Color, border: Color) -> void:
	for yy in range(6):
		for xx in range(6):
			var edge := xx == 0 or yy == 0 or xx == 5 or yy == 5
			var corner := (xx == 0 or xx == 5) and (yy == 0 or yy == 5)
			if corner:
				continue
			img.set_pixel(x + xx, y + yy, border if edge else fill)

## The bevel ring inside a 6x6 frame at (x, y): row 1 / column 1 the top and left, row 4 / column 4
## the bottom and right. The 9-patch stretches the middle, so the ring runs the box's whole edge.
func _bevel_px(img: Image, x: int, y: int, fill: Color, bevel: int, border: Color = BORDER) -> void:
	if bevel == BEVEL_NONE:
		return
	if bevel == BEVEL_DOUBLE:
		for i in range(1, 5):
			for p in [Vector2i(1, i), Vector2i(4, i), Vector2i(i, 1), Vector2i(i, 4)]:
				img.set_pixel(x + p.x, y + p.y, border)
		return
	var soft := bevel == BEVEL_SOFT
	var lit := bevel_light(fill, soft)
	var dark := bevel_dark(fill, soft)
	if soft:
		# a panel: one lit line along the top, one shaded along the bottom, short of the corners
		for i in range(2, 4):
			img.set_pixel(x + i, y + 1, lit)
			img.set_pixel(x + i, y + 4, dark)
		return
	var top := dark if bevel == BEVEL_SUNK else lit       # top and left
	var bottom := fill if bevel == BEVEL_SUNK else dark   # bottom and right
	for i in range(1, 4):
		img.set_pixel(x + 1, y + i, top)
		img.set_pixel(x + i, y + 1, top)
	for i in range(2, 5):
		img.set_pixel(x + 4, y + i, bottom)
		img.set_pixel(x + i, y + 4, bottom)

## A fill's lit and shaded bevel colours: the same hue, brighter and a touch paler / deeper.
## soft = the panel strength.
func bevel_light(fill: Color, soft: bool = false) -> Color:
	var t := 0.45 if soft else 1.0
	var c := Color.from_hsv(fill.h, fill.s * lerpf(1.0, 0.72, t), minf(1.0, fill.v + 0.13 * t + (0.06 if soft else 0.0)))
	return c

func bevel_dark(fill: Color, soft: bool = false) -> Color:
	return Color.from_hsv(fill.h, minf(1.0, fill.s * 1.05), fill.v * (0.84 if soft else 0.76))

## Button colours per style: [fill, hover fill, pressed fill, border, font colour]
## The kinds: normal (blue), primary (gold), good (green), danger (red), ghost (the quiet secondary
## blue), tab / tab_on (a tab row: tab_on is the selected one).
const BUTTON_STYLES := {
	"normal": ["2a68f5", "3b7bff", "1f52c9", "ffffff", "ffffff"],
	"primary": ["ffd23f", "ffe27a", "e0b52a", "ffffff", "06103a"],
	"good": ["23913a", "2aa846", "1c7a30", "ffffff", "ffffff"],
	"danger": ["c0322f", "d63f3c", "a12826", "ffffff", "ffffff"],
	"ghost": ["1f52c9", "2a5fd9", "1a47b0", "a9c1ff", "ffffff"],
	"tab": ["1f52c9", "2a5fd9", "1a47b0", "a9c1ff", "c3d4ff"],
	"tab_on": ["ffd23f", "ffd23f", "e0b52a", "ffffff", "06103a"],
}
## A disabled button: muted and pressed into the page (no shadow, a sunk bevel), never lit on hover.
const DISABLED_FILL := Color("34509f")
const DISABLED_EDGE := Color("7d93c9")

## A hovered edge: a step brighter (a white one is already as bright as it goes).
func hover_edge(border: Color) -> Color:
	return border if border.v >= 0.99 and border.s < 0.05 else border.lightened(0.4)

func style_button(b: Button, style: String) -> void:
	var st: Array = BUTTON_STYLES.get(style, BUTTON_STYLES.normal)
	var border := Color(st[3])
	b.add_theme_stylebox_override("normal", chunky(Color(st[0]), border))
	b.add_theme_stylebox_override("hover", chunky(Color(st[1]), hover_edge(border)))
	b.add_theme_stylebox_override("pressed", chunky(Color(st[2]), border, false, true))
	b.add_theme_stylebox_override("hover_pressed", chunky(Color(st[2]), border, false, true))
	b.add_theme_stylebox_override("disabled", chunky(DISABLED_FILL, DISABLED_EDGE, false, false, 6, 3, BEVEL_SUNK))
	var fc := Color(st[4])
	b.add_theme_color_override("font_color", fc)
	b.add_theme_color_override("font_hover_color", fc)
	b.add_theme_color_override("font_pressed_color", fc)
	b.add_theme_color_override("font_hover_pressed_color", fc)
	b.add_theme_color_override("font_disabled_color", DIM2)

func _build_theme() -> Theme:
	var t := Theme.new()
	t.default_font = font_body
	t.default_font_size = 8
	t.set_color("font_color", "Label", TEXT)
	t.set_constant("line_spacing", "Label", 1)
	# buttons: chunky white-bordered boxes with a drop shadow
	var bs: Array = BUTTON_STYLES.normal
	t.set_stylebox("normal", "Button", chunky(Color(bs[0]), BORDER))
	t.set_stylebox("hover", "Button", chunky(Color(bs[1]), BORDER))
	t.set_stylebox("pressed", "Button", chunky(Color(bs[2]), BORDER, false, true))
	t.set_stylebox("hover_pressed", "Button", chunky(Color(bs[2]), BORDER, false, true))
	t.set_stylebox("disabled", "Button", chunky(DISABLED_FILL, DISABLED_EDGE, false, false, 6, 3, BEVEL_SUNK))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", GOLD)
	t.set_color("font_disabled_color", "Button", DIM2)
	t.set_font_size("font_size", "Button", 8)
	# panels
	t.set_stylebox("panel", "PanelContainer", chunky(PANEL, BORDER, false, false, 4, 3, BEVEL_SOFT))
	t.set_stylebox("panel", "Panel", chunky(PANEL, BORDER, false, false, 0, 0, BEVEL_SOFT))
	# line edit (a text field is a well: pressed into the panel)
	var le := chunky(Color("0b1f66"), BORDER_HI, false, false, 4, 3, BEVEL_SUNK)
	t.set_stylebox("normal", "LineEdit", le)
	t.set_stylebox("focus", "LineEdit", chunky(Color("0b1f66"), GOLD, false, false, 4, 3, BEVEL_SUNK))
	t.set_color("font_color", "LineEdit", TEXT)
	t.set_color("caret_color", "LineEdit", GOLD)
	t.set_font_size("font_size", "LineEdit", 8)
	# scroll bars (thin): a dark well, a light grabber that turns gold while it's held
	var grab := sb(Color(1, 1, 1, 0.75), Color.TRANSPARENT, 0, 1, 1)
	var grab_hi := sb(Color(1, 1, 1, 0.92), Color.TRANSPARENT, 0, 1, 1)
	var track := sb(Color(0, 0, 0, 0.25), Color.TRANSPARENT, 0, 1, 1)
	for bar_kind in ["VScrollBar", "HScrollBar"]:
		t.set_stylebox("scroll", bar_kind, track)
		t.set_stylebox("grabber", bar_kind, grab)
		t.set_stylebox("grabber_highlight", bar_kind, grab_hi)
		t.set_stylebox("grabber_pressed", bar_kind, sb(GOLD, Color.TRANSPARENT, 0, 1, 1))
	t.set_constant("separation", "HBoxContainer", 3)
	t.set_constant("separation", "VBoxContainer", 2)
	t.set_constant("h_separation", "GridContainer", 3)
	t.set_constant("v_separation", "GridContainer", 2)
	# tooltip
	t.set_stylebox("panel", "TooltipPanel", sb(Color("0b1224"), GOLD, 1, 3, 2))
	t.set_color("font_color", "TooltipLabel", TEXT)
	return t

# ------------------------------------------------------------------ widgets
func label(text: String, size: int = 8, color: Color = TEXT, font: String = "body") -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	match font:
		"big":
			l.add_theme_font_override("font", font_big)
		"caps":
			l.add_theme_font_override("font", font_caps)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

## A label that gives way to a longer LANGUAGE: it no longer holds its row open at its text's
## width, takes the room it's given (it expands) and breaks onto another line when it must.
func wrap(l: Label, min_w: float = 24.0) -> Label:
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = min_w
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l

## A team's name as a headline in `w` px, centred: the big font at 20 px, else at 16, else at 16
## on two lines, the place above the mascot ("LOS ANGELES" / "MOUNTAIN LIONS"). A name that
## still doesn't fit goes small, in caps, cut short if it has to be.
func team_title(name: String, mascot: String, w: float, color: Color = TEXT) -> Label:
	var size := 20 if text_width(name, 20, "big") <= w else 16
	var text := name
	var font := "big"
	if text_width(name, size, "big") > w:
		var place := name.trim_suffix(" " + mascot.to_upper())
		if place != name and text_width(place, size, "big") <= w and text_width(mascot.to_upper(), size, "big") <= w:
			text = place + "\n" + mascot.to_upper()
		else:
			size = 8
			font = "caps"
	var l := label(text, size, color, font)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.custom_minimum_size.y = 14
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if not "\n" in text:
		l.clip_text = true
		l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	return l

func button(text: String, cb: Callable, style: String = "normal", min_w: int = 0, min_h: int = 18) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(min_w, min_h)
	if style != "normal":
		style_button(b, style)
	b.pressed.connect(func():
		Sfx.play("click")
		cb.call())
	return b

func panel(bg: Color = PANEL, border: Color = BORDER) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", chunky(bg, border, false, false, 4, 3, BEVEL_SOFT))
	return p

# ------------------------------------------------------------------ popups
## THE POPUP (every dialog, notification and confirmation): a raised navy panel with a hard pixel
## shadow, an edge and a title plate in its kind's colour, the body, then the buttons. The kinds:
##   info     white edge, gold title (the default: questions, confirmations, news)
##   reward   gold (achievements, bonuses, purchases)
##   danger   red (deleting, resetting, injuries, forfeits)
##   warn     orange (deadlines, limits, things to check)
##   good     green (something that worked)
const POPUP_KINDS := {
	"info": {"edge": "ffffff", "title": "ffd23f", "plate": "14318c"},
	"reward": {"edge": "ffd23f", "title": "ffd23f", "plate": "3d3410"},
	"danger": {"edge": "ff4a4a", "title": "ff7a7a", "plate": "4a0f22"},
	"warn": {"edge": "ffb13b", "title": "ffb13b", "plate": "47270b"},
	"good": {"edge": "7fe35f", "title": "7fe35f", "plate": "123f22"},
}
const POPUP_FILL := Color("0b1d5c")         # Deck.NAVY
const POPUP_SHADOW := Color(0.01, 0.03, 0.12, 0.85)
const POPUP_PAD_H := 8
const POPUP_PAD_V := 6

func popup_kind(kind: String) -> Dictionary:
	var k: Dictionary = POPUP_KINDS.get(kind, POPUP_KINDS.info)
	return {"edge": Color(k.edge), "title": Color(k.title), "plate": Color(k.plate)}

## The popup's panel: an ink outline round its edge (so it stands off any screen), the soft bevel,
## and a hard shadow 2 px right and 3 down drawn outside the box (the layout doesn't move).
var _popup_cache := {}

func popup_box(kind: String = "info", fill: Color = POPUP_FILL, pad_h: int = POPUP_PAD_H, pad_v: int = POPUP_PAD_V) -> StyleBoxTexture:
	return popup_frame(popup_kind(kind).edge, fill, pad_h, pad_v)

## A toast's frame: the popup's, slimmer, its edge in the message's colour and its navy fill
## tinted a touch toward it (a gold toast reads warm, a green one cool).
func toast_box(edge: Color) -> StyleBoxTexture:
	return popup_frame(edge, Color("0a1440").lerp(Color(edge, 1.0), 0.1), 6, 4)

## A toast's end mark: a 5 x 5 pixel diamond in its colour, lit at the top, on an ink outline (7 x 7).
func toast_pip(col: Color) -> ImageTexture:
	var key := "pip|" + col.to_html()
	if _popup_cache.has(key):
		return _popup_cache[key]
	var img := Image.create(7, 7, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in 7:
		for x in 7:
			var d: int = absi(x - 3) + absi(y - 3)
			if d == 3:
				img.set_pixel(x, y, INK)
			elif d < 3:
				img.set_pixel(x, y, col.lightened(0.45) if y < 3 and d < 2 else col)
	var t := ImageTexture.create_from_image(img)
	_popup_cache[key] = t
	return t

func popup_frame(edge: Color, fill: Color = POPUP_FILL, pad_h: int = POPUP_PAD_H, pad_v: int = POPUP_PAD_V) -> StyleBoxTexture:
	var key := "%s|%s|%d|%d" % [edge.to_html(), fill.to_html(), pad_h, pad_v]
	if _popup_cache.has(key):
		return _popup_cache[key]
	# 8 x 8 for the box (ink ring, edge ring, bevel ring, fill), plus the shadow: 10 x 11
	var img := Image.create(10, 11, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	_ring(img, Rect2i(2, 3, 8, 8), POPUP_SHADOW, true)
	img.fill_rect(Rect2i(3, 4, 6, 6), POPUP_SHADOW)
	_ring(img, Rect2i(0, 0, 8, 8), INK, true)
	_ring(img, Rect2i(1, 1, 6, 6), edge, false)
	img.fill_rect(Rect2i(2, 2, 4, 4), fill)
	for i in range(3, 5):
		img.set_pixel(i, 2, bevel_light(fill, true))
		img.set_pixel(i, 5, bevel_dark(fill, true))
	var s := StyleBoxTexture.new()
	s.texture = ImageTexture.create_from_image(img)
	s.texture_margin_left = 3
	s.texture_margin_top = 3
	s.texture_margin_right = 5     # (the box's right edge, then the shadow)
	s.texture_margin_bottom = 6
	s.expand_margin_left = 1       # the ink ring sits just outside the edge
	s.expand_margin_top = 1
	s.expand_margin_right = 3
	s.expand_margin_bottom = 4
	s.content_margin_left = pad_h
	s.content_margin_right = pad_h
	s.content_margin_top = pad_v
	s.content_margin_bottom = pad_v
	_popup_cache[key] = s
	return s

## A 1 px ring in `r`; cut = leave its four corners out (the pixel-art cut).
func _ring(img: Image, r: Rect2i, col: Color, cut: bool) -> void:
	for x in range(r.position.x, r.end.x):
		for y in [r.position.y, r.end.y - 1]:
			if cut and (x == r.position.x or x == r.end.x - 1):
				continue
			img.set_pixel(x, y, col)
	for y in range(r.position.y + 1, r.end.y - 1):
		img.set_pixel(r.position.x, y, col)
		img.set_pixel(r.end.x - 1, y, col)

## The title plate: a band in the kind's darker colour with a lit top and its edge colour along the
## bottom, holding the title.
func popup_plate(kind: String = "info") -> StyleBoxTexture:
	var key := "plate|" + kind
	if _popup_cache.has(key):
		return _popup_cache[key]
	var k := popup_kind(kind)
	var plate: Color = k.plate
	var img := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	img.fill(plate)
	for x in 4:
		img.set_pixel(x, 0, bevel_light(plate, true))
		img.set_pixel(x, 3, Color(k.edge, 0.7))
	var s := StyleBoxTexture.new()
	s.texture = ImageTexture.create_from_image(img)
	s.texture_margin_top = 1
	s.texture_margin_bottom = 1
	s.content_margin_left = 5
	s.content_margin_right = 5
	s.content_margin_top = 2
	s.content_margin_bottom = 3
	_popup_cache[key] = s
	return s

func hbox(sep: int = 3) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	return h

func vbox(sep: int = 2) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	return v

func spacer(w: int = 0, h: int = 0, expand: bool = false) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(w, h)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if expand:
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return c

func scroll(child: Control) -> ScrollContainer:
	var s := TouchScroll.new()
	s.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	s.size_flags_vertical = Control.SIZE_EXPAND_FILL
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	child.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.add_child(child)
	return s

func margin(child: Control, l: int, t: int, r: int, b: int) -> MarginContainer:
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", l)
	m.add_theme_constant_override("margin_top", t)
	m.add_theme_constant_override("margin_right", r)
	m.add_theme_constant_override("margin_bottom", b)
	m.add_child(child)
	return m

## A Control whose drawing is done by a callable(ci: Control).
func canvas(w: int, h: int, draw_cb: Callable) -> Control:
	var c := DrawBox.new()
	c.custom_minimum_size = Vector2(w, h)
	c.draw_cb = draw_cb
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c

class DrawBox extends Control:
	var draw_cb: Callable
	func _draw() -> void:
		if draw_cb.is_valid():
			draw_cb.call(self)
	func _notification(what: int) -> void:
		if what == NOTIFICATION_TRANSLATION_CHANGED:
			queue_redraw()   # (LANGUAGE changed: its drawn text in the new one)

# ------------------------------------------------------------------ drawing
## Tests set it to an Array to collect every string drawn on a canvas (UI.text, Deck.text).
var drawn_log = null

func text(ci: CanvasItem, pos: Vector2, s: String, size: int = 8, color: Color = TEXT, font: String = "body", align: int = HORIZONTAL_ALIGNMENT_LEFT, width: float = -1.0) -> void:
	s = Loc.t(s)   # (the player's LANGUAGE, as a Label would be)
	if drawn_log != null:
		drawn_log.append(s)
	var f: Font = font_body
	if font == "big":
		f = font_big
	elif font == "caps":
		f = font_caps
	ci.draw_string(f, pos, s, align, width, fit_size(f, s, size, width), color)

## Text drawn into a set width that a longer LANGUAGE would overrun: drawn smaller until it fits
## (never under 5 px). English is drawn as it always was.
func fit_size(f: Font, s: String, size: int, width: float) -> int:
	if width <= 0.0 or Loc.current == Loc.DEFAULT:
		return size
	var tw := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	if tw <= width:
		return size
	return maxi(5, floori(size * width / tw))

func text_shadow(ci: CanvasItem, pos: Vector2, s: String, size: int = 8, color: Color = TEXT, font: String = "body", align: int = HORIZONTAL_ALIGNMENT_LEFT, width: float = -1.0, shadow: Color = Color(0, 0, 0, 0.6)) -> void:
	var sh := shadow
	sh.a *= color.a
	text(ci, pos + Vector2(1, 1), s, size, sh, font, align, width)
	text(ci, pos, s, size, color, font, align, width)

func text_width(s: String, size: int = 8, font: String = "body") -> float:
	s = Loc.t(s)
	var f: Font = font_body
	if font == "big":
		f = font_big
	elif font == "caps":
		f = font_caps
	return f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x


func draw_bar(ci: CanvasItem, r: Rect2, v: float, col: Color, bg: Color = Color(0, 0, 0, 0.45)) -> void:
	ci.draw_rect(r, bg)
	var w := floorf(r.size.x * clampf(v, 0.0, 1.0))
	if w > 0:
		ci.draw_rect(Rect2(r.position, Vector2(w, r.size.y)), col)

## An OVR's colour: gold 90+, green 80s, cyan 70s, white 60s, grey below.
func ovr_color(v: float) -> Color:
	if v >= 90:
		return GOLD
	if v >= 80:
		return GOOD
	if v >= 70:
		return ACCENT
	if v >= 60:
		return TEXT
	return Color("9aa7c4")

## A player's 0-10 OVERALL (or an attribute) in the same colours as ovr_color.
func ten_color(v: float) -> Color:
	if v >= 9.0:
		return GOLD
	if v >= 8.0:
		return GOOD
	if v >= 6.5:
		return ACCENT
	if v >= 5.0:
		return TEXT
	return Color("9aa7c4")

func rating_color(v: float) -> Color:
	if v >= 90:
		return Color("ff6fae")
	if v >= 80:
		return GOLD
	if v >= 70:
		return GOOD
	if v >= 58:
		return ACCENT
	if v >= 45:
		return TEXT
	return DIM


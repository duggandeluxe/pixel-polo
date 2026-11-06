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
var theme: Theme

func _ready() -> void:
	font_body = _load_font("res://assets/fonts/Tiny5-Regular.ttf")
	font_big = _load_font("res://assets/fonts/Jersey10-Regular.ttf")
	font_caps = _load_font("res://assets/fonts/Silkscreen-Regular.ttf")
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
var _chunky_cache := {}

func chunky(fill: Color, border: Color = BORDER, shadow: bool = true, pressed: bool = false, pad_h: int = 6, pad_v: int = 3) -> StyleBoxTexture:
	var key := "%s|%s|%s|%s|%d|%d" % [fill.to_html(), border.to_html(), shadow, pressed, pad_h, pad_v]
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

## Button colours per style: [fill, hover fill, pressed fill, border, font colour]
const BUTTON_STYLES := {
	"normal": ["2a68f5", "3b7bff", "1f52c9", "ffffff", "ffffff"],
	"primary": ["ffd23f", "ffe27a", "e0b52a", "ffffff", "06103a"],
	"good": ["23913a", "2aa846", "1c7a30", "ffffff", "ffffff"],
	"danger": ["c0322f", "d63f3c", "a12826", "ffffff", "ffffff"],
	"ghost": ["1f52c9", "2a5fd9", "1a47b0", "a9c1ff", "ffffff"],
	"tab": ["1f52c9", "2a5fd9", "1a47b0", "a9c1ff", "c3d4ff"],
	"tab_on": ["ffd23f", "ffd23f", "e0b52a", "ffffff", "06103a"],
}

func style_button(b: Button, style: String) -> void:
	var st: Array = BUTTON_STYLES.get(style, BUTTON_STYLES.normal)
	var border := Color(st[3])
	b.add_theme_stylebox_override("normal", chunky(Color(st[0]), border))
	b.add_theme_stylebox_override("hover", chunky(Color(st[1]), border))
	b.add_theme_stylebox_override("pressed", chunky(Color(st[2]), border, false, true))
	b.add_theme_stylebox_override("hover_pressed", chunky(Color(st[2]), border, false, true))
	b.add_theme_stylebox_override("disabled", chunky(Color("3d5aa8"), DIM2, false))
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
	t.set_stylebox("disabled", "Button", chunky(Color("3d5aa8"), DIM2, false))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", GOLD)
	t.set_color("font_disabled_color", "Button", DIM2)
	t.set_font_size("font_size", "Button", 8)
	# panels
	t.set_stylebox("panel", "PanelContainer", chunky(PANEL, BORDER, false, false, 4, 3))
	t.set_stylebox("panel", "Panel", chunky(PANEL, BORDER, false, false, 0, 0))
	# line edit
	var le := sb(Color("0b1f66"), BORDER_HI, 1, 4, 3)
	t.set_stylebox("normal", "LineEdit", le)
	t.set_stylebox("focus", "LineEdit", sb(Color("0b1f66"), GOLD, 1, 4, 3))
	t.set_color("font_color", "LineEdit", TEXT)
	t.set_color("caret_color", "LineEdit", GOLD)
	t.set_font_size("font_size", "LineEdit", 8)
	# scroll bars (thin)
	var grab := sb(Color(1, 1, 1, 0.75), Color.TRANSPARENT, 0, 1, 1)
	var track := sb(Color(0, 0, 0, 0.25), Color.TRANSPARENT, 0, 1, 1)
	t.set_stylebox("scroll", "VScrollBar", track)
	t.set_stylebox("grabber", "VScrollBar", grab)
	t.set_stylebox("grabber_highlight", "VScrollBar", grab)
	t.set_stylebox("grabber_pressed", "VScrollBar", sb(GOLD, Color.TRANSPARENT, 0, 1, 1))
	t.set_stylebox("scroll", "HScrollBar", track)
	t.set_stylebox("grabber", "HScrollBar", grab)
	t.set_stylebox("grabber_highlight", "HScrollBar", grab)
	t.set_stylebox("grabber_pressed", "HScrollBar", sb(GOLD, Color.TRANSPARENT, 0, 1, 1))
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
	p.add_theme_stylebox_override("panel", chunky(bg, border, false, false, 4, 3))
	return p

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

# ------------------------------------------------------------------ drawing
## Tests set it to an Array to collect every string drawn on a canvas (UI.text, Deck.text).
var drawn_log = null

func text(ci: CanvasItem, pos: Vector2, s: String, size: int = 8, color: Color = TEXT, font: String = "body", align: int = HORIZONTAL_ALIGNMENT_LEFT, width: float = -1.0) -> void:
	if drawn_log != null:
		drawn_log.append(s)
	var f: Font = font_body
	if font == "big":
		f = font_big
	elif font == "caps":
		f = font_caps
	ci.draw_string(f, pos, s, align, width, size, color)

func text_shadow(ci: CanvasItem, pos: Vector2, s: String, size: int = 8, color: Color = TEXT, font: String = "body", align: int = HORIZONTAL_ALIGNMENT_LEFT, width: float = -1.0, shadow: Color = Color(0, 0, 0, 0.6)) -> void:
	var sh := shadow
	sh.a *= color.a
	text(ci, pos + Vector2(1, 1), s, size, sh, font, align, width)
	text(ci, pos, s, size, color, font, align, width)

func text_width(s: String, size: int = 8, font: String = "body") -> float:
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


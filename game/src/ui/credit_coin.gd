class_name CreditCoin
extends RefCounted
## THE CREDIT COIN (the Golden Credits update): the official golden water polo coin, drawn after
## every Coaching Credits amount, number first: "35 (coin)", "+8 (coin)". Amounts anywhere in the
## game go through here, so it's the same coin everywhere.
##
## The art is the provided image, kept as it is: assets/ui/credit_coin.png is its native pixel
## grid on a transparent background (tools/make_credit_coin.py, from the original), and every
## size below is made from that source alone with nearest-neighbour sampling (SIZES: each one
## its own file, never one shrunk from another), drawn unfiltered at whole pixels, never
## stretched or cropped. The coin is allowed to stand taller than the number beside it.
##
##   texture(px)            the coin `px` tall (the nearest size made, never bigger than asked)
##   draw_amount(ci, ...)   "NUMBER coin" on a canvas, vertically centred on a line
##   amount_w(...)          how wide that is
##   widget(n, ...)         the same as Controls (a Label and a TextureRect), for containers
##   tag(n)                 "35{coin}": an amount in text (a dialog, a toast, a recap line, a
##                          message); rich() and every place such text is shown turn TAG into
##                          the coin, so the number always comes first and the coin right after

const DIR := "res://assets/ui/"
const SOURCE := "res://assets/ui/credit_coin.png"
## The sizes made from the source (px tall): rows and buttons, headings, the big reward panels.
const SIZES := [16, 20, 24, 32, 48]
const GAP := 2                 # between the number and the coin
## Where an amount's coin goes in text: "35" + TAG.
const TAG := "{coin}"
## rich() also draws a five-star bar in text: STARS % 3.5 ("{stars:3.5}": Deck.star_bar_texture).
const STARS := "{stars:%s}"
static var _ART := RegEx.create_from_string("\\{coin\\}|\\{stars:([0-9.]+)\\}")

static var _cache := {}

## The coin `px` tall: the largest made size that isn't bigger than `px` (the smallest at least).
static func texture(px: int = 16) -> Texture2D:
	var size: int = SIZES[0]
	for s in SIZES:
		if s <= px:
			size = s
	if _cache.has(size):
		return _cache[size]
	var path := "%scredit_coin_%d.png" % [DIR, size]
	var tex: Texture2D = null
	if ResourceLoader.exists(path):
		tex = load(path)
	elif ResourceLoader.exists(SOURCE):
		tex = load(SOURCE)
	else:
		tex = Deck.coin_texture()   # (only until the official art is in the project)
	_cache[size] = tex
	return tex

## The size a coin is drawn at (its texture's own height, whole pixels).
static func height(px: int = 16) -> int:
	return mini(px, texture(px).get_height())

## "35", "+8", "-3": the amount the coin follows.
static func text(n: int, sign: bool = false) -> String:
	return ("%+d" % n) if sign else str(n)

static func amount_w(n_text: String, size: int = 8, font: String = "caps", px: int = 16) -> float:
	return Deck.text_w(n_text, size, font) + GAP + height(px)

## "NUMBER coin" from `x`, centred on `y_mid`; the number in `col`, the coin always gold.
## `align` 0 left, 1 centred in `w`, 2 right-aligned to x. Returns the width drawn.
static func draw_amount(ci: CanvasItem, x: float, y_mid: float, n_text: String, size: int = 8, col: Color = UI.GOLD,
		font: String = "caps", px: int = 16, align: int = 0, w: float = 0.0) -> float:
	var tw := amount_w(n_text, size, font, px)
	if align == 1:
		x += floorf((w - tw) * 0.5)
	elif align == 2:
		x -= tw
	x = roundf(x)
	Deck.text(ci, x, y_mid, n_text, size, col, font)
	var h := height(px)
	var tex := texture(px)
	var at := Vector2(x + Deck.text_w(n_text, size, font) + GAP, roundf(y_mid - h * 0.5))
	ci.draw_texture_rect(tex, Rect2(at, Vector2(h * tex.get_width() / float(tex.get_height()), h).round()), false)
	return tw

## The coin alone, `px` tall, top-left at `at`.
static func draw(ci: CanvasItem, at: Vector2, px: int = 16) -> void:
	var h := height(px)
	var tex := texture(px)
	ci.draw_texture_rect(tex, Rect2(at.round(), Vector2(h * tex.get_width() / float(tex.get_height()), h).round()), false)

## A TextureRect of the coin, `px` tall, crisp (nearest, whole pixels, kept square).
static func icon(px: int = 16) -> TextureRect:
	var tr := TextureRect.new()
	tr.texture = texture(px)
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var h := height(px)
	tr.custom_minimum_size = Vector2(h, h)
	tr.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tr.name = "Coin"
	return tr

## "NUMBER coin" as Controls: an HBox of the amount's Label and the coin.
static func widget(n: int, size: int = 8, col: Color = UI.GOLD, sign: bool = false, px: int = 16, font: String = "caps") -> HBoxContainer:
	return widget_text(text(n, sign), size, col, px, font)

static func widget_text(n_text: String, size: int = 8, col: Color = UI.GOLD, px: int = 16, font: String = "caps") -> HBoxContainer:
	var h := UI.hbox(GAP)
	h.name = "CreditAmount"
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := UI.label(n_text, size, col, font)
	l.name = "Amount"
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(l)
	h.add_child(icon(px))
	h.set_meta("amount", n_text)
	return h

## "35{coin}" ("+8{coin}" with `sign`): an amount in text.
static func tag(n: int, sign: bool = false) -> String:
	return text(n, sign) + TAG

## `t` without its coins, for where no picture can go (a tooltip): "35 credits".
static func plain(t: String) -> String:
	return norm(t).replace(TAG, " credits")

## `t` with its tags as TAG (text put in capitals has "{COIN}").
static func norm(t: String) -> String:
	return t.replace("{COIN}", TAG).replace("{STARS:", "{stars:")

static func has_tag(t: String) -> bool:
	return norm(t).contains(TAG)

## A Button's text with an amount: "REFRESH  3{coin}" -> the text, and the coin as its icon right
## after it (gold whatever the button's colour). Text without TAG is left alone.
static func set_button(b: Button, t: String, px: int = 16) -> Button:
	t = norm(t)
	if not t.contains(TAG):
		b.text = t
		return b
	b.text = t.replace(TAG, "")
	b.icon = texture(px)
	b.icon_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	b.expand_icon = false
	b.add_theme_constant_override("h_separation", GAP)
	b.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return b

## Text that may hold amounts (TAG): a plain Label when it has none; else a RichTextLabel with the
## coin set in the line, centred on it, at whole pixels. `width` > 0 wraps it at that width.
static func rich(t: String, size: int = 8, col: Color = UI.TEXT, font: String = "body", width: float = 0.0, px: int = 16) -> Control:
	t = norm(t)
	if not t.contains(TAG) and not t.contains("{stars:"):
		var l := UI.label(t, size, col, font)
		if width > 0.0:
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			l.custom_minimum_size = Vector2(width, 0)
		return l
	var rl := RichTextLabel.new()
	rl.bbcode_enabled = false
	rl.fit_content = true
	rl.scroll_active = false
	rl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rl.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	rl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if width > 0.0 else TextServer.AUTOWRAP_OFF
	if width > 0.0:
		rl.custom_minimum_size = Vector2(width, 0)
	var f: Font = UI.font_body
	if font == "big":
		f = UI.font_big
	elif font == "caps":
		f = UI.font_caps
	rl.add_theme_font_override("normal_font", f)
	rl.add_theme_font_size_override("normal_font_size", size)
	rl.add_theme_color_override("default_color", col)
	rl.add_theme_constant_override("line_separation", 1)
	var h := height(px)
	var at := 0
	for m in _ART.search_all(t):
		if m.get_start() > at:
			rl.add_text(t.substr(at, m.get_start() - at))
		if m.get_string() == TAG:
			rl.add_image(_gap(), GAP, 1, Color.WHITE, INLINE_ALIGNMENT_CENTER)   # (the number's small gap)
			rl.add_image(texture(px), h, h, Color.WHITE, INLINE_ALIGNMENT_CENTER)
		else:
			var bar := Deck.star_bar_texture(float(m.get_string(1)))
			rl.add_image(bar, bar.get_width(), bar.get_height(), Color.WHITE, INLINE_ALIGNMENT_CENTER)
		at = m.get_end()
	if at < t.length():
		rl.add_text(t.substr(at))
	rl.set_meta("text", t)
	rl.name = "CreditText"
	return rl

static var _gap_tex: Texture2D

## A clear GAP x 1 picture: the space between a number and its coin in rich text.
static func _gap() -> Texture2D:
	if _gap_tex == null:
		var img := Image.create(GAP, 1, false, Image.FORMAT_RGBA8)
		img.fill(Color(0, 0, 0, 0))
		_gap_tex = ImageTexture.create_from_image(img)
	return _gap_tex

## Text that may hold amounts (TAG) on a canvas, from `x`, centred on `y_mid`: the words as
## Deck.text draws them, each coin right after its number. Returns the width drawn.
static func draw_text(ci: CanvasItem, x: float, y_mid: float, t: String, size: int = 8, col: Color = UI.TEXT, font: String = "caps", px: int = 16) -> float:
	var at := x
	var parts := norm(t).split(TAG)
	for i in parts.size():
		if parts[i] != "":
			Deck.text(ci, at, y_mid, parts[i], size, col, font)
			at += Deck.text_w(parts[i], size, font)
		if i < parts.size() - 1:
			at += GAP
			draw(ci, Vector2(at, roundf(y_mid - height(px) * 0.5)), px)
			at += height(px)
	return at - x

## How wide draw_text draws `t`.
static func text_w(t: String, size: int = 8, font: String = "caps", px: int = 16) -> float:
	var parts := norm(t).split(TAG)
	var w := 0.0
	for p in parts:
		w += Deck.text_w(p, size, font)
	return w + (parts.size() - 1) * (GAP + height(px))

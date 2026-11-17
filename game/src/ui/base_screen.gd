class_name BaseScreen
extends Control
## Common chrome for menu screens: tiled background, header bar, safe-area margins, back.
## Career screens get the coaching-credits chip (opens the store) and the season/week chip.

var body: VBoxContainer
var header_left: HBoxContainer
var header_right: HBoxContainer
var title_label: Label
var c: Career
var back_target := "title"     # where the back button goes; career screens use "hub"
var detail := false            # DETAIL MODE (Game.set_detail): drawn at the window's pixels, art in half pixels

func setup(_params: Dictionary) -> void:
	pass

func safe_insets() -> Vector4:
	## left, top, right, bottom in viewport pixels
	if not OS.has_feature("mobile"):
		return Vector4.ZERO
	var win := DisplayServer.window_get_size()
	var safe := DisplayServer.get_display_safe_area()
	if win.x <= 0 or safe.size.x <= 0:
		return Vector4.ZERO
	var vs := get_viewport_rect().size
	var sx := vs.x / float(win.x)
	var sy := vs.y / float(win.y)
	return Vector4(safe.position.x * sx, safe.position.y * sy, (win.x - safe.end.x) * sx, (win.y - safe.end.y) * sy)

func build(title: String, back: bool = true, show_status: bool = false) -> VBoxContainer:
	c = Game.career
	theme = UI.theme
	var bg := UI.canvas(0, 0, _draw_bg)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var ins := safe_insets()
	var root := UI.margin(UI.vbox(3), int(4 + ins.x), 2, int(4 + ins.z), int(3 + ins.w))
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var v: VBoxContainer = root.get_child(0)
	# header: back button at the left, the title centred between the two sides, status at the right
	var head := UI.hbox(4)
	head.custom_minimum_size = Vector2(0, 22)
	v.add_child(head)
	header_left = UI.hbox(4)
	head.add_child(header_left)
	if back:
		header_left.add_child(Deck.icon_button("left", on_back, 24, 20))
	title_label = Label.new()
	title_label.text = title
	title_label.add_theme_font_override("font", UI.font_big)
	title_label.add_theme_font_size_override("font_size", 20)
	title_label.add_theme_color_override("font_color", UI.TEXT)
	title_label.add_theme_color_override("font_shadow_color", Color(0.02, 0.06, 0.25, 0.7))
	title_label.add_theme_constant_override("shadow_offset_x", 1)
	title_label.add_theme_constant_override("shadow_offset_y", 1)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_label.clip_text = true
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(title_label)
	header_right = UI.hbox(4)
	head.add_child(header_right)
	if show_status and c != null:
		header_right.add_child(credits_chip())
		header_right.add_child(_chip("%s  %s" % [c.season_label(), c.calendar_text()], UI.DIM))
	# the title, never cut off (_fit_title): centred on the page while it fits, else smaller, else
	# centred in the room between the two sides
	var refit := func(): _fit_title.call_deferred()   # (never mid-layout or mid-draw)
	for n in [head, header_left, header_right, title_label]:
		n.resized.connect(refit)
	title_label.draw.connect(refit)   # (a title changed later: redrawn)
	# the body fills the page; if a screen needs more height than the phone has, the page scrolls
	body = UI.vbox(3)
	var page := UI.scroll(body)
	# (the page sits in a plain holder so it can be drawn smaller: see _fit_page)
	var holder := Control.new()
	holder.name = "PageHolder"
	holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(holder)
	holder.add_child(page)
	_page = page
	_holder = holder
	holder.resized.connect(_place_page)
	page.resized.connect(func(): body.custom_minimum_size.y = page.size.y)
	body.minimum_size_changed.connect(_queue_fit_page)
	return body

# ------------------------------------------------------------------ FIT (a longer LANGUAGE)
## Another language never makes a page scroll that fits in English: when its text (longer words,
## taller scripts) would need more room than the phone has, the whole page is drawn smaller
## (`fit_scale`), laid out in the larger space that leaves, until it fits. English is never
## touched. A page far taller than the screen (a long list) scrolls in every language, as it
## was made to.
const FIT_MIN := 0.6       # never smaller than this
const FIT_LIST := 1.5      # content this many screens tall: a list, it scrolls
var fit_scale := 1.0
var _page: ScrollContainer
var _holder: Control
var _fitpage_queued := false

func _place_page() -> void:
	if _page == null or _holder == null:
		return
	_page.position = Vector2.ZERO
	_page.scale = Vector2(fit_scale, fit_scale)
	_page.size = _holder.size / fit_scale

func _queue_fit_page() -> void:
	if not _fitpage_queued:
		_fitpage_queued = true
		_fit_page.call_deferred()

## The body's content as it needs to be: its height (the children's, not the page-filling
## minimum it's given) and width.
func _content_size() -> Vector2:
	if body == null:
		return Vector2.ZERO
	var h := 0.0
	var w := 0.0
	var n := 0
	for ch in body.get_children():
		var c := ch as Control
		if c == null or not c.visible:
			continue
		var m := c.get_combined_minimum_size()
		h += m.y
		w = maxf(w, m.x)
		n += 1
	h += maxf(0, n - 1) * body.get_theme_constant("separation")
	return Vector2(w, h)

func _fit_page() -> void:
	_fitpage_queued = false
	if not is_instance_valid(body) or _holder == null or _holder.size.y <= 0.0:
		return
	if Loc.current == Loc.DEFAULT:
		if fit_scale != 1.0:
			fit_scale = 1.0
			_place_page()
		return
	var avail := _holder.size
	var k := fit_scale
	var need := _content_size()
	var room := avail / k
	if need.y > room.y * FIT_LIST and k == 1.0:
		return   # a list: it scrolls
	var kk := k
	if need.y > room.y + 0.5:
		kk = minf(kk, k * room.y / need.y)
	if need.x > room.x + 0.5:
		kk = minf(kk, k * room.x / need.x)
	kk = maxf(FIT_MIN, floorf(kk * 100.0) / 100.0)
	if kk < k - 0.001:
		fit_scale = kk
		_place_page()
		# (smaller -> wider -> fewer wrapped lines: measured again once it's laid out)
		if not get_tree().process_frame.is_connected(_queue_fit_page):
			get_tree().process_frame.connect(_queue_fit_page, CONNECT_ONE_SHOT)
	if fit_scale < 1.0:
		# (drawn smaller: at the display's own resolution, so the text stays sharp)
		var win := get_window()
		if win != null:
			win.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
			win.oversampling = true

## The plain header of the redesigned career screens (roster, training): a square back button,
## the title, then the credits (the number, then the coin: CreditCoin) and season/week chips.
## THE HEADING, NEVER CUT OFF (every screen's): at its size (20, or the screen's own: the
## "title_max" meta) centred on the page, the left side as wide as the right; if it doesn't fit,
## 16; then the sides no longer mirrored (the title centred in the room between them) at its size,
## then 16; at last the 8 px caps font. Recomputed when the header or the title changes.
var _title_key := ""

func _fit_title() -> void:
	if title_label == null or not is_instance_valid(header_left) or not is_instance_valid(header_right):
		return
	var head := title_label.get_parent() as Control
	var key := "%s|%s|%d|%d|%d" % [Loc.current, title_label.text, int(head.size.x), int(_content_w(header_left)), int(_content_w(header_right))]
	if key == _title_key:
		return
	_title_key = key
	var l := _content_w(header_left)
	var r := _content_w(header_right)
	var sep := float(head.get_theme_constant("separation")) * 2.0 + 2.0
	var mirrored := head.size.x - 2.0 * maxf(l, r) - sep
	var free := head.size.x - l - r - sep
	var top := int(title_label.get_meta("title_max", 20))
	var pick := []   # [size, mirror, font]
	for opt in [[top, true], [16, true], [top, false], [16, false]]:
		if int(opt[0]) > top:
			continue
		if UI.font_big.get_string_size(Loc.t(title_label.text), HORIZONTAL_ALIGNMENT_LEFT, -1, int(opt[0])).x <= (mirrored if opt[1] else free):
			pick = [int(opt[0]), bool(opt[1]), UI.font_big]
			break
	if pick.is_empty():
		pick = [8, false, UI.font_caps]
	title_label.add_theme_font_override("font", pick[2])
	title_label.add_theme_font_size_override("font_size", pick[0])
	var w := maxf(l, r) if pick[1] else 0.0
	header_left.custom_minimum_size.x = w
	header_right.custom_minimum_size.x = w

## A side's own width (its children, not the mirror's minimum).
func _content_w(box: HBoxContainer) -> float:
	var w := 0.0
	var n := 0
	for ch in box.get_children():
		if ch is Control and (ch as Control).visible:
			w += (ch as Control).get_combined_minimum_size().x
			n += 1
	return w + maxf(0, n - 1) * float(box.get_theme_constant("separation"))

func build_compact(title: String) -> VBoxContainer:
	build(title, false, false)
	var back := Deck.icon_button("left", on_back, 30, 22, "normal", 2)
	back.tooltip_text = "Back"
	header_left.add_child(back)
	if c != null:
		header_right.add_child(credits_chip())
		header_right.add_child(_chip("%s  %s" % [c.season_label(), c.calendar_text()], UI.TEXT))
		for ch in header_right.get_children():
			ch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return body

# ------------------------------------------------------------------ redesigned-screen pieces
## A dark navy panel with a thin white border and the panel bevel (roster, training, facilities).
func navy_panel(content: Control) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UI.chunky(Deck.NAVY, UI.BORDER, false, false, 8, 5, UI.BEVEL_SOFT))
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(content)
	return p

## Big pixel text in a box only as tall as its letters (a Label would add the font's leading).
func big_text(t: String, col: Color) -> Control:
	var d := UI.canvas(int(Deck.text_w(t, 20, "big")), 15, func(ci): Deck.text(ci, 0, 7.5, t, 20, col, "big"))
	d.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	return d

func divider_line() -> Control:
	var d := UI.canvas(0, 1, func(ci): ci.draw_rect(Rect2(0, 0, ci.size.x, 1), Color(1, 1, 1, 0.55)))
	d.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return d

## A thin vertical line, `h` tall, in a strip `w` wide.
func vline(col: Color, h: int, w: int) -> Control:
	var d := UI.canvas(w, h, func(ci): ci.draw_rect(Rect2(floorf(ci.size.x * 0.5), floorf((ci.size.y - h) * 0.5), 1, h), col))
	d.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return d

func centered(child: Control) -> CenterContainer:
	var cc := CenterContainer.new()
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cc.add_child(child)
	return cc

## A slim button (no drop shadow, so it fits a tight row): one fill, a 1 px border with cut corners,
## the raised bevel; hovered a step lighter with a brighter edge, pressed sunk into the page.
## Caps text.
func flat_button(t: String, cb: Callable, fill: Color, border: Color, font_col: Color, h: int) -> Button:
	var b := UI.button(t, cb, "normal", 0, h)
	var hover := fill.lightened(0.08)
	for st in ["normal", "focus", "disabled"]:
		b.add_theme_stylebox_override(st, UI.chunky(fill, border, false, false, 4, 1, UI.BEVEL_RAISED))
	b.add_theme_stylebox_override("hover", UI.chunky(hover, UI.hover_edge(border), false, false, 4, 1, UI.BEVEL_RAISED))
	for st in ["pressed", "hover_pressed"]:
		b.add_theme_stylebox_override(st, UI.chunky(fill.darkened(0.12), border, false, false, 4, 1, UI.BEVEL_SUNK))
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(k, font_col)
	b.add_theme_font_override("font", UI.font_caps)
	b.add_theme_font_size_override("font_size", 8)
	return b

## The Polo Points chip (the one balance: Wallet.yellow): tap it to open the shop.
func credits_chip() -> Control:
	var b := Deck.cost_button(Wallet.yellow(c), func(): Game.goto("store"), 0, 18)
	b.tooltip_text = "Polo Points (PP): recruits, upgrades and everything else. Tap for the Polo Points Shop."
	b.name = "YellowChip"
	return b

func _chip(text: String, col: Color) -> Control:
	var p := UI.panel(Color(0, 0, 0, 0.18), col if col != UI.DIM else Color(1, 1, 1, 0.55))
	p.add_child(UI.label(text, 8, col, "caps"))
	return p

func _draw_bg(ci: Control) -> void:
	var s := ci.get_viewport_rect().size
	ci.draw_rect(Rect2(Vector2.ZERO, s), UI.BG)
	var col := Color(1, 1, 1, 0.03)
	var x := 0.0
	while x < s.x:
		ci.draw_rect(Rect2(x, 0, 1, s.y), col)
		x += 12.0
	var y := 0.0
	while y < s.y:
		ci.draw_rect(Rect2(0, y, s.x, 1), col)
		y += 12.0

func on_back() -> void:
	Sfx.play("back")
	Game.goto(back_target)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		on_back()

func cap_widget(cap: Color, trim: Color) -> Control:
	return UI.canvas(8, 7, func(ci): Hud.cap_chip(ci, Vector2(0, 0), cap, trim))

func row_button(content: Control, cb: Callable, selected: bool = false, h: int = 18) -> Control:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, h)
	# a list row: see-through (it sits on any panel), the game's cut corners; selected a gold edge
	# on a brighter wash, hovered a light edge, pressed gold and a little darker (it goes in)
	var border := UI.GOLD if selected else Color(1, 1, 1, 0.14)
	var bg := Color(1, 1, 1, 0.1) if selected else Color(1, 1, 1, 0.03)
	b.add_theme_stylebox_override("normal", UI.chunky(bg, border, false, false, 3, 1, UI.BEVEL_NONE))
	b.add_theme_stylebox_override("hover", UI.chunky(Color(1, 1, 1, 0.08), UI.BORDER_HI if not selected else UI.GOLD, false, false, 3, 1, UI.BEVEL_NONE))
	b.add_theme_stylebox_override("pressed", UI.chunky(Color(0, 0, 0, 0.12), UI.GOLD, false, false, 3, 1, UI.BEVEL_NONE))
	b.add_theme_stylebox_override("hover_pressed", UI.chunky(Color(0, 0, 0, 0.12), UI.GOLD, false, false, 3, 1, UI.BEVEL_NONE))
	b.pressed.connect(func():
		Sfx.play("click")
		cb.call())
	var m := UI.margin(content, 3, 1, 3, 1)
	m.set_anchors_preset(Control.PRESET_FULL_RECT)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ignore_mouse(m)
	b.add_child(m)
	# a Button doesn't size to its children: grow it to fit its content (wrapped text included),
	# never shorter than `h`, so nothing spills out of the row
	var fit := func():
		var need := maxf(float(h), m.get_combined_minimum_size().y)
		if not is_equal_approx(b.custom_minimum_size.y, need):
			b.custom_minimum_size.y = need
	m.minimum_size_changed.connect(fit)
	m.resized.connect(fit)
	return b

func _ignore_mouse(n: Node) -> void:
	for ch in n.get_children():
		if ch is Control:
			ch.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_ignore_mouse(ch)

func bar(v: float, col: Color, w: int = 40, h: int = 4) -> Control:
	return UI.canvas(w, h, func(ci): UI.draw_bar(ci, Rect2(0, 0, w, h), v, col))

func fixed_label(text: String, w: int, col: Color = UI.TEXT, size: int = 8) -> Label:
	var l := UI.label(text, size, col)
	l.custom_minimum_size = Vector2(w, 0)
	l.clip_text = true
	return l

func tabs(names: Array, current: String, cb: Callable) -> HBoxContainer:
	var h := UI.hbox(2)
	for n in names:
		var nn: String = n
		h.add_child(UI.button(nn, func(): cb.call(nn), "tab_on" if nn == current else "tab", 0, 16))
	return h

## Wrapped text that takes the width it's given.
func para(text: String, col: Color = UI.TEXT, w: int = 200) -> Label:
	var l := UI.label(text, 8, col)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(w, 0)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l

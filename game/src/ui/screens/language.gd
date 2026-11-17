extends BaseScreen
## SELECT LANGUAGE (Settings -> LANGUAGE): the App Store's 50 localizations, each in its own
## writing system, two to a row in a list that scrolls under a search bar.
##   - SEARCH: as you type, only the languages whose native name, English name or code match
##     ("jap", "日本", "pt-BR"); the count beside it
##   - the language in use: a yellow border and a check
##   - a tap: the game's text changes at once (Loc.set_language: saved, no restart), this page
##     rebuilt in it, where you were in the list and the search kept
## BACK returns to Settings.

const ROW_H := 30

var search: LineEdit
var count_label: Label
var list: GridContainer
var scroller: ScrollContainer
var _query := ""

func _ready() -> void:
	build("SELECT LANGUAGE")
	back_target = "settings"
	_build_page()

func _build_page() -> void:
	for ch in body.get_children():
		body.remove_child(ch)
		ch.queue_free()
	body.add_theme_constant_override("separation", 4)
	# the search bar
	var bar := UI.hbox(5)
	bar.name = "SearchBar"
	body.add_child(bar)
	bar.add_child(_icon("lang_search", SEARCH, UI.ACCENT))
	search = LineEdit.new()
	search.name = "Search"
	search.placeholder_text = "SEARCH LANGUAGES"
	search.text = _query
	search.clear_button_enabled = true
	search.custom_minimum_size = Vector2(0, 18)
	search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	search.add_theme_font_override("font", UI.font_caps)
	search.text_changed.connect(_on_search)
	bar.add_child(search)
	count_label = UI.label("", 8, UI.ACCENT, "caps")
	count_label.name = "Count"
	count_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.add_child(count_label)
	# the list
	list = GridContainer.new()
	list.name = "List"
	list.columns = 2
	list.add_theme_constant_override("h_separation", 5)
	list.add_theme_constant_override("v_separation", 4)
	scroller = UI.scroll(list)
	scroller.name = "Scroller"
	body.add_child(scroller)
	_fill()

# ------------------------------------------------------------------ the list
## Every language matching the search, in the App Store's order.
func matches(q: String) -> Array:
	q = q.strip_edges().to_lower()
	var out: Array = []
	for id in Loc.ids():
		if q == "" or q in Loc.native_name(id).to_lower() or q in Loc.english_name(id).to_lower() or q in String(id).to_lower():
			out.append(id)
	return out

func _fill() -> void:
	for ch in list.get_children():
		list.remove_child(ch)
		ch.queue_free()
	var ids := matches(_query)
	for id in ids:
		list.add_child(_row(id))
	count_label.text = Loc.tn("%d LANGUAGES", ids.size(), "%d LANGUAGE")
	if ids.is_empty():
		var none := UI.label("NO LANGUAGE MATCHES", 8, UI.DIM, "caps")
		none.name = "NoMatches"
		list.add_child(none)

## One language: its name in its own script (big), the English name small under it, a check
## and a yellow border on the one in use.
func _row(id: String) -> Button:
	var on := id == Loc.current
	var b := Button.new()
	b.name = "Lang_" + id
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, ROW_H)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var edge := UI.GOLD if on else UI.BORDER
	var fill := Color("0b1f66") if on else Deck.NAVY
	b.add_theme_stylebox_override("normal", UI.chunky(fill, edge, false, false, 6, 3))
	b.add_theme_stylebox_override("hover", UI.chunky(fill.lightened(0.12), edge, false, false, 6, 3))
	b.add_theme_stylebox_override("pressed", UI.chunky(fill.darkened(0.2), edge, false, true, 6, 3))
	b.add_theme_stylebox_override("hover_pressed", UI.chunky(fill.darkened(0.2), edge, false, true, 6, 3))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.pressed.connect(choose.bind(id))
	var m := UI.margin(UI.hbox(5), 6, 2, 6, 2)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.set_anchors_preset(Control.PRESET_FULL_RECT)
	b.add_child(m)
	var h: HBoxContainer = m.get_child(0)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var v := UI.vbox(0)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(v)
	# (a system-font script at 12: its glyphs are taller than the pixel font's at 16)
	var nat := UI.label(Loc.native_name(id), 12 if Loc.hires(id) else 16, UI.GOLD if on else UI.TEXT, "big")
	nat.name = "Native"
	nat.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED   # (its own name, never translated)
	nat.clip_text = true
	nat.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	v.add_child(nat)
	var en := UI.label(Loc.english_name(id).to_upper(), 8, UI.ACCENT if on else UI.DIM, "caps")
	en.name = "English"
	en.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	en.clip_text = true
	en.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	v.add_child(en)
	if on:
		var ck := _icon("lang_check", CHECK, UI.GOLD)
		ck.name = "Check"
		h.add_child(ck)
	# a Button doesn't size to what's inside it: at least as tall as its two lines
	var fit := func(): b.custom_minimum_size.y = maxf(ROW_H, m.get_combined_minimum_size().y)
	m.minimum_size_changed.connect(fit)
	fit.call()
	return b

const CHECK := ["......#", ".....##", "#...##.", "##.##..", ".###...", "..#....", "......."]
const SEARCH := [".###...", "#...#..", "#...#..", "#...#..", ".###...", "....##.", ".....##"]

func _icon(key: String, rows: Array, col: Color) -> TextureRect:
	var tr := TextureRect.new()
	tr.texture = Deck._pattern_texture(key, rows, col)
	tr.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tr.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tr

func _on_search(t: String) -> void:
	_query = t
	_fill()
	scroller.scroll_vertical = 0

# ------------------------------------------------------------------ choosing
## The game now in `id`: applied and saved at once, this page rebuilt in it (search and place kept).
func choose(id: String) -> void:
	if id == Loc.current:
		Sfx.play("click")
		return
	var at := scroller.scroll_vertical
	Sfx.play("confirm")
	Loc.set_language(id)
	_build_page()
	await get_tree().process_frame
	if is_instance_valid(scroller):
		scroller.scroll_vertical = at
		var row := list.get_node_or_null("Lang_" + id)
		if row is Control:
			Juice.pop(row, 0.06)

func on_back() -> void:
	Sfx.play("back")
	Game.back("settings")

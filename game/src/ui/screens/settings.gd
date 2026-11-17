extends BaseScreen
## SETTINGS: two navy panels side by side on the blue grid, filling the page, each with its own
## small pixel icon.
##   GAMEPLAY          DIFFICULTY (DYNAMIC / EASY / NORMAL / HARD, the pick in yellow, a note on
##                     it underneath) and QUARTER LENGTH: one button, 2 -> 3 -> 4 -> 5 -> 2 MIN,
##                     the loaded career's own (Career.quarter_min, saved with it) or, with no
##                     career, Quick Match's (Game.settings.quarter_min). Read when a match starts:
##                     a change is for the next game.
##   AUDIO & FEEDBACK  SOUND EFFECTS, MUSIC, VIBRATION, REDUCE MOTION, DISABLE
##                     COACHING REMINDERS: ON (yellow) / OFF (navy)
##   TUTORIALS         under them: CAREER TOUR (the first career's guided tour, CareerTour,
##                     replayed on the loaded dynasty, else the one played last) and GAMEPLAY
##                     TUTORIAL (the drills, DrillScreen, from part 1; BACK returns here)
##   LANGUAGE          beside TUTORIALS: a globe, the word, the language now in its own script;
##                     it opens SELECT LANGUAGE (language.gd, Loc)
## The small DEV button at the top right asks for the developer code (DevPad, checked by DevGate);
## DEVELOPER MODE, its tools and RESET EVERYTHING live on that screen (dev_settings.gd, which
## shares this file's pieces).

const DevPad := preload("res://src/ui/dev_pad.gd")

const NAVY_HI := Color("1a2f86")
const RED := Color("ff5a5a")
## Small pixel icons (the panels' and the rows').
const ICONS := {
	"ball": ["..###..", ".#.#.#.", "#..#..#", "#######", "#..#..#", ".#.#.#.", "..###.."],
	"clock": ["..###..", ".#...#.", "#..#..#", "#..##.#", "#.....#", ".#...#.", "..###.."],
	"sound": ["...#...", "..##.#.", "###..#.", "###..#.", "###..#.", "..##.#.", "...#..."],
	"music": ["..####", "..#..#", "..#..#", "..#..#", "###.##", "###.##", "......"],
	"vibe": ["#.###.#", "#.#.#.#", "..#.#..", "#.#.#.#", "..#.#..", "#.#.#.#", "#.###.#"],
	"motion": ["...#...", "..###..", ".#.#.#.", "...#...", ".#.#.#.", "..###..", "...#..."],
	"dev": ["##...##", "#.#.#.#", ".#...#.", "..#.#..", ".#...#.", "#.#.#.#", "##...##"],
	"wrench": ["...##", "..#..", "..#.#", ".#.##", "#.#..", ".#...", "#...."],
	"warn": ["...#...", "..#.#..", "..#.#..", ".#.#.#.", ".#...#.", "#..#..#", "#######"],
	"speaker": [".......", "##.....", "###.#..", "###..#.", "###.#..", "##.....", "......."],
	"book": ["##.##..", "#.#.#..", "#.#.#..", "#.#.#..", "#.#.#..", "##.##..", "......."],
	"bell": ["...#...", "..###..", ".#####.", ".#####.", ".#####.", "#######", "...#..."],
	"play": ["#......", "##.....", "###....", "####...", "###....", "##.....", "#......"],
	"globe": ["..###..", ".#.#.#.", "#######", "#..#..#", "#######", ".#.#.#.", "..###.."],
	"more": ["#....", "##...", ".##..", "..##.", ".##..", "##...", "#...."],
}

var _pop := ""   # the control just changed: it pops once it's rebuilt (Reduce Motion: never)

func _ready() -> void:
	build("SETTINGS")
	# PRIVACY: the privacy policy (AppConfig.PRIVACY_POLICY_URL), in the browser
	if AppConfig.has_privacy_policy() or DevGate.allowed():
		var priv := Deck.button("PRIVACY", open_privacy, "tab", 52, 16)
		priv.name = "PrivacyButton"
		_navy(priv)
		priv.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		header_right.add_child(priv)
	if DevGate.allowed():   # (release builds: no DEV button at all)
		var dev := Deck.button("DEV", open_dev_pad, "tab", 30, 16)
		dev.name = "DevButton"
		_navy(dev)
		dev.add_theme_color_override("font_color", UI.DIM)
		dev.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		header_right.add_child(dev)
	_refresh()

## PRIVACY POLICY: the published page in the browser. With no URL configured yet (development
## builds only show the button then), says so instead of opening anything.
func open_privacy() -> void:
	if not AppConfig.has_privacy_policy():
		Sfx.play("error")
		Game.toast("Privacy policy URL not set (AppConfig.PRIVACY_POLICY_URL)", UI.WARN)
		return
	Sfx.play("confirm")
	OS.shell_open(AppConfig.PRIVACY_POLICY_URL)

## DEVELOPER ACCESS: the code first, every time (DevGate opens the DEV screen only after it).
func open_dev_pad() -> void:
	if not DevGate.allowed():
		return
	if _dev_pad() == null:
		DevPad.open()

func _dev_pad() -> Node:
	return Game.overlay.get_node_or_null("DevPad") if Game.overlay != null else null

func _refresh() -> void:
	_clear_body()
	var top := UI.hbox(5)
	top.name = "Main"
	# the two panels sit at the top, as tall as the taller one's content (no stretching to the
	# page's bottom: the blue grid shows under them)
	top.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	body.add_child(top)
	var gp := _gameplay()
	gp.size_flags_stretch_ratio = 1.2
	top.add_child(gp)
	top.add_child(_audio())
	var bottom := UI.hbox(5)
	bottom.name = "Bottom"
	bottom.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	bottom.add_child(_tutorials())
	bottom.add_child(_language())
	body.add_child(bottom)
	_pop_changed()

func _clear_body() -> void:
	for ch in body.get_children():
		body.remove_child(ch)
		ch.queue_free()
	body.add_theme_constant_override("separation", 4)
	body.add_child(_underline())

func _pop_changed() -> void:
	if _pop != "":
		var n := body.find_child(_pop, true, false)
		if n is Control:
			Juice.pop(n, 0.08)
		_pop = ""

## The heading's short yellow underline.
func _underline() -> Control:
	var cv := UI.canvas(0, 3, func(ci: Control):
		var w := 64.0
		var x := floorf((ci.size.x - w) * 0.5)
		ci.draw_rect(Rect2(x, 0, w, 2), UI.GOLD)
		ci.draw_rect(Rect2(x + 1, 2, w, 1), Color(0, 0, 0.15, 0.45))
		ci.draw_rect(Rect2(x - 6, 0, 2, 2), UI.GOLD)
		ci.draw_rect(Rect2(x + w + 4, 0, 2, 2), UI.GOLD))
	cv.name = "Underline"
	cv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return cv

# ------------------------------------------------------------------ the pieces
static func icon(name: String, col: Color = Color.WHITE) -> TextureRect:
	var tr := TextureRect.new()
	tr.texture = Deck._pattern_texture("set_%s_%s" % [name, col.to_html()], ICONS[name], col)
	tr.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tr.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tr

## A section: a navy panel, a white pixel border and shadow, its icon and heading on top.
func _section(title: String, ic: String, nm: String, border: Color = UI.BORDER, head_col: Color = UI.TEXT) -> Array:
	var p := PanelContainer.new()
	p.name = nm
	p.add_theme_stylebox_override("panel", UI.chunky(Deck.NAVY, border, false, false, 6, 4))
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := UI.vbox(3)
	p.add_child(v)
	var h := UI.hbox(4)
	h.add_child(icon(ic, UI.GOLD if head_col == UI.TEXT else head_col))
	var l := UI.wrap(UI.label(title, 16, head_col, "big"), 40)   # (a long LANGUAGE: two lines)
	l.name = "Heading"
	h.add_child(l)
	v.add_child(h)
	var rule := ColorRect.new()
	rule.color = Color(border, 0.25)
	rule.custom_minimum_size = Vector2(0, 1)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(rule)
	return [p, v]

## A row: icon, label, and the control at the right.
func _row(ic: String, text: String, ctl: Control, col: Color = UI.TEXT) -> HBoxContainer:
	var r := UI.hbox(5)
	r.add_child(icon(ic, UI.ACCENT))
	var l := UI.wrap(UI.label(text, 8, col, "caps"))
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	r.add_child(l)
	ctl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	r.add_child(ctl)
	return r

## A plate inside a section: a faint inset strip as tall as its content plus even padding, the
## content centred in it.
func _plate(nm: String, content: Control) -> PanelContainer:
	var p := PanelContainer.new()
	p.name = nm
	p.add_theme_stylebox_override("panel", UI.chunky(Color(1, 1, 1, 0.035), Color(1, 1, 1, 0.12), false, false, 6, 5, UI.BEVEL_NONE))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	p.add_child(content)
	return p

## An ON / OFF button: ON yellow, OFF navy with a white border.
func _toggle(on: bool, cb: Callable, nm: String) -> Button:
	var b := Deck.button("ON" if on else "OFF", cb, "tab_on" if on else "tab", 44, 16)
	if not on:
		_navy(b)
	b.name = nm
	return b

## The unselected look: dark navy, a white pixel border.
static func _navy(b: Button) -> void:
	b.add_theme_stylebox_override("normal", UI.chunky(Deck.NAVY, UI.BORDER))
	b.add_theme_stylebox_override("hover", UI.chunky(NAVY_HI, UI.BORDER))
	b.add_theme_stylebox_override("pressed", UI.chunky(Deck.NAVY.darkened(0.2), UI.BORDER, false, true))
	b.add_theme_stylebox_override("hover_pressed", UI.chunky(Deck.NAVY.darkened(0.2), UI.BORDER, false, true))
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(k, UI.TEXT)

# ------------------------------------------------------------------ GAMEPLAY
const DIFF_NOTES := {
	"dynamic": "Starts between EASY and MEDIUM and follows your last few games: beat even teams by a lot and the AI gets smarter, lose heavily and it eases off.",
	"easy": "A more predictable AI: it misreads plays, overlooks open men, and its keeper guesses more.",
	"normal": "Balanced, believable water polo.",
	"hard": "A smarter AI: better passes and shots, tighter rotations, a keeper who reads the open net.",
}

func _gameplay() -> Control:
	var s := _section("GAMEPLAY", "ball", "Gameplay")
	(s[1] as VBoxContainer).add_theme_constant_override("separation", 6)
	var v := UI.vbox(3)
	(s[1] as VBoxContainer).add_child(_plate("DifficultyPlate", v))
	v.add_child(_sub("ball", "DIFFICULTY"))
	var row := UI.hbox(3)
	row.name = "Difficulty"
	v.add_child(row)
	var cur := Difficulty.mode(Game.career != null)   # (a loaded career's own pick)
	# (a LANGUAGE whose names don't fit a quarter of the row: all four in the narrower body font)
	var narrow := Difficulty.MODES.any(func(m): return UI.text_width(Difficulty.NAMES[m], 8, "caps") > 44.0)
	for m in Difficulty.MODES:
		var mm: String = m
		var b := Deck.button(Difficulty.NAMES[mm], func():
			Difficulty.set_mode(mm)
			_pop = "Diff_" + mm
			_refresh(), "tab_on" if cur == mm else "tab", 0, 16)
		if cur != mm:
			_navy(b)
		b.name = "Diff_" + mm
		if narrow:
			b.add_theme_font_override("font", UI.font_body)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size.y = 18
		row.add_child(b)
	# every mode's note stacked in one spot, only the pick's shown: the plate is always as tall
	# as the longest note, so switching difficulty never resizes the box
	var notes := MarginContainer.new()
	notes.name = "DiffNotes"
	v.add_child(notes)
	for m in Difficulty.MODES:
		var nl := para(_diff_note(m), UI.ACCENT, 150)
		nl.name = "DiffNote" if m == cur else "DiffNote_" + String(m)
		if m != cur:
			nl.modulate.a = 0.0   # (invisible, but still holding its height)
		notes.add_child(nl)
	var qp := UI.vbox(3)
	(s[1] as VBoxContainer).add_child(_plate("QuarterPlate", qp))
	qp.add_child(_sub("clock", "QUARTER LENGTH"))
	var q := UI.hbox(6)
	qp.add_child(q)
	var mins := quarter_min()
	var qb := Deck.button(Loc.f("%d MIN", [mins]), _cycle_quarter, "tab_on", 68, 22)
	qb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	qb.name = "QuarterLength"
	qb.add_theme_font_override("font", UI.font_big)
	qb.add_theme_font_size_override("font_size", 16)
	q.add_child(qb)
	var qv := UI.vbox(0)
	qv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	qv.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	qv.add_child(para("Choose how long each quarter lasts.", UI.TEXT, 100))
	var scope := UI.label("%s  |  %s" % [Loc.t("YOUR DYNASTY" if Game.career != null else "QUICK MATCH"), Loc.f("%d:00 GAME", [mins * MatchState.QUARTERS])], 8, UI.ACCENT, "caps")
	scope.name = "QuarterScope"
	UI.wrap(scope)
	qv.add_child(scope)
	q.add_child(qv)
	return s[0]

func _diff_note(m: String) -> String:
	var note := Loc.t(DIFF_NOTES[m])
	if m == "dynamic":
		var qm := Loc.t(Difficulty.word(Difficulty.level_for(false)))
		if Game.career != null:
			note += "  " + Loc.f("Quick Match is at %s, your career at %s.", [qm, Loc.t(Difficulty.word(Difficulty.level_for(true)))])
		else:
			note += "  " + Loc.f("Quick Match is at %s.", [qm])
	return note

func _sub(ic: String, t: String) -> Control:
	var h := UI.hbox(4)
	h.add_child(icon(ic, UI.ACCENT))
	h.add_child(UI.wrap(UI.label(t, 8, UI.GOLD, "caps")))
	return h

## QUARTER LENGTH now: the loaded career's, else Quick Match's.
static func quarter_min() -> int:
	return MatchState.quarter_min_for(Game.career != null)

## One click, the next length (2 -> 3 -> 4 -> 5 -> 2), saved at once where it belongs. A match
## reads it when it starts, so a game already under way never changes.
func _cycle_quarter() -> void:
	var n := MatchState.next_quarter_min(quarter_min())
	if Game.career != null:
		Game.career.quarter_min = n
		Game.save_career()
	else:
		Game.settings.quarter_min = n
		Game.save_settings()
	_pop = "QuarterLength"
	_refresh()

# ------------------------------------------------------------------ AUDIO & FEEDBACK
func _audio() -> Control:
	var s := _section("AUDIO & FEEDBACK", "speaker", "Audio")
	var v: VBoxContainer = s[1]
	v.add_theme_constant_override("separation", 2)   # (five rows: tight, so TUTORIALS stays on screen)
	var first := true
	for key in [["sfx", "SOUND EFFECTS", "sound"], ["music", "MUSIC", "music"], ["haptics", "VIBRATION", "vibe"], ["reduce_motion", "REDUCE MOTION", "motion"], ["no_reminders", "DISABLE COACHING REMINDERS", "bell"]]:
		var k: String = key[0]
		var on: bool = Game.settings[k]
		if not first:   # compact rows, any room the GAMEPLAY panel leaves shared evenly between them
			var gap := Control.new()
			gap.size_flags_vertical = Control.SIZE_EXPAND_FILL
			gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
			v.add_child(gap)
		first = false
		v.add_child(_plate("Row_" + k, _row(key[2], key[1], _toggle(on, func():
			Game.settings[k] = not Game.settings[k]
			Game.save_settings()
			_pop = "Toggle_" + k
			_refresh(), "Toggle_" + k))))
	return s[0]

# ------------------------------------------------------------------ TUTORIALS
## One slim strip (the two panels leave little room under them): its icon and heading, then a
## button for each tutorial. (REPLAY ANY TIME after the heading while the row has the room.)
func _tutorials() -> Control:
	var p := PanelContainer.new()
	p.name = "Tutorials"
	p.add_theme_stylebox_override("panel", UI.chunky(Deck.NAVY, UI.BORDER, false, false, 6, 3))
	p.size_flags_vertical = Control.SIZE_FILL   # (as tall as the LANGUAGE box beside it)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var h := UI.hbox(5)
	p.add_child(h)
	var ic := icon("book", UI.GOLD)
	h.add_child(ic)
	# the heading with REPLAY ANY TIME under it, as LANGUAGE has its language under it
	var hv := UI.vbox(0)
	hv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hv.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(hv)
	# (a LANGUAGE whose word is long: the heading in the small caps, as a page title would go)
	var long := UI.text_width("TUTORIALS", 16, "big") > 96.0
	var l := UI.label("TUTORIALS", 8 if long else 16, UI.TEXT, "caps" if long else "big")
	l.name = "Heading"
	hv.add_child(l)
	var note := UI.wrap(UI.label("REPLAY ANY TIME", 8, UI.ACCENT, "caps"), 40)   # (long: two lines)
	note.name = "TutorialsNote"
	hv.add_child(note)
	var can_tour := Game.career != null or Game.last_slot() != 0
	var tour := Deck.button("CAREER TOUR", _play_tour, "tab_on", 92, 16)
	tour.name = "PlayTour"
	tour.disabled = not can_tour
	tour.tooltip_text = "A guided walk through your dynasty's screens." if can_tour else "Start a dynasty first."
	tour.size_flags_vertical = Control.SIZE_FILL   # (as tall as the strip)
	tour.autowrap_mode = TextServer.AUTOWRAP_WORD   # (a long LANGUAGE: two lines, never wider)
	h.add_child(tour)
	var drills := Deck.button("GAMEPLAY TUTORIAL", _play_drills, "tab_on", 120, 16)
	drills.name = "PlayDrills"
	drills.tooltip_text = "Practice passing, counters, shooting and goalkeeping, from part 1."
	drills.size_flags_vertical = Control.SIZE_FILL
	drills.autowrap_mode = TextServer.AUTOWRAP_WORD
	h.add_child(drills)
	return p

# ------------------------------------------------------------------ LANGUAGE
## The LANGUAGE button: a strip like TUTORIALS' (navy, white pixel border), the globe, LANGUAGE
## and under it the language now, in its own script; a chevron says it opens a list.
func _language() -> Control:
	var b := Button.new()
	b.name = "Language"
	b.focus_mode = Control.FOCUS_NONE
	b.size_flags_vertical = Control.SIZE_FILL
	b.add_theme_stylebox_override("normal", UI.chunky(Deck.NAVY, UI.BORDER, false, false, 6, 3))
	b.add_theme_stylebox_override("hover", UI.chunky(NAVY_HI, UI.BORDER, false, false, 6, 3))
	b.add_theme_stylebox_override("pressed", UI.chunky(Deck.NAVY.darkened(0.2), UI.BORDER, false, true, 6, 3))
	b.add_theme_stylebox_override("hover_pressed", UI.chunky(Deck.NAVY.darkened(0.2), UI.BORDER, false, true, 6, 3))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.pressed.connect(open_language)
	var m := UI.margin(UI.hbox(5), 6, 2, 6, 3)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.set_anchors_preset(Control.PRESET_FULL_RECT)
	b.add_child(m)
	var h: HBoxContainer = m.get_child(0)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(icon("globe", UI.GOLD))
	var v := UI.vbox(0)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(v)
	var long := UI.text_width("LANGUAGE", 16, "big") > 72.0
	var l := UI.label("LANGUAGE", 8 if long else 16, UI.TEXT, "caps" if long else "big")
	l.name = "Heading"
	v.add_child(l)
	var sub := UI.label(Loc.native_name(Loc.current), 8, UI.ACCENT, "caps")
	sub.name = "Current"
	sub.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED   # (a language's own name)
	sub.clip_text = true   # (a long name: cut short with an ellipsis past 96 px)
	sub.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	sub.custom_minimum_size.x = minf(UI.text_width(sub.text, 8, "caps") + 1.0, 96.0)
	v.add_child(sub)
	var ch := icon("more", UI.ACCENT)
	h.add_child(ch)
	# a Button doesn't size to what's inside it: as wide and tall as its content
	var fit := func(): b.custom_minimum_size = m.get_combined_minimum_size()
	m.minimum_size_changed.connect(fit)
	fit.call()
	return b

func open_language() -> void:
	Sfx.play("confirm")
	Game.goto("language")

## CAREER TOUR: on the loaded dynasty's home screen (none loaded: the one played last).
func _play_tour() -> void:
	if Game.career == null:
		var n := Game.last_slot()
		if n == 0 or not Game.load_career(n):
			Sfx.play("error")
			Game.toast(Loc.t("START A DYNASTY FIRST"), UI.WARN)
			return
	Sfx.play("confirm")
	var cur := CareerTour.current()
	if cur != null:
		cur.queue_free()   # (a tour already under way starts over)
	Game.history.clear()
	Game.goto("hub", {}, false)
	CareerTour.start()

## GAMEPLAY TUTORIAL: the drills from part 1; their BACK (and MAIN MENU) come back here.
func _play_drills() -> void:
	Sfx.play("confirm")
	Game.goto("drill", {"id": Drill.ORDER[0], "from": "settings"})

func on_back() -> void:
	var pad := _dev_pad()
	if pad != null:   # (the phone's Back: the code popup closes first)
		pad.cancel()
		return
	Sfx.play("back")
	Game.back("title")

# ------------------------------------------------------------------ the background
## The blue grid, with a little more to it: a darker band top and bottom, thin lines, and small
## pixel balls in the corners.
func _draw_bg(ci: Control) -> void:
	super(ci)
	var s := ci.get_viewport_rect().size
	ci.draw_rect(Rect2(0, 0, s.x, 26), Color(0.02, 0.08, 0.3, 0.22))
	ci.draw_rect(Rect2(0, 26, s.x, 1), Color(1, 1, 1, 0.12))
	ci.draw_rect(Rect2(0, s.y - 18, s.x, 18), Color(0.02, 0.08, 0.3, 0.16))
	ci.draw_rect(Rect2(0, s.y - 19, s.x, 1), Color(1, 1, 1, 0.08))
	var ball: Texture2D = Deck._pattern_texture("set_bgball", ICONS.ball, Color(1, 1, 1, 0.1))
	for p in [Vector2(6, s.y - 13), Vector2(s.x - 13, s.y - 13)]:
		ci.draw_texture(ball, p)

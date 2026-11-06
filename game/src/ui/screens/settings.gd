extends BaseScreen
## SETTINGS: four navy panels on the blue grid, each with its own small pixel icon.
##   GAMEPLAY          DIFFICULTY (DYNAMIC / EASY / NORMAL / HARD, the pick in yellow, a note on
##                     it underneath) and QUARTER LENGTH: one button, 2 -> 3 -> 4 -> 5 -> 2 MIN,
##                     the loaded career's own (Career.quarter_min, saved with it) or, with no
##                     career, Quick Match's (Game.settings.quarter_min). Read when a match starts:
##                     a change is for the next game.
##   AUDIO & FEEDBACK  SOUND EFFECTS, MUSIC, VIBRATION, REDUCE MOTION: ON (yellow) / OFF (navy)
##   GAME OPTIONS      DEVELOPER MODE
##   DANGER ZONE       RESET EVERYTHING, after two confirmations
## Developer Mode on adds the DEVELOPER TOOLS panel: the HOT form lab, the SHOT & TEMPO TEST, the
## ATTRIBUTE TEST LAB, the HOT STAR REVEAL preview, SPECIAL GOAL EFFECTS (BAR-IN! / BAR-DOWN! on
## demand), DEFENSIVE TESTING (the pistons, the one-arm block, the penalty from behind), RECORD
## ROOM ANIMATIONS, COACHING EVENTS (coach_lab), HOT STAR TESTING (hot_star_lab), COIN WALLET TESTING (coin_lab) and PREGAME CINEMATIC TESTING
## (cinema_lab).

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
}

var _pop := ""   # the control just changed: it pops once it's rebuilt (Reduce Motion: never)

func _ready() -> void:
	build("SETTINGS")
	_refresh()

func _refresh() -> void:
	for ch in body.get_children():
		body.remove_child(ch)
		ch.queue_free()
	body.add_theme_constant_override("separation", 4)
	body.add_child(_underline())
	var top := UI.hbox(4)
	top.name = "Main"
	body.add_child(top)
	var gp := _gameplay()
	gp.size_flags_stretch_ratio = 1.15
	top.add_child(gp)
	top.add_child(_audio())
	var bottom := UI.hbox(4)
	bottom.name = "Lower"
	body.add_child(bottom)
	var go := _options()
	go.size_flags_stretch_ratio = 1.15
	bottom.add_child(go)
	bottom.add_child(_danger())
	if bool(Game.settings.get("dev_mode", false)):
		body.add_child(_dev_tools())
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
	var l := UI.label(title, 16, head_col, "big")
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
	var l := UI.label(text, 8, col, "caps")
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	r.add_child(l)
	r.add_child(ctl)
	return r

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
	"dynamic": "Starts at MEDIUM and follows your last few games: beat even teams by a lot and the AI gets smarter, lose heavily and it eases off.",
	"easy": "A more predictable AI: it misreads plays, overlooks open men, and its keeper guesses more.",
	"normal": "Balanced, believable water polo.",
	"hard": "A smarter AI: better passes and shots, tighter rotations, a keeper who reads the open net.",
}

func _gameplay() -> Control:
	var s := _section("GAMEPLAY", "ball", "Gameplay")
	var v: VBoxContainer = s[1]
	v.add_child(_sub("ball", "DIFFICULTY"))
	var row := UI.hbox(3)
	row.name = "Difficulty"
	v.add_child(row)
	var cur := Difficulty.mode(Game.career != null)   # (a loaded career's own pick)
	for m in Difficulty.MODES:
		var mm: String = m
		var b := Deck.button(Difficulty.NAMES[mm], func():
			Difficulty.set_mode(mm)
			_pop = "Diff_" + mm
			_refresh(), "tab_on" if cur == mm else "tab", 0, 16)
		if cur != mm:
			_navy(b)
		b.name = "Diff_" + mm
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(b)
	var note: String = DIFF_NOTES[cur]
	if cur == "dynamic":
		note += "  Quick Match is at %s%s." % [Difficulty.word(Difficulty.level_for(false)),
			(", your career at %s" % Difficulty.word(Difficulty.level_for(true))) if Game.career != null else ""]
	var nl := para(note, UI.ACCENT, 150)
	nl.name = "DiffNote"
	v.add_child(nl)
	v.add_child(_sub("clock", "QUARTER LENGTH"))
	var q := UI.hbox(5)
	v.add_child(q)
	var mins := quarter_min()
	var qb := Deck.button("%d MIN" % mins, _cycle_quarter, "tab_on", 64, 20)
	qb.name = "QuarterLength"
	qb.add_theme_font_override("font", UI.font_big)
	qb.add_theme_font_size_override("font_size", 16)
	q.add_child(qb)
	var qv := UI.vbox(0)
	qv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	qv.add_child(para("Choose how long each quarter lasts.", UI.TEXT, 100))
	var scope := UI.label("%s  |  %d:00 GAME" % ["YOUR DYNASTY" if Game.career != null else "QUICK MATCH", mins * MatchState.QUARTERS], 8, UI.ACCENT, "caps")
	scope.name = "QuarterScope"
	qv.add_child(scope)
	q.add_child(qv)
	return s[0]

func _sub(ic: String, t: String) -> Control:
	var h := UI.hbox(4)
	h.add_child(icon(ic, UI.ACCENT))
	h.add_child(UI.label(t, 8, UI.GOLD, "caps"))
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
	for key in [["sfx", "SOUND EFFECTS", "sound"], ["music", "MUSIC", "music"], ["haptics", "VIBRATION", "vibe"], ["reduce_motion", "REDUCE MOTION", "motion"]]:
		var k: String = key[0]
		var on: bool = Game.settings[k]
		v.add_child(_row(key[2], key[1], _toggle(on, func():
			Game.settings[k] = not Game.settings[k]
			Game.save_settings()
			_pop = "Toggle_" + k
			_refresh(), "Toggle_" + k)))
	return s[0]

# ------------------------------------------------------------------ GAME OPTIONS
func _options() -> Control:
	var s := _section("GAME OPTIONS", "wrench", "Options")
	var v: VBoxContainer = s[1]
	var dev: bool = Game.settings.get("dev_mode", false)
	var ar: bool = Game.settings.get("auto_replay", true)
	if Store.looks.level("replay") >= 2:   # (INSTANT REPLAY unlocked: its one on/off switch)
		ar = ar and Store.looks.worn("replay") >= 2
		v.add_child(_row("motion", "AUTOMATIC REPLAYS", _toggle(ar, func():
			if not ar:
				Store.equip_level("replay", 2)
			Game.settings.auto_replay = not ar
			Game.save_settings()
			_pop = "Toggle_auto_replay"
			_refresh(), "Toggle_auto_replay")))
	# a pack you own that this dynasty doesn't play yet (NOT NOW on the invitation, say)
	var cc: Career = Game.career
	if cc != null:
		for d in [Colleges.D2, Colleges.D3]:
			var dv: int = d
			if not dv in cc.divisions and Colleges.division_enabled(dv) and Store.division_owned(dv):
				var waiting: bool = dv in cc.div_pending
				var add := UI.button("JOINS NEXT SEASON" if waiting else "ADD NEXT SEASON", func():
					cc.queue_division(dv)
					cc.div_answers[str(dv)] = "add"
					Game.save_career()
					_refresh(), "ghost" if waiting else "normal", 0, 14)
				add.name = "AddDivision%d" % dv
				add.disabled = waiting
				v.add_child(_row("wrench", Colleges.division_name(dv), add))
	v.add_child(_row("dev", "DEVELOPER MODE", _toggle(dev, func():
		Game.settings.dev_mode = not dev
		if dev:
			BarHit.override = BarHit.Override.NORMAL   # (its overrides never outlive it)
		Game.save_settings()
		_pop = "Toggle_dev_mode"
		_refresh(), "Toggle_dev_mode")))
	return s[0]

## Developer Mode's tools (unchanged), in their own panel.
func _dev_tools() -> Control:
	var s := _section("DEVELOPER TOOLS", "dev", "DevTools")
	var g := GridContainer.new()
	g.columns = 4
	g.add_theme_constant_override("h_separation", 3)
	g.add_theme_constant_override("v_separation", 3)
	var tools: Array = [["TEST PLAYER FORM", "form_lab", "FormLab"], ["SHOT & TEMPO TEST", "tempo_lab", "TempoLab"], ["ATTRIBUTE TEST LAB", "attr_lab", "AttrLab"],
			["HOT STAR REVEAL", "hot_lab", "HotLab"], ["SPECIAL GOAL EFFECTS", "fx_lab", "FxLab"], ["DEFENSIVE TESTING", "defense_lab", "DefenseLab"],
			["RECORD ROOM ANIMATIONS", "record_lab", "RecordLab"], ["COACHING EVENTS", "coach_lab", "CoachLab"],
			["HOT STAR TESTING", "hot_star_lab", "HotStarLab"], ["COIN WALLET TESTING", "coin_lab", "CoinLab"],
			["PREGAME CINEMATIC TESTING", "cinema_lab", "CinemaLab"], ["VISUAL UPGRADE TESTING", "visual_lab", "VisualLab"],
			["DYNASTY REFINEMENT TESTS", "refine_lab", "RefineLab"]]
	if Colleges.lower_divisions:   # (hibernated: the lab's screen stays in the game, unlisted)
		tools.append(["DIVISION EXPANSION TESTING", "division_lab", "DivisionLab"])
	for t in tools:
		var to: String = t[1]
		var b := UI.button(String(t[0]), func(): Game.goto(to), "ghost", 0, 18)
		b.name = String(t[2])
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.clip_text = true
		g.add_child(b)
	(s[1] as VBoxContainer).add_child(g)
	return s[0]

# ------------------------------------------------------------------ DANGER ZONE
func _danger() -> Control:
	var s := _section("DANGER ZONE", "warn", "ResetRow", RED, RED)
	var p: PanelContainer = s[0]
	p.add_theme_stylebox_override("panel", UI.chunky(Color("2a0d22"), RED, false, false, 6, 4))
	var v: VBoxContainer = s[1]
	var rb := Deck.button("RESET EVERYTHING", _confirm_reset, "danger", 0, 18)
	rb.name = "ResetGame"
	rb.add_theme_stylebox_override("normal", UI.chunky(Color("c0322f"), Color.WHITE))
	v.add_child(rb)
	v.add_child(para("Erase your saved progress and restore defaults.", Color("ffb3b3"), 100))
	return p

## Two steps: what goes, then are you sure. Nothing is touched until the second yes.
func _confirm_reset() -> void:
	Game.dialog("RESET GAME?", "This puts Pixel Polo back the way it was when you installed it:\n\n- every career save is deleted\n- Road to Glory unlocks are lost\n- settings go back to their defaults\n- PIXEL POLO + and ALL 30 TEAMS are removed from the game\n\nPurchased Yellow Coins will remain available. Each career's earned coins go with it. Paid unlocks come back only if you use RESTORE PURCHASES in the store.", [
		["CONTINUE", _confirm_reset_again, "danger"],
		["CANCEL", Callable(), "ghost"]])

func _confirm_reset_again() -> void:
	Game.dialog("ARE YOU SURE?", "All of it is gone for good. This can't be undone.", [
		["RESET EVERYTHING", _reset, "danger"],
		["CANCEL", Callable(), "ghost"]])

func _reset() -> void:
	Game.reset_everything()
	Game.toast("Pixel Polo has been reset", UI.GOLD)
	Game.goto("title", {}, false)

func on_back() -> void:
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

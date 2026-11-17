class_name HotTutorial
extends Control
## THE FIRST HOT STAR TUTORIAL: the first time one of your players earns a HOT star in a dynasty,
## a short celebration that walks you to the Roster, highlights him and explains what Heating Up
## does (the real numbers: PlayerForm, Attributes.hot_bonus, PoloTeam.team_overall). Once per
## dynasty save, for good. It lives on Game.overlay like CareerTour, and reads and changes nothing
## of the Heating Up system: no grade, heat, run or bonus is touched.
##
## WHEN IT PLAYS (Career.hot_tutorial_seen / hot_tutorial_pid, saved with the dynasty):
##   - Career._grade calls note_graded after every game your seven play (played or simulated): the
##     first of yours whose heat rose from NORMAL is queued (hot_tutorial_pid; several in one game:
##     the best game of them, the order PlayerForm.limit_hot gives spots in).
##   - The home screen calls maybe_start: never mid-game, never over a coaching event (the hub sends
##     those to their own screen first), never over the first-career tour. It waits, hidden, while a
##     dialog is up (postgame results, cards, tips) and shows once they're all closed.
##   - An older save, or one whose queued player cooled off before you got home: whoever of yours is
##     HOT right now (the hottest, then the best last game). Nobody HOT: it waits for the next one.
##   - GOT IT! or SKIP TUTORIAL marks it seen for that dynasty (saved). Leaving it some other way (a
##     match, the title screen) doesn't: it comes back the next time you're home.
##
## THE STEPS: an announcement on the home screen (CONTINUE); the ROSTER button highlighted, the real
## button the only thing that takes a tap; then on the Roster, his card lit in a fire-red frame with
## an arrow, his burning red stars outlined, the rest dimmed: what HOT means (NEXT), HEATING UP
## BONUSES (his own attributes at HOT and VERY HOT), the HOT_SLOTS limit, and KEEP THE FIRE GOING!
## (GOT IT!). REDUCE MOTION: nothing bobs, pulses or flickers.
##
## PREVIEW (Settings > DEV > Developer Tools: PREVIEW HOT STAR TUTORIAL, preview()): the same walk
## on the dynasty that's loaded, from its home screen, whether or not anyone is HOT. Nothing is
## saved or marked: no seen flag, no hot_tip, and nobody's heat changes. A player who isn't HOT is
## shown HOT on his card only (the Roster's own display-only test form, dev_forms).

const NODE_NAME := "HotTutorial"
const DIM := Color(0.0, 0.02, 0.1, 0.5)   # "slightly darken"
const BOX_W := 184.0
const GAP := 20.0
const EDGE := 4.0
const HOLE_PAD := 2.0
const ARROW_PX := 2.0
const SETTLE_FRAMES := 4      # dialog-free frames before it shows (chained dialogs never flash it)

const FIRE := Color("ff4a2a")        # PlayerForm.FIRE_RED
const FLAME := Color("ff8a3d")
const EMBER := Color("ffb13b")
const DEEP := Color("6a0f08")
const PANEL_FILL := Color("1a0f2e")  # a warm navy for the fire panels

const RosterScreen := preload("res://src/ui/screens/roster.gd")
const HotBadge := preload("res://src/ui/hot_badge.gd")

## Screens where it stops for now (not marked seen: it comes back at home).
const END_ON := ["title", "match", "matchup", "mp_match", "drill", "new_career", "careers"]

const STEPS := [
	{"id": "intro", "screen": "hub"},
	{"id": "nav", "screen": "hub", "target": "nav_roster"},
	{"id": "player", "screen": "roster", "target": "card"},
	{"id": "bonuses", "screen": "roster", "target": "card"},
	{"id": "limit", "screen": "roster", "target": "card"},
	{"id": "final", "screen": "roster"},
]

const NAV_TEXT := "Your player is heating up! Open your Roster to see their new status."
const FINAL_TEXT := "Strong performances can help your players stay HOT and become VERY HOT. Keep winning and developing your team!"

## Tests only: lets it start by itself under --test (otherwise it never does there).
static var force_in_tests := false

var step := 0
var uid := ""
var pid := -1
var preview_mode := false
var preview_heat := 0         # the heat the preview shows (his own, or HOT)
var t := 0.0
var clear_frames := 0
var shown_step := -1
var hole := Rect2()
var has_hole := false
var box_side := ""
var blockers: Array = []
var lid: ColorRect
var deco: Control
var box: PanelContainer
var center_layer: Control
var star_art: Control
var _place_key := ""

# ------------------------------------------------------------------ when it plays
static func auto_allowed() -> bool:
	return force_in_tests or not ("--test" in OS.get_cmdline_user_args())

## After a game of yours is graded (Career._grade): queue the first of your seven to heat up.
## Nothing about the grading changes; this only reads the rows.
static func note_graded(c: Career, rows: Array) -> void:
	if c == null or c.hot_tutorial_seen:
		return
	if c.hot_tutorial_pid >= 0:
		var q := c.team().find_id(c.hot_tutorial_pid)
		if q != null and q.heat > 0:
			return   # (already queued, and still HOT)
	var best: Dictionary = {}
	for row in rows:
		var p: PoloPlayer = row.p
		if PlayerForm.level_of(String(row.before)) != 0 or p.heat <= 0:
			continue
		if best.is_empty() or float(row.pm) > float(best.pm) or (is_equal_approx(float(row.pm), float(best.pm)) and float(row.raw) > float(best.raw)):
			best = row
	if not best.is_empty():
		c.hot_tutorial_pid = (best.p as PoloPlayer).id

## The player the tutorial is about: the queued one while he's HOT, else whoever of yours is HOT
## now (the hottest, then the best last game). Null: nobody.
static func pick_player(c: Career) -> PoloPlayer:
	if c == null:
		return null
	var team := c.team()
	var q := team.find_id(c.hot_tutorial_pid) if c.hot_tutorial_pid >= 0 else null
	if q != null and q.heat > 0:
		return q
	var hot: Array = team.roster.filter(func(x: PoloPlayer): return x.heat > 0)
	if hot.is_empty():
		return null
	hot.sort_custom(func(a: PoloPlayer, b: PoloPlayer):
		if a.heat != b.heat:
			return a.heat > b.heat
		return float(a.last_game.get("pm", 0.0)) > float(b.last_game.get("pm", 0.0)))
	return hot[0]

## The home screen is up: start it if this dynasty hasn't had it and one of yours is HOT.
static func maybe_start() -> HotTutorial:
	if not auto_allowed() or Game.career == null or Game.overlay == null:
		return null
	var cur := current()
	if cur != null:
		return cur
	var c := Game.career
	if c.hot_tutorial_seen or CareerTour.current() != null:
		return null
	var p := pick_player(c)
	if p == null:
		return null
	return start(p)

static func start(p: PoloPlayer) -> HotTutorial:
	var cur := current()
	if cur != null:
		return cur
	var c := Game.career
	c.hot_tutorial_pid = p.id
	c.hot_tip = true   # (the roster's older one-line HOT tip: this covers it, and must not pop over it)
	var tut := HotTutorial.new()
	tut.name = NODE_NAME
	tut.uid = c.uid
	tut.pid = p.id
	Game.overlay.add_child(tut)
	return tut

## The developer preview: the whole tutorial on the loaded dynasty, nothing saved or changed.
static func preview() -> HotTutorial:
	if Game.career == null or Game.overlay == null:
		Game.toast("LOAD A DYNASTY TO PREVIEW", UI.BAD)
		return null
	var old := current()
	if old != null:
		old.get_parent().remove_child(old)
		old.free()
	var c := Game.career
	var p := pick_player(c)
	if p == null:
		var seven := c.team().starters()
		if seven.is_empty():
			Game.toast("NO PLAYERS TO PREVIEW", UI.BAD)
			return null
		p = seven[mini(3, seven.size() - 1)]
	var tut := HotTutorial.new()
	tut.name = NODE_NAME
	tut.uid = c.uid
	tut.pid = p.id
	tut.preview_mode = true
	tut.preview_heat = maxi(1, p.heat)
	Game.overlay.add_child(tut)
	Game.goto("hub")
	return tut

static func current() -> HotTutorial:
	if Game.overlay == null:
		return null
	var n := Game.overlay.get_node_or_null(NODE_NAME)
	return n as HotTutorial if n != null and not n.is_queued_for_deletion() else null

## Done (GOT IT!) or skipped: seen for good in this dynasty.
static func mark_seen(c: Career) -> void:
	if c == null:
		return
	c.hot_tutorial_seen = true
	c.hot_tutorial_pid = -1
	c.hot_tip = true
	Game.save_career()

# ------------------------------------------------------------------ the overlay
func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = UI.theme
	for i in 4:
		var r := ColorRect.new()
		r.color = DIM
		r.mouse_filter = Control.MOUSE_FILTER_STOP
		add_child(r)
		blockers.append(r)
	lid = ColorRect.new()
	lid.color = Color(0, 0, 0, 0)
	lid.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(lid)
	deco = Control.new()
	deco.mouse_filter = Control.MOUSE_FILTER_IGNORE
	deco.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	deco.draw.connect(_draw_deco)
	add_child(deco)
	_hide_all()

func player() -> PoloPlayer:
	return Game.career.team().find_id(pid) if Game.career != null else null

func step_id() -> String:
	return String(STEPS[step].id)

func _process(dt: float) -> void:
	t += dt
	if Game.career == null or Game.career.uid != uid or Game.current_name in END_ON:
		_close()
		return
	var p := player()
	if p == null:
		_close()   # (he left the roster: it waits for the next one, not marked seen)
		return
	var s: Dictionary = STEPS[step]
	var changing := Game.is_changing_screen()
	# the ROSTER step is done once the Roster is open (the player's own tap on the real button)
	if not changing and step_id() == "nav" and Game.current_name == "roster":
		_go(step + 1)
		s = STEPS[step]
	# back home in the middle of the Roster part (a hardware back): point at ROSTER again
	if not changing and String(s.screen) == "roster" and Game.current_name == "hub":
		_go(1)
		s = STEPS[step]
	if changing or _dialog_up() or Game.current_screen == null or Game.current_name != String(s.screen):
		clear_frames = 0
		_hide_all()
		return
	clear_frames += 1
	if preview_mode:
		_preview_card()
	if clear_frames < SETTLE_FRAMES:
		return
	if step != shown_step:
		_build()
	_quiet_hub_hint()
	if Juice.enabled() and is_instance_valid(star_art):
		star_art.queue_redraw()
	if step_id() in ["intro", "final"]:
		return
	_layout(s)

## The preview's player shown at its heat on his roster card: the Roster's display-only test
## form (Developer Mode's dev_forms, never saved), cleared again when the screen goes.
func _preview_card() -> void:
	if Game.current_name != "roster" or heat_of(player()) == player().heat:
		return
	var forms = Game.current_screen.get("dev_forms")
	if forms is Dictionary and String((forms as Dictionary).get(pid, "")) != state_of(player()):
		(forms as Dictionary)[pid] = state_of(player())
		var cd := card()
		if cd != null:
			cd.queue_redraw()

## Any dialog (or other tap-taking layer) over the screens hides it until it's gone: the overlay's
## dialogs, a celebration drawn on the screen itself (WeeklyAwardShow, ChallengeShow), and the home
## screen's queue (awards, cards, achievements...) until every item in it has been clicked through.
func _dialog_up() -> bool:
	if not preview_mode and Game.current_name == "hub" and Game.career != null and not Game.career.queue.is_empty():
		return true
	if Game.current_screen != null:
		for ch in Game.current_screen.get_children():
			if (ch is WeeklyAwardShow or ch is ChallengeShow) and (ch as Control).visible and not ch.is_queued_for_deletion():
				return true
	for ch in Game.overlay.get_children():
		if ch == self or not ch is Control or ch is CareerTour:
			continue
		var cc := ch as Control
		if cc.visible and cc.mouse_filter == Control.MOUSE_FILTER_STOP and not cc.is_queued_for_deletion():
			return true
	return false

func _quiet_hub_hint() -> void:
	if Game.current_name != "hub":
		return
	var hint := Game.current_screen.find_child("HubHint", true, false)
	if hint != null:
		(hint as Control).visible = false

func _hide_all() -> void:
	for b in blockers:
		(b as Control).visible = false
	if lid != null:
		lid.visible = false
	if deco != null:
		deco.visible = false
	for n in [box, center_layer]:
		if is_instance_valid(n):
			(n as Control).visible = false
	shown_step = -1

# ------------------------------------------------------------------ steps
func _go(i: int) -> void:
	step = clampi(i, 0, STEPS.size() - 1)
	shown_step = -1
	_place_key = ""

func _next() -> void:
	Sfx.play("click")
	_go(step + 1)

func _back() -> void:
	Sfx.play("back")
	_go(step - 1)

func _skip() -> void:
	Sfx.play("back")
	if not preview_mode:
		mark_seen(Game.career)
	_close()
	Game.toast("PREVIEW ENDED" if preview_mode else "TUTORIAL SKIPPED")

func _done() -> void:
	Sfx.play("confirm")
	if not preview_mode:
		mark_seen(Game.career)
	_close()

func _close() -> void:
	if not is_queued_for_deletion():
		queue_free()

# ------------------------------------------------------------------ building
func _build() -> void:
	for n in [box, center_layer]:
		if is_instance_valid(n):
			n.queue_free()
	box = null
	center_layer = null
	star_art = null
	_hide_all()
	shown_step = step
	_place_key = ""
	match step_id():
		"intro":
			_build_intro()
		"final":
			_build_final()
		_:
			_build_box()

func _fire_box() -> StyleBox:
	return UI.popup_frame(FIRE, PANEL_FILL)

## A full-screen dim with one panel in the middle (the announcement, the last word).
func _centered(w: float) -> Array:
	center_layer = Control.new()
	center_layer.name = "TutCenter"
	center_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = DIM
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center_layer.add_child(dim)
	var cc := CenterContainer.new()
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center_layer.add_child(cc)
	var pw := minf(w, get_viewport_rect().size.x - 16.0)
	var panel := PanelContainer.new()
	panel.name = "Popup"
	panel.add_theme_stylebox_override("panel", _fire_box())
	panel.custom_minimum_size = Vector2(pw, 0)
	cc.add_child(panel)
	var v := UI.vbox(5)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(v)
	add_child(center_layer)
	if Juice.enabled():
		panel.pivot_offset = Vector2(pw * 0.5, 50)
		panel.scale = Vector2(0.9, 0.9)
		create_tween().tween_property(panel, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return [v, pw - 2.0 * UI.POPUP_PAD_H]

func _title(text: String, size: int, col: Color, width: float) -> Label:
	var l := UI.label(text, size, col, "big")
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(width, 0)
	l.add_theme_color_override("font_outline_color", DEEP)
	l.add_theme_constant_override("outline_size", 3)
	return l

func _body(text: String, width: float, center := true) -> Label:
	var l := UI.label(text, 8, UI.TEXT, "body")
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if center:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.custom_minimum_size = Vector2(width, 0)
	return l

func _skip_button() -> Button:
	var sk := UI.button("SKIP TUTORIAL", _skip, "ghost", 0, 16)
	sk.name = "TutSkip"
	return sk

## YOUR PLAYER IS HEATING UP!: the big red star in its flames, his name, CONTINUE.
func _build_intro() -> void:
	var parts := _centered(270.0)
	var v: VBoxContainer = parts[0]
	var inner: float = parts[1]
	star_art = UI.canvas(int(inner), 62, _draw_big_star)
	star_art.name = "HotStar"
	v.add_child(star_art)
	var head := _title("YOUR PLAYER IS HEATING UP!", 20, FLAME, inner)
	head.name = "TutTitle"
	v.add_child(head)
	var p := player()
	var nm := ("%s %s" % [p.first, p.last]).strip_edges().to_upper()
	var line := _body("%s has earned %s status! Let's see what that means." % [nm, _state_word(p)], inner)
	line.name = "TutText"
	v.add_child(line)
	v.add_child(UI.spacer(0, 2))
	var row := UI.hbox(6)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(row)
	row.add_child(_skip_button())
	var go := UI.button("CONTINUE", _next, "primary", 96, 22)
	go.name = "TutContinue"
	row.add_child(go)
	Sfx.play("levelup")

## KEEP THE FIRE GOING!: GOT IT! closes it, for good.
func _build_final() -> void:
	var parts := _centered(250.0)
	var v: VBoxContainer = parts[0]
	var inner: float = parts[1]
	star_art = UI.canvas(int(inner), 40, _draw_small_stars)
	v.add_child(star_art)
	var head := _title("KEEP THE FIRE GOING!", 20, FLAME, inner)
	head.name = "TutTitle"
	v.add_child(head)
	var body := _body(FINAL_TEXT, inner)
	body.name = "TutText"
	v.add_child(body)
	v.add_child(UI.spacer(0, 2))
	var bc := CenterContainer.new()
	v.add_child(bc)
	var ok := UI.button("GOT IT!", _done, "primary", 110, 24)
	ok.name = "TutGotIt"
	ok.add_theme_font_override("font", UI.font_big)
	ok.add_theme_font_size_override("font_size", 16)
	bc.add_child(ok)
	Sfx.play("card")

## The small box beside what it highlights: the ROSTER button, then his card.
func _build_box() -> void:
	var id := step_id()
	var w := 212.0 if id == "bonuses" else BOX_W
	box = PanelContainer.new()
	box.name = "TutBox"
	box.mouse_filter = Control.MOUSE_FILTER_STOP
	box.add_theme_stylebox_override("panel", _fire_box())
	box.custom_minimum_size = Vector2(w, 0)
	var inner := w - 2.0 * UI.POPUP_PAD_H
	var v := UI.vbox(3)
	box.add_child(v)
	var p := player()
	match id:
		"nav":
			v.add_child(_box_title("HEATING UP!"))
			v.add_child(_body(NAV_TEXT, inner, false))
			if not has_target_now("nav_roster"):
				# (no ROSTER button on this home screen: open it from here instead)
				var open := UI.button("OPEN ROSTER", func(): Game.goto("roster"), "primary", 0, 16)
				open.name = "TutOpenRoster"
				v.add_child(open)
			else:
				var hint := UI.label("TAP ROSTER", 8, UI.GOLD, "caps")
				hint.name = "TutHint"
				v.add_child(hint)
		"player":
			v.add_child(_box_title("%s IS %s!" % [p.short_name().to_upper(), _state_word(p)]))
			v.add_child(_body("This player is now %s! Their recent performances have earned them a temporary boost to their abilities." % _state_word(p), inner, false))
		"bonuses":
			v.add_child(_box_title("HEATING UP BONUSES"))
			_bonus_rows(v, p, inner)
		"limit":
			v.add_child(_box_title("ONLY %d CAN BE HOT" % PlayerForm.HOT_SLOTS))
			v.add_child(_body("Only %d players on your team can be HOT at once! Players must earn their spot through strong performances." % PlayerForm.HOT_SLOTS, inner, false))
			for b in _limit_points():
				var l := _body("- " + b, inner, false)
				l.add_theme_color_override("font_color", UI.DIM)
				v.add_child(l)
			var now := UI.label("YOUR TEAM NOW: %d / %d HOT" % [PlayerForm.hot_count(Game.career.team()), PlayerForm.HOT_SLOTS], 8, FLAME, "caps")
			now.name = "TutHotCount"
			v.add_child(now)
	var row := UI.hbox(4)
	v.add_child(row)
	row.add_child(_skip_button())
	row.add_child(UI.spacer(0, 0, true))
	if id in ["bonuses", "limit"]:
		var bk := UI.button("BACK", _back, "normal", 40, 16)
		bk.name = "TutBack"
		row.add_child(bk)
	if id in ["player", "bonuses", "limit"]:
		var nx := UI.button("NEXT", _next, "primary", 44, 16)
		nx.name = "TutNext"
		row.add_child(nx)
	add_child(box)
	box.visible = true

func _box_title(text: String) -> Label:
	var l := UI.label(text, 16, FLAME, "big")
	l.clip_text = true
	l.add_theme_color_override("font_outline_color", DEEP)
	l.add_theme_constant_override("outline_size", 2)
	return l

func _state_word(p: PoloPlayer) -> String:
	return "VERY HOT" if p != null and heat_of(p) >= 2 else "HOT"

## His heat as the tutorial shows it: his own, or in a preview the one it shows.
func heat_of(p: PoloPlayer) -> int:
	return preview_heat if preview_mode else p.heat

func state_of(p: PoloPlayer) -> String:
	return PlayerForm.state_of(heat_of(p))

static func _limit_points() -> Array:
	return ["HOT and VERY HOT players each take one of the %d spots." % PlayerForm.HOT_SLOTS,
		"With every spot taken, a player heating up must outplay a HOT teammate in the same game to replace them.",
		"1-star HOT players are replaced first: VERY HOT players are protected while any 1-star player holds a spot."]

## The bonus each level gives, from the game's own numbers (never typed in here).
static func bonus_per_attr(stars: int) -> float:
	return Attributes.HOT_PER_STAR * stars

static func bonus_stars(stars: int) -> float:
	return float(PlayerForm.FORM_STARS[PlayerForm.state_of(stars)])

## HOT / VERY HOT and what each adds, then his own four attributes at each level.
func _bonus_rows(v: VBoxContainer, p: PoloPlayer, inner: float) -> void:
	for n: int in [1, 2]:
		var hdr := UI.hbox(3)
		v.add_child(hdr)
		hdr.add_child(UI.canvas(10 * n - 1, 9, func(ci: CanvasItem): _red_stars(ci, Vector2.ZERO, n, 1.0)))
		var nm := UI.label("%s - %d RED STAR%s" % ["HOT" if n == 1 else "VERY HOT", n, "" if n == 1 else "S"], 8, FLAME, "caps")
		hdr.add_child(nm)
		var txt := "+%.1f to all four attributes (+%s effective star)%s" % [bonus_per_attr(n), _num(bonus_stars(n)),
			"." if n == 1 else ". Earn a second red star while HOT to reach it."]
		var l := _body(txt, inner, false)
		l.name = "TutBonus%d" % n
		v.add_child(l)
	var grid := GridContainer.new()
	grid.name = "TutAttrs"
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 0)
	v.add_child(grid)
	for h in ["%s (%s)" % [p.short_name().to_upper(), Deck.pos_tag(p)], "BASE", "HOT", "V.HOT"]:
		var hl := UI.label(h, 8, UI.GOLD, "caps")
		if h != "BASE" and h != "HOT" and h != "V.HOT":
			hl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(hl)
	for k in Attributes.keys_for(p):
		var base := Attributes.base_play_value(p, k)
		grid.add_child(UI.label(String(Attributes.NAMES[k]).to_upper(), 8, UI.TEXT, "caps"))
		grid.add_child(_cell(base, UI.DIM))
		grid.add_child(_cell(base + bonus_per_attr(1), FLAME))
		grid.add_child(_cell(base + bonus_per_attr(2), FIRE))
	var foot := _body("Every attribute effect in a match uses the boosted value, even past 10. Red stars also count toward your team OVR while they start, and lift them in simulated games.", inner, false)
	foot.add_theme_color_override("font_color", UI.DIM)
	v.add_child(foot)

func _cell(val: float, col: Color) -> Label:
	var l := UI.label("%.1f" % val, 8, col, "caps")
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	return l

static func _num(x: float) -> String:
	return ("%.1f" % x) if not is_equal_approx(x, roundf(x)) else "%d" % int(x)

func has_target_now(target: String) -> bool:
	return not _rects(target).is_empty()

# ------------------------------------------------------------------ layout, every frame
func _layout(s: Dictionary) -> void:
	var vs := get_viewport_rect().size
	var rects := _rects(String(s.get("target", "")))
	has_hole = not rects.is_empty()
	if has_hole:
		var u: Rect2 = rects[0]
		for r in rects:
			u = u.merge(r)
		hole = u.grow(HOLE_PAD).intersection(Rect2(Vector2.ZERO, vs))
		hole = Rect2(hole.position.floor(), hole.size.ceil())
		has_hole = hole.size.x > 2.0 and hole.size.y > 2.0
	var h := hole if has_hole else Rect2(vs * 0.5, Vector2.ZERO)
	var parts := [Rect2(0, 0, vs.x, h.position.y), Rect2(0, h.end.y, vs.x, vs.y - h.end.y),
		Rect2(0, h.position.y, h.position.x, h.size.y), Rect2(h.end.x, h.position.y, vs.x - h.end.x, h.size.y)]
	if not has_hole:
		parts = [Rect2(Vector2.ZERO, vs), Rect2(), Rect2(), Rect2()]
	for i in 4:
		var b: ColorRect = blockers[i]
		var r: Rect2 = parts[i]
		b.position = r.position
		b.size = r.size
		b.visible = r.size.x > 0.0 and r.size.y > 0.0
	# the ROSTER button takes the tap; his card is look-only (no page, no drag mid-tutorial)
	lid.visible = has_hole and step_id() != "nav"
	if lid.visible:
		lid.position = hole.position
		lid.size = hole.size
	deco.visible = has_hole
	deco.queue_redraw()
	if box == null:
		return
	box.visible = true
	var bs := box.get_combined_minimum_size()
	var key := "%s|%s|%s|%s" % [str(hole) if has_hole else "-", str(bs), str(vs), step]
	if key != _place_key:
		_place_key = key
		box.size = bs
		box.position = _place(bs, vs)

## Beside the hole (below, above, right, left) where it fits clear of it; else where it covers
## least of it. Centred with no hole.
func _place(bs: Vector2, vs: Vector2) -> Vector2:
	var lo := Vector2(EDGE, EDGE)
	var hi := (vs - bs - Vector2(EDGE, EDGE)).max(lo)
	if not has_hole:
		box_side = ""
		return ((vs - bs) * 0.5).floor()
	var c := hole.get_center()
	var tries := [["right", Vector2(hole.end.x + GAP, c.y - bs.y * 0.5)], ["left", Vector2(hole.position.x - GAP - bs.x, c.y - bs.y * 0.5)],
		["above", Vector2(c.x - bs.x * 0.5, hole.position.y - GAP - bs.y)], ["below", Vector2(c.x - bs.x * 0.5, hole.end.y + GAP)]]
	if step_id() == "nav":
		tries = [tries[2], tries[3], tries[0], tries[1]]   # (the nav bar's along the bottom: above it)
	var keep := hole.grow(GAP - 3.0)
	for tr in tries:
		var p: Vector2 = (tr[1] as Vector2).clamp(lo, hi).floor()
		if not Rect2(p, bs).intersects(keep):
			box_side = String(tr[0])
			return p
	var best := lo
	var best_score := INF
	var y := lo.y
	while y <= hi.y:
		var x := lo.x
		while x <= hi.x:
			var r := Rect2(Vector2(x, y), bs)
			var score := r.intersection(hole.grow(3.0)).get_area() * 1000.0 + r.get_center().distance_to(c)
			if score < best_score:
				best_score = score
				best = Vector2(x, y)
			x += 6.0
		y += 6.0
	box_side = "over"
	return best.floor()

## The target's rects on screen, read from the live screen every frame.
func _rects(target: String) -> Array:
	var scr := Game.current_screen
	if scr == null or target == "":
		return []
	match target:
		"nav_roster":
			var n := scr.find_child("Nav_roster", true, false)
			return _rect_of(n)
		"card":
			return _rect_of(card())
	return []

## His card on the Roster (a starter's or a sub's), or null.
func card() -> Control:
	var scr := Game.current_screen
	if scr == null or Game.current_name != "roster":
		return null
	var cards = scr.get("cards")
	if not cards is Dictionary or not (cards as Dictionary).has(pid):
		return null
	var n = cards[pid]
	return n as Control if n is Control and is_instance_valid(n) and (n as Control).is_visible_in_tree() else null

func _rect_of(n: Node) -> Array:
	if n == null or not n is Control or not (n as Control).is_visible_in_tree():
		return []
	var r := (n as Control).get_global_rect()
	return [r] if r.size.x > 0.0 and r.size.y > 0.0 else []

## His burning red stars on his card, the fire included (for the highlight and tests).
func badge_rect() -> Rect2:
	var cd := card()
	var p := player()
	if cd == null or p == null or heat_of(p) <= 0:
		return Rect2()
	return HotBadge.rect(Vector2(RosterScreen.STAR_X, RosterScreen.STAR_Y), p.stars, p.stars, state_of(p)).grow(1.0)

func red_star_rect() -> Rect2:
	var cd := card()
	var p := player()
	if cd == null or p == null or heat_of(p) <= 0:
		return Rect2()
	var n := PlayerForm.red_stars(state_of(p))
	var fills := Deck.star_fills(p.stars, p.stars, n)
	var first := -1
	var last := -1
	for i in fills.size():
		var f: Dictionary = fills[i]
		if float(f.form) > float(f.gold) and Color(f.form_col) == PlayerForm.FIRE_RED:
			if first < 0:
				first = i
			last = i
	if first < 0:
		return Rect2()
	var x := RosterScreen.STAR_X + Deck.star_x(first)
	var w := Deck.star_x(last) - Deck.star_x(first) + float(Deck.STAR_SHAPE.w)
	return Rect2(x, RosterScreen.STAR_Y, w, float(Deck.STAR_SHAPE.w)).grow(1.0)

# ------------------------------------------------------------------ drawing
func _pulse(speed := 5.0) -> float:
	return 0.7 + 0.3 * sin(t * speed) if Juice.enabled() else 1.0

func _draw_deco() -> void:
	if not has_hole:
		return
	var fire_step := step_id() != "nav"
	var main := FIRE if fire_step else UI.GOLD
	var f := hole.grow(2.0)
	# a soft glow outside the frame (orange, pulsing; steady with REDUCE MOTION)
	if fire_step:
		var g := Color(EMBER, 0.35 * _pulse())
		_frame(f.grow(2.0), 2.0, g)
	_frame(f, 2.0, Color(main, _pulse()))
	_frame(f.grow(1.0), 1.0, UI.INK)
	# on his card: his burning red stars outlined in gold
	var cd := card()
	if fire_step and cd != null:
		var o := cd.get_global_rect().position
		var lit := Color(UI.GOLD, _pulse(7.0))
		var r := badge_rect()
		if r.size.x > 0.0:
			_frame(Rect2(o + r.position, r.size), 1.0, lit)
	_draw_arrow(f, main)

func _frame(r: Rect2, w: float, col: Color) -> void:
	r = Rect2(r.position.floor(), r.size.floor())
	deco.draw_rect(Rect2(r.position, Vector2(r.size.x, w)), col)
	deco.draw_rect(Rect2(r.position.x, r.end.y - w, r.size.x, w), col)
	deco.draw_rect(Rect2(r.position.x, r.position.y + w, w, r.size.y - 2.0 * w), col)
	deco.draw_rect(Rect2(r.end.x - w, r.position.y + w, w, r.size.y - 2.0 * w), col)

## The arrow (the tour's shape), in the gap on the box's side, bobbing toward the hole.
const ARROW := ["..ooo..", "..o#o..", "ooo#ooo", "o#####o", ".o###o.", "..o#o..", "...o..."]

func _draw_arrow(f: Rect2, col: Color) -> void:
	var bob := roundf(absf(sin(t * 6.0)) * 2.0) if Juice.enabled() else 0.0
	var side := box_side
	if side in ["", "over"]:
		side = "above" if f.position.y > 18.0 else "below"
	var span := ARROW.size() * ARROW_PX
	var c := f.get_center()
	match side:
		"below":
			_arrow(Vector2(floorf(c.x - span * 0.5), f.end.y + 2 + bob), "up", col)
		"above":
			_arrow(Vector2(floorf(c.x - span * 0.5), f.position.y - 2 - span - bob), "down", col)
		"right":
			_arrow(Vector2(f.end.x + 2 + bob, floorf(c.y - span * 0.5)), "left", col)
		"left":
			_arrow(Vector2(f.position.x - 2 - span - bob, floorf(c.y - span * 0.5)), "right", col)

func _arrow(at: Vector2, dir: String, col: Color) -> void:
	var n := ARROW.size()
	for yy in n:
		var row: String = ARROW[yy]
		for xx in row.length():
			var ch := row[xx]
			if ch == ".":
				continue
			var p := Vector2(xx, yy)
			match dir:
				"up":
					p = Vector2(xx, n - 1 - yy)
				"left":
					p = Vector2(n - 1 - yy, xx)
				"right":
					p = Vector2(yy, xx)
			deco.draw_rect(Rect2(at + p * ARROW_PX, Vector2(ARROW_PX, ARROW_PX)), col if ch == "#" else UI.INK)

## Red stars at `scale` px a pixel, `n` of them side by side (Deck.STAR's shape, the game's one star).
static func _red_stars(ci: CanvasItem, at: Vector2, n: int, scale: float) -> void:
	for i in n:
		_star(ci, at + Vector2(i * Deck.STAR_STEP * scale, 0), scale, FIRE, FLAME)

static func _star(ci: CanvasItem, at: Vector2, s: float, fill: Color, lit: Color) -> void:
	var shape: Array = Deck.STAR
	var inner: Array = Deck.STAR_INNER
	for y in shape.size():
		var row: String = shape[y]
		for x in row.length():
			if row[x] != "#":
				continue
			var is_in := String(inner[y])[x] == "#"
			var col := (lit if y <= 3 and x <= 4 else fill) if is_in else DEEP
			ci.draw_rect(Rect2(at + Vector2(x, y) * s, Vector2(s, s)), col)

## The announcement's star: a big red HOT star in a warm glow, flames either side, embers rising.
func _draw_big_star(ci: Control) -> void:
	var w := ci.size.x
	var s := 5.0
	var sw := 9.0 * s
	var moving := Juice.enabled()
	var bob := roundf(sin(t * 3.0) * 1.5) if moving else 0.0
	var at := Vector2(floorf((w - sw) * 0.5), 6.0 + bob)
	# the glow: the star's shape again, a pixel-step bigger each ring, fading out
	for ring: int in [3, 2, 1]:
		var a := (0.12 + 0.06 * (3 - ring)) * _pulse(4.0)
		var gs := s + ring * 0.6
		var off := (Vector2(9.0 * gs, 9.0 * gs) - Vector2(sw, sw)) * 0.5
		_glow(ci, at - off, gs, Color(EMBER, a))
	_star(ci, at, s, FIRE, FLAME)
	# flames either side (HotBadge's VERY HOT flame, two frames)
	var fr := HotBadge.frame()
	var flame: Array = HotBadge.FLAME_VERY[fr % 2]
	for side: int in [-1, 1]:
		var fx := at.x + (sw * 0.5) + side * (sw * 0.5 + 16.0) - 9.0
		_flame(ci, Vector2(floorf(fx), at.y + 14.0 - bob), flame, 3.0)
	# embers drifting up (still with REDUCE MOTION: a few fixed sparks)
	for i in 7:
		var k := float(i) / 7.0
		var x := at.x - 30.0 + fmod(k * 137.0, sw + 60.0)
		var life := fmod(t * 0.6 + k, 1.0) if moving else k
		var y := 58.0 - life * 56.0
		var col := Color(EMBER if i % 2 == 0 else UI.GOLD, 1.0 - life * 0.8)
		ci.draw_rect(Rect2(floorf(x), floorf(y), 2, 2), col)

func _glow(ci: CanvasItem, at: Vector2, s: float, col: Color) -> void:
	var shape: Array = Deck.STAR
	for y in shape.size():
		var row: String = shape[y]
		for x in row.length():
			if row[x] == "#":
				ci.draw_rect(Rect2((at + Vector2(x, y) * s).floor(), Vector2(ceilf(s), ceilf(s))), col)

func _flame(ci: CanvasItem, at: Vector2, rows: Array, s: float) -> void:
	for y in rows.size():
		var row: String = rows[y]
		for x in row.length():
			var col: Color
			match row[x]:
				"r":
					col = FIRE
				"y":
					col = HotBadge.FLAME_Y
				"w":
					col = HotBadge.FLAME_W
				_:
					continue
			ci.draw_rect(Rect2(at + Vector2(x, y) * s, Vector2(s, s)), col)

## The last word's two red stars (VERY HOT to aim for), a small flame between.
func _draw_small_stars(ci: Control) -> void:
	var s := 3.0
	var w := ci.size.x
	var total := 9.0 * s * 2.0 + 10.0
	var bob := roundf(sin(t * 3.0)) if Juice.enabled() else 0.0
	var at := Vector2(floorf((w - total) * 0.5), 6.0 + bob)
	_glow(ci, at - Vector2(2, 2), s + 0.45, Color(EMBER, 0.25 * _pulse(4.0)))
	_glow(ci, at + Vector2(9.0 * s + 10.0, 0) - Vector2(2, 2), s + 0.45, Color(EMBER, 0.25 * _pulse(4.0)))
	_star(ci, at, s, FIRE, FLAME)
	_star(ci, at + Vector2(9.0 * s + 10.0, 0), s, FIRE, FLAME)

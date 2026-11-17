class_name CareerTour
extends Control
## THE FIRST CAREER TOUR: a guided walk through the real screens of the player's very first
## dynasty (home screen, Dynasty Hub, Roster, Training, Coaching and Recruiting, with pinning a
## recruit on his profile), one step at a time. SETTINGS' TUTORIALS replays it any time (start). It lives on Game.overlay, so it rides along as the screens change underneath it.
##
## WHEN IT PLAYS (a global flag in Game.settings, never in a career save):
##   - settings.career_tour: "" (no career started yet), "pending" (the first career has been
##     created, its tour not yet shown) or "seen" (shown, skipped, or not a first career).
##   - Game.start_career calls note_new_career: the first-ever career gets "pending" plus its uid
##     (settings.career_tour_uid); any later career, or one made when a career already existed,
##     makes it "seen". An install from before the tour had careers already: "seen" (Game.load_settings).
##   - The home screen calls maybe_start: only the pending career starts it, and starting marks it
##     "seen" at once, so leaving early, skipping or closing the game never brings it back.
##
## HOW A STEP WORKS (STEPS): the step's screen gets a light dim with a hole over its target (a
## gold frame and a bobbing arrow point at it) and a small dialogue box placed clear of the hole.
## "next" steps advance on NEXT; "click" steps advance when the player's tap opens the step's `to`
## screen (the real button, through the hole). `pass` lets taps through the hole on a "next" step
## (exploring Training or the defenses); otherwise the hole is look-only, so a tap there can't lead
## off the tour. BACK revisits earlier explanations on the same screen; SKIP TUTORIAL ends it.
##
## NEVER STUCK: a dialog on top (a welcome, a tip) hides the tour until it closes; the tour also
## hides during a screen change. On a screen the step isn't about, the tour shrinks to a small
## TUTORIAL PAUSED bar (RESUME TOUR goes back to the step's screen, SKIP ends it). The title screen,
## a match or another career ends it quietly. It reads and changes nothing in the career.

const KEY := "career_tour"
const UID_KEY := "career_tour_uid"
const PENDING := "pending"
const SEEN := "seen"
const NODE_NAME := "CareerTour"

const RosterScreen := preload("res://src/ui/screens/roster.gd")
const RecruitingScreen := preload("res://src/ui/screens/recruiting.gd")

const DIM := Color(0.0, 0.02, 0.1, 0.5)   # "slightly darken"
const BOX_W := 184.0
const GAP := 20.0         # between the hole and the box (the arrow sits in it)
const ARROW_PX := 2.0     # the arrow's pixels
const EDGE := 4.0         # the box keeps this far from the screen's edges
const HOLE_PAD := 2.0

## Screens where the tour ends by itself (the player has left the tour behind).
const END_ON := ["title", "match", "matchup", "mp_match", "drill", "new_career", "careers"]

## The steps, in order. screen: where it's shown; target: what's highlighted (_rects); mode:
## intro (centred, no hole), next, click (to: the screen the tap opens), final.
const STEPS := [
	# ---- the home screen
	{"screen": "hub", "mode": "intro", "target": "", "title": "WELCOME TO PIXEL POLO!",
		"text": "You're now the head coach of your very own college water polo program. Let's take a quick tour!"},
	{"screen": "hub", "mode": "next", "target": "standings", "title": "CONFERENCE STANDINGS",
		"text": "Here you can track your team's conference ranking, record, and competition throughout the season."},
	{"screen": "hub", "mode": "next", "target": "schedule", "title": "SEASON SCHEDULE",
		"text": "This is your season schedule! Play games, track results, and work toward a conference championship."},
	{"screen": "hub", "mode": "click", "to": "more", "target": "hub_door", "title": "DYNASTY HUB",
		"text": "Your Dynasty Hub tracks your program's history, achievements, records, and progress throughout your coaching career.",
		"hint": "TAP THE DYNASTY HUB BUTTON"},
	# ---- the Dynasty Hub
	{"screen": "more", "mode": "next", "target": "dh_program", "title": "PROGRAM OVERVIEW",
		"text": "Your program at a glance: this season's record, conference place and national rank, your team's ratings, and your record as head coach."},
	{"screen": "more", "mode": "next", "target": "dh_history", "title": "HISTORY & RECORDS",
		"text": "League News has the scores and headlines. The Trophy Case holds your championships, and the Record Book keeps records, awards and history."},
	{"screen": "more", "mode": "next", "target": "dh_tools", "title": "MORE TOOLS",
		"text": "The Polo Points Shop, Settings, Visual Upgrades and Recruiting live here too."},
	{"screen": "more", "mode": "next", "target": "dh_all", "title": "YOUR LEGACY",
		"text": "Your Dynasty Hub is where your program's legacy lives. Track your accomplishments and see how your dynasty grows over time!"},
	{"screen": "more", "mode": "click", "to": "hub", "target": "back", "title": "BACK HOME",
		"text": "Come back here any time from the team card on your home screen.", "hint": "TAP THE BACK ARROW"},
	# ---- the roster
	{"screen": "hub", "mode": "click", "to": "roster", "target": "nav_roster", "title": "YOUR ROSTER",
		"text": "Now let's meet your team.", "hint": "TAP ROSTER"},
	{"screen": "roster", "mode": "next", "target": "r_starters", "title": "STARTING LINEUP",
		"text": "These are your starting players! Choose the best lineup to give your team an advantage. Drag one card onto another to swap two players."},
	{"screen": "roster", "mode": "next", "target": "r_card", "title": "PLAYER ATTRIBUTES",
		"text": "Each player has different strengths. Shooting, Passing, Strength, and Defense determine how effective your field players are. Tap a card any time to see them."},
	{"screen": "roster", "mode": "next", "target": "r_stars", "title": "STAR RATINGS",
		"text": "Stars represent player ability, while potential shows how much a player can improve. A player's page shows both."},
	{"screen": "roster", "mode": "next", "target": "r_pos", "title": "PLAYER POSITIONS",
		"text": "Make sure players are assigned to positions that suit their abilities. Utility players can fill multiple roles!"},
	{"screen": "roster", "mode": "next", "target": "r_xp", "title": "PLAYER DEVELOPMENT",
		"text": "Your players can improve throughout their careers by earning XP and developing their attributes. This bar shows their XP."},
	{"screen": "roster", "mode": "click", "to": "hub", "target": "back", "title": "BACK HOME",
		"text": "Your lineup is saved automatically.", "hint": "TAP THE BACK ARROW"},
	# ---- training
	{"screen": "hub", "mode": "click", "to": "training", "target": "nav_training", "title": "TRAINING",
		"text": "Next, your weekly practice plan.", "hint": "TAP TRAINING"},
	{"screen": "training", "mode": "next", "pass": true, "target": "t_focus", "title": "TRAINING FOCUS",
		"text": "Choose a training focus to influence which attributes your players develop: Balanced, Shooting, Passing, Swimming, Strength, Defense or Recovery."},
	{"screen": "training", "mode": "next", "pass": true, "target": "t_intensity", "title": "TRAINING INTENSITY",
		"text": "Higher training intensity can improve development, but it also increases the risk of injuries."},
	{"screen": "training", "mode": "next", "pass": true, "target": "t_recovery", "title": "RECOVERY",
		"text": "Recovery helps injured players heal instead of focusing on attribute development."},
	{"screen": "training", "mode": "next", "target": "t_summary", "title": "PLAYER PROGRESSION",
		"text": "Players earn XP through games and training. As they improve, their abilities can increase! Your plan runs when the week ends."},
	{"screen": "training", "mode": "click", "to": "hub", "target": "back", "title": "BACK HOME",
		"text": "Your training plan is saved automatically.", "hint": "TAP THE BACK ARROW"},
	# ---- coaching and recruiting
	{"screen": "hub", "mode": "click", "to": "coaching", "target": "nav_coaching", "title": "COACHING",
		"text": "Last stop: your gameplan and recruiting.", "hint": "TAP COACHING"},
	{"screen": "coaching", "mode": "next", "pass": true, "target": "c_drops", "title": "DEFENSIVE STRATEGY",
		"text": "Choose your team's defensive strategy! Every possession starts in a PRESS. In games, tap CALL DROP to switch to the drop you pick here: M-DROP, 4-5, 5 or 3-4."},
	{"screen": "coaching", "mode": "next", "target": "c_scout", "title": "SCOUT OPPONENT",
		"text": "Scout your upcoming opponent to learn about their strengths and prepare your strategy."},
	{"screen": "coaching", "mode": "click", "to": "recruiting", "target": "c_open", "title": "RECRUITING",
		"text": "Recruiting is how you build your program for the future.", "hint": "TAP OPEN RECRUITING"},
	{"screen": "recruiting", "mode": "next", "target": "rc_cards", "title": "THE RECRUITS",
		"text": "Gold stars are a recruit's current ability; hollow stars show his potential. Tap a card to see his full profile and attributes."},
	{"screen": "recruiting", "mode": "next", "target": "rc_signed", "title": "SIGNING RECRUITS",
		"text": "Recruits cost Polo Points, and better recruits cost more. Sign up to 4 a season: they join next year. Nothing is spent until you press SIGN RECRUIT."},
	# ---- pinning (a recruit's profile; skipped when the market has nobody to open: `optional`)
	{"screen": "recruiting", "mode": "click", "to": "player", "optional": true, "target": "rc_first", "title": "PIN RECRUITS",
		"text": "Like a prospect but not ready to sign him? You can pin him. Let's open one.", "hint": "TAP A RECRUIT"},
	{"screen": "player", "mode": "next", "pass": true, "target": "p_pin", "title": "PIN RECRUITS",
		"text": "PIN keeps a recruit on your market through every refresh, up to 4 at a time. It's free and signs nobody, and a gold pin marks his card. Give it a try!"},
	{"screen": "player", "mode": "click", "to": "recruiting", "target": "back", "title": "BACK",
		"text": "Tap UNPIN any time to let him go.", "hint": "TAP THE BACK ARROW"},
	{"screen": "recruiting", "mode": "next", "target": "rc_refresh", "title": "NEW RECRUITS",
		"text": "REFRESH RECRUITS brings in new prospects, keeping your pinned ones. Your first refresh each season is free, and fresh recruits also arrive free every 2 games."},
	{"screen": "recruiting", "mode": "click", "to": "coaching", "target": "back", "title": "BACK",
		"text": "Recruiting is also in your Dynasty Hub.", "hint": "TAP THE BACK ARROW"},
	{"screen": "coaching", "mode": "click", "to": "hub", "target": "back", "title": "BACK HOME",
		"text": "That's the tour!", "hint": "TAP THE BACK ARROW"},
	# ---- done
	{"screen": "hub", "mode": "final", "target": "", "title": "YOU'RE READY, COACH!",
		"text": "Manage your roster, develop your players, recruit future stars, and lead your program to a national championship. Your dynasty starts now!"},
]

## Tests only: lets the tour start automatically under --test (otherwise it never does there).
static var force_in_tests := false

var step := 0
var uid := ""
var t := 0.0
var shown_step := -1          # the step the box was built for (-1: rebuild)
var shown_paused := false
var hole := Rect2()
var has_hole := false
var parts_now: Array = []    # the hole's own rects (a lineup: each card), which the box keeps off
var box_side := ""            # where the box sits from the hole: below, above, right, left, over
var blockers: Array = []      # the dim around the hole (four rects) and its lid
var lid: ColorRect
var deco: Control             # the gold frame and the arrow
var box: PanelContainer
var pill: PanelContainer
var final_layer: Control
var _place_key := ""

# ------------------------------------------------------------------ when it plays
## Is the tour allowed to start by itself? Never in a test run, unless a test asks.
static func auto_allowed() -> bool:
	return force_in_tests or not _under_test()

static func _under_test() -> bool:
	return "--test" in OS.get_cmdline_user_args()

## The flag only ever goes to disk outside test runs (a test never touches the player's settings file).
static func _persist() -> void:
	if not _under_test():
		Game.save_settings()

## A career was just created (Game.start_career). `had_career`: a career save already existed.
## Only the first-ever career is given the tour; the decision is made once, for good.
static func note_new_career(c: Career, had_career: bool) -> void:
	if c == null or not auto_allowed() or String(Game.settings.get(KEY, "")) != "":
		return
	Game.settings[KEY] = SEEN if had_career else PENDING
	Game.settings[UID_KEY] = "" if had_career else c.uid
	_persist()

## The home screen is up: start the tour if this is the first career and it hasn't been shown.
static func maybe_start() -> CareerTour:
	if not auto_allowed() or Game.career == null or Game.overlay == null:
		return null
	if String(Game.settings.get(KEY, "")) != PENDING or String(Game.settings.get(UID_KEY, "")) != Game.career.uid:
		return null
	return start()

## Starts the tour now (marking it seen first, so it can never start again by itself).
static func start() -> CareerTour:
	var cur := current()
	if cur != null:
		return cur
	Game.settings[KEY] = SEEN
	_persist()
	var tour := CareerTour.new()
	tour.name = NODE_NAME
	tour.uid = Game.career.uid if Game.career != null else ""
	Game.overlay.add_child(tour)
	return tour

static func current() -> CareerTour:
	if Game.overlay == null:
		return null
	var n := Game.overlay.get_node_or_null(NODE_NAME)
	return n as CareerTour if n != null and not n.is_queued_for_deletion() else null

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
	lid = ColorRect.new()   # over the hole on a look-only step: clear, but it takes the taps
	lid.color = Color(0, 0, 0, 0)
	lid.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(lid)
	deco = Control.new()
	deco.mouse_filter = Control.MOUSE_FILTER_IGNORE
	deco.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	deco.draw.connect(_draw_deco)
	add_child(deco)
	_hide_all()

func _process(dt: float) -> void:
	t += dt
	if Game.career == null or Game.career.uid != uid or Game.current_name in END_ON:
		_finish(false)
		return
	var s: Dictionary = STEPS[step]
	var changing := Game.is_changing_screen()
	# a "click" step is done once its screen is open (however the player got there)
	if not changing and String(s.mode) == "click" and Game.current_name == String(s.get("to", "")):
		_go(step + 1)
		s = STEPS[step]
	# an `optional` section with nothing to show (an empty market): on past it
	if not changing and bool(s.get("optional", false)) and Game.current_name == String(s.screen) and not _optional_ready(s):
		_go(_after_section(step))
		s = STEPS[step]
	if changing or _dialog_up() or Game.current_screen == null:
		_hide_all()
		return
	var paused := Game.current_name != String(s.screen)
	if step != shown_step or paused != shown_paused or (paused and pill == null) or (not paused and box == null and final_layer == null):
		_build(paused)
	if paused:
		return
	_quiet_hub_hint()
	if String(s.mode) == "final":
		return
	_layout(s)

## Any dialog (or other tap-taking layer) over the screens hides the tour until it's gone.
func _dialog_up() -> bool:
	for ch in Game.overlay.get_children():
		if ch == self or not ch is Control:
			continue
		var cc := ch as Control
		if cc.visible and cc.mouse_filter == Control.MOUSE_FILTER_STOP and not cc.is_queued_for_deletion():
			return true
	return false

func _hide_all() -> void:
	for b in blockers:
		(b as Control).visible = false
	if lid != null:
		lid.visible = false
	if deco != null:
		deco.visible = false
	for n in [box, pill, final_layer]:
		if is_instance_valid(n):
			(n as Control).visible = false
	shown_step = -1   # (rebuilt, and placed again, when it comes back)

## The home screen's own "CLICK HERE TO VIEW YOUR DYNASTY HUB!" callout would talk over the tour.
func _quiet_hub_hint() -> void:
	if Game.current_name != "hub":
		return
	var hint := Game.current_screen.find_child("HubHint", true, false)
	if hint != null:
		(hint as Control).visible = false

# ------------------------------------------------------------------ steps
func _go(i: int) -> void:
	step = clampi(i, 0, STEPS.size() - 1)
	shown_step = -1
	_place_key = ""

func _next() -> void:
	Sfx.play("click")
	_go(step + 1)

func _back() -> void:
	if _back_to() >= 0:
		Sfx.play("back")
		_go(_back_to())

## The step BACK returns to: the one before, if it's an explanation on this same screen.
func _back_to() -> int:
	if step <= 0:
		return -1
	var prev: Dictionary = STEPS[step - 1]
	if String(prev.screen) != String(STEPS[step].screen) or not String(prev.mode) in ["next", "intro"]:
		return -1
	return step - 1

func _skip() -> void:
	Sfx.play("back")
	_finish(false)
	Game.toast("TUTORIAL SKIPPED")

## Can an `optional` step be shown? (The pin section: a market recruit to open.)
func _optional_ready(s: Dictionary) -> bool:
	match String(s.target):
		"rc_first":
			return Game.career != null and not Game.career.market.is_empty() and RecruitingScreen.tab == "MARKET"
	return true

## The first step after the optional section starting at `i` (its own screen's steps and the
## ones on the screen it opens, up to the step back on its screen).
func _after_section(i: int) -> int:
	var home := String(STEPS[i].screen)
	var j := i + 1
	while j < STEPS.size() - 1 and String(STEPS[j].screen) != home:
		j += 1
	return j

func _resume() -> void:
	Sfx.play("click")
	# a step on a recruit's page: back to the step that opens one, on the market
	while String(STEPS[step].screen) == "player" and step > 0:
		step -= 1
	_go(step)
	var s: Dictionary = STEPS[step]
	var params := {"from": "coaching"} if String(s.screen) == "recruiting" else {}
	Game.goto(String(s.screen), params)

func _finish(done: bool) -> void:
	if is_queued_for_deletion():
		return
	if done:
		Sfx.play("confirm")
	queue_free()

# ------------------------------------------------------------------ building the box
func _build(paused: bool) -> void:
	for n in [box, pill, final_layer]:
		if is_instance_valid(n):
			n.queue_free()
	box = null
	pill = null
	final_layer = null
	shown_step = step
	shown_paused = paused
	_place_key = ""
	var s: Dictionary = STEPS[step]
	if paused:
		_hide_all()
		shown_step = step
		_build_pill()
		return
	if String(s.mode) == "final":
		_hide_all()
		shown_step = step
		_build_final(s)
		return
	box = PanelContainer.new()
	box.name = "TourBox"
	box.mouse_filter = Control.MOUSE_FILTER_STOP
	box.add_theme_stylebox_override("panel", UI.popup_box("info"))
	box.custom_minimum_size = Vector2(BOX_W, 0)
	var inner := BOX_W - 2.0 * UI.POPUP_PAD_H
	var v := UI.vbox(4)
	box.add_child(v)
	var head := UI.hbox(4)
	v.add_child(head)
	var title := UI.label(String(s.title), 16, UI.GOLD, "big")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.clip_text = true
	head.add_child(title)
	var count := UI.label("%d/%d" % [step + 1, STEPS.size() - 1], 8, UI.DIM, "caps")
	count.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(count)
	var body := UI.label(String(s.text), 8, UI.TEXT, "body")
	body.name = "TourText"
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size = Vector2(inner, 0)
	v.add_child(body)
	if String(s.mode) == "click":
		var hint := UI.label(String(s.get("hint", "TAP THE HIGHLIGHTED BUTTON")), 8, UI.GOLD, "caps")
		hint.name = "TourHint"
		v.add_child(hint)
	var row := UI.hbox(4)
	v.add_child(row)
	var skip := UI.button("SKIP TUTORIAL", _skip, "ghost", 0, 16)
	skip.name = "TourSkip"
	row.add_child(skip)
	row.add_child(UI.spacer(0, 0, true))
	if _back_to() >= 0:
		var back := UI.button("BACK", _back, "normal", 40, 16)
		back.name = "TourBack"
		row.add_child(back)
	if String(s.mode) in ["next", "intro"]:
		var nx := UI.button("NEXT", _next, "primary", 44, 16)
		nx.name = "TourNext"
		row.add_child(nx)
	add_child(box)
	box.visible = true

## TUTORIAL PAUSED: a small bar at the top when the player is on another screen.
func _build_pill() -> void:
	pill = PanelContainer.new()
	pill.name = "TourPaused"
	pill.mouse_filter = Control.MOUSE_FILTER_STOP
	pill.add_theme_stylebox_override("panel", UI.popup_box("info", UI.POPUP_FILL, 6, 3))
	var h := UI.hbox(6)
	pill.add_child(h)
	var l := UI.label("TUTORIAL PAUSED", 8, UI.GOLD, "caps")
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(l)
	var res := UI.button("RESUME TOUR", _resume, "primary", 0, 16)
	res.name = "TourResume"
	h.add_child(res)
	var sk := UI.button("SKIP", _skip, "ghost", 0, 16)
	sk.name = "TourSkip"
	h.add_child(sk)
	add_child(pill)
	pill.reset_size()
	var vs := get_viewport_rect().size
	pill.position = Vector2(floorf((vs.x - pill.get_combined_minimum_size().x) * 0.5), 26.0)

## YOU'RE READY, COACH!: the whole screen dimmed, one big panel, START MY DYNASTY!.
func _build_final(s: Dictionary) -> void:
	final_layer = Control.new()
	final_layer.name = "TourFinal"
	final_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	final_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0.02, 0.1, 0.62)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	final_layer.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	final_layer.add_child(center)
	var p := PanelContainer.new()
	p.name = "Popup"
	p.add_theme_stylebox_override("panel", UI.popup_box("reward"))
	var vw := get_viewport_rect().size.x
	var pw := minf(260.0, vw - 16.0)
	p.custom_minimum_size = Vector2(pw, 0)
	center.add_child(p)
	var v := UI.vbox(6)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	p.add_child(v)
	var title := UI.label(String(s.title), 20, UI.GOLD, "big")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_outline_color", UI.INK)
	title.add_theme_constant_override("outline_size", 2)
	v.add_child(title)
	var body := UI.label(String(s.text), 8, UI.TEXT, "body")
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.custom_minimum_size = Vector2(pw - 2.0 * UI.POPUP_PAD_H, 0)
	v.add_child(body)
	v.add_child(UI.spacer(0, 2))
	var bc := CenterContainer.new()
	v.add_child(bc)
	var go := UI.button("START MY DYNASTY!", func(): _finish(true), "primary", 180, 30)
	go.name = "StartDynasty"
	go.add_theme_font_override("font", UI.font_big)
	go.add_theme_font_size_override("font_size", 20)
	bc.add_child(go)
	add_child(final_layer)
	Sfx.play("levelup")
	if Juice.enabled():
		p.pivot_offset = Vector2(pw * 0.5, 40)
		p.scale = Vector2(0.9, 0.9)
		create_tween().tween_property(p, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

# ------------------------------------------------------------------ layout, every frame
## The dim around the hole, the hole's lid, the box placed clear of it, the frame and arrow.
func _layout(s: Dictionary) -> void:
	var vs := get_viewport_rect().size
	var rects := _rects(String(s.target))
	has_hole = not rects.is_empty()
	parts_now = rects
	if has_hole:
		var u: Rect2 = rects[0]
		for r in rects:
			u = u.merge(r)
		hole = u.grow(HOLE_PAD).intersection(Rect2(Vector2.ZERO, vs))
		hole = Rect2(hole.position.floor(), hole.size.ceil())
		has_hole = hole.size.x > 2.0 and hole.size.y > 2.0
	var h := hole if has_hole else Rect2(vs * 0.5, Vector2.ZERO)
	# four dim rects around the hole (one whole-screen rect with no hole)
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
	var passes := String(s.mode) == "click" or bool(s.get("pass", false))
	lid.visible = has_hole and not passes
	if lid.visible:
		lid.position = hole.position
		lid.size = hole.size
	deco.visible = has_hole
	deco.queue_redraw()
	# the box: placed again only when the hole or its own size changes (no jitter)
	if box == null:
		return
	box.visible = true
	var bs := box.get_combined_minimum_size()
	var key := "%s|%s|%s|%s" % [str(hole) if has_hole else "-", str(bs), str(vs), step]
	if key != _place_key:
		_place_key = key
		box.size = bs
		box.position = _place(bs, vs)

## Where the box goes: beside the hole (below, above, right, left) when it fits clear of it;
## otherwise wherever it covers least of the hole, nearest to it. Centred with no hole.
func _place(bs: Vector2, vs: Vector2) -> Vector2:
	var lo := Vector2(EDGE, EDGE)
	var hi := (vs - bs - Vector2(EDGE, EDGE)).max(lo)
	if not has_hole:
		box_side = ""
		return ((vs - bs) * 0.5).floor()
	var c := hole.get_center()
	var tries := [["below", Vector2(c.x - bs.x * 0.5, hole.end.y + GAP)], ["above", Vector2(c.x - bs.x * 0.5, hole.position.y - GAP - bs.y)],
		["right", Vector2(hole.end.x + GAP, c.y - bs.y * 0.5)], ["left", Vector2(hole.position.x - GAP - bs.x, c.y - bs.y * 0.5)]]
	var keep := hole.grow(GAP - 3.0)
	for tr in tries:
		var p: Vector2 = (tr[1] as Vector2).clamp(lo, hi).floor()
		if not Rect2(p, bs).intersects(keep):
			box_side = String(tr[0])
			return p
	# nowhere clear: the spot covering the least of what's highlighted (the lineup's cards, not
	# the room between them), then the closest
	var best := lo
	var best_score := INF
	var y := lo.y
	while y <= hi.y:
		var x := lo.x
		while x <= hi.x:
			var r := Rect2(Vector2(x, y), bs)
			var cover := 0.0
			for pr in parts_now:
				cover += r.intersection((pr as Rect2).grow(3.0)).get_area()
			var score := cover * 1000.0 + r.get_center().distance_to(c)
			if score < best_score:
				best_score = score
				best = Vector2(x, y)
			x += 6.0
		y += 6.0
	box_side = "over"
	return best.floor()

# ------------------------------------------------------------------ the frame and the arrow
## A down-pointing arrow, 7 x 7 at ARROW_PX ("#" gold, "o" ink outline), turned for the other sides.
const ARROW := ["..ooo..", "..o#o..", "ooo#ooo", "o#####o", ".o###o.", "..o#o..", "...o..."]

func _draw_deco() -> void:
	if not has_hole:
		return
	# a 2 px gold frame just outside the hole, its brightness pulsing (steady with REDUCE MOTION)
	var pulse := 0.75 + 0.25 * sin(t * 5.0) if Juice.enabled() else 1.0
	var col := Color(UI.GOLD, pulse)
	var f := hole.grow(2.0)
	for r in [Rect2(f.position, Vector2(f.size.x, 2)), Rect2(f.position.x, f.end.y - 2, f.size.x, 2),
			Rect2(f.position, Vector2(2, f.size.y)), Rect2(f.end.x - 2, f.position.y, 2, f.size.y)]:
		deco.draw_rect(r, col)
	deco.draw_rect(Rect2(f.grow(1.0).position, Vector2(f.size.x + 2, 1)), UI.INK)
	deco.draw_rect(Rect2(f.grow(1.0).position.x, f.end.y, f.size.x + 2, 1), UI.INK)
	# the arrow, in the gap on the box's side, pointing at the hole and bobbing toward it
	var bob := roundf(absf(sin(t * 6.0)) * 2.0) if Juice.enabled() else 0.0
	var side := box_side
	if side == "over" and box != null and hole.encloses(box.get_rect()):
		return   # (the box sits in the highlight itself, beside what it's about: no arrow)
	if side in ["", "over"]:
		side = "above" if hole.position.y > 18.0 else "below"
	var span := ARROW.size() * ARROW_PX
	var bx := clampf(box.get_rect().get_center().x if box != null else hole.get_center().x, hole.position.x + 8.0, maxf(hole.position.x + 8.0, hole.end.x - 8.0))
	var by := clampf(box.get_rect().get_center().y if box != null else hole.get_center().y, hole.position.y + 7.0, maxf(hole.position.y + 7.0, hole.end.y - 7.0))
	match side:
		"below":   # the box under the hole: the arrow points up
			_arrow(Vector2(floorf(bx - span * 0.5), f.end.y + 1 + bob), "up")
		"above":
			_arrow(Vector2(floorf(bx - span * 0.5), f.position.y - 1 - span - bob), "down")
		"right":
			_arrow(Vector2(f.end.x + 1 + bob, floorf(by - span * 0.5)), "left")
		"left":
			_arrow(Vector2(f.position.x - 1 - span - bob, floorf(by - span * 0.5)), "right")

func _arrow(at: Vector2, dir: String) -> void:
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
			deco.draw_rect(Rect2(at + p * ARROW_PX, Vector2(ARROW_PX, ARROW_PX)), UI.GOLD if ch == "#" else UI.INK)

# ------------------------------------------------------------------ what each step points at
## The target's rects on screen (global), from the live screen every frame: screens rebuild
## their nodes (a pick on Training), so nothing is kept. Empty: no hole (the box is centred).
func _rects(target: String) -> Array:
	var scr := Game.current_screen
	if scr == null or target == "":
		return []
	match target:
		"standings":
			var door := _find("HubDoor")
			return [] if door == null else _rect_of(door.get_parent().get_child(0))
		"schedule":
			var path := _find("SeasonPath")
			return [] if path == null else _rect_of(path.get_parent().get_parent())
		"hub_door":
			return _rect_of(_find("HubDoor")) + _rect_of(_find("HubTab"))
		"nav_roster", "nav_training", "nav_coaching":
			return _rect_of(_find("Nav_" + target.trim_prefix("nav_")))
		"back":
			var hl = scr.get("header_left")
			if hl is Node:
				for ch in (hl as Node).get_children():
					if ch is BaseButton and (ch as Control).visible:
						return _rect_of(ch)
			return []
		"dh_program":
			return _rect_of(_find("Card_program"))
		"dh_history":
			return _rect_of(_find("Card_news")) + _rect_of(_find("Card_team_trophies")) + _rect_of(_find("Card_records"))
		"dh_tools":
			return _rect_of(_find("Card_store")) + _rect_of(_find("Card_settings")) + _rect_of(_find("Card_visual_shop")) + _rect_of(_find("Card_recruiting"))
		"dh_all":
			return _rect_of(_find("Cards"))
		"r_starters":
			var out: Array = []
			for k in RosterScreen.SPOTS:
				out += _rect_of(_find("Spot_" + String(k)))
			return out
		"r_card":
			return _rect_of(_roster_card())
		"r_stars":
			var card := _roster_card()
			if card == null:
				return []
			var r := card.get_global_rect()
			# (his name and stars: the card's lower half down to the XP bar)
			return [Rect2(r.position + Vector2(2, RosterScreen.SPLIT + 1), Vector2(r.size.x - 4, RosterScreen.XP_Y - RosterScreen.SPLIT - 2))]
		"r_pos":
			var card := _roster_card()
			if card == null:
				return []
			var r := card.get_global_rect()
			return [Rect2(r.position - Vector2(0, RosterScreen.LABEL_H), Vector2(r.size.x, RosterScreen.LABEL_H + 12))]
		"r_xp":
			var card := _roster_card()
			if card == null:
				return []
			var r := card.get_global_rect()
			return [Rect2(r.position + Vector2(1, RosterScreen.XP_Y - 2), Vector2(r.size.x - 2, 5))]
		"t_focus", "t_intensity":
			var panels := _find("Panels")
			if panels == null or panels.get_child_count() < 2:
				return []
			return _rect_of(panels.get_child(0 if target == "t_focus" else 1))
		"t_recovery":
			var panels := _find("Panels")
			if panels == null:
				return []
			for b in panels.find_children("*", "Button", true, false):
				if (b as Button).text == Training.FOCI.recovery.name:
					return _rect_of(b)
			return []
		"t_summary":
			var sm := _find("Summary")
			return [] if sm == null or sm.get_child_count() == 0 else _rect_of(sm.get_child(0))
		"c_drops":
			var out: Array = []
			for f in DefenseFormation.DROPS:
				out += _rect_of(_find("Drop_%d" % f))
			return out + _rect_of(_find("DropText")) + _rect_of(_find("Playbook"))
		"c_scout":
			return _rect_of(_find("ScoutOpponent"))
		"c_open":
			return _rect_of(_find("OpenRecruiting"))
		"rc_cards":
			return _rect_of(_find("Cards"))
		"rc_signed":
			return _rect_of(_find("Signed"))
		"rc_refresh":
			return _rect_of(_find("Refresh"))
		"rc_first":
			var grid := _find("Cards")
			if grid != null:
				for ch in grid.get_children():
					if ch is BaseButton and (ch as Control).visible:
						return _rect_of(ch)
			return []
		"p_pin":
			return _rect_of(_find("Pin"))
	return []

func _find(nm: String) -> Control:
	var n := Game.current_screen.find_child(nm, true, false)
	return n as Control if n is Control and (n as Control).is_visible_in_tree() else null

func _rect_of(n: Node) -> Array:
	if n == null or not n is Control or not (n as Control).is_visible_in_tree():
		return []
	var r := (n as Control).get_global_rect()
	return [r] if r.size.x > 0.0 and r.size.y > 0.0 else []

## The roster card the roster steps point at: a field starter near the middle.
func _roster_card() -> Control:
	for k in ["Spot_cf", "Spot_pt", "Spot_lw", "Spot_lf", "Spot_rw", "Spot_rf"]:
		var n := _find(k)
		if n != null and n is BaseButton:
			return n
	return null

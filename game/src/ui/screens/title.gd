extends BaseScreen
## Title: a HIGHLIGHT REEL in the pool behind the logo (the Main Menu Polish update), and a short menu: CONTINUE
## (the career played last) and NEW CAREER (the five career slots; a new career opens with the
## tutorial), help and settings in the top corners.

const TITLE_Y := 104     # PIXEL POLO's baseline; WATER POLO DYNASTY sits under it
const MENU_Y := 136     # the top of CONTINUE
const MENU_W := 190
const EDGE := 6          # the corner icons' margin from the screen edges
const SUB_SIZE := 13     # WATER POLO DYNASTY: 20% under the 16 it was (the font is drawn unsmoothed: still sharp)

## THE HIGHLIGHT REEL: one bot-played attack after another, cut together like a highlights
## package, everything the game's own (Play, PlayBot, PoolArt):
##   - each scene a counterattack or a set attack between a new pair of teams (REEL_TEAMS), the
##     defence a little slow to read it (REEL_LEVEL) so the attacks get their looks, the attack
##     quick to move it (REEL_THINK, REEL_RELEASE)
##   - a shot: the game slows (SHOT_SLOW) while it flies, the camera punches in (SHOT_ZOOM), its
##     streak, the release ring and the net splash; a goal: a jolt and a soft flash
##   - no dead time: a scene that drags (MAX_SCENE) is cut, a finished one held a beat (HOLD)
##     and wiped (WIPE) into the next
## Under the logo's dim the whole time, so the menu reads as ever.
const REEL_TEAMS := 8
const REEL_LEVEL := 0.25
const REEL_THINK := 0.22
const REEL_RELEASE := 0.16
const COUNTER_SHARE := 0.5
const SHOT_SLOW := 0.42
const SHOT_ZOOM := 1.14
const MAX_SCENE := 9.0
const HOLD := 1.3
const WIPE := 0.35

var t := 0.0
var art: Control
var demo: Play
var view := PoolView.new()
var rng := RandomNumberGenerator.new()
var think := 0.0
var hold := 0.0
var plan := {}     # the demo's next throw: ball up first, then it goes
var demo_teams: Array = []
var scene_t := 0.0
var wipe := 0.0      # >0: the cut to the next scene under way (s left)
var flash := 0.0     # a goal's soft flash
var scored := false
var scene_no := 0

func _ready() -> void:
	theme = UI.theme
	rng.seed = 7
	_new_demo()
	art = UI.canvas(0, 0, _draw_art)
	art.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(art)
	var v := UI.vbox(3)
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(v)
	v.add_child(UI.spacer(0, MENU_Y))   # the title and WATER POLO are drawn above the menu
	var menu := UI.vbox(6)
	menu.custom_minimum_size = Vector2(MENU_W, 0)
	var cc := CenterContainer.new()
	cc.add_child(menu)
	v.add_child(cc)
	var cont := _big("CONTINUE", _continue, "primary")
	cont.disabled = not Game.has_save()
	menu.add_child(cont)
	menu.add_child(_big("NEW CAREER", _new_career, "normal"))
	for i in menu.get_child_count():
		Juice.enter(menu.get_child(i), i)
	var ins := safe_insets()
	# (help and gear placed by offsets from their corners, which hold in every LANGUAGE: a
	# position set before the button is on screen takes its direction from the language alone,
	# and in Arabic, Hebrew or Urdu would land mirrored, off the screen)
	var help := Deck.icon_button("help", func(): Game.goto("howto"), 26, 22)
	help.set_anchors_preset(Control.PRESET_TOP_LEFT)
	help.offset_left = EDGE + ins.x
	help.offset_top = EDGE + ins.y
	help.offset_right = help.offset_left + 26
	help.offset_bottom = help.offset_top + 22
	add_child(help)
	var gear := Deck.icon_button("gear", func(): Game.goto("settings"), 26, 22)
	gear.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	gear.offset_left = -26 - EDGE - 1 - ins.z   # 1 more for the drop shadow
	gear.offset_top = EDGE + ins.y
	gear.offset_right = gear.offset_left + 26
	gear.offset_bottom = gear.offset_top + 22
	add_child(gear)
	var ver := UI.label("v" + str(ProjectSettings.get_setting("application/config/version")), 8, UI.DIM)
	ver.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	ver.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ver.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	ver.offset_left = -20
	ver.offset_right = 20
	ver.offset_top = -13 - ins.w
	ver.offset_bottom = ver.offset_top + 9
	add_child(ver)
	Sfx.music("menu")
	Sfx.crowd(0.0)

func _big(text: String, cb: Callable, style: String) -> Button:
	var b := Deck.button(text, cb, style, MENU_W, 30)
	b.add_theme_font_override("font", UI.font_big)
	b.add_theme_font_size_override("font_size", 20)
	return b

func on_back() -> void:
	get_tree().quit()

## The career played most recently (it may already be in memory, back from its hub).
func _continue() -> void:
	var n := Game.last_slot()
	if n == 0:
		return
	if (Game.career == null or Game.slot != n) and not Game.load_career(n):
		Game.dialog("SAVE PROBLEM", "That career save couldn't be read. Pick another slot or start a new career.", [
			["CAREERS", func(): Game.goto("careers"), "primary"],
			["BACK", Callable(), "ghost"]])
		return
	Game.history.clear()
	Game.goto("game_summary" if not Game.career.last_summary.is_empty() else "hub")

func _new_career() -> void:
	Game.goto("careers")

## The next scene: a new pair of teams, a counter or a set attack.
func _new_demo() -> void:
	plan = {}
	scene_t = 0.0
	scored = false
	var a := scene_no % REEL_TEAMS
	var b := (a + 1 + rng.randi() % (REEL_TEAMS - 1)) % REEL_TEAMS
	scene_no += 1
	demo_teams = [League.make_team(a), League.make_team(b)]
	demo = Play.new(demo_teams[0], demo_teams[1], Play.Kind.COUNTER if rng.randf() < COUNTER_SHARE else Play.Kind.HALF_COURT, rng)
	demo.set_level(REEL_LEVEL)
	view.zoom_to = 1.0
	view.snap_to(PoolView.attack_focus(demo.ball.pos))

func _process(dt: float) -> void:
	t += dt
	view.width = get_viewport_rect().size.x
	view.height = get_viewport_rect().size.y
	flash = maxf(0.0, flash - dt)
	if wipe > 0.0:
		wipe -= dt
		if wipe <= WIPE * 0.5 and hold > 0.0:
			hold = 0.0
			_new_demo()   # (at the wipe's darkest)
		art.queue_redraw()
		return
	# a shot in the air: the reel slows and leans in
	var shooting := demo.ball.state == Ball.State.SHOT
	var sdt := dt * (SHOT_SLOW if shooting else 1.0)
	view.zoom_to = SHOT_ZOOM if shooting else 1.0
	scene_t += sdt
	think -= sdt
	if not plan.is_empty():
		plan.t -= sdt
		if plan.t <= 0.0:
			demo.throw(plan.target, plan.power)
			plan = {}
	elif think <= 0.0:
		think = REEL_THINK
		var d := PlayBot.think(demo, rng)
		if not d.is_empty():
			demo.raise_ball(true)
			plan = {"target": d.target, "power": d.power, "t": REEL_RELEASE}
	demo.step(sdt)
	view.follow(PoolView.attack_focus(demo.ball.pos), dt)
	if not scored and String(demo.result.get("outcome", "")) == "goal":
		scored = true
		view.shake = maxf(view.shake, 0.6)
		flash = 0.18
	if demo.over or scene_t > MAX_SCENE:
		hold += dt
		if hold > (HOLD if demo.over else 0.01):
			wipe = WIPE   # cut to the next scene
	art.queue_redraw()

func _draw_art(ci: Control) -> void:
	var sz := ci.get_viewport_rect().size
	PoolArt.draw_pool(ci, view, t, sz, 0.0)
	var bodies := demo.bodies()
	bodies.sort_custom(func(a: Swimmer, b: Swimmer): return a.pos.y < b.pos.y)
	for s in bodies:
		var cap: Color = PoolArt.CAP_KEEPER if s.keeper else (Color("f2f2e9") if s.side == Swimmer.Side.US else demo_teams[1].c1)
		PoolArt.draw_body(ci, view, s, cap, demo_teams[0].c1 if s.side == Swimmer.Side.US else demo_teams[1].c2)
	PoolArt.draw_release_ring(ci, view, demo.release_by, demo.release_t)
	PoolArt.draw_shot_power(ci, view, demo.ball)
	PoolArt.draw_shot_fx(ci, view, demo.ball)
	PoolArt.draw_ball(ci, view, demo.ball)
	PoolArt.draw_net_splash(ci, view, demo.ball)
	if flash > 0.0:
		ci.draw_rect(Rect2(Vector2.ZERO, sz), Color(1, 1, 1, 0.5 * flash))
	ci.draw_rect(Rect2(Vector2.ZERO, sz), Color(UI.BG2, 0.4))
	if wipe > 0.0:
		# the cut: dark in, dark out
		var k := 1.0 - absf(wipe / WIPE * 2.0 - 1.0)
		ci.draw_rect(Rect2(Vector2.ZERO, sz), Color(UI.INK, 0.85 * k))
	var title := Game.TITLE.to_upper()
	for d in [Vector2(-2, 0), Vector2(2, 0), Vector2(0, -2), Vector2(0, 3), Vector2(2, 3), Vector2(-2, 3)]:
		UI.text(ci, Vector2(0, TITLE_Y) + d, title, 60, UI.INK, "big", HORIZONTAL_ALIGNMENT_CENTER, sz.x)
	UI.text(ci, Vector2(0, TITLE_Y), title, 60, UI.GOLD, "big", HORIZONTAL_ALIGNMENT_CENTER, sz.x)
	UI.text(ci, Vector2(0, TITLE_Y - 2), title, 60, Color("ffe37a"), "big", HORIZONTAL_ALIGNMENT_CENTER, sz.x)
	# the subtitle, part of the logo: the menu's caps pixel type at twice its size (whole pixels:
	# sharp), white on the logo's ink. (Not the big type: it draws an A after an N lower case.)
	var sub := Game.SUBTITLE.to_upper()
	for d in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(1, 1)]:
		UI.text(ci, Vector2(0, TITLE_Y + 15) + d, sub, SUB_SIZE, UI.INK, "caps", HORIZONTAL_ALIGNMENT_CENTER, sz.x)
	UI.text(ci, Vector2(0, TITLE_Y + 15), sub, SUB_SIZE, UI.TEXT, "caps", HORIZONTAL_ALIGNMENT_CENTER, sz.x)

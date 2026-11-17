extends "res://src/ui/screens/play_lab.gd"
## Developer Mode's COUNTERATTACK CURL TEST (Settings > Developer Mode): the counter's chain-reaction
## rotation (CounterCurl) in a real possession, swum by exactly the code a match swims it with: the
## men down the pool first take the deep spots for teammates still coming, and each is moved on to
## his next spot by the teammate coming in for his, until it's the 6 on 6. Your six are back at your
## own end where they've just stopped an attack, your keeper has the ball, and START COUNTERATTACK
## gives it to the outlet man and puts the possession in the counter state PlaySetup._counter
## leaves a real one in (Play.kind COUNTER, Play.carry). That forcing is this lab's alone: nothing
## in a match ever calls it, so it can't change how often a match has a counter.
##   START COUNTERATTACK   the outlet, and the counter's on
##   RESET TEST            everybody back where they started, the ball back with your keeper
##   REVERSE DIRECTION     the other way: their counter, at your goal (drawn attacking left)
##   REPEAT TEST           ON: each run resets and starts again once the attack's set
##   SHOW PATHS            what's happening now (_draw_paths): sprints, held spots, where each man's
##                         going, the rotations under way and the ones waiting, the final formation
##   SHOW PLAYER STATES    each man's state, and down the left why ("PLAYER 3: ROTATING TO POSITION 4 -
##                         PLAYER 5 APPROACHING") and who's on each spot (* held for its owner)
## You can still pass and shoot on your own counter (tap / the stick, as in a match): the rotation
## gives way to the ball. Nothing is counted (play_lab).

const SEED := 21
const LEAVE := 1.6             # m your men have got away from theirs (they turned first)
const OUTLET_X := 10.0         # where the outlet man takes the keeper's pass
const SETTLE_HOLD := 1.6       # s the set attack stays up before REPEAT goes again
const RUN_MAX := 22.0          # s a run is watched at most
## A colour each, by spot: the paths and the labels.
const COLS := {"C": Color("ffd23f"), "1": Color("ff6b6b"), "2": Color("ff9f43"), "3": Color("7bed9f"),
	"4": Color("54a0ff"), "5": Color("c56cf0")}

var reversed := false
var repeat := false
var show_paths := true
var show_states := true
var phase := "ready"           # ready (the keeper has it), running, set (the attack's set up)
var run_t := 0.0
var set_t := 0.0
var gk: Swimmer = null         # your keeper (art only: a match's possession has only theirs in it)
var gk_ball := Ball.new()
var events: Array = []         # the rotations this run (CounterCurl's log: rotate, peel, release)
var seen_states := {}          # Swimmer -> the states he's been through this run
var runs := 0
var btn := {}

func _ready() -> void:
	lab_ready("COUNTERATTACK CURL TEST")
	var row := UI.hbox(3)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	body.add_child(row)
	btn.start = UI.button("START COUNTERATTACK", start_counter, "normal", 112, 18)
	btn.reset = UI.button("RESET TEST", reset_test, "ghost", 70, 18)
	btn.reverse = UI.button("REVERSE DIRECTION", reverse, "ghost", 100, 18)
	btn.repeat = UI.button("REPEAT TEST: OFF", toggle_repeat, "ghost", 100, 18)
	for k in ["start", "reset", "reverse", "repeat"]:
		btn[k].name = "Curl" + String(k).capitalize()
		row.add_child(btn[k])
	var row2 := UI.hbox(3)
	row2.alignment = BoxContainer.ALIGNMENT_CENTER
	body.add_child(row2)
	btn.paths = UI.button("SHOW PATHS: ON", toggle_paths, "ghost", 96, 18)
	btn.states = UI.button("SHOW PLAYER STATES: ON", toggle_states, "ghost", 128, 18)
	btn.pause = UI.button("PAUSE", toggle_pause, "ghost", 60, 18)
	for k in ["paths", "states", "pause"]:
		btn[k].name = "Curl" + String(k).capitalize()
		row2.add_child(btn[k])
	reset_test.call_deferred()

# ------------------------------------------------------------------ the controls
## Everybody back at your own end, the ball with your keeper. Nothing moves until START.
func reset_test() -> void:
	new_play(Play.Kind.HALF_COURT, SEED)
	aims = not reversed   # (their counter: you can't throw for them)
	play.defending = reversed
	view.mirror = reversed
	events.clear()
	seen_states.clear()
	run_t = 0.0
	set_t = 0.0
	_layout()
	phase = "ready"
	paused = true
	view.snap_to(_ready_focus())
	_pause_text()
	status = "READY: %s HAS IT. START COUNTERATTACK" % ("THEIR KEEPER" if reversed else "YOUR KEEPER")

## Where everybody is as the keeper gathers it: the attack they've just stopped, at this end
## (their men on their spots in the umbrella, turned round into this possession's frame), and the
## new attack's six goal side of them, already turned and LEAVE up the pool (no dice: the same
## every time).
func _layout() -> void:
	for i in play.attackers.size():
		var a := play.attackers[i]
		var d := play.defenders[i]
		var spot: Vector2 = PlaySetup.HOME_6V6[a.tag]
		var theirs := Vector2(Geo.LENGTH - spot.x, spot.y)
		d.pos = theirs
		d.vel = Vector2.ZERO
		d.mark = a
		a.pos = theirs + Vector2(LEAVE, 0.4 if a.pos.y < Geo.GOAL_Y else -0.4)
		a.vel = Vector2.ZERO
		a.facing = 1.0
		d.facing = 1.0
	var outlet := _outlet()
	outlet.pos = Vector2(OUTLET_X - 2.0, outlet.pos.y)
	play.holder = null
	play.keeper.pos = Vector2(Geo.KEEPER_X, Geo.GOAL_Y)
	for s in play.bodies():
		s.target = s.pos
	gk = Swimmer.new(PlaySetup.seven(play.us)[0], Swimmer.Side.US, true)
	gk.pos = Vector2(0.6, Geo.GOAL_Y)
	gk.facing = 1.0
	gk.arm = 1.0
	gk_ball = Ball.new()
	gk_ball.put(Play.held_at(gk))
	play.ball.put(Play.held_at(gk))

## The outlet man: the point (the first man up the pool off a save).
func _outlet() -> Swimmer:
	return PlaySetup._by_tag(play, "3")

## START COUNTERATTACK: the keeper's outlet, and the counter state, as PlaySetup._counter leaves a
## real one (DEVELOPER MODE ONLY: a match never calls this).
func start_counter() -> void:
	if phase != "ready":
		reset_test()
	var o := _outlet()
	o.pos.x = OUTLET_X
	play.give_ball(o)
	for a in play.attackers:
		a.vel = Vector2(a.top_speed * PlaySetup.BREAK_SWIM * 0.6, 0.0)   # (turned and away)
	force_counter(play)
	phase = "running"
	paused = false
	_pause_text()
	runs += 1
	banner.show("COUNTERATTACK!", EventBanner.YELLOW)

## The counter state, exactly the flags PlaySetup._counter sets on a real break.
static func force_counter(p: Play) -> void:
	p.kind = Play.Kind.COUNTER
	p.carry = true
	p.counter_t = 5.0
	p._hold_ball()
	p.break_n = p.break_numbers()
	PlayAI.counter_marks(p)
	PlayAI.assign_lanes(p)

func reverse() -> void:
	reversed = not reversed
	reset_test()

func toggle_repeat() -> void:
	repeat = not repeat
	btn.repeat.text = "REPEAT TEST: %s" % ("ON" if repeat else "OFF")
	if repeat and phase == "ready":
		start_counter()

func toggle_paths() -> void:
	show_paths = not show_paths
	btn.paths.text = "SHOW PATHS: %s" % ("ON" if show_paths else "OFF")

func toggle_states() -> void:
	show_states = not show_states
	btn.states.text = "SHOW PLAYER STATES: %s" % ("ON" if show_states else "OFF")

func toggle_pause() -> void:
	if phase == "ready":
		return
	paused = not paused
	_pause_text()

func _pause_text() -> void:
	if btn.has("pause"):
		btn.pause.text = "RESUME" if paused and phase != "ready" else "PAUSE"


# ------------------------------------------------------------------ the run
func lab_tick(dt: float) -> void:
	if play == null:
		return
	if phase == "ready":
		gk_ball.put(Play.held_at(gk))
		play.ball.put(Play.held_at(gk))
		return
	var R: CounterCurl.Rotation = play.rot
	for a in play.attackers:
		if not seen_states.has(a):
			seen_states[a] = {}
		seen_states[a][CounterCurl.state_of(play, a)] = true
	if R != null:
		for e: Dictionary in R.log:
			if e.k in ["rotate", "peel", "release"] and not events.has(e):
				events.append(e)
	if not paused:
		run_t += dt
	var moving := R.agents.size() if R != null else 0
	if phase == "running":
		var finished := play.over or run_t > RUN_MAX or (play.curl_mode == CounterCurl.Mode.FINISHED and not play.carry)
		if finished:
			phase = "set"
			set_t = 0.0
	elif phase == "set" and not paused:
		set_t += dt
		if repeat and set_t >= SETTLE_HOLD and end_t < 0.0:
			start_counter()
			return
	status = "%s  |  COUNTER %s  |  %.1f s  |  %d ROTATIONS  |  %s" % [
		"ATTACKING LEFT (THEIRS)" if reversed else "ATTACKING RIGHT (YOURS)",
		"ON" if play.carry else "OVER", run_t, events.size(),
		("FORMATION READY: 1 CENTRE + 5 PERIMETER" if phase == "set" else "%d MOVING  RUN %d" % [moving, runs])]

## A result (a goal, a steal) holds, then the lab waits for the next run.
func settled() -> void:
	if phase != "ready":
		phase = "set"

func focus() -> Vector2:
	return _ready_focus() if phase == "ready" else view.attack_frame(play)

func _ready_focus() -> Vector2:
	return Vector2(7.0, Geo.GOAL_Y)

# ------------------------------------------------------------------ drawing
func lab_draw(ci: Control) -> void:
	if play == null:
		return
	if gk != null and (phase == "ready" or gk.pos.distance_to(play.ball.pos) > 0.5):
		PoolArt.draw_body(ci, view, gk, PoolArt.CAP_KEEPER, play.us.c1)
		if phase == "ready":
			PoolArt.draw_ball(ci, view, gk_ball)
	if show_paths:
		_draw_paths(ci)
	if show_states:
		_draw_states(ci)

## Only what's happening now, laid out again the moment a rotation starts:
##   the final formation      every spot, a small hollow box in its owner's colour
##   occupied spots           a filled box in the colour of the man on it (white edge: held for its owner)
##   sprints                  a thin line, from the man to where he's going (a hollow diamond there)
##   active rotations         a thick line
##   pending rotations        dotted, from a man holding a spot to where he'll go when he's moved on
## A man in the break's lanes: a thin line to where he's going.
func _draw_paths(ci: Control) -> void:
	var R: CounterCurl.Rotation = play.rot
	for a in play.attackers:
		if not a.out:
			_box(ci, view.to_screen(a.home), Color(COLS.get(a.tag, Color.WHITE), 0.5), 2)
	if R == null:
		return
	var own := CounterCurl.owners(play)
	for k: String in own.keys():
		var s: Swimmer = own[k][0]
		var at := view.to_screen(R.spots[k])
		ci.draw_rect(Rect2(at.x - 3, at.y - 3, 7, 7), COLS.get(s.tag, Color.WHITE))
		if own[k][1]:
			_box(ci, at, Color.WHITE, 4)
	for a: Swimmer in R.agents.keys():
		var ag: CounterCurl.Agent = R.agents[a]
		var col: Color = COLS.get(a.tag, Color.WHITE)
		if ag.at != "":
			var nxt := CounterCurl.next_for(play, a)
			if nxt != "":
				_dots(ci, view.to_screen(a.pos), view.to_screen(R.spots[nxt]), col)
			continue
		var rt := ag.route
		if rt == null:
			continue
		var w := 2.0 if rt.rotation else 1.0
		var from := maxi(rt.k, 0)
		for i in range(from, rt.pts.size() - 1):
			ci.draw_line(view.to_screen(rt.pts[i]), view.to_screen(rt.pts[i + 1]), Color(col, 0.95 if rt.rotation else 0.7), w)
		var tp := view.to_screen(rt.end())
		ci.draw_polyline(PackedVector2Array([tp + Vector2(0, -4), tp + Vector2(4, 0), tp + Vector2(0, 4), tp + Vector2(-4, 0), tp + Vector2(0, -4)]), col, 1.0)
	if play.carry:
		for a in play.attackers:
			if not a.out and a != play.holder and not R.agents.has(a) and play.lanes.has(a):
				ci.draw_line(view.to_screen(a.pos), view.to_screen(a.target), Color(COLS.get(a.tag, Color.WHITE), 0.6), 1.0)

func _box(ci: Control, at: Vector2, col: Color, h: int) -> void:
	ci.draw_rect(Rect2(at.x - h, at.y - h, h * 2 + 1, h * 2 + 1), col, false, 1.0)

func _dots(ci: Control, a: Vector2, b: Vector2, col: Color) -> void:
	var n := int(a.distance_to(b) / 5.0)
	for i in range(0, n + 1, 2):
		ci.draw_line(a.lerp(b, float(i) / maxf(n, 1)), a.lerp(b, minf(float(i + 1) / maxf(n, 1), 1.0)), Color(col, 0.8), 1.0)

## Each man's state over his head; down the left, each man's state and why (ROTATION DEBUGGING), and
## who's on each spot.
func _draw_states(ci: Control) -> void:
	for a in play.attackers:
		if a.out:
			continue
		var st := CounterCurl.state_of(play, a)
		var txt := "%s %s" % [a.tag, CounterCurl.SHORT.get(st, st)]
		UI.text_shadow(ci, view.to_screen(a.pos) + Vector2(-12, -24), txt, 8, COLS.get(a.tag, Color.WHITE), "caps")
	if play.rot == null:
		return
	ci.draw_rect(Rect2(0, PoolView.HUD_H - 22, 236, 8 * 9 + 4), Color(UI.INK, 0.6))
	var y := PoolView.HUD_H - 14
	var line := "ON THE SPOTS: "
	var own := CounterCurl.owners(play)
	for k in ["C", "1", "2", "3", "4", "5"]:
		line += "%s=%s  " % ["2M" if k == "C" else k, (String((own[k][0] as Swimmer).tag) + ("*" if own[k][1] else "")) if own.has(k) else "-"]
	UI.text(ci, Vector2(3, y), line, 8, UI.TEXT, "body")
	for a in play.attackers:
		y += 9
		# in the rotation: why he's doing what he's doing; otherwise what he's doing
		var line2 := CounterCurl.reason_of(play, a) if (play.rot as CounterCurl.Rotation).agents.has(a) else CounterCurl.state_of(play, a)
		UI.text(ci, Vector2(3, y), "PLAYER %s: %s" % [a.tag, line2], 8, COLS.get(a.tag, Color.WHITE), "body")

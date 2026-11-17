extends BaseScreen
## Developer Mode's SHOT & TEMPO TEST (Settings > Developer Mode): player quality in the pool,
## without playing a game (TempoBench measures it with the game's own code, Tempo holds the
## numbers). Pick a TEAM RATING (every player on the team rated that) and a SHOOTER rating, then:
##   TEST SHOT: the same shooter's shot on every team rating, raced side by side on the pool, with
##     each one's speed and travel time: all the same, since only the shooter sets the pace.
##   TEST PASSING: their attack plays a few possessions at the chosen rating (the AI on the ball,
##     the bot in goal): passes, the time between them, their pace, the time to the shot. Each
##     rating tried stays in the table to compare.
##   WIDE vs ON TARGET: two shots with the same power, one in, one wide, side by side. The dots
##     mark every 0.05 s of each flight: the same spacing is the same speed.
## Nothing here is a real team or player: no career, save or rating changes.

const RATINGS := [50, 65, 75, 85, 95, 100]
const SHOOTERS := [40, 55, 70, 85, 95]
const POOL := Vector2(150, 150)
const SCALE := 16.0                 # px a metre
const VIEW_AT := Vector2(21.6, 5.3)  # the pool metre at the canvas's top left
const CELL := 40                    # a read-out column
const DOT_EVERY := 0.05
const HOLD := 0.9                   # the balls sit where they stopped this long before it replays

var team_rating := 75
var shooter := 70
var mode := ""                      # "shot", "pass", "wide"
var balls: Array = []               # {from, to, dur, lead, col, tag}
var lines: Array = []               # the read-out, [text, colour]: tabs split it into columns
var passing := {}                   # rating -> TempoBench.possessions
var anim_t := 0.0
var anim_speed := 1.0
var pool: Control
var controls: VBoxContainer
var readout: VBoxContainer

func _ready() -> void:
	build("SHOT & TEMPO TEST")
	var row := UI.hbox(6)
	body.add_child(row)
	controls = UI.vbox(3)
	controls.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(controls)
	pool = UI.canvas(int(POOL.x), int(POOL.y), _draw_pool)
	row.add_child(pool)
	_controls()

func on_back() -> void:
	Sfx.play("back")
	Game.back("dev_settings")

func _process(dt: float) -> void:
	if balls.is_empty():
		return
	anim_t += dt * anim_speed
	if anim_t > _longest() + HOLD:
		anim_t = 0.0
	pool.queue_redraw()

func _longest() -> float:
	var m := 0.0
	for b in balls:
		m = maxf(m, float(b.dur))
	return m

# ------------------------------------------------------------------ the tests
## The same shot by every team rating, on parallel lanes across the goal mouth (the same 7 m each).
func test_shot() -> void:
	mode = "shot"
	balls.clear()
	lines = [["SHOOTER %d, POWER %d%%, FROM 7 M" % [shooter, roundi(TempoBench.SHOT_POWER * 100)], UI.ACCENT],
		["TEAM\tSPEED\tTO LINE\tSHOOTER x", UI.ACCENT]]
	for i in RATINGS.size():
		var y := Geo.GOAL_Y - 1.25 + i * 0.5
		var r := TempoBench.shot(RATINGS[i], shooter, y, Vector2(Geo.GOAL_X - 7.0, y))
		var on: bool = RATINGS[i] == team_rating
		balls.append({"from": r.from, "to": r.to, "dur": r.dur, "col": UI.GOLD if on else UI.DIM2, "tag": str(RATINGS[i])})
		lines.append(["%d\t%.1f M/S\t%.2f S\t%.2f" % [RATINGS[i], r.speed, r.line_t, r.shooter_k],
			UI.GOLD if on else UI.TEXT])
	_restart()

## Their attack at the chosen rating, a few possessions of it.
func test_passing() -> void:
	mode = "pass"
	balls.clear()
	passing[team_rating] = TempoBench.possessions(team_rating, 6, 11)
	lines = [["TEAM\tPASSES\tGAP\tPACE\tTO SHOT", UI.ACCENT]]
	var keys := passing.keys()
	keys.sort()
	for k in keys:
		var r: Dictionary = passing[k]
		lines.append(["%d\t%.1f\t%.2f S\t%.1f M/S\t%.1f S" % [k, r.passes, r.gap, r.pass_speed, r.to_shot],
			UI.GOLD if k == team_rating else UI.TEXT])
	lines.append(["(6 possessions each, average; decisions x%.2f)" % float(passing[team_rating].think), UI.DIM])
	pool.queue_redraw()
	_controls()

## Two shots with the same power from the same spot: one in the far corner, one wide of the post.
func test_wide() -> void:
	mode = "wide"
	balls.clear()
	var on := TempoBench.shot(team_rating, shooter, Geo.GOAL_Y + 1.1)
	var wide := TempoBench.shot(team_rating, shooter, Geo.GOAL_Y + Geo.GOAL_HALF + 0.9)
	balls.append({"from": on.from, "to": on.to, "dur": on.dur, "col": UI.GOLD, "tag": "IN"})
	balls.append({"from": wide.from, "to": wide.to, "dur": wide.dur, "col": UI.ACCENT, "tag": "WIDE"})
	var same := is_equal_approx(float(on.speed), float(wide.speed)) and absf(float(on.drawn_speed) - float(wide.drawn_speed)) < 0.01
	lines = [["TEAM %d, SHOOTER %d, SAME POWER" % [team_rating, shooter], UI.ACCENT],
		["SHOT\tENDS\tSPEED\tTIME\tDISTANCE", UI.ACCENT],
		["IN\t%s\t%.2f M/S\t%.2f S\t%.1f M" % [String(on.outcome).to_upper(), on.drawn_speed, on.flight, on.dist], UI.GOLD],
		["WIDE\t%s\t%.2f M/S\t%.2f S\t%.1f M" % [String(wide.outcome).to_upper(), wide.drawn_speed, wide.flight, wide.dist], UI.ACCENT],
		["SAME SPEED: THE WIDE ONE JUST GOES FURTHER" if same else "SPEEDS DIFFER!", UI.TEXT if same else Color("ff4545")]]
	_restart()

func _restart() -> void:
	anim_t = 0.0
	pool.queue_redraw()
	_controls()

# ------------------------------------------------------------------ the controls
func _controls() -> void:
	for ch in controls.get_children():
		ch.queue_free()
	var tr := _labelled("TEAM RATING")
	for v in RATINGS:
		var r: int = v
		tr.add_child(UI.button(str(r), func():
			team_rating = r
			_rerun(), "tab_on" if r == team_rating else "tab", 22, 16))
	var sr := _labelled("SHOOTER")
	for v in SHOOTERS:
		var s: int = v
		sr.add_child(UI.button(str(s), func():
			shooter = s
			_rerun(), "tab_on" if s == shooter else "tab", 22, 16))
	var tests := UI.hbox(3)
	controls.add_child(tests)
	tests.add_child(UI.button("TEST SHOT", test_shot, "primary" if mode == "shot" else "normal", 0, 18))
	tests.add_child(UI.button("TEST PASSING", test_passing, "primary" if mode == "pass" else "normal", 0, 18))
	tests.add_child(UI.button("WIDE vs IN", test_wide, "primary" if mode == "wide" else "normal", 0, 18))
	var sp := _labelled("PLAYBACK")
	for v in [0.25, 0.5, 1.0]:
		var f: float = v
		sp.add_child(UI.button("%sx" % str(f), func():
			anim_speed = f
			_controls(), "tab_on" if is_equal_approx(anim_speed, f) else "tab", 30, 16))
	sp.add_child(UI.button("REPLAY", func(): anim_t = 0.0, "ghost", 44, 16))
	readout = UI.vbox(0)
	controls.add_child(readout)
	if lines.is_empty():
		readout.add_child(para("Pick a team and a shooter, then run a test. Test teams only: no saves or players change.", UI.DIM, 250))
	for l in lines:
		var cells := String(l[0]).split("\t")
		if cells.size() == 1:
			readout.add_child(UI.label(cells[0], 8, l[1], "body"))
			continue
		var row := UI.hbox(0)
		readout.add_child(row)
		for c in cells:
			var cl := UI.label(c, 8, l[1], "body")
			cl.custom_minimum_size = Vector2(CELL, 0)
			row.add_child(cl)

## A rating changed: run the test that's showing again with it (passing only when asked: it's slower).
func _rerun() -> void:
	match mode:
		"shot":
			test_shot()
		"wide":
			test_wide()
		_:
			_controls()

func _labelled(text: String) -> HBoxContainer:
	var h := UI.hbox(2)
	controls.add_child(h)
	var l := UI.label(text, 8, UI.ACCENT, "caps")
	l.custom_minimum_size = Vector2(64, 0)
	h.add_child(l)
	return h

# ------------------------------------------------------------------ the pool
func _px(m: Vector2) -> Vector2:
	return (m - VIEW_AT) * SCALE

func _draw_pool(ci: Control) -> void:
	ci.draw_rect(Rect2(Vector2.ZERO, POOL), Color("1d5fd1"))
	for x in [Geo.SIX_M, Geo.FIVE_M, Geo.TWO_M]:
		ci.draw_line(_px(Vector2(x, VIEW_AT.y)), _px(Vector2(x, VIEW_AT.y + POOL.y / SCALE)), Color(1, 1, 1, 0.25))
	ci.draw_line(_px(Vector2(Geo.GOAL_X, VIEW_AT.y)), _px(Vector2(Geo.GOAL_X, VIEW_AT.y + POOL.y / SCALE)), Color(1, 1, 1, 0.6))
	var top := _px(Vector2(Geo.GOAL_X, Geo.GOAL_Y - Geo.GOAL_HALF))
	var bot := _px(Vector2(Geo.GOAL_X + Geo.NET_DEPTH, Geo.GOAL_Y + Geo.GOAL_HALF))
	ci.draw_rect(Rect2(top, bot - top), Color(1, 1, 1, 0.18))
	ci.draw_rect(Rect2(top, bot - top), Color.WHITE, false)
	ci.draw_circle(_px(Vector2(Geo.KEEPER_X, Geo.GOAL_Y)), 3.0, Color("ff4545"))
	Deck.text(ci, 3, 6, "SHOT LAB", 8, UI.DIM)
	if mode == "pass":
		Deck.text(ci, 3, POOL.y - 8, "SEE THE TABLE", 8, UI.DIM)
	for b in balls:
		var from: Vector2 = b.from
		var to: Vector2 = b.to
		var dur := float(b.dur)
		var col: Color = b.col
		ci.draw_line(_px(from), _px(to), Color(col, 0.25))
		var k := 0.0
		while k <= minf(anim_t, dur):
			ci.draw_circle(_px(from.lerp(to, k / dur)), 1.0, Color(col, 0.7))
			k += DOT_EVERY
		ci.draw_circle(_px(from.lerp(to, clampf(anim_t / dur, 0.0, 1.0))), 2.5, col)
		if mode == "shot":
			Deck.text(ci, 2, _px(from).y, String(b.tag), 8, col)
	if mode == "wide":
		for i in balls.size():
			Deck.text(ci, 3 + i * 40, POOL.y - 8, String(balls[i].tag), 8, balls[i].col)

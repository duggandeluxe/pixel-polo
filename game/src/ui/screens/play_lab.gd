extends BaseScreen
## Developer Mode's labs in the water (SPECIAL GOAL EFFECTS: fx_lab, DEFENSIVE TESTING: defense_lab):
## a real possession (Play) between two made-up teams, run and drawn the way the match screen runs
## and draws one, with the real BarHit and GoalShow over it. Nothing is ever counted: the teams are
## made here (League.make_team), the show reads a scratch MatchState nobody adds to, and no career,
## record, standing, statistic or save is touched. Leaving the lab throws it all away.

const US_CAP := Color("f2f2e9")
const SLOWMO := 0.6            # the pool slows while you aim (as in a match)
const HOLD := 1.4              # s a result stays up before the lab settles again

var us: PoloTeam
var them: PoloTeam
var rng := RandomNumberGenerator.new()
var play: Play = null
var view := PoolView.new()
var bar_show := BarHit.new()
var goal_show := GoalShow.new()
var goal_fx := GoalFx.new()       # the Goal Celebrations level (none but Level 1 unless a lab asks)
var banner := EventBanner.new()
var scratch := MatchState.new()   # (GoalShow reads the score off it; nothing's ever added)
var aim := AimGuide.new()
var stick := ShotStick.new()   # (as in a match: the only way to shoot)
var stage_cv: Control
var t := 0.0
var paused := false
var end_t := -1.0              # s until the lab settles after a result (-1: nothing pending)
var status := ""
var aims := false              # this lab lets you aim, shoot and pass (DEFENSIVE TESTING)
var goals_shown := 0           # GOAL! shows played (tests: one a preview)

func lab_ready(title: String) -> void:
	build(title)
	us = League.make_team(2, 1)
	them = League.make_team(3, 1)
	stage_cv = UI.canvas(0, 0, _draw_stage)
	stage_cv.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stage_cv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stage_cv.clip_contents = true
	body.add_child(stage_cv)

func on_back() -> void:
	Sfx.play("back")
	Game.back("settings")

## Your attack, a fresh possession: `kind` (a counter, the half court), the same every time.
func new_play(kind: int = Play.Kind.HALF_COURT, seed_v: int = 7) -> Play:
	rng.seed = seed_v
	_end_show()
	banner.clear()
	aim.cancel()
	play = Play.new(us, them, kind, rng)
	play.bar_fx = true
	play.bar_mode = BarHit.override
	end_t = -1.0
	view.width = maxf(stage_cv.size.x, 120.0)
	view.height = maxf(stage_cv.size.y, 80.0)
	view.zoom_to = 1.0
	view.zoom = 1.0
	view.snap_to(view.attack_frame(play))
	return play

## The lab's back to waiting for the next test (fx_lab, defense_lab say what that looks like).
func settled() -> void:
	pass

func _process(dt: float) -> void:
	t += dt
	view.width = maxf(stage_cv.size.x, 120.0)
	view.height = maxf(stage_cv.size.y, 80.0)
	if play != null and not paused:
		var k := goal_show.time_scale() * bar_show.play_scale()
		if aims:
			if aim.active and aim.stick and play.can_throw():
				k *= SLOWMO
			if aim.stick and aim.index != -99 and play.holder != null and play.holder.side == Swimmer.Side.US:
				aim.stick_at(play.holder, ShotStick.target(play.holder.pos, stick.knob))
			play.raise_ball(aim.active and aim.stick and aim.long_enough() and play.can_throw() and play.shooting_pull(aim.target(play.holder)))
		play.step(dt * k)
		_events()
		if goal_show.active():
			view.zoom_to = goal_show.zoom()
			view.follow(goal_show.focus(), dt)
		else:
			view.follow(focus(), dt)
	stick.layout(Vector2(view.width, view.height), Vector2.ZERO)
	stick.step(dt, aims and play != null and play.can_throw() and not play.over, aim.stick and aim.index != -99)
	banner.step(dt)
	goal_show.step(dt, view)
	goal_fx.tick(view)
	bar_show.step(dt)
	if end_t >= 0.0:
		end_t -= dt
		if end_t < 0.0:
			_end_show()
			settled()
	lab_tick(dt)
	stage_cv.queue_redraw()

## A frame of the lab's own (the status line).
func lab_tick(_dt: float) -> void:
	pass

## The play's events as the match screen takes them: the sounds, the callouts, the end.
func _events() -> void:
	for e in play.events:
		match String(e.k):
			"shot":
				Sfx.play("splash")
			"block":
				Sfx.play("turn")
				banner.event("block")
			"foul":
				Sfx.play("whistle", 1.15, -5.0)
				banner.event("foul")
			"net":
				Sfx.play("splash", 0.7, 1.5)
				Sfx.play("touch", 0.8, -3.0)
				view.shake = maxf(view.shake, 0.6)
			"end":
				_on_end(String(e.outcome))
	play.events.clear()

func _on_end(outcome: String) -> void:
	end_t = HOLD
	match outcome:
		"goal":
			_goal()
			end_t = goal_show.total()
		"penalty":
			banner.event("penalty")
			Sfx.play("whistle")
		"save":
			banner.event("save")
		"miss":
			banner.show("WIDE!")
		"steal", "turnover":
			banner.event("steal")
		_:
			banner.show(String(play.result.get("text", outcome.to_upper())))

## The goal's show, exactly the match screen's (MatchScreen._play_goal): off the frame first if
## that's how it went in, then GOAL!. Nothing is counted.
func _goal() -> void:
	var pre := 0.0
	if play.ball.bar_on() and play.ball.in_net():
		bar_show.start(play.ball, view)
		pre = BarHit.PRE
	var who: PoloPlayer = play.result.get("scorer")
	goal_show.start(0, who, scratch, Colleges.short_name(us).to_upper(), US_CAP, Vector2(Geo.GOAL_X, play.ball.pos.y), false, pre)
	goal_show.cast(play.ball.shooter, play.attackers, play.keeper)
	goal_fx.start(lab_goal_level(), goal_show, us.c1, us.c2, fire_still())
	lab_goal(who)
	goals_shown += 1

func _end_show() -> void:
	goal_fx.clear()
	bar_show.clear()
	if goal_show.active():
		goal_show.clear()
	view.zoom_to = 1.0
	view.zoom = 1.0

# ------------------------------------------------------------------ touches (aims only)
## As in a match: a touch that comes down on the shooting stick is a shot's; anywhere else, a tap
## to pass, and a pull there is nothing.
func _input(event: InputEvent) -> void:
	if not aims or play == null:
		return
	var r := stage_cv.get_global_rect()
	if event is InputEventScreenTouch:
		var pos: Vector2 = event.position - r.position
		if event.pressed:
			if r.has_point(event.position) and play.can_throw() and not aim.active:
				aim.begin(event.index, pos, stick.hit(pos))
				if aim.stick:
					stick.take(pos)
				get_viewport().set_input_as_handled()
		elif aim.active and event.index == aim.index:
			if event.canceled:
				aim.cancel()
			else:
				if aim.stick:
					stick.drag(pos)
					aim.stick_at(play.holder, ShotStick.target(play.holder.pos, stick.knob))
				else:
					aim.now = pos
				_release(pos)
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag and aim.active and event.index == aim.index:
		if aim.stick:
			stick.drag(event.position - r.position)
		else:
			aim.now = event.position - r.position
		get_viewport().set_input_as_handled()

## Let go: the stick pulled back shoots, a tap passes (a teammate, or the water), as in a match.
func _release(pos: Vector2) -> void:
	if play.can_throw():
		if aim.stick:
			if aim.long_enough():
				play.shoot_at(aim.target(play.holder), aim.power(play.holder))
				paused = false
		elif aim.is_tap():
			var mate := AimGuide.tap_mate(view, play, pos)
			var spot = AimGuide.tap_spot(view, pos)
			if mate != null:
				play.pass_to(mate)
			elif spot != null:
				play.pass_at(spot)
	aim.cancel()

# ------------------------------------------------------------------ drawing
func _net() -> Dictionary:
	if play == null or not play.ball.in_net():
		return {}
	var b := play.ball
	var out := {"x": b.net_line, "y": b.pos.y, "t": b.net_t}
	if b.bar_t >= 0.0:
		out["in_t"] = b.bar_t
		out["in_y"] = (b.bar.at as Vector3).y
	return out

func _cap(s: Swimmer) -> Color:
	if s.keeper:
		return PoolArt.CAP_KEEPER
	return US_CAP if s.side == Swimmer.Side.US else them.cap_against(US_CAP)

func _trim(s: Swimmer) -> Color:
	return us.c1 if s.side == Swimmer.Side.US else them.trim_against(US_CAP)

func _draw_stage(ci: Control) -> void:
	var size := ci.size
	PoolArt.draw_pool(ci, view, t, size, lab_excite(), null, lab_crowd(), _net(), lab_style())
	if play != null:
		var bodies: Array[Swimmer] = play.bodies().duplicate()
		bodies.sort_custom(func(a: Swimmer, b: Swimmer): return a.pos.y < b.pos.y)
		var calm := fire_still()
		for s in bodies:
			HotFire.draw_under(ci, view, s, t, -1, calm)   # (as in a match: the spark ring, HotFire)
			PoolArt.draw_body(ci, view, s, _cap(s), _trim(s))
			HotFire.draw_over(ci, view, s, t, -1, calm)
		goal_show.draw_world(ci, view)
		PoolArt.draw_shot_fx(ci, view, play.ball)
		HotFire.draw_ball_fire(ci, view, play.ball, t, play.holder, -1, calm)
		PoolArt.draw_ball(ci, view, play.ball)
		PoolArt.draw_net_splash(ci, view, play.ball)
		bar_show.draw_world(ci, view)
		if aims and play.holder != null and play.holder.side == Swimmer.Side.US and not play.over:
			PoolArt.draw_holder_marker(ci, view, play.holder, t)
			aim.draw(ci, view, play, t)
		lab_draw(ci)
		if aims:
			stick.draw(ci, aim.stick and aim.index != -99)
	goal_fx.draw(ci, size, view)
	banner.draw(ci, size)
	bar_show.draw(ci, size, view)
	goal_show.draw(ci, size, view)
	# the status line, along the bottom (clear of the pool's top edge, where the wings play)
	ci.draw_rect(Rect2(0, size.y - 12, size.x, 12), Color(UI.INK, 0.75))
	UI.text(ci, Vector2(4, size.y - 3), status, 8, UI.TEXT, "body")

## A goal's just gone in (VISUAL UPGRADE TESTING's broadcast graphics).
func lab_goal(_who: PoloPlayer) -> void:
	pass

## VISUAL UPGRADE TESTING's levels: the goal, the stands, how full and how excited they are.
func lab_goal_level() -> int:
	return 1

func lab_style() -> Dictionary:
	return {}

func lab_crowd() -> float:
	return 0.6

func lab_excite() -> float:
	return 0.0

## Where the camera looks: the attack, as in a match (HOT STAR TESTING frames a keeper's goal).
func focus() -> Vector2:
	return view.attack_frame(play)

## The fire drawn as Reduce Motion draws it (HOT STAR TESTING's MOTION: CALM).
func fire_still() -> bool:
	return HotFire.calm()

## Anything of the lab's own over the pool.
func lab_draw(_ci: Control) -> void:
	pass

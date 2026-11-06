extends RefCounted
## The shooting stick (ShotStick): the only way to shoot, through the slingshot's own aim:
##   godot --headless --path game -- --test shot_stick
##   godot --path game -- --test shot_stick_png <outdir>   (needs a window)
## Its mapping (power back, inverted aim across, the fan), the same shot as an equivalent slingshot
## pull from every attacking spot, the red X through it, and the match screen's touches: release,
## cancel, the dead zone, extra fingers, one shot per release, a pull on the water never a shot,
## passes untouched.

const DT := 1.0 / 60.0

var r   # the test runner (check, check_between)

func run(runner) -> void:
	r = runner
	print("shot stick: mapping")
	_mapping()
	print("shot stick: the slingshot's power and aim, from every spot")
	_equivalence()
	print("shot stick: the same shot")
	_same_shot()
	print("shot stick: the red X")
	_red_x()
	print("shot stick: the match screen")
	await _screen()

# ------------------------------------------------------------------ helpers
## The knob for power share `u` (0..1) and aim `v` (-1 top .. 1 bottom of the fan).
static func knob(u: float, v: float) -> Vector2:
	var back := ShotStick.DEAD + u * (ShotStick.REACH - ShotStick.DEAD)
	return Vector2(-back, v * ShotStick.SPREAD * back)

static func power_of(u: float) -> float:
	return AimGuide.SHOT_BASE + (1.0 - AimGuide.SHOT_BASE) * u

## Where a throw from `from` at `target` crosses the goal line (before any close_tuck).
static func crossing(from: Vector2, target: Vector2) -> float:
	var d := target - from
	return from.y + d.y * (Geo.GOAL_X - from.x) / d.x

## The stick's aim, as the slingshot's: AimGuide driven by the knob from `h`.
static func stick_aim(h: Swimmer, k: Vector2) -> AimGuide:
	var aim := AimGuide.new()
	aim.begin(0, Vector2(60, 150), true)
	aim.stick_at(h, ShotStick.target(h.pos, k))
	return aim

func _play(seed_value: int) -> Play:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var teams: Array = r._teams()
	return Play.new(teams[0], teams[1], Play.Kind.HALF_COURT, rng)

# ------------------------------------------------------------------ mapping
func _mapping() -> void:
	r.check(ShotStick.clamp_knob(Vector2(25, 9)) == Vector2.ZERO, "the knob can't go forward of its rest point")
	r.check(ShotStick.clamp_knob(Vector2(-300, 0)) == Vector2(-ShotStick.REACH, 0), "...or back past full pull")
	var c := ShotStick.clamp_knob(Vector2(-40, -200))
	r.check(is_equal_approx(c.y, -ShotStick.SPREAD * 40.0) and is_equal_approx(c.x, -40.0),
		"up or down it stops at the fan's edge, the pull kept (%.1f, %.1f)" % [c.x, c.y])
	r.check(ShotStick.clamp_knob(Vector2(-3, 30)).y <= ShotStick.SPREAD * 3.0 + 0.001, "at the narrow point it barely moves up or down")
	r.check(ShotStick.SPREAD * ShotStick.REACH > ShotStick.SPREAD * 20.0 * 3.0, "pulled back, it has room to aim")
	# power: back only
	r.check(ShotStick.power_t(Vector2.ZERO) == 0.0 and not ShotStick.live(Vector2.ZERO) and ShotStick.target(Vector2(24, 10), Vector2.ZERO) == null,
		"at rest: no pull, no shot")
	r.check(not ShotStick.live(Vector2(-ShotStick.DEAD + 0.5, 0)), "a nudge inside the dead zone is no shot")
	r.check(is_equal_approx(ShotStick.power_t(knob(0.5, 0.0)), 0.5) and is_equal_approx(ShotStick.power_t(Vector2(-ShotStick.REACH, 0)), 1.0),
		"halfway back is half the power range, all the way back all of it")
	var steps := [0.0, 0.25, 0.5, 0.75, 1.0]
	var rising := true
	for i in range(1, steps.size()):
		rising = rising and ShotStick.power_t(knob(steps[i], 0.0)) > ShotStick.power_t(knob(steps[i - 1], 0.0))
	r.check(rising, "the further back, the harder")
	var same_power := true
	var same_aim := true
	for u in steps:
		for v in [-1.0, -0.4, 0.0, 0.6, 1.0]:
			same_power = same_power and is_equal_approx(ShotStick.power_t(knob(u, v)), ShotStick.power_t(knob(u, 0.0)))
			same_aim = same_aim and absf(ShotStick.aim_t(knob(u, v)) - v) < 0.0001
	r.check(same_power, "up or down never changes the power")
	r.check(same_aim, "straight back along a ray never changes the aim")
	# inverted aim
	r.check(ShotStick.cross_y(knob(1.0, -1.0)) > Geo.GOAL_Y + Geo.GOAL_HALF, "up-left aims low (across the bottom post)")
	r.check(is_equal_approx(ShotStick.cross_y(knob(1.0, 0.0)), Geo.GOAL_Y), "straight left aims at the middle")
	r.check(ShotStick.cross_y(knob(1.0, 1.0)) < Geo.GOAL_Y - Geo.GOAL_HALF, "down-left aims high")
	r.check(absf(ShotStick.cross_y(knob(1.0, 1.0)) - (Geo.GOAL_Y - Geo.GOAL_HALF - Play.SHOT_WIDE)) < 0.03,
		"the full fan is the slingshot's whole aim, as wide as aim_info still calls a shot")
	r.check(is_equal_approx(ShotStick.cross_y(knob(0.1, -1.0)), ShotStick.cross_y(knob(1.0, -1.0))),
		"a soft shot aims as far as a full one")
	var v := PoolView.new()
	v.snap_to(Vector2(26, 10))
	r.check(v.to_screen(Vector2(Geo.GOAL_X, ShotStick.cross_y(knob(1, -1)))).y > v.to_screen(Geo.goal_center()).y,
		"on screen: knob up, reticle down")
	# fixed: the same layout whoever has the ball, on the left but in from the edge, in the open water
	var st := ShotStick.new()
	st.layout(Vector2(480, 270), Vector2.ZERO)
	var rest := st.rest
	r.check(rest.x - ShotStick.REACH - ShotStick.PAD >= 48.0 and rest.x + ShotStick.PAD < 200.0, "the stick sits on the left, in from the edge (%s)" % str(rest))
	r.check(rest.y - ShotStick.SPREAD * ShotStick.REACH - ShotStick.PAD > PoolView.HUD_H and rest.y + ShotStick.SPREAD * ShotStick.REACH + ShotStick.PAD < 270 - 16,
		"clear of the scoreboard and of the holder's tag")
	st.layout(Vector2(480, 270), Vector2.ZERO)
	r.check(st.rest == rest and st.hit(rest) and st.hit(rest + Vector2(-ShotStick.REACH, ShotStick.SPREAD * ShotStick.REACH)) \
		and not st.hit(rest + Vector2(40, 0)) and not st.hit(Vector2(240, 140)), "the knob and the wedge take a touch, the water doesn't")
	st.take(rest + Vector2(-5, 3))
	st.drag(rest + Vector2(-5 - 400, 3 - 400))
	r.check(st.knob == ShotStick.clamp_knob(Vector2(-400, -400)), "a finger dragged off the stick keeps it, the knob clamped in the fan")
	st.step(DT, true, false)
	r.check(st.knob.length() > 1.0, "let go, the knob springs back (not in one frame)")
	for i in 30:
		st.step(DT, true, false)
	r.check(st.knob == Vector2.ZERO, "...and is back at rest")
	for i in 20:
		st.step(DT, false, false)
	r.check(st.shown == 0.0, "no shot to take: it hides")

# ------------------------------------------------------------------ the slingshot's numbers
## From every spot of the attack: the stick's power is the slingshot's for the same pull past the
## shot line, its aim crosses where it says, and any slingshot shot pull has a stick twin.
func _equivalence() -> void:
	var p := _play(31)
	var spots := []
	for tag in ["1", "2", "3", "4", "5", "6"]:
		var a: Swimmer = PlaySetup._by_tag(p, tag)
		if a != null:
			spots.append(a)
	# the corners of the attack too (the spots the slingshot struggled from, on the screen's edge)
	for at in [Vector2(23.0, 2.5), Vector2(23.0, 17.5), Vector2(27.6, 3.5), Vector2(28.4, 16.0), Vector2(18.0, 10.0)]:
		var s := Swimmer.new(p.holder.player, Swimmer.Side.US)
		s.pos = at
		spots.append(s)
	r.check(spots.size() >= 10, "the attack's spots: %d" % spots.size())
	var n := 0
	var power_ok := 0
	var aim_ok := 0
	var shot_ok := 0
	var twin_ok := 0
	var twins := 0
	var power_by_spot := {}
	for s in spots:
		p.holder = s
		for u in [0.0, 0.2, 0.5, 0.8, 1.0]:
			for v in [-1.0, -0.6, -0.2, 0.0, 0.3, 0.7, 1.0]:
				var k := knob(u, v)
				var aim := stick_aim(s, k)
				var target := aim.target(s)
				n += 1
				power_ok += 1 if absf(aim.power(s) - power_of(u)) < 0.0005 else 0
				aim_ok += 1 if absf(crossing(s.pos, target) - ShotStick.cross_y(k)) < 0.0005 else 0
				var mode := String(p.aim_info(target).mode)
				shot_ok += 1 if mode == "shot" and aim.long_enough() and not aim.is_tap() and p.shooting_pull(target) else 0
				power_by_spot[str(u)] = power_by_spot.get(str(u), []) + [aim.power(s)]
		# a slingshot pull into the goal from here, and the stick's twin of it
		for pull_to in [Vector2(29.4, 9.0), Vector2(30.6, 11.7), Vector2(31.5, 8.2), Vector2(33.5, 10.0)]:
			var orig := AimGuide.new()
			orig.begin(0, Vector2(300, 150))
			orig.now = orig.start + AimGuide.pull_for(s, pull_to)
			if String(p.aim_info(orig.target(s)).mode) != "shot":
				continue
			var cy := crossing(s.pos, orig.target(s))
			var u2 := (orig.power(s) - AimGuide.SHOT_BASE) / (1.0 - AimGuide.SHOT_BASE)
			var v2 := (Geo.GOAL_Y - cy) / ShotStick.AIM_SPAN
			var twin := stick_aim(s, knob(u2, v2))
			twins += 1
			var a1: Dictionary = p.aim_info(orig.target(s))
			var a2: Dictionary = p.aim_info(twin.target(s))
			twin_ok += 1 if absf(twin.power(s) - orig.power(s)) < 0.0005 and absf(float(a1.cross_y) - float(a2.cross_y)) < 0.0005 else 0
	r.check(power_ok == n, "the stick's power is the slingshot's for the same pull past the line: %d / %d" % [power_ok, n])
	r.check(aim_ok == n, "its aim crosses the goal line where the knob says: %d / %d" % [aim_ok, n])
	r.check(shot_ok == n, "every live knob is a shot (a pull back, never a tap or a pass): %d / %d" % [shot_ok, n])
	r.check(twins >= 30 and twin_ok == twins, "every slingshot shot has a stick twin, same power, same crossing: %d / %d" % [twin_ok, twins])
	var spread := 0.0
	for u in power_by_spot:
		var ps: Array = power_by_spot[u]
		spread = maxf(spread, ps.max() - ps.min())
	r.check(spread < 0.001, "the same knob is the same power from the wing, the point, the corner (spread %.4f)" % spread)
	var aim := stick_aim(spots[0], Vector2(-ShotStick.REACH, 0))
	r.check(is_equal_approx(aim.power(spots[0]), 1.0), "full pull is the slingshot's full power, no more")
	aim = stick_aim(spots[0], knob(0.0, 0.0))
	r.check(absf(aim.power(spots[0]) - AimGuide.SHOT_BASE) < 0.001, "just out of the dead zone, the slingshot's softest shot")

# ------------------------------------------------------------------ the same shot
## Twin plays, the same dice: a slingshot pull and its stick twin shoot the same shot.
func _same_shot() -> void:
	var n := 0
	var same := 0
	var outcomes := {}
	for i in 30:
		var u: float = [0.15, 0.55, 1.0][i % 3]
		var v: float = [-0.9, -0.3, 0.0, 0.4, 0.8][i % 5]
		var pa := _play(500 + i)
		var pb := _play(500 + i)
		for k in 20:
			pa.step(DT)
			pb.step(DT)
		if not (pa.can_throw() and pb.can_throw()):
			continue
		var h := pa.holder
		var k := knob(u, v)
		# the slingshot's pull for the same shot: past the shot line along the same line, as far
		var cy := ShotStick.cross_y(k)
		var dir := (Vector2(Geo.GOAL_X, cy) - h.pos).normalized()
		var reach := (Play.SHOT_ZONE_X - h.pos.x) / dir.x
		var orig := AimGuide.new()
		orig.begin(0, Vector2(300, 150))
		orig.now = orig.start + AimGuide.pull_for(h, h.pos + dir * (reach + u * AimGuide.SHOT_EXTRA + 0.001))
		var mode_a := pa.shoot_at(orig.target(h), orig.power(h))
		var st := stick_aim(pb.holder, k)
		var mode_b := pb.shoot_at(st.target(pb.holder), st.power(pb.holder))
		var sa := pa.ball.shot.duplicate()
		var sb := pb.ball.shot.duplicate()
		for f in 200:
			if pa.ball.state != Ball.State.SHOT and pb.ball.state != Ball.State.SHOT:
				break
			pa.step(DT)
			pb.step(DT)
		n += 1
		var match_all := mode_a == mode_b and String(sa.get("outcome", "")) == String(sb.get("outcome", "")) \
			and pa.ball.pos.distance_to(pb.ball.pos) < 0.01 and pa.keeper.pos.distance_to(pb.keeper.pos) < 0.01 \
			and pa.over == pb.over
		same += 1 if match_all else 0
		outcomes[String(sa.get("outcome", mode_a))] = true
	r.check(n >= 20 and same == n, "a stick shot plays out exactly as its slingshot twin (the keeper, the dice, the ball): %d / %d" % [same, n])
	r.check(outcomes.size() >= 2, "...over more than one kind of result (%s)" % ", ".join(outcomes.keys()))

## Through a piston's raised arm the stick's aim has the red X and is blocked, as the slingshot's is.
func _red_x() -> void:
	var pt = load("res://tests/piston_test.gd").new()
	pt.r = r
	var n := 0
	var ok := 0
	for i in 12:
		var o: Array = pt._blocking(6400 + i, DefenseFormation.F.FOUR_FIVE)
		if o.is_empty():
			continue
		var p: Play = o[0]
		var u := 0.5
		var cy := p.blocked_aim(power_of(u))
		if is_nan(cy):
			continue
		var k := knob(u, clampf((Geo.GOAL_Y - cy) / ShotStick.AIM_SPAN, -1.0, 1.0))
		var aim := stick_aim(p.holder, k)
		var info := p.aim_info(aim.target(p.holder))
		if String(info.mode) != "shot":
			continue
		var x := not p.arm_block(float(info.cross_y), aim.power(p.holder)).is_empty()
		var sh: Dictionary = pt._fire(p, aim.target(p.holder), aim.power(p.holder))
		n += 1
		ok += 1 if x and String(sh.get("outcome", "")) == "block" and bool(sh.get("arm", false)) else 0
	r.check(n >= 6 and ok == n, "through a raised arm: the red X up and the stick's shot blocked, %d / %d" % [ok, n])

# ------------------------------------------------------------------ the match screen
## A match screen with your ball, the tips out of the way: the screen, once you can shoot.
func _match(seed_value: int):
	Game.goto("match", {"us": League.make_team(3), "them": League.make_team(0), "seed": seed_value, "minutes": 2.0, "level": 0.5})
	await r.get_tree().process_frame
	var ms = Game.current_screen
	ms.flow.sprint_done(true)
	for i in 120:
		await r.get_tree().process_frame
		if ms.flow.phase == MatchFlow.Phase.ATTACK and ms.flow.play.can_throw() and ms.stick.shown >= 1.0:
			break
	return ms

func _touch(ms, at: Vector2, down: bool, index := 0, canceled := false) -> void:
	var e := InputEventScreenTouch.new()
	e.position = at
	e.pressed = down
	e.index = index
	e.canceled = canceled
	ms._input(e)

func _drag(ms, at: Vector2, index := 0) -> void:
	var e := InputEventScreenDrag.new()
	e.position = at
	e.index = index
	ms._input(e)

func _frames(n: int) -> void:
	for i in n:
		await r.get_tree().process_frame

func _shots(p: Play) -> int:
	return p.events.filter(func(e): return e.get("k", "") == "shot").size()

func _screen() -> void:
	# a shot: up-left, all the way back, to the low side
	var ms = await _match(41)
	var p: Play = ms.flow.play
	r.check(p.can_throw() and ms.stick.shown >= 1.0, "your ball: the stick is up")
	var rest: Vector2 = ms.stick.rest
	var holder: Swimmer = p.holder
	_touch(ms, rest, true)
	r.check(ms.aim.active and ms.aim.stick and not ms.aim.long_enough(), "a touch on the knob takes the stick, no pull yet")
	_drag(ms, rest + Vector2(-35, -12))
	await _frames(2)
	var cy1 := float(p.aim_info(ms.aim.target(p.holder)).cross_y)
	var pw1 := float(ms.aim.power(p.holder))
	_drag(ms, rest + Vector2(-70, -24))   # (twice as far back along the same ray)
	await _frames(2)
	var cy2 := float(p.aim_info(ms.aim.target(p.holder)).cross_y)
	r.check(absf(cy1 - cy2) < 0.05, "pulling further back along it keeps the aim (%.2f, %.2f)" % [cy1, cy2])
	r.check(is_equal_approx(ms.aim.power(p.holder), 1.0) and pw1 < 0.8, "...and goes to full power (half back was %.2f)" % pw1)
	_drag(ms, rest + Vector2(-200, -200))
	await _frames(3)
	var info: Dictionary = p.aim_info(ms.aim.target(p.holder))
	r.check(ms.aim.long_enough() and String(info.mode) == "shot" and float(info.cross_y) > Geo.GOAL_Y + 1.0,
		"dragged up-left, the slingshot's guide aims low in the goal (%.2f)" % float(info.cross_y))
	r.check(p.raised, "he lifts the ball to shoot")
	r.check(p.holder == holder and ms.calls.open == false, "no pass, no call, the same man on the ball")
	# another finger: changes nothing
	var knob_before: Vector2 = ms.stick.knob
	_touch(ms, Vector2(300, 120), true, 1)
	_drag(ms, Vector2(200, 200), 1)
	_touch(ms, Vector2(200, 200), false, 1)
	await _frames(1)
	r.check(ms.aim.active and ms.aim.index == 0 and ms.stick.knob == knob_before and p.holder == holder and p.ball.state == Ball.State.HELD,
		"a second finger neither moves the stick nor passes nor shoots")
	_touch(ms, rest + Vector2(-200, -200), false)
	r.check(_shots(p) == 1 and p.ball.state == Ball.State.SHOT and not ms.aim.active, "let go: one shot, the slingshot's")
	r.check(ms.stick.knob != Vector2.ZERO, "the knob springs back after the shot, not before it")
	_touch(ms, rest + Vector2(-200, -200), false)
	r.check(_shots(p) == 1 and not ms.aim.active, "a second release is no second shot")
	await r.get_tree().create_timer(0.6).timeout
	r.check(ms.stick.knob == Vector2.ZERO, "the knob is back at rest")
	r.check(ms.stick.shown < 1.0, "the ball's gone: the stick hides")
	# down-left, half back: high in the goal
	ms = await _match(42)
	p = ms.flow.play
	rest = ms.stick.rest
	_touch(ms, rest, true)
	_drag(ms, rest + Vector2(-38, 18))
	await _frames(2)
	info = p.aim_info(ms.aim.target(p.holder))
	var pw: float = ms.aim.power(p.holder)
	r.check(String(info.mode) == "shot" and float(info.cross_y) < Geo.GOAL_Y - 0.5 and pw > 0.55 and pw < 0.85,
		"down-left, half back: high in the goal, middling power (%.2f, %.2f)" % [float(info.cross_y), pw])
	_touch(ms, rest + Vector2(-38, 18), false)
	r.check(_shots(p) == 1, "...and shot")
	# cancelled by the system: nothing thrown
	ms = await _match(43)
	p = ms.flow.play
	rest = ms.stick.rest
	holder = p.holder
	_touch(ms, rest, true)
	_drag(ms, rest + Vector2(-60, 0))
	await _frames(2)
	_touch(ms, rest + Vector2(-60, 0), false, 0, true)
	await _frames(2)
	r.check(_shots(p) == 0 and not ms.aim.active and p.ball.state == Ball.State.HELD, "a cancelled touch lets go without a shot")
	# the dead zone, and a tap on the stick: neither shoots nor passes
	_touch(ms, rest, true)
	_drag(ms, rest + Vector2(-3, 1))
	await _frames(2)
	r.check(not p.raised, "inside the dead zone he doesn't lift it")
	_touch(ms, rest + Vector2(-3, 1), false)
	_touch(ms, rest + Vector2(-50, 10), true)
	_touch(ms, rest + Vector2(-50, 10), false)
	await _frames(2)
	r.check(_shots(p) == 0 and p.ball.state == Ball.State.HELD and p.holder == holder, "a nudge or a tap on the stick: no shot, no pass")
	# pause mid-pull: let go
	_touch(ms, rest, true)
	_drag(ms, rest + Vector2(-60, -10))
	ms._pause()
	r.check(not ms.aim.active, "the pause menu lets go of the stick")
	ms.paused = false
	_touch(ms, rest + Vector2(-60, -10), false)
	await _frames(2)
	r.check(_shots(p) == 0, "...and the release after it throws nothing")
	# the play's over mid-pull (a steal, a whistle): let go
	_touch(ms, rest, true)
	_drag(ms, rest + Vector2(-60, -10))
	p.over = true
	ms._stick_aim(p)
	r.check(not ms.aim.active, "the play over mid-pull: the stick lets go")
	p.over = false
	_touch(ms, rest + Vector2(-60, -10), false)
	r.check(_shots(p) == 0, "...and nothing's thrown")
	# the slingshot on the water is gone: a pull there neither aims nor shoots; a tap still passes
	await _frames(2)
	var h := p.holder
	var from: Vector2 = ms.view.to_screen(h.pos) + Vector2(20, 30)
	r.check(not ms.stick.hit(from), "(the touch is on the water, off the stick)")
	_touch(ms, from, true, 2)
	_drag(ms, from + AimGuide.pull_for(h, Vector2(31.0, 9.4)), 2)
	await _frames(2)
	r.check(not ms.aim.stick and not p.raised, "a pull on the water doesn't aim (no ball up)")
	_touch(ms, from + AimGuide.pull_for(p.holder, Vector2(31.0, 9.4)), false, 2)
	r.check(_shots(p) == 0 and p.holder == h and p.ball.state == Ball.State.HELD, "...and never shoots")
	ms = await _match(44)
	p = ms.flow.play
	var mate: Swimmer = null
	for a in p.attackers:
		if a != p.holder and not a.out and not ms.stick.hit(ms.view.to_screen(a.pos) + Vector2(0, -5)):
			mate = a
			break
	var at: Vector2 = ms.view.to_screen(mate.pos) + Vector2(0, -5)
	_touch(ms, at, true)
	_touch(ms, at, false)
	r.check(p.ball.state == Ball.State.PASS and p.ball.receiver == mate, "a tap on a teammate still passes to him")
	# a teammate swimming under the stick: a tap on him is still his pass
	ms = await _match(46)
	p = ms.flow.play
	var under: Swimmer = null
	for a in p.attackers:
		if a != p.holder and not a.out:
			under = a
			break
	under.pos = ms.view.to_world(ms.stick.rest + Vector2(-30, 5))
	under.vel = Vector2.ZERO
	at = ms.view.to_screen(under.pos) + Vector2(0, -5)
	r.check(ms.stick.hit(at), "(he's under the stick)")
	_touch(ms, at, true)
	_touch(ms, at, false)
	r.check(p.ball.state == Ball.State.PASS and p.ball.receiver == under and _shots(p) == 0,
		"a tap on a teammate under the stick passes to him, not the stick")
	# autoplay never shows it
	Game.goto("match", {"us": League.make_team(3), "them": League.make_team(0), "seed": 45, "minutes": 2.0, "autoplay": true})
	await _frames(1)
	ms = Game.current_screen
	ms.flow.sprint_done(true)
	await _frames(40)
	r.check(ms.stick.shown == 0.0, "the bot's attack: no stick")
	Game.save_settings()
	Game.goto("title")
	await _frames(1)

# ------------------------------------------------------------------ screenshots
static func shots(runner, dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	var save := func(name: String) -> void:
		await RenderingServer.frame_post_draw
		runner.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [dir, name])
		print("  shot ", name)
	var t = load("res://tests/shot_stick_test.gd").new()
	t.r = runner
	var ms = await t._match(41)
	Engine.time_scale = 0.0001   # (hold the play still while the stick's dragged)
	await save.call("stick_rest")
	var rest: Vector2 = ms.stick.rest
	for c in [["stick_up_left_full", Vector2(-200, -200)], ["stick_left_full", Vector2(-200, 0)],
			["stick_down_left_half", Vector2(-38, 18)]]:
		t._touch(ms, rest, true)
		t._drag(ms, rest + c[1])
		ms._process(1.0 / 60.0)   # (one tick at the paused speed: the guide and the raised ball)
		await runner.get_tree().process_frame
		await save.call(c[0])
		t._touch(ms, rest + c[1], false, 0, true)   # (let go without shooting)
		ms.stick.knob = Vector2.ZERO
	Engine.time_scale = 1.0
	t._touch(ms, rest, true)
	t._drag(ms, rest + Vector2(-200, 10))
	await t._frames(3)
	t._touch(ms, rest + Vector2(-200, 10), false)
	await t._frames(2)
	await save.call("stick_after_shot")
	Game.save_settings()
	Game.goto("title")

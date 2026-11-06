extends RefCounted
## THE MAN-DOWN ZONE (ManDownZone): five lanes from the coaching sketch, the ball side stepping out,
## the rest shifting as a unit, the old ball side recovering, nobody swimming faster than he can.
##   godot --headless --path game -- --test man_down

var r   # the test runner

const DT := 1.0 / 60.0

func run(runner) -> void:
	r = runner
	print("man-down zone")
	Store.reset_for_tests()
	Game.progress = Progression.fresh()
	var c := Career.new_game("SJCU", "A", "B", 71)
	c.queue.clear()
	var f := MatchFlow.new(c.team(), c.teams["CULA"], 99, 2.0)
	f._start_attack(Play.Kind.HALF_COURT)
	var p := f.play
	var gone := p.defenders[3]
	p._exclusion(gone, p.attackers[3])
	p.freeze = 0.0
	for a in p.attackers:
		a.pos = a.home
		a.vel = Vector2.ZERO
		a.target = a.home
	_ball_to(p, "3")
	_settle(p, 3.0)

	var lanes := {}
	for d in p.defenders:
		if d != gone:
			lanes[d.zlane] = d
	r.check(gone.zlane == -1 and lanes.size() == 5 and not lanes.has(-1),
		"five lanes, one each, none for the excluded man (%s)" % str(lanes.keys()))
	var L := ManDownZone.Lane
	var top_point: Swimmer = lanes.get(L.TOP_POINT)
	var bot_point: Swimmer = lanes.get(L.BOT_POINT)
	var mid: Swimmer = lanes.get(L.MID)
	var top_flat: Swimmer = lanes.get(L.TOP_FLAT)
	var three := _tag(p, "3")
	var two := _tag(p, "2")

	# ball at 3 (top point): his lane man is out on him, hand up; the lanes round the man he left shade over
	r.check(p.zone_primary == top_point and top_point.pos.distance_to(three.pos) < 1.3,
		"ball at 3: the top-point lane man steps out to him (%.2f m off)" % top_point.pos.distance_to(three.pos))
	r.check(top_point.zreach > 0.5 and top_point.mark == three, "...his hand up in the lane, and he's the one on 3")
	var bot_flat: Swimmer = lanes.get(L.BOT_FLAT)
	var mid_y_top := mid.pos.y
	var flat_y_top := bot_flat.pos.y
	var tp_out := top_point.pos

	# swing it to 2: the old ball side recovers, the new one steps up, the middle slides down
	var vmax := 0.0
	_ball_to(p, "2")
	for i in int(3.0 / DT):
		_tick(p)
		for d in p.defenders:
			if not d.out:
				vmax = maxf(vmax, d.speed() / (d.top_speed * d.pace))
	r.check(p.zone_primary == bot_point and bot_point.pos.distance_to(two.pos) < 1.3,
		"ball at 2: the bottom-point lane man steps out (%.2f m off)" % bot_point.pos.distance_to(two.pos))
	r.check(top_point.pos.distance_to(three.pos) > tp_out.distance_to(three.pos) + 0.8 and top_point.zreach < 0.05,
		"...the old one recovers into his lane (%.2f -> %.2f m from 3), his hand down" % [tp_out.distance_to(three.pos), top_point.pos.distance_to(three.pos)])
	r.check(mid.pos.y - mid_y_top > 0.4 and flat_y_top - bot_flat.pos.y > 0.15,
		"...and the zone shifts with it: the middle %.2f m down to C, the bottom flat %.2f m up onto him (the man the stepper left)" % [mid.pos.y - mid_y_top, flat_y_top - bot_flat.pos.y])
	r.check(vmax <= 1.2 + 0.01, "nobody swims faster than his own pace allows (%.2f of it at most)" % vmax)

	# a wing: the flat on that side goes out, the post-side lanes cover the man he left
	_ball_to(p, "5")
	_settle(p, 3.0)
	r.check(p.zone_primary == top_flat and top_flat.pos.distance_to(_tag(p, "5").pos) < 1.2,
		"ball on the top wing: the top flat steps out to him")

	# the ball in the air: they read the pass, before the catch
	p.ball.state = Ball.State.PASS
	p.ball.receiver = _tag(p, "1")
	p.ball.to = p.ball.receiver.pos
	ManDownZone.update(p, DT)
	r.check(p.zone_primary == lanes.get(L.BOT_FLAT), "a pass to the bottom wing: the bottom flat is the one going (as it's thrown)")

	# the man-up over: the zone's gone
	p.man_up = 0.0
	ManDownZone.update(p, DT)
	var none := true
	for d in p.defenders:
		none = none and d.zlane == -1
	r.check(none and not p.zone_set, "6 on 6 again: nobody's in a lane")
	_camera()

## The 6 on 5 camera (ManUpCam): an animated push in, a brief impact shake, a hold, a smooth way out.
func _camera() -> void:
	var cam := ManUpCam.new()
	cam.pivot = Vector2(300, 150)
	r.check(cam.xform() == Transform2D.IDENTITY, "camera: at rest the world is drawn pixel for pixel")
	cam.push()
	var scales: Array[float] = []
	var shook_early := false
	var shook := false
	var shake_max := 0.0
	var time := 0.0
	while time < 0.7:
		cam.step(DT, true)
		time += DT
		scales.append(cam.scale)
		if cam.offset != Vector2.ZERO:
			shook = true
			shake_max = maxf(shake_max, cam.offset.length())
			shook_early = shook_early or time < ManUpCam.SHAKE_FROM - 0.01 or time > ManUpCam.SHAKE_TO + 0.02
	var at := func(s: float) -> float: return scales[clampi(int(s / DT) - 1, 0, scales.size() - 1)]
	r.check(at.call(0.1) > 1.02 and at.call(0.1) < ManUpCam.ZOOM - 0.02 and at.call(0.3) < ManUpCam.ZOOM,
		"camera: the push in is animated over several frames (%.3f at 0.1 s, %.3f at 0.3 s)" % [at.call(0.1), at.call(0.3)])
	r.check(absf(at.call(0.46) - ManUpCam.ZOOM) < 0.005, "camera: ...and it's in by 0.45 s (%.3f)" % at.call(0.46))
	r.check(at.call(0.1) - 1.0 > (ManUpCam.ZOOM - 1.0) * 0.4, "camera: ...easing out (quick first, settling)")
	r.check(shook and not shook_early and shake_max >= 3.0,
		"camera: a noticeable shake (%.1f px) only as it lands, %.2f-%.2f s" % [shake_max, ManUpCam.SHAKE_FROM, ManUpCam.SHAKE_TO])
	r.check(cam.phase == ManUpCam.Phase.HOLD and cam.offset == Vector2.ZERO, "camera: then it holds still, pushed in")
	# the way out: smooth, about half a second, no shake
	var out_shake := false
	var steps := 0
	var mid := 0.0
	while cam.active() and steps < 120:
		cam.step(DT, false)
		steps += 1
		out_shake = out_shake or cam.offset != Vector2.ZERO
		if steps == 15:
			mid = cam.scale
	r.check(not out_shake and steps * DT > 0.4 and steps * DT < 0.62 and mid > 1.02 and mid < ManUpCam.ZOOM - 0.02,
		"camera: out again over %.2f s, no shake (%.3f halfway)" % [steps * DT, mid])
	r.check(cam.xform() == Transform2D.IDENTITY, "camera: and back pixel for pixel")
	# taps go through it, at either end of the pool
	for mirror in [false, true]:
		var v := PoolView.new()
		v.mirror = mirror
		v.snap_to(Vector2(26.0, 10.0))
		cam.push(false)
		for i in 40:
			cam.step(DT, true)
		v.cine = cam.xform()
		var w := Vector2(27.3, 8.1)
		var tap: Vector2 = v.cine * v.to_screen(w)
		r.check(v.to_world(tap).distance_to(w) < 0.06, "camera: a tap on a player still finds him, pushed in (%s)" % ("mirrored" if mirror else "attacking right"))

func _tag(p: Play, t: String) -> Swimmer:
	for a in p.attackers:
		if a.tag == t:
			return a
	return null

func _ball_to(p: Play, t: String) -> void:
	p.give_ball(_tag(p, t))

## Just the defence: the attack stands on its 4-2 spots with the ball where it's put.
func _tick(p: Play) -> void:
	PlayAI._defend(p, DT)
	for d in p.defenders:
		d.step(DT)

func _settle(p: Play, secs: float) -> void:
	for i in int(secs / DT):
		_tick(p)

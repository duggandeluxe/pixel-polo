extends RefCounted
## BAR-IN! / BAR-DOWN! (BarHit): picked off where the goal went in, never changing a shot; the ball
## onto the right bit of frame, the hit-stop, the ricochet the right way, the net, then GoalShow;
## counted once; pauses, skips, the buzzer and leaving the match; the share of corner goals.
##   godot --headless --path game -- --test bar_hit
##   godot --path game -- --test bar_hit_png <outdir>   (screenshots, needs a window)

const DT := 1.0 / 60.0
const LEFT_Y := Geo.GOAL_Y - Geo.GOAL_HALF
const RIGHT_Y := Geo.GOAL_Y + Geo.GOAL_HALF
const FROM := Vector2(24.0, 10.0)

var r   # the test runner

func run(runner) -> void:
	r = runner
	print("bar in / bar down")
	_selection()
	_frequency_and_gameplay()
	await _screen_goals()
	await _interruptions()

static func _goal(cy: float, h: float) -> Dictionary:
	return {"outcome": "goal", "cross_y": cy, "height": h, "speed": 14.0}

## The height that puts the ball's centre `gap` m under the bar.
static func _h_under(gap: float) -> float:
	return (BarHit.BAR_Z - gap - KeeperDuel.LINE_Z.x) / (KeeperDuel.LINE_Z.y - KeeperDuel.LINE_Z.x)

# ------------------------------------------------------------------ TESTS 1-6, 12: the pick
func _selection() -> void:
	# TEST 1: tight in the top left: high chance, the surface it was nearest
	var tl := BarHit.pick(_goal(LEFT_Y + 0.05, _h_under(0.25)), FROM, 0.0)
	r.check(tl.on and tl.kind == BarHit.Kind.LEFT_POST and tl.text == "BAR-IN!", "TEST 1: tight on the left post, high: BAR-IN! off the left post")
	r.check(float(tl.chance) >= 0.35 and float(tl.chance) <= 0.45, "TEST 1: almost touching: %.0f %% (35-45)" % (100.0 * float(tl.chance)))
	var tb := BarHit.pick(_goal(LEFT_Y + 0.35, _h_under(0.01)), FROM, 0.0)
	r.check(tb.on and tb.kind == BarHit.Kind.CROSSBAR and tb.text == "BAR-DOWN!", "TEST 1: top left, tighter under the bar than to the post: BAR-DOWN!")
	# the corner itself, equally near both: the way it was going decides
	var c := Geo.GOAL_HALF - BarHit.POST_EDGE - 0.02
	var across := BarHit.pick(_goal(Geo.GOAL_Y - c, _h_under(0.02)), Vector2(24.0, 13.0), 0.0)   # from the right, going left
	var down := BarHit.pick(_goal(Geo.GOAL_Y - c, _h_under(0.02)), Vector2(24.0, 7.0), 0.0)      # from the left, going away from it
	r.check(across.kind == BarHit.Kind.LEFT_POST and down.kind == BarHit.Kind.CROSSBAR,
		"the very corner: the post it was flying at, else the bar (%d, %d)" % [across.kind, down.kind])
	# TEST 2: the top right, mirrored: the right post, back across to the left
	var tr := BarHit.pick(_goal(RIGHT_Y - 0.05, _h_under(0.25)), FROM, 0.0)
	r.check(tr.on and tr.kind == BarHit.Kind.RIGHT_POST and float(tr.dir) < 0.0, "TEST 2: the right post, ricochet to the left")
	r.check(float(tl.dir) > 0.0, "...and the left post's goes right")
	r.check(absf((tr.at as Vector3).y - (RIGHT_Y - BarHit.CONTACT)) < 0.001 and absf((tl.at as Vector3).y - (LEFT_Y + BarHit.CONTACT)) < 0.001,
		"TEST 2: the contact is on the inside of the post it hit")
	# the contact is never more than NUDGE_MAX from where it really went
	r.check(absf((tl.nudge as Vector2).x) <= BarHit.NUDGE_MAX and absf((tb.nudge as Vector2).y) <= BarHit.NUDGE_MAX, "the flight's bent a few cm at most")
	# TEST 3: the middle: never, whatever the dice
	var mid_ok := true
	for cy in [9.6, 10.0, 10.4]:
		for h in [0.0, 0.25, 0.5]:   # (the middle: ORDINARY or more off the posts and the bar)
			var m := BarHit.pick(_goal(cy, h), FROM, 0.0)
			mid_ok = mid_ok and not m.on and float(m.chance) == 0.0
	r.check(mid_ok, "TEST 3: through the middle: never (chance 0 even on a 0 roll)")
	# TEST 4: an ordinary corner goal: next to nothing
	var oc := BarHit.chance(0.24)
	r.check(oc > 0.0 and oc <= 0.03, "TEST 4: an ordinary corner (0.24 m off): %.1f %%" % (100.0 * oc))
	r.check(BarHit.chance(0.07) >= 0.20 and BarHit.chance(0.07) <= 0.30, "extremely close (0.07 m): %.0f %% (20-30)" % (100.0 * BarHit.chance(0.07)))
	r.check(BarHit.chance(0.14) >= 0.05 and BarHit.chance(0.14) <= 0.12, "near (0.14 m): %.0f %% (5-12)" % (100.0 * BarHit.chance(0.14)))
	var falls := true
	var last := 1.0
	for i in 40:
		var p := BarHit.chance(i * 0.01)
		falls = falls and p <= last
		last = p
	r.check(falls and BarHit.chance(BarHit.ORDINARY) == 0.0, "the closer to the frame, the likelier; nothing past %.2f m" % BarHit.ORDINARY)
	# too far off to make contact believable: a plain goal, even on a winning roll
	var far := BarHit.pick(_goal(LEFT_Y + 0.33, 0.3), FROM, 0.0)
	r.check(not far.on, "a ball too far off the frame to bend onto it stays a plain goal")
	# TEST 5 / 6: saves and misses: never
	for o in ["save", "parry", "miss", "post", "block", "pending"]:
		var s := _goal(LEFT_Y + 0.05, 0.95)
		s.outcome = o
		r.check(not BarHit.pick(s, FROM, 0.0).on, "TEST 5/6: a %s: no BAR-IN!" % o)
	# TEST 12: the text is the surface's
	r.check(tl.text == "BAR-IN!" and tr.text == "BAR-IN!" and tb.text == "BAR-DOWN!", "TEST 12: left post BAR-IN!, right post BAR-IN!, bar BAR-DOWN!")
	# the pick is its own: the same shot, the same answer; the shot itself untouched
	var s1 := _goal(LEFT_Y + 0.06, 0.5)
	var copy := s1.duplicate()
	var a := BarHit.pick(s1, FROM)
	var b := BarHit.pick(s1, FROM)
	r.check(a.on == b.on and s1 == copy, "its own seeded die (the same shot, the same pick), the shot result unchanged")
	# the ricochet paths: off a post straight across; off the bar down hard first
	var back := Geo.GOAL_X + Geo.NET_DEPTH - Ball.NET_BALL_R
	var p0 := BarHit.path(tl, 0.0, back)
	var p1 := BarHit.path(tl, BarHit.RICOCHET * 0.25, back)
	var p2 := BarHit.path(tl, BarHit.RICOCHET, back)
	r.check(p1.y - p0.y > (p2.y - p0.y) * 0.45, "off the post: an immediate burst of speed (%.0f %% of the way in the first quarter)" % (100.0 * (p1.y - p0.y) / (p2.y - p0.y)))
	r.check(p2.y > RIGHT_Y - 0.3 and is_equal_approx(p2.x, back), "...across into the far (right) side of the net")
	var b0 := BarHit.path(tb, 0.0, back)
	var b1 := BarHit.path(tb, BarHit.DROP, back)
	var b2 := BarHit.path(tb, BarHit.DROP + BarHit.ACROSS, back)
	r.check(b0.z - b1.z > 0.6 and absf(b1.y - b0.y) < 0.3, "off the bar: sharply down first (%.2f m in %.2f s)" % [b0.z - b1.z, BarHit.DROP])
	r.check(absf(b2.y - b1.y) > 0.8 and is_equal_approx(b2.x, back), "...then diagonally across the goal into the net")
	var inside := true
	for s in 30:
		for q in [BarHit.path(tl, s * 0.01, back), BarHit.path(tr, s * 0.01, back), BarHit.path(tb, s * 0.01, back)]:
			inside = inside and q.x >= Geo.GOAL_X and q.x <= back + 0.001 and q.y >= LEFT_Y and q.y <= RIGHT_Y and q.z < BarHit.BAR_Z
	r.check(inside, "every ricochet stays behind the line, between the posts and under the bar")
	r.check(BarHit.RICOCHET >= 0.15 and BarHit.RICOCHET <= 0.3 and BarHit.DROP + BarHit.ACROSS <= 0.3, "ricochets last 0.15-0.30 s")
	r.check(BarHit.EXPAND >= 0.1 and BarHit.EXPAND <= 0.15 and BarHit.OUT >= 0.15 and BarHit.OUT <= 0.25, "the word: in 0.10-0.15 s, out 0.15-0.25 s")
	r.check(BarHit.pop(0.0) < 0.7 and BarHit.pop(BarHit.EXPAND) > 1.2 and is_equal_approx(BarHit.pop(0.3), 1.0) and BarHit.pop(BarHit.OUT_AT + BarHit.OUT) < 0.4,
		"...compressed, past full size, settled, shrunk away")

# ------------------------------------------------------------------ TEST 11 + gameplay preservation
func _frequency_and_gameplay() -> void:
	var teams: Array = [[League.make_team(2, 1), League.make_team(3, 1)], [League.make_team(1, 2), League.make_team(4, 2)],
		[League.make_team(3, 3), League.make_team(2, 3)]]
	var places: Array = []   # every goal's [cross_y, z, from]
	var same := true
	var shown := 0
	var corner := 0
	var corner_shown := 0
	var bad := 0
	var n := 0
	for kind in [Play.Kind.HALF_COURT, Play.Kind.COUNTER, Play.Kind.PENALTY]:
		for i in 260:
			var pair: Array = teams[i % teams.size()]
			# the same possession twice, BAR-IN! off and on: everything must come out the same
			var outs := []
			for fx in [false, true]:
				var rng := RandomNumberGenerator.new()
				rng.seed = 7000 + kind * 1000 + i
				var p := Play.new(pair[0], pair[1], kind, rng)
				p.bar_fx = fx
				r._run_play(p, rng)
				var o := String(p.result.get("outcome", ""))
				outs.append([o, p.result.get("scorer"), p.elapsed, p.shot_clock, p.ball.shot.get("cross_y", -1.0), rng.state])
				if not fx:
					continue
				n += 1
				if o != "goal":
					bad += 1 if p.ball.bar_on() else 0
					continue
				var sh := p.ball.shot
				var from: Vector2 = p.ball.from
				places.append([float(sh.cross_y), BarHit.line_z(float(sh.height)), from])
				var s := BarHit.surface(float(sh.cross_y), BarHit.line_z(float(sh.height)), from)
				if float(s.d) <= BarHit.NEAR:
					corner += 1
					corner_shown += 1 if p.ball.bar_on() else 0
				shown += 1 if p.ball.bar_on() else 0
			same = same and outs[0] == outs[1]
	r.check(same, "GAMEPLAY: %d possessions played with BAR-IN! off and on: every outcome, scorer, clock and die the same" % n)
	r.check(bad == 0, "TEST 5/6: no save, miss or block ever carries one")
	print("  real goals: %d, corner goals (<= %.2f m): %d, shown in play: %d of all goals, %d of corner goals" % [places.size(), BarHit.NEAR, corner, shown, corner_shown])
	# TEST 11: the share, on these real placements, many times over on a fixed seed
	var rng2 := RandomNumberGenerator.new()
	rng2.seed = 4242
	var bands := {"almost": [0, 0], "extreme": [0, 0], "near": [0, 0], "ordinary": [0, 0], "middle": [0, 0]}
	var q_on := 0
	var q_n := 0
	var all_on := 0
	for rep in 40:
		for pl: Array in places:
			var sh := _goal(float(pl[0]), 0.0)
			sh.height = (float(pl[1]) - KeeperDuel.LINE_Z.x) / (KeeperDuel.LINE_Z.y - KeeperDuel.LINE_Z.x)
			var res := BarHit.pick(sh, pl[2], rng2.randf())
			var d := float(res.d)
			var band := "almost" if d <= BarHit.ALMOST else ("extreme" if d <= BarHit.EXTREME else ("near" if d <= BarHit.NEAR
				else ("ordinary" if d <= BarHit.ORDINARY else "middle")))
			bands[band][0] += 1
			bands[band][1] += 1 if res.on else 0
			all_on += 1 if res.on else 0
			if d <= BarHit.NEAR:
				q_n += 1
				q_on += 1 if res.on else 0
	var share := q_on / maxf(1.0, q_n)
	var line := ""
	for k in bands:
		line += "%s %.1f%% (%d)  " % [k, 100.0 * bands[k][1] / maxf(1.0, bands[k][0]), bands[k][0]]
	print("  by band: " + line)
	print("  qualifying corner goals: %.1f %% of %d; all goals: %.1f %%" % [100.0 * share, q_n, 100.0 * all_on / maxf(1.0, places.size() * 40)])
	r.check(q_n > 2000, "TEST 11: a big enough sample (%d qualifying)" % q_n)
	r.check_between(share, 0.16, 0.24, "TEST 11: BAR-IN! / BAR-DOWN! on qualifying corner goals")
	var pa: Array = bands.almost
	var pe: Array = bands.extreme
	var pn: Array = bands.near
	var po: Array = bands.ordinary
	var pm: Array = bands.middle
	var ra: float = float(pa[1]) / maxf(1.0, float(pa[0]))
	var re: float = float(pe[1]) / maxf(1.0, float(pe[0]))
	var rn: float = float(pn[1]) / maxf(1.0, float(pn[0]))
	var ro: float = float(po[1]) / maxf(1.0, float(po[0]))
	r.check(ra > re and re > rn and rn > ro, "TEST 11: the closer to the frame, the more often")
	r.check(pm[1] == 0, "TEST 11: never through the middle")

# ------------------------------------------------------------------ in a real match screen
func _screen(seed_v: int = 9) -> Variant:
	Game.match_cfg = {"us": League.make_team(2, 1), "them": League.make_team(3, 1), "seed": seed_v, "minutes": 2.0, "autoplay": true}
	Game.goto("match", Game.match_cfg)
	await r.get_tree().process_frame
	return Game.current_screen

## A goal on its way from FROM, crossing the line at (cy, height), shown off the frame (roll 0).
## Everything after the release is the game's own: the flight, the line, the net, the show.
func _shoot(ms, cy: float, h: float, force := true) -> Play:
	var f: MatchFlow = ms.flow
	var p: Play = f.play
	var shooter: Swimmer = p.holder if p.holder != null else p.attackers[2]
	shooter.pos = FROM
	var res := _goal(cy, h)
	var end := ShotModel.past_line(FROM, cy, 0.6)
	p.ball.launch(FROM, end, FROM.distance_to(end) / 14.0, 0.0, Ball.State.SHOT)
	p.ball.shot = res
	p.ball.shooter = shooter
	p.holder = null
	p.ball.bar = BarHit.pick(res, FROM, 0.0 if force else -1.0)
	return p

func _attack(ms, kind := Play.Kind.HALF_COURT) -> Play:
	ms.flow._start_attack(kind)
	ms._process(DT)
	return ms.flow.play

## Plays the goal out frame by frame: what was seen.
func _watch(ms, p: Play) -> Dictionary:
	var f: MatchFlow = ms.flow
	var seen := {"contact": Vector3.INF, "freeze_frames": 0, "phases": [], "frozen_keeper": true, "net": false, "net_y": 0.0,
		"in_give": 0.0, "far_give": 0.0, "goal_at": -1.0, "word": "", "clock": true, "board_early": false, "frames": 0,
		"min_z_after": 9.0, "y_at_end": 0.0, "scored": f.state.score.duplicate(), "teleport": 0.0, "pre_ok": true}
	var clock := -1.0   # (it runs while the ball's in the air: from the goal on, it stands)
	var last := Vector2.INF
	var keeper_y := 0.0
	while f.play == p and int(seen.frames) < 900:
		ms._process(DT)
		seen.frames += 1
		var b: BarHit = ms.bar_show
		if b.active() and not (seen.phases as Array).has(b.phase):
			seen.phases.append(b.phase)
		if b.freeze > 0 or b.phase == BarHit.Phase.HIT_STOP:
			if seen.contact == Vector3.INF:
				seen.contact = Vector3(p.ball.pos.x, p.ball.pos.y, p.ball.z)
				keeper_y = p.keeper.pos.y
				seen.word = b.text
			seen.freeze_frames += 1
			seen.frozen_keeper = seen.frozen_keeper and p.keeper.pos.y == keeper_y \
				and Vector3(p.ball.pos.x, p.ball.pos.y, p.ball.z) == seen.contact
		if seen.contact != Vector3.INF and p.ball.in_net():
			seen.min_z_after = minf(seen.min_z_after, p.ball.z)
			if last != Vector2.INF:
				seen.teleport = maxf(seen.teleport, last.distance_to(p.ball.pos))
			last = p.ball.pos
		var net: Dictionary = ms._net()
		var fx := PoolArt.net_fx(net, 0.0)
		if not fx.is_empty():
			seen.in_give = maxf(seen.in_give, float(fx.give2))
		if p.ball.net_t >= 0.0 and not seen.net:
			seen.net = true
			seen.net_y = p.ball.pos.y
		seen.far_give = maxf(seen.far_give, Ball.net_bulge(p.ball.net_t))
		if ms.goal_show.active() and ms.goal_show.stage >= GoalShow.Stage.IMPACT and seen.goal_at < 0.0:
			seen.goal_at = ms.goal_show.t + ms.goal_show.pre
			seen.pre_ok = not b.active() or b.t >= BarHit.OUT_AT
		if p.over and f.play == p:
			if clock < 0.0:
				clock = f.state.clock
			seen.clock = seen.clock and f.state.clock == clock
		if ms.goal_show.active() and ms.goal_show.board_fx().is_empty():
			seen.board_early = seen.board_early or f.state.score != seen.scored
	return seen

func _screen_goals() -> void:
	var ms = await _screen(9)
	var f: MatchFlow = ms.flow
	var st := f.state
	# TEST 7, 8, 9, 10: each surface, scored exactly once, the show after it
	var cases := [["left post", LEFT_Y + 0.06, _h_under(0.3), BarHit.Kind.LEFT_POST, 1.0],
		["right post", RIGHT_Y - 0.06, _h_under(0.3), BarHit.Kind.RIGHT_POST, -1.0],
		["crossbar", Geo.GOAL_Y - 0.5, _h_under(0.02), BarHit.Kind.CROSSBAR, 1.0]]
	for c: Array in cases:
		var p := _attack(ms)
		var s0: int = st.score[0]
		var g0: int = st.goal_by[0].size()
		var who: PoloPlayer = (p.holder if p.holder != null else p.attackers[2]).player
		_shoot(ms, float(c[1]), float(c[2]))
		var w := _watch(ms, p)
		var name := String(c[0])
		var contact: Vector3 = w.contact
		r.check(contact != Vector3.INF, "TEST %s: the ball stops on the frame (hit-stop)" % name)
		if contact == Vector3.INF:
			continue
		if int(c[3]) == BarHit.Kind.CROSSBAR:
			r.check(absf(contact.z - (BarHit.BAR_Z - BarHit.CONTACT_Z)) < 0.001 and String(w.word) == "BAR-DOWN!",
				"TEST 9: on the underside of the bar (z %.2f): BAR-DOWN!" % contact.z)
			r.check(float(w.min_z_after) < 0.15, "TEST 9: it comes down hard off the bar (to z %.2f)" % float(w.min_z_after))
		else:
			var post := LEFT_Y if int(c[3]) == BarHit.Kind.LEFT_POST else RIGHT_Y
			r.check(absf(absf(contact.y - post) - BarHit.CONTACT) < 0.001 and String(w.word) == "BAR-IN!",
				"TEST %s: on the inside of the post (%.2f m in): BAR-IN!" % [name, absf(contact.y - post)])
		r.check(contact.x >= Geo.GOAL_X and contact.x < Geo.GOAL_X + 0.05, "TEST %s: contact on the goal line" % name)
		r.check(int(w.freeze_frames) >= 2 and int(w.freeze_frames) <= 3 and w.frozen_keeper,
			"TEST %s: hit-stop %d rendered frames, ball and keeper frozen" % [name, int(w.freeze_frames)])
		var dir := float(c[4])
		r.check(w.net and (float(w.net_y) - contact.y) * dir > 0.7, "TEST %s: it rockets across into the far side of the net (%.2f m across)" % [name, (float(w.net_y) - contact.y) * dir])
		r.check(float(w.in_give) > 0.3 and float(w.far_give) > 0.5, "TEST %s: the net snaps where it came in and where it lands" % name)
		r.check(float(w.teleport) < 0.25 * absf(float(w.net_y) - contact.y) + 0.1,
			"TEST %s: no jumps: fastest frame %.2f m of a %.2f m ricochet" % [name, float(w.teleport), absf(float(w.net_y) - contact.y)])
		var ph: Array = w.phases
		r.check(ph.has(BarHit.Phase.HIT_STOP) and ph.has(BarHit.Phase.RICOCHET) and ph.has(BarHit.Phase.NET_IMPACT)
			and ph.find(BarHit.Phase.HIT_STOP) < ph.find(BarHit.Phase.RICOCHET), "TEST %s: hit-stop, ricochet, net: %s" % [name, str(ph)])
		r.check(float(w.goal_at) > 0.5 and float(w.goal_at) < 0.7 and w.pre_ok, "TEST 10: GOAL! follows (%.2f s after the contact), the word gone first" % float(w.goal_at))
		r.check(w.clock and not w.board_early, "TEST 14: the clocks stand still; nothing counted early")
		r.check(st.score[0] == s0 + 1 and st.goal_by[0].size() == g0 + 1 and st.goal_by[0][-1] == who, "TEST %s / 10: one goal, his, counted once" % name)
		r.check(f.phase == MatchFlow.Phase.DEFENSE and not ms.bar_show.active() and ms.bar_show.ball == null, "TEST 10: their ball next, the show cleared")
	# their goal off your post: the same, against you
	f._start_defense(Play.Kind.HALF_COURT)
	ms._process(DT)
	var dp: Play = f.play
	var t0: int = st.score[1]
	_shoot(ms, LEFT_Y + 0.05, 0.4)
	var dw := _watch(ms, dp)
	r.check(String(dw.word) == "BAR-IN!" and st.score[1] == t0 + 1, "their goal in off your post: BAR-IN!, counted once")
	# a plain goal: none of it
	var pp := _attack(ms)
	var s1: int = st.score[0]
	_shoot(ms, Geo.GOAL_Y, 0.4)
	var pw := _watch(ms, pp)
	r.check(String(pw.word) == "" and (pw.phases as Array).is_empty() and absf(float(pw.goal_at) - GoalShow.IMPACT_AT) < 0.05,
		"TEST 3: a goal through the middle: the normal show, on time")
	r.check(st.score[0] == s1 + 1, "...counted once")
	# TEST 15: over and over: cheap, nothing left behind
	var t_us := Time.get_ticks_usec()
	var frames := 0
	for i in 12:
		var p := _attack(ms)
		_shoot(ms, LEFT_Y + 0.06 if i % 3 == 0 else (RIGHT_Y - 0.06 if i % 3 == 1 else 9.3), _h_under(0.02) if i % 3 == 2 else 0.4)
		var w := _watch(ms, p)
		frames += int(w.frames)
		if f.phase == MatchFlow.Phase.BREAK:
			f.break_done()
		if f.phase == MatchFlow.Phase.FINAL:
			break
	var per := float(Time.get_ticks_usec() - t_us) / maxf(1.0, frames) / 1000.0
	r.check(per < 4.0, "TEST 15: %d frames of repeated BAR-IN!s: %.3f ms a frame (logic)" % [frames, per])
	r.check(not ms.bar_show.active() and ms.bar_show.ball == null, "TEST 15: nothing left behind")
	Game.goto("title")
	await r.get_tree().process_frame

## TEST 13 / 14: paused in the middle, the buzzer, leaving the match.
func _interruptions() -> void:
	var ms = await _screen(13)
	var f: MatchFlow = ms.flow
	var st := f.state
	# paused in the middle of the ricochet: nothing moves; resumed: it finishes, counted once
	var p := _attack(ms)
	var s0: int = st.score[0]
	_shoot(ms, LEFT_Y + 0.06, 0.4)
	var n := 0
	while ms.bar_show.phase != BarHit.Phase.RICOCHET and n < 200:
		ms._process(DT)
		n += 1
	var at: Vector2 = p.ball.pos
	var bt: float = ms.bar_show.t
	ms.paused = true
	for _i in 30:
		ms._process(DT)
	r.check(p.ball.pos == at and ms.bar_show.t == bt, "TEST 13: paused mid-ricochet: everything holds")
	ms.paused = false
	var w := _watch(ms, p)
	r.check(st.score[0] == s0 + 1 and not ms.bar_show.active(), "TEST 13: resumed: it finishes, the goal counted once")
	# a tap during it doesn't skip it (only once GOAL! is in)
	p = _attack(ms)
	s0 = st.score[0]
	_shoot(ms, RIGHT_Y - 0.06, 0.4)
	n = 0
	while ms.bar_show.phase != BarHit.Phase.RICOCHET and n < 120:
		ms._process(DT)
		n += 1
	r.check(ms.bar_show.active() and not ms._skip_goal(), "TEST 13: a tap in the middle of it doesn't skip it")
	_watch(ms, p)
	r.check(st.score[0] == s0 + 1, "...counted once")
	# TEST 14: at the buzzer: a shot in the air at 0:00 of the 2nd, in off the bar
	p = _attack(ms)
	st.quarter = 2
	s0 = st.score[0]
	_shoot(ms, Geo.GOAL_Y + 0.6, _h_under(0.02))
	st.clock = 0.0
	w = _watch(ms, p)
	r.check(String(w.word) == "BAR-DOWN!" and st.score[0] == s0 + 1, "TEST 14: at the buzzer: BAR-DOWN!, counted")
	r.check(f.phase == MatchFlow.Phase.BREAK and st.clock == 0.0, "TEST 14: then the half-time break as usual")
	# leaving the match in the middle of one, and a fresh match after
	f.break_done()
	ms._process(DT)
	p = _attack(ms)
	_shoot(ms, LEFT_Y + 0.06, 0.4)
	n = 0
	while not ms.bar_show.active() and n < 120:
		ms._process(DT)
		n += 1
	r.check(ms.bar_show.active(), "TEST 13: one under way...")
	Game.goto("title")
	await r.get_tree().process_frame
	ms = await _screen(14)
	r.check(not ms.bar_show.active() and ms.flow.state.score == [0, 0], "TEST 13: ...left the match: a fresh match starts clean")
	Game.goto("title")
	await r.get_tree().process_frame

# ------------------------------------------------------------------ screenshots
## Frames of each kind: the contact (hit-stop), mid-ricochet, the net, then GOAL!.
static func shots(runner, dir: String) -> void:
	var t = load("res://tests/bar_hit_test.gd").new()
	t.r = runner
	DirAccess.make_dir_recursive_absolute(dir)
	var ms = await t._screen(9)
	var cases := [["left", LEFT_Y + 0.06, 0.45], ["right", RIGHT_Y - 0.06, 0.45], ["bar", Geo.GOAL_Y - 0.6, _h_under(0.02)]]
	for c: Array in cases:
		var p: Play = t._attack(ms)
		ms.autoplay = false
		t._shoot(ms, float(c[1]), float(c[2]))
		var n := 0
		var snaps := {"a_contact": false, "b_ricochet": false, "c_net": false, "d_word": false, "e_goal": false}
		while ms.flow.play == p and n < 400:
			await runner.get_tree().process_frame
			n += 1
			var b: BarHit = ms.bar_show
			var key := ""
			if b.phase == BarHit.Phase.HIT_STOP and not snaps.a_contact:
				key = "a_contact"
			elif b.phase == BarHit.Phase.RICOCHET and p.ball.bar_t > 0.06 and not snaps.b_ricochet:
				key = "b_ricochet"
			elif p.ball.net_t >= 0.02 and not snaps.c_net:
				key = "c_net"
			elif b.active() and b.t > 0.3 and not snaps.d_word:
				key = "d_word"
			elif ms.goal_show.stage == GoalShow.Stage.IMPACT and ms.goal_show.t > 0.2 and not snaps.e_goal:
				key = "e_goal"
			if key != "":
				snaps[key] = true
				await RenderingServer.frame_post_draw
				runner.get_viewport().get_texture().get_image().save_png("%s/bar_%s_%s.png" % [dir, c[0], key])
	Game.goto("title")

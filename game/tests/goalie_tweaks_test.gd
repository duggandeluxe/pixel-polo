extends RefCounted
## The Goalie & Tweaks update:
##   godot --headless --path game -- --test goalie_tweaks
## A: a keeper's save puts the ball in his hands and keeps it there (Ball.secure/put, Play.held_at,
##    KeeperDive.held): no jump, no hang, through every phase of his dive; a parry stays loose.
## B: the computer's 5 DROP, 4-5 DROP and 3-4 DROP are its own (DefenseFormation.slot): the men at the
##    bottom of the pool, yours unchanged at the top; the pistons press and foul as before.
## C/D: the stick in from the edge, DRIVE half as big again on top of it, the formation buttons tall.
## E: only a touch that comes down on the stick shoots. F: every screen shape.

const DT := 1.0 / 60.0
const F := DefenseFormation.F
const OLD_REST_X := 8.0 + ShotStick.PAD + ShotStick.REACH   # where the stick's knob rested before (90 px in)
const JUMP := 6.0      # px a frame: a ball going with his own dive and fall moves up to ~4.5; the old catch jumped 10-20

var r   # the test runner (check)

func run(runner) -> void:
	r = runner
	print("goalie & tweaks: A. the keeper's catch")
	_catch()
	print("goalie & tweaks: B. the computer's formations")
	_formations()
	print("goalie & tweaks: F. the controls on every screen")
	_layouts()
	print("goalie & tweaks: A/C/D/E. the match screen")
	await _screen()

# ------------------------------------------------------------------ A. the keeper's catch
## A play with the ball at the point, nobody moving it.
func _play(seed_value: int, defending := false) -> Play:
	var p: Play = r._center_play(seed_value, defending)
	p.give_ball(PlaySetup._by_tag(p, "3"))
	return p

## A dive of `side` for his keeper, `at` seconds into it.
static func _dive(p: Play, side: int, at: float) -> KeeperDive:
	var d := KeeperDive.from_body(KeeperDive.body_of(p.keeper.player), side, p.keeper.pos.y)
	d.t = at
	return d

## The shot reaches him `in_reach` of the way out along his reach (0: his body) and he holds it
## (or parries it): the play's own end of a shot (Play._resolve_shot), from the point it got to.
func _saved(p: Play, pose: KeeperDive, in_reach: float, outcome := "save") -> Vector3:
	p.keeper.pose = pose
	p.keeper.pos.y = pose.body_y()
	var cy := pose.body_y() + float(pose.side) * pose.reach() * in_reach
	var sh := p.holder
	p.ball.launch(sh.pos, Vector2(Geo.GOAL_X - 0.4, cy), 0.4, 0.0, Ball.State.SHOT)
	p.ball.shot = {"outcome": outcome, "cross_y": cy, "height": 0.6}
	p.ball.shooter = sh
	p.holder = null
	p.ball.t = 1.0
	p.ball.pos = p.ball.to
	p.ball.z = Play.shot_z(p.ball.shot, 1.0)
	var contact := Vector3(p.ball.pos.x, p.ball.pos.y, p.ball.z)
	p._resolve_shot()
	return contact

## Unrounded screen point of (x, y, height) in `v` (not mirrored).
static func _scr(v: PoolView, at: Vector3) -> Vector2:
	return Vector2((at.x - v.cam.x) * v.sx(), PoolView.HUD_H + (at.y - v.cam.y) * v.sy() - at.z * v.sz())

static func _b3(b: Ball) -> Vector3:
	return Vector3(b.pos.x, b.pos.y, b.z)

## `secs` of the play after the catch, watching the ball on screen: the biggest move it makes in a
## frame (px), how far it ever gets from his hands once caught (m), how far from the hand his art
## draws while he's up (px), whether it's always his. `run_pose`: his dive is run here, as
## MatchFlow runs your keeper's (Play only runs the computer's).
func _watch(p: Play, secs: float, run_pose := false) -> Dictionary:
	var v := PoolView.new()
	v.snap_to(Vector2(27.0, Geo.GOAL_Y))
	var last := _scr(v, _b3(p.ball))
	var out := {"jump": 0.0, "off": 0.0, "hand": 0.0, "hand_n": 0, "his": true, "phases": {}, "done": false,
		"lo": p.keeper.pos.y, "hi": p.keeper.pos.y}
	var t := 0.0
	while t < secs:
		if run_pose and p.keeper.pose != null:
			p.keeper.pose.advance(DT)
			p.keeper.pos.y = p.keeper.pose.body_y()
			if p.keeper.pose.done():
				p.keeper.pose = null
		p.step(DT)
		t += DT
		var now := _scr(v, _b3(p.ball))
		if now.distance_to(last) > out.jump:
			out.jump = now.distance_to(last)
			out["at"] = "%s t=%.2f sec=%.2f d=%s" % [KeeperDive.Phase.keys()[p.keeper.pose.phase()] if p.keeper.pose != null else "-", t, p.ball.secure_t, str(now - last)]
		last = now
		out.his = out.his and p.holder == p.keeper and p.ball.state == Ball.State.DEAD
		out.lo = minf(out.lo, p.keeper.pos.y)
		out.hi = maxf(out.hi, p.keeper.pos.y)
		if p.ball.secure_t >= Ball.SECURE_TIME:
			out.off = maxf(out.off, _b3(p.ball).distance_to(Play.held_at(p.keeper)))
		var pose := p.keeper.pose
		if pose == null:
			out.done = true
			continue
		out.phases[pose.phase()] = true
		if pose.phase() == KeeperDive.Phase.ACTIVE and pose.side != KeeperDive.CENTRE and not pose.turned() \
				and p.ball.secure_t >= Ball.SECURE_TIME:
			# PoolArt._keeper_dive's leading hand, its centre on screen, against the ball's
			var o := v.to_screen(p.keeper.pos)
			var f := 1.0 if p.keeper.facing >= 0.0 else -1.0
			var hx := 3 + roundi((2.0 if pose.side < 0 else 7.0) * pose.ext())
			var hy := pose.side * roundi(pose.reach() * v.sy()) - roundi(KeeperDive.BALL_Z * v.sz())
			var hand := o + Vector2(f * (hx + 1), hy + 0.5)
			var ball := v.to_screen(p.ball.pos, p.ball.z) + Vector2(1, 0)
			out.hand = maxf(out.hand, hand.distance_to(ball))
			out.hand_n += 1
	return out

func _catch() -> void:
	var cases := [
		# [name, side, seconds into his dive at the catch, how far out along his reach]
		["A1 a stationary keeper (the block, his body still)", KeeperDive.CENTRE, -1.0, 0.3],
		["A2 a moving keeper (still rising into his dive)", 1, -2.0, 0.9],
		["A3 a lunging keeper (full stretch, up the screen)", -1, -3.0, 1.0],
		["A3 a lunging keeper (full stretch, down the screen)", 1, -3.0, 0.6],
	]
	for i in cases.size():
		var c: Array = cases[i]
		var p := _play(100 + i)
		var pose := _dive(p, c[1], 0.0)
		match c[2]:
			-1.0, -3.0:
				pose.t = pose.extend_time() + 0.01   # up and holding
			-2.0:
				pose.t = lerpf(pose.react_time(), pose.extend_time(), 0.55)   # body still going
		var contact := _saved(p, pose, c[3])
		# (what the old catch did on this frame: straight to over his body, a field player's ball up)
		var v0 := PoolView.new()
		v0.snap_to(Vector2(27.0, Geo.GOAL_Y))
		var old := Vector3(p.keeper.pos.x + 0.2 * p.keeper.facing, p.keeper.pos.y - 0.05, 0.9)
		print("    %s: the old catch jumped %.1f px on the save's frame" % [c[0], _scr(v0, contact).distance_to(_scr(v0, old))])
		r.check(p.holder == p.keeper and p.ball.state == Ball.State.DEAD and String(p.result.get("outcome", "")) == "save",
			"%s: it's his ball" % c[0])
		r.check(_b3(p.ball).distance_to(contact) < 0.001 and p.ball.secure_t == 0.0,
			"%s: the catch starts where the ball met him, no jump to his body" % c[0])
		var w := _watch(p, 1.6)
		r.check(w.jump < JUMP, "%s: it never teleports (biggest move %.1f px a frame: %s)" % [c[0], w.jump, w.get("at", "")])
		r.check(w.off < 0.001, "%s: once caught it stays in his hands every frame (off by %.4f m)" % [c[0], w.off])
		r.check(w.his, "%s: it stays his, never loose" % c[0])
		r.check(w.done and p.keeper.pose == null and _b3(p.ball).distance_to(Play.held_at(p.keeper)) < 0.001,
			"%s: his dive over, it's up in his hand as any man holds it" % c[0])
		r.check(w.phases.has(KeeperDive.Phase.FALL) and w.phases.has(KeeperDive.Phase.RECOVER),
			"%s: (watched through his fall and his recovery: A6, no snap between them)" % c[0])
		if c[1] != KeeperDive.CENTRE:
			r.check(w.hand_n == 0 or w.hand <= 3.0, "%s: while he's up it's in the hand his art draws (%.1f px off)" % [c[0], w.hand])
		if c[2] == -2.0:
			r.check(w.hi - w.lo > 0.2 and w.off < 0.001, "%s: he moves %.2f m with it and it goes with him" % [c[0], w.hi - w.lo])
	# your keeper (MatchFlow runs his dive, the verdict is yours): the same catch
	var py := _play(130, true)
	var yours := _dive(py, -1, 0.0)
	yours.t = yours.extend_time() + 0.02
	py.keeper.pose = yours
	py.keeper.pos.y = yours.body_y()
	var sh := py.holder
	var cy := yours.tip_y()
	py.ball.launch(sh.pos, Vector2(Geo.GOAL_X, cy), 0.5, 0.0, Ball.State.SHOT)
	py.ball.shot = {"outcome": "pending", "auto": "save", "cross_y": cy, "height": 0.5}
	py.ball.shooter = sh
	py.holder = null
	py.ball.t = 0.97
	py.ball.pos = py.ball.from.lerp(py.ball.to, 0.97)
	py.ball.z = Play.shot_z(py.ball.shot, 0.97)
	py.set_verdict("save", py.shot_n)
	yours.hit(cy)
	var w2 := _watch(py, 1.6, true)
	r.check(py.holder == py.keeper and w2.his and w2.jump < JUMP and w2.off < 0.001 and w2.done,
		"A your keeper's save (the duel's verdict): into his hands and kept there (%.1f px, %.4f m)" % [w2.jump, w2.off])
	# A4: a parry stays a deflection: loose, its own drift, never stuck to him
	var pp := _play(140)
	var parry := _dive(pp, 1, 0.0)
	parry.t = parry.extend_time() + 0.01
	_saved(pp, parry, 0.95, "parry")
	var at0 := pp.ball.pos
	var drift := pp.ball.drift
	r.check(pp.ball.state == Ball.State.LOOSE and pp.holder == null and pp.ball.secure_t == INF and drift.length() > 1.0,
		"A4 a parry: loose, nobody's, knocked away")
	pp.loose_skip = 1.0   # (nobody gathers it for a moment: only the drift, Play._loose)
	pp.step(DT)
	r.check(pp.ball.state == Ball.State.LOOSE and pp.ball.pos.distance_to(Geo.clamp_in_pool(at0 + drift * DT)) < 0.001 and pp.ball.z == 0.0,
		"A4 ...on the water, drifting as a loose ball does (Play._loose), not in his hands")
	# A5: the ball leaves his hands: nothing holds it any more
	var pr := _play(150)
	var rel := _dive(pr, KeeperDive.CENTRE, 0.0)
	rel.t = rel.extend_time()
	_saved(pr, rel, 0.0)
	pr.ball.launch(pr.ball.pos, Vector2(20.0, 8.0), 0.6, 1.0, Ball.State.PASS)
	r.check(pr.ball.secure_t == INF, "A5 thrown: the catch is over, the ball follows its own flight")
	# ...and the possession after a save starts with it in a man's hands, not left on the keeper
	var saved_p := _play(160)
	var sp := _dive(saved_p, 1, 0.0)
	sp.t = sp.extend_time()
	_saved(saved_p, sp, 0.5)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var nxt := Play.new(saved_p.them, saved_p.us, Play.Kind.COUNTER, rng, saved_p.snapshot())
	r.check(nxt.holder != null and not nxt.holder.keeper and nxt.ball.state == Ball.State.HELD \
		and _b3(nxt.ball).distance_to(Play.held_at(nxt.holder)) < 0.001 and nxt.ball.secure_t == INF,
		"A5 the next possession: the outlet's gone, the ball's in a field player's hands")
	# a field player's ball sits where it always did
	var pf := _play(170)
	var h := pf.holder
	h.arm = 0.6
	pf.step(DT)
	r.check(_b3(pf.ball).distance_to(Vector3(h.pos.x + lerpf(0.35, 0.2, h.arm) * h.facing, h.pos.y - 0.05, lerpf(0.02, 0.9, h.arm))) < 0.001,
		"a field player holds it exactly as before")

# ------------------------------------------------------------------ B. formations
## A settled possession: the ball at `tag`, formation `f`, `secs` of it run.
func _settled(seed_value: int, f: int, tag: String, defending: bool, secs := 3.0) -> Play:
	var p: Play = r._center_play(seed_value, defending)
	for s in p.attackers + p.defenders:
		s.player.trait_id = ""
	p.give_ball(PlaySetup._by_tag(p, tag))
	p.select_formation(f)
	var t := 0.0
	while t < secs and not p.over:
		p.step(DT)
		t += DT
	return p

func _formations() -> void:
	r.check(DefenseFormation.slot(_play(1, true), "5") == "5" and DefenseFormation.slot(_play(1, false), "5") == "1"
		and DefenseFormation.slot(_play(1, false), "3") == "3" and DefenseFormation.slot(_play(1, false), "C") == "C",
		"B spot 5 is your D5 and the computer's D1 (its own spot 5, seen from its end); 3 and the centre the same")
	# B1-B5: which men drop, and where they are
	var want := {
		F.FIVE_DROP: [["5"], ["1"]],
		F.FOUR_FIVE: [["4", "5"], ["2", "1"]],
		F.THREE_FOUR: [["3", "4"], ["3", "2"]],
	}
	var names := {F.FIVE_DROP: "B2 5 DROP", F.FOUR_FIVE: "B1 4-5 DROP", F.THREE_FOUR: "B3 3-4 DROP"}
	for f: int in want:
		for defending in [true, false]:
			var who := "yours" if defending else "the computer's"
			var tags: Array = want[f][0 if defending else 1]
			var p := _settled(600 + f * 10 + int(defending), f, "3", defending)
			var dr := p.f_dropper
			var first_dropper: String = tags[tags.size() - 1]
			if f != F.FIVE_DROP:
				r.check(DefenseFormation.piston_tags(p) == tags, "%s, %s: the pistons are D%s and D%s" % [names[f], who, tags[0], tags[1]])
			r.check(dr != null and dr.dtag == first_dropper and dr.duty == DefenseFormation.Duty.DROP,
				"%s, %s: D%s is the one in front of the centre (%s)" % [names[f], who, first_dropper, dr.dtag if dr != null else "nobody"])
			var home := PlaySetup.HOME_6V6[first_dropper] as Vector2
			var top := home.y < Geo.GOAL_Y
			r.check(top == defending,
				"%s, %s: he comes from the %s of the pool" % [names[f], who, "top" if defending else "bottom"])
			var c := DefenseFormation.by_tag(p.attackers, "C")
			r.check(dr != null and dr.pos.distance_to(DefenseFormation.drop_spot(p, c)) < 1.2,
				"%s, %s: in the same central spot in front of the centre (%.2f m off)" % [names[f], who, dr.pos.distance_to(DefenseFormation.drop_spot(p, c)) if dr != null else 99.0])
	# the same formation from either end: the mirror image (the same jobs, the other men)
	for f in [F.FIVE_DROP, F.FOUR_FIVE, F.THREE_FOUR]:
		var a := _settled(700 + f, f, "3", true)
		var b := _settled(700 + f, f, "3", false)
		var same := true
		for s in a.defenders:
			var m := DefenseFormation.by_tag(b.defenders, DefenseFormation.TURNED[s.dtag], true)
			same = same and m.duty == s.duty
		r.check(same, "B %s: the computer's men do the jobs yours do, on the other side" % DefenseFormation.NAMES[f])
	# B4/B5: yours, every formation, as before (the tags the formations always used)
	var p45 := _settled(800, F.FOUR_FIVE, "3", true)
	r.check(p45.f_in.dtag == "5" and DefenseFormation.pistons(F.FOUR_FIVE) == ["4", "5"], "B4 your 4-5 DROP: D4 and D5 above the goal, unchanged")
	var press := _settled(801, F.PRESS, "3", true)
	var marking := press.defenders.all(func(s: Swimmer) -> bool: return s.duty in [DefenseFormation.Duty.MARK, DefenseFormation.Duty.CLOSE])
	r.check(marking and press.f_dropper == null, "B5 your PRESS: everyone on his man")
	var md := _settled(802, F.M_DROP, "3", true)
	r.check(md.f_dropper != null and md.f_dropper.dtag == "3", "B5 your M-DROP: D3 drops")
	var md2 := _settled(802, F.M_DROP, "3", false)
	r.check(md2.f_dropper != null and md2.f_dropper.dtag == "3", "B the computer's M-DROP: D3 drops (the middle is the middle)")
	# B6: the pistons press, block and foul as ever, the right ones
	for defending in [true, false]:
		var who := "yours" if defending else "the computer's"
		var n := DefenseFormation.slot(_play(1, defending), "4")
		var p := _settled(900 + int(defending), F.FOUR_FIVE, "3", defending, 2.0)
		var man := DefenseFormation.by_tag(p.attackers, n)
		p.give_ball(man)
		p.free_throw = false
		p._end_restart()   # (nor a restart: Play.restart)
		var d := DefenseFormation.by_tag(p.defenders, n, true)
		var states := {}
		var fouled := false
		var t := 0.0
		while t < 6.0 and not p.over:
			p.step(DT)
			t += DT
			states[d.press] = true
			for e in p.events:
				fouled = fouled or String(e.get("k", "")) == "piston_foul"
			p.events.clear()
		r.check(states.has(DefenseFormation.Press.APPROACH) and states.has(DefenseFormation.Press.BLOCK) and (fouled or states.has(DefenseFormation.Press.FOUL)),
			"B6 %s 4-5 DROP: the ball to spot 4 (A%s), D%s goes out, gets his arm up and fouls" % [who, n, n])
		var other := DefenseFormation.slot(_play(1, defending), "2")
		var q := _settled(950 + int(defending), F.FOUR_FIVE, "3", defending, 2.0)
		q.give_ball(DefenseFormation.by_tag(q.attackers, other))
		var od := DefenseFormation.by_tag(q.defenders, other, true)
		var never := true
		for k in 120:
			q.step(DT)
			never = never and od.press == DefenseFormation.Press.HOLD
		r.check(never, "B6 %s 4-5 DROP: spot 2's man (D%s) is no piston, he never presses" % [who, other])
	# what the computer weighs: the men its own drops would leave open
	var w := _settled(990, F.PRESS, "3", false, 0.0)
	var wm := DropCall.matchup(w.them, w.us)
	var base := DropCall.score(wm, true, DropCall.center_edge(wm.att.C, wm.def.C))
	wm.att["1"] = AttrBench.player({"sho": 1.0}, false, {}, PoloPlayer.Pos.UTILITY)
	var weak1 := DropCall.score(wm, true, DropCall.center_edge(wm.att.C, wm.def.C))
	r.check(weak1[F.FIVE_DROP] - weak1[F.M_DROP] > base[F.FIVE_DROP] - base[F.M_DROP],
		"B a poor shooter at A1: the computer's 5 DROP (which leaves him) scores better")
	# B7: no end changes in a match (Play always attacks x = 30, the screen turns round); the
	# orientation goes with which team defends, so it holds whichever possession it is
	r.check(DefenseFormation.slot(_play(2, false), "4") == "2" and DefenseFormation.slot(_play(3, true), "4") == "4",
		"B7 the orientation follows the defending team, possession after possession")

# ------------------------------------------------------------------ F. layouts
func _layouts() -> void:
	var shapes := [[Vector2(480, 270), Vector2.ZERO], [Vector2(584, 270), Vector2.ZERO], [Vector2(584, 270), Vector2(32, 32)],
		[Vector2(640, 270), Vector2(24, 24)], [Vector2(480, 320), Vector2.ZERO], [Vector2(480, 360), Vector2.ZERO], [Vector2(520, 270), Vector2.ZERO]]
	var player := AttrBench.player({}, false, {}, PoloPlayer.Pos.GK)
	var tag_w: float = Hud.tag_parts(player).size.x
	for sh in shapes:
		var size: Vector2 = sh[0]
		var ins: Vector2 = sh[1]
		var label := "%dx%d%s" % [size.x, size.y, " (notch)" if ins != Vector2.ZERO else ""]
		var screen := Rect2(Vector2.ZERO, size)
		var st := ShotStick.new()
		st.layout(size, ins)
		var area := st.area()
		var cs := CallStrip.new()
		cs.layout(area)
		r.check(screen.encloses(area) and area.position.y > PoolView.HUD_H and area.end.y < size.y - 16.0,
			"F %s: the stick on screen, clear of the scoreboard and the holder's tag" % label)
		r.check(st.rest.x >= ins.x + OLD_REST_X + 40.0 and area.position.x > ins.x + 40.0 and st.rest.x < size.x * 0.5,
			"C1 %s: the stick further right, in the open water (knob at %.0f, was %.0f)" % [label, st.rest.x, ins.x + OLD_REST_X])
		var b := cs.button
		r.check(screen.encloses(b) and b.position.y > 37.0, "F %s: DRIVE on screen, under the shot clock and the formation tag" % label)
		r.check(absf(b.get_center().x - area.get_center().x) <= 1.0 and b.end.y < area.position.y and area.position.y - b.end.y <= 8.0,
			"C3 %s: DRIVE right on top of the stick, centred, a small gap" % label)
		var apart := not b.intersects(area)
		for x: Rect2 in cs.rows.values():
			apart = apart and screen.encloses(x) and not x.intersects(b)
			for yy in range(int(x.position.y), int(x.end.y) + 1):
				for xx in range(int(x.position.x), int(x.end.x) + 1):
					apart = apart and not st.hit(Vector2(xx, yy))
		r.check(apart, "C6 %s: DRIVE and its strip never overlap the stick's touch area" % label)
		var fb := FormationBar.new()
		var left := ins.x + 3.0 + tag_w + 4.0
		fb.layout(size, ins, left)
		var rects := fb.rects
		var row := rects.size() == FormationBar.BUTTONS
		for i in rects.size():
			row = row and screen.encloses(rects[i]) and rects[i].size.y == rects[0].size.y and rects[i].position.y == rects[0].position.y
			if i > 0:
				row = row and is_equal_approx(rects[i].position.x - rects[i - 1].end.x, FormationBar.GAP) and not rects[i].grow(1.0).intersects(rects[i - 1].grow(1.0))
		r.check(row, "D2 %s: two buttons (PRESS, your drop) in one row, equal heights, even gaps, on screen" % label)
		r.check(rects[0].position.x >= left and rects[0].size.y >= 26.0 and rects[rects.size() - 1].end.x <= size.x - ins.y,
			"D1/D5 %s: tall (%.0f px, was 13), clear of your keeper's tag" % [label, rects[0].size.y])
		var order := true
		for i in rects.size():
			order = order and fb.hit(rects[i].get_center()) == i
		r.check(order, "D %s: PRESS | your drop, left to right" % label)

# ------------------------------------------------------------------ the match screen
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

## A pull like a real one: down, a few drags, up.
func _gesture(ms, from: Vector2, to: Vector2, index := 0) -> void:
	_touch(ms, from, true, index)
	for k in range(1, 5):
		_drag(ms, from.lerp(to, k / 4.0), index)
	_touch(ms, to, false, index)

func _screen() -> void:
	var ms = await _match(61)
	var p: Play = ms.flow.play
	var rest: Vector2 = ms.stick.rest
	var holder: Swimmer = p.holder
	var shot_pull := rest + Vector2(-60, -8)
	# C2/E1: a pull on the stick shoots, as it always has
	_touch(ms, rest, true)
	_drag(ms, shot_pull)
	await _frames(2)
	r.check(p.raised and ms.aim.stick and ms.aim.long_enough(), "E1 the stick pulled back: he lifts it to shoot")
	_touch(ms, shot_pull, false)
	r.check(_shots(p) == 1, "E1 ...let go: a shot")
	# E2: a pull back on the open water
	ms = await _match(62)
	p = ms.flow.play
	holder = p.holder
	var water := Vector2(ms.get_viewport_rect().size.x * 0.7, ms.get_viewport_rect().size.y * 0.55)
	r.check(not ms.stick.hit(water), "(that's open water)")
	_touch(ms, water, true)
	for k in range(1, 5):
		_drag(ms, water + AimGuide.pull_for(holder, Vector2(31.0, 9.5)) * k / 4.0)
	await _frames(2)
	r.check(not p.raised and not ms.aim.stick, "E2 a pull back on the water: no ball up, no aim")
	_touch(ms, water + AimGuide.pull_for(holder, Vector2(31.0, 9.5)), false)
	r.check(_shots(p) == 0 and p.holder == holder and p.ball.state == Ball.State.HELD, "E2 ...let go: no shot, no pass")
	# E3: a pull from a player (the man with the ball, a teammate)
	for who in [holder, _mate(ms, p)]:
		var at: Vector2 = ms.view.to_screen((who as Swimmer).pos) + Vector2(0, -5)
		if ms.stick.hit(at):
			continue
		_gesture(ms, at, at + Vector2(-70, 20))
		r.check(_shots(p) == 0 and p.holder == holder, "E3 a pull from a player (%s): no shot" % ("the man with it" if who == holder else "a teammate"))
	# E3: the scoreboard and the holder's tag
	for at in [Vector2(ms.get_viewport_rect().size.x * 0.5, 12), Vector2(30, ms.get_viewport_rect().size.y - 8)]:
		_gesture(ms, at, at + Vector2(-60, 0))
		r.check(_shots(p) == 0 and p.holder == holder, "E3 a pull from %s: no shot" % ("the scoreboard" if at.y < 30 else "the player tag"))
	# E4: from outside the stick, dragged onto it
	var outside: Vector2 = ms.stick.area().end + Vector2(30, -20)
	r.check(not ms.stick.hit(outside), "(that's off the stick)")
	_gesture(ms, outside, rest + Vector2(-40, 0))
	r.check(_shots(p) == 0 and not p.raised and p.holder == holder, "E4 a touch from off the stick dragged onto it: never a shot")
	# E11: where the stick used to be (its wide end, now off it)
	var old := Vector2(ms._insets().x + 20.0, rest.y)
	r.check(not ms.stick.hit(old), "(the old stick's wide end is off the new one)")
	_gesture(ms, old, old + Vector2(-15, 10))
	_gesture(ms, old, old + Vector2(40, 0))
	r.check(_shots(p) == 0 and p.holder == holder, "E11 a pull where the stick used to be: no shot")
	# E5: from the stick, out past its edge, let go out there: a shot
	_touch(ms, rest, true)
	_drag(ms, rest + Vector2(-80, 40))
	_drag(ms, rest + Vector2(-120, 70))
	await _frames(2)
	r.check(not ms.stick.hit(rest + Vector2(-120, 70)) and ms.aim.stick and p.raised, "E5 dragged out past the stick: still the stick's")
	_touch(ms, rest + Vector2(-120, 70), false)
	r.check(_shots(p) == 1, "E5 ...let go out there: the shot")
	# C5/C6/E6: DRIVE
	ms = await _match(63)
	p = ms.flow.play
	holder = p.holder
	await _frames(1)
	var b: Rect2 = ms.calls.button
	r.check(b.size.x >= 72.0 and b.size.y >= 27.0 and absf(b.size.x / 50.0 - 1.5) < 0.1 and absf(b.size.y / 19.0 - 1.5) < 0.1,
		"C4 DRIVE is half as big again (%.0f x %.0f, was 50 x 19)" % [b.size.x, b.size.y])
	r.check(ms.calls.button.get_center().y < ms.stick.rest.y and absf(b.get_center().x - ms.stick.area().get_center().x) <= 1.0,
		"C3 DRIVE sits on top of the stick")
	_touch(ms, Vector2(b.position.x + 2, b.end.y - 2), true)
	_drag(ms, Vector2(b.position.x - 50, b.end.y + 20))
	_touch(ms, Vector2(b.position.x - 50, b.end.y + 20), false)
	r.check(ms.calls.open and not ms.aim.active and _shots(p) == 0, "C4/E6 a touch anywhere on DRIVE opens it, pulled or not: no shot")
	var row: Rect2 = ms.calls.rows["left"]
	var side := "left" if p.drive_candidate("left") != null else ("right" if p.drive_candidate("right") != null else "middle")
	row = ms.calls.rows[side]
	_touch(ms, row.get_center(), true)
	_touch(ms, row.get_center(), false)
	r.check(not ms.calls.open and _shots(p) == 0 and p.holder == holder, "C5/E6 a call from its strip: the drive's on, no shot")
	_touch(ms, ms.stick.rest, true)
	_touch(ms, ms.stick.rest, false)
	r.check(not ms.calls.open, "C6 a touch on the stick never opens DRIVE")
	# E9: a second finger, on DRIVE and on the water, mid-pull
	_touch(ms, ms.stick.rest, true, 0)
	_drag(ms, ms.stick.rest + Vector2(-55, 6), 0)
	await _frames(1)
	_touch(ms, b.get_center(), true, 1)
	_touch(ms, b.get_center(), false, 1)
	_gesture(ms, water, water + Vector2(-80, 0), 2)
	_touch(ms, ms.stick.rest + Vector2(-10, 0), false, 3)
	r.check(ms.aim.active and ms.aim.index == 0 and _shots(p) == 0 and not ms.calls.open,
		"E9 other fingers mid-pull: they neither shoot, nor let go of it, nor call a drive")
	_touch(ms, ms.stick.rest + Vector2(-55, 6), false, 0)
	r.check(_shots(p) == 1, "E9 ...the finger on the stick lets go: one shot")
	# E8: cancelled
	ms = await _match(64)
	p = ms.flow.play
	_touch(ms, ms.stick.rest, true)
	_drag(ms, ms.stick.rest + Vector2(-60, 0))
	await _frames(1)
	_touch(ms, ms.stick.rest + Vector2(-60, 0), false, 0, true)
	r.check(_shots(p) == 0 and not ms.aim.active, "E8 a cancelled touch: no shot, the aim gone")
	await _frames(2)
	r.check(not p.raised and p.ball.state == Ball.State.HELD, "E8 ...and he puts the ball back down")
	# a cancelled tap on the water passes nothing either
	var mate := _mate(ms, p)
	var mate_at: Vector2 = ms.view.to_screen(mate.pos) + Vector2(0, -5)
	_touch(ms, mate_at, true)
	_touch(ms, mate_at, false, 0, true)
	r.check(p.ball.state == Ball.State.HELD, "E8 ...nor a pass")
	_touch(ms, mate_at, true)
	_touch(ms, mate_at, false)
	r.check(p.ball.state == Ball.State.PASS and p.ball.receiver == mate, "a tap on a teammate still passes")
	# catch and shoot: the stick taken while the pass is on its way, let go once he has it
	_touch(ms, ms.stick.rest, true)
	_drag(ms, ms.stick.rest + Vector2(-50, 0))
	r.check(ms.aim.stick, "the stick's up while your pass is on its way (catch and shoot)")
	for k in 120:
		await _frames(1)
		if p.holder == mate:
			break
	await _frames(2)
	_touch(ms, ms.stick.rest + Vector2(-50, 0), false)
	r.check(p.holder == null and _shots(p) == 1, "...he catches it and the release shoots")
	# E10: the ball's lost mid-pull
	ms = await _match(65)
	p = ms.flow.play
	_touch(ms, ms.stick.rest, true)
	_drag(ms, ms.stick.rest + Vector2(-60, 0))
	await _frames(1)
	p._turnover(p.defenders[1], "STOLEN!", "steal")
	await _frames(2)
	_touch(ms, ms.stick.rest + Vector2(-60, 0), false)
	r.check(_shots(p) == 0 and not ms.aim.active, "E10 the ball lost mid-pull: it lets go, no shot")
	# C1/F: the controls don't move with the camera
	ms = await _match(66)
	await _frames(1)
	var r0: Vector2 = ms.stick.rest
	var b0: Rect2 = ms.calls.button
	ms.view.cam += Vector2(3.0, 2.0)
	ms._process(DT)
	ms.canvas.queue_redraw()
	await _frames(1)
	r.check(ms.stick.rest == r0 and ms.calls.button == b0, "F the stick and DRIVE stay put when the camera moves")
	# E7/D: your defence: the bar, no stick
	ms.flow._start_defense(Play.Kind.HALF_COURT)
	ms._process(DT)
	await _frames(2)
	var dp: Play = ms.flow.play
	r.check(not ms._stick_ready(dp) and FormationBar.shown(ms.flow), "D/E7 their ball: the bar's up, the stick isn't")
	var dholder := dp.holder
	_touch(ms, ms.stick.rest, true)
	_drag(ms, ms.stick.rest + Vector2(-60, 0))
	r.check(not ms.aim.active and not dp.raised, "E7 a pull where the stick is on their ball: nothing to aim")
	_touch(ms, ms.stick.rest + Vector2(-60, 0), false)
	r.check(not ms.aim.active and _shots(dp) == 0 and dp.holder == dholder, "E7 ...and no shot")
	var rects: Array[Rect2] = ms.fbar.rects
	r.check(rects.size() == 2 and rects[0].size.y >= 26.0, "D1 the buttons are tall in the match (%.0f px)" % (rects[0].size.y if rects.size() > 0 else 0.0))
	var tag_end: float = ms._insets().x + 3.0 + Hud.tag_parts(dp.keeper.player).size.x
	r.check(rects.size() == 2 and rects[0].position.x > tag_end, "D5 ...clear of your keeper's tag")
	# D3/D4: a touch at a corner of the drop button (4-5 DROP here: its top-left, far above the old 13 px bar) picks it
	ms.flow.drop = F.FOUR_FIVE
	var corner := rects[1].position + Vector2(1, 1)
	r.check(corner.y < ms.get_viewport_rect().size.y - 17.0, "(that corner is above where the old bar ended)")
	_touch(ms, corner, true)
	_touch(ms, corner, false)
	r.check(dp.formation == F.FOUR_FIVE and dp.formation_locked, "D3/D4 the top corner of 4-5 DROP picks it")
	# D4: each of the two can be picked (a fresh possession each), at its top edge
	var picked := 0
	for i in 2:
		ms.flow._start_defense(Play.Kind.HALF_COURT)
		ms._process(DT)
		await _frames(1)
		var rr: Array[Rect2] = ms.fbar.rects
		var top := Vector2(rr[i].get_center().x, rr[i].position.y + 1)
		_touch(ms, top, true)
		_touch(ms, top, false)
		picked += 1 if ms.flow.play.formation == ms.flow.user_formations()[i] and ms.flow.play.formation_locked else 0
	r.check(picked == 2, "D4 both picked from their top edge (%d / 2)" % picked)
	Game.save_settings()
	Game.goto("title")
	await _frames(1)
	await _duel()

## A teammate of the man with the ball, off the stick.
func _mate(ms, p: Play) -> Swimmer:
	for a in p.attackers:
		if a != p.holder and not a.out and not ms.stick.hit(ms.view.to_screen(a.pos) + Vector2(0, -5)):
			return a
	return null

## A: the shootout (you in goal, MatchScreen's own duel): a save goes into his hands and stays.
func _duel() -> void:
	var ms = await _match(67)
	var flow: MatchFlow = ms.flow
	var shooter: PoloPlayer = flow.them.starters()[1]
	flow.opp = {"shooter": shooter, "shot": true, "from": Vector2(5.0, Geo.GOAL_Y)}
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	flow.duel = KeeperDuel.new().setup(shooter, flow.us.keeper(), Vector2(5.0, Geo.GOAL_Y), 0.0, rng, 0.5, true)
	flow.phase = MatchFlow.Phase.THEIR_SHOT
	ms._start_duel()
	var d: KeeperDuel = flow.duel
	d.anim = d._new_dive(-1)
	d.anim.t = d.anim.extend_time() + 0.01
	d.keeper_y = d.anim.body_y()
	d.cross_y = d.anim.tip_y()
	d.state = KeeperDuel.State.DONE
	d.outcome = "save"
	ms._duel_result(d)
	var gk: Swimmer = ms.duel_bodies[0]
	var v: PoolView = ms.view
	var b: Ball = ms.duel_ball
	r.check(b != null and b.state == Ball.State.HELD and b.pos.distance_to(Vector2(d.goal_x, d.cross_y)) < 0.001,
		"A the shootout save: the ball starts from where it met his hand")
	var last := _scr(v, _b3(b))
	var jump := 0.0
	var off := 0.0
	var t := 0.0
	while t < 1.4:
		ms._tick_duel(DT)
		t += DT
		var now := _scr(v, _b3(b))
		jump = maxf(jump, now.distance_to(last))
		last = now
		if b.secure_t >= Ball.SECURE_TIME:
			off = maxf(off, _b3(b).distance_to(Play.held_at(gk)))
	r.check(jump < JUMP and off < 0.001 and gk.pose == null,
		"A the shootout save: into his hands and kept there through his fall and recovery (%.1f px, %.4f m)" % [jump, off])
	Game.goto("title")
	await _frames(1)

# ------------------------------------------------------------------ screenshots
## godot --path game -- --test goalie_tweaks_png <outdir>   (needs a window)
## A save in a match, frame by frame (the catch, his hold, his fall, back up), and the controls:
## your attack (the stick, DRIVE on it, its strip open) and your defence (the tall bar).
static func shots(runner, dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	var save := func(name: String) -> void:
		await RenderingServer.frame_post_draw
		runner.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [dir, name])
		print("  shot ", name)
	var t = load("res://tests/goalie_tweaks_test.gd").new()
	t.r = runner
	var ms = await t._match(61)
	await save.call("attack")
	ms.calls.open = true
	await runner.get_tree().process_frame
	await save.call("attack_drive_open")
	ms.calls.open = false
	# a save: the keeper up the screen at full stretch, the ball into his hand
	for side in [-1, 1, 0]:
		ms = await t._match(70 + side)
		var p: Play = ms.flow.play
		Engine.time_scale = 0.0001
		var pose := _dive(p, side, 0.0)
		pose.t = pose.extend_time() + 0.01
		t._saved(p, pose, 0.7 if side != 0 else 0.2)
		var name: String = ["up", "centre", "down"][side + 1]
		var at := 0.0
		for snap in [0.0, 0.05, 0.1, 0.17, 0.3, 0.45, 0.55, 0.65, 0.8, 1.2]:
			while at < snap - 0.001:
				ms._process(DT)
				at += DT
			await runner.get_tree().process_frame
			var ph: String = KeeperDive.Phase.keys()[p.keeper.pose.phase()] if p.keeper.pose != null else "HELD"
			var kp: Vector2 = ms.view.to_screen(p.keeper.pos)
			await save.call("save_%s_%03d_%s_%d_%d" % [name, roundi(snap * 100), ph.to_lower(), kp.x, kp.y])
		Engine.time_scale = 1.0
	# your defence: the bar
	ms = await t._match(75)
	ms.flow._start_defense(Play.Kind.HALF_COURT)
	ms._process(DT)
	for k in 30:
		await runner.get_tree().process_frame
	await save.call("defence_bar")
	Game.save_settings()
	Game.goto("title")

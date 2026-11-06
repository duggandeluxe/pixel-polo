extends RefCounted
## The goalkeeper overhaul (anticipation, reaction, panic recovery) and the first-pass centre entry:
##   godot --headless --path game -- --test keeper_overhaul           (the checks: A-K the keeper, L-T the centre)
##   godot --headless --path game -- --test keeper_overhaul_balance [n] (the numbers; see also --test keeper_measure)
## Fixed seeds throughout.

var r
const DT := 1.0 / 60.0

func run(runner) -> void:
	r = runner
	print("keeper overhaul: reaction")
	_a_b_fast_sides()
	_c_correct_anticipation()
	_d_wrong_anticipation()
	_e_wrong_jump_central()
	_f_elite_keeper()
	_g_upper_corner()
	_h_central_shot()
	_i_minor_lean()
	_j_visual_contact()
	_k_high_speed()
	_commitment_and_attributes()
	print("keeper overhaul: first pass into the centre")
	_l_first_pass_through()
	_m_n_around_and_out_of_position()
	_o_second_pass()
	_p_q_deflect_and_steal()
	_r_s_possession_reset()
	_t_no_keeper_steal()

# ------------------------------------------------------------------ helpers
func _keeper(v: float = 5.0, vals: Dictionary = {}) -> PoloPlayer:
	var a := {"com": v, "lun": v, "blk": v, "leg": v}
	a.merge(vals, true)
	return AttrBench.player(a, true)

func _ctx(keeper: PoloPlayer, extra: Dictionary = {}) -> Dictionary:
	var c := AttrBench.shot_ctx(AttrBench.player({}), null, keeper, INF)
	c["exact"] = true
	c["iq"] = 0.5
	c.merge(extra, true)
	return c

func _rng(seed_value: int) -> RandomNumberGenerator:
	var g := RandomNumberGenerator.new()
	g.seed = seed_value
	return g

## `n` shots at `keeper` from `from`, aims from `aim` (Callable(rng) -> y), power `power`:
## {saves, goals, n, res (all results)}.
func _shots(keeper: PoloPlayer, from: Vector2, aim: Callable, power: float, extra: Dictionary, n: int, seed_value: int, keeper_y := Geo.GOAL_Y) -> Dictionary:
	var rng := _rng(seed_value)
	var arng := _rng(seed_value + 1)
	var out := {"saves": 0, "goals": 0, "n": 0, "res": []}
	for i in n:
		var res := ShotModel.resolve(from, float(aim.call(arng)), power, 62.0, 4.0, [], keeper_y, 62.0, rng, false, {}, _ctx(keeper, extra))
		var o := String(res.outcome)
		if o in ["miss", "post"]:
			continue
		out.n += 1
		out.saves += int(o in ["save", "parry"])
		out.goals += int(o == "goal")
		out.res.append(res)
	return out

func _rate(d: Dictionary) -> float:
	return float(d.saves) / maxf(1.0, float(d.n))

# ------------------------------------------------------------------ A, B. fast shots either side, no commitment
func _a_b_fast_sides() -> void:
	var k := _keeper()
	for way in [-1, 1]:
		var t := _shots(k, Vector2(25.0, 10.0), func(g): return Geo.GOAL_Y + way * g.randf_range(0.8, 1.4), 1.0, {"commit": false}, 400, 10 + way)
		var toward := 0
		var away := 0
		for res in t.res:
			toward += int(int(res.guess) == way)
			away += int(int(res.guess) == -way)
		var name := "LEFT" if way < 0 else "RIGHT"
		print("  fast %s shots, no commitment: dived %s %d of %d, the other way %d; saves %.2f" % [name, name, toward, t.n, away, _rate(t)])
		r.check(toward == t.n and away == 0, "%s: he reacts %s every time, never a random dive the other way" % ["A" if way < 0 else "B", name])
		r.check(int(t.goals) > 0, "...and a goal is still possible (speed, reach): %d goals" % int(t.goals))

# ------------------------------------------------------------------ C. right anticipation
func _c_correct_anticipation() -> void:
	var k := _keeper()
	var aim := func(g): return Geo.GOAL_Y - g.randf_range(0.8, 1.45)
	var from := Vector2(26.0, 10.0)
	var early := _shots(k, from, aim, 0.95, {"read_side": -1, "commit": true, "lead": 0.12, "hold": 2.0}, 600, 31)
	var late := _shots(k, from, aim, 0.95, {"commit": false}, 600, 31)
	var go_e := 0.0
	var go_l := 0.0
	var antic := 0
	for res in early.res:
		go_e += float(res.keeper_go)
		antic += int(String(res.gk.kind) == "anticipated")
	for res in late.res:
		go_l += float(res.keeper_go)
	go_e /= maxf(1.0, early.n)
	go_l /= maxf(1.0, late.n)
	print("  C: left shots, he went left early: set off %.3f s (reacting: %.3f s), saves %.2f (reacting %.2f), anticipated %d of %d" % [go_e, go_l, _rate(early), _rate(late), antic, early.n])
	r.check(antic == early.n and go_e < go_l - 0.1, "C: going the right way early gets him moving sooner")
	r.check(_rate(early) > _rate(late) and _rate(early) < 1.0, "...more saves, never all of them")

# ------------------------------------------------------------------ D. wrong anticipation, fully committed
func _d_wrong_anticipation() -> void:
	var k := _keeper()
	var t := _shots(k, Vector2(27.0, 10.0), func(g): return Geo.GOAL_Y + g.randf_range(0.8, 1.4), 0.85,
		{"read_side": -1, "commit": true, "commit_go": -0.2, "hold": 2.0}, 500, 41)
	var panic := 0
	var full := 0
	var stranded := 0
	var back := true
	for res in t.res:
		stranded += int(String(res.gk.kind) == "stranded")
		if String(res.gk.kind) != "panic":
			continue
		panic += 1
		full += int(int(res.gk.commit) == KeeperDive.Commit.FULL)
		var d := KeeperDive.from_dict(res.dive)
		d.t = d.turn_t + 0.01
		var y1 := d.body_y()
		d.t = d.turn_t + 0.3
		back = back and d.body_y() > y1 + 0.03 and d.phase() in [KeeperDive.Phase.PANIC, KeeperDive.Phase.FALL]
	print("  D: committed LEFT, shot RIGHT: panic %d of %d (full commitment %d; already falling back in %d), saves %d" % [panic, t.n, full, stranded, int(t.saves)])
	r.check(panic + stranded == t.n and panic > t.n * 0.8 and full > t.n * 0.7, "D: panic recovery whenever he's committed the wrong way and still up")
	r.check(back, "...he claws back towards the middle (no teleport: his body moves back over time)")
	r.check(int(t.saves) == 0, "...and never saves the right-side shot")

# ------------------------------------------------------------------ E. wrong jump, central shot
func _e_wrong_jump_central() -> void:
	var k := _keeper()
	var aim := func(g): return Geo.GOAL_Y - g.randf_range(0.05, 0.3)
	var ctx := {"read_side": -1, "commit": true, "commit_go": -0.12, "hold": 2.0}
	var slow := _shots(k, Vector2(22.5, 10.0), aim, 0.2, ctx, 500, 51)
	var fast := _shots(k, Vector2(27.0, 10.0), aim, 1.0, ctx, 500, 52)
	# only the ones he went past (the panics): a central ball his dive still had on its way is no recovery
	var ps := func(d: Dictionary) -> Vector2:
		var v := Vector2.ZERO
		for res in d.res:
			if String(res.gk.kind) == "panic":
				v += Vector2(1.0 if String(res.outcome) in ["save", "parry"] else 0.0, 1.0)
		return v
	var vs: Vector2 = ps.call(slow)
	var vf: Vector2 = ps.call(fast)
	print("  E: committed LEFT, central shot, panics: slow from range %d saved of %d, fast close in %d of %d" % [int(vs.x), int(vs.y), int(vf.x), int(vf.y)])
	r.check(vs.y > 50 and vf.y > 50, "E: a central ball he'd committed past is a panic")
	r.check(vs.x > 0 and vs.x / vs.y > vf.x / vf.y + 0.05, "...a slow one he can sometimes claw back, a fast one hardly ever")

# ------------------------------------------------------------------ F. an elite keeper still can't cross the goal
func _f_elite_keeper() -> void:
	var elite := _keeper(10.0)
	var avg := _keeper(5.0)
	var aim := func(g): return Geo.GOAL_Y + g.randf_range(0.6, 1.4)
	var ctx := {"read_side": -1, "commit": true, "commit_go": -0.12, "hold": 2.0}
	var saves := 0
	var n := 0
	for from in [Vector2(22.5, 10.0), Vector2(24.0, 10.0), Vector2(26.0, 10.0), Vector2(27.5, 10.0)]:
		for power in [0.2, 0.6, 1.0]:
			var t := _shots(elite, from, aim, power, ctx, 150, 61)
			saves += int(t.saves)
			n += int(t.n)
	# the same panic, an elite pair of legs and feet against an average one: he gets back further, sooner
	var mk := func(kp: PoloPlayer) -> KeeperDive:
		var d := KeeperDive.from_body(KeeperDive.body_of(kp), KeeperDive.LEFT, Geo.GOAL_Y)
		d.turn(d.extend_time() + 0.02, Geo.GOAL_Y + 1.2)
		return d
	var de: KeeperDive = mk.call(elite)
	var da: KeeperDive = mk.call(avg)
	var gain := func(d: KeeperDive) -> float:
		d.t = d.turn_t + 0.01
		var y0 := d.body_y()
		d.t = d.turn_t + 0.22
		return d.body_y() - y0
	var ge: float = gain.call(de)
	var ga: float = gain.call(da)
	var wall_ok := de.covers(Geo.GOAL_Y + KeeperDive.PANIC_WALL.y + 0.05) < 0.0 and de.covers(Geo.GOAL_Y + 1.2) < 0.0
	print("  F: elite keeper committed LEFT, right-side shots: %d saves of %d; clawed back %.2f m in the panic's first 0.2 s (average keeper %.2f)" % [saves, n, ge, ga])
	r.check(saves == 0, "F: even a 10 in everything never saves the far side once he's fully committed")
	r.check(ge > ga, "...he recovers faster towards the middle than an average keeper")
	r.check(wall_ok, "...but never covers past his wall, whatever he's got")

# ------------------------------------------------------------------ G. fast top corner
func _g_upper_corner() -> void:
	var aim := func(g): return Geo.GOAL_Y + (1.0 if g.randf() < 0.5 else -1.0) * g.randf_range(1.0, 1.35)
	var top := {"commit": false, "height": 0.97}
	var weak := _shots(_keeper(5.0, {"leg": 1.0}), Vector2(23.5, 10.0), aim, 0.6, top, 600, 71)
	var strong := _shots(_keeper(5.0, {"leg": 9.0}), Vector2(23.5, 10.0), aim, 0.6, top, 600, 71)
	var hands := _shots(_keeper(5.0, {"leg": 0.0, "blk": 10.0}), Vector2(23.5, 10.0), aim, 0.6, top, 600, 71)
	var right := 0
	for res in weak.res:
		right += int(int(res.guess) == int(signf(float(res.cross_y) - Geo.GOAL_Y)))
	print("  G: top-corner shots from 6.5 m: saved by leg 1 %.2f, leg 9 %.2f, leg 0 / blocking 10 %.2f (the right way %d of %d)" % [_rate(weak), _rate(strong), _rate(hands), right, weak.n])
	r.check(right == weak.n and int(weak.goals) > 0, "G: he goes the right way, and the top corner still beats him")
	r.check(_rate(strong) > _rate(weak), "...LEG STRENGTH gets him up to more of them")
	r.check(_rate(hands) < 0.5, "...great hands and weak legs don't save the top corner")

# ------------------------------------------------------------------ H. straight at him
func _h_central_shot() -> void:
	var k := _keeper()
	var central := _shots(k, Vector2(25.0, 10.0), func(g): return Geo.GOAL_Y + g.randf_range(-0.2, 0.2), 0.9, {"commit": false}, 500, 81)
	var corner := _shots(k, Vector2(25.0, 10.0), func(g): return Geo.GOAL_Y + (1.0 if g.randf() < 0.5 else -1.0) * g.randf_range(1.0, 1.4), 0.9, {"commit": false}, 500, 81)
	var up := 0
	for res in central.res:
		up += int(int(res.guess) == KeeperDive.CENTRE)
	print("  H: shots at him: blocked up %d of %d, saved %.2f; corners saved %.2f" % [up, central.n, _rate(central), _rate(corner)])
	r.check(up > central.n * 0.9, "H: a shot at him is a block straight up")
	r.check(_rate(central) > _rate(corner) + 0.2, "...and much easier to stop than a corner")

# ------------------------------------------------------------------ I. a lean the wrong way
func _i_minor_lean() -> void:
	var k := _keeper()
	# he'd shaded left (a lean: LEAN_MAX up the screen) and it goes right
	var rng := _rng(91)
	var ok := true
	for i in 300:
		var aim := Geo.GOAL_Y + rng.randf_range(0.8, 1.3)
		var ky := Geo.GOAL_Y - KeeperAI.LEAN_MAX
		var a := ShotModel.resolve(Vector2(25.0, 10.0), aim, 0.8, 62.0, 4.0, [], ky, 62.0, rng, false, {}, _ctx(k, {"commit": false, "read_side": -1, "lean_y": Geo.GOAL_Y}))
		ok = ok and String(a.gk.kind) == "react" and int(a.guess) == KeeperDive.RIGHT and not KeeperDive.from_dict(a.dive).turned()
	r.check(ok, "I: leaned the wrong way: a normal dive the right way, no panic")
	# barely set off the wrong way (Commit.MINIMAL): a quick correction, a new dive the right way
	var corr := 0
	var corr_ok := true
	var panics_minimal := 0
	rng = _rng(92)
	for i in 600:
		var res := ShotModel.resolve(Vector2(24.5, 10.0), Geo.GOAL_Y + rng.randf_range(0.8, 1.3), 0.7, 62.0, 4.0, [], Geo.GOAL_Y, 62.0, rng, false, {},
			_ctx(k, {"read_side": -1, "commit": true, "commit_go": 0.33}))
		if String(res.gk.kind) == "correction":
			corr += 1
			corr_ok = corr_ok and int(res.gk.commit) <= KeeperDive.Commit.MINIMAL and int(res.guess) == KeeperDive.RIGHT and res.has("redive")
		if String(res.gk.kind) == "panic" and int(res.gk.commit) <= KeeperDive.Commit.MINIMAL:
			panics_minimal += 1
	print("  I: a lean the wrong way: %d quick corrections (new dive the right way), %d panics from a lean" % [corr, panics_minimal])
	r.check(corr > 20 and corr_ok and panics_minimal == 0, "...barely set off the wrong way: a quick correction, never the full panic")

# ------------------------------------------------------------------ J. what you see is what saves it
func _j_visual_contact() -> void:
	var rng := _rng(101)
	var k := _keeper(6.0)
	var bad := 0
	var saves := 0
	var goals := 0
	for i in 2000:
		var from := Vector2(rng.randf_range(23.0, 28.0), rng.randf_range(7.5, 12.5))
		var res := ShotModel.resolve(from, Geo.GOAL_Y + rng.randf_range(-1.4, 1.4), rng.randf_range(0.3, 1.0), 62.0, 4.0, [], Geo.GOAL_Y, 62.0, rng, false, {},
			_ctx(k, {"hold": rng.randf_range(0.0, 2.0), "read_side": [-1, 0, 1][i % 3]}))
		var o := String(res.outcome)
		if not o in ["save", "parry", "goal"]:
			continue
		# the dive Play draws (the same dicts), at the moment the ball is at his hands
		var t_at := float(res.flight) if o != "goal" else from.distance_to(ShotModel.on_line(from, float(res.cross_y), Geo.KEEPER_X)) / float(res.speed)
		var d := KeeperDive.from_dict(res.dive)
		d.t = t_at - float(res.keeper_go)
		if res.has("redive") and t_at >= float(res.redive_go):
			d = KeeperDive.from_dict(res.redive)
			d.t = t_at - float(res.redive_go)
		var y := (res.end as Vector2).y if o != "goal" else ShotModel.on_line(from, float(res.cross_y), Geo.KEEPER_X).y
		var ph := d.phase() if d.t >= 0.0 else KeeperDive.Phase.READY
		var in_hands := d.covers(y) >= 0.0 if not ph in [KeeperDive.Phase.REACT, KeeperDive.Phase.RECOVER, KeeperDive.Phase.READY] \
			else absf(y - (d.body_y() if d.t >= 0.0 else Geo.GOAL_Y)) <= KeeperDuel.BODY_R
		if o == "goal":
			goals += 1
			bad += int(in_hands and not bool(res.get("touched", false)))
		else:
			saves += 1
			bad += int(not in_hands)
	print("  J: %d saves, %d goals checked against the dive drawn: %d don't match" % [saves, goals, bad])
	r.check(bad == 0 and saves > 100 and goals > 100, "J: every save is a ball in the hands you see, every goal (bar a ball through his hands) one outside them")

# ------------------------------------------------------------------ K. no tunnelling
func _k_high_speed() -> void:
	var d := KeeperDive.from_body(KeeperDive.body_of(_keeper()), KeeperDive.RIGHT, Geo.GOAL_Y)
	var from := Vector2(24.0, 10.0)
	var cross := Geo.GOAL_Y + 0.9
	var found := true
	var framed_miss := 0
	for speed: float in [12.0, 30.0, 80.0, 200.0, 600.0]:
		var at_t: float = from.distance_to(ShotModel.on_line(from, cross, Geo.KEEPER_X)) / speed
		var go: float = at_t - (d.extend_time() + 0.05)   # he's up as it gets there
		var c := ShotModel._contact(from, cross, speed, d, go, null, INF, Geo.GOAL_Y)
		found = found and float(c.at) >= 0.0
		# a frame-by-frame look (60 fps) at the ball's position against his line can step right past him
		var t := 0.0
		var seen := false
		while t < at_t + 0.1:
			var p := from.lerp(Vector2(Geo.GOAL_X, cross), clampf(t * speed / from.distance_to(Vector2(Geo.GOAL_X, cross)), 0.0, 1.0))
			if absf(p.x - Geo.KEEPER_X) <= ShotModel.KEEPER_DEPTH:
				seen = true
			t += DT
		framed_miss += int(not seen)
	print("  K: contact found at every pace up to 600 m/s; a 60 fps frame check would have missed %d of 5" % framed_miss)
	r.check(found, "K: the ball's whole path through him is checked: no pace tunnels through his hands")
	r.check(framed_miss > 0, "...(where a frame-by-frame check would have let some through)")

# ------------------------------------------------------------------ commitment and the attributes' jobs
func _commitment_and_attributes() -> void:
	var d := KeeperDive.from_body(KeeperDive.body_of(_keeper()), KeeperDive.LEFT, Geo.GOAL_Y)
	var levels := [d.commitment_at(0.0), d.commitment_at(d.react_time() + 0.005), d.commitment_at(d.react_time() + 0.04), d.commitment_at(d.extend_time() + 0.05)]
	r.check(levels == [KeeperDive.Commit.NONE, KeeperDive.Commit.MINIMAL, KeeperDive.Commit.PARTIAL, KeeperDive.Commit.FULL],
		"commitment comes from how far into the dive he is: none, minimal, partial, full (%s)" % str(levels))
	# the more committed, the less he gets back
	var back := func(at: float) -> float:
		var dv := KeeperDive.from_body(KeeperDive.body_of(_keeper()), KeeperDive.LEFT, Geo.GOAL_Y)
		dv.turn(at, Geo.GOAL_Y + 1.0)
		dv.t = at + 0.12
		return dv.tip_y()
	r.check(float(back.call(d.react_time() + 0.04)) > float(back.call(d.extend_time() + 0.1)), "a partial commitment gets further back than a full one")
	# COMMUNICATION never touches his saves; LUNGE SPEED his reaction, never his reach
	var same := true
	for i in 200:
		var a := ShotModel.resolve(Vector2(25.0, 10.0), 11.0, 0.8, 62.0, 4.0, [], 10.0, 62.0, _rng(500 + i), false, {}, _ctx(_keeper(5.0, {"com": 0.0}), {"hold": 1.0}))
		var b := ShotModel.resolve(Vector2(25.0, 10.0), 11.0, 0.8, 62.0, 4.0, [], 10.0, 62.0, _rng(500 + i), false, {}, _ctx(_keeper(5.0, {"com": 10.0}), {"hold": 1.0}))
		same = same and a.outcome == b.outcome and a.keeper_go == b.keeper_go and a.guess == b.guess
	r.check(same, "COMMUNICATION changes nothing about his reaction, reach or saves")
	var fast := KeeperDive.body_of(_keeper(5.0, {"lun": 10.0}))
	var slow := KeeperDive.body_of(_keeper(5.0, {"lun": 0.0}))
	r.check(KeeperAI.recognize_time(1.0, 0.8) < KeeperAI.recognize_time(0.0, 1.2) and is_equal_approx(float(fast.lunge) + float(fast.arm), float(slow.lunge) + float(slow.arm)),
		"LUNGE SPEED: he sees it and moves sooner, never further")

# ------------------------------------------------------------------ the centre
## A set half court (test_runner._center_play): the ball with `from_tag`, the centre's man
## `ahead` m out from him towards the ball and `wide` m off that line. First pass not yet thrown.
func _entry_play(seed_value: int, from_tag: String, ahead: float, wide: float) -> Play:
	var p: Play = r._center_play(seed_value, false)
	for a in p.attackers:
		a.player.trait_id = ""
	for d in p.defenders:
		d.player.trait_id = ""
	p.give_ball(PlaySetup._by_tag(p, from_tag))
	var c := PlaySetup._by_tag(p, "C")
	var g := p._center_guard(c)
	if g == null:
		for d in p.defenders:
			if d.mark == c:
				g = d
	var to_ball := (p.holder.pos - c.pos).normalized()
	g.pos = c.pos + to_ball * ahead + to_ball.orthogonal() * wide
	g.target = g.pos
	g.cswitch = 0.0
	return p

## Just off the line of the entry (Play.ENTRY_LANE_R: not fronting him) and still inside his reach
## (DefenseFormation.TIP_REACH): the hole the first-pass rule closes.
const OFF_LANE := 0.53

## Throws the first pass in to the centre and plays it out: "steal", "loose", "catch", "other".
func _feed(p: Play) -> String:
	var c := PlaySetup._by_tag(p, "C")
	p.pass_to(c)
	var t := 0.0
	while p.ball.state == Ball.State.PASS and t < 2.0:
		p.step(DT)
		t += DT
	if p.over:
		return String(p.result.outcome)
	if p.ball.state == Ball.State.LOOSE:
		return "loose"
	return "catch" if p.holder == c else "other"

func _l_first_pass_through() -> void:
	var planned := 0
	var through := 0
	var clean := 0
	var n := 0
	for sd in 200:
		var p := _entry_play(7000 + sd, ["4", "5", "3", "2", "1"][sd % 5], 0.9, OFF_LANE * (1.0 if sd % 2 == 0 else -1.0))
		var c := PlaySetup._by_tag(p, "C")
		var g := p._center_guard(c)
		n += 1
		p.pass_to(c)
		if p.first_entry.is_empty():
			continue
		planned += 1
		var t := 0.0
		while p.ball.state == Ball.State.PASS and t < 2.0:
			p.step(DT)
			t += DT
		var clean_catch := not p.over and p.holder == c
		through += int(not clean_catch)
		clean += int(p.over and String(p.result.outcome) == "steal" and p.holder == g)
	print("  L: first pass by his man, just off the lane (not fronting: the old rule let these through) but in his reach: %d of %d; never caught: %d, picked clean %d" % [planned, n, through, clean])
	r.check(planned > n * 0.3, "L: a first pass straight at a properly set guard goes through his reach")
	r.check(through == planned, "...and the centre never catches it cleanly: stolen or knocked loose")

func _m_n_around_and_out_of_position() -> void:
	# M: round him (well off the line of the pass)
	var caught := 0
	var n := 0
	var planned := 0
	for sd in 120:
		var p := _entry_play(7400 + sd, ["4", "5", "3", "2", "1"][sd % 5], 0.7, 1.1 * (1.0 if sd % 2 == 0 else -1.0))
		n += 1
		var got := _feed(p)
		planned += int(p.events.any(func(e): return String(e.k) == "first_entry"))
		caught += int(got == "catch")
	print("  M: round his man: no first-pass rule %d times, caught %d of %d" % [n - planned, caught, n])
	r.check(planned == 0 and caught > n * 0.7, "M: a pass round him isn't disrupted, and mostly gets there")
	# N: out of position (behind the centre, goal side)
	caught = 0
	planned = 0
	for sd in 120:
		var p := _entry_play(7600 + sd, ["4", "5", "3", "2", "1"][sd % 5], -0.55, 0.0)
		var got := _feed(p)
		planned += int(p.events.any(func(e): return String(e.k) == "first_entry"))
		caught += int(got == "catch")
	print("  N: his man behind the centre: first-pass rule %d times, caught %d of 120" % [planned, caught])
	r.check(planned == 0 and caught > 100, "N: a defender out of position gets nothing for free")

func _o_second_pass() -> void:
	var triggered := 0
	var n := 0
	for sd in 120:
		var p := _entry_play(7800 + sd, "4", 0.9, 0.0)
		var mate := PlaySetup._by_tag(p, "3")
		p.pass_to(mate)   # the first pass: round the perimeter
		var t := 0.0
		while p.ball.state == Ball.State.PASS and t < 2.0:
			p.step(DT)
			t += DT
		if p.over or p.holder != mate:
			continue
		var c := PlaySetup._by_tag(p, "C")
		var g := p._center_guard(c)
		if g == null:
			continue
		var to_ball := (p.holder.pos - c.pos).normalized()
		g.pos = c.pos + to_ball * 0.9
		g.target = g.pos
		n += 1
		p.pass_to(c)
		triggered += int(not p.first_entry.is_empty())
	print("  O: second pass in to the centre: first-pass rule %d of %d" % [triggered, n])
	r.check(n > 80 and triggered == 0, "O: only the first pass: the next one into the centre is an ordinary entry")

func _p_q_deflect_and_steal() -> void:
	var loose := 0
	var loose_ok := true
	var steals := 0
	var steal_ok := true
	for sd in 300:
		var p := _entry_play(8000 + sd, ["4", "5", "3", "2", "1"][sd % 5], 0.9, OFF_LANE * (1.0 if sd % 2 == 0 else -1.0))
		var c := PlaySetup._by_tag(p, "C")
		var g := p._center_guard(c)
		var line_to := p.lead_point(c)
		p.pass_to(c)
		if p.first_entry.is_empty():
			continue
		var plan := p.first_entry.duplicate()
		var t := 0.0
		while p.ball.state == Ball.State.PASS and t < 2.0:
			p.step(DT)
			t += DT
		var hit := p.events.filter(func(e): return String(e.k) == "first_entry")
		if hit.is_empty():
			continue   # (somebody else got a hand to it first: an ordinary pick-off)
		if bool(hit[0].clean):
			steals += 1
			steal_ok = steal_ok and p.over and String(p.result.outcome) == "steal" and p.holder == g and p.result.get("by") == g.player
		else:
			loose += 1
			# off his hand: loose on the water, knocked off the line it was on (a visible change)
			var off_line := p.ball.drift.normalized().dot((line_to - (plan.at as Vector2)).normalized()) < 0.99 if p.ball.drift.length() > 0.1 else true
			loose_ok = loose_ok and not p.over and p.ball.state == Ball.State.LOOSE and p.ball.receiver == null and off_line \
				and p.events.any(func(e): return String(e.k) == "tip") and absf(g.dive) > 0.5
	print("  P/Q: first-pass disruptions: %d knocked loose, %d picked clean" % [loose, steals])
	r.check(loose > 10 and loose_ok, "P: a deflection is a loose ball off his raised hand, knocked off its line, for anybody")
	r.check(steals > 10 and steal_ok, "Q: a clean pick is his ball: the possession changes (a steal)")

func _r_s_possession_reset() -> void:
	# R: the defence wins it: the next possession (a new Play, theirs) starts with its first pass to come
	var p := _entry_play(8400, "4", 0.9, 0.0)
	p.pass_to(PlaySetup._by_tag(p, "C"))
	var snap := p.snapshot()
	var nxt := Play.new(p.them, p.us, Play.Kind.COUNTER, _rng(8401), snap)
	r.check(not p.first_pass and nxt.first_pass and nxt.first_entry.is_empty(), "R: a new possession starts its own first pass")
	# S: knocked loose and won back by the offence: the first pass is spent
	var won_back := 0
	var later := 0
	for sd in 300:
		var q := _entry_play(8500 + sd, ["4", "5", "3", "2", "1"][sd % 5], 0.9, OFF_LANE * (1.0 if sd % 2 == 0 else -1.0))
		q.pass_to(PlaySetup._by_tag(q, "C"))
		if q.first_entry.is_empty() or bool(q.first_entry.clean):
			continue
		var t := 0.0
		while not q.over and t < 3.0 and not (q.ball.state == Ball.State.HELD and q.holder != null):
			q.step(DT)
			t += DT
		if q.over or q.holder == null or q.holder.side != Swimmer.Side.US:
			continue
		won_back += 1
		var c := PlaySetup._by_tag(q, "C")
		if q.holder == c:
			continue
		q.pass_to(c)
		later += int(not q.first_entry.is_empty())
	print("  S: knocked loose and won back %d times; the next pass got the first-pass rule %d times" % [won_back, later])
	r.check(won_back > 0 and later == 0, "S: the first pass is spent: the next one is an ordinary pass")

func _t_no_keeper_steal() -> void:
	var by_keeper := 0
	var keeper_moved := 0
	var n := 0
	for sd in 200:
		var p := _entry_play(8900 + sd, ["4", "5", "3", "2", "1"][sd % 5], 0.9, OFF_LANE * (1.0 if sd % 2 == 0 else -1.0))
		var k0 := p.keeper.pos
		var got := _feed(p)
		n += 1
		for e in p.events:
			if String(e.k) == "first_entry" and e.by == p.keeper.player:
				by_keeper += 1
		if got == "steal" and p.holder == p.keeper:
			by_keeper += 1
		keeper_moved += int(p.keeper_rush)
	print("  T: %d first passes in: keeper took %d, came out %d" % [n, by_keeper, keeper_moved])
	r.check(by_keeper == 0, "T: only the centre's own man takes a first pass in: never the keeper")

# ------------------------------------------------------------------ balance
static func balance(runner, matches: int) -> void:
	print("keeper overhaul balance (shots: --test keeper_measure)")
	for lv in [0.5]:
		var s := {"first_c": 0, "first_through": 0, "first_caught": 0, "disrupt": 0, "steal": 0, "loose": 0, "passes_c": 0,
			"goals": 0, "shots": 0, "saves": 0, "react": 0, "anticipated": 0, "panic": 0, "correction": 0, "panic_saves": 0, "right_ant": 0}
		for i in matches:
			var f := MatchFlow.new(League.make_team(i % 8, 0), League.make_team((i + 3) % 8, 0), 9000 + i, MatchState.QUARTER_MIN, lv)
			var steps := 0
			while f.phase != MatchFlow.Phase.FINAL and steps < 200000:
				steps += 1
				match f.phase:
					MatchFlow.Phase.SPRINT:
						f.sprint_done(f.rng.randf() < 0.5)
					MatchFlow.Phase.ATTACK:
						var tt := 0.0
						var think := 0.0
						var pending_c := false
						while not f.play.over and tt < 60.0:
							think -= 1.0 / 30.0
							if think <= 0.0:
								think = PlayBot.THINK_EVERY
								var d := PlayBot.think(f.play, f.rng)
								if not d.is_empty():
									f.play.throw(d.target, d.power)
							var p := f.play
							var seen_n := f.events.size()
							f.tick_attack(1.0 / 30.0)
							for e in f.events.slice(seen_n):
								match String(e.k):
									"pass":
										if String(e.get("to", "")) == "C":
											s.passes_c += 1
											if bool(e.get("first", false)):
												s.first_c += 1
												s.first_through += int(bool(e.get("through", false)))
												pending_c = true
									"first_entry":
										s.disrupt += 1
										s.steal += int(bool(e.clean))
										s.loose += int(not bool(e.clean))
										pending_c = false
									"catch":
										if pending_c and p.holder != null and p.holder.tag == "C":
											s.first_caught += 1
										pending_c = false
									"shot":
										s.shots += 1
							if p.ball.state == Ball.State.SHOT and p.ball.shot.has("gk") and not p.ball.shot.get("_counted", false):
								p.ball.shot["_counted"] = true
								var k := String(p.ball.shot.gk.kind)
								if s.has(k):
									s[k] += 1
							tt += 1.0 / 30.0
						f.events.clear()
						var out := String(f.play.result.get("outcome", ""))
						s.goals += int(out == "goal")
						s.saves += int(out == "save")
						f.attack_done()
					MatchFlow.Phase.DEFENSE:
						f.auto_defense(0.5)
						f.defense_done()
					MatchFlow.Phase.SHOOTOUT_THEM:
						f.their_ball_done()
					MatchFlow.Phase.THEIR_SHOT:
						f.auto_duel(0.5)
						f.duel_done()
					MatchFlow.Phase.BREAK:
						f.break_done()
		var m := float(matches)
		print("  your bot attack vs their keeper (MEDIUM), %d matches: goals/game %.2f, shots %.1f, saves %.2f a game" % [matches, s.goals / m, s.shots / m, s.saves / m])
		print("  their keeper's shots: reacted %d, anticipated right %d, quick corrections %d, panics %d" % [s.react, s.anticipated, s.correction, s.panic])
		print("  passes into the centre %d (%.1f a game); first passes into him %d: through his man %d, disrupted %d (stolen %d, loose %d), caught %d (%.2f)" % [
			s.passes_c, s.passes_c / m, s.first_c, s.first_through, s.disrupt, s.steal, s.loose, s.first_caught, s.first_caught / maxf(1.0, s.first_c)])

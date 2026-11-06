extends RefCounted
## The AI keeper, centre play and difficulty overhaul:
##   godot --headless --path game -- --test ai              (the checks, the 18 below)
##   godot --headless --path game -- --test ai_balance [n]  (the balancing numbers only, n matches a level)
## 1-4 the keeper's three dives, no save the wrong way, no reversal, his attributes; 5-6 the
## close-range chance and its aiming tolerance; 7-8 the beaten defender's answers and the 5 m
## penalty; 9-10, 16-18 difficulty as decisions only (Hard is smarter, never stronger, and still
## guesses wrong); 11-12 DYNAMIC; 13 your keeper unchanged; 14 team overall changes nothing;
## 15 saves. Fixed seeds throughout.

var r
const LEVELS := [0.0, 0.5, 1.0]

func run(runner) -> void:
	r = runner
	print("AI overhaul: the keeper")
	_t1_directions()
	_t2_wrong_way()
	_t3_no_reversal()
	_t4_keeper_attributes()
	print("AI overhaul: centre play")
	_t5_close_range()
	_t6_close_aim()
	_t7_center_defender()
	_t8_penalties()
	print("AI overhaul: difficulty")
	_t9_decisions_differ()
	_t10_hard_keeper_guesses_wrong()
	_t11_dynamic()
	_t12_locked_in_match()
	_t13_your_keeper()
	_t14_team_overall()
	_t15_saves()
	_t16_offense()
	_t17_defense()
	_t18_keeper_physics()

# ------------------------------------------------------------------ helpers
func _keeper(v: float = 5.0, vals: Dictionary = {}) -> PoloPlayer:
	var a := {"com": v, "lun": v, "blk": v, "leg": v}
	a.merge(vals, true)
	return AttrBench.player(a, true)

## The ctx Play._shoot builds for a shot at `keeper`, your aim (exact), at decision level `iq`.
func _ctx(keeper: PoloPlayer, iq: float, extra: Dictionary = {}) -> Dictionary:
	var c := AttrBench.shot_ctx(AttrBench.player({}), null, keeper, INF)
	c["exact"] = true
	c["iq"] = iq
	c.merge(extra, true)
	return c

## Where their keeper sets for a shooter at `from` (PlayAI._keeper's shading, an average keeper).
func _set_y(from: Vector2) -> float:
	return PlayAI.keeper_set_y(from, 0.6)

## A shooter who reads the keeper too: mostly the open net (the side with more room), some at the
## near post, a few down the middle. Returns the aim (pool y).
func _sensible_aim(keeper_y: float, rng: RandomNumberGenerator) -> float:
	var open_side := -1.0 if keeper_y > Geo.GOAL_Y else 1.0
	if absf(keeper_y - Geo.GOAL_Y) < 0.05:
		open_side = -1.0 if rng.randf() < 0.5 else 1.0
	var u := rng.randf()
	if u < 0.6:
		return Geo.GOAL_Y + open_side * rng.randf_range(0.8, 1.35)
	if u < 0.85:
		return Geo.GOAL_Y - open_side * rng.randf_range(0.8, 1.3)
	return Geo.GOAL_Y + rng.randf_range(-0.35, 0.35)

## {read (his read before the shot, KeeperAI's pick, was the way it went: KeeperAI.zone_of), right (his dive had it at full stretch),
## goal, save, picks (LEFT, UP, RIGHT shares)} over `n` sensible shots
## from spots `spots` at level `iq` against `keeper`.
func _keeper_trial(keeper: PoloPlayer, iq: float, spots: Array, n: int = 3000, seed_value: int = 41) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var arng := RandomNumberGenerator.new()
	arng.seed = seed_value + 1
	var right := 0
	var reads := 0
	var goals := 0
	var saves := 0
	var picks := Vector3.ZERO
	for i in n:
		var from: Vector2 = spots[i % spots.size()]
		var ky := _set_y(from)
		var aim := _sensible_aim(ky, arng)
		var res := ShotModel.resolve(from, aim, 0.75, 62.0, 4.0, [], ky, 62.0, rng, false, {}, _ctx(keeper, iq))
		right += int(bool(res.right_way))
		reads += int(int(res.read_side) == KeeperAI.zone_of(float(res.cross_y), ky))
		match int(res.read_side):
			-1:
				picks.x += 1
			0:
				picks.y += 1
			1:
				picks.z += 1
		match String(res.outcome):
			"goal":
				goals += 1
			"save", "parry":
				saves += 1
	return {"read": reads / float(n), "right": right / float(n), "goal": goals / float(n), "save": saves / float(n), "picks": picks / float(n)}

const PERIMETER := [Vector2(24.0, 10.0), Vector2(24.2, 8.0), Vector2(24.2, 12.0), Vector2(24.6, 6.8), Vector2(24.6, 13.2)]
const CLOSE := [Vector2(27.6, 10.0), Vector2(27.4, 9.2), Vector2(27.4, 10.8), Vector2(27.8, 9.6), Vector2(27.8, 10.4)]

## A possession: the man with the ball at `at`, defender 0 (his marker) at `d_at`, everybody else
## well away, their keeper in the middle; the defence's AI at `level`.
func _staged(at: Vector2, d_at: Vector2, seed_value: int, level: float = 0.5) -> Play:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var p := Play.new(League.make_team(2, 1), League.make_team(3, 1), Play.Kind.HALF_COURT, rng)
	p.set_level(level)
	p.holder.pos = at
	for o in p.defenders:
		if o.mark == p.holder and o != p.defenders[0]:
			o.mark = p.defenders[0].mark
	p.defenders[0].mark = p.holder
	for i in p.defenders.size():
		p.defenders[i].pos = d_at if i == 0 else Vector2(12.0 + i, 2.0 + i)
	for a in p.attackers:
		if a != p.holder:
			a.pos = Vector2(14.0, 2.0 + p.attackers.find(a) * 3.0)
			a.home = a.pos
	p.holder.home = at
	p.keeper.pos = Vector2(Geo.KEEPER_X, Geo.GOAL_Y)
	p.keeper.target = p.keeper.pos
	return p

# ------------------------------------------------------------------ 1. three dives
func _t1_directions() -> void:
	var b := KeeperDive.body_of(_keeper())
	var covers := {}
	for side in [KeeperDive.LEFT, KeeperDive.CENTRE, KeeperDive.RIGHT]:
		var d := KeeperDive.from_body(b, side, Geo.GOAL_Y)
		d.t = d.extend_time() + 0.05
		var c := []
		for y10 in range(-15, 16, 3):
			c.append(d.covers(Geo.GOAL_Y + y10 / 10.0) >= 0.0)
		covers[side] = c
	print("  full-stretch cover, -1.5 .. +1.5 m: L %s  U %s  R %s" % [str(covers[-1]), str(covers[0]), str(covers[1])])
	r.check(covers[-1][1] and not covers[-1][9], "LEFT covers his left (pool y below the middle), not his right")
	r.check(covers[1][9] and not covers[1][1], "RIGHT covers his right, not his left")
	r.check(covers[0][5] and not covers[0][1] and not covers[0][9], "UP covers the middle, not the corners")
	r.check(covers[-1] != covers[0] and covers[0] != covers[1] and covers[-1] != covers[1], "each way covers a different part of the goal")
	r.check(not (covers[-1][1] and covers[-1][9]) and not (covers[0][1] or covers[0][9]), "no dive covers both corners")
	# through the shot model: forced each way, shots at each third
	var k := _keeper()
	var table := {}
	for side in [-1, 0, 1]:
		for zone in [-1, 0, 1]:
			var rng := RandomNumberGenerator.new()
			rng.seed = 5
			var saves := 0
			for i in 400:
				var aim: float = Geo.GOAL_Y + zone * 0.95 + rng.randf_range(-0.15, 0.15)
				var res := ShotModel.resolve(Vector2(24.5, 10.0), aim, 0.7, 62.0, 4.0, [], Geo.GOAL_Y, 62.0, rng, false, {}, _ctx(k, 0.5, {"dive_side": side}))
				saves += int(String(res.outcome) in ["save", "parry"])
			table["%d>%d" % [side, zone]] = saves / 400.0
	print("  saves, dive>shot third: %s" % str(table))
	for side in [-1, 0, 1]:
		r.check(float(table["%d>%d" % [side, side]]) > 0.5, "a %s dive saves most shots its way (%.2f)" % [["LEFT", "UP", "RIGHT"][side + 1], float(table["%d>%d" % [side, side]])])
	r.check(float(table["-1>1"]) == 0.0 and float(table["1>-1"]) == 0.0, "...and none in the far corner")

# ------------------------------------------------------------------ 2. the wrong way
func _t2_wrong_way() -> void:
	var impossible := 0
	var n := 0
	for kv in [3.0, 5.0, 10.0]:
		var k := _keeper(kv)
		for side in [-1, 0, 1]:
			var rng := RandomNumberGenerator.new()
			rng.seed = 77
			for i in 600:
				var from: Vector2 = (PERIMETER + CLOSE)[i % 10]
				var aim := Geo.GOAL_Y + (rng.randf_range(0.75, 1.4) * (1.0 if side <= 0 else -1.0))
				if side == 0:
					aim = Geo.GOAL_Y + (1.0 if i % 2 == 0 else -1.0) * rng.randf_range(0.8, 1.4)
				var res := ShotModel.resolve(from, aim, 0.8, 62.0, 4.0, [], Geo.GOAL_Y, 62.0, rng, false, {}, _ctx(k, 1.0, {"dive_side": side, "block": 1.0}))
				# the wrong way is where it goes past him (his line, in front of the goal line), not where it crosses the goal line
				var past := ShotModel.on_line(from, float(res.cross_y), Geo.KEEPER_X).y - Geo.GOAL_Y
				if (side == 0 and absf(past) < 0.75) or (side != 0 and past * -float(side) < 0.75):
					continue
				n += 1
				if String(res.outcome) in ["save", "parry"]:
					impossible += 1
	r.check(impossible == 0, "no save from a dive the wrong way, even a 10 keeper with perfect hands (%d of %d)" % [impossible, n])
	# a left dive at the right corner, through a real possession
	var p := _staged(Vector2(24.5, 10.0), Vector2(12, 2), 9)
	var res := {}
	for i in 80:
		var rng := RandomNumberGenerator.new()
		rng.seed = 300 + i
		p = _staged(Vector2(24.5, 10.0), Vector2(12, 2), 300 + i)
		p.set_level(0.5)
		p.shoot_at(Vector2(Geo.GOAL_X, Geo.GOAL_Y + 1.15), 0.8)
		var sh: Dictionary = p.ball.shot
		if int(sh.guess) == -1:
			res = sh
			break
	r.check(not res.is_empty() and String(res.outcome) == "goal", "a keeper who went LEFT concedes the right corner in play")

# ------------------------------------------------------------------ 3. no instant reversal
func _t3_no_reversal() -> void:
	var states := []
	var p := _staged(Vector2(24.5, 9.0), Vector2(12, 2), 21)
	var ok_side := true
	var ok_line := true
	for i in 30:
		p = _staged(Vector2(24.5, 9.0 + (i % 3)), Vector2(12, 2), 400 + i)
		p.raise_ball(true)
		for j in 20:
			p.step(1.0 / 60.0)
		if states.is_empty() or states[-1] != p.gk_state:
			states.append(p.gk_state)
		p.shoot_at(Vector2(Geo.GOAL_X, Geo.GOAL_Y + (1.2 if i % 2 == 0 else -1.2)), 0.85)
		var side := -99
		var y0 := p.keeper.pos.y
		var last := y0
		var t := 0.0
		while t < 2.5:
			p.step(1.0 / 60.0)
			t += 1.0 / 60.0
			if p.keeper.pose != null:
				if side == -99:
					side = p.keeper.pose.side
				elif p.keeper.pose.side != side:
					ok_side = false
				# his body only ever goes out the way he went (then back the same way); a panic may claw
				# back towards the middle, but never covers past its wall
				var out := (p.keeper.pos.y - p.keeper.pose.base_y) * float(p.keeper.pose.side)   # (from where this dive set off)
				if not p.keeper.pose.turned() and out < -0.005:   # (Vector2 is single precision)
					ok_line = false
				if p.keeper.pose.turned() and side != 0 and p.keeper.pose.covers(y0 - float(side) * (KeeperDive.PANIC_WALL.x + 0.05)) >= 0.0:
					ok_line = false
				last = p.keeper.pos.y
			if i < 3 and (states.is_empty() or states[-1] != p.gk_state):
				states.append(p.gk_state)
	r.check(ok_side, "once he's gone, the way he went never changes")
	r.check(ok_line, "...his body never comes back across the other way, and a panic never covers past its wall")
	var names := states.map(func(s): return KeeperAI.STATE_NAMES[s])
	print("  his states: %s" % str(names))
	r.check((names.has("ANTICIPATING") or names.has("LEANING")) and names.any(func(s): return String(s).begins_with("COMMITTED") or String(s) == "REACTING") and names.has("RECOVERING"),
		"READY > ANTICIPATING / LEANING > COMMITTED / REACTING > RECOVERING drive what he does")
	# a rebound while he's still down: that dive has to stop it, no second one
	var k := _keeper()
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var busy_saves := 0
	var guess_kept := true
	for i in 300:
		var res := ShotModel.resolve(Vector2(27.0, 10.0), Geo.GOAL_Y + 1.1, 0.8, 62.0, 4.0, [], Geo.GOAL_Y, 62.0, rng, false, {},
			_ctx(k, 1.0, {"busy": {"side": -1, "t": 0.3, "base_y": Geo.GOAL_Y}, "dive_side": 1}))
		busy_saves += int(String(res.outcome) in ["save", "parry"])
		guess_kept = guess_kept and int(res.guess) == -1
	r.check(guess_kept and busy_saves == 0, "still in a LEFT dive, he can't start a RIGHT one for a quick rebound (%d saves)" % busy_saves)

# ------------------------------------------------------------------ 4. his attributes
func _t4_keeper_attributes() -> void:
	var slow := KeeperDive.from_body(KeeperDive.body_of(_keeper(5.0, {"lun": 1.0})), 1, Geo.GOAL_Y)
	var quick := KeeperDive.from_body(KeeperDive.body_of(_keeper(5.0, {"lun": 9.0})), 1, Geo.GOAL_Y)
	r.check(quick.extend_time() < slow.extend_time() - 0.02, "LUNGE SPEED: up to full stretch sooner (%.3f vs %.3f s)" % [quick.extend_time(), slow.extend_time()])
	var go := func(k: PoloPlayer) -> float:
		var rng := RandomNumberGenerator.new()
		rng.seed = 8
		var s := 0.0
		for i in 200:
			s += float(ShotModel.resolve(Vector2(27.5, 10.0), 11.0, 0.8, 62.0, 4.0, [], Geo.GOAL_Y, 62.0, rng, false, {}, _ctx(k, 0.5)).keeper_go)
		return s / 200.0
	var g1: float = go.call(_keeper(5.0, {"lun": 1.0}))
	var g9: float = go.call(_keeper(5.0, {"lun": 9.0}))
	r.check(g9 < g1, "LUNGE SPEED: he reacts to a close shot sooner (%.3f vs %.3f s)" % [g9, g1])
	var rate := func(k: PoloPlayer, aim: float, from: Vector2) -> float:
		var rng := RandomNumberGenerator.new()
		rng.seed = 12
		var sv := 0
		for i in 1500:
			var res := ShotModel.resolve(from, aim, 0.8, 62.0, 4.0, [], Geo.GOAL_Y, 62.0, rng, false, {}, _ctx(k, 0.5, {"dive_side": 1}))
			sv += int(String(res.outcome) in ["save", "parry"])
		return sv / 1500.0
	var close_aim := Geo.GOAL_Y + 0.9
	var l1: float = rate.call(_keeper(5.0, {"lun": 1.0}), close_aim, Vector2(27.6, 10.0))
	var l9: float = rate.call(_keeper(5.0, {"lun": 9.0}), close_aim, Vector2(27.6, 10.0))
	print("  close shot, right way: lunge 1 %.2f, lunge 9 %.2f" % [l1, l9])
	r.check(l9 > l1 + 0.05, "LUNGE SPEED: a quicker keeper gets to more close-range shots the right way")
	var b1: float = rate.call(_keeper(5.0, {"blk": 1.0}), Geo.GOAL_Y + 1.0, Vector2(24.0, 10.0))
	var b9: float = rate.call(_keeper(5.0, {"blk": 9.0}), Geo.GOAL_Y + 1.0, Vector2(24.0, 10.0))
	print("  in reach: blocking 1 %.2f, blocking 9 %.2f" % [b1, b9])
	r.check(b9 > b1, "BLOCKING: more of what he gets to stays out")
	# BLOCKING only holds what he gets to: a 10's saves in the far corner are never more than the
	# balls a 0 even gets a hand to there (the same dice: the same dives, the same balls)
	var touch := func(k: PoloPlayer) -> Vector2:
		var rng := RandomNumberGenerator.new()
		rng.seed = 12
		var got := Vector2.ZERO
		for i in 1500:
			var res := ShotModel.resolve(Vector2(24.0, 10.0), Geo.GOAL_Y + 1.45, 0.8, 62.0, 4.0, [], Geo.GOAL_Y, 62.0, rng, false, {}, _ctx(k, 0.5, {"dive_side": 1}))
			var saved := String(res.outcome) in ["save", "parry"]
			got += Vector2(1.0 if saved else 0.0, 1.0 if saved or bool(res.get("touched", false)) else 0.0)
		return got / 1500.0
	var b10: Vector2 = touch.call(_keeper(5.0, {"blk": 10.0}))
	var b0: Vector2 = touch.call(_keeper(5.0, {"blk": 0.0}))
	r.check(b10.x <= b10.y + 0.001 and absf(b10.y - b0.y) < 0.04, "BLOCKING never reaches past his arm (far corner: a 10 saves %.2f, a 0 gets a hand to %.2f)" % [b10.x, b0.y])
	var leg1 := KeeperDive.body_of(_keeper(5.0, {"leg": 1.0}))
	var leg9 := KeeperDive.body_of(_keeper(5.0, {"leg": 9.0}))
	r.check(float(leg9.lunge) + float(leg9.arm) > float(leg1.lunge) + float(leg1.arm) + 0.2, "LEG STRENGTH: reach (%.2f vs %.2f m)" % [float(leg9.lunge) + float(leg9.arm), float(leg1.lunge) + float(leg1.arm)])
	r.check(float(leg9.window) > float(leg1.window), "LEG STRENGTH: stays up longer (%.2f vs %.2f s)" % [leg9.window, leg1.window])
	r.check(is_equal_approx(float(leg9.quick), float(leg1.quick)), "LEG STRENGTH never makes his dive quicker")
	var c1: float = rate.call(_keeper(5.0, {"leg": 1.0}), Geo.GOAL_Y + 1.25, Vector2(24.0, 10.0))
	var c9: float = rate.call(_keeper(5.0, {"leg": 9.0}), Geo.GOAL_Y + 1.25, Vector2(24.0, 10.0))
	r.check(c9 > c1, "LEG STRENGTH: more of the corner the right way (%.2f vs %.2f)" % [c9, c1])
	# attributes never pick the way
	var same := true
	for i in 200:
		var r1 := RandomNumberGenerator.new()
		r1.seed = 900 + i
		var r2 := RandomNumberGenerator.new()
		r2.seed = 900 + i
		var a := ShotModel.resolve(Vector2(24.5, 9.0), 11.0, 0.8, 62.0, 4.0, [], 9.8, 62.0, r1, false, {}, _ctx(_keeper(1.0), 0.5))
		var b := ShotModel.resolve(Vector2(24.5, 9.0), 11.0, 0.8, 62.0, 4.0, [], 9.8, 95.0, r2, false, {}, _ctx(_keeper(10.0), 0.5))
		same = same and int(a.guess) == int(b.guess)
	r.check(same, "a 1 keeper and a 10 keeper pick the same way from the same look: attributes aren't anticipation")

# ------------------------------------------------------------------ 5. close range
func _t5_close_range() -> void:
	var k := _keeper()
	var far := _keeper_trial(k, 0.5, PERIMETER, 3000, 51)
	var near := _keeper_trial(k, 0.5, CLOSE, 3000, 51)
	print("  sensible aim, medium keeper: perimeter goal %.2f (right way %.2f), close goal %.2f (right way %.2f)" % [far.goal, far.right, near.goal, near.right])
	r.check(float(near.goal) > float(far.goal) + 0.04, "a close-range look is clearly more dangerous than a perimeter one")
	r.check(float(near.goal) < 0.92, "...but not an automatic goal")
	# in play: a man with inside water at 2 m against a man out on the perimeter, both aiming sensibly
	var rate := func(at: Vector2, d_at: Vector2) -> float:
		var goals := 0
		var arng := RandomNumberGenerator.new()
		arng.seed = 4
		for i in 200:
			var p := _staged(at, d_at, 700 + i)
			for j in 10:
				p.step(1.0 / 60.0)
			if p.over or p.holder == null:
				continue
			var aim := _sensible_aim(p.keeper.pos.y, arng)
			p.shoot_at(Vector2(Geo.GOAL_X, aim) + (Vector2(Geo.GOAL_X, aim) - p.holder.pos).normalized() * 0.01, 0.8)
			var t := 0.0
			while not p.over and t < 3.0 and p.ball.state == Ball.State.SHOT:
				p.step(1.0 / 60.0)
				t += 1.0 / 60.0
			goals += int(String(p.result.get("outcome", "")) == "goal")
		return goals / 200.0
	var inside: float = rate.call(Vector2(27.8, 10.0), Vector2(27.0, 10.0))
	var outside: float = rate.call(Vector2(24.0, 7.0), Vector2(23.0, 7.0))
	print("  in play: inside water at 2 m %.2f, perimeter %.2f" % [inside, outside])
	r.check(inside > outside + 0.06, "in play too, inside water at 2 m beats a perimeter shot")
	# pressure still counts: smothered (his man in front, goal side) vs inside water
	var pp := _staged(Vector2(27.6, 10.0), Vector2(28.4, 10.0), 5)
	var smothered := pp.close_chance(pp.holder)
	var pi := _staged(Vector2(27.6, 10.0), Vector2(26.8, 10.0), 5)
	var inside_q := pi.close_chance(pi.holder)
	r.check(smothered < inside_q * 0.5, "his man goal side of him smothers the chance (%.2f vs %.2f inside)" % [smothered, inside_q])
	r.check(pp.contact_on(pp.holder) > pi.contact_on(pi.holder), "...and the contact in front of him is more (a slower shot)")
	# no label bonus: a wing who gets to the same water, his man in the same place, has the same chance
	# and the same shot
	var by_tag := func(tag: String) -> Array:
		var rng := RandomNumberGenerator.new()
		rng.seed = 77
		var p := Play.new(League.make_team(2, 1), League.make_team(3, 1), Play.Kind.HALF_COURT, rng)
		var man := PlaySetup._by_tag(p, tag)
		man.player = p.attackers[0].player   # (the same player in both: only the label differs)
		p.give_ball(man)
		man.pos = Vector2(27.6, 10.0)
		var g := p._marker(man)
		g.player = p.defenders[0].player   # (the same defender on him in both)
		for d in p.defenders:
			d.pos = Vector2(26.8, 10.0) if d == g else Vector2(12.0, 2.0 + p.defenders.find(d))
		p.shoot_at(Vector2(Geo.GOAL_X + 0.5, 11.0), 0.8)
		var sh: Dictionary = p.ball.shot
		return [snappedf(p.close_chance(man), 0.0001), String(sh.outcome), snappedf(float(sh.speed), 0.001)]
	var as_c: Array = by_tag.call("C")
	var as_w: Array = by_tag.call("2")
	r.check(as_c == as_w, "the chance (and the shot) is where he is, not his position: C %s, wing %s" % [str(as_c), str(as_w)])
	var src := FileAccess.get_file_as_string("res://src/core/shot_model.gd")
	r.check(not src.contains("CENTER_POWER") and not src.contains("\"center\""), "no centre-only shot bonus left in the shot model")

# ------------------------------------------------------------------ 6. close-range aim
func _t6_close_aim() -> void:
	var p := _staged(Vector2(27.8, 10.0), Vector2(27.0, 10.0), 33)
	var q := p.close_chance(p.holder)
	var post := Geo.GOAL_Y + Geo.GOAL_HALF
	var aim_for := func(pl: Play, cy: float) -> Dictionary:
		var h := pl.holder.pos
		var tgt := h + (Vector2(Geo.GOAL_X, cy) - h) * 1.3
		return pl.aim_info(tgt)
	var just: Dictionary = aim_for.call(p, post + 0.15)
	var bad: Dictionary = aim_for.call(p, post + 0.6)
	print("  close chance %.2f: aim 0.15 m wide crosses at %+.2f, 0.6 m wide at %+.2f (post %+.2f)" % [q, float(just.cross_y) - Geo.GOAL_Y, float(bad.cross_y) - Geo.GOAL_Y, Geo.GOAL_HALF])
	r.check(String(just.mode) == "shot" and absf(float(just.cross_y) - Geo.GOAL_Y) < Geo.GOAL_HALF, "from a strong close-range spot, just wide is tucked inside the post")
	r.check(absf(float(bad.cross_y) - Geo.GOAL_Y) > Geo.GOAL_HALF + 0.3, "...but a badly aimed one is still wide")
	var far := _staged(Vector2(23.8, 10.0), Vector2(12.0, 2.0), 33)
	var far_just: Dictionary = aim_for.call(far, post + 0.15)
	r.check(absf(float(far_just.cross_y) - Geo.GOAL_Y) > Geo.GOAL_HALF, "from the perimeter, just wide is just wide")
	# and it goes where the reticle shows
	p.shoot_at(p.holder.pos + (Vector2(Geo.GOAL_X, post + 0.15) - p.holder.pos) * 1.3, 0.8)
	r.check(p.ball.state == Ball.State.SHOT and is_equal_approx(float(p.ball.shot.cross_y), float(just.cross_y)), "...and the shot crosses exactly where the reticle showed")
	var b2 := _staged(Vector2(27.8, 10.0), Vector2(27.0, 10.0), 34)
	b2.shoot_at(b2.holder.pos + (Vector2(Geo.GOAL_X, post + 0.6) - b2.holder.pos) * 1.3, 0.8)
	r.check(b2.ball.state == Ball.State.SHOT and String(b2.ball.shot.outcome) == "miss", "the badly aimed close one misses")

# ------------------------------------------------------------------ 7. the beaten defender
func _t7_center_defender() -> void:
	var acts := {}
	var moved := true
	var teleport := false
	var passive := 0
	var n := 0
	for lv in LEVELS:
		for i in 40:
			var p := _staged(Vector2(27.9, 10.0 + (i % 3 - 1) * 0.3), Vector2(27.0, 10.0), 1100 + i, lv)
			var d := p.defenders[0]
			var start := d.pos
			var last := d.pos
			var seen := -1
			var t := 0.0
			while t < 1.4 and not p.over and p.holder != null:
				p.step(1.0 / 60.0)
				t += 1.0 / 60.0
				var step_len := d.pos.distance_to(last)
				if step_len > d.top_speed * 1.6 / 60.0 + 0.05:
					teleport = true
				last = d.pos
				if d.cdef > CenterDefense.Act.HOLD and seen < 0:
					seen = d.cdef
			n += 1
			if seen < 0:
				passive += 1
			else:
				var k := "%s:%s" % [lv, CenterDefense.ACT_NAMES[seen]]
				acts[k] = int(acts.get(k, 0)) + 1
			if seen in [CenterDefense.Act.RECOVER, CenterDefense.Act.PRESSURE, CenterDefense.Act.CHALLENGE] and d.pos.distance_to(start) < 0.1 and not p.over:
				moved = false
	print("  first answer by level: %s  (never answered %d of %d)" % [str(acts), passive, n])
	r.check(passive <= n * 0.05, "a defender beaten for inside water answers it (recover, press, challenge, foul or contain)")
	r.check(moved, "...and an active answer moves him")
	r.check(not teleport, "...at his own speed: nobody jumps into place")
	# he needs a moment to see it, longer on EASY
	var e := Difficulty.value("recognize", 0.0)
	var h := Difficulty.value("recognize", 1.0)
	var p2 := _staged(Vector2(27.9, 10.0), Vector2(27.0, 10.0), 1200, 0.0)
	var held := 0.0
	while held < e - 0.05:
		p2.step(1.0 / 60.0)
		held += 1.0 / 60.0
	r.check(p2.defenders[0].cdef == CenterDefense.Act.HOLD, "EASY: still beaten, still reading it after %.2f s" % held)
	r.check(h < e, "HARD reads inside water sooner (%.2f vs %.2f s)" % [h, e])
	# inside water is an advantage that stays: no automatic steal
	var steals := 0
	for i in 200:
		var p := _staged(Vector2(27.9, 10.0), Vector2(27.0, 10.0), 1300 + i, 1.0)
		var t := 0.0
		while t < 0.6 and not p.over:
			p.step(1.0 / 60.0)
			t += 1.0 / 60.0
		steals += int(String(p.result.get("outcome", "")) == "steal")
	r.check(steals < 60, "inside water at 2 m isn't stolen back in the first 0.6 s, even on HARD (%d of 200)" % steals)

# ------------------------------------------------------------------ 8. 5 m penalties
func _t8_penalties() -> void:
	var tally := func(act: int, at: Vector2, d_at: Vector2, n: int = 300) -> Dictionary:
		var out := {}
		for i in n:
			var p := _staged(at, d_at, 1500 + i)
			var d := p.defenders[0]
			d.cdef = act
			p.shoot_at(Vector2(Geo.GOAL_X, Geo.GOAL_Y + 1.1), 0.8)
			var o := String(p.result.get("outcome", "shot")) if p.over else ("foul" if p.freeze > 0.0 else ("shot" if p.ball.state == Ball.State.SHOT else "held"))
			if p.excluded != null:
				o = "exclusion"
			out[o] = int(out.get(o, 0)) + 1
		return out
	var inside := Vector2(27.9, 10.0)
	var behind := Vector2(27.0, 10.0)
	var des: Dictionary = tally.call(CenterDefense.Act.DESPERATE, inside, behind)
	var con: Dictionary = tally.call(CenterDefense.Act.CONTAIN, inside, behind)
	var rec: Dictionary = tally.call(CenterDefense.Act.RECOVER, inside, behind)
	var hold: Dictionary = tally.call(CenterDefense.Act.HOLD, inside, behind)
	print("  pulled back going up: %s; contain: %s; recover: %s; beaten, no answer: %s" % [str(des), str(con), str(rec), str(hold)])
	r.check(int(des.get("penalty", 0)) > 150, "a pull from behind that stops a probable goal is a 5 m penalty")
	r.check(int(des.get("shot", 0)) > 20, "...but a strong man gets it away now and then")
	for t in [con, rec, hold]:
		r.check(not t.has("penalty"), "inside water on its own never draws a penalty")
	# a pull on a man who's no probable goal (wide, outside the box) isn't a penalty
	var wide: Dictionary = tally.call(CenterDefense.Act.DESPERATE, Vector2(25.0, 15.0), Vector2(24.2, 15.4))
	r.check(not wide.has("penalty"), "a pull with no probable goal is no penalty (%s)" % str(wide))
	# legal challenges: a steal, a free throw, or nothing; never a penalty
	var out := {}
	for i in 400:
		var p := _staged(Vector2(27.9, 10.0), Vector2(27.9, 10.75), 1900 + i)
		var d := p.defenders[0]
		d.cdef = CenterDefense.Act.CHALLENGE
		d.cdef_cool = 0.0
		CenterDefense.challenges(p)
		var o := String(p.result.get("outcome", "")) if p.over else ("free throw" if p.freeze > 0.0 else "nothing")
		out[o] = int(out.get(o, 0)) + 1
	print("  a challenge from beside him: %s" % str(out))
	r.check(not out.has("penalty") and out.has("steal") and int(out.get("nothing", 0)) > int(out.get("steal", 0)), "a legal challenge is sometimes a steal, more often nothing, never a penalty")
	# from behind he can't legally reach it: no challenge at all
	var p3 := _staged(Vector2(27.9, 10.0), Vector2(27.2, 10.0), 2400)
	p3.defenders[0].cdef = CenterDefense.Act.CHALLENGE
	CenterDefense.challenges(p3)
	r.check(not p3.over and p3.freeze <= 0.0 and p3.defenders[0].cdef_cool == 0.0, "from behind him he can't go for the ball")
	# Defense vs Strength: the better defender wins more and fouls less (the (D - S) x 4% modifier)
	var p4 := _staged(Vector2(27.9, 10.0), Vector2(27.9, 10.75), 2500)
	var good := AttrBench.player({"dfn": 9.0, "str": 6.0})
	var weak := AttrBench.player({"dfn": 2.0, "str": 4.0})
	p4.defenders[0].player = good
	var s_good := CenterDefense.steal_chance(p4, p4.defenders[0], p4.holder)
	var f_good := CenterDefense.fail_foul(p4, p4.defenders[0], p4.holder)
	p4.defenders[0].player = weak
	r.check(s_good > CenterDefense.steal_chance(p4, p4.defenders[0], p4.holder) and f_good < CenterDefense.fail_foul(p4, p4.defenders[0], p4.holder),
		"higher Defense: more legal steals, fewer needless fouls")

# ------------------------------------------------------------------ 9. difficulty: decisions, not bodies
func _t9_decisions_differ() -> void:
	var k := _keeper()
	var spots := PERIMETER + CLOSE
	var acc := []
	for lv in LEVELS:
		acc.append(float(_keeper_trial(k, lv, spots, 4000, 61).read))
	print("  keeper's read before the shot was the way it went, EASY / MEDIUM / HARD: %.3f / %.3f / %.3f" % acc)
	r.check(acc[0] < acc[1] and acc[1] < acc[2], "the keeper reads the shot better up the levels")
	r.check(acc[2] - acc[0] > 0.06, "...noticeably")
	# the centre defender's choices: how much the attack is left with, as he works it out (no dice)
	var eg := []
	for lv in LEVELS:
		var sum := 0.0
		for i in 120:
			var p := _staged(Vector2(27.9, 10.0 + (i % 5 - 2) * 0.25), Vector2(27.0 + (i % 3) * 0.1, 10.0 + (i % 4 - 1.5) * 0.3), 3000 + i, lv)
			var d := p.defenders[0]
			var a := p.holder
			if not CenterDefense.inside_water(p, a, d):
				continue
			var v := CenterDefense.values(p, d, a)
			var pick := CenterDefense.choose(p, d, a, p.ai_rng)
			var best := INF
			for kk in v:
				best = minf(best, float(v[kk]))
			sum += float(v[pick]) - best
		eg.append(sum / 120.0)
	print("  the beaten defender's pick, expected goals given away over the best answer: %.3f / %.3f / %.3f" % eg)
	r.check(eg[2] < eg[1] and eg[1] < eg[0], "the centre defender picks better answers up the levels")

# ------------------------------------------------------------------ 10. Hard still guesses wrong
func _t10_hard_keeper_guesses_wrong() -> void:
	var t := _keeper_trial(_keeper(9.0), 1.0, PERIMETER + CLOSE, 4000, 71)
	print("  HARD, a 9 keeper: picked the way it went %.3f, had it at full stretch %.3f, goals %.3f, picks L/U/R %s" % [t.read, t.right, t.goal, str(t.picks)])
	r.check(float(t.read) < 0.85, "a HARD keeper still guesses wrong a good part of the time")
	r.check(float(t.goal) > 0.15, "...and gets beaten")
	var w := KeeperAI.read({"from": Vector2(24.5, 12.0), "keeper_y": 10.4}, 1.0)
	var odds := KeeperAI.pick_odds(w, 1.0)
	r.check(odds.x > 0.0 and odds.y > 0.0 and odds.z > 0.0, "...every way is always possible for him, even when he's sure (%s)" % str(odds))

# ------------------------------------------------------------------ 11. DYNAMIC
func _t11_dynamic() -> void:
	var climb := func(entries: Array, start: float) -> Array:
		var hist := []
		var l := start
		var out := []
		for e in entries:
			hist = Difficulty.record(hist, e)
			var step := Difficulty.step_for(hist)
			l = clampf(l + step, 0.0, 1.0)
			out.append([step, l])
		return out
	var wins: Array = climb.call([{"m": 7, "gap": 0.0}, {"m": 6, "gap": 0.1}, {"m": 8, "gap": -0.2}, {"m": 6, "gap": 0.0}, {"m": 7, "gap": 0.0}, {"m": 6, "gap": 0.0}], 0.5)
	var losses: Array = climb.call([{"m": -7, "gap": 0.0}, {"m": -6, "gap": 0.1}, {"m": -8, "gap": -0.2}, {"m": -6, "gap": 0.0}, {"m": -7, "gap": 0.0}, {"m": -6, "gap": 0.0}], 0.5)
	var weak: Array = climb.call([{"m": 7, "gap": 2.2}, {"m": 6, "gap": 2.0}, {"m": 8, "gap": 2.4}, {"m": 6, "gap": 2.0}, {"m": 7, "gap": 2.1}], 0.5)
	var strong: Array = climb.call([{"m": -7, "gap": -2.2}, {"m": -6, "gap": -2.0}, {"m": -8, "gap": -2.4}, {"m": -6, "gap": -2.0}, {"m": -7, "gap": -2.1}], 0.5)
	var one: Array = climb.call([{"m": 0, "gap": 0.0}, {"m": 1, "gap": 0.0}, {"m": -1, "gap": 0.0}, {"m": 9, "gap": 0.0}], 0.5)
	print("  dynamic, 0.5 after comparable blowouts %s, heavy losses %s, wins vs much weaker %.3f, losses to much stronger %.3f, one blowout %.3f" % [
		str(wins.map(func(x): return snappedf(x[1], 0.001))), str(losses.map(func(x): return snappedf(x[1], 0.001))), weak[-1][1], strong[-1][1], one[-1][1]])
	r.check(wins[-1][1] > 0.6, "sustained wins over comparable teams raise it")
	r.check(losses[-1][1] < 0.4, "sustained heavy losses to comparable teams lower it")
	r.check(absf(weak[-1][1] - 0.5) < 0.04, "beating much weaker teams hardly moves it")
	r.check(absf(strong[-1][1] - 0.5) < 0.04, "losing to much stronger teams hardly moves it")
	r.check(absf(one[-1][0]) < 0.02, "one isolated blowout barely moves it (%.3f)" % one[-1][0])
	var all_steps := wins + losses + weak + strong + one
	r.check(all_steps.all(func(x): return absf(x[0]) <= Difficulty.DYN_MAX_STEP + 1e-6), "never more than 0.05 a game")
	var top: Array = climb.call([{"m": 9, "gap": 0.0}, {"m": 9, "gap": 0.0}, {"m": 9, "gap": 0.0}, {"m": 9, "gap": 0.0}, {"m": 9, "gap": 0.0}, {"m": 9, "gap": 0.0}], 0.98)
	var bottom: Array = climb.call([{"m": -9, "gap": 0.0}, {"m": -9, "gap": 0.0}, {"m": -9, "gap": 0.0}, {"m": -9, "gap": 0.0}, {"m": -9, "gap": 0.0}, {"m": -9, "gap": 0.0}], 0.02)
	r.check(top.all(func(x): return x[1] <= 1.0) and bottom.all(func(x): return x[1] >= 0.0), "always 0.0 .. 1.0")
	r.check(Difficulty.DYN_START == 0.5 and is_equal_approx(Difficulty.value("gk_read", 0.25), lerpf(Difficulty.PARAMS.gk_read.x, Difficulty.PARAMS.gk_read.y, 0.5)),
		"starts at 0.50, and in-between levels are the lines between EASY, MEDIUM and HARD")
	# the matchup comes from attributes, never stars or team overall
	var a := League.make_team(1, 4)
	var b := League.make_team(1, 4)
	for p in b.starters():
		p.stars = 5.0   # (shown stars only: no attribute changed)
	r.check(is_equal_approx(Difficulty.team_strength(a), Difficulty.team_strength(b)) and b.team_overall() != a.team_overall(),
		"matchup strength reads attributes, not the stars or team overall")
	# a completed career game records and moves it (a career in memory: nothing written to disk)
	var was: Career = Game.career
	var c := Career.new()
	c.difficulty = "dynamic"
	c.dyn_ai = 0.5
	Game.career = c
	for i in 6:
		Difficulty.after_game(true, 12, 4, a, League.make_team(1, 4))
	var moved := c.dyn_ai
	c.difficulty = "hard"
	Difficulty.after_game(true, 12, 4, a, League.make_team(1, 4))
	Game.career = was
	r.check(moved > 0.55 and moved <= 0.5 + 6 * Difficulty.DYN_MAX_STEP + 1e-6 and c.dyn_hist.size() == Difficulty.DYN_WINDOW, "after_game moves a career's DYNAMIC and keeps the last 5 games (%.3f)" % moved)
	r.check(is_equal_approx(c.dyn_ai, moved), "...and a fixed mode leaves the dynamic level alone")

# ------------------------------------------------------------------ 12. fixed for the match
func _t12_locked_in_match() -> void:
	var was: Career = Game.career
	var c := Career.new()
	c.difficulty = "dynamic"
	c.dyn_ai = 0.35
	Game.career = c
	var level := Difficulty.level_for(true)
	var f := MatchFlow.new(League.make_team(2, 0), League.make_team(5, 0), 4242, 2.0, level)
	var levels := {}
	var steps := 0
	while f.phase != MatchFlow.Phase.FINAL and steps < 200000:
		steps += 1
		match f.phase:
			MatchFlow.Phase.SPRINT:
				f.sprint_done(f.rng.randf() < 0.5)
			MatchFlow.Phase.ATTACK:
				levels["their defence %.3f" % f.play.level] = true
				r._run_flow_attack(f)
				f.attack_done()
			MatchFlow.Phase.DEFENSE:
				levels["their offence %.3f" % f.opp_ai.iq] = true
				levels["your defence %.3f" % f.play.level] = true
				f.auto_defense(0.5)
				f.defense_done()
			MatchFlow.Phase.SHOOTOUT_THEM:
				f.their_ball_done()
			MatchFlow.Phase.THEIR_SHOT:
				f.auto_duel(0.5)
				f.duel_done()
			MatchFlow.Phase.BREAK:
				f.break_done()
		levels["flow %.3f" % f.level] = true
		levels["career %.3f" % c.dyn_ai] = true
	Game.career = was
	print("  levels seen through a match: %s" % str(levels.keys()))
	r.check(levels.keys().all(func(k): return String(k).ends_with("%.3f" % level) or String(k).begins_with("your defence 0.500")),
		"the level is the one set at kick-off all match: goals, quarters, penalties and comebacks change nothing")
	r.check(levels.has("your defence 0.500"), "your own AI defenders play at MEDIUM whatever the level")

# ------------------------------------------------------------------ 13. your keeper
## KeeperDuel as it was before the overhaul at NORMAL (the old formulas, written out).
func _t13_your_keeper() -> void:
	var same := true
	for v in [1.0, 4.0, 5.0, 7.5, 10.0]:
		var gk := _keeper(v)
		for lv in LEVELS:
			var d := KeeperDuel.new().setup_given(gk, Vector2(24, 10), 11.0, 0.4, 0.0, Geo.GOAL_Y, lv)
			var k := Attributes.keeper_skill(gk, "leg")
			var legs := Attributes.leg_reach(gk)
			same = same and is_equal_approx(d.lunge, lerpf(0.6, 0.85, k) * legs) \
				and is_equal_approx(d.reach, lerpf(0.4, 0.62, k) * legs) \
				and is_equal_approx(d.quick, 1.0 / Attributes.lunge_mult(gk)) \
				and is_equal_approx(d.window, Attributes.dive_window(gk)) \
				and is_equal_approx(d.slowmo, 0.55) and is_equal_approx(d.block, Attributes.block_mod(gk))
	r.check(same, "your keeper's dive is the old NORMAL one at every level: reach, speed, window, hands, slow motion")
	# the duel's results at MEDIUM are the old NORMAL's to the shot (test_duel's numbers before the overhaul)
	var shooter := PoloPlayer.new()
	shooter.shoot = 62
	var gk2 := PoloPlayer.new()
	gk2.pos = PoloPlayer.Pos.GK
	gk2.keeping = 62
	var rates := []
	for skill in [0.0, 0.4, 0.7, 1.0]:
		var rng := RandomNumberGenerator.new()
		rng.seed = 5
		var brng := RandomNumberGenerator.new()
		brng.seed = 6
		var goals := 0
		for i in 2000:
			var from: Vector2 = OppSim.SPOTS[i % OppSim.SPOTS.size()][1] + Vector2(0, rng.randf_range(-2.0, 2.0))
			var d := KeeperDuel.new().setup(shooter, gk2, from, 0.0, rng, 0.5)
			goals += int(d.auto(skill, brng) == "goal")
		rates.append(snappedf(goals / 2000.0, 0.01))
	print("  your keeper, bot skill 0 / 0.4 / 0.7 / 1: %s (before: %s)" % [str(rates), str(BEFORE_DUEL)])
	var same_rates := true
	for i in rates.size():
		same_rates = same_rates and absf(float(rates[i]) - float(BEFORE_DUEL[i])) < 0.001
	r.check(same_rates, "...and plays out shot for shot as before")
	# the controls: a tap's thirds and a running dive ignoring taps
	r.check(KeeperDive.zone_for(Geo.GOAL_Y - 1.0) == KeeperDive.LEFT and KeeperDive.zone_for(Geo.GOAL_Y) == KeeperDive.CENTRE and KeeperDive.zone_for(Geo.GOAL_Y + 1.0) == KeeperDive.RIGHT,
		"tap thirds: LEFT, CENTRE, RIGHT as before")
	var dd := KeeperDuel.new().setup_given(_keeper(), Vector2(24, 10), 11.0, 0.4, 0.0, Geo.GOAL_Y, 0.5)
	dd.dive(1)
	r.check(not dd.can_dive(), "a running dive still ignores another tap")

## test_duel's "level +0.0" line on the game before the overhaul (the baseline run's log).
const BEFORE_DUEL := [0.77, 0.49, 0.35, 0.17]

# ------------------------------------------------------------------ 14. team overall changes nothing
func _t14_team_overall() -> void:
	var log_of := func(bump: bool) -> Array:
		var a := League.make_team(2, 7)
		var b := League.make_team(4, 7)
		if bump:
			for p in a.roster + b.roster:
				p.stars = 5.0 if p.stars < 3.0 else 0.5   # (shown stars: team overall swings, attributes don't)
		var out := [a.team_overall(), b.team_overall()]
		var f := MatchFlow.new(a, b, 5151, 2.0, 0.5)
		var steps := 0
		while f.phase != MatchFlow.Phase.FINAL and steps < 200000:
			steps += 1
			match f.phase:
				MatchFlow.Phase.SPRINT:
					f.sprint_done(f.rng.randf() < 0.5)
				MatchFlow.Phase.ATTACK:
					r._run_flow_attack(f)
					out.append(String(f.play.result.get("outcome", "")))
					f.attack_done()
				MatchFlow.Phase.DEFENSE:
					f.auto_defense(0.5)
					out.append(String(f.play.result.get("outcome", "")))
					f.defense_done()
				MatchFlow.Phase.SHOOTOUT_THEM:
					f.their_ball_done()
				MatchFlow.Phase.THEIR_SHOT:
					f.auto_duel(0.5)
					f.duel_done()
				MatchFlow.Phase.BREAK:
					f.break_done()
		out.append(str(f.state.score))
		return out
	var x: Array = log_of.call(false)
	var y: Array = log_of.call(true)
	print("  team overall %.1f / %.1f vs %.1f / %.1f: %s vs %s" % [x[0], x[1], y[0], y[1], x[-1], y[-1]])
	r.check(absf(float(x[0]) - float(y[0])) > 5.0, "the team overall really is different")
	r.check(x.slice(2) == y.slice(2), "...and every possession comes out exactly the same")

# ------------------------------------------------------------------ 15. saves
func _t15_saves() -> void:
	var c: Career = r._v2_career("CULA", 515)
	var before := {}
	for p in c.team().roster:
		before[p.id] = p.attrs.duplicate()
	var d: Dictionary = c.to_dict()
	# a save from before the overhaul: no difficulty or dyn_ai, the old -1..+1 dynamic level
	d.erase("difficulty")
	d.erase("dyn_ai")
	d.erase("dyn_hist")
	d["dyn_level"] = -0.6
	var old := Career.from_dict(JSON.parse_string(JSON.stringify(d)))
	r.check(old != null and old.year == c.year and old.week == c.week and old.school == c.school, "an older save loads, its career where it was")
	r.check(is_equal_approx(old.dyn_ai, 0.2) and old.dyn_hist.is_empty(), "...its dynamic level comes across (-0.6 is 0.2 now)")
	r.check(old.difficulty in Difficulty.MODES, "...and it has a difficulty (the device's pick: %s)" % old.difficulty)
	var same := true
	for p in old.team().roster:
		same = same and before.has(p.id) and p.attrs == before[p.id]
	r.check(same, "...every player's attributes untouched")
	d.erase("dyn_level")
	var older := Career.from_dict(JSON.parse_string(JSON.stringify(d)))
	r.check(is_equal_approx(older.dyn_ai, Difficulty.DYN_START), "no dynamic data at all: it starts at 0.50")
	# the new fields survive a save
	old.difficulty = "hard"
	old.dyn_ai = 0.65
	old.dyn_hist = [{"m": 3, "gap": 0.1}, {"m": -2, "gap": -0.4}]
	var back := Career.from_dict(JSON.parse_string(JSON.stringify(old.to_dict())))
	r.check(back.difficulty == "hard" and is_equal_approx(back.dyn_ai, 0.65) and back.dyn_hist.size() == 2 and int(back.dyn_hist[1].m) == -2,
		"difficulty, the dynamic level and its history are saved and loaded")
	var was: Career = Game.career
	Game.career = back
	r.check(Difficulty.mode(true) == "hard" and is_equal_approx(Difficulty.level_for(true), 1.0), "a loaded career plays at its own difficulty")
	back.difficulty = "dynamic"
	r.check(is_equal_approx(Difficulty.level_for(true), 0.65), "...DYNAMIC at its saved level")
	Game.career = was
	var fresh: Node = load("res://src/autoload/game.gd").new()
	r.check(String(fresh.settings.difficulty) == "normal", "MEDIUM is the default for a new player")
	fresh.free()

# ------------------------------------------------------------------ 16. their offence
## Whole matches, the same teams and seeds, the opposing offence at each level: how good a look
## it chooses to shoot (OffenseAI's own shot quality, averaged over every shot it took), how often
## it throws it away, and what it scores against the same bot keeper.
func _t16_offense() -> void:
	var q := []
	var g := []
	var lost := []
	for lv in LEVELS:
		var tot: Dictionary = load("res://tests/offense_stats.gd").new().run(r, 12, true, lv)
		var qs := 0.0
		var shots := 0.0
		for k in tot:
			if String(k).begins_with("q_"):
				qs += float(tot[k])
			elif String(k).begins_with("why_"):
				shots += float(tot[k])
		q.append(qs / maxf(1.0, shots))
		g.append(float(tot.get("goals", 0.0)) / 12.0)
		lost.append((float(tot.get("end_steal", 0.0)) + float(tot.get("end_turnover", 0.0))) / 12.0)
	print("  their offence, EASY / MEDIUM / HARD: shot quality chosen %.3f / %.3f / %.3f, goals per game %.2f / %.2f / %.2f" % (q + g))
	r.check(q[2] > q[1] and q[1] > q[0], "a smarter offence picks better looks to shoot")
	r.check(g[2] > g[0], "...and a HARD offence scores more than an EASY one with the same players")

# ------------------------------------------------------------------ 17. their defence
func _t17_defense() -> void:
	var cover := []
	var speed_same := true
	for lv in LEVELS:
		var in_lane := 0.0
		var samples := 0
		var tops := []
		for i in 25:
			var rng := RandomNumberGenerator.new()
			rng.seed = 7000 + i
			var p := Play.new(League.make_team(2, 1), League.make_team(3, 1), Play.Kind.HALF_COURT, rng)
			p.set_level(lv)
			tops.append(p.defenders.map(func(d: Swimmer): return [d.top_speed, d.accel]))
			var t := 0.0
			while t < 8.0 and not p.over:
				p.step(1.0 / 30.0)
				t += 1.0 / 30.0
				if p.holder == null or int(t * 30.0) % 6 != 0:
					continue
				# off the ball: how much of each passing lane from the ball to his man is covered
				for d in p.defenders:
					var m := d.mark
					if d.out or m == null or m == p.holder or m.tag == "C":
						continue
					var c := Geometry2D.get_closest_point_to_segment(d.pos, p.holder.pos, m.pos)
					in_lane += 1.0 if d.pos.distance_to(c) < 1.0 else 0.0
					samples += 1
		cover.append(in_lane / maxf(1.0, samples))
		if lv > 0.0:
			speed_same = speed_same and tops == _tops_easy
		else:
			_tops_easy = tops
	print("  their defenders within a metre of the passing lane, EASY / MEDIUM / HARD: %.2f / %.2f / %.2f" % cover)
	r.check(cover[2] > cover[0], "a HARD defence covers the passing lanes better")
	r.check(speed_same, "...with exactly the same swimmers: speed and acceleration don't change with the level")
	var src := FileAccess.get_file_as_string("res://src/match/play.gd") + FileAccess.get_file_as_string("res://src/match/play_ai.gd")
	r.check(not src.contains("steal_mult") and not src.contains("intercept_mult") and not src.contains("keeper_bonus"),
		"no difficulty multiplier on steals, interceptions or the keeper's rating is left")

var _tops_easy := []

# ------------------------------------------------------------------ 18. the keeper's body at every level
func _t18_keeper_physics() -> void:
	var k := _keeper(6.0)
	var same := true
	for lv in LEVELS:
		var outs := []
		for side in [-1, 0, 1]:
			var rng := RandomNumberGenerator.new()
			rng.seed = 88
			for i in 300:
				var from: Vector2 = (PERIMETER + CLOSE)[i % 10]
				var res := ShotModel.resolve(from, Geo.GOAL_Y + rng.randf_range(-1.4, 1.4), 0.8, 62.0, 4.0, [], Geo.GOAL_Y, 62.0, rng, false, {},
					_ctx(k, lv, {"dive_side": side}))
				outs.append([String(res.outcome), res.dive, float(res.keeper_go)])
		if lv == 0.0:
			_outs_easy = outs
		else:
			same = same and outs == _outs_easy
	r.check(same, "the same dive the same way: identical reach, timing and result at EASY, MEDIUM and HARD")
	var dv := Difficulty.params(1.0)
	r.check(not dv.has("reach") and not dv.has("lunge") and not dv.has("block") and not dv.has("speed"), "no physical parameter in the difficulty table")

var _outs_easy := []

# ------------------------------------------------------------------ balancing (Phase 20)
## The numbers behind the tuning: --test ai_balance [matches a level].
static func balance(runner, matches: int) -> void:
	var t := new()
	t.r = runner
	t._balance(matches)

func _balance(matches: int) -> void:
	print("AI balance")
	var k := _keeper()
	for lv in LEVELS:
		var all := _keeper_trial(k, lv, PERIMETER + CLOSE, 6000, 91)
		var far := _keeper_trial(k, lv, PERIMETER, 4000, 92)
		var near := _keeper_trial(k, lv, CLOSE, 4000, 93)
		print("  keeper %.1f: picks L/U/R %s, picked the way it went %.3f, right way %.3f; save rate perimeter %.3f, close %.3f; goals perimeter %.3f close %.3f" % [
			lv, str(all.picks), all.read, all.right, far.save, near.save, far.goal, near.goal])
	for v in [2.0, 5.0, 8.0]:
		var t := _keeper_trial(_keeper(v), 0.5, PERIMETER + CLOSE, 4000, 94)
		print("  MEDIUM keeper, all four at %.0f: save %.3f, goals %.3f" % [v, t.save, t.goal])
	for lv in LEVELS:
		var tot: Dictionary = load("res://tests/offense_stats.gd").new().run(r, matches, true, lv)
		print("  their offence %.1f over %d matches: goals/game %.2f" % [lv, matches, float(tot.get("goals", 0.0)) / matches])
	for lv in LEVELS:
		var s := {"goals": 0, "shots": 0, "pens": 0, "excl": 0, "steals": 0, "challenge": 0, "pulled": 0, "poss": 0}
		var acts := {}
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
						while not f.play.over and tt < 60.0:
							think -= 1.0 / 30.0
							if think <= 0.0:
								think = PlayBot.THINK_EVERY
								var d := PlayBot.think(f.play, f.rng)
								if not d.is_empty():
									f.play.throw(d.target, d.power)
							f.tick_attack(1.0 / 30.0)
							for dd in f.play.defenders:
								if dd.cdef > 0:
									acts[CenterDefense.ACT_NAMES[dd.cdef]] = int(acts.get(CenterDefense.ACT_NAMES[dd.cdef], 0)) + 1
							tt += 1.0 / 30.0
						for e in f.events:
							match String(e.k):
								"shot":
									s.shots += 1
								"penalty":
									s.pens += 1
								"exclusion":
									s.excl += 1
								"challenge":
									s.challenge += 1
								"pulled":
									s.pulled += 1
						f.events.clear()
						s.poss += 1
						if String(f.play.result.get("outcome", "")) == "goal":
							s.goals += 1
						if String(f.play.result.get("outcome", "")) == "steal":
							s.steals += 1
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
		print("  your bot attack vs their AI %.1f: goals/game %.2f, shots %.1f, steals %.2f, penalties %.2f, exclusions %.2f, challenges %.2f, pulls %.2f a game; answer frames %s" % [
			lv, s.goals / float(matches), s.shots / float(matches), s.steals / float(matches), s.pens / float(matches), s.excl / float(matches),
			s.challenge / float(matches), s.pulled / float(matches), str(acts)])

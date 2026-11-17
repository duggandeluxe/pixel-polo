extends RefCounted
## DROP POSITIONING & WING PRESS: M-DROP and 3-4 DROP keep both wings pressed (on the ball: tight;
## off it: denied, a hand in the lane), 5 DROP collapses its whole perimeter in round its dropper,
## 4-5 DROP drops both its pistons. The same for either defence, at either end.
##   godot --headless --path game -- --test drop_wings
## (F, the late drop and inside water: --test inside_water_penalty.)

const DT := 1.0 / 60.0
const F := DefenseFormation.F
const D := DefenseFormation.Duty

var r

func run(runner) -> void:
	r = runner
	var was := Play.instant_drops
	Play.instant_drops = true   # (the formation on at once: it's the positions being tested)
	print("drop wings: A M-DROP, B 3-4 DROP (the wings pressed)")
	for f in [F.M_DROP, F.THREE_FOUR]:
		_wings_pressed(f)
	print("drop wings: C 5 DROP (the collapse)")
	_five_collapse()
	print("drop wings: D 4-5 DROP (the double drop)")
	_double_drop()
	print("drop wings: E ball reversals")
	for f in [F.M_DROP, F.THREE_FOUR, F.FIVE_DROP, F.FOUR_FIVE]:
		_reversals(f)
	Play.instant_drops = was

# ------------------------------------------------------------------ helpers
func _settled(seed_value: int, f: int, tag: String, defending: bool) -> Play:
	var p: Play = r._center_play(seed_value, defending)
	for s in p.attackers + p.defenders:
		s.player.trait_id = ""
	p.give_ball(PlaySetup._by_tag(p, tag))
	p.select_formation(f)
	return p

func _a(p: Play, tag: String) -> Swimmer:
	return DefenseFormation.by_tag(p.attackers, tag)

func _d(p: Play, tag: String) -> Swimmer:
	return DefenseFormation.by_tag(p.defenders, tag, true)

func _steps(p: Play, secs: float) -> void:
	var t := 0.0
	while t < secs - 0.0001 and not p.over:
		p.freeze = 0.0 if p.holder != null and not p.restart else p.freeze
		p.step(DT)
		t += DT

func _feed(p: Play, m: Swimmer) -> bool:
	p.freeze = 0.0
	p._pass(p.lead_point(m), m)
	var t := 0.0
	while p.ball.state == Ball.State.PASS and t < 2.0 and not p.over:
		p.step(DT)
		t += DT
	return p.holder == m and not p.over

## Distance from `at` to the ball's line to `m` (the lane a pass to him goes down).
func _lane_off(p: Play, m: Swimmer, at: Vector2) -> float:
	var q := Geometry2D.get_closest_point_to_segment(at, p.ball.pos, m.pos)
	return at.distance_to(q)

func _who(defending: bool) -> String:
	return "your defence" if defending else "the computer's"

## The two defenders closest together (no two on one spot).
func _closest_pair(p: Play) -> float:
	var best := INF
	for i in p.defenders.size():
		for j in range(i + 1, p.defenders.size()):
			best = minf(best, p.defenders[i].pos.distance_to(p.defenders[j].pos))
	return best

# ------------------------------------------------------------------ A, B (and G: both ends)
func _wings_pressed(f: int) -> void:
	var name: String = DefenseFormation.NAMES[f]
	for defending in [true, false]:
		# the ball at the point: both wings off the ball, both denied
		var far := {}
		for boost in [false, true]:
			DefenseFormation.wing_boost = boost
			var p := _settled(9100 + f, f, "3", defending)
			_steps(p, 2.5)
			var worst := 0.0
			var lane := 0.0
			var duties := true
			for w in ["1", "5"]:
				var dw := _d(p, w)
				var aw := _a(p, w)
				worst = maxf(worst, dw.pos.distance_to(aw.pos))
				lane = maxf(lane, _lane_off(p, aw, dw.pos))
				duties = duties and dw.duty == D.MARK and dw.mark == aw
			far[boost] = worst
			if boost:
				r.check(duties, "%s, %s: both wings' own men are on them (MARK), not dropped" % [name, _who(defending)])
				r.check(worst < 1.5, "%s, %s: ball at the point, both wings tight (furthest %.2f m)" % [name, _who(defending), worst])
				r.check(lane <= DefenseFormation.TIP_REACH + 0.25, "%s, %s: ...each a hand in the lane from the ball (%.2f m off it)" % [name, _who(defending), lane])
				var c := _a(p, "C")
				r.check(p.f_dropper != null and p.f_dropper.pos.distance_to(c.pos) < 2.2, "%s, %s: ...while the dropper protects the centre (%.2f m)" % [name, _who(defending), p.f_dropper.pos.distance_to(c.pos) if p.f_dropper != null else -1.0])
		DefenseFormation.wing_boost = true
		print("    %s, %s: furthest wing defender off his wing, ball at the point: %.2f m before -> %.2f m now" % [name, _who(defending), far[false], far[true]])
		# the ball at a wing: pressed hard, the far wing still denied
		var q := _settled(9200 + f, f, "3", defending)
		_steps(q, 2.0)
		var w1 := _a(q, "1")
		if _feed(q, w1):
			_steps(q, 1.2)
			var on := _d(q, "1").pos.distance_to(w1.pos)
			var other := _d(q, "5").pos.distance_to(_a(q, "5").pos)
			r.check(DefenseFormation.wing_pressure(q, w1) and on < 1.3, "%s, %s: A1 has it: pressed (%.2f m)" % [name, _who(defending), on])
			r.check(other < 1.6, "%s, %s: ...the far wing stays denied, not sagging into the hole (%.2f m)" % [name, _who(defending), other])
	# passes out to the wings: the denial gets a hand to more of them (the game's own tips, nothing forced)
	for ff in ([F.M_DROP, F.THREE_FOUR] if f == F.M_DROP else []):
		var tips := {}
		for boost in [false, true]:
			DefenseFormation.wing_boost = boost
			var n := 0
			for sd in 60:
				var p := _settled(9700 + sd, ff, ["2", "3", "4"][sd % 3], sd % 2 == 0)
				_steps(p, 2.0)
				var to := _a(p, "1" if sd % 2 == 0 else "5")
				p.freeze = 0.0
				p._pass(p.lead_point(to), to)
				var t := 0.0
				while p.ball.state == Ball.State.PASS and t < 2.0 and not p.over:
					p.step(DT)
					t += DT
				n += 1 if p.events.any(func(e): return String(e.get("k", "")) in ["tip", "steal", "intercept"]) else 0
			tips[boost] = n
		DefenseFormation.wing_boost = true
		print("    %s: passes to a wing with a hand to them: %d of 60 before -> %d of 60 now" % [DefenseFormation.NAMES[ff], tips[false], tips[true]])
		r.check(int(tips[true]) > int(tips[false]) and int(tips[true]) < 30, "%s: the wing denial gets to more wing passes (%d -> %d of 60), never all of them" % [DefenseFormation.NAMES[ff], tips[false], tips[true]])
	# the exempt drops: no wing press
	var x := _settled(9300, F.FIVE_DROP, "1", true)
	var y := _settled(9301, F.FOUR_FIVE, "1", true)
	r.check(not DefenseFormation.wing_pressure(x, _a(x, "1")) and not DefenseFormation.wing_pressure(y, _a(y, "1")), "5 DROP and 4-5 DROP don't force the wing press")

# ------------------------------------------------------------------ C
func _five_collapse() -> void:
	for defending in [true, false]:
		var p := _settled(9400, F.FIVE_DROP, "2", defending)
		var press := _settled(9400, F.PRESS, "2", defending)
		_steps(p, 3.0)
		_steps(press, 3.0)
		var c := _a(p, "C")
		var five := DefenseFormation.slot(p, "5")
		var dr := _d(p, five)
		r.check(p.f_dropper == dr and dr.duty in [D.DROP, D.CRASH] and dr.pos.distance_to(c.pos) < 2.0,
			"5 DROP, %s: D5 (D%s) fronts the centre (%.2f m)" % [_who(defending), five, dr.pos.distance_to(c.pos)])
		var sags := 0
		var in_drop := 0.0
		var in_press := 0.0
		var ball2 := DefenseFormation.by_tag(p.attackers, "2")
		for n in ["1", "2", "3", "4"]:
			var t := DefenseFormation.slot(p, n)
			var s := _d(p, t)
			if _a(p, t) == ball2:
				r.check(s.duty in [D.MARK, D.CLOSE] and s.pos.distance_to(ball2.pos) < 2.0, "5 DROP, %s: the man on the ball (D%s) stays on him (%.2f m)" % [_who(defending), t, s.pos.distance_to(ball2.pos)])
				continue
			sags += 1 if s.duty == D.SAG and s.mark == _a(p, t) else 0
			in_drop += s.pos.distance_to(c.pos)
			in_press += _d(press, t).pos.distance_to(_a(press, "C").pos)
		r.check(sags == 3, "5 DROP, %s: the other three perimeter men all sag in (%d of 3)" % [_who(defending), sags])
		r.check(in_drop < in_press - 1.5, "5 DROP, %s: compact round the centre: %.1f m in all against PRESS's %.1f m" % [_who(defending), in_drop, in_press])
		r.check(_closest_pair(p) > 0.6, "5 DROP, %s: nobody on top of anybody (closest pair %.2f m)" % [_who(defending), _closest_pair(p)])
		# a shooter sags less than a poor one
		var aa := _a(p, "3")
		var hi := DefenseFormation.sag_spot(aa, DefenseFormation.drop_spot(p, c))
		var keep: PoloPlayer = aa.player
		aa.player = AttrBench.player({"sho": 2.0}, false, {}, PoloPlayer.Pos.UTILITY)
		var lo := DefenseFormation.sag_spot(aa, DefenseFormation.drop_spot(p, c))
		aa.player = AttrBench.player({"sho": 9.5}, false, {}, PoloPlayer.Pos.UTILITY)
		var sh := DefenseFormation.sag_spot(aa, DefenseFormation.drop_spot(p, c))
		aa.player = keep
		r.check(sh.distance_to(aa.pos) < lo.distance_to(aa.pos) and hi != Vector2.INF, "5 DROP: a good shooter is sagged off less (%.2f m vs %.2f m)" % [sh.distance_to(aa.pos), lo.distance_to(aa.pos)])

# ------------------------------------------------------------------ D
func _double_drop() -> void:
	for defending in [true, false]:
		var p := _settled(9500, F.FOUR_FIVE, "3", defending)
		_steps(p, 3.0)
		var c := _a(p, "C")
		var pair := DefenseFormation.piston_tags(p)
		var dn := _d(p, pair[1])
		var dout := _d(p, pair[0])
		r.check(p.f_in == dn and dn.duty in [D.DROP, D.CRASH] and dn.pos.distance_to(c.pos) < 2.0,
			"4-5 DROP, %s: D%s fronts the centre (%.2f m)" % [_who(defending), pair[1], dn.pos.distance_to(c.pos)])
		r.check(dout.duty == D.SAG and dout.pos.distance_to(c.pos) < 3.2 and dout.pos.distance_to(dn.pos) > 1.0,
			"4-5 DROP, %s: D%s collapses in beside him (%.2f m off the centre, %.2f m from D%s)" % [_who(defending), pair[0], dout.pos.distance_to(c.pos), dout.pos.distance_to(dn.pos), pair[1]])
		# deeper than the half-way piston spot (the 3-4's, PISTON_SAG) would have him
		var m := _a(p, pair[0])
		var half := (m.pos + (Geo.goal_center() - m.pos).normalized() * 1.1).lerp(DefenseFormation.drop_spot(p, c), DefenseFormation.PISTON_SAG)
		r.check(dout.pos.distance_to(c.pos) < 2.2 and dout.pos.distance_to(m.pos) > half.distance_to(m.pos) + 0.2,
			"4-5 DROP, %s: a true double drop: beside the centre (%.2f m), further off his man than a half-way piston (%.2f vs %.2f m)" % [_who(defending), dout.pos.distance_to(c.pos), dout.pos.distance_to(m.pos), half.distance_to(m.pos)])
		var perim := true
		for n in ["1", "2"]:
			var t := DefenseFormation.slot(p, n)
			perim = perim and _d(p, t).duty == D.MARK and _d(p, t).mark == _a(p, t)
		r.check(perim, "4-5 DROP, %s: the other side holds the perimeter, man to man" % _who(defending))
		r.check(_closest_pair(p) > 0.6, "4-5 DROP, %s: nobody on top of anybody (closest pair %.2f m)" % [_who(defending), _closest_pair(p)])

# ------------------------------------------------------------------ E
func _reversals(f: int) -> void:
	var name: String = DefenseFormation.NAMES[f]
	for defending in [true, false]:
		var p := _settled(9600 + f, f, "1", defending)
		_steps(p, 2.0)
		var seq := ["2", "3", "4", "5", "4", "3", "2", "1", "2", "3"]
		var caught := 0
		var drop_ok := true
		var wings_ok := true
		var spread := INF
		var worst_wing := 0.0
		var tipped := 0
		for tag in seq:
			if p.over or p.holder == null:
				break
			var tips_before := p.events.filter(func(e): return String(e.get("k", "")) == "tip").size()
			if not _feed(p, _a(p, tag)):
				if p.over or p.events.filter(func(e): return String(e.get("k", "")) == "tip").size() == tips_before:
					break
				tipped += 1   # (a hand to it in the lane: theirs again, carry on)
				p.give_ball(_a(p, tag))
			caught += 1
			_steps(p, 0.9)
			var c := _a(p, "C")
			var dr := p.f_dropper
			drop_ok = drop_ok and p.formation == f and dr != null and dr.pos.distance_to(c.pos) < 3.0
			spread = minf(spread, _closest_pair(p))
			if DefenseFormation.presses_wings(f):
				for w in ["1", "5"]:
					var dist := _d(p, w).pos.distance_to(_a(p, w).pos)
					worst_wing = maxf(worst_wing, dist)
					wings_ok = wings_ok and dist < 1.8
		r.check(caught >= 8, "E %s, %s: the ball goes round (%d passes, %d tipped)" % [name, _who(defending), caught, tipped])
		r.check(drop_ok, "E %s, %s: the formation holds and somebody's always in front of the centre" % [name, _who(defending)])
		r.check(spread > 0.5, "E %s, %s: it never bunches onto one spot (closest pair %.2f m)" % [name, _who(defending), spread])
		if DefenseFormation.presses_wings(f):
			r.check(wings_ok, "E %s, %s: both wings stay pressed through every reversal (furthest %.2f m)" % [name, _who(defending), worst_wing])

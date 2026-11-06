extends RefCounted
## The gameplay update: the 2 m battle (the centre wins inside water every 5-10 s for a 3-5 s
## window), the transition taking 10 s off both clocks, the clocks at 1.25x, and every man in the
## attack able to pass to every other, right across the pool.
##   godot --headless --path game -- --test update

const DT := 1.0 / 60.0
const TAGS := ["C", "1", "2", "3", "4", "5"]
const NAMES := {"C": "centre", "1": "right corner", "2": "right wing", "3": "point", "4": "left wing", "5": "left corner"}

var r   # the test runner (check, check_between)

func run(runner) -> void:
	r = runner
	_battle()
	_entries()
	_clock_speed()
	_transitions()
	_mp_transition()
	_all_passes()
	_tap_targets()
	_long_pass_lane()

# ------------------------------------------------------------------ the 2 m battle
## A set possession, the ball held up by `from` (or swung round the arc every `swing` s), the
## clocks and the press kept off: just the centre and his man, for `secs`.
func _battle_play(seed_value: int, defending: bool, from_tag: String, secs: float, swing: float = 0.0) -> Dictionary:
	var p: Play = r._center_play(seed_value, defending)
	var c := PlaySetup._by_tag(p, "C")
	p.give_ball(PlaySetup._by_tag(p, from_tag))
	var g0 := p._center_guard(c)   # (set up fronting him, as he'd be once the attack's set)
	g0.pos = c.pos + PlayAI.front_dir(c, p.holder.pos, 1) * PlayAI.CENTER_FRONT
	g0.target = g0.pos
	var arc := ["5", "4", "3", "2", "1", "2", "3", "4"]
	var arc_i := arc.find(from_tag)
	var opens: Array = []        # [start, end] of each stretch the entry from the ball was open
	var open_at := -1.0
	var open_k := ""
	var hold_open := 0.0         # open looks in HOLD (the ball swung round before his man came round)
	var fronted_hold := 0.0
	var locked := 0.0
	var live := 0.0
	var g_min := Vector2(INF, INF)
	var g_max := -Vector2(INF, INF)
	var c_min := Vector2(INF, INF)
	var c_max := -Vector2(INF, INF)
	var last_rel := Vector2.ZERO
	var turn := 0.0              # how far the guard went round the centre, radians, all told
	var next_swing := swing
	var t := 0.0
	var phases := {}
	while t < secs and not p.over:
		p.shot_clock = Play.SHOT_CLOCK   # (this is about the battle)
		p.pressure = 0.0
		p.foul_t = 0.0   # (no whistle: DefenseFormation's contact fouls too)
		if swing > 0.0 and t >= next_swing and p.ball.state == Ball.State.HELD:
			next_swing += swing
			arc_i = (arc_i + 1) % arc.size()
			p.pass_to(PlaySetup._by_tag(p, arc[arc_i]))
		p.raise_ball(p.ball.state == Ball.State.HELD)
		p.step(DT)
		t += DT
		var g := p._center_guard(c)
		if g == null or p.holder == null or p.ball.state != Ball.State.HELD or p.holder == c:
			continue
		live += DT
		var e := p.center_entry(p.holder.pos, c)
		var k := ["HOLD", "SPIN", "SEALED", "ROUND"][p.cfight] as String
		phases[k] = float(phases.get(k, 0.0)) + DT
		if e == "open" or e == "straight":   # (his man off the lane: the centre has it)
			if open_at < 0.0:
				open_at = t
				open_k = k
			if p.cfight == PlayAI.Fight.HOLD:
				hold_open += DT
		elif open_at >= 0.0:
			opens.append([open_at, t, open_k, k, e])
			open_at = -1.0
		if e == "fronted" and p.cfight == PlayAI.Fight.HOLD:
			fronted_hold += DT
		if c.grip > 0.9 and g.grip > 0.9:
			locked += DT
		g_min = g_min.min(g.pos)
		g_max = g_max.max(g.pos)
		c_min = c_min.min(c.pos)
		c_max = c_max.max(c.pos)
		var rel := g.pos - c.pos
		if last_rel != Vector2.ZERO:
			turn += absf(last_rel.angle_to(rel))
		last_rel = rel
	return {"opens": opens, "hold_open": hold_open, "fronted_hold": fronted_hold, "locked": locked, "live": live,
		"g_range": g_max - g_min, "c_range": c_max - c_min, "turn": turn, "phases": phases, "over": p.over}

func _battle() -> void:
	print("the 2 m battle")
	var durs: Array[float] = []
	var gaps: Array[float] = []
	var firsts: Array[float] = []
	var locked := 0.0
	var live := 0.0
	var still := 0
	var fronted_ok := 0
	var runs := 0
	var stray := 0.0
	for defending in [false, true]:
		for i in 12:
			var from: String = ["2", "4", "1", "5", "3"][i % 5]
			var b := _battle_play(400 + i, defending, from, 60.0)
			runs += 1
			var opens: Array = b.opens
			if not opens.is_empty():
				firsts.append(float(opens[0][0]))
			for j in opens.size():
				var o: Array = opens[j]
				durs.append(float(o[1]) - float(o[0]))
				if j > 0:
					gaps.append(float(o[0]) - float(opens[j - 1][1]))
			locked += float(b.locked)
			live += float(b.live)
			stray += float(b.hold_open)
			if (b.g_range as Vector2).length() > 0.25 and (b.c_range as Vector2).length() > 0.15 and float(b.turn) > PI:
				still += 1
			if float(b.fronted_hold) > 0.8 * float(b.phases.get("HOLD", 1.0)):
				fronted_ok += 1
	durs.sort()
	gaps.sort()
	firsts.sort()
	var n_open := durs.size()
	print("  %d possessions of 60 s, the ball held on one spot: %d openings, %.1f per minute" % [runs, n_open, n_open / float(runs)])
	print("  first opening after %.1f..%.1f s; open %.2f..%.2f s (median %.2f); %.1f..%.1f s between (median %.1f)" % [
		firsts.front(), firsts.back(), durs.front(), durs.back(), durs[n_open / 2], gaps.front(), gaps.back(), gaps[gaps.size() / 2]])
	print("  locked up %.0f%% of the time; open while he holds him (the ball still) %.2f s in all" % [100.0 * locked / live, stray])
	r.check(n_open >= runs * 4, "the centre wins inside water again and again over a long possession (%d openings)" % n_open)
	r.check(firsts.front() >= 5.0 and firsts.back() <= 10.8, "the first opening comes 5-10 s in (%.1f..%.1f s)" % [firsts.front(), firsts.back()])
	r.check(durs.front() >= 2.9 and durs.back() <= 5.2, "each opening lasts 3-5 s, judged by where the two of them are (%.2f..%.2f s)" % [durs.front(), durs.back()])
	r.check(gaps.front() >= 4.9 and gaps.back() <= 11.0, "...and the next comes 5-10 s later (%.1f..%.1f s)" % [gaps.front(), gaps.back()])
	r.check(gaps[gaps.size() - 1] - gaps[0] > 2.5 and durs[n_open - 1] - durs[0] > 1.0, "the timing varies: not on a script")
	r.check(stray < 0.5, "with the ball still, the centre's only open in his windows: never left open (%.2f s)" % stray)
	r.check(fronted_ok == runs, "between the windows his man fronts him: the entry from the ball is his (%d of %d)" % [fronted_ok, runs])
	r.check(locked > live * 0.85, "the two of them are locked up nearly all the time (%.0f%%)" % (100.0 * locked / live))
	r.check(still == runs, "both keep moving: the guard goes round him and back, the centre shifts (%d of %d)" % [still, runs])
	# the art: the centre seals with his arm hooked back round his man only once he's won it
	var p: Play = r._center_play(77, false)
	var c := PlaySetup._by_tag(p, "C")
	p.give_ball(PlaySetup._by_tag(p, "2"))
	var hooked_hold := false
	var hooked_seal := false
	for _i in 900:
		p.shot_clock = Play.SHOT_CLOCK
		p.pressure = 0.0
		p.foul_t = 0.0   # (no whistle: DefenseFormation's contact fouls too)
		p.raise_ball(true)
		p.step(DT)
		if p.cfight == PlayAI.Fight.HOLD and c.hook:
			hooked_hold = true
		if p.cfight == PlayAI.Fight.SEALED and c.hook:
			hooked_seal = true
	r.check(hooked_seal and not hooked_hold, "the centre hooks his man only once he's sealed him")
	# swinging it still opens the other side for a beat: more open looks than holding it
	var swung := 0.0
	var swung_live := 0.0
	var held := 0.0
	var held_live := 0.0
	for i in 8:
		var s := _battle_play(600 + i, i % 2 == 0, "4", 40.0, 2.6)
		var h := _battle_play(600 + i, i % 2 == 0, "4", 40.0)
		for o: Array in s.opens:
			swung += float(o[1]) - float(o[0])
		for o: Array in h.opens:
			held += float(o[1]) - float(o[0])
		swung_live += float(s.live)
		held_live += float(h.live)
	print("  the entry open from the ball, 8 x 40 s: swinging it round %.0f%% of the time, holding it %.0f%%" % [100.0 * swung / swung_live, 100.0 * held / held_live])
	r.check(swung / swung_live > held / held_live * 1.15, "swinging the ball round makes more entry angles than holding it")

## The entry, at any moment of the battle: his man in the lane (between the ball and the centre)
## picks it off, every time; his man behind the centre never gets it. Both attacks.
func _entries() -> void:
	print("entries during the battle")
	for defending in [false, true]:
		var who := "theirs" if defending else "yours"
		var tally := {}
		var by_guard_open := 0
		for sd in 240:
			var p: Play = r._center_play(2000 + sd, defending)
			var c := PlaySetup._by_tag(p, "C")
			for a in p.attackers + p.defenders:
				a.player.trait_id = ""
			var from: String = ["1", "2", "3", "4", "5"][sd % 5]
			p.give_ball(PlaySetup._by_tag(p, from))
			var rng := RandomNumberGenerator.new()
			rng.seed = sd
			var wait := rng.randf_range(0.5, 18.0)
			var t := 0.0
			while t < wait and not p.over:
				p.shot_clock = Play.SHOT_CLOCK
				p.pressure = 0.0
				p.foul_t = 0.0   # (no whistle: DefenseFormation's contact fouls too)
				p.raise_ball(true)
				p.step(DT)
				t += DT
			if p.over or p.holder == null:
				continue
			var g := p._center_guard(c)
			var behind := g != null and PlayAI.is_behind(g, c, p.holder.pos)
			p.raise_ball(false)
			p.pass_to(c)
			var e := p.entry
			var f := 0.0
			while p.ball.state == Ball.State.PASS and f < 2.0:
				p.step(DT)
				f += DT
			var out := "catch" if p.holder == c else ("steal" if p.over and String(p.result.outcome) == "steal" else "other")
			# (the possession's first pass thrown straight through him is his by the first-pass rule: Play._first_entry_plan)
			var first_rule := p.events.any(func(ev): return String(ev.k) == "first_entry")
			if p.over and String(p.result.outcome) == "steal" and g != null and p.result.by == g.player and e != "fronted" and not first_rule:
				by_guard_open += 1
			var k := "%s%s" % [e, " (behind)" if behind else ""]
			if not tally.has(k):
				tally[k] = {}
			tally[k][out] = int(tally[k].get(out, 0)) + 1
		print("  %s: %s" % [who, str(tally)])
		var fr: Dictionary = tally.get("fronted", {})
		var fn := 0
		for k in fr:
			fn += int(fr[k])
		var ob: Dictionary = tally.get("open (behind)", {})
		var on := 0
		for k in ob:
			on += int(ob[k])
		# (his hands on it every time: picked off, or knocked loose under his nose, DefenseFormation.FRONT_LOOSE)
		r.check(fn > 30 and int(fr.get("steal", 0)) + int(fr.get("other", 0)) == fn and int(fr.get("steal", 0)) > fn / 2,
			"%s: into a fronted centre, his man has it every time: picked off or knocked loose (%d)" % [who, fn])
		r.check(on > 30 and int(ob.get("catch", 0)) == on, "%s: with his man behind him the centre catches every one (%d)" % [who, on])
		r.check(not tally.has("fronted (behind)"), "%s: a man behind the centre is never fronting him" % who)
		r.check(by_guard_open == 0, "%s: his man never picks off an entry he isn't fronting" % who)

# ------------------------------------------------------------------ the clocks
func _clock_speed() -> void:
	print("the clocks at 1.25x")
	var teams: Array = r._teams()
	var f := MatchFlow.new(teams[0], teams[1], 77, MatchState.QUARTER_MIN)
	f._start_attack(Play.Kind.HALF_COURT)
	var p := f.play
	var h := p.holder
	var c0 := f.state.clock
	var sc0 := p.shot_clock
	var top := h.top_speed
	var frames := 0
	for _i in 240:   # 8 real seconds
		p.pressure = 0.0
		p.foul_t = 0.0   # (no whistle: DefenseFormation's contact fouls too)
		p.raise_ball(true)
		f.tick_attack(1.0 / 30.0)
		frames += 1
		if p.over:
			break
	var live := p.elapsed
	print("  8 real s: %.2f s live, %.2f s off the game clock, %.2f s off the shot clock" % [live, c0 - f.state.clock, sc0 - p.shot_clock])
	r.check(absf(live - 8.0) < 0.05, "8 real seconds of play are 8 live seconds (the play isn't sped up)")
	r.check(absf((c0 - f.state.clock) - 10.0) < 0.05, "8 real seconds take 10 s off the game clock")
	r.check(absf((sc0 - p.shot_clock) - 10.0) < 0.05, "...and 10 s off the shot clock: the two stay together")
	r.check(h.top_speed == top and Engine.time_scale == 1.0, "swimmers, the ball and the engine run at normal speed")
	r.check(is_equal_approx(f.state.quarter_len, MatchState.QUARTER_MIN * 60.0) and MatchState.QUARTER_MIN == 2.0, "quarters are still 2:00 of game clock")
	# a quarter's last 3 s go in 2.4 real s, and it ends on 0:00
	var g := MatchFlow.new(teams[0], teams[1], 78, MatchState.QUARTER_MIN)
	g._start_attack(Play.Kind.HALF_COURT)
	g.state.clock = 3.0
	var n := 0
	while not g.play.over and n < 300:
		g.play.pressure = 0.0
		g.play.foul_t = 0.0   # (no whistle: DefenseFormation's contact fouls too)
		g.play.raise_ball(true)
		g.tick_attack(1.0 / 30.0)
		n += 1
	r.check(g.play.over and String(g.play.result.outcome) == "buzzer" and g.state.clock == 0.0, "the quarter still ends at 0:00 (%s)" % g.state.clock_text())
	r.check(n >= 70 and n <= 74, "3 game seconds go in 2.4 real seconds (%d frames)" % n)
	g.attack_done()
	r.check(g.phase == MatchFlow.Phase.BREAK and g.state.clock == 0.0, "...then the quarter break, the clock on 0:00, not below")
	g.break_done()
	r.check(g.state.quarter == 2 and g.state.clock_text() == "2:00", "Q2 starts at 2:00")
	g.sprint_done(true)
	r.check(g.play.shot_clock == Play.SHOT_CLOCK, "...with a fresh 30 s shot clock")

func _held(f: MatchFlow, secs: float) -> void:
	var t := 0.0
	while t < secs - 0.001 and not f.play.over:
		f.play.pressure = 0.0
		f.play.foul_t = 0.0   # (no whistle: DefenseFormation's contact fouls too)
		f.play.raise_ball(true)
		if f.phase == MatchFlow.Phase.ATTACK:
			f.tick_attack(1.0 / 30.0)
		else:
			f.tick_defense(1.0 / 30.0)
		t += 1.0 / 30.0

## How each possession ends (`outcome`), and what that does to the clocks.
func _end(f: MatchFlow, outcome: String) -> void:
	var p := f.play
	var d := p.defenders[1]
	match outcome:
		"steal", "turnover":
			p._turnover(d, "STOLEN!", outcome)
		"save":
			p._finish("save", "SAVED!", {"shooter": p.holder.player})
		"miss":
			p._finish("miss", "WIDE!", {"shooter": p.holder.player})
		"shotclock":
			p._finish("shotclock", "SHOT CLOCK")
		"goal":
			p._finish("goal", "GOAL!", {"scorer": p.holder.player})
		"penalty":
			p._finish("penalty", "PENALTY!", {"fouled": p.holder.player})

func _transitions() -> void:
	print("the transition: 10 s off both clocks")
	var teams: Array = r._teams()
	for side in ["yours", "theirs"]:
		for outcome in ["steal", "turnover", "save", "miss", "shotclock", "goal", "penalty"]:
			var f := MatchFlow.new(teams[0], teams[1], 90 + outcome.length(), MatchState.QUARTER_MIN)
			f.auto_keeper = 0.5
			if side == "yours":
				f._start_attack(Play.Kind.HALF_COURT)
			else:
				f._start_defense(Play.Kind.HALF_COURT)
			_held(f, 2.0)
			_end(f, outcome)
			var c0 := f.state.clock
			if side == "yours":
				f.attack_done()
			else:
				f.defense_done()
			var off := c0 - f.state.clock
			var sc := f.play.shot_clock
			match outcome:
				"goal":
					r.check(off == 0.0 and sc == Play.SHOT_CLOCK, "%s goal: no transition, 30 on the shot clock (-%.1f, %.1f)" % [side, off, sc])
				"penalty":
					r.check(off == 0.0 and f.play.kind == Play.Kind.PENALTY and sc == 5.0, "%s penalty: no transition, its own 5 s (-%.1f, %.1f)" % [side, off, sc])
				_:
					r.check(is_equal_approx(off, MatchState.TURNOVER_TIME) and is_equal_approx(sc, Play.SHOT_CLOCK - MatchState.TURNOVER_TIME),
						"%s %s: the transition takes 10 s off the game clock and the shot clock goes 30 -> 20 (-%.1f, %.1f)" % [side, outcome, off, sc])
					# ...once: from there both run on together at 1.25x, the shot clock from 20, never back to 30
					var c1 := f.state.clock
					var s1 := f.play.shot_clock
					var p := f.play
					var e0 := p.elapsed
					_held(f, 2.0)
					if not p.over:
						var live := (p.elapsed - e0) * MatchState.CLOCK_SPEED
						r.check(absf((c1 - f.state.clock) - live) < 0.01 and absf((s1 - p.shot_clock) - live) < 0.01 and p.shot_clock < 20.0,
							"%s %s: then both clocks just run (no second 10 s off, no reset to 30): -%.2f / -%.2f" % [side, outcome, c1 - f.state.clock, s1 - p.shot_clock])
	# the shot clock runs out: 20 game seconds is 16 real ones, it stops at 0.0, and the next
	# possession after that change of hands is 20 s again
	var g := MatchFlow.new(teams[0], teams[1], 501, MatchState.QUARTER_MIN)
	g.next_shot_clock = 20.0
	g._start_attack(Play.Kind.HALF_COURT)
	g.play.formation = DefenseFormation.F.PRESS   # (no whistle: a piston's contact foul neither)
	var frames := 0
	var lowest := INF
	while not g.play.over and frames < 900:
		g.play.pressure = 0.0
		g.play.foul_t = 0.0   # (no whistle: DefenseFormation's contact fouls too)
		g.play.raise_ball(true)
		g.tick_attack(1.0 / 30.0)
		lowest = minf(lowest, g.play.shot_clock)
		frames += 1
	r.check(g.play.over and String(g.play.result.outcome) == "shotclock", "a 20 s shot clock still runs out: shot-clock violation")
	r.check(frames >= 478 and frames <= 482, "...after 16 real seconds (%d frames)" % frames)
	r.check(lowest == 0.0, "...and it stops on 0.0, never below (%.2f)" % lowest)
	var c2 := g.state.clock
	g.attack_done()
	r.check(is_equal_approx(c2 - g.state.clock, 10.0) and g.play.shot_clock == 20.0 and g.phase == MatchFlow.Phase.DEFENSE,
		"...their ball, 10 s off for the transition and 20 on their shot clock")
	# not 10 s left on the game clock: the transition takes what's there (0:00, never below) and
	# the quarter's over
	var q := MatchFlow.new(teams[0], teams[1], 502, MatchState.QUARTER_MIN)
	q._start_attack(Play.Kind.HALF_COURT)
	q.state.clock = 6.0
	_end(q, "steal")
	q.attack_done()
	r.check(q.state.clock == 0.0 and q.phase == MatchFlow.Phase.BREAK, "a transition with 6 s left: 0:00 and the quarter's over (%.2f)" % q.state.clock)
	var lp := Play.new(teams[0], teams[1], Play.Kind.HALF_COURT, RandomNumberGenerator.new())
	lp.start_shot_clock(-4.0)
	r.check(lp.shot_clock == 0.0, "a shot clock is never set below 0")

## Multiplayer's referee takes the same 10 s off and hands the next attacker a 20 s shot clock.
class NetStub extends Node:
	func send_match(_m: Dictionary) -> void:
		pass
	func now_ms() -> float:
		return 0.0

func _mp_transition() -> void:
	print("multiplayer: the transition")
	var net := NetStub.new()
	var m := MpMatch.new(net, {"minutes": 2.0, "seed": 5, "names": ["A", "B"], "clubs": [1, 2], "equal": true}, 0)
	m.seq = 1
	m.phase = MpMatch.Phase.ATTACK
	m.att = 0
	m.on_result(0, {"seq": 1, "outcome": "steal", "elapsed": 4.0})
	r.check(is_equal_approx(m.st.clock, 120.0 - 4.0 * MatchState.CLOCK_SPEED - 10.0), "a steal: the play's 5 s (4 live) and the transition's 10 s off (%.2f)" % m.st.clock)
	r.check(m.att == 1 and m.shot0 == 20.0 and m.new_play().shot_clock == 20.0 and m.shadow_play().shot_clock == 20.0,
		"...and the other phone attacks with 20 on the shot clock, on both phones")
	r.check(float(m.snapshot_msg().shot0) == 20.0, "...which the guest is sent")
	m.on_result(1, {"seq": m.seq, "outcome": "goal", "elapsed": 2.0, "scorer": 1})
	r.check(m.shot0 == Play.SHOT_CLOCK and m.new_play().shot_clock == Play.SHOT_CLOCK, "after a goal it's a fresh 30")
	net.free()

# ------------------------------------------------------------------ passing
## Every man in the set attack to every other: 30 passes, each way round the pool, your attack and
## theirs. With nobody in the way every one is caught; with the defence on and the lane clear
## (pass_risk) too. Distance never stops a pass.
func _all_passes() -> void:
	print("passing: every position to every other")
	for defending in [false, true]:
		var who := "theirs" if defending else "yours"
		var caught := 0
		var tried := 0
		var missed: Array[String] = []
		var longest := 0.0
		for from_tag in TAGS:
			for to_tag in TAGS:
				if from_tag == to_tag:
					continue
				var p: Play = r._center_play(300 + tried, defending)
				for d in p.defenders:
					d.pos = Vector2(4.0, d.pos.y)   # nobody in the way
					d.target = d.pos
					d.mark = null
				var from := PlaySetup._by_tag(p, from_tag)
				var to := PlaySetup._by_tag(p, to_tag)
				p.give_ball(from)
				tried += 1
				longest = maxf(longest, from.pos.distance_to(to.pos))
				var ok := p.pass_to(to)
				var t := 0.0
				while ok and p.ball.state == Ball.State.PASS and t < 3.0:
					p.step(DT)
					t += DT
				if ok and p.holder == to and not p.over:
					caught += 1
				else:
					missed.append("%s -> %s" % [NAMES[from_tag], NAMES[to_tag]])
		r.check(caught == 30 and tried == 30, "%s: all 30 passes between the six positions get there, up to %.1f m (missed: %s)" % [who, longest, ", ".join(missed)])
	# the ones asked about by name, with the defence in place: when the lane's clear, it's caught
	var named := [["2", "5"], ["4", "1"], ["1", "5"], ["5", "1"], ["1", "4"], ["5", "2"]]
	for t in TAGS:
		if t != "C":
			named.append([t, "C"])
			named.append(["C", t])
	for defending in [false, true]:
		var who := "theirs" if defending else "yours"
		var clear := 0
		var caught := 0
		var picked := 0
		var denied := 0
		var blocked := 0
		for sd in 20:
			for pair: Array in named:
				var p: Play = r._center_play(700 + sd * 31 + named.find(pair), defending)
				var from := PlaySetup._by_tag(p, pair[0])
				var to := PlaySetup._by_tag(p, pair[1])
				var c := PlaySetup._by_tag(p, "C")
				p.give_ball(from)
				if to == c:
					# the centre with inside water: his man behind him
					var g := p._center_guard(c)
					g.pos = c.pos + PlayAI.behind_dir(c, from.pos) * PlayAI.CENTER_BEHIND
					g.target = g.pos
					p.cfight = PlayAI.Fight.SEALED
					p.cfight_t = 3.0
				if p.pass_risk(p.lead_point(to), to) != null:
					blocked += 1
					continue
				clear += 1
				p.pass_to(to)
				var t := 0.0
				while p.ball.state == Ball.State.PASS and t < 3.0:
					p.step(DT)
					t += DT
				if p.holder == to and not p.over:
					caught += 1
				elif (p.over and String(p.result.outcome) == "steal") or p.ball.tipped_by != null:
					# (picked off, or a hand on it that knocked it loose: DefenseFormation's tips)
					var by: Swimmer = p.ball.tipped_by
					for d in p.defenders:
						if p.over and d.player == p.result.by and by == null:
							by = d
					if by != null and by.mark == to and to != c:
						denied += 1   # his own man stepped into the lane as it came (the lane closed in flight)
					else:
						picked += 1
		print("  %s, the defence on: %d lanes clear at the release: %d caught, %d picked off by the catcher's own man stepping into it, %d by anybody else; %d with a man in the lane (not thrown)" % [who, clear, caught, denied, picked, blocked])
		r.check(clear > 0 and picked == 0 and caught + denied == clear, "%s: right wing -> left corner, left wing -> right corner, corner to corner, every perimeter spot into the sealed centre and the centre back out: a clear lane is never picked off by a man who wasn't in it" % who)
		r.check(caught >= clear * 0.9, "%s: ...and 90%%+ are caught (%d of %d)" % [who, caught, clear])

## The camera on your attack frames the whole attack, so every teammate is on screen, and a tap
## on a man passes to him: the right one, even right across the pool.
func _tap_targets() -> void:
	print("tapping a teammate")
	var v := PoolView.new()
	var bad: Array[String] = []
	var hidden_before := 0
	var picked := 0
	var n := 0
	for from_tag in TAGS:
		var p: Play = r._center_play(55, false)
		p.give_ball(PlaySetup._by_tag(p, from_tag))
		v.snap_to(PoolView.attack_focus(p.ball.pos))
		for a in p.attackers:
			if not _on_screen(v, a):
				hidden_before += 1
		v.snap_to(v.attack_frame(p))
		for to_tag in TAGS:
			if to_tag == from_tag:
				continue
			n += 1
			var to := PlaySetup._by_tag(p, to_tag)
			var at := v.to_screen(to.pos) + Vector2(0, -5)
			if not _on_screen(v, to):
				bad.append("%s off screen from the %s" % [NAMES[to_tag], NAMES[from_tag]])
			elif AimGuide.tap_mate(v, p, at) == to and AimGuide.tap_mate(v, p, at + Vector2(6, 4)) == to:
				picked += 1
			else:
				bad.append("tap on the %s from the %s" % [NAMES[to_tag], NAMES[from_tag]])
	print("  following the ball alone, %d teammates were off screen across the 6 spots (the bug); framing the attack: %d of %d tapped right" % [hidden_before, picked, n])
	r.check(picked == n, "every teammate is on screen and a tap on him picks him, from every spot (%s)" % ", ".join(bad))
	# a tap in open water still goes to the spot (no snapping), and the man with the ball isn't a target
	var p: Play = r._center_play(56, false)
	var h := PlaySetup._by_tag(p, "3")
	p.give_ball(h)
	v.snap_to(v.attack_frame(p))
	r.check(AimGuide.tap_mate(v, p, v.to_screen(h.pos) + Vector2(0, -5)) == null, "a tap on the man with the ball isn't a pass")
	var water := Vector2(20.0, 10.0)
	r.check(AimGuide.tap_mate(v, p, v.to_screen(water)) == null and p.pass_at(water) and p.ball.to.distance_to(water) < 0.01,
		"a tap in open water still passes to that spot")

func _on_screen(v: PoolView, a: Swimmer) -> bool:
	var s := v.to_screen(a.pos)
	return s.x >= 8.0 and s.x <= v.width - 8.0 and s.y - 14.0 >= PoolView.HUD_H and s.y + 3.0 <= v.height

## A long pass (right corner to left corner, right across the pool) with a defender standing in
## its lane near either end can be picked off; the same pass with the lane clear never is.
func _long_pass_lane() -> void:
	print("long passes and the lane")
	var spots := {"near the passer": 0.22, "the middle": 0.5, "near the catcher": 0.86}
	var rates := {}
	for where in spots:
		var picked := 0
		for sd in 300:
			var p: Play = r._center_play(900 + sd, false)
			var from := PlaySetup._by_tag(p, "1")
			var to := PlaySetup._by_tag(p, "5")
			for d in p.defenders:
				d.pos = Vector2(4.0, d.pos.y)
				d.target = d.pos
				d.mark = null
			var d := p.defenders[2]
			d.pos = from.pos.lerp(to.pos, spots[where])
			d.target = d.pos
			p.give_ball(from)
			p.pass_to(to)
			var spot := d.pos
			var t := 0.0
			while p.ball.state == Ball.State.PASS and t < 3.0:
				d.target = spot   # (standing in the lane)
				p.step(DT)
				t += DT
			if (p.over and String(p.result.outcome) == "steal") or p.ball.tipped_by == d:
				picked += 1   # (a hand on it: picked off clean, or knocked loose)
		rates[where] = picked / 300.0
	print("  right corner -> left corner, a defender in the lane: got a hand on it %s" % str(rates))
	r.check(float(rates["near the passer"]) > 0.03 and float(rates["near the catcher"]) > 0.03,
		"a defender in the lane of a long pass, near either end, can get a hand on it")

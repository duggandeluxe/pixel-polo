extends RefCounted
## Their attack (the opposing AI, MatchFlow's brain) over whole bot-played matches: how long
## a possession lasts, how it ends, how the ball moves and who shoots.
##   godot --headless --path game -- --test offense [matches] [level]
## run() returns the totals so test_runner can check them too.

const DT := 1.0 / 30.0

var tot := {}
var _pw := ""
var durs: Array[float] = []          # settled (half-court) possessions: live seconds to the end
var first_shot: Array[float] = []    # settled possessions with a shot: live seconds to the first one

func run(_runner, matches: int, quiet := false, level := Difficulty.BASELINE) -> Dictionary:
	for i in matches:
		var teams := [League.make_team(i % 8, 0), League.make_team((i + 3) % 8, 0)]
		_match(MatchFlow.new(teams[0], teams[1], 9000 + i, MatchState.QUARTER_MIN, level))
	tot["matches"] = matches
	tot["durs"] = durs
	tot["first_shot"] = first_shot
	if not quiet:
		_report(matches)
	var ks := tot.keys().filter(func(k): return String(k).begins_with("POW"))
	ks.sort_custom(func(a, b): return tot[a] > tot[b])
	for k in ks:
		print("  ", k, " ", tot[k])
	return tot

func _g(k: String) -> float:
	return float(tot.get(k, 0.0))

func _report(n: int) -> void:
	var poss := maxf(1.0, _g("poss"))
	var set_n := maxf(1.0, _g("set"))
	print("their attack (opposing AI) over %d matches" % n)
	print("  possessions        %.1f per game (settled %.1f, breaks %.1f)" % [_g("poss") / n, _g("set") / n, _g("brk") / n])
	print("  average length     %.1f s live (settled %.1f s, breaks %.1f s)" % [_g("poss_t") / poss,
		_g("set_t") / set_n, _g("brk_t") / maxf(1.0, _g("brk"))])
	print("  shots / possession %.2f   (settled with a shot: %.0f%%)" % [_g("shots") / poss, 100.0 * _g("set_shot") / set_n])
	var fs := first_shot.duplicate()
	fs.sort()
	if not fs.is_empty():
		var in_window := fs.filter(func(t): return t <= 15.0).size()
		print("  first shot (settled) median %.1f s, p10 %.1f, p90 %.1f; within 15 s %.0f%%, 3-15 s %.0f%%" % [
			fs[fs.size() / 2], fs[fs.size() / 10], fs[fs.size() * 9 / 10],
			100.0 * in_window / fs.size(), 100.0 * fs.filter(func(t): return t >= 3.0 and t <= 15.0).size() / fs.size()])
	if not fs.is_empty():
		var bins := [0, 0, 0, 0, 0]
		for t in fs:
			bins[0 if t < 3.0 else (1 if t < 8.0 else (2 if t <= 15.0 else (3 if t <= 20.0 else 4)))] += 1
		print("  first shot (settled, full shot clock) <3 s %.0f%%, 3-8 s %.0f%%, 8-15 s %.0f%%, 15-20 s %.0f%%, >20 s %.0f%%  (%d possessions; %d cut short by the quarter)" % [
			100.0 * bins[0] / fs.size(), 100.0 * bins[1] / fs.size(), 100.0 * bins[2] / fs.size(),
			100.0 * bins[3] / fs.size(), 100.0 * bins[4] / fs.size(), fs.size(), int(_g("clock_cut"))])
		var early := []
		for k in ["look", "pressed", "pass", "deadline", "late", "wait", "drive"]:
			if _g("early_" + k) > 0.0:
				early.append("%s %d" % [k, int(_g("early_" + k))])
		print("  first shots under 3 s, why: " + ", ".join(early))
	print("  shot clock violations %d  (%.1f%% of possessions)" % [int(_g("shotclock")), 100.0 * _g("shotclock") / poss])
	print("  passes / possession %.2f   back-and-forth %.2f per possession (%.0f%% of passes)" % [
		_g("passes") / poss, _g("pingpong") / poss, 100.0 * _g("pingpong") / maxf(1.0, _g("passes"))])
	print("  shots: centre %d, wings %d, flats %d, point %d   catch and shoot %d   from outside 6 m %d (yours, the bot's: %d of %d)" % [
		int(_g("sh_C")), int(_g("sh_wing")), int(_g("sh_flat")), int(_g("sh_point")), int(_g("catch_shoot")),
		int(_g("sh_out6")), int(_g("our_out6")), int(_g("our_shots"))])
	print("  into the centre    open side %d, straight %d, his guard's side %d, unguarded %d" % [int(_g("feed_open")), int(_g("feed_straight")),
		int(_g("feed_fronted")), int(_g("feed_unguarded"))])
	print("  drives: with the ball %.2f per game, hit in stride on a cut %.2f per game" % [_g("drives") / n, _g("stride") / n])
	print("  goals              %.2f per game (theirs); %.1f shots per game" % [_g("goals") / n, _g("shots") / n])
	print("  off-ball attackers moving %.0f%% of the time" % [100.0 * _g("moving") / maxf(1.0, _g("samples"))])
	var whys := []
	for k in ["look", "pressed", "late", "deadline"]:
		whys.append("%s %d (q %.2f)" % [k, int(_g("why_" + k)), _g("q_" + k) / maxf(1.0, _g("why_" + k))])
	print("  why they shot: " + ", ".join(whys))
	var decs := []
	for k in ["look", "pass", "pressed", "drive", "late", "deadline", "wait"]:
		decs.append("%s %d" % [k, int(_g("dec_" + k))])
	print("  their decisions: " + ", ".join(decs))
	var ends := []
	for k in tot.keys():
		if String(k).begins_with("end_"):
			ends.append("%s %d" % [String(k).substr(4), int(tot[k])])
	print("  endings: " + ", ".join(ends))
	print("  steals: picked off %d, stripped %d" % [int(_g("steal_pass")), int(_g("steal_ball"))])
	print("  picked off on the way to: C %d, 1 %d, 2 %d, 3 %d, 4 %d, 5 %d" % [int(_g("po_C")), int(_g("po_1")),
		int(_g("po_2")), int(_g("po_3")), int(_g("po_4")), int(_g("po_5"))])

func _add(k: String, v: float = 1.0) -> void:
	tot[k] = float(tot.get(k, 0.0)) + v

func _match(f: MatchFlow) -> void:
	var steps := 0
	while f.phase != MatchFlow.Phase.FINAL and steps < 200000:
		steps += 1
		match f.phase:
			MatchFlow.Phase.SPRINT:
				f.sprint_done(f.rng.randf() < 0.5)
			MatchFlow.Phase.ATTACK:
				_ours(f)
				f.attack_done()
			MatchFlow.Phase.DEFENSE:
				_theirs(f)
				f.defense_done()
			MatchFlow.Phase.SHOOTOUT_THEM:
				f.their_ball_done()
			MatchFlow.Phase.THEIR_SHOT:
				f.auto_duel(0.5)
				f.duel_done()
			MatchFlow.Phase.BREAK:
				f.break_done()
	_add("goals", f.state.score[1])

## Your attack, played by PlayBot as in match_stats (not counted here).
func _ours(f: MatchFlow) -> void:
	var p := f.play
	var think := 0.0
	var t := 0.0
	while not p.over and t < 90.0:
		think -= DT
		if think <= 0.0:
			think = PlayBot.THINK_EVERY
			var d := PlayBot.think(p, f.rng)
			if not d.is_empty():
				var at := p.holder.pos
				if p.throw(d.target, d.power) == "shot":
					_add("our_shots")
					if not Geo.in_shot_range(at):
						_add("our_out6")   # (never: PlayBot only shoots inside 6 m)
		f.tick_attack(DT)
		t += DT
	f.events.clear()

## Their attack, the AI's, counted.
func _theirs(f: MatchFlow) -> void:
	var p := f.play
	f.auto_keeper = 0.5
	var t := 0.0
	var shots := 0
	var first := -1.0
	var last_pair := []
	var counted := p.kind != Play.Kind.PENALTY
	var settled := p.kind == Play.Kind.HALF_COURT
	# a possession that starts with less on the game clock than the shot clock is cut short by
	# the quarter, not by the attack: counted, but kept out of the timing histogram
	var clock_cut := f.state.clock < Play.SHOT_CLOCK
	if settled and clock_cut:
		_add("clock_cut")
	var was_holder: Swimmer = null
	var sample := 0.0
	while not p.over and t < 90.0:
		f.tick_defense(DT)
		t += DT
		if counted and p.holder != null and p.holder.side == Swimmer.Side.US and p.holder != was_holder:
			# the holder swimming at the goal with it (a drive on the ball)
			was_holder = p.holder
		for e in f.events:
			if not counted:
				continue
			match String(e.k):
				"pass":
					_add("passes")
					if p.ball.passer == null:
						continue   # (tipped away the frame it was thrown: nothing more to read off it)
					var aiw = f.get("opp_ai")
					_pw = "%s|%s|%s|%s|%.1f" % [aiw.why, p.ball.passer.tag, "in" if p.ball.passer.pos.x >= 24.0 else "out", "pr" if f.opp_pressed else "-", p.ball.passer.pos.distance_to(p.ball.to)]
					var pair := [p.ball.passer, p.ball.receiver]
					if last_pair.size() == 2 and pair[0] == last_pair[1] and pair[1] == last_pair[0]:
						_add("pingpong")
					last_pair = pair
					if p.ball.receiver != null and p.ball.receiver.tag == "C":
						_add("feed_" + (p.entry if p.entry != "" else "unguarded"))
				"shot":
					shots += 1
					_add("shots")
					var ai = f.get("opp_ai")   # (null on a build without OffenseAI: comparisons)
					if ai != null:
						_add("why_" + ai.why)
						_add("q_" + ai.why, ai.why_q)
					if first < 0.0:
						first = p.elapsed
						var brain0 = f.get("opp_ai")
						if settled and brain0 != null and first < 3.0:
							_add("early_" + String(brain0.why))
					var sh := p.ball.shooter
					if sh != null and not Geo.in_shot_range(sh.pos):
						_add("sh_buzzer" if f.state.clock <= OffenseAI.FINAL else "sh_out6")   # (never, bar the period's last seconds: OffenseAI._final)
					if sh != null:
						match sh.tag:
							"C": _add("sh_C")
							"1", "5": _add("sh_wing")
							"2", "4": _add("sh_flat")
							_: _add("sh_point")
					if float(e.get("catch_shoot", 0.0)) > 0.0:
						_add("catch_shoot")
				"drive_ball":
					_add("drives")
				"catch":
					if p.holder != null and p.holder.drive_t > 0.0:
						_add("stride")
		f.events.clear()
		sample += DT
		if counted and sample >= 0.5 and p.ball.state == Ball.State.HELD and not p.over and p.freeze <= 0.0:
			sample = 0.0
			for a in p.attackers:
				if a != p.holder and not a.out:
					_add("samples")
					if a.speed() > 0.35:
						_add("moving")
	if not counted:
		return
	var brain = f.get("opp_ai")
	if brain != null:
		for k in brain.tally:
			_add("dec_" + k, brain.tally[k])
	var oc := String(p.result.get("outcome", ""))
	_add("end_" + oc)
	if oc == "steal":
		_add("steal_" + ("pass" if String(p.result.get("text", "")) == "PICKED OFF!" else "ball"))
		if String(p.result.get("text", "")) == "PICKED OFF!":
			_add("POW_" + _pw.rsplit("|", true, 1)[0])
			_add("POWD", float(_pw.rsplit("|", true, 1)[1]))
		if String(p.result.get("text", "")) == "PICKED OFF!" and p.ball.receiver != null:
			_add("po_" + p.ball.receiver.tag)
	_add("poss")
	_add("poss_t", p.elapsed)
	if oc == "shotclock":
		_add("shotclock")
	if settled:
		_add("set")
		_add("set_t", p.elapsed)
		durs.append(p.elapsed)
		if shots > 0:
			_add("set_shot")
			if not clock_cut:
				first_shot.append(first)
	else:
		_add("brk")
		_add("brk_t", p.elapsed)

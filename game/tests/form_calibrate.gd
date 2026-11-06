extends RefCounted
## The expected-performance model against real games: the average PERFORMANCE +/- by position
## (about 0 when the model is fair) and how often each grade comes up, for games the scoring
## engine decides and for games played out in the pool by the bots.
##   godot --headless --path game -- --test form_calibrate [games] [first]
## `first`: where the played games' seeds and pairings start (another number for a fresh sample).

const DT := 1.0 / 30.0

func run(runner, games: int, first: int = 0) -> void:
	Store.reset_for_tests()
	var c := Career.new_game("WAGN", "Test", "Coach", 77)
	var ids: Array = c.teams.keys()
	ids.sort()
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	# the scoring engine, every pairing at random, home and away
	var sim := {}
	for i in games * 10:
		var a: PoloTeam = c.teams[ids[rng.randi() % ids.size()]]
		var b: PoloTeam = c.teams[ids[rng.randi() % ids.size()]]
		if a == b:
			continue
		var xg := GameSim.pregame_expected(a, b, true, false)
		var res := GameSim.play(a, b, rng.randi(), false)
		_tally(sim, a, res.lines[0], PlayerForm.expected(a, [xg[0], xg[1]], "sim"))
		_tally(sim, b, res.lines[1], PlayerForm.expected(b, [xg[1], xg[0]], "sim"))
	_print("SCORING ENGINE (%d games)" % (games * 10), sim)
	runner.check(_fair(sim, 1.0), "the scoring engine's games average about 0 +/- at every position")
	# games played out by the bots (both attacks AI, the bot in your goal)
	var played := {}
	for j in games:
		var i := first + j
		var a: PoloTeam = c.teams[ids[(i * 7) % ids.size()]]
		var b: PoloTeam = c.teams[ids[(i * 7 + 11 + i / 30) % ids.size()]]
		if a == b:
			b = c.teams[ids[(i * 7 + 12) % ids.size()]]
		var f := MatchFlow.new(a, b, 9000 + i, MatchState.QUARTER_MIN)
		_play(f)
		var xg := GameSim.pregame_expected(a, b, true, false)
		var lines := [f.state.player_lines(0, a), f.state.player_lines(1, b)]
		_tally(played, a, lines[0], PlayerForm.expected(a, [xg[0], xg[1]], "played"))
		_tally(played, b, lines[1], PlayerForm.expected(b, [xg[1], xg[0]], "played"))
	_print("PLAYED OUT BY THE BOTS (%d games)" % games, played)
	# (40 games is 80 keepers: his +/- has an SD near 12, so 2.5 is about two standard errors)
	runner.check(_fair(played, 2.5), "played games average about 0 +/- at every position (bots)")
	_season(runner)

## A season of the scoring engine: how far form takes teams from BASE, how long it lasts, and
## how many results it changes (every game replayed from its seed with no form).
func _season(runner) -> void:
	var c := Career.new_game("WAGN", "Test", "Coach", 99)
	Game.career = c
	var deltas: Array = []
	var prev := {}
	var pairs: Array = []
	var flipped := 0
	var games := 0
	var upsets := [0, 0]   # BASE 10+ apart, the weaker won: [with form, without]
	var gaps := 0
	while c.phase == "season":
		c.queue.clear()
		while c.has_game():
			c.sim_my_game()
		c._sim_others(Schedule.DAYS, true)
		for g in c.cur().games:
			if g.r == null or not g.r.has("sd"):
				continue
			var h: PoloTeam = c.teams[g.h]
			var a: PoloTeam = c.teams[g.a]
			var flat := GameSim.play(h, a, int(g.r.sd), Schedule.is_neutral(g), [0, 0])
			games += 1
			if int(flat.winner) != int(g.r.w):
				flipped += 1
			var gap := h.base_ovr() - a.base_ovr()
			if absf(gap) >= 10:
				gaps += 1
				var weaker := 1 if gap > 0 else 0
				if int(g.r.w) == weaker:
					upsets[0] += 1
				if int(flat.winner) == weaker:
					upsets[1] += 1
		for id in c.teams:
			var d: int = (c.teams[id] as PoloTeam).form_delta()
			deltas.append(d)
			if prev.has(id):
				pairs.append([prev[id], d])
			prev[id] = d
		c.end_week()
	var abs_sum := 0.0
	var big := 0
	var hi := 0
	for d in deltas:
		abs_sum += absf(d)
		hi = maxi(hi, absi(d))
		if absi(d) >= 5:
			big += 1
	var mx := 0.0
	var my := 0.0
	for p in pairs:
		mx += p[0]
		my += p[1]
	mx /= pairs.size()
	my /= pairs.size()
	var cov := 0.0
	var vx := 0.0
	var vy := 0.0
	for p in pairs:
		cov += (p[0] - mx) * (p[1] - my)
		vx += (p[0] - mx) * (p[0] - mx)
		vy += (p[1] - my) * (p[1] - my)
	var ac := cov / sqrt(maxf(0.0001, vx * vy))
	print("A SEASON OF FORM (scoring engine)")
	print("  team LIVE - BASE: mean |%.2f|, %d%% of team-weeks 5+ away, most %d; week-to-week correlation %.2f" % [abs_sum / deltas.size(), roundi(100.0 * big / deltas.size()), hi, ac])
	print("  results form changed: %d of %d (%.1f%%); upsets 10+ BASE apart: %d of %d with form, %d without" % [flipped, games, 100.0 * flipped / maxf(1.0, games), upsets[0], gaps, upsets[1]])
	Game.career = null

func _tally(acc: Dictionary, t: PoloTeam, lines: Dictionary, exp: Dictionary) -> void:
	for p: PoloPlayer in t.starters():
		var raw := PlayerForm.raw_points(lines.get(p.id, {"gk": p.is_keeper()}))
		var pm := raw - float(exp.get(p.id, 0.0))
		var k: String = PoloPlayer.POS_SHORT[p.pos]
		if not acc.has(k):
			acc[k] = {"n": 0, "pm": 0.0, "pm2": 0.0, "raw": 0.0, "exp": 0.0, "good": 0, "bad": 0, "line": {}}
		var e: Dictionary = acc[k]
		var ln: Dictionary = lines.get(p.id, {})
		for lk in ln:
			if lk != "gk":
				e.line[lk] = float(e.line.get(lk, 0.0)) + float(ln[lk])
		e.n += 1
		e.pm += pm
		e.pm2 += pm * pm
		e.raw += raw
		e.exp += float(exp.get(p.id, 0.0))
		var g := PlayerForm.grade_of(pm)
		if g == PlayerForm.GOOD:
			e.good += 1
		elif g == PlayerForm.BAD:
			e.bad += 1

func _print(title: String, acc: Dictionary) -> void:
	print(title)
	for k in acc:
		var e: Dictionary = acc[k]
		var n := float(e.n)
		var mean := float(e.pm) / n
		var sd := sqrt(maxf(0.0, float(e.pm2) / n - mean * mean))
		print("  %-4s n %5d  raw %6.2f  exp %6.2f  +/- %+5.2f (sd %.1f)  GOOD %4.1f%%  BAD %4.1f%%" % [k, e.n, float(e.raw) / n,
			float(e.exp) / n, mean, sd, 100.0 * float(e.good) / n, 100.0 * float(e.bad) / n])
		var per := []
		for lk in e.line:
			per.append("%s %.2f" % [lk, float(e.line[lk]) / n])
		print("        a game: ", ", ".join(per))

func _fair(acc: Dictionary, tol: float) -> bool:
	for k in acc:
		if absf(float(acc[k].pm) / float(acc[k].n)) > tol:
			return false
	return true

## A whole match with the bots on both attacks and in your goal (as tests/match_stats.gd).
func _play(f: MatchFlow) -> void:
	var steps := 0
	while f.phase != MatchFlow.Phase.FINAL and steps < 200000:
		steps += 1
		match f.phase:
			MatchFlow.Phase.SPRINT:
				f.sprint_done(f.rng.randf() < 0.5)
			MatchFlow.Phase.ATTACK:
				var p := f.play
				var think := 0.0
				var t := 0.0
				while not p.over and t < 90.0:
					think -= DT
					if think <= 0.0:
						think = PlayBot.THINK_EVERY
						var d := PlayBot.think(p, f.rng)
						if not d.is_empty():
							p.throw(d.target, d.power)
					f.tick_attack(DT)
					t += DT
				f.events.clear()
				f.attack_done()
			MatchFlow.Phase.DEFENSE:
				f.auto_keeper = 0.5
				var t := 0.0
				while not f.play.over and t < 90.0:
					f.tick_defense(DT)
					t += DT
				f.events.clear()
				f.defense_done()
			MatchFlow.Phase.SHOOTOUT_THEM:
				f.their_ball_done()
			MatchFlow.Phase.THEIR_SHOT:
				f.auto_duel(0.5)
				f.duel_done()
			MatchFlow.Phase.BREAK:
				f.break_done()

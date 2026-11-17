extends RefCounted
## The scoring engine and the season around it: the exact OVR/OFF/DEF table, ratings locked all
## season (only the roster lock moves them), the neutral-pool formulas, the 5% home pool (never
## twice in overtime), the final scores, the calibration against the brief's prototype games,
## the National Top 20 poll, GAME 1-16 schedule labels, the strict at-large selection and the
## 12-team bracket, and saves (new and old).
##   godot --headless --path game -- --test engine [games per calibration matchup]

## The brief's table: OVR, OFF, DEF.
const RATINGS := {
	"CULA": [91, 90, 92], "CUSC": [90, 92, 88], "STAM": [89, 87, 91], "ALC": [88, 90, 86],
	"FORDU": [86, 88, 84], "SJCU": [83, 81, 85], "LBSC": [82, 84, 80], "CUSD": [81, 80, 82],
	"PRIN": [80, 82, 78], "PPCU": [79, 81, 77], "UCDS": [78, 76, 80], "ICU": [78, 77, 79],
	"CRBU": [77, 79, 75], "LMMU": [77, 78, 76], "UPAC": [76, 76, 76], "HVRD": [76, 77, 75],
	"CCSB": [75, 75, 75], "NANA": [74, 76, 72], "BROW": [74, 74, 74], "GWU": [73, 72, 74],
	"SCCU": [72, 72, 72], "USAF": [71, 74, 68], "SMCC": [70, 70, 70], "CSFU": [70, 72, 68],
	"BUCK": [69, 69, 69], "WAGN": [68, 70, 66], "MSMU": [67, 67, 67], "IONA": [66, 68, 64],
	"LIUB": [65, 63, 67], "HURST": [62, 63, 61],
}
## The Simulation Realism brief's example results (neutral pool, plain OVR, no lean either way):
## A's OVR, B's OVR, A's score, B's score, and the least A should win (a bigger gap, a surer thing).
const PROTOTYPES := [
	[80, 78, 12.0, 11.0, 0.55],
	[85, 75, 14.0, 9.0, 0.92],
	[88, 68, 17.0, 6.0, 0.995],
	[92, 65, 20.0, 5.0, 0.999],
]

var r   # the test runner (check, check_between)

func run(runner, games: int = 20000) -> void:
	r = runner
	Store.reset_for_tests()
	_ratings_table()
	_formulas()
	_home_pool()
	_scores()
	_calibration(games)
	_locked_season()
	_poll_by_results()
	_selection_rule()
	_season_flow()
	_saves()
	await _screens()
	Game.career = null

func _ok(ok: bool, what: String) -> void:
	r.check(ok, what)

# ------------------------------------------------------------------ 1-4: the ratings table
func _ratings_table() -> void:
	print("engine: ratings")
	var wrong: Array = []
	for sid in RATINGS:
		var s := Colleges.school(sid)
		var want: Array = RATINGS[sid]
		if int(s.get("ovr", -1)) != want[0] or int(s.get("off", -1)) != want[1] or int(s.get("def", -1)) != want[2]:
			wrong.append(sid)
	_ok(RATINGS.size() == 30 and Colleges.SCHOOLS.size() == 30 and wrong.is_empty(), "1-3: all 30 schools have the exact OVR, OFF and DEF in the data %s" % str(wrong))
	_ok(Colleges.SCHOOLS.all(func(s): return float(s.ovr) == (float(s.off) + float(s.def)) / 2.0), "4: every school's OVR is the average of its OFF and DEF")
	for seed in [3, 2026]:
		var c := Career.new_game("HURST", "A", "B", seed)
		var bad: Array = RATINGS.keys().filter(func(sid):
			var t: PoloTeam = c.teams[sid]
			return t.base_ovr() != int(RATINGS[sid][0]) or t.initial_strength_target != float(RATINGS[sid][0]))
		_ok(bad.is_empty(), "1-3: career seed %d: every team's first roster shows its exact original OVR %s" % [seed, str(bad)])
		_ok(c.teams.values().all(func(t: PoloTeam): return is_equal_approx(t.ratings()[0], (t.ratings()[1] + t.ratings()[2]) / 2.0)), "4: seed %d: OVR = (OFF + DEF) / 2 for every team" % seed)
		_ok(c.teams["CULA"].prestige != c.teams["CULA"].rating() and c.teams["HURST"].base_ovr() == 62, "prestige and team OVR are separate numbers")

# ------------------------------------------------------------------ 8-11: formulas, home pool
func _rt(sid: String) -> Array:
	return (RATINGS[sid] as Array).map(func(x): return float(x))

func _formulas() -> void:
	print("engine: formulas")
	# CULA v CUSC by hand: GAP 1, STYLE -1 / +2, average DEF 90
	var total := 21.5 + 0.24 * (85.0 - 90.0) + 0.08 * 1.0 + 0.35 * (-1.0 + 2.0)
	var margin := 0.265 * ((90.0 - 88.0) - (92.0 - 92.0)) + 0.10 * (-1.0 - 2.0)
	var e := GameSim.neutral_expected(_rt("CULA"), _rt("CUSC"))
	_ok(is_equal_approx(e[0], (total + margin) / 2.0) and is_equal_approx(e[1], (total - margin) / 2.0),
		"the neutral formula, CULA v CUSC: %.3f-%.3f (total %.2f, margin %.3f)" % [e[0], e[1], total, margin])
	# every pairing: the two sides add up to TOTAL, the difference is MARGIN, and swapping sides mirrors it
	var ok := true
	for a in RATINGS:
		for b in RATINGS:
			var ra := _rt(a)
			var rb := _rt(b)
			var gap: float = ra[0] - rb[0]
			var tot: float = 21.5 + 0.24 * (85.0 - (ra[2] + rb[2]) / 2.0) + 0.08 * absf(gap) + 0.35 * ((ra[1] - ra[0]) + (rb[1] - rb[0]))
			var mar: float = 0.265 * ((ra[1] - rb[2]) - (rb[1] - ra[2])) + 0.10 * ((ra[1] - ra[0]) - (rb[1] - rb[0]))
			var x := GameSim.neutral_expected(ra, rb)
			var y := GameSim.neutral_expected(rb, ra)
			ok = ok and is_equal_approx(x[0] + x[1], tot) and is_equal_approx(x[0] - x[1], mar) and is_equal_approx(x[0], y[1]) and is_equal_approx(x[1], y[0])
	_ok(ok, "TOTAL, MARGIN and EXPECTED_A/B exactly as written, for all 900 pairings (and symmetric)")

func _home_pool() -> void:
	print("engine: home pool")
	var n := GameSim.neutral_expected(_rt("NANA"), _rt("LIUB"))
	var neu := GameSim.expected(_rt("NANA"), _rt("LIUB"), true)
	_ok(neu == n, "8: a neutral site has no home edge (%.3f-%.3f)" % [neu[0], neu[1]])
	var home := GameSim.expected(_rt("NANA"), _rt("LIUB"), false)
	_ok(is_equal_approx(home[0], n[0] * 1.05), "9: the home team's expected goals x 1.05 (%.3f -> %.3f)" % [n[0], home[0]])
	_ok(is_equal_approx(home[1], n[1] * 0.95), "10: the away team's expected goals x 0.95 (%.3f -> %.3f)" % [n[1], home[1]])
	# the home pool moves goals, not the rating
	var c := Career.new_game("NANA", "A", "B", 5)
	_ok(c.teams["NANA"].rating() == c.teams["NANA"].team_overall() and c.teams["NANA"].base_ovr() == 74, "the home pool never touches OVR (no +5)")
	# 11: overtime runs at the game's own rates: the home pool once, never again
	var ot := GameSim.ot_expected(home)
	_ok(is_equal_approx(ot[0], home[0] * GameSim.OT_SHARE) and is_equal_approx(ot[1], home[1] * GameSim.OT_SHARE),
		"11: an overtime period's expected goals are the game's own (home pool already in them, not applied again)")
	_ok(is_equal_approx(ot[0] / ot[1], n[0] / n[1] * 1.05 / 0.95), "11: overtime's home/away ratio is the 5%% edge once (%.3f), not twice (%.3f)" % [ot[0] / ot[1], n[0] / n[1] * pow(1.05 / 0.95, 2)])
	# and in practice: two identical teams, the host's share of overtime goals
	var same := [76.0, 76.0, 76.0]
	var x := GameSim.expected(same, same, false)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var ot_goals := [0, 0]
	var ot_games := 0
	for i in 30000:
		var sc := GameSim.score(x, rng)
		if not (sc.ot[0] as Array).is_empty():
			ot_games += 1
			for side in 2:
				for g in sc.ot[side]:
					ot_goals[side] += g
	var ratio := float(ot_goals[0]) / maxf(1.0, ot_goals[1])
	print("  overtime between equal teams: %d games, home %d - away %d goals (ratio %.3f; once 1.105, twice 1.222)" % [ot_games, ot_goals[0], ot_goals[1], ratio])
	_ok(ratio > 1.0 and ratio < 1.17, "11: overtime goals between equal teams lean 5%% home once (%.3f), not twice" % ratio)

# ------------------------------------------------------------------ 12-14: final scores
func _scores() -> void:
	print("engine: scores")
	var rng := RandomNumberGenerator.new()
	rng.seed = 4
	var neg := 0
	var bad_winner := 0
	var level := 0
	var ties := 0
	var ot_ok := true
	var q_ok := true
	var min_total := 99
	for a in ["CULA", "LIUB", "FORDU", "HURST", "UPAC"]:
		for b in ["CUSC", "IONA", "HURST", "CULA"]:
			var x := GameSim.expected(_rt(a), _rt(b), rng.randf() < 0.5)
			for i in 2000:
				var sc := GameSim.score(x, rng)
				var s: Array = sc.s
				if s[0] < 0 or s[1] < 0:
					neg += 1
				if s[0] == s[1]:
					level += 1
				if sc.w != (0 if s[0] > s[1] else 1):
					bad_winner += 1
				min_total = mini(min_total, sc.reg[0] + sc.reg[1])
				q_ok = q_ok and (sc.q[0] as Array).reduce(func(t, v): return t + v, 0) == sc.reg[0] and (sc.q[1] as Array).reduce(func(t, v): return t + v, 0) == sc.reg[1] and (sc.q[0] as Array).size() == 4
				if sc.reg[0] == sc.reg[1]:
					ties += 1
					ot_ok = ot_ok and not (sc.ot[0] as Array).is_empty() and s[0] != s[1]
				else:
					ot_ok = ot_ok and (sc.ot[0] as Array).is_empty() and s == sc.reg
	_ok(neg == 0, "12: no negative scores in 40,000 games")
	_ok(level == 0 and bad_winner == 0, "13: every game has a winner, and it's whoever scored more")
	_ok(ties > 0 and ot_ok, "14: every regulation tie (%d) goes to overtime and ends with a winner; nobody else plays overtime" % ties)
	_ok(q_ok, "the regulation goals are split over four quarters")
	_ok(min_total >= GameSim.MIN_TOTAL, "combined regulation goals never under %d (lowest %d)" % [GameSim.MIN_TOTAL, min_total])
	# the seed is the game: the same seed plays the same game again
	var c := Career.new_game("UPAC", "A", "B", 8)
	var g1 := GameSim.play(c.teams["CULA"], c.teams["IONA"], 123456789, false)
	var g2 := GameSim.play(c.teams["CULA"], c.teams["IONA"], 123456789, false)
	_ok(g1.score == g2.score and g1.q == g2.q and g1.ot == g2.ot and g1.goals[0].size() == g2.goals[0].size(), "the same seed replays the same game")
	_ok((g1.goals[0] as Array).size() == g1.score[0] and (g1.goals[1] as Array).size() == g1.score[1], "every goal has a scorer for the stats")
	# upsets: nine OVR points apart, the underdog still wins now and then (at 20+ points apart
	# the formulas make it all but impossible: the brief's own FORDU v LIUB is >99.99%)
	var x2 := GameSim.expected(_rt("NANA"), _rt("SJCU"), false)
	var x3 := GameSim.expected(_rt("HURST"), _rt("CULA"), false)
	var upsets := [0, 0]
	for i in 20000:
		if GameSim.score(x2, rng).w == 0:
			upsets[0] += 1
		if GameSim.score(x3, rng).w == 0:
			upsets[1] += 1
	print("  upsets in 20,000: NANA (74) at home to SJCU (83) %d; HURST (62) at home to CULA (91) %d (expected margin %.1f, SD %.1f)" % [upsets[0], upsets[1], x3[1] - x3[0], GameSim.MARGIN_SD])
	_ok(upsets[0] > 100, "upsets stay possible (NANA beat SJCU %d times in 20,000)" % upsets[0])

# ------------------------------------------------------------------ 15: calibration
func _calibration(games: int) -> void:
	print("engine: calibration (%d neutral games per matchup)" % games)
	print("  %-14s %-15s %-15s %-12s %-14s %-10s %s" % ["MATCHUP", "FORMULA (REG)", "SIM AVERAGE", "BRIEF", "SIM WIN %", "BRIEF", "OT %"])
	for pt in PROTOTYPES:
		var a := str(pt[0])
		var b := str(pt[1])
		var x := GameSim.expected([float(pt[0]), float(pt[0]), float(pt[0])], [float(pt[1]), float(pt[1]), float(pt[1])], true)
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(a + b)
		var sum := [0.0, 0.0]
		var reg := [0.0, 0.0]
		var wins := 0
		var ots := 0
		var margins := 0.0
		for i in games:
			var sc := GameSim.score(x, rng)
			for side in 2:
				sum[side] += sc.s[side]
				reg[side] += sc.reg[side]
			margins += sc.s[0] - sc.s[1]
			if sc.w == 0:
				wins += 1
			if not (sc.ot[0] as Array).is_empty():
				ots += 1
		var avg := [sum[0] / games, sum[1] / games]
		var reg_avg := [reg[0] / games, reg[1] / games]
		var win := float(wins) / games
		print("  %-14s %5.2f-%-9.2f %5.2f-%-9.2f %4.1f-%-7.1f %6.2f%%       %5.2f%%    %.1f%%" % [a + " v " + b, x[0], x[1], avg[0], avg[1], pt[2], pt[3], win * 100.0, float(pt[4]) * 100.0, float(ots) * 100.0 / games])
		# the engine is the formula: regulation averages sit on EXPECTED_A/B (the minimum total
		# of 15 can only push a low-scoring game up)
		_ok(absf(reg_avg[0] - x[0]) < 0.12 and absf(reg_avg[1] - x[1]) < 0.12, "15: %s v %s regulation averages %.2f-%.2f match the formula's %.2f-%.2f" % [a, b, reg_avg[0], reg_avg[1], x[0], x[1]])
		# against the brief's prototype: totals close, margins and win rates in its neighbourhood
		_ok(absf((avg[0] + avg[1]) - (pt[2] + pt[3])) < 2.0, "15: %s v %s total goals %.1f near the brief's %.1f" % [a, b, avg[0] + avg[1], pt[2] + pt[3]])
		_ok(absf(avg[0] - pt[2]) < 1.25 and absf(avg[1] - pt[3]) < 1.25, "15: %s v %s average score %.1f-%.1f within 1.25 of the brief's %.1f-%.1f" % [a, b, avg[0], avg[1], pt[2], pt[3]])
		_ok(win >= float(pt[4]), "15: %s v %s: %s wins %.1f%%, at least %.1f%%" % [a, b, a, win * 100.0, float(pt[4]) * 100.0])
	# upsets across OVR gaps, neutral water: the favourite's win % by gap
	var line := PackedStringArray()
	var fav := 0.0
	var last := 0.0
	var monotone := true
	for pair in [["UPAC", "HVRD"], ["CRBU", "CCSB"], ["ICU", "BROW"], ["PRIN", "SCCU"], ["LBSC", "BUCK"], ["SJCU", "IONA"], ["CUSC", "HURST"]]:
		var x := GameSim.expected(_rt(pair[0]), _rt(pair[1]), true)
		var rng := RandomNumberGenerator.new()
		rng.seed = 99
		var w := 0
		for i in 5000:
			if GameSim.score(x, rng).w == 0:
				w += 1
		fav = float(w) / 5000.0
		monotone = monotone and fav >= last - 0.03
		last = fav
		line.append("gap %d: %.1f%%" % [int(RATINGS[pair[0]][0]) - int(RATINGS[pair[1]][0]), fav * 100.0])
	print("  favourite's win %% by OVR gap: " + ", ".join(line))
	_ok(monotone and fav > 0.99, "15: a bigger OVR gap, a likelier favourite")
	# home v neutral, the same pairing
	for pair in [["CULA", "CUSC"], ["LIUB", "IONA"]]:
		var res := []
		for neutral in [true, false]:
			var x := GameSim.expected(_rt(pair[0]), _rt(pair[1]), neutral)
			var rng := RandomNumberGenerator.new()
			rng.seed = 5
			var w := 0
			var gs := [0, 0]
			for i in games / 2:
				var sc := GameSim.score(x, rng)
				gs[0] += sc.s[0]
				gs[1] += sc.s[1]
				if sc.w == 0:
					w += 1
			res.append([float(gs[0]) / (games / 2), float(gs[1]) / (games / 2), float(w) / (games / 2)])
		print("  %s v %s neutral %.2f-%.2f (%.1f%%), %s at home %.2f-%.2f (%.1f%%)" % [pair[0], pair[1], res[0][0], res[0][1], res[0][2] * 100.0, pair[0], res[1][0], res[1][1], res[1][2] * 100.0])
		_ok(res[1][2] > res[0][2] + 0.03 and res[1][0] > res[0][0] and res[1][1] < res[0][1], "the home pool helps %s at home (%.1f%% -> %.1f%%)" % [pair[0], res[0][2] * 100.0, res[1][2] * 100.0])

# ------------------------------------------------------------------ 5-7: ratings are the players'
## (2.0 team overall) A team's OVR/OFF/DEF are always its seven starters' now: results, rankings
## and the weeks going by never move them; the players' attributes do, the moment they change;
## the season keeps a snapshot of where everyone started (rating_history), and the off-season
## never pushes a team back towards the rating it started with.
func _locked_season() -> void:
	print("engine: ratings are the players'")
	var c := Career.new_game("CULA", "A", "B", 31)
	var start := {}
	# (XP Development 2.0: a team that has already played its first game may have spent the
	# upgrades it earned there, so only the teams still on their first rosters are compared)
	var played := {}
	for g in c.cur().games:
		if g.r != null:
			played[g.h] = true
			played[g.a] = true
	for id in c.teams:
		start[id] = (c.teams[id] as PoloTeam).ratings()
	_ok(c.season.has("ratings") and c.season.ratings.keys().all(func(id): return played.has(id) or range(3).all(func(i): return absf(float(c.season.ratings[id][i]) - float(start[id][i])) < 0.001)),
		"5: the season starts with a snapshot of every team's ratings")
	_ok(c.rating_history.size() == 1 and int(c.rating_history[0].year) == c.year, "the snapshot is kept in the rating history")
	var results_never := true
	var cula_losses := 0
	var guard := 0
	while c.week < c.schedule.size() and c.year == Career.START_YEAR and guard < 40:
		guard += 1
		c.queue.clear()
		while c.has_game():
			var before := {}
			var attrs := {}
			for id in c.teams:
				before[id] = (c.teams[id] as PoloTeam).ratings()
				attrs[id] = JSON.stringify((c.teams[id] as PoloTeam).roster.map(func(q): return q.attrs))
			# CULA throws a few: the result counts, the ratings don't move
			if cula_losses < 5 and not Schedule.is_playoff(c.cur()):
				c.finish_my_game({"score": [3, 9], "won": false, "played": c.team().starters()})
				cula_losses += 1
			else:
				c.sim_my_game()
			# (XP development: a game can earn an AI player a token he spends at once; only that moves it)
			for id in c.teams:
				var tm: PoloTeam = c.teams[id]
				if tm.ratings() != before[id] and JSON.stringify(tm.roster.map(func(q): return q.attrs)) == attrs[id]:
					results_never = false
		c.end_week()
	_ok(cula_losses == 5 and c.history.size() == 1, "CULA lost five games this season")
	_ok(results_never, "5-6: no result moves a team's OVR/OFF/DEF unless its players' attributes changed")
	# the players move it, at once: one starter's attribute, then a sub's (nothing)
	var me := c.team()
	var was := me.team_overall(false)
	var st: PoloPlayer = me.starters()[2]
	var k: String = st.key_ratings()[0]
	Attributes.set_ceiling(st, k, Attributes.MAX)
	Attributes.set_value(st, k, minf(Attributes.MAX, st.attr(k) + 4.0))
	_ok(me.team_overall(false) >= was, "6: a starter's attributes move the team overall the moment they change (%.2f -> %.2f)" % [was, me.team_overall(false)])
	# the off-season
	guard = 0
	while c.phase != "season" and guard < 20:
		guard += 1
		c.queue.clear()
		c.end_week()
	_ok(c.year == Career.START_YEAR + 1 and c.phase == "season", "the next season has begun")
	var moved := c.teams.keys().filter(func(id): return (c.teams[id] as PoloTeam).ratings() != start[id])
	_ok(moved.size() >= 15, "7: the new rosters make next season's ratings (%d of 30 moved)" % moved.size())
	_ok(c.teams.values().all(func(t: PoloTeam): return is_equal_approx(t.ratings()[0], (t.ratings()[1] + t.ratings()[2]) / 2.0)), "7: OVR is still the average of OFF and DEF")
	_ok(c.rating_history.size() == 2, "7: the new season keeps its own snapshot")
	var first: Dictionary = c.rating_history[0].ratings
	_ok(first.keys().all(func(id): return played.has(id) or range(3).all(func(i): return absf(float(first[id][i]) - float(start[id][i])) < 0.001)), "the first season's ratings stay in the history as they were")
	var ch: Dictionary = c.rating_history[1].ratings
	print("  CULA %s -> %s, HURST %s -> %s" % [str(start.CULA), str(ch.CULA), str(start.HURST), str(ch.HURST)])

# ------------------------------------------------------------------ 16-19: the poll
## A regular season in which `winners` win every game and `losers` lose every game (the rest
## by the engine), on to schedule index `to`.
func _rigged(c: Career, winners: Array, losers: Array, to: int) -> void:
	var guard := 0
	while c.week < to and guard < 40:
		guard += 1
		c.queue.clear()
		c._sim_others(Schedule.DAYS, true)
		for g in c.cur().games:
			var home_wins: bool = g.h in winners or g.a in losers
			var away_wins: bool = g.a in winners or g.h in losers
			if home_wins == away_wins:
				continue   # nothing to fix, or two of them meet: the engine decides
			if Schedule.winner(g) != (g.h if home_wins else g.a):
				g.r.s = [g.r.s[1], g.r.s[0]]
				g.r.w = 1 - int(g.r.w)
		# the table: recount this week's results
		c.table = {}
		for id in c.teams:
			c.table[id] = Schedule.empty_row()
		for w in c.week + 1:
			var rd: Dictionary = c.schedule[w]
			if not Schedule.is_playoff(rd):
				for g in rd.games:
					if g.r != null:
						g["n"] = true
						Schedule.record(c.table, g, Schedule.is_conf_game(rd, g))
		c.end_week()

func _poll_by_results() -> void:
	print("engine: the Top 20")
	var c := Career.new_game("WAGN", "A", "B", 12)
	var pre: Dictionary = Poll.latest(c)
	_ok(pre.kind == "pre" and pre.ranks == Poll.hierarchy(c.teams) and pre.ranks[0] == "CULA", "the Season 1 preseason poll is the initial team hierarchy (CULA #1)")
	_rigged(c, ["FORDU", "HURST"], ["CULA"], 5)
	var polls: Array = c.season.polls
	_ok(polls.size() == 6 and range(1, 6).all(func(i): return int(polls[i].wk) == i - 1 and polls[i].label == "WEEK %d" % i), "17: a new poll after every week (%d polls)" % polls.size())
	var now: Dictionary = Poll.latest(c)
	var rk := Poll.rank_map(now)
	var by_ovr := Poll.hierarchy(c.teams)
	print("  after week 5: FORDU #%d (unbeaten), CULA #%d (winless), HURST #%d (unbeaten); top 5 %s" % [rk.FORDU, rk.CULA, rk.HURST, str(now.ranks.slice(0, 5))])
	_ok(now.ranks != by_ovr, "16: the poll isn't the OVR order")
	_ok(int(rk.CULA) > 20, "16: CULA, the best team on paper, falls out of the Top 20 after losing every game (#%d)" % rk.CULA)
	_ok(int(rk.FORDU) <= 3, "16: FORDU climbs to the top by winning every game (#%d)" % rk.FORDU)
	_ok(int(rk.HURST) <= 20, "16: HURST, the lowest-rated team, climbs into the Top 20 on its upsets (#%d)" % rk.HURST)
	var rated := [c.teams["CULA"].ratings(), c.teams["HURST"].ratings()]
	Poll.make(c.teams, c.schedule, 4, c.season.poll_prior, polls[4])   # (a poll made, nothing kept)
	_ok([c.teams["CULA"].ratings(), c.teams["HURST"].ratings()] == rated, "rankings never change ratings")
	# from week 4 on it's results only: the same results with any preseason order give the same poll
	var flipped: Array = (c.season.poll_prior as Array).duplicate()
	flipped.reverse()
	var again := Poll.make(c.teams, c.schedule, 4, flipped, polls[4])
	_ok(again.ranks == now.ranks, "16: week 4 onward is results only (the preseason order makes no difference)")
	var early_a := Poll.make(c.teams, c.schedule, 0, c.season.poll_prior, polls[0])
	var early_b := Poll.make(c.teams, c.schedule, 0, flipped, polls[0])
	_ok(early_a.ranks != early_b.ranks, "the preseason poll still counts after week 1")
	_ok(Poll.prior_weight(0) == 1.0 and Poll.prior_weight(1) > Poll.prior_weight(2) and Poll.prior_weight(3) == 0.0, "the preseason influence fades over three weeks")
	# 18: movement against the poll before
	var rows := Poll.rows(c, now)
	var prev_rk := Poll.rank_map(polls[polls.size() - 2])
	var moves_ok := true
	for d in rows:
		var before := int(prev_rk.get(d.id, 0))
		if d.rv:
			continue
		if before > Poll.TOP:
			moves_ok = moves_ok and d.move == "NEW" and d.prev == 0
		else:
			moves_ok = moves_ok and d.prev == before and int(d.move) == before - int(d.rank)
	_ok(moves_ok, "18: previous rank and movement (up, down, NEW) against last week's poll")
	var pre_rows := Poll.rows(c, polls[0])
	_ok(pre_rows.all(func(d): return d.move == "-"), "18: the preseason poll has no movement")
	# 19: two teams receiving votes under the Top 20
	_ok(rows.size() == 22 and rows.slice(0, 20).all(func(d): return not d.rv) and rows[20].rv and rows[21].rv and rows[20].rank == 21, "19: #1-#20, then two receiving votes")
	# ties: head to head first
	var sc := {"A": {"beat": {"B": 1}, "qw": 0.0, "sos": 0.0}, "B": {"beat": {}, "qw": 1.0, "sos": 1.0}}
	_ok(Poll.order({"A": 0, "B": 0}, {"A": 50.0, "B": 50.0}, sc) == ["A", "B"], "a tie goes to head to head before quality wins")
	sc.A.beat = {}
	_ok(Poll.order({"A": 0, "B": 0}, {"A": 50.0, "B": 50.0}, sc) == ["B", "A"], "...then quality wins")

# ------------------------------------------------------------------ 22-25: selection
func _selection_rule() -> void:
	print("engine: NCSA selection")
	# the brief's example: champions #1 CULA, #3 FORDU, #8 LBSC, #15 PRIN and unranked HURST
	var ranks := ["CULA", "CUSC", "FORDU", "STAM", "ALC", "SJCU", "CUSD", "LBSC", "PPCU", "UCDS", "ICU", "CRBU", "LMMU", "UPAC", "PRIN",
		"HVRD", "CCSB", "NANA", "BROW", "GWU", "SCCU", "USAF", "SMCC", "CSFU", "BUCK", "WAGN", "MSMU", "IONA", "LIUB", "HURST"]
	var champs := ["CULA", "FORDU", "LBSC", "PRIN", "HURST"]
	var field := Schedule.select_field(ranks, champs, 12)
	var at_large: Array = field.filter(func(id): return not id in champs)
	_ok(field.size() == 12 and champs.all(func(ch): return ch in field), "22: all five tournament champions are in, HURST unranked too")
	_ok(at_large == ["CUSC", "STAM", "ALC", "SJCU", "CUSD", "PPCU", "UCDS"], "24-25: the seven at-large are the next seven down the poll %s" % str(at_large))
	_ok(field[0] == "CULA" and field[11] == "HURST" and _in_poll_order(field, ranks), "seeded in poll order (HURST 12th)")

func _in_poll_order(field: Array, ranks: Array) -> bool:
	for i in range(1, field.size()):
		if ranks.find(field[i]) < ranks.find(field[i - 1]):
			return false
	return true

# ------------------------------------------------------------------ 17, 20-27: whole seasons
func _season_flow() -> void:
	print("engine: seasons")
	var reg_champ_out := 0
	for seed in [5, 64, 808, 2024]:
		var c := Career.new_game("NANA", "A", "B", seed)
		# 21: the calendar underneath is the same
		var reg: Array = c.schedule.filter(func(rd): return not Schedule.is_playoff(rd))
		_ok(reg.size() == 10 and c.schedule.size() == 17, "21: seed %d: 10 internal regular-season weeks, then 7 playoff rounds" % seed)
		var games_ok := true
		var nums_ok := true
		for id in c.teams:
			var tg := Schedule.team_games(c.schedule, id)
			games_ok = games_ok and tg.size() == 16
			var per_week := {}
			for i in tg.size():
				nums_ok = nums_ok and Schedule.game_no(c.schedule, id, tg[i][1]) == i + 1
				per_week[tg[i][0]] = int(per_week.get(tg[i][0], 0)) + 1
				if i > 0:
					nums_ok = nums_ok and (tg[i][0] > tg[i - 1][0] or (tg[i][0] == tg[i - 1][0] and int(tg[i][1].d) > int(tg[i - 1][1].d)))
			games_ok = games_ok and per_week.values().all(func(n): return n <= 3)
		_ok(games_ok, "21: seed %d: 16 games each, never more than 3 in a week" % seed)
		_ok(nums_ok, "20: seed %d: every team's games are numbered 1-16 in the order played" % seed)
		_ok(c.calendar_text() == "GAME 1/16", "20: the header says GAME 1/16 (%s)" % c.calendar_text())
		_ok(c.week_text() == "WEEK 1" and c.season_years() == "%d-%d" % [c.year, c.year + 1],
			"hub tracker: %s, %s at the start" % [c.season_years(), c.week_text()])
		r._sim_to(c, 3)
		_ok(c.week_text() == "WEEK %d" % (c.week + 1) and Schedule.games_played(c.schedule, c.school) >= c.week,
			"hub tracker: weeks, not games (%s after %d games)" % [c.week_text(), Schedule.games_played(c.schedule, c.school)])
		r._sim_to(c, 13)
		var dogs := 0
		var played := 0
		for rd in c.schedule.slice(0, 10):
			for g in rd.games:
				var gap: float = c.teams[g.h].rating() - c.teams[g.a].rating()
				if gap != 0.0:
					played += 1
					if (Schedule.winner(g) == g.h) != (gap > 0.0):
						dogs += 1
		print("  seed %d: the lower-rated team won %d of %d regular-season games (%.0f%%)" % [seed, dogs, played, 100.0 * dogs / played])
		_ok(dogs > played / 20, "seed %d: upsets happen through the season (%d)" % [seed, dogs])
		var polls: Array = c.season.polls
		var kinds: Array = polls.map(func(p): return String(p.label))
		_ok(polls.size() == 14 and kinds.slice(1, 11) == range(1, 11).map(func(i): return "WEEK %d" % i) and kinds.slice(11) == ["CONF. QUARTERFINALS", "CONF. SEMIFINALS", "SELECTION"],
			"17: seed %d: preseason, 10 weekly polls, then after each conference tournament round %s" % [seed, str(kinds)])
		var sel: Dictionary = polls[13]
		_ok(sel.kind == "select" and int(sel.wk) == 12, "the SELECTION poll comes out after the conference finals")
		var champs: Array = c.season.conf_champs
		var finals: Array = c.schedule[12].games.map(func(g): return Schedule.winner(g))
		var field: Array = c.season.nat_seeds
		_ok(champs.size() == 5 and champs == finals and champs.all(func(ch): return ch in field), "22: seed %d: the five conference tournament champions get the automatic bids" % seed)
		var at_large: Array = field.filter(func(id): return not id in champs)
		var want: Array = (sel.ranks as Array).filter(func(id): return not id in champs).slice(0, 7)
		_ok(at_large.size() == 7 and c.season.at_large == at_large, "24: seed %d: exactly seven at-large teams" % seed)
		_ok(want == at_large, "25: seed %d: the at-large bids go straight down the SELECTION poll %s" % [seed, str(at_large)])
		var lowest_in := 0
		for id in at_large:
			lowest_in = maxi(lowest_in, Poll.rank_in(sel, id))
		var skipped: Array = (sel.ranks as Array).slice(0, lowest_in).filter(func(id): return not id in field)
		_ok(skipped.is_empty(), "25: no eligible team ranked above the last at-large team is left out %s" % str(skipped))
		_ok(field.size() == 12 and _in_poll_order(field, sel.ranks), "26: seed %d: 12 teams, seeded in SELECTION poll order" % seed)
		# 23: the regular-season champions only get in through the tournament or the poll
		for cid in ["MPSF", "BIGWEST", "WCC", "MAWPC", "NWPC"]:
			var top: String = c.season.conf_seeds[cid][0]
			if not top in champs:
				var by_poll: bool = top in want
				_ok((top in field) == by_poll, "23: seed %d: %s, %s regular-season champion, is %s by its poll rank (#%d) alone" % [seed, top, cid, "in" if by_poll else "out", Poll.rank_in(sel, top)])
				if not top in field:
					reg_champ_out += 1
		var r1: Dictionary = c.schedule[13]
		_ok(r1.games.size() == 4 and r1.games.all(func(g): return field.find(g.h) >= 4 and field.find(g.a) >= 4), "27: seed %d: seeds 1-4 have byes, 5-12 play the first round" % seed)
		r._sim_to(c, 17)
		_ok(c.schedule[15].games.all(func(g): return Schedule.is_neutral(g)) and c.schedule[16].games.all(func(g): return Schedule.is_neutral(g)), "the NCSA semifinals and final are at a neutral site")
		_ok(c.schedule.slice(0, 15).all(func(rd): return rd.games.all(func(g): return not Schedule.is_neutral(g))), "every other game is at the home team's pool")
		var all_ok := true
		for rd in c.schedule:
			for g in rd.games:
				if g.r == null:
					all_ok = false
					continue
				var s: Array = g.r.s
				all_ok = all_ok and s[0] >= 0 and s[1] >= 0 and s[0] != s[1] and int(g.r.w) == (0 if s[0] > s[1] else 1) and g.r.has("sd")
		_ok(all_ok, "12-13: seed %d: every game of the season has a seed, no negative score, and its winner scored more" % seed)
		_ok(c.final_polls.size() == 1 and int(c.final_polls[0].year) == Career.START_YEAR and c.season.polls[c.season.polls.size() - 1].label == "FINAL", "a FINAL poll after the NCSA final")
		_ok(int(c.history[0].get("poll", 0)) == Poll.rank_in(Poll.latest(c), c.school), "the season's history keeps your final rank")
		var guard := 0
		while c.phase != "season" and guard < 20:
			guard += 1
			c.queue.clear()
			c.end_week()
		_ok(c.season.poll_prior == c.final_polls[0].ranks, "the next preseason poll starts from last season's final poll")
	print("  regular-season conference champions who missed the NCSA Championship: %d in 4 seasons" % reg_champ_out)

# ------------------------------------------------------------------ 30: saves
func _saves() -> void:
	print("engine: saves")
	var c := Career.new_game("PRIN", "A", "B", 77)
	r._sim_to(c, 6)
	while c.has_game():
		c.sim_my_game()
	var d: Dictionary = JSON.parse_string(JSON.stringify(c.to_dict()))
	var c2 := Career.from_dict(d)
	_ok(not c2.rated and int(d.v) == Career.SAVE_VERSION, "a new save loads as it is")
	_ok(c2.teams.keys().all(func(id): return (c2.teams[id] as PoloTeam).ratings() == (c.teams[id] as PoloTeam).ratings()) and JSON.stringify(c2.season.ratings) == JSON.stringify(c.season.ratings), "30: OVR/OFF/DEF and the season snapshot survive a save")
	_ok(c2.season.polls.size() == c.season.polls.size() and Poll.latest(c2).ranks == Poll.latest(c).ranks and _moves(c2) == _moves(c), "30: the polls, previous ranks and movement survive a save")
	var sim_ok := true
	for w in c.week + 1:
		for i in c.schedule[w].games.size():
			var g: Dictionary = c.schedule[w].games[i]
			var g2: Dictionary = c2.schedule[w].games[i]
			if g.r != null:
				sim_ok = sim_ok and g2.r.s == g.r.s and g2.r.get("sd") == g.r.get("sd") and g2.r.get("q") == g.r.get("q") and g2.r.get("ot") == g.r.get("ot")
				if g.r.has("sd") and g2.r.sd is int:
					var again := GameSim.replay(c2.teams[g.h], c2.teams[g.a], g2.r, Schedule.is_neutral(g2))
					sim_ok = sim_ok and again.score == g.r.s
	_ok(sim_ok, "30: simulated scores, quarters, overtime and seeds survive a save, and a seed replays its game")
	_ok(Schedule.game_no(c2.schedule, "PRIN", c2.my_game()) == Schedule.game_no(c.schedule, "PRIN", c.my_game()) and c2.calendar_text() == c.calendar_text(), "30: the game numbers are the same after loading")
	# the playoffs: qualifiers and the bracket survive a save
	r._sim_to(c, 14)
	var d3: Dictionary = JSON.parse_string(JSON.stringify(c.to_dict()))
	var c3 := Career.from_dict(d3)
	_ok(c3.season.nat_seeds == c.season.nat_seeds and c3.season.at_large == c.season.at_large and c3.season.conf_champs == c.season.conf_champs and c3.season.nat_slots == c.season.nat_slots, "30: the NCSA qualifiers and bracket survive a save")
	r._sim_to(c3, 17)
	_ok(c3.phase == "done" and c3.season.champion != "", "a loaded save plays the NCSA Championship out")
	# an older save (version 5), mid-season: its locked "ovr" from the school table, no OFF/DEF,
	# no snapshot. Its players are kept exactly; its ratings are its players'.
	var old := Career.new_game("BUCK", "A", "B", 40)
	r._sim_to(old, 4)
	var od: Dictionary = JSON.parse_string(JSON.stringify(old.to_dict()))
	od.v = 5
	od.erase("rating_history")
	od.erase("final_polls")
	od.season.erase("polls")
	od.season.erase("poll_prior")
	od.season.erase("ratings")
	var shown := {}
	for id in od.teams:
		var td: Dictionary = od.teams[id]
		td.erase("init_target")
		td.ovr = int(RATINGS[id][0]) + 7   # (whatever it says, it's never read)
		shown[id] = PoloTeam.from_dict(td).ratings()
	var o2 := Career.from_dict(od)
	_ok(o2.rated, "an old save gets its season snapshot on load (and Game keeps a backup of the original)")
	_ok(o2.teams.keys().all(func(id): return (o2.teams[id] as PoloTeam).ratings() == shown[id]), "an old save's teams are rated from their players, never the saved number")
	# (but "schol": a pre-7 save re-awards scholarships to the best four now, and with XP
	# development the AI's best four can have changed since week 0)
	var bare := func(q: PoloPlayer) -> Dictionary:
		var dd := q.to_dict()
		dd.erase("schol")
		return dd
	_ok(o2.teams.keys().all(func(id): return JSON.stringify(o2.teams[id].roster.map(bare)) == JSON.stringify(od.teams[id].roster.map(func(q): return bare.call(PoloPlayer.from_dict(q))))), "...its players exactly as saved")
	_ok(o2.season.polls.size() == o2.week + 1, "...with the polls of the weeks already played (%d)" % o2.season.polls.size())
	r._sim_to(o2, 13)
	_ok(o2.season.nat_seeds.size() == 12, "...and plays on to a 12-team NCSA field")

func _moves(c: Career) -> Array:
	return Poll.rows(c, Poll.latest(c)).map(func(d): return [d.id, d.prev, str(d.move), d.rec[0], d.rec[1]])

# ------------------------------------------------------------------ 9, 18-20: the screens
func _screens() -> void:
	print("engine: screens")
	var c := Career.new_game("FORDU", "A", "B", 21)
	r._sim_to(c, 3)
	c.queue.clear()
	Game.career = c
	Game.goto("top20")
	await r.get_tree().process_frame
	var scr = Game.current_screen
	_ok(scr != null and scr.title_label.text == "NATIONAL TOP 20", "the National Top 20 screen opens")
	var labels: Array = scr.find_children("*", "Label", true, false).map(func(l): return (l as Label).text)
	_ok("WEEK 3 POLL" in labels, "it shows the latest poll %s" % str(labels.slice(0, 4)))
	scr.at = 0
	scr._render()
	await r.get_tree().process_frame
	labels = scr.find_children("*", "Label", true, false).map(func(l): return (l as Label).text)
	_ok("PRESEASON POLL" in labels, "< goes back to the preseason poll")
	# the hub has the way in
	for q in Game.career.upgrades_due(): Development.ai_spend(q)   # (XP 2.0: upgrades are spent before the hub moves on)
	Game.goto("hub")
	await r.get_tree().process_frame
	var hub = Game.current_screen
	var tops: Array = hub.find_children("*", "Button", true, false).filter(func(b): return (b as Button).text.begins_with("TOP 20"))
	_ok(tops.size() == 1, "the hub has a TOP 20 button (%s)" % (tops[0].text if not tops.is_empty() else "none"))
	if not tops.is_empty():
		(tops[0] as Button).pressed.emit()
		await r.get_tree().create_timer(0.6).timeout
		_ok(Game.current_screen != null and Game.current_screen.get_script().resource_path.ends_with("top20.gd"), "...and it opens the Top 20")
	# 20: the schedule says GAME 1-16, no week numbers
	Game.goto("schedule")
	await r.get_tree().process_frame
	var rows: Array = Game.current_screen._rows()
	var nums: Array = rows.filter(func(d): return d.wk != "").map(func(d): return d.wk)
	_ok(nums == range(1, 17).map(func(i): return str(i)), "20: the schedule numbers the games 1 to 16 %s" % str(nums))
	_ok(rows.filter(func(d): return d.wk == "" and not d.opp in ["BYE", "OUT", "TBD"]).size() == 0, "20: only byes and playoff rounds have no number")
	if c.has_game():
		for q in Game.career.upgrades_due(): Development.ai_spend(q)   # (XP 2.0: upgrades are spent before the hub moves on)
		Game.goto("matchup")
		await r.get_tree().process_frame
		var n := Schedule.game_no(c.schedule, c.school, c.my_game())
		_ok(Game.current_screen.title_label.text == "GAME %d" % n, "20: the game preview says GAME %d (%s)" % [n, Game.current_screen.title_label.text])
	Game.goto("title")
	await r.get_tree().process_frame
	Game.career = null

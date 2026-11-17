extends RefCounted
## The Simulation Realism & Instant Sim update: full games by OVR gap (the scoring engine every
## simulated game uses, GameSim), SIM TO END from every point of a match (SimFinish: only what's
## left, nothing reset, the box score adding up), and how long SIM TO END takes.
##   godot --headless --path game -- --test sim_realism [games per matchup]

## [A's OVR, B's OVR] and the brief's typical winning margin for that gap.
const MATCHUPS := [
	[80, 80, 1.0, 3.5],
	[85, 80, 2.0, 5.0],
	[85, 75, 4.0, 7.0],
	[88, 68, 8.0, 13.0],
	[90, 65, 11.0, 17.0],
]

var r   # the test runner (check)

func run(runner, games: int = 5000) -> void:
	r = runner
	Store.reset_for_tests()
	_full_games(games)
	_sim_finish_consistent(maxi(1000, games / 5))
	_partial_games(maxi(1000, games / 5))
	_late_lead(maxi(1000, games / 5))
	await _speed()

func _ok(ok: bool, what: String) -> void:
	r.check(ok, what)

## Plain ratings for an OVR (no lean either way, no keeper term): the gap alone.
func _rt(ovr: float) -> Array:
	return [ovr, ovr, ovr]

# ------------------------------------------------------------------ full games
func _full_games(games: int) -> void:
	print("sim_realism: %d neutral full games per matchup (GameSim)" % games)
	print("  %-9s %-13s %-8s %-8s %-8s %-8s %-8s %-8s" % ["OVR", "AVG SCORE", "TOTAL", "MARGIN", "FAV WIN", "1-2 GLS", "8+ GLS", "UPSETS"])
	for m in MATCHUPS:
		var x := GameSim.expected(_rt(m[0]), _rt(m[1]), true)
		var rng := RandomNumberGenerator.new()
		rng.seed = 2026 + int(m[0]) * 100 + int(m[1])
		var st := _measure(games, func(): return GameSim.score(x, rng).s)
		print("  %d v %d   %5.1f-%-6.1f %-8.1f %-8.2f %-8s %-8s %-8s %s" % [m[0], m[1], st.a, st.b, st.total, st.margin,
			"%.1f%%" % (st.fav * 100.0), "%.1f%%" % (st.close * 100.0), "%.1f%%" % (st.big * 100.0), "%.1f%%" % (st.upset * 100.0)])
		var gap: int = int(m[0]) - int(m[1])
		_ok(st.margin >= float(m[2]) and st.margin <= float(m[3]), "%d v %d: the average winning margin %.2f is the brief's %.0f-%.0f" % [m[0], m[1], st.margin, m[2], m[3]])
		_ok(st.total >= 20.0 and st.total <= 28.0, "%d v %d: %.1f goals a game, college water polo's pace" % [m[0], m[1], st.total])
		if gap == 0:
			_ok(absf(st.fav - 0.5) < 0.03, "even teams: a coin flip (%.1f%%)" % (st.fav * 100.0))
			_ok(st.close > 0.35, "even teams: often decided by one or two (%.1f%%)" % (st.close * 100.0))
		if gap >= 5 and gap <= 10:
			_ok(st.upset > 0.0, "%d v %d: upsets still happen (%.2f%%)" % [m[0], m[1], st.upset * 100.0])
		if gap == 20:
			_ok(st.fav > 0.98, "88 v 68: the 88 wins the overwhelming majority (%.2f%%)" % (st.fav * 100.0))
			_ok(st.close < 0.05, "88 v 68: games decided by 1-2 goals are rare (%.2f%%)" % (st.close * 100.0))
			_ok(st.big > 0.6, "88 v 68: usually by 8 or more (%.1f%%)" % (st.big * 100.0))
		if gap == 25:
			_ok(st.fav > 0.995, "90 v 65: an upset all but never (%.3f%%)" % (st.upset * 100.0))
	# the keeper: a better GOALKEEPING, fewer goals against
	var with_gk := GameSim.neutral_expected([80.0, 80.0, 80.0, 85.0], [80.0, 80.0, 80.0, 65.0])
	print("  80 v 80, keepers 85 v 65: %.2f-%.2f" % [with_gk[0], with_gk[1]])
	_ok(with_gk[0] > with_gk[1] + 0.5 and absf(with_gk[0] + with_gk[1] - 23.0) < 1.5, "a better keeper takes goals off the other side (%.2f-%.2f)" % [with_gk[0], with_gk[1]])

## {a, b: average scores; total; margin: average winning margin; fav: A's win share; close: share
## decided by 1-2; big: by 8+; upset: B's win share} over `games` of `play` (-> [a, b]).
func _measure(games: int, play: Callable) -> Dictionary:
	var sa := 0.0
	var sb := 0.0
	var margin := 0.0
	var wins := 0
	var upsets := 0
	var close := 0
	var big := 0
	for i in games:
		var s: Array = play.call()
		sa += s[0]
		sb += s[1]
		var d := absi(int(s[0]) - int(s[1]))
		margin += d
		if s[0] > s[1]:
			wins += 1
		elif s[1] > s[0]:
			upsets += 1
		if d >= 1 and d <= 2:
			close += 1
		if d >= 8:
			big += 1
	var n := float(games)
	return {"a": sa / n, "b": sb / n, "total": (sa + sb) / n, "margin": margin / n, "fav": wins / n, "upset": upsets / n,
		"close": close / n, "big": big / n}

# ------------------------------------------------------------------ SIM TO END
## Two career teams `a` and `b` (your side a), a fresh match between them.
func _flow(a: PoloTeam, b: PoloTeam, seed: int) -> MatchFlow:
	var f := MatchFlow.new(a, b, seed, MatchState.QUARTER_MIN)
	f.home = true
	return f

func _teams() -> Dictionary:
	if Game.career == null or not Game.career.teams.has("ALC"):
		Game.career = Career.new_game("BROW", "Test", "Coach", 4242)
	return Game.career.teams

## SIM TO END from kickoff is the same game as a weekly sim of the same two teams: the same
## expected goals, the same spread.
func _sim_finish_consistent(n: int) -> void:
	var t := _teams()
	var a: PoloTeam = t["ALC"]    # 88
	var b: PoloTeam = t["WAGN"]   # 68
	print("sim_realism: SIM TO END from kickoff v a weekly sim, %s (%d) v %s (%d), %d games each, neutral" % [a.id, a.base_ovr(), b.id, b.base_ovr(), n])
	var x := GameSim.expected(GameSim.live_ratings(a), GameSim.live_ratings(b), true)
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var weekly := _measure(n, func(): return GameSim.score(x, rng).s)
	var i := [0]
	var finish := _measure(n, func():
		i[0] += 1
		var f := _flow(a, b, 5000 + i[0])
		SimFinish.run(f, true, 9000 + i[0])
		return f.state.score)
	print("  weekly sim   %.1f-%.1f, margin %.2f, %s wins %.1f%%" % [weekly.a, weekly.b, weekly.margin, a.id, weekly.fav * 100.0])
	print("  SIM TO END   %.1f-%.1f, margin %.2f, %s wins %.1f%%" % [finish.a, finish.b, finish.margin, a.id, finish.fav * 100.0])
	_ok(absf(weekly.a - finish.a) < 0.6 and absf(weekly.b - finish.b) < 0.6 and absf(weekly.fav - finish.fav) < 0.03,
		"SIM TO END from kickoff plays like a weekly sim of the same teams")

## SIM TO END from five points of a match, each from a score already on the board.
func _partial_games(n: int) -> void:
	var t := _teams()
	var a: PoloTeam = t["ALC"]
	var b: PoloTeam = t["WAGN"]
	var ql := MatchState.QUARTER_MIN * 60.0
	# [name, quarter, clock, phase, score so far]
	var points := [
		["start of Q1", 1, ql, MatchFlow.Phase.SPRINT, [0, 0]],
		["middle of Q2", 2, ql * 0.5, MatchFlow.Phase.ATTACK, [3, 2]],
		["halftime", 2, 0.0, MatchFlow.Phase.BREAK, [5, 4]],
		["start of Q4", 4, ql, MatchFlow.Phase.SPRINT, [9, 6]],
		["final minute", 4, ql * 0.5, MatchFlow.Phase.DEFENSE, [12, 8]],
	]
	print("sim_realism: SIM TO END from five points, %s (%d) v %s (%d), %d each" % [a.id, a.base_ovr(), b.id, b.base_ovr(), n])
	var last_added := INF
	for pt in points:
		var added := [0.0, 0.0]
		var kept := true
		var box := true
		var final_ok := true
		var max_ms := 0.0
		var total_ms := 0.0
		for i in n:
			var f := _flow(a, b, 100 + i)
			_stage(f, pt)
			var before: Array = f.state.score.duplicate()
			var goals_before: Array = [f.state.goal_by[0].duplicate(), f.state.goal_by[1].duplicate()]
			var t0 := Time.get_ticks_usec()
			var res := SimFinish.run(f, false, 31 * i + 7)
			var ms := (Time.get_ticks_usec() - t0) / 1000.0
			max_ms = maxf(max_ms, ms)
			total_ms += ms
			var st := f.state
			for side in 2:
				added[side] += st.score[side] - before[side]
				kept = kept and st.score[side] >= before[side] and int(res.goals[side]) == st.score[side] - before[side]
				for k in goals_before[side].size():
					kept = kept and st.goal_by[side][k] == goals_before[side][k]
			box = box and _box_ok(st)
			final_ok = final_ok and f.phase == MatchFlow.Phase.FINAL and st.quarter == MatchState.QUARTERS and st.clock == 0.0 and st.winner() != -1
		var add_total: float = (added[0] + added[1]) / n
		print("  %-13s Q%d %5.1fs %-7s share %.3f: +%.2f / +%.2f goals (rest margin %+.2f), %.3f ms avg, %.3f ms max" % [pt[0], pt[1], pt[2],
			str(pt[4]), SimFinish.remaining_share(_staged(a, b, pt)), added[0] / n, added[1] / n, (added[0] - added[1]) / n, total_ms / n, max_ms])
		_ok(kept, "%s: the score so far and its goals kept, only the rest added" % pt[0])
		_ok(box, "%s: the box score adds up (goals, assists, shots, saves, steals, blocks, exclusions)" % pt[0])
		_ok(final_ok, "%s: full time, a winner by the normal rules" % pt[0])
		_ok(add_total <= last_added + 0.2, "%s: fewer goals still to come the less time is left (%.1f)" % [pt[0], add_total])
		_ok(max_ms < 50.0, "%s: worked out in %.2f ms at most" % [pt[0], max_ms])
		last_added = add_total

func _staged(a: PoloTeam, b: PoloTeam, pt: Array) -> MatchState:
	var f := _flow(a, b, 1)
	_stage(f, pt)
	return f.state

## A match put at point `pt`: the quarter, the clock, the phase, a score with its scorers.
func _stage(f: MatchFlow, pt: Array) -> void:
	var st := f.state
	st.quarter = int(pt[1])
	st.clock = float(pt[2])
	var score: Array = pt[4]
	for side in 2:
		var team: PoloTeam = f.us if side == 0 else f.them
		var field := team.starters().slice(1)
		for k in int(score[side]):
			var who: PoloPlayer = field[k % field.size()]
			st.add_goal(side, who)
			st.shots[side] += 1
			st.shot_by[side].append(who)
	if int(pt[3]) == MatchFlow.Phase.ATTACK:
		f.sprint_done(true)
	elif int(pt[3]) == MatchFlow.Phase.DEFENSE:
		f.sprint_done(false)
	else:
		f.phase = int(pt[3])

## Every goal has a scorer and a shot, assists never outnumber goals, saves and blocks match
## their lists' sizes where those are kept, nobody fouled out twice.
func _box_ok(st: MatchState) -> bool:
	for side in 2:
		if st.goal_by[side].size() != st.score[side]:
			return false
		if st.assist_by[side].size() > st.score[side] or st.shot_by[side].size() > st.shots[side] or st.shots[side] < st.score[side]:
			return false
		if st.block_by[side].size() != st.blocks[side] or st.steal_by[side].size() != st.steals[side]:
			return false
		if st.excl_drawn_by[side].size() != st.exclusions[side] or st.excl_by[1 - side].size() != st.exclusions[side]:
			return false
	for id in st.pf:
		if int(st.pf[id]) > MatchState.ROLL_AT:
			return false
	return true

## The brief's own case: the 68 up 8-3 on the 88 with a minute left. The lead mostly holds.
func _late_lead(n: int) -> void:
	var t := _teams()
	var weak: PoloTeam = t["WAGN"]
	var strong: PoloTeam = t["ALC"]
	var ql := MatchState.QUARTER_MIN * 60.0
	var held := 0
	var added := [0.0, 0.0]
	for i in n:
		var f := _flow(weak, strong, 300 + i)
		_stage(f, ["final minute", 4, ql * 0.5, MatchFlow.Phase.DEFENSE, [8, 3]])
		SimFinish.run(f, false, 17 * i + 3)
		added[0] += f.state.score[0] - 8
		added[1] += f.state.score[1] - 3
		if f.state.winner() == 0:
			held += 1
	print("sim_realism: %s (%d) up 8-3 on %s (%d) with a minute left: the lead held %.1f%% (+%.2f / +%.2f goals)" % [weak.id, weak.base_ovr(), strong.id, strong.base_ovr(), 100.0 * held / n, added[0] / n, added[1] / n])
	_ok(float(held) / n > 0.97, "a five-goal lead with a minute left isn't wiped out by the ratings (%.1f%% held)" % (100.0 * held / n))
	_ok(added[1] / n > added[0] / n, "...though the better team still wins the minute (+%.2f v +%.2f)" % [added[1] / n, added[0] / n])

# ------------------------------------------------------------------ speed
## SIM TO END on the real match screen, from a career game in its first quarter: confirm to the
## full-time panel, measured.
func _speed() -> void:
	var times: Array = []
	for i in 5:
		Game.career = Career.new_game("BROW", "Test", "Coach", 600 + i)
		var c := Game.career
		var cfg := {"us": c.team(), "them": c.opponent() if c.opponent() != null else c.teams["ALC"], "career": true, "home": true, "autoplay": true,
			"seed": 70 + i, "intro": false, "victory": false}
		Game.match_cfg = cfg
		Game.goto("match", cfg)
		await r.get_tree().process_frame
		var ms = Game.current_screen
		for k in 30:
			ms._process(1.0 / 60.0)
		ms._sim_to_end_now()
		times.append(ms.sim_end_ms)
		_ok(ms.flow.phase == MatchFlow.Phase.FINAL and ms.results != null, "screen %d: full time and the results panel straight away" % i)
	times.sort()
	print("sim_realism: SIM TO END on the match screen, confirm to the full-time panel: %s ms (max %.2f)" % [", ".join(times.map(func(v): return "%.2f" % v)), times[-1]])
	_ok(float(times[-1]) < 500.0, "SIM TO END takes under half a second (max %.2f ms)" % times[-1])
	Game.career = null

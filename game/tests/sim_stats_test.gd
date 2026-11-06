extends RefCounted
## Simulated games' player stats (GameSim.player_lines): steals, turnovers and exclusions
## committed alongside the blocks and exclusions drawn, all from the game's own result (the score,
## goals, assists and saves never move), at the rates played games show; and the goals spread
## over a team's shooters more evenly (GameSim scorers: PlayerForm.shot_weight).
##   godot --headless --path game -- --test sim_stats
##   godot --headless --path game -- --test sim_stats_measure [n]   (played vs simulated rates)

var r

## Per side per game: [turnovers, steals, exclusions committed, exclusions drawn] in n bot-played
## matches (MatchFlow, both sides' AI) and n simulated games of the same pairings; and the
## simulated goals' spread: the top scorer's share of a team's goals.
static func measure(runner, n: int) -> Dictionary:
	var played := [0.0, 0.0, 0.0, 0.0, 0.0]   # (and goals, the fifth)
	var simmed := [0.0, 0.0, 0.0, 0.0, 0.0]
	var top_share := 0.0
	var top_n := 0
	var c := Career.new_setup(808)
	var ids: Array = c.teams.keys()
	for i in n:
		var a: PoloTeam = c.teams[ids[(i * 7) % ids.size()]]
		var b: PoloTeam = c.teams[ids[(i * 7 + 11) % ids.size()]]
		var f := MatchFlow.new(a, b, 9000 + i, MatchState.QUARTER_MIN, 0.5)
		var steps := 0
		while f.phase != MatchFlow.Phase.FINAL and steps < 200000:
			steps += 1
			match f.phase:
				MatchFlow.Phase.SPRINT:
					f.sprint_done(f.rng.randf() < 0.5)
				MatchFlow.Phase.ATTACK:
					runner._run_flow_attack(f)
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
		var st: MatchState = f.state
		for side in 2:
			played[0] += st.turnover_by[side].size()
			played[1] += st.steal_by[side].size() + st.keeper_steal_by[side].size()
			played[2] += st.excl_by[side].size()
			played[3] += st.excl_drawn_by[side].size()
			played[4] += int(st.score[side])
		var res := GameSim.play(a, b, 9000 + i)
		for side in 2:
			var tot := [0, 0, 0, 0]
			for id in res.lines[side]:
				var ln: Dictionary = res.lines[side][id]
				tot[0] += int(ln.get("to", 0))
				tot[1] += int(ln.get("st", 0))
				tot[2] += int(ln.get("ex", 0))
				tot[3] += int(ln.get("ed", 0))
			for k in 4:
				simmed[k] += tot[k]
			simmed[4] += int(res.score[side])
			var by := {}
			for p in res.goals[side]:
				by[p.id] = int(by.get(p.id, 0)) + 1
			if res.goals[side].size() >= 6:
				top_share += float(by.values().max()) / res.goals[side].size()
				top_n += 1
	for k in 5:
		played[k] /= 2.0 * n
		simmed[k] /= 2.0 * n
	return {"played": played, "simmed": simmed, "top_share": top_share / maxf(1, top_n), "season_share": season_share()}

## Over a regular season of simulated games: each team's top scorer's share of its goals, averaged.
static func season_share() -> float:
	var c := Career.new_game("LIUB", "A", "B", 4040)
	var guard := 0
	while c.week < Schedule.REGULAR_WEEKS and guard < 30:
		guard += 1
		c.queue.clear()
		while c.has_game():
			c.sim_my_game()
		for q in c.upgrades_due():
			Development.ai_spend(q)
		c.end_week()
	var total := 0.0
	for id in c.teams:
		var t: PoloTeam = c.teams[id]
		var g := 0
		var top := 0
		for p: PoloPlayer in t.roster:
			g += p.stat("g")
			top = maxi(top, p.stat("g"))
		total += float(top) / maxf(1.0, g)
	return total / c.teams.size()

func run(runner) -> void:
	r = runner
	print("simulated games' player stats")
	var c := Career.new_setup(77)
	var ids: Array = c.teams.keys()
	var same := true
	var reconciled := true
	var steals_ok := true
	var any := [0, 0, 0]
	for i in 60:
		var a: PoloTeam = c.teams[ids[i % ids.size()]]
		var b: PoloTeam = c.teams[ids[(i + 7) % ids.size()]]
		var res := GameSim.play(a, b, 500 + i)
		var again := GameSim.play(a, b, 500 + i)
		same = same and res.score == again.score and str(res.lines) == str(again.lines)
		for side in 2:
			var to := 0
			var ex := 0
			var g := 0
			for id in res.lines[side]:
				to += int(res.lines[side][id].get("to", 0))
				ex += int(res.lines[side][id].get("ex", 0))
				g += int(res.lines[side][id].get("g", 0))
			var st_other := 0
			var ed_other := 0
			for id in res.lines[1 - side]:
				st_other += int(res.lines[1 - side][id].get("st", 0))
				ed_other += int(res.lines[1 - side][id].get("ed", 0))
			reconciled = reconciled and g == int(res.score[side]) and ex == ed_other
			steals_ok = steals_ok and st_other <= to
			any[0] += to
			any[1] += st_other
			any[2] += ex
	r.check(same, "the same game (seed) gives the same lines, every time")
	r.check(reconciled, "goals are the score; every exclusion drawn was committed by a man on the other side")
	r.check(steals_ok, "steals never outnumber the other side's turnovers")
	r.check(any[0] > 0 and any[1] > 0 and any[2] > 0, "simulated games now have turnovers, steals and exclusions (%s)" % [any])
	var m := measure(runner, 12)
	print("  per side, played [to, st, ex, ed]: %s   simulated: %s   top scorer's share: %.2f" % [str(m.played), str(m.simmed), float(m.top_share)])
	var near := func(a: float, b: float) -> bool: return absf(a - b) <= maxf(1.5, b * 0.45)
	r.check(near.call(m.simmed[0], m.played[0]) and near.call(m.simmed[1], m.played[1]), "turnovers and steals at about the played games' rates")
	r.check(float(m.top_share) < 0.42, "a team's goals spread over its shooters (top scorer %.0f%%)" % (float(m.top_share) * 100.0))

extends RefCounted
## Developer probe: their attack (OffenseAI) against each of your defensive formations. For every
## formation, who shoots, from where, which side of the goal he aims at (near post / middle /
## cross-cage, read from where the ball crosses the line against the shooter's own side), how many
## passes the possession made first, and why he shot.
##   godot --headless --path game -- --test offense_probe [possessions] [level]

static func run(runner, n: int, level: float) -> void:
	var teams: Array = runner._teams()
	print("their attack against each of your formations: %d possessions each, CPU level %.2f" % [n, level])
	for f in [-1] + range(DefenseFormation.COUNT):
		var spots := {}
		var aims := {"near": 0, "middle": 0, "cross": 0}
		var whys := {}
		var shooters := {}
		var passes := []
		var shots := 0
		var detail := {}
		var decisions := {}
		var goals := 0
		var memory: Array = []
		for i in n:
			if i % 15 == 0:
				memory = []   # (a match's worth of their possessions share the attack's shot memory: OffenseAI.history)
			var flow := MatchFlow.new(teams[0], teams[1], 12000 + i, MatchState.QUARTER_MIN, level)
			flow.auto_keeper = 0.5
			flow.their_shots = memory
			flow._start_defense(Play.Kind.HALF_COURT)
			var p := flow.play
			if f >= 0:
				p.select_formation(f)
			var t := 0.0
			while not p.over and t < 40.0:
				flow.tick_defense(1.0 / 30.0)
				t += 1.0 / 30.0
				for e in flow.events:
					if String(e.k) != "shot":
						continue
					var sh: Swimmer = null
					for x in p.attackers:
						if x.player == e.by:
							sh = x
					if sh == null or p.ball.shot.is_empty():
						continue
					shots += 1
					var key := "%s@(%.0f,%.0f)" % [sh.tag, sh.pos.x, sh.pos.y]
					spots[key] = int(spots.get(key, 0)) + 1
					shooters[sh.tag] = int(shooters.get(sh.tag, 0)) + 1
					var dy := float(p.ball.shot.get("cross_y", Geo.GOAL_Y)) - Geo.GOAL_Y
					var side := signf(sh.pos.y - Geo.GOAL_Y)
					var aim := "middle"
					if absf(dy) >= 0.4:
						aim = "near" if signf(dy) == side else "cross"
					aims[aim] += 1
					whys[flow.opp_ai.why] = int(whys.get(flow.opp_ai.why, 0)) + 1
					passes.append(flow.opp_ai.passes)
					var own := DefenseFormation.by_tag(p.defenders, sh.tag, true)
					var dk := "%s:%s" % [sh.tag, DefenseFormation.DUTY_NAMES[own.duty] if own != null else "-"]
					if not detail.has(dk):
						detail[dk] = [0, 0.0, 0.0]
					detail[dk][0] += 1
					detail[dk][1] += t
					detail[dk][2] += flow.opp_ai.why_q
				flow.events.clear()
			for k in flow.opp_ai.tally:
				decisions[k] = int(decisions.get(k, 0)) + int(flow.opp_ai.tally[k])
			if String(p.result.get("outcome", "")) == "goal":
				goals += 1
		var top := spots.keys()
		top.sort_custom(func(a, b): return spots[a] > spots[b])
		var tops := []
		for k in top.slice(0, 4):
			tops.append("%s x%d" % [k, spots[k]])
		var avg := 0.0
		for x in passes:
			avg += x
		avg = avg / maxf(1.0, passes.size())
		print("  %-9s shots %3d goals %3d | aim near %d middle %d cross %d | passes before the shot %.1f | shooters %s | why %s | top spots %s" % [
			"(none)" if f < 0 else DefenseFormation.NAMES[f], shots, goals, aims.near, aims.middle, aims.cross, avg, str(shooters), str(whys), ", ".join(tops)])
		var ds := []
		for k in detail:
			ds.append("%s x%d at %.1fs q %.2f" % [k, detail[k][0], detail[k][1] / detail[k][0], detail[k][2] / detail[k][0]])
		print("      shooter:his own defender's duty  " + ", ".join(ds))
		print("      every decision: %s" % str(decisions))

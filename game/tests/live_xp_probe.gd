extends RefCounted
## Base game XP (before class multipliers) per appearance: whole live matches (PlayBot as you,
## the AI as them, as offense_stats plays them) against GameSim between the same two programs.
##   godot --headless --path game -- --test live_xp [matches]

static func report(runner, matches: int = 12) -> void:
	var c := Career.new_game("STAM", "A", "B", 77)
	var ids: Array = c.teams.keys()
	var live := {"field": [], "gk": [], "starter": []}
	var sim := {"field": [], "gk": [], "starter": []}
	var os = load("res://tests/offense_stats.gd").new()
	for i in matches:
		var a: PoloTeam = c.teams[ids[(i * 2) % ids.size()]]
		var b: PoloTeam = c.teams[ids[(i * 2 + 5) % ids.size()]]
		var f := MatchFlow.new(a, b, 5000 + i, MatchState.QUARTER_MIN, Difficulty.MEDIUM)
		os._match(f)
		var box := f.state.box(a, b)
		var won0: bool = box.won
		var mine := Development.lines_of(box.played, {"g": box.goals, "a": box.assists, "st": box.steals + box.keeper_steals,
			"bl": box.blocks, "ed": box.excl_drawn, "to": box.turnovers, "ex": box.excl, "pd": box.pen_drawn}, a.keeper(), int(box.saves), int(box.score[1]))
		var theirs := Development.lines_of(box.them.played, box.them.lists, b.keeper(), int(box.them.saves), int(box.score[0]))
		_add(live, a, mine, won0)
		_add(live, b, theirs, not won0 and box.score[0] != box.score[1])
		var res := GameSim.play(a, b, 6000 + i, false)
		var r := GameSim.result_of(res)
		for side in 2:
			var t: PoloTeam = a if side == 0 else b
			var lines := Development.lines_of(_played(t, res.lines[side]), {"g": res.goals[side], "a": res.assists[side]}, t.keeper(),
				int(res.saves[side]), int(res.score[1 - side]), res.lines[side])
			_add(sim, t, lines, int(res.score[side]) > int(res.score[1 - side]))
	for k in ["starter", "field", "gk"]:
		print("  %-8s live %.1f (n %d)   sim %.1f (n %d)" % [k, _avg(live[k]), live[k].size(), _avg(sim[k]), sim[k].size()])

static func _played(t: PoloTeam, lines: Dictionary) -> Array:
	var out: Array = []
	for id in lines:
		var p := t.find_id(int(id))
		if p != null:
			out.append(p)
	return out

static func _add(into: Dictionary, t: PoloTeam, lines: Dictionary, won: bool) -> void:
	var seven := t.starters()
	for id in lines:
		var p := t.find_id(int(id))
		if p == null:
			continue
		var xp := Development.base_game_xp(p, lines[id], won)
		into["gk" if p.is_keeper() else "field"].append(xp)
		if seven.has(p) and not p.is_keeper():
			into.starter.append(xp)

static func _avg(a: Array) -> float:
	var s := 0.0
	for v in a:
		s += float(v)
	return s / maxf(1, a.size())

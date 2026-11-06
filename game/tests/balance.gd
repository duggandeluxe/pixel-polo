extends RefCounted
## League balance over many seasons: the team ratings' spread and drift, and yours (the autopilot
## signs from the recruiting market: test_runner._autopilot_recruit).
func run(runner, seasons: int) -> void:
	Store.reset_for_tests()
	var c := Career.new_game("WAGN", "Test", "Coach", 4242)
	Game.career = c
	var start := {}
	for id in c.teams:
		start[id] = (c.teams[id] as PoloTeam).rating()
	_print(c, start, "start")
	for s in seasons:
		var label := c.season_label()
		var guard := 0
		while c.season_label() == label and guard < 60:
			guard += 1
			c.queue.clear()
			while c.has_game():
				c.sim_my_game()
			runner._autopilot_recruit(c)
			c.end_week()
			runner._make_cuts(c)
		c.game_over = false
		_print(c, start, label)
		print("      credits %d, signed this year %s" % [c.credits, c.team().roster.filter(func(p): return p.year == 1).map(func(p): return PlayerForm.star_text(p.stars))])
	Game.career = null

func _print(c: Career, start: Dictionary, label: String) -> void:
	var rs: Array = []
	var st: Array = []
	var allp: Array = []
	var dev := 0.0
	for id in c.teams:
		var t: PoloTeam = c.teams[id]
		rs.append(t.rating())
		var s := 0.0
		for p in t.starters():
			s += p.overall()
		st.append(s / 7.0)
		for p in t.roster:
			allp.append(p.overall())
		dev += absf(t.rating() - float(start[id]))
	var mean := func(a: Array) -> float: return a.reduce(func(x, v): return x + v, 0.0) / a.size()
	var m: float = mean.call(rs)
	var sd := 0.0
	for r in rs:
		sd += (r - m) * (r - m)
	sd = sqrt(sd / rs.size())
	rs.sort()
	print("  %s  rating mean %.1f sd %.1f min %.1f max %.1f | starters %.1f | roster %.1f | mean |drift| %.1f | me %.1f" % [label, m, sd, rs[0], rs[rs.size() - 1], mean.call(st), mean.call(allp), dev / c.teams.size(), c.team().rating()])

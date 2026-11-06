extends RefCounted
## Benches never outrank the starters: on every generated team (a new league, and each AI
## program's roster after its freshmen join), no substitute has more CURRENT stars than the
## weakest starter he could replace: in a place the position rules let him play
## (CollegeGen.bench_bar: a backup keeper against the keeper, a 2MD against the posts...).
##   godot --headless --path game -- --test bench

var r

func run(runner) -> void:
	r = runner
	print("bench below the starters")
	Store.reset_for_tests()
	var bad: Array = []
	for seed in 40:
		_check(Career.new_setup(1000 + seed), "new %d" % seed, bad, "")
	r.check(bad.is_empty(), "a new league: no sub above a starter (%d teams, %s)" % [40 * 30, bad.slice(0, 5)])
	bad = []
	var c := Career.new_game("CULA", "A", "B", 77)
	for s in 3:
		var guard := 0
		while guard < 60 and c.phase != "done":
			guard += 1
			c.queue.clear()
			while c.has_game():
				c.sim_my_game()
			for q in c.upgrades_due():
				Development.ai_spend(q)
			c.end_week()
		c.queue.clear()
		c.end_week()   # (NEXT SEASON: the transition, the AI programs' freshmen in)
		runner._make_cuts(c)
		_check(c, "season %d" % (s + 2), bad, c.school)
	r.check(bad.is_empty(), "every season's new AI rosters: no sub above a starter (%s)" % [bad.slice(0, 5)])

## Every team in `c` (but `skip`, your own: your lineup is yours to set).
func _check(c: Career, label: String, bad: Array, skip: String) -> void:
	for id in c.teams:
		if id == skip:
			continue
		var t: PoloTeam = c.teams[id]
		var seven: Array = t.starters()
		for p: PoloPlayer in t.roster:
			if p in seven:
				continue
			# the weakest starter he could stand in for: in a place the position rules let him
			# play (CollegeGen.bench_bar, PoloTeam.fits)
			var low := CollegeGen.bench_bar(p, seven)
			if p.stars > low + 0.001:
				bad.append("%s %s %s %.1f* (starters' low %.1f)" % [label, id, p.pos_text(), p.stars, low])

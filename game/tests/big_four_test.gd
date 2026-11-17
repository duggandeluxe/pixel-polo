extends RefCounted
## THE BIG FOUR: the Los Angeles Bears (CULA), Los Angeles Spartans (CUSC), Pacific Grove Redwoods
## (STAM) and Bayview Golden Grizzlies (ALC) keep their Top 4 places unless an outside school
## beats them (Poll.protect_big_four).
##   godot --headless --path game -- --test big_four

var r   # the test runner

## A week of games: [home, away, home won].
func _week(games: Array) -> Dictionary:
	var out: Array = []
	for g in games:
		out.append({"h": g[0], "a": g[1], "r": {"w": 0 if g[2] else 1, "s": [5, 4] if g[2] else [4, 5]}})
	return {"kind": "week", "games": out}

func _top4(ids: Array) -> Array:
	var t: Array = ids.slice(0, 4)
	t.sort()
	return t

func _sorted(a: Array) -> Array:
	var t := a.duplicate()
	t.sort()
	return t

func run(runner) -> void:
	r = runner
	print("big four")
	var big := _sorted(Poll.BIG_FOUR)
	# the normal order with outside schools on top: the score alone never moves the Big Four out
	var normal := ["FORDU", "HURST", "LBSC", "PRIN", "CULA", "CUSC", "STAM", "ALC", "SJCU", "ICU"]
	var none := Poll.protect_big_four(normal, [], -1)
	r.check(_top4(none) == big, "C: a better record or score alone never takes a Big Four place (%s)" % str(none.slice(0, 4)))
	r.check(none.slice(0, 4) == ["CULA", "CUSC", "STAM", "ALC"] and none.slice(4, 8) == ["FORDU", "HURST", "LBSC", "PRIN"], "...the Top 4 and the rest keep the normal order")
	# A: losses among themselves
	var rounds := [_week([["CUSC", "CULA", true], ["ALC", "STAM", true]]), _week([["STAM", "CUSC", true], ["ALC", "CULA", true]])]
	var a := Poll.protect_big_four(["FORDU", "ALC", "STAM", "CUSC", "LBSC", "CULA", "HURST"], rounds, 1)
	r.check(_top4(a) == big and a.slice(0, 4) == ["ALC", "STAM", "CUSC", "CULA"], "A: losses to each other keep all four in the Top 4, reordered (%s)" % str(a.slice(0, 4)))
	# B: the #12 school beats the Bears: it takes their place, the other three stay
	var ranked := ["CUSC", "STAM", "ALC", "FORDU", "LBSC", "PRIN", "SJCU", "ICU", "UCDS", "CRBU", "LMMU", "HURST", "CULA"]
	rounds = [_week([["HURST", "CULA", true]])]
	var b := Poll.protect_big_four(ranked, rounds, 0)
	r.check(_top4(b) == _sorted(["CUSC", "STAM", "ALC", "HURST"]) and Poll._order_map(b).CULA > 4, "B: HURST beat the Bears and replaces them; the Bears drop (%s)" % str(b.slice(0, 5)))
	r.check(not "FORDU" in b.slice(0, 4), "B: ...FORDU, ranked higher but with no Big Four win, still can't get in")
	# the Bears return through the normal order when they outrank the giant killer
	var back := Poll.protect_big_four(["CULA", "FORDU", "CUSC", "HURST", "STAM", "ALC"], rounds, 0)
	r.check(back.slice(0, 4) == ["CULA", "CUSC", "STAM", "ALC"], "dynamic: the beaten Bears can win their place back on the normal order (%s)" % str(back.slice(0, 4)))
	# the replacement isn't protected: another giant killer ranked above it takes the open place
	rounds = [_week([["HURST", "CULA", true], ["LBSC", "CULA", true]])]
	var two := Poll.protect_big_four(["LBSC", "CUSC", "STAM", "ALC", "HURST", "CULA"], rounds, 0)
	r.check(_top4(two) == _sorted(["LBSC", "CUSC", "STAM", "ALC"]), "dynamic: replacements are ranked normally, never protected (%s)" % str(two.slice(0, 4)))
	# a result not yet played (upto) doesn't count
	var early := Poll.protect_big_four(ranked, [_week([]), _week([["HURST", "CULA", true]])], 0)
	r.check(_top4(early) == big, "only the games up to the poll's week count")
	# a real career: the preseason and every published poll keep the unbeaten Big Four in the Top 4
	Store.reset_for_tests()
	var c := Career.new_game("WAGN", "A", "B", 12)
	c.queue.clear()
	r.check(_top4(Poll.latest(c).ranks) == big, "the preseason poll's Top 4 is the Big Four")
	var board = load("res://tests/standings_board_test.gd")
	var guard := 0
	while not c.in_offseason() and guard < 40:   # the whole season, NCSA final included
		guard += 1
		board._week(c)
	var ok := true
	for p in c.season.polls:
		var lost: Array = []
		var res := Poll.results(c.schedule, int(p.wk))
		for id in Poll.BIG_FOUR:
			if (res.get(id, []) as Array).any(func(e): return not e.won and not e.o in Poll.BIG_FOUR):
				lost.append(id)
		for id in Poll.BIG_FOUR:
			if not id in lost and Poll.rank_in(p, id) > 4:
				ok = false
	r.check(ok and c.season.polls.size() > 10, "every poll of a whole season (%d) keeps each Big Four team no outsider has beaten in the Top 4" % c.season.polls.size())

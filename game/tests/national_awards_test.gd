extends RefCounted
## The National Awards (NationalAwards): a whole season played, its honours checked.
##   godot --headless --path game -- --test national_awards

var r

func run(runner) -> void:
	r = runner
	print("national awards")
	Store.reset_for_tests()
	var c := Career.new_game("BUCK", "A", "B", 71)
	var label := c.season_label()
	var guard := 0
	var early := false
	while c.phase == "season" and guard < 80:
		guard += 1
		c.queue.clear()
		for q in c.upgrades_due():
			Development.ai_spend(q)
		while c.has_game():
			c.sim_my_game()
			for q in c.upgrades_due():
				Development.ai_spend(q)
		if c.week < c.schedule.size() - 1:
			early = early or c.awards.any(func(a): return String(a.year) == label and a.has("pid"))
		c.end_week()
	r.check(not early, "16: nothing given before the NCSA final")
	var recs: Array = c.awards.filter(func(a): return String(a.year) == label and a.has("pid"))
	var by := func(k: String) -> Array: return recs.filter(func(a): return String(a.award) == k)
	var find := func(pid: int) -> PoloPlayer:
		for id in c.teams:
			var q := (c.teams[id] as PoloTeam).find_id(pid)
			if q != null:
				return q
		return null
	r.check(by.call("poy").size() == 1 and by.call("dpoy").size() == 1 and by.call("foy").size() == 1, "1: POY, DPOY and FOY, one each")
	var majors := [by.call("poy")[0].pid, by.call("dpoy")[0].pid, by.call("foy")[0].pid]
	r.check(majors[0] != majors[1] and majors[1] != majors[2] and majors[0] != majors[2], "11: three different men")
	var fr: PoloPlayer = find.call(int(majors[2]))
	r.check(fr != null and fr.year == 1, "8: Freshman of the Year a freshman")
	# Golden Arm / Iron Wall: the totals, everyone's
	var most_g := 0
	var most_sv := 0
	for id in c.teams:
		for q: PoloPlayer in (c.teams[id] as PoloTeam).roster:
			most_g = maxi(most_g, q.stat("g"))
			if q.is_keeper():
				most_sv = maxi(most_sv, q.stat("sv"))
	r.check(by.call("arm").size() >= 1 and by.call("arm").all(func(a): return int(a.line.g) == most_g), "9: Golden Arm the most goals (%d), every tied leader" % most_g)
	r.check(by.call("wall").size() >= 1 and by.call("wall").all(func(a): return int(a.line.sv) == most_sv and int(a.pos) == PoloPlayer.Pos.GK), "10: Iron Wall the most saves (%d), a keeper" % most_sv)
	# All-NCSA: seven each, the lineup's places, nobody twice
	for key in ["first", "second"]:
		var team: Array = by.call(key)
		var slots: Array = team.map(func(a): return String(a.slot))
		slots.sort()
		r.check(team.size() == 7 and slots == ["2MD", "ATK", "ATK", "C", "GK", "WG", "WG"], "12/13: %s: C, 2MD, two ATK, two WG, GK (%s)" % [key, str(slots)])
		var legal := true
		for a in team:
			var q: PoloPlayer = find.call(int(a.pid))
			var place: int = int(NationalAwards.TEAM_PLACES.filter(func(pl): return NationalAwards.PLACE_NAMES[pl] == String(a.slot))[0])
			legal = legal and q != null and (PoloTeam.fit_rank(q, place) <= 1 or (String(a.slot) in ["ATK", "WG"] and (PoloTeam.fit_rank(q, 3) <= 1 or PoloTeam.fit_rank(q, 2) <= 1 or PoloTeam.fit_rank(q, 5) <= 1 or PoloTeam.fit_rank(q, 6) <= 1)))
		r.check(legal, "12: every pick plays a place he may legally play")
	var firsts: Array = by.call("first").map(func(a): return int(a.pid))
	r.check(by.call("second").all(func(a): return not int(a.pid) in firsts), "13: nobody on both teams")
	# once, saved, not given again
	var n := c.awards.size()
	NationalAwards.run(c)
	var back := Career.from_dict(JSON.parse_string(JSON.stringify(c.to_dict())))
	r.check(c.awards.size() == n and back.awards.size() == n and label in back.national_done, "16: given once a season; loading never gives them again")
	r.check(NationalAwards.earned_year("2026-27") == 2027, "17: a 2026-27 honour is earned in 2027")
	# DPOY: an extraordinary field defender can beat the keepers; an ordinary one can't
	var ks: Array = []
	var fs: Array = []
	# (a league's worth: 30 keepers, 200 field players, as in the game)
	for i in 30:
		var k := AttrBench.player({}, true)
		k.id = 9000 + i
		k.stats = {"gp": 20, "sv": 100 + i * 2, "ga": 160}
		ks.append({"p": k, "team": "X"})
	for i in 200:
		var f := AttrBench.player({}, false, {}, PoloPlayer.Pos.DEFENDER)
		f.id = 10000 + i
		f.stats = {"gp": 20, "st": 2 + i % 5, "bl": 3 + i % 7}
		fs.append({"p": f, "team": "X"})
	var star := AttrBench.player({}, false, {}, PoloPlayer.Pos.DEFENDER)
	star.id = 9999
	star.stats = {"gp": 20, "st": 41, "bl": 29}
	var normal := NationalAwards.def_values(ks + fs)
	var best_f: float = fs.map(func(e): return float(normal[e.p.id])).max()
	var best_k: float = ks.map(func(e): return float(normal[e.p.id])).max()
	r.check(best_k > best_f, "5: ordinary field defenders don't beat a strong keeper")
	var with_star := NationalAwards.def_values(ks + fs + [{"p": star, "team": "X"}])
	r.check(float(with_star[9999]) > ks.map(func(e): return float(with_star[e.p.id])).max(), "5: a 2MD with 41 steals and 29 blocks beats every keeper")
	r.check(str(NationalAwards.def_values(ks + fs)) == str(normal), "40: deterministic")

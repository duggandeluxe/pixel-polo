extends RefCounted
## The Conference Accolades, Tournament Awards & Player Transfer update: POTW over OPOTW, a
## goalkeepers-only DPOTW, accolades named for the conference they were won in (and kept through
## a move), All-Tournament awards from every tournament game's totals (each tournament its own),
## and players cut in the off-season signed by AI programs as themselves.
##   godot --headless --path game -- --test accolades
## Fixed seeds throughout.

var r
var Player = load("res://src/ui/screens/player.gd")

func run(runner) -> void:
	r = runner
	print("accolades: weekly")
	Store.reset_for_tests()
	_weekly_rules()
	print("accolades: by conference")
	_by_conference()
	print("accolades: a season (weekly, tournaments, transfers)")
	await _season(runner)

func _lab(vals: Dictionary, pos: int, year := 2, keeper := false) -> PoloPlayer:
	var p := AttrBench.player(vals, keeper, {}, pos)
	p.year = year
	return p

# ------------------------------------------------------------------ 2, 3: the weekly rules
func _weekly_rules() -> void:
	var a := _lab({}, PoloPlayer.Pos.DRIVER)
	a.id = 1
	var b := _lab({}, PoloPlayer.Pos.DRIVER)
	b.id = 2
	var k := _lab({}, PoloPlayer.Pos.GK, 2, true)
	k.id = 3
	var d := _lab({}, PoloPlayer.Pos.DEFENDER)
	d.id = 4
	var lines := [{"p": a, "team": "X", "line": {"gp": 1, "g": 9, "a": 4, "st": 2}},
		{"p": b, "team": "X", "line": {"gp": 1, "g": 5, "a": 2, "st": 1}},
		{"p": k, "team": "Y", "line": {"gp": 1, "sv": 14, "ga": 6, "st": 1}},
		{"p": d, "team": "Y", "line": {"gp": 1, "st": 6, "bl": 5}}]
	var potw := ConfAwards._best(lines, "potw")
	var opotw := ConfAwards._best(lines.filter(func(e): return e.p != potw.p), "opotw")
	r.check(potw.p == a and opotw.p == b, "2: Player A (9 G, 4 A, 2 ST) is POTW, Player B (5 G, 2 A, 1 ST) OPOTW")
	r.check(ConfAwards.score(a, lines[0].line, "potw") > ConfAwards.score(b, lines[1].line, "potw"), "2: POTW outranks OPOTW on the shared overall score")
	var dp := ConfAwards._best(lines, "dpotw")
	r.check(dp.p == k, "3: DPOTW is the goalkeeper's, the field player's 6 steals and 5 blocks notwithstanding")
	r.check(ConfAwards.score(d, lines[3].line, "dpotw") == 0.0 and ConfAwards.score(d, lines[3].line, "dpot") > 0.0,
		"3: a field player can't win the weekly DPOTW, but can the tournament's")
	var no_gk := ConfAwards._best(lines.filter(func(e): return not (e.p as PoloPlayer).is_keeper()), "dpotw")
	r.check(no_gk.is_empty(), "3: no keeper with a real week: DPOTW unawarded (nothing made up)")

# ------------------------------------------------------------------ 4-6: conference-specific accolades
func _by_conference() -> void:
	var c := Career.new()
	var rec := func(conf: String, cat: String, wk: int) -> Dictionary:
		return {"year": 2026, "season": "2026-27", "week": wk, "label": "WEEK %d" % (wk + 1), "conf": conf, "cat": cat, "pid": 77,
			"team": "OLD", "name": "TEST PLAYER", "pos": PoloPlayer.Pos.DRIVER, "cls": 1, "stars": 3.0, "line": {}, "score": 10.0}
	c.conf_awards = [rec.call("WCC", "rotw", 1), rec.call("WCC", "opotw", 2), rec.call("WCC", "opotw", 4), rec.call("NWPC", "potw", 20), rec.call("NWPC", "opotw", 21)]
	var acc: Array = Player.accolades(c, 77)
	var full: Array = acc.map(func(e): return "%dx %s" % [int(e[0]), String(e[1])])
	r.check(full == ["1x WWPC ROOKIE OF THE WEEK (2027)", "2x WWPC OFFENSIVE PLAYER OF THE WEEK (2027)", "1x NCC PLAYER OF THE WEEK (2027)", "1x NCC OFFENSIVE PLAYER OF THE WEEK (2027)"],
		"4-6: named for the conference they were won in, the same award combined, different conferences apart (%s)" % str(full))
	r.check(acc.map(func(e): return String(e[2])) == ["WWPC ROTW (2027)", "WWPC OPOTW (2027)", "NCC POTW (2027)", "NCC OPOTW (2027)"], "28: short forms keep the conference too")
	c.tourney_awards = [{"year": 2026, "season": "2026-27", "tid": "conf:WCC", "conf": "WCC", "cat": "opot", "pid": 77, "team": "OLD",
		"name": "TEST PLAYER", "pos": PoloPlayer.Pos.DRIVER, "cls": 1, "stars": 3.0, "line": {"gp": 3, "g": 12, "a": 6, "st": 5}, "score": 30.0},
		{"year": 2027, "season": "2027-28", "tid": "nat", "conf": "", "cat": "pot", "pid": 77, "team": "NEW",
		"name": "TEST PLAYER", "pos": PoloPlayer.Pos.DRIVER, "cls": 2, "stars": 3.5, "line": {"gp": 4, "g": 10}, "score": 25.0}]
	var acc2: Array = Player.accolades(c, 77).map(func(e): return "%dx %s" % [int(e[0]), String(e[1])])
	r.check(acc2.slice(4) == ["1x ALL-WWPC OFFENSIVE PLAYER OF THE TOURNAMENT (2027)", "1x ALL-NCSA PLAYER OF THE TOURNAMENT (2028)"],
		"28: All-WWPC and All-NCSA honours after the weekly ones (%s)" % str(acc2.slice(4)))
	r.check(TourneyAwards.line_text(c.tourney_awards[0]) == "3 GAMES | 12 GOALS | 6 ASSISTS | 5 STEALS", "27: the totals that won it: %s" % TourneyAwards.line_text(c.tourney_awards[0]))

# ------------------------------------------------------------------ a whole season
func _season(runner) -> void:
	var c := Career.new_game("BUCK", "A", "B", 83)
	Game.career = c
	var before := {}       # pid -> season stats as the conference tournament begins
	var before_nat := {}
	var mid_ok := true
	var reloaded := false
	var guard := 0
	while c.phase == "season" and guard < 200:
		guard += 1
		c.queue.clear()
		for q in c.upgrades_due():
			Development.ai_spend(q)
		if c.week < c.schedule.size():
			var kind := String(c.schedule[c.week].kind)
			if kind == "conf_qf" and before.is_empty():
				before = _snap(c)
			if kind == "nat_r1" and before_nat.is_empty():
				before_nat = _snap(c)
			if kind == "conf_semi" and not reloaded:
				# a save and load in the middle of a tournament: nothing counted twice, nothing lost
				reloaded = true
				var keep_stats := JSON.stringify(c.tourney_stats)
				c = Career.from_dict(JSON.parse_string(JSON.stringify(c.to_dict())))
				Game.career = c
				mid_ok = JSON.stringify(c.tourney_stats) == keep_stats and c.tourney_awards.all(func(a): return bool(a.get("hist", false)))
		if c.has_game():
			c.sim_my_game()
			continue
		c.end_week()
	r.check(reloaded and mid_ok, "35.10: a career saved and loaded mid-tournament: its totals as they were, no awards yet")
	# the weekly awards of a whole season
	var weeks := {}
	for a in c.conf_awards.filter(func(x): return not bool(x.get("hist", false))):   # (this dynasty's weeks: Legacy's carry no lines)
		var k := "%d:%d:%s" % [a.year, a.week, a.conf]
		if not weeks.has(k):
			weeks[k] = {}
		weeks[k][a.cat] = a
	var distinct := true
	var outranks := true
	var gk_only := true
	var fresh := true
	for k in weeks:
		var w: Dictionary = weeks[k]
		if w.has("potw") and w.has("opotw"):
			distinct = distinct and int(w.potw.pid) != int(w.opotw.pid)
			var pp := ConfAwards.player_of(c, w.potw)
			var op := ConfAwards.player_of(c, w.opotw)
			outranks = outranks and ConfAwards.score(pp, w.potw.line, "potw") >= ConfAwards.score(op, w.opotw.line, "potw") - 0.001
		if w.has("dpotw"):
			gk_only = gk_only and int(w.dpotw.pos) == PoloPlayer.Pos.GK
		if w.has("rotw"):
			fresh = fresh and int(w.rotw.cls) == 1
	r.check(distinct, "32.4: POTW and OPOTW never the same man in a conference's week (%d weeks)" % weeks.size())
	r.check(outranks, "32.3: POTW always outranks OPOTW on the overall score")
	r.check(gk_only, "32.5: every DPOTW of the season a goalkeeper")
	r.check(fresh, "32.6: every ROTW a freshman")
	# the tournaments
	var live := c.tourney_awards.filter(func(a): return not bool(a.get("hist", false)))   # (Legacy's past seasons apart)
	var conf_recs := live.filter(func(a): return String(a.tid).begins_with("conf:"))
	var nat_recs := live.filter(func(a): return String(a.tid) == "nat")
	var tids := {}
	for a in conf_recs:
		tids[a.tid] = int(tids.get(a.tid, 0)) + 1
	r.check(tids.size() == Colleges.conf_ids_of(c.teams).size() and tids.values().all(func(n): return n == 3),
		"23: every conference tournament names its three (%s)" % str(tids))
	r.check(nat_recs.size() == 3, "26: the NCSA names its three (%d)" % nat_recs.size())
	var once := true
	for tid in tids:
		var cats := conf_recs.filter(func(a): return a.tid == tid).map(func(a): return a.cat)
		once = once and cats.has("pot") and cats.has("opot") and cats.has("dpot")
		var pot = conf_recs.filter(func(a): return a.tid == tid and a.cat == "pot")[0]
		var opot = conf_recs.filter(func(a): return a.tid == tid and a.cat == "opot")[0]
		once = once and int(pot.pid) != int(opot.pid)
	r.check(once, "23: one of each, the Player and the Offensive Player different men")
	# their totals are their tournament's games, every round, and only those
	var after_conf := before_nat
	var sums_ok := true
	for a in conf_recs:
		sums_ok = sums_ok and _delta_ok(a, before, after_conf)
	r.check(sums_ok, "19/21: each conference winner's totals are every round he played in it (QF, SF, final), no regular season")
	var nat_ok := true
	var end := _snap(c)
	for a in nat_recs:
		nat_ok = nat_ok and _delta_ok(a, before_nat, end)
	r.check(nat_ok, "22: the NCSA's winners: national tournament games only")
	r.check(conf_recs.all(func(a): return String(TourneyAwards.prefix(a.tid)) == "ALL-" + Colleges.conf_abbr(String(a.conf))) \
		and TourneyAwards.prefix("conf:WCC") == "ALL-WWPC" and TourneyAwards.prefix("nat") == "ALL-NCSA", "25/26: ALL-PEC .. ALL-WWPC .. ALL-NCSA")
	var acc_pid: int = int(conf_recs[0].pid)
	r.check(Player.accolades(c, acc_pid).any(func(e): return String(e[1]).begins_with(TourneyAwards.prefix(conf_recs[0].tid))),
		"28: the winner's Career Accolades carry it")
	# saved and loaded after: the same awards, never decided again
	var back := Career.from_dict(JSON.parse_string(JSON.stringify(c.to_dict())))
	r.check(back.tourney_awards.size() == c.tourney_awards.size() and back.tourney_done == c.tourney_done, "35.10: loading never decides a tournament again")
	# ------------------------------------------------------------------ the off-season: cuts, the pool, pickups
	c.queue.clear()
	var me := c.team()
	var star_cut := _cut_candidate(c, me)    # a promising young player you'll have to cut
	var star_awards: Array = Player.accolades(c, star_cut.id)
	var keep := [star_cut.id, star_cut.attrs.duplicate(), star_cut.attr_pot.duplicate(), star_cut.xp_level, star_cut.xp, star_cut.xp_start,
		star_cut.totals.duplicate(true), star_cut.first, star_cut.last, star_cut.lefty, star_cut.pos]
	# over the cap: signings (incoming freshmen) the roster can't hold
	var rng := RandomNumberGenerator.new()
	rng.seed = 501
	for i in 4:
		var q := CollegeGen.make_player(rng, PoloPlayer.Pos.DRIVER, 60.0, 1, {})
		q.id = c.new_id()
		c.incoming.append({"p": q})
	c.end_week()   # (the transition: seniors out, everyone a year older, your signings in)
	r.check(c.phase == "cuts", "34: over the cap: the cuts are yours to make")
	var year_now := star_cut.year
	var cut_ids: Array = []
	while not Offseason.roster_legal(c):
		var victim: PoloPlayer = star_cut if Offseason.cut_block(c, star_cut) == "" and not star_cut.id in cut_ids else null
		if victim == null:
			var can: Array = me.roster.filter(func(p: PoloPlayer): return Offseason.cut_block(c, p) == "")
			can.sort_custom(func(a: PoloPlayer, b: PoloPlayer): return a.overall() < b.overall())
			victim = can[0]
		cut_ids.append(victim.id)
		Offseason.cut(c, victim)
	r.check(c.cut_pool.size() == cut_ids.size(), "34.1: every cut player in the pool (%d)" % cut_ids.size())
	var pool_players: Array = c.cut_pool.map(func(e): return e.p)
	Offseason.finish_cuts(c)
	# where everybody is now
	var where := {}
	var dupes := false
	var over := false
	for id in c.teams:
		var t: PoloTeam = c.teams[id]
		over = over or t.roster.size() > c.roster_cap(id)
		for p: PoloPlayer in t.roster:
			if where.has(p.id):
				dupes = true
			where[p.id] = id
	var signed := pool_players.filter(func(p): return where.has((p as PoloPlayer).id))
	print("    cut %d, signed elsewhere %d: %s" % [pool_players.size(), signed.size(), str(signed.map(func(p): return "%s %s* -> %s" % [p.short_name(), p.stars, where[p.id]]))])
	r.check(not dupes and not over, "34.4/12/13: every player on one roster at most, no program over its cap")
	r.check(signed.all(func(p): return where[(p as PoloPlayer).id] != c.school), "34: they sign with other programs (the AI's), never back with you")
	r.check(c.cut_pool.is_empty(), "34: the pool is emptied once the rosters are set")
	if where.has(star_cut.id):
		var now := [star_cut.id, star_cut.attrs, star_cut.attr_pot, star_cut.xp_level, star_cut.xp, star_cut.xp_start, star_cut.totals,
			star_cut.first, star_cut.last, star_cut.lefty, star_cut.pos]
		r.check(str(now) == str(keep) and star_cut.year == year_now, "34.5-9: the same player: id, attributes, ceilings, XP, career totals, name, hand, position, class year")
		r.check(Player.accolades(c, star_cut.id) == star_awards, "34.10/11 / 33.6: his accolades exactly as they were (%d lines)" % star_awards.size())
		var t: PoloTeam = c.teams[where[star_cut.id]]
		r.check(t.find_id(star_cut.id) == star_cut, "16: scouting his new team finds him, history and all")
	else:
		r.check(true, "34.3: (he wasn't signed this time: not guaranteed)")
	# the value a program puts on a player: need, quality, youth
	var t0: PoloTeam = c.teams[c.teams.keys().filter(func(id): return id != c.school)[0]]
	var cen := _lab({"str": 7.0, "sho": 6.0, "pas": 5.0, "dfn": 5.0}, PoloPlayer.Pos.CENTER, 2)
	var no_c := t0.roster.filter(func(p: PoloPlayer): return p.pos != PoloPlayer.Pos.CENTER)
	var full_c := t0.roster.duplicate()
	t0.roster.assign(no_c)
	var need_v := Offseason.pickup_value(c, t0, cen)
	t0.roster.assign(full_c)
	for i in 3:
		var extra := _lab({"str": 8.0, "sho": 8.0, "pas": 7.0, "dfn": 7.0}, PoloPlayer.Pos.CENTER, 2)
		t0.roster.append(extra)
	var crowded_v := Offseason.pickup_value(c, t0, cen)
	t0.roster.assign(full_c)
	r.check(need_v > crowded_v, "10: a program with no centre wants a centre more than one with three better ones (%.2f > %.2f)" % [need_v, crowded_v])
	var weak_sr := _lab({"str": 2.0, "sho": 2.0, "pas": 2.0, "dfn": 2.0}, PoloPlayer.Pos.DRIVER, 4)
	weak_sr.attr_pot = weak_sr.attrs.duplicate()
	Attributes.sync(weak_sr)
	r.check(Offseason.pickup_value(c, t0, weak_sr) < Offseason.pickup_value(c, t0, cen), "11: a weak senior with no room is worth less than a young centre")
	Game.career = null

## Every player's season stats now: {pid: {g, a, st, bl, sv, ga, gp}}.
func _snap(c: Career) -> Dictionary:
	var out := {}
	for id in c.teams:
		for p: PoloPlayer in (c.teams[id] as PoloTeam).roster:
			out[p.id] = {"g": p.stat("g"), "a": p.stat("a"), "st": p.stat("st"), "bl": p.stat("bl"), "sv": p.stat("sv"), "gp": p.stat("gp")}
	return out

## A tournament award's totals against his season stats from `from` to `to`.
func _delta_ok(a: Dictionary, from: Dictionary, to: Dictionary) -> bool:
	var pid := int(a.pid)
	if not from.has(pid) or not to.has(pid):
		return false
	for k in ["g", "a", "st", "bl", "sv", "gp"]:
		if int(to[pid][k]) - int(from[pid][k]) != int((a.line as Dictionary).get(k, 0)):
			return false
	return true

## A young player of yours worth something to somebody: the best returning non-senior.
func _cut_candidate(c: Career, t: PoloTeam) -> PoloPlayer:
	var can: Array = t.roster.filter(func(p: PoloPlayer): return p.year <= 2 and not p.is_keeper())
	can.sort_custom(func(a: PoloPlayer, b: PoloPlayer): return a.stars > b.stars)
	return can[0] if not can.is_empty() else t.roster[1]

extends RefCounted
## THE GENERATED PLAYER LEGACY (Legacy): a new dynasty's three past seasons of awards. Numbered by
## the spec's REQUIRED TESTING (1-36).
##   godot --headless --path game -- --test legacy

var r

func run(runner) -> void:
	r = runner
	print("generated player legacy")
	Store.reset_for_tests()
	var t0 := Time.get_ticks_msec()
	var c := Career.new_game("SJCU", "A", "B", 81)
	print("    a new career with its history: %d ms" % (Time.get_ticks_msec() - t0))
	_eligibility(c)
	_integrity(c)
	_rarity(c)
	_saves(c)
	await _screens(c)
	Game.career = null
	Game.goto("title")
	await r.get_tree().process_frame

func _hist(list: Array) -> Array:
	return list.filter(func(a): return bool(a.get("hist", false)))

## Every player now (pid -> player).
func _players(c: Career) -> Dictionary:
	var out := {}
	for id in c.teams:
		for p in (c.teams[id] as PoloTeam).roster:
			out[p.id] = p
	return out

## An award's season start year ("2025-26" -> 2025).
func _start(season: String) -> int:
	return int(season.get_slice("-", 0))

func _eligibility(c: Career) -> void:
	var ps := _players(c)
	var all: Array = _hist(c.conf_awards) + _hist(c.tourney_awards) + _hist(c.awards)
	r.check(not all.is_empty() and c.legacy.size() == 3, "three past seasons written (%d records)" % all.size())
	var seasons: Array = c.legacy.map(func(e): return String(e.season))
	r.check(seasons == ["%d-%02d" % [c.year - 3, (c.year - 2) % 100], "%d-%02d" % [c.year - 2, (c.year - 1) % 100], "%d-%02d" % [c.year - 1, c.year % 100]],
		"6: the three seasons before %s (%s)" % [c.season_label(), str(seasons)])
	var ok := true
	var fresh_clean := true
	for a in all:
		var season := String(a.get("season", a.get("year", "")))
		var k := c.year - _start(season)
		var pid := int(a.pid)
		if ps.has(pid):
			var p: PoloPlayer = ps[pid]
			var cls := p.year - k
			ok = ok and cls >= 1 and cls <= 4
			fresh_clean = fresh_clean and p.year > 1
	r.check(fresh_clean, "1: today's freshmen have no college awards")
	r.check(ok, "2-5: every current player's award is from a season he was in college (class 1-4 then)")
	r.check(all.all(func(a): return c.year - _start(String(a.get("season", a.get("year", "")))) >= 1), "5: none dated after the dynasty began")

func _integrity(c: Career) -> void:
	var weekly := _hist(c.conf_awards)
	var confs: Array = Colleges.SCHOOLS.map(func(s): return String(s.conf))
	r.check(weekly.all(func(a): return String(a.conf) in confs and int(a.week) >= 0 and String(a.label) == "WEEK %d" % (int(a.week) + 1)), "7: valid conferences and weeks")
	var ps := _players(c)
	r.check(weekly.filter(func(a): return a.cat == "dpotw").all(func(a): return int(a.pos) == PoloPlayer.Pos.GK), "8: DPOTW keepers only")
	r.check(weekly.filter(func(a): return a.cat == "rotw").all(func(a): return int(a.cls) == 1), "9: ROTW freshmen then")
	var per_week := {}
	var slots := {}
	var dup := false
	for a in weekly:
		var kw := "%s|%d|%d" % [a.season, int(a.week), int(a.pid)]
		var ks := "%s|%d|%s|%s" % [a.season, int(a.week), a.conf, a.cat]
		dup = dup or per_week.has(kw) or slots.has(ks)
		per_week[kw] = true
		slots[ks] = true
	r.check(not dup, "10: one weekly award a man a week; each conference's award once a week")
	var nat := _hist(c.awards)
	var uniq := true
	var majors_ok := true
	for e in c.legacy:
		var s := String(e.season)
		for key in ["poy", "dpoy", "foy"]:
			uniq = uniq and nat.filter(func(a): return a.year == s and a.award == key).size() <= 1
		var m: Array = nat.filter(func(a): return a.year == s and a.award in ["poy", "dpoy", "foy"]).map(func(a): return int(a.pid))
		majors_ok = majors_ok and m.size() == _uniq(m).size()
		var first: Array = nat.filter(func(a): return a.year == s and a.award == "first")
		var second: Array = nat.filter(func(a): return a.year == s and a.award == "second")
		r.check(_slots(first) == ["2MD", "ATK", "ATK", "C", "GK", "WG", "WG"] and _slots(second) == ["2MD", "ATK", "ATK", "C", "GK", "WG", "WG"],
			"14: %s All-NCSA teams: the seven places" % s)
		var fp: Array = first.map(func(a): return int(a.pid))
		r.check(second.all(func(a): return not int(a.pid) in fp), "15: %s nobody on both teams" % s)
		r.check(nat.filter(func(a): return a.year == s and a.award == "wall").all(func(a): return int(a.pos) == PoloPlayer.Pos.GK), "Iron Wall a keeper")
	r.check(uniq and majors_ok, "11: one POY, DPOY, FOY a season, three different men")
	var dpoy_gk := nat.filter(func(a): return a.award == "dpoy" and int(a.pos) == PoloPlayer.Pos.GK).size()
	r.check(dpoy_gk >= 2, "12: DPOY usually a keeper (%d of 3)" % dpoy_gk)
	var champs_ok := true
	for e in c.legacy:
		champs_ok = champs_ok and (e.conf as Dictionary).size() == 5 and c.teams.has(String(e.nat))
		for cf in e.conf:
			champs_ok = champs_ok and String((c.teams[String(e.conf[cf])] as PoloTeam).conf) == String(cf)
	r.check(champs_ok, "16: each season one champion a conference (its own school) and one NCSA champion")
	var pot_ok := true
	for e in c.legacy:
		for cf in e.conf:
			var pot: Array = _hist(c.tourney_awards).filter(func(a): return a.season == e.season and a.tid == "conf:" + cf and a.cat == "pot")
			pot_ok = pot_ok and pot.size() == 1 and String(pot[0].team) == String(e.conf[cf])
	r.check(pot_ok, "16: each tournament's Player of the Tournament from its champion")

func _slots(t: Array) -> Array:
	var x: Array = t.map(func(a): return String(a.slot))
	x.sort()
	return x

func _uniq(a: Array) -> Array:
	var out: Array = []
	for x in a:
		if not x in out:
			out.append(x)
	return out

func _rarity(c: Career) -> void:
	var ps := _players(c)
	var by := {}
	for a in _hist(c.conf_awards) + _hist(c.tourney_awards) + _hist(c.awards):
		var pid := int(a.pid)
		if not ps.has(pid):
			continue
		if not by.has(pid):
			by[pid] = {"weekly": 0, "tourney": 0, "major": 0, "allncsa": 0}
		var kind := "weekly" if a.has("week") else ("tourney" if a.has("tid") else ("allncsa" if String(a.award) in ["first", "second"] else "major"))
		by[pid][kind] += 1
	var upper: Array = ps.values().filter(func(p: PoloPlayer): return p.year >= 2)
	var none := upper.filter(func(p: PoloPlayer): return not by.has(p.id)).size()
	var major := upper.filter(func(p: PoloPlayer): return by.has(p.id) and int(by[p.id].major) > 0).size()
	var allncsa := upper.filter(func(p: PoloPlayer): return by.has(p.id) and int(by[p.id].allncsa) > 0).size()
	print("    upperclassmen %d: no awards %d (%.0f%%), a major national award %d (%.1f%%), All-NCSA %d" % [upper.size(), none, 100.0 * none / upper.size(), major, 100.0 * major / upper.size(), allncsa])
	var common := upper.filter(func(p: PoloPlayer): return not by.has(p.id) or (int(by[p.id].weekly) <= 1 and int(by[p.id].tourney) + int(by[p.id].major) + int(by[p.id].allncsa) == 0)).size()
	print("    no awards or a single weekly honour: %d (%.0f%%)" % [common, 100.0 * common / upper.size()])
	r.check(float(none) / upper.size() >= 0.3 and float(common) / upper.size() >= 0.55,
		"17/15: the common outcomes are no award (%d) or one weekly honour (%d of %d in all)" % [none, common, upper.size()])
	r.check(float(major) / upper.size() <= 0.06, "17: major national awards are rare (%d of %d)" % [major, upper.size()])
	# stronger players more often decorated; a lower-rated one now and then
	var sorted: Array = upper.duplicate()
	sorted.sort_custom(func(a: PoloPlayer, b: PoloPlayer): return a.rating10() > b.rating10())
	var top: Array = sorted.slice(0, sorted.size() / 4)
	var bottom: Array = sorted.slice(sorted.size() / 2)
	var share := func(list: Array) -> float: return float(list.filter(func(p): return by.has(p.id)).size()) / maxf(1.0, list.size())
	print("    decorated: the best quarter %.0f%%, the bottom half %.0f%%" % [share.call(top) * 100.0, share.call(bottom) * 100.0])
	r.check(share.call(top) > share.call(bottom) * 1.5, "18: the stronger players are likelier to have honours")
	r.check(share.call(bottom) > 0.0, "19: and a lower-rated one sometimes has one")
	var by_class := {}
	for p in upper:
		var y: int = p.year
		by_class[y] = [int(by_class.get(y, [0, 0])[0]) + (1 if by.has(p.id) else 0), int(by_class.get(y, [0, 0])[1]) + 1]
	print("    decorated by class: %s" % str(by_class))
	r.check(float(by_class[4][0]) / by_class[4][1] > float(by_class[2][0]) / by_class[2][1], "20: seniors (three past seasons) more often than sophomores (one)")
	# the best-decorated man
	var best := -1
	var most := 0
	for pid in by:
		var n: int = by[pid].weekly + by[pid].tourney + by[pid].major + by[pid].allncsa
		if n > most:
			most = n
			best = pid
	if best >= 0:
		print("    the most decorated: %s (%s, %.1f): %s" % [(ps[best] as PoloPlayer).short_name(), (ps[best] as PoloPlayer).year_text(), (ps[best] as PoloPlayer).rating10(), str(by[best])])

func _saves(c: Career) -> void:
	var d := Career.from_dict(JSON.parse_string(JSON.stringify(c.to_dict())))
	r.check(JSON.stringify(d.legacy) == JSON.stringify(c.legacy) and _hist(d.conf_awards).size() == _hist(c.conf_awards).size()
		and _hist(d.awards).size() == _hist(c.awards).size() and _hist(d.tourney_awards).size() == _hist(c.tourney_awards).size(), "30: a save keeps the exact history")
	var n := _hist(c.conf_awards).size()
	Legacy.generate(c)
	r.check(_hist(c.conf_awards).size() == n, "29: generated once: never again for the same career")
	var again := Career.new_game("SJCU", "A", "B", 81)
	r.check(JSON.stringify(again.legacy) == JSON.stringify(c.legacy) and _hist(again.awards).map(func(a): return [a.award, a.pid]) == _hist(c.awards).map(func(a): return [a.award, a.pid]),
		"18: the same dynasty seed, the same history")
	# no gameplay effect: the rosters exactly as without it
	var stats_clean := true
	for id in c.teams:
		for p in (c.teams[id] as PoloTeam).roster:
			stats_clean = stats_clean and p.stats.is_empty() and p.awards.is_empty()
	r.check(stats_clean, "21: no current-season stat or award string touched")
	var plain := Career.new_setup(81)
	var made := Career.new_setup(81).begin("SJCU", "A", "B")
	r.check(plain.teams.keys().all(func(id): return (plain.teams[id] as PoloTeam).roster.map(func(p: PoloPlayer): return [p.id, p.attrs, p.attr_pot, p.xp, p.xp_level]) == (made.teams[id] as PoloTeam).roster.map(func(p: PoloPlayer): return [p.id, p.attrs, p.attr_pot, p.xp, p.xp_level]) or id == "SJCU"),
		"21: ratings, potential and XP exactly as made without it")
	# an older save: nothing added
	var old: Dictionary = JSON.parse_string(JSON.stringify(c.to_dict()))
	old.erase("legacy")
	old.conf_awards = (old.conf_awards as Array).filter(func(a): return not bool(a.get("hist", false)))
	old.awards = (old.awards as Array).filter(func(a): return not bool(a.get("hist", false)))
	old.tourney_awards = (old.tourney_awards as Array).filter(func(a): return not bool(a.get("hist", false)))
	var od := Career.from_dict(old)
	r.check(od.legacy.is_empty() and _hist(od.conf_awards).is_empty(), "33: an existing save isn't given a made-up past")
	# a real award alongside: both kept, the old conference kept after a move
	var ps := _players(c)
	var vet: PoloPlayer = null
	for a in _hist(c.conf_awards):
		if ps.has(int(a.pid)):
			vet = ps[int(a.pid)]
			break
	if vet != null:
		var before := Honours.of(c, vet.id).size()
		var conf0: String = _hist(c.conf_awards).filter(func(a): return int(a.pid) == vet.id)[0].conf
		c.conf_awards.append({"year": c.year, "season": c.season_label(), "week": 0, "label": "WEEK 1", "conf": "NWPC" if conf0 != "NWPC" else "WCC", "cat": "potw",
			"pid": vet.id, "team": "X", "name": vet.short_name(), "pos": vet.pos, "cls": vet.year, "stars": 3.0, "line": {"g": 4, "gp": 1}, "score": 10.0})
		var after := Honours.of(c, vet.id)
		r.check(after.size() == before + 1 and after.any(func(e): return e.kind == "weekly" and e.conf == Colleges.conf_abbr(conf0)), "32/34: a real award is added beside the history; the past one keeps its conference")

func _screens(c: Career) -> void:
	Game.career = c
	var ps := _players(c)
	var best := -1
	var count := 0
	for pid in ps:
		var n := Honours.of(c, pid).size()
		if n > count:
			count = n
			best = pid
	Game.goto("trophy_room", {"id": best, "back": {"id": best}})
	await r.get_tree().process_frame
	await r.get_tree().process_frame
	var room = Game.current_screen
	var all: Array = room.find_children("*", "", true, false)
	var plaques := all.filter(func(n): return n.has_meta("entry")).size()
	var weekly := Honours.of(c, best).filter(func(e): return e.kind == "weekly").size()
	r.check(plaques == weekly, "22: every historical weekly award a plaque (%d)" % plaques)
	var trophies := all.filter(func(n): return n.has_meta("trophy")).size()
	var kinds := {}
	for e in Honours.of(c, best):
		if e.kind != "weekly":
			kinds[e.key] = true
	r.check(trophies == kinds.size(), "23/28: each other honour a trophy, as the accolades list them (%d)" % trophies)
	var acc: Array = load("res://src/ui/screens/player.gd").accolades(c, best)
	r.check(acc.size() == kinds.size() + _uniq(Honours.of(c, best).filter(func(e): return e.kind == "weekly").map(func(e): return e.key)).size(), "13: the Career Accolades list them, with years")
	Game.goto("records")
	await r.get_tree().process_frame
	Game.current_screen.tab = "SEASON AWARDS"
	Game.current_screen._render()
	await r.get_tree().process_frame
	r.check(Game.current_screen.find_child("Awards_%s" % String(c.legacy[2].season), true, false) != null, "35: the Record Book has the past seasons")
	Game.goto("title")
	await r.get_tree().process_frame

##   godot --path game -- --test legacy_png <dir>
static func shots(runner, out: String) -> void:
	DirAccess.make_dir_recursive_absolute(out)
	var tree: SceneTree = runner.get_tree()
	Store.reset_for_tests()
	var c := Career.new_game("SJCU", "A", "B", 81)
	c.queue.clear()
	Game.career = c
	var snap := func(name: String) -> void:
		await tree.create_timer(0.6).timeout
		await RenderingServer.frame_post_draw
		runner.get_viewport().get_texture().get_image().save_png(out.path_join(name + ".png"))
		print("  shot ", name)
	var best := -1
	var most := 0
	for id in c.teams:
		for p in (c.teams[id] as PoloTeam).roster:
			var n := Honours.of(c, p.id).size()
			if n > most:
				most = n
				best = p.id
	Game.goto("player", {"id": best, "view": true})
	await snap.call("l1_profile")
	Game.goto("trophy_room", {"id": best, "back": {"id": best, "view": true}})
	await snap.call("l2_room")
	Game.goto("records")
	await tree.process_frame
	Game.current_screen.tab = "SEASON AWARDS"
	Game.current_screen._render()
	await snap.call("l3_records")
	Game.career = null

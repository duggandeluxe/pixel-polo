extends RefCounted
## The Playoff Bracket visual overhaul (PlayoffBracket, the Conference screen's PLAYOFFS tab): the
## bracket is the schedule's own tournament, every conference's and the NCSA's, at every stage.
##   godot --headless --path game -- --test bracket
##   godot --path game -- --test bracket_png <dir>     (needs a window)

var r

func run(runner) -> void:
	r = runner
	print("playoff bracket")
	Store.reset_for_tests()
	var c := Career.new_game("BUCK", "A", "B", 71)
	Game.career = c
	# before the playoffs: the bracket the standings would make, no games in it
	_to(c, func(): return _weeks_left(c) <= 2)
	var conf := c.team().conf
	var pm := PlayoffBracket.model(c, "conf", conf)
	r.check(not pm.empty and pm.projected and (pm.seeds as Array) == Schedule.conf_table(c.teams, c.table, conf).slice(0, pm.size),
		"12: before the playoffs: the bracket the standings make today, marked PROJECTED")
	r.check(pm.rounds.all(func(rd): return rd.matches.all(func(m): return m.game.is_empty() and m.win == "" or m.bye)), "11: ...with no games or results in it")
	# the conference quarterfinals drawn, not played: who plays whom, no scores, placeholders after
	_to(c, func(): return _drawn(c, "conf_qf") and not _played(c, "conf_qf"))
	for cid in Colleges.conf_ids_of(c.teams):
		_consistent(c, cid, "drawn")
	var m0 := PlayoffBracket.model(c, "conf", conf)
	r.check(String(PlayoffBracket.placeholder(m0, 1, 0, "b")).begins_with("WINNER OF") or m0.rounds[1].matches[0].b != "?",
		"7: a game whose team isn't known yet waits for 'WINNER OF ...'")
	# mid-tournament and done
	_to(c, func(): return _played(c, "conf_qf") and not _played(c, "conf_semi"))
	for cid in Colleges.conf_ids_of(c.teams):
		_consistent(c, cid, "after the quarterfinals")
	_to(c, func(): return _played(c, "conf_final"))
	var champs_ok := true
	for cid in Colleges.conf_ids_of(c.teams):
		_consistent(c, cid, "complete")
		var m := PlayoffBracket.model(c, "conf", cid)
		champs_ok = champs_ok and m.champion != "" and m.champion in (c.season.get("conf_champs", []) as Array)
	var tall := true
	for cid in Colleges.conf_ids_of(c.teams):
		tall = tall and float(PlayoffBracket.layout(PlayoffBracket.model(c, "conf", cid), 464.0).bottom) <= PlayoffBracket.ROOM_H
	r.check(tall, "17/19: every conference's bracket (4 to 8 teams) fits the height the tab has, the 8-team one in compact cards")
	r.check(champs_ok, "9/13: every conference's champion is the one the season recorded (conf_champs)")
	# the NCSA, all the way
	_to(c, func(): return _played(c, "nat_final"))
	var nm := PlayoffBracket.model(c, "nat", "")
	r.check(not nm.empty and nm.champion != "" and nm.champion == Schedule.winner(_round(c, "nat_final").games[0]),
		"9: the NCSA bracket ends at the real national champion")
	_consistent_fam(c, nm, "nat", "NCSA complete")
	# a save loads with the same bracket
	var back := Career.from_dict(JSON.parse_string(JSON.stringify(c.to_dict())))
	var bm := PlayoffBracket.model(back, "conf", conf)
	var cm := PlayoffBracket.model(c, "conf", conf)
	r.check(bm.champion == cm.champion and str(bm.rounds.map(func(rd): return rd.matches.map(func(x): return [x.a, x.b, x.win]))) \
		== str(cm.rounds.map(func(rd): return rd.matches.map(func(x): return [x.a, x.b, x.win]))), "22: a saved career shows the same bracket")
	# the screen: the tab, the bracket, every conference, inside the width
	Game.goto("conference")
	await runner.get_tree().process_frame
	var scr = Game.current_screen
	scr.tab = "PLAYOFFS"
	scr._render()
	await runner.get_tree().process_frame
	await runner.get_tree().process_frame
	var box: Control = scr.find_child("Bracket", true, false)
	r.check(box != null and scr.find_child("BracketTitle", true, false) != null, "1: the PLAYOFFS tab is the bracket")
	var fits := true
	var wide := true
	for cid in Colleges.conf_ids_of(c.teams):
		for w in [480.0, 584.0, 640.0]:
			# (the Bracket Polish update: laid out in FINE units, two-thirds of a game pixel each)
			var room: float = (w - 16.0) / PlayoffBracket.FINE
			var lay := PlayoffBracket.layout(PlayoffBracket.model(c, "conf", cid), room)
			fits = fits and (lay.plaque as Rect2).end.x <= room + 0.5
			wide = wide and float(lay.w) >= 118.0 * 1.2   # (room for text: at least 20% more than the old 118-px cards)
	var nlay := PlayoffBracket.layout(nm, 464.0 / PlayoffBracket.FINE)
	fits = fits and (nlay.plaque as Rect2).end.x <= 464.0 / PlayoffBracket.FINE + 0.5
	r.check(fits, "19: every bracket fits the screen's width (480, 584, 640 wide; the NCSA's too), the plaque inside it")
	r.check(wide, "Polish 3/4: the conference cards hold at least 20%% more than before (118 px at 480: now %d units)" % int(PlayoffBracket.layout(pm, 464.0 / PlayoffBracket.FINE).w))
	var pg := PlayoffBracket.PLAQUE * PlayoffBracket.FINE   # (on screen, in game pixels)
	r.check(pg.x <= 76.0 and pg.y < 63.0, "Polish 1/2: the champion's card %d x %d game px: no bigger than the old 76 x 63 box" % [pg.x, pg.y])
	r.check(PlayoffBracket.ROW_H > 13 and PlayoffBracket.CARD_H > 31, "Polish 3: taller rows (%d) for the full-size logos" % PlayoffBracket.ROW_H)
	var titles := {}
	for i in Colleges.conf_ids_of(c.teams).size():
		titles[(scr.find_child("BracketTitle", true, false) as Label).text] = true
		scr._step_conf(Colleges.conf_ids_of(c.teams), 1)
		await runner.get_tree().process_frame
	r.check(titles.size() == Colleges.conf_ids_of(c.teams).size(), "15: < > goes through all %d conferences" % titles.size())
	scr.tab = "STANDINGS"
	scr._render()
	await runner.get_tree().process_frame
	r.check(scr.find_child("Bracket", true, false) == null, "21: STANDINGS is still the standings")
	Game.goto("title")
	await runner.get_tree().process_frame
	Game.career = null

# ------------------------------------------------------------------ checks
## The bracket of conference `cid` against the schedule: every one of its scheduled games is in it
## once, with those two teams; byes go to the top seeds; each later place is its feeder's winner.
func _consistent(c: Career, cid: String, when: String) -> void:
	var m := PlayoffBracket.model(c, "conf", cid)
	_consistent_fam(c, m, "conf", "%s %s" % [cid, when], cid)

func _consistent_fam(c: Career, m: Dictionary, fam: String, what: String, cid := "") -> void:
	var games := 0
	var found := 0
	for i in Schedule._family(c.schedule, fam):
		for g in c.schedule[i].games:
			if fam == "nat" or (c.teams[g.h] as PoloTeam).conf == cid:
				games += 1
	var feeds := true
	var byes_top := true
	var seeds: Array = m.seeds
	for k in m.rounds.size():
		for j in m.rounds[k].matches.size():
			var mt: Dictionary = m.rounds[k].matches[j]
			if not mt.game.is_empty():
				found += 1
				feeds = feeds and ((mt.game.h == mt.a and mt.game.a == mt.b) or (mt.game.h == mt.b and mt.game.a == mt.a))
			if mt.bye and k == 0:
				byes_top = byes_top and seeds.find(mt.win) < int(m.size) - seeds.size()   # (the top size - n seeds sit out)
			if k > 0:
				for s in 2:
					var f: Dictionary = m.rounds[k - 1].matches[j * 2 + s]
					var here: String = mt["a" if s == 0 else "b"]
					feeds = feeds and (here == f.win if f.win != "" else here == "?")
	r.check(found == games, "4/8 %s: every scheduled game in its place (%d of %d)" % [what, found, games])
	r.check(feeds, "8/9 %s: each place is its feeder's winner (upsets included), the teams the game's" % what)
	r.check(byes_top, "10 %s: the byes are the top seeds', no game made up for them" % what)

func _round(c: Career, kind: String) -> Dictionary:
	for rd in c.schedule:
		if String(rd.kind) == kind:
			return rd
	return {}

func _drawn(c: Career, kind: String) -> bool:
	var rd := _round(c, kind)
	return not rd.is_empty() and Schedule.drawn(rd) and not (rd.games as Array).is_empty()

func _played(c: Career, kind: String) -> bool:
	var rd := _round(c, kind)
	return _drawn(c, kind) and rd.games.all(func(g): return g.r != null)

func _weeks_left(c: Career) -> int:
	var n := 0
	for i in range(c.week, c.schedule.size()):
		if not Schedule.is_playoff(c.schedule[i]):
			n += 1
	return n

## Plays the season on (your games simmed, upgrades spent) until `done` says stop, a day at a time.
func _to(c: Career, done: Callable) -> void:
	var guard := 0
	while not done.call() and guard < 80:
		guard += 1
		c.queue.clear()
		for q in c.upgrades_due():
			Development.ai_spend(q)
		if c.has_game():
			c.sim_my_game()
			continue
		c.end_week()

# ------------------------------------------------------------------ screenshots
static func shots(runner, out: String) -> void:
	DirAccess.make_dir_recursive_absolute(out)
	Store.reset_for_tests()
	Store.mark_starter_offered()
	var t = load("res://tests/bracket_test.gd").new()
	var c := Career.new_game("BUCK", "A", "B", 71)
	Game.career = c
	var stages := [["projected", func(): return t._weeks_left(c) <= 2],
		["qf_drawn", func(): return t._drawn(c, "conf_qf") and not t._played(c, "conf_qf")],
		["after_qf", func(): return t._played(c, "conf_qf") and not t._played(c, "conf_semi")],
		["conf_done", func(): return t._played(c, "conf_final")],
		["ncsa_done", func(): return t._played(c, "nat_final")]]
	for st in stages:
		t._to(c, st[1])
		c.queue.clear()
		for q in c.upgrades_due():
			Development.ai_spend(q)
		Game.goto("conference")
		await runner.get_tree().process_frame
		var scr = Game.current_screen
		scr.tab = "PLAYOFFS"
		if st[0] == "ncsa_done":
			scr.pfam = "nat"
		scr._render()
		await runner.get_tree().create_timer(0.5).timeout
		await RenderingServer.frame_post_draw
		runner.get_viewport().get_texture().get_image().save_png(out.path_join("bracket_%s.png" % st[0]))
		print("  shot ", st[0])
		if st[0] == "conf_done":
			var confs: Array = Colleges.conf_ids_of(c.teams)
			for i in confs.size() - 1:
				scr._step_conf(confs, 1)
				await runner.get_tree().create_timer(0.3).timeout
				await RenderingServer.frame_post_draw
				runner.get_viewport().get_texture().get_image().save_png(out.path_join("bracket_conf_%s.png" % scr.pconf))
				print("  shot conf ", scr.pconf)
	Game.career = null

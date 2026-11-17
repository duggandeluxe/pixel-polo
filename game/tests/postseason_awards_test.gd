extends RefCounted
## THE POSTSEASON AWARDS update: weekly awards are the regular season's only; each tournament's
## PLAYER OF THE TOURNAMENT is named once its final is played (never before, never twice), from
## that tournament's games, and announced (queued, saved) for the tournaments that are yours.
##   godot --headless --path game -- --test postseason_awards
##   godot --path game -- --test postseason_awards_png <dir>
## Fixed seeds throughout.

var r

func run(runner) -> void:
	r = runner
	Store.reset_for_tests()
	print("postseason awards: the stats on show")
	_stats()
	print("postseason awards: a season")
	await _season(runner)

func _stats() -> void:
	var field := {"tid": "conf:WCC", "conf": "WCC", "cat": "pot", "pos": PoloPlayer.Pos.DRIVER, "line": {"gp": 3, "g": 11, "a": 5, "st": 4, "bl": 1}}
	var st := WeeklyAwardShow.stats_of(field)
	r.check(st.map(func(s): return s[1]) == ["GAMES", "GOALS", "ASSISTS", "STEALS"] and st[0][0] == "3" and st[1][0] == "11",
		"announcement: a field player's tournament totals, games first (%s)" % str(st))
	var gk := {"tid": "nat", "conf": "", "cat": "pot", "pos": PoloPlayer.Pos.GK, "line": {"gp": 4, "sv": 40, "ga": 20}}
	var ks := WeeklyAwardShow.stats_of(gk)
	r.check(ks.map(func(s): return s[1]) == ["GAMES", "SAVES", "SAVE RATE", "GOALS ALLOWED"] and ks[2][0] == "67%", "announcement: a keeper's (%s)" % str(ks))
	r.check(WeeklyAwardShow.is_national(gk) and not WeeklyAwardShow.is_national(field) and WeeklyAwardShow.is_tourney(field)
		and not WeeklyAwardShow.is_tourney({"cat": "potw", "week": 2}), "announcement: national vs conference vs weekly")
	# team success leans, never decides: two equal tournaments, the deeper run wins; a far better one on a semifinalist still does
	var a := AttrBench.player({}, false, {}, PoloPlayer.Pos.DRIVER)
	var line := {"gp": 3, "g": 6, "a": 3, "st": 2}
	var deep := line.duplicate()
	deep["tw"] = 3
	r.check(ConfAwards.score(a, deep, "pot") > ConfAwards.score(a, line, "pot"), "POT: the same totals on a team that won more score higher")
	r.check(ConfAwards.score(a, {"gp": 2, "g": 12, "a": 4, "st": 3, "tw": 1}, "pot") > ConfAwards.score(a, deep, "pot"),
		"POT: a great tournament on a team out in the semis still beats a good one on the champions")
	r.check(ConfAwards.score(a, deep, "opot") == ConfAwards.score(a, line, "opot") and ConfAwards.score(a, deep, "rotw") == ConfAwards.score(a, line, "rotw"),
		"POT only: the other awards' scores don't change")

func _season(runner) -> void:
	var c := Career.new_game("BUCK", "A", "B", 83)
	Game.career = c
	var guard := 0
	var weekly_in_playoffs := 0
	var weekly_regular := {}
	var early := false            # a tournament award before its final
	var queued: Array = []        # every tourney_award queue item, in order
	var conf_final_wk := -1
	var nat_final_wk := -1
	var reloaded := false
	var reload_ok := true
	while c.phase == "season" and guard < 200:
		guard += 1
		for q in c.queue:
			if String(q.type) == "tourney_award":
				queued.append(q.duplicate())
		c.queue.clear()
		for q in c.upgrades_due():
			Development.ai_spend(q)
		if c.has_game():
			c.sim_my_game()
			continue
		var wk := c.week
		var kind := String(c.schedule[wk].kind) if wk < c.schedule.size() else ""
		var n_weekly := ConfAwards.earned(c).size()
		var live_before := c.tourney_awards.filter(func(x): return not bool(x.get("hist", false))).size()
		c.end_week()
		var made_weekly := ConfAwards.earned(c).size() - n_weekly
		if Schedule.is_playoff({"kind": kind}):
			weekly_in_playoffs += made_weekly
		elif kind != "":
			weekly_regular[wk] = made_weekly
		var live_after := c.tourney_awards.filter(func(x): return not bool(x.get("hist", false))).size()
		if live_after > live_before and not kind in ["conf_final", "nat_final"]:
			early = true
		if kind == "conf_final":
			conf_final_wk = wk
		if kind == "nat_final":
			nat_final_wk = wk
		# saved and loaded straight after the conference final: nothing named or queued again
		if kind == "conf_final" and not reloaded:
			reloaded = true
			var n_t := c.tourney_awards.size()
			var n_q := c.queue.filter(func(q): return String(q.type) == "tourney_award").size()
			c = Career.from_dict(JSON.parse_string(JSON.stringify(c.to_dict())))
			Game.career = c
			c.week = wk   # (the final's week again: deciding it once more must do nothing)
			ConfAwards.decide_week(c)
			TourneyAwards.decide(c)
			c.week = wk + 1
			reload_ok = c.tourney_awards.size() == n_t and c.queue.filter(func(q): return String(q.type) == "tourney_award").size() == n_q
	for q in c.queue:
		if String(q.type) == "tourney_award":
			queued.append(q.duplicate())
	var regular_weeks := c.schedule.filter(func(x): return not Schedule.is_playoff(x)).size()
	r.check(weekly_regular.size() == regular_weeks and weekly_regular.values().all(func(n): return n > 0),
		"1: Player of the Week every regular-season week, the last one too (%s)" % str(weekly_regular))
	r.check(weekly_in_playoffs == 0, "1: no weekly award in any conference or national tournament round (%d)" % weekly_in_playoffs)
	r.check(ConfAwards.earned(c).all(func(a): return not Schedule.is_playoff(c.schedule[int(a.week)])), "1: every weekly record a regular-season week's")
	r.check(not early, "2/3/4: no tournament award before its final")
	r.check(conf_final_wk >= 0 and nat_final_wk > conf_final_wk, "the season ran both tournaments")
	var mine: Array = c.my_tourneys()
	var tids: Array = queued.map(func(q): return String(q.tid))
	r.check(tids == mine.filter(func(t): return c.tourney_awards.any(func(a): return String(a.tid) == t and String(a.cat) == "pot")),
		"2/3/7: your conference's and the national POT announced, once each, in order (%s of %s)" % [str(tids), str(mine)])
	r.check(reloaded and reload_ok, "7: saved and loaded after the final: no award or announcement twice")
	var live := c.tourney_awards.filter(func(a): return not bool(a.get("hist", false)))
	var pots := live.filter(func(a): return String(a.cat) == "pot")
	var per := {}
	for a in pots:
		per[String(a.tid)] = int(per.get(String(a.tid), 0)) + 1
	r.check(per.values().all(func(n): return n == 1) and per.has("nat") and per.has("conf:" + c.team().conf), "5: one POT a tournament, in the records (%s)" % str(per))
	r.check(live.all(func(a): return not (a.line as Dictionary).has("tw")), "5: the records keep the player's stats, not the team-success weight")
	# the hub shows the queued announcement and drops it only once closed
	c.queue = [queued[0]]
	Game.goto("hub")
	for _i in 4:
		await runner.get_tree().process_frame
	var shows: Array = Game.current_screen.find_children("*", "WeeklyAwardShow", true, false)
	r.check(shows.size() == 1 and WeeklyAwardShow.is_tourney((shows[0] as WeeklyAwardShow).rec()), "announcement: the tournament's show over the hub")
	r.check(c.queue.size() == 1, "7: not closed yet: still queued (a reload shows it again)")
	if shows.size() == 1:
		(shows[0] as WeeklyAwardShow)._next()
	await runner.get_tree().process_frame
	r.check(c.queue.is_empty(), "7: closed: gone for good")
	Game.career = null
	Game.goto("title")
	await runner.get_tree().process_frame

## The two announcements, mid-animation and finished: conference, then national.
static func shots(runner, out: String) -> void:
	DirAccess.make_dir_recursive_absolute(out)
	var tree: SceneTree = runner.get_tree()
	Store.reset_for_tests()
	var c := Career.new_game("SJCU", "A", "B", 97)
	c.queue.clear()
	Game.career = c
	var seven := c.team().starters()
	var field: PoloPlayer = seven[2]
	var gk: PoloPlayer = seven[0]
	c.tourney_awards.append({"year": c.year, "season": c.season_label(), "tid": "conf:" + c.team().conf, "conf": c.team().conf, "cat": "pot",
		"pid": field.id, "team": c.school, "name": field.short_name(), "pos": field.pos, "cls": field.year, "stars": 3.0,
		"line": {"gp": 3, "g": 11, "a": 5, "st": 4, "bl": 1}, "score": 30.0})
	c.tourney_awards.append({"year": c.year, "season": c.season_label(), "tid": "nat", "conf": "", "cat": "pot",
		"pid": gk.id, "team": c.school, "name": gk.short_name(), "pos": gk.pos, "cls": gk.year, "stars": 3.0,
		"line": {"gp": 4, "sv": 41, "ga": 22, "st": 2}, "score": 30.0})
	c.queue = [{"type": "tourney_award", "year": c.year, "tid": "conf:" + c.team().conf}, {"type": "tourney_award", "year": c.year, "tid": "nat"}]
	for n in ["conf", "nat"]:
		Game.goto("hub")
		await tree.create_timer(0.5).timeout
		var ws: WeeklyAwardShow = Game.current_screen.find_children("*", "WeeklyAwardShow", true, false)[0]
		ws.motion = true
		ws.t = 0.0
		await tree.create_timer(0.55).timeout
		await RenderingServer.frame_post_draw
		runner.get_viewport().get_texture().get_image().save_png(out.path_join("%s_mid.png" % n))
		await tree.create_timer(1.4).timeout
		await RenderingServer.frame_post_draw
		runner.get_viewport().get_texture().get_image().save_png(out.path_join("%s_done.png" % n))
		ws._next()
		await tree.process_frame
	print("  shots")
	Game.career = null
	Game.goto("title")

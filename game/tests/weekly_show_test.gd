extends RefCounted
## THE WEEKLY AWARD CELEBRATION (WeeklyAwardShow).
##   godot --headless --path game -- --test weekly_show
##   godot --path game -- --test weekly_show_png <dir>

var r

## Two award records for your team this week (a field POTW, a keeper DPOTW), as decide_week makes them.
static func setup(c: Career) -> Array:
	var seven := c.team().starters()
	var field: PoloPlayer = seven[2]
	var gk: PoloPlayer = seven[0]
	var a := {"year": c.year, "season": c.season_label(), "week": 3, "label": "WEEK 4", "conf": c.team().conf, "cat": "potw", "pid": field.id,
		"team": c.school, "name": field.short_name(), "pos": field.pos, "cls": field.year, "stars": 3.0, "line": {"gp": 2, "g": 7, "a": 4, "st": 2, "bl": 1, "sh": 12}, "score": 40.0}
	var b := {"year": c.year, "season": c.season_label(), "week": 3, "label": "WEEK 4", "conf": c.team().conf, "cat": "dpotw", "pid": gk.id,
		"team": c.school, "name": gk.short_name(), "pos": gk.pos, "cls": gk.year, "stars": 3.0, "line": {"gp": 2, "sv": 18, "ga": 11, "st": 1}, "score": 30.0}
	c.conf_awards.append(a)
	c.conf_awards.append(b)
	c.queue = [{"type": "awards", "year": c.year, "week": 3, "label": "WEEK 4", "mine": [["potw", a.name], ["dpotw", b.name]]}]
	return [a, b]

func run(runner) -> void:
	r = runner
	print("weekly award celebration")
	Store.reset_for_tests()
	var c := Career.new_game("SJCU", "A", "B", 97)
	c.queue.clear()
	Game.career = c
	var recs := setup(c)
	var n_awards := c.conf_awards.size()
	var xp0: Array = c.team().roster.map(func(p): return [p.xp, p.tokens])
	var w0 := c.wallet()
	# the stats are the record's own
	var fs := WeeklyAwardShow.stats_of(recs[0])
	r.check(fs.map(func(s): return s[1]) == ["GOALS", "ASSISTS", "STEALS", "BLOCKS"] and fs[0][0] == "7" and fs[1][0] == "4", "9/11: a field player's week: goals, assists, steals, blocks, his own (%s)" % str(fs))
	var ks := WeeklyAwardShow.stats_of(recs[1])
	r.check(ks.map(func(s): return s[1]) == ["SAVES", "SAVE RATE", "GOALS ALLOWED", "STEALS"] and ks[0][0] == "18" and ks[1][0] == "62%", "10: a keeper's: saves, save rate, goals allowed (%s)" % str(ks))
	var op := WeeklyAwardShow.stats_of({"cat": "opotw", "pos": 2, "line": {"g": 5, "a": 1}})
	r.check(op.size() == 2 or op.all(func(s): return s[1] in ["GOALS", "ASSISTS", "SHOTS", "EXCL DRAWN", "GAMES"]), "9: nothing the week didn't record (%s)" % str(op))
	# the hub shows them, one at a time
	Game.goto("hub")
	for _i in 4:
		await r.get_tree().process_frame
	var show = Game.current_screen.find_children("*", "WeeklyAwardShow", true, false)
	r.check(show.size() == 1 and (show[0] as WeeklyAwardShow).recs.size() == 2, "2/16: your two winners celebrated, in turn")
	r.check(Game.overlay.find_children("*", "Label", true, false).filter(func(l): return (l as Label).text.begins_with("CONFERENCE ")).is_empty(), "the old plain announcement is gone")
	var ws: WeeklyAwardShow = show[0]
	r.check(int(ConfAwards.player_of(c, ws.rec()).id) == int(recs[0].pid), "5: the right player (his own id)")
	r.check(c.queue.size() == 1, "19: not dismissed yet: the item waits in the save")
	ws._next()
	r.check(ws.i == 1 and is_instance_valid(ws), "16: CONTINUE: the next award")
	ws._next()
	await r.get_tree().process_frame
	r.check(c.queue.is_empty(), "15/19: the last CONTINUE closes it, and the queue item is gone (saved): never again")
	r.check(c.conf_awards.size() == n_awards and c.wallet() == w0 and c.team().roster.map(func(p): return [p.xp, p.tokens]) == xp0, "17/22: no award added, no XP, no credits")
	# another team's winners: the toast as before
	c.queue = [{"type": "awards", "year": c.year, "week": 4, "label": "WEEK 5", "mine": []}]
	Game.goto("hub")
	for _i in 4:
		await r.get_tree().process_frame
	r.check(Game.current_screen.find_children("*", "WeeklyAwardShow", true, false).is_empty() and c.queue.is_empty(), "3: nobody of yours: no celebration")
	Game.career = null
	Game.goto("title")
	await r.get_tree().process_frame

static func shots(runner, out: String) -> void:
	DirAccess.make_dir_recursive_absolute(out)
	var tree: SceneTree = runner.get_tree()
	Store.reset_for_tests()
	var c := Career.new_game("SJCU", "A", "B", 97)
	c.queue.clear()
	Game.career = c
	var recs := setup(c)
	recs[0]["cat"] = "opotw"
	Game.goto("hub")
	await tree.create_timer(0.5).timeout
	var ws: WeeklyAwardShow = Game.current_screen.find_children("*", "WeeklyAwardShow", true, false)[0]
	ws.motion = true
	ws.t = 0.0
	await tree.create_timer(0.55).timeout
	await RenderingServer.frame_post_draw
	runner.get_viewport().get_texture().get_image().save_png(out.path_join("w1_mid.png"))
	await tree.create_timer(1.4).timeout
	await RenderingServer.frame_post_draw
	runner.get_viewport().get_texture().get_image().save_png(out.path_join("w2_field.png"))
	ws._next()
	await tree.create_timer(1.8).timeout
	await RenderingServer.frame_post_draw
	runner.get_viewport().get_texture().get_image().save_png(out.path_join("w3_keeper.png"))
	print("  shots")
	Game.career = null

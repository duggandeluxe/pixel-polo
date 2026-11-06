extends RefCounted
## THE SEASON SCHEDULE VISUAL UPDATE: the hub's season path, a node a game (GAME n or the
## playoff round, CONF / TITLE tags, the opponent's logo and name, W/L and the score once played),
## the next game in yellow with its NEXT GAME tab, GAME n OF N from the schedule. Display only.
## The numbered checks follow the spec's REQUIRED TESTING list.
##   godot --headless --path game -- --test season_path
##   godot --path game -- --test season_path_png <dir>

var r   # the test runner

func run(runner) -> void:
	r = runner
	print("season path")
	Store.reset_for_tests()
	var c := Career.new_game("SJCU", "A", "B", 41)
	c.queue.clear()
	c.hot_tip = true
	Game.career = c
	var sched := JSON.stringify(c.schedule)
	var scr = await _hub()
	var weeks: Array = _weeks(scr)
	r.check(weeks.size() == scr.SPAN and scr.find_child("SeasonProgress", true, false) != null, "T1: five nodes on the path, the progress box beside the heading")
	var next: Array = weeks.filter(func(d): return d.state == "next")
	var g: Dictionary = c.my_game()
	var opp: String = g.a if g.h == c.school else g.h
	r.check(next.size() == 1 and next[0].opp == c.teams[opp] and next[0].head == "GAME 1", "T2: the next game is the one node in yellow, against %s" % opp)
	r.check(_progress(scr) == "GAME 1 OF %d" % Schedule.team_games(c.schedule, c.school).size(), "T9: GAME 1 OF N, N from the schedule (%s)" % _progress(scr))
	r.check(JSON.stringify(c.schedule) == sched, "the schedule untouched by drawing it")
	# T3: a game played
	_play_week(c)
	scr = await _hub()
	weeks = _weeks(scr)
	var done: Dictionary = weeks.filter(func(d): return d.head == "GAME 1")[0]
	var g1: Dictionary = Schedule.team_games(c.schedule, c.school)[0][1]
	var won := Schedule.winner(g1) == c.school
	r.check(done.state == ("win" if won else "loss") and done.big == ("W " if won else "L ") + Schedule.score_text(g1, g1.h == c.school), "T3: game 1 shows its result: %s" % done.big)
	r.check(weeks.filter(func(d): return d.state == "next").size() <= 1 and _progress(scr).begins_with("GAME %d OF" % mini(Schedule.games_played(c.schedule, c.school) + 1, Schedule.team_games(c.schedule, c.school).size())), "T3/T17: NEXT moved on, the count with it (%s)" % _progress(scr))
	# T4: the whole season, every game once, in order
	var seen: Array = []
	var order_ok := true
	var guard := 0
	while not c.in_offseason() and guard < 40:
		guard += 1
		scr = await _hub()
		for d in _weeks(scr):
			if d.opp != null and d.head.begins_with("GAME ") and not d.head in seen:
				seen.append(d.head)
		if c.week < c.schedule.size() and Schedule.is_playoff(c.schedule[c.week]) and c.has_game():
			var w: Array = _weeks(scr)
			var nx: Array = w.filter(func(d): return d.state == "next")
			# T5: a playoff game shows its round
			order_ok = order_ok and nx.size() == 1 and String(nx[0].head) == String(Schedule.SHORT_NAMES[String(c.schedule[c.week].kind)])
		_play_week(c)
	var n := Schedule.team_games(c.schedule, c.school).size()
	var want: Array = range(1, n + 1).map(func(i): return "GAME %d" % i)
	seen.sort_custom(func(a, b): return int(a.split(" ")[1]) < int(b.split(" ")[1]))
	r.check(seen == want, "T4: every regular-season game on the path once (%d of %d)" % [seen.size(), n])
	r.check(order_ok, "T5: each playoff game you played showed its round on the next node")
	# T6 / T7: the drawing itself
	Game.career = null
	c = Career.new_game("CULA", "A", "B", 42)
	c.queue.clear()
	c.hot_tip = true
	Game.career = c
	scr = await _hub()
	var path: Control = scr.find_child("SeasonPath", true, false)
	var drawn: Array = []
	UI.drawn_log = drawn
	path.queue_redraw()
	await r.get_tree().process_frame
	await r.get_tree().process_frame
	UI.drawn_log = null
	r.check(drawn.has("NEXT GAME") and drawn.has("GAME 1"), "T2/T6: the path draws NEXT GAME and the game numbers")
	r.check(path.size.x <= scr.get_viewport_rect().size.x and path.size.x >= scr.SPAN * (TeamLogo.box(TeamLogo.MEDIUM).x + 30), "T7: the path fits the page with room for every node's logo and result (%d)" % int(path.size.x))
	Game.career = null
	Game.goto("title")
	await r.get_tree().process_frame

func _hub() -> Node:
	Game.goto("hub", {}, false)
	for _i in 3:
		await r.get_tree().process_frame
	for layer in Game.overlay.get_children():
		layer.queue_free()
	return Game.current_screen

func _weeks(scr) -> Array:
	var p: Control = scr.find_child("SeasonPath", true, false)
	return p.get_meta("weeks") if p != null else []

func _progress(scr) -> String:
	var p: Control = scr.find_child("SeasonProgress", true, false)
	return (p.find_children("*", "Label", true, false)[0] as Label).text if p != null else ""

## One week: your game simulated (as SIM THIS GAME), upgrades spent, the week ended.
static func _play_week(c: Career) -> void:
	while c.has_game():
		c.sim_my_game()
	c.queue.clear()
	for p in c.team().roster:
		while Development.pending(p) > 0:
			var spent := false
			for k in p.key_ratings():
				if Development.spend(p, k):
					spent = true
					break
			if not spent:
				break
	c.end_week()
	c.queue.clear()

## The hub at a few points of a season, at 16:9, a wide phone and 4:3.
static func shots(runner, out: String) -> void:
	DirAccess.make_dir_recursive_absolute(out)
	var tree: SceneTree = runner.get_tree()
	var c := Career.new_game("SJCU", "A", "B", 41)
	c.queue.clear()
	c.hot_tip = true
	Game.career = c
	var plan := [[3, "s1_week4"], [4, "s2_week8"], [3, "s3_late"], [0, "s4_playoffs"]]
	for st in plan:
		for _i in int(st[0]):
			_play_week(c)
		if String(st[1]) == "s4_playoffs":
			var guard := 0
			while not (c.week < c.schedule.size() and Schedule.is_playoff(c.schedule[c.week])) and guard < 20:
				guard += 1
				_play_week(c)
		for sz in [[Vector2i(1440, 810), ""], [Vector2i(1752, 810), "_wide"], [Vector2i(1080, 810), "_4x3"]]:
			DisplayServer.window_set_size(sz[0])
			await tree.create_timer(0.3).timeout
			Game.goto("hub", {}, false)
			await tree.create_timer(0.4).timeout
			for layer in Game.overlay.get_children():
				layer.queue_free()
			await tree.create_timer(0.1).timeout
			runner.get_viewport().get_texture().get_image().save_png(out.path_join(String(st[1]) + String(sz[1]) + ".png"))
			print("  shot ", st[1], sz[1])
	DisplayServer.window_set_size(Vector2i(1440, 810))
	Game.career = null
	Game.goto("title")

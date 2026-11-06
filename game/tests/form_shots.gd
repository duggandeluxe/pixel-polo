extends RefCounted
## Screenshot tour of stars and form: the roster's seven cards (five stars: gold, then red for
## HOT and VERY HOT), a HOT player's page, the summary after FINAL (the HOT reveal), and the matchup's LIVE.
## Needs a window:
##   godot --path game -- --test form_png <dir>

static func run(runner: Node, out: String) -> void:
	DirAccess.make_dir_recursive_absolute(out)
	var tree := runner.get_tree()
	Store.reset_for_tests()
	Store.starter_offered = true
	var c := Career.new_game("LIUB", "Shot", "Coach", 4)
	Game.career = c
	for _w in 3:
		c.queue.clear()
		while c.has_game():
			c.sim_my_game()
		c.end_week()
	c.queue.clear()
	# every level on show: VERY HOT, HOT and NORMAL
	var seven := c.team().starters()
	var heats := [2, 1, 0, 0, 1, 2, 0]
	for i in seven.size():
		seven[i].form = [1, 1, 1, 1, 0] if heats[i] == 2 else ([1, 1, 1] if heats[i] == 1 else [0, -1, 0])
		seven[i].heat = heats[i]
	Game.goto("roster")
	await tree.create_timer(0.3).timeout
	await _shot(runner, out, "f_roster")
	Game.goto("player", {"id": seven[1].id, "list": c.team().roster.map(func(q): return q.id)})
	await tree.create_timer(0.4).timeout
	await _shot(runner, out, "f_player_hot")
	if c.has_game():
		Game.goto("matchup")
		await tree.create_timer(0.3).timeout
		await _shot(runner, out, "f_matchup")
		c.last_summary = c.sim_my_game()
		Game.goto("game_summary")
		await tree.create_timer(0.5).timeout
		var scr = Game.current_screen
		scr.tap(Vector2(10, 10))
		await tree.create_timer(1.2).timeout
		await _shot(runner, out, "f_summary_form")
	Game.career = null
	Game.goto("title")

static func _shot(runner: Node, out: String, name: String) -> void:
	await RenderingServer.frame_post_draw
	runner.get_viewport().get_texture().get_image().save_png(out.path_join(name + ".png"))
	print("  shot ", name)

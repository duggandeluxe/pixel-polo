extends RefCounted
## Screenshots of the Scoreboard upgrade's three tiers (Scoreboard): on a real match screen (each
## tier, a quiet moment, the shot clock's final five, a goal going up on the board), and in
## Developer Mode's SCOREBOARD VISUAL PREVIEW (ALL TIERS, long names, the shootout).
##   godot --path game --resolution 480x270 -- --test scoreboard_png <outdir>   (needs a window)

static func _snap(runner, path: String) -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	runner.get_viewport().get_texture().get_image().save_png(path)

static func run(runner, dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	Game.test_mode = true   # (nothing here is ever saved: the real saves stay as they are)
	var dev := bool(Game.settings.get("dev_mode", false))
	Game.settings.dev_mode = true
	var c := Career.new_setup(777)
	var pairs := [["FORDU", "LMMU"], ["CULA", "WAGN"], ["GWU", "LBSC"]]
	for pr in pairs:
		Game.match_cfg = {"us": c.teams[pr[0]], "them": c.teams[pr[1]], "seed": 9, "minutes": 2.0, "autoplay": false}
		Game.goto("match", Game.match_cfg)
		var ms = Game.current_screen
		for _i in 3:
			await runner.get_tree().process_frame
		if ms.intro != null:
			ms.intro.skip()
			ms._end_intro()
		ms.flow._start_attack(Play.Kind.HALF_COURT)
		ms.flow.state.score = [7, 12]
		ms.flow.state.quarter = 3
		ms.flow.state.clock = 72.0
		await runner.get_tree().process_frame
		Engine.time_scale = 0.0
		for n in Scoreboard.TOP:
			Scoreboard.override = n + 1
			ms.flow.play.shot_clock = 17.0
			ms.queue_redraw()
			await _snap(runner, "%s/match_%s_t%d.png" % [dir, pr[0], n + 1])
			if pr[0] == "FORDU":
				ms.flow.play.shot_clock = 3.9
				ms.flow.play.man_up = 14.0
				ms.queue_redraw()
				await _snap(runner, "%s/match_t%d_final5.png" % [dir, n + 1])
				ms.flow.play.man_up = 0.0
		Engine.time_scale = 1.0
		if pr[0] == "FORDU":   # Developer Mode's pause menu: the BOARD button
			ms._pause()
			await _snap(runner, "%s/match_pause_dev.png" % dir)
			Game.overlay.get_child(Game.overlay.get_child_count() - 1).queue_free()
			ms.paused = false
	# the lab: ALL TIERS, a goal going up, the shootout
	Game.goto("scoreboard_lab")
	for _i in 4:
		await runner.get_tree().process_frame
	var lab = Game.current_screen
	lab.all_view = true
	lab._labels()
	await _snap(runner, "%s/lab_all.png" % dir)
	for k in [0.05, 0.12, 0.3, 0.6]:
		lab.lab_fx = {"side": 0, "add": 1, "t": k, "col": Color("f2f2e9"), "big": true}
		Engine.time_scale = 0.0
		await _snap(runner, "%s/lab_all_goal_%.2f.png" % [dir, k])
	lab.lab_fx = {}
	Engine.time_scale = 1.0
	lab.home_i = 13   # Los Angeles Mountain Lions
	lab.away_i = 21   # (a long place name)
	lab._use_teams()
	lab.next_quarter()
	lab.next_quarter()
	lab.next_quarter()
	await _snap(runner, "%s/lab_all_long_so.png" % dir)
	lab.all_view = false
	lab.set_tier(3)
	await _snap(runner, "%s/lab_live_t3.png" % dir)
	Scoreboard.override = 0
	# the shop: the gallery's card, then the upgrade's page at each level (its preview window)
	var art := UI.canvas(480, 270, func(ci: Control):
		ci.draw_rect(Rect2(0, 0, 480, 270), UI.INK)
		for k in 4:
			UpgradeArt.draw(ci, "scoreboard", Rect2(8 + (k % 2) * 110, 8 + (k / 2) * 72, 96, 62), 0.6 * k, Color("860038"), Color("ffffff")))
	Game.current_screen.add_child(art)
	await _snap(runner, "%s/shop_card_art.png" % dir)
	art.queue_free()
	Game.goto("upgrade_detail", {"cat": "scoreboard"})
	for _i in 4:
		await runner.get_tree().process_frame
	var page = Game.current_screen
	for n in Scoreboard.TOP:
		page.select(n + 1)
		await runner.get_tree().process_frame
		await _snap(runner, "%s/shop_page_l%d.png" % [dir, n + 1])
	Game.settings.dev_mode = dev
	Game.goto("title")

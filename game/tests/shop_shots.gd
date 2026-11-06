extends RefCounted
## Screenshots of the shop's areas.
##   godot --path game -- --test shop_png <outdir>   (needs a window)

static func run(runner, dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	runner.get_window().size = Vector2i(1440, 810)
	Store.reset_for_tests()
	var c := Career.new_game("GWU", "S", "H", 640)
	c.queue.clear()
	c.add_credits(125, "WIN")
	Game.career = c
	Store.bank.credit(900, "T-SHOT")
	Store.looks.buy_tier("goal", c, null, false)
	Store.looks.buy_tier("goal", c, null, false)
	Game.goto("more")
	await _snap(runner, dir, "HUB")
	Game.goto("store")
	await _snap(runner, dir, "STORE")
	Game.goto("visual_shop")
	for i in 3:
		await runner.get_tree().process_frame
	await _snap(runner, dir, "GALLERY")
	Game.goto("store")
	var sc: ScrollContainer = Game.current_screen.body.get_child(Game.current_screen.body.get_child_count() - 1)
	await _snap(runner, dir, "STORE_TOP")
	sc.scroll_vertical = 100000
	await _snap(runner, dir, "STORE_END")
	Game.goto("recruiting")
	await _snap(runner, dir, "RECRUITING")
	Game.goto("program")
	await _snap(runner, dir, "PROGRAM")
	for id in ["goal", "replay", "crowd", "broadcast", "victory", "pregame"]:
		Game.goto("upgrade_detail", {"cat": id})
		for i in 4:
			await runner.get_tree().process_frame
		var d = Game.current_screen
		d.select(VisualUpgrades.top(id))
		d.play_level()
		for i in 150:
			d._process(1.0 / 30.0)
			if i == 45 or i == 149:
				await _snap(runner, dir, "D_%s_%d" % [id, i])
	# the victory scenes, full screen
	var blue: PoloTeam = c.teams["CULA"]
	for row in [[1, 1.0, ""], [2, 1.3, ""], [3, 0.6, ""], [3, 2.0, ""], [3, 3.6, ""], [4, 1.5, ""], [4, 3.4, ""], [4, 3.4, "nat"], [3, 5.6, "conf"]]:
		var show := VictoryShow.new(blue, row[0], row[2], false, false)
		show.score = [12, 9]
		var cv := UI.canvas(0, 0, func(ci: Control): show.draw(ci, ci.size))
		cv.set_anchors_preset(Control.PRESET_FULL_RECT)
		Game.overlay.add_child(cv)
		while show.t < float(row[1]):
			show.step(1.0 / 30.0)
		cv.queue_redraw()
		await _snap(runner, dir, "V%d_%.1f%s" % [row[0], row[1], row[2]])
		cv.queue_free()
	Store.reset_for_tests()
	Game.career = null

static func _snap(runner, dir: String, name: String) -> void:
	for i in 3:
		await runner.get_tree().process_frame
	await RenderingServer.frame_post_draw
	runner.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [dir, name])

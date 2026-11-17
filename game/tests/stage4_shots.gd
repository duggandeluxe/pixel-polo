extends RefCounted
## Screenshots: the trophy ceremony, lineup cards, broadcast graphics.
##   godot --path game -- --test stage4_png <dir>   (needs a window)

static func _snap(runner, dir: String, name: String) -> void:
	await RenderingServer.frame_post_draw
	runner.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [dir, name])

static func run(runner, dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	runner.get_window().size = Vector2i(1440, 810)
	Game.settings.dev_mode = true
	Game.goto("visual_lab")
	for i in 3:
		await runner.get_tree().process_frame
	var lab = Game.current_screen
	lab.cat_i = 4
	lab._labels()
	for e in [[1, 0, 1.0, "vic1"], [4, 0, 1.6, "vic4"], [1, 3, 3.2, "trophy1"], [4, 3, 6.2, "trophy4"]]:
		lab.lv = e[0]
		lab.game_i = e[1]
		lab.preview()
		lab.cine.t = float(e[2])
		for i in 3:
			await runner.get_tree().process_frame
		await _snap(runner, dir, e[3])
	lab.cine = null
	lab.cat_i = 5
	lab.game_i = 3
	lab._labels()
	for e in [[3, 3.2, "lineup3"], [4, 3.2, "lineup4"], [4, 7.6, "matchup4"]]:
		lab.lv = e[0]
		lab.preview()
		lab.cine.t = float(e[1])
		for i in 3:
			await runner.get_tree().process_frame
		await _snap(runner, dir, e[2])
	lab.cine = null
	lab.cat_i = 3
	lab._labels()
	for lv in [2, 3, 4]:
		lab.lv = lv
		lab.preview()
		var g := 0
		while g < 400 and not (lab.goal_show.active() and lab.goal_show.t > 0.9):
			g += 1
			await runner.get_tree().process_frame
		await _snap(runner, dir, "bc%d" % lv)
		lab.reset_preview()
		lab.cat_i = 3
		lab._labels()
		await runner.get_tree().process_frame
	Game.settings.dev_mode = false

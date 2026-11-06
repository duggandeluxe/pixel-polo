extends RefCounted
## Screenshots: each Goal Celebrations level at its peak, each Crowd Atmosphere level.
##   godot --path game -- --test goal_crowd_png <dir>   (needs a window)

static func run(runner, dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	runner.get_window().size = Vector2i(1440, 810)
	Game.settings.dev_mode = true
	Game.goto("visual_lab")
	for i in 3:
		await runner.get_tree().process_frame
	var lab = Game.current_screen
	lab.cat_i = 0
	lab._labels()
	for lv in [1, 2, 3, 4]:
		lab.lv = lv
		lab.preview()
		var g := 0
		while g < 400 and not (lab.goal_show.active() and lab.goal_show.t > 0.95):
			g += 1
			await runner.get_tree().process_frame
		await RenderingServer.frame_post_draw
		runner.get_viewport().get_texture().get_image().save_png("%s/goal_%d.png" % [dir, lv])
		lab.reset_preview()
		lab.cat_i = 0
		lab._labels()
		await runner.get_tree().process_frame
	lab.cat_i = 2
	lab._labels()
	for lv in [1, 2, 3, 4]:
		lab.lv = lv
		lab.preview()
		lab.cheer = 0.0
		for i in 12:
			await runner.get_tree().process_frame
		await RenderingServer.frame_post_draw
		runner.get_viewport().get_texture().get_image().save_png("%s/crowd_%d.png" % [dir, lv])
	Game.settings.dev_mode = false

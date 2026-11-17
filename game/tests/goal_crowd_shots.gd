extends RefCounted
## Screenshots: each Goal Celebration through its run (GOAL CELEBRATION PREVIEW), each Crowd Atmosphere level.
##   godot --path game -- --test goal_crowd_png <dir>   (needs a window)

static func run(runner, dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	runner.get_window().size = Vector2i(1440, 810)
	Game.settings.dev_mode = true
	# GOAL CELEBRATION PREVIEW: each celebration at a few moments, at each goal (and the
	# defending view), named celeb_<level>_<end>_<ms>.png
	Game.goto("celeb_lab")
	for i in 3:
		await runner.get_tree().process_frame
	var cl = Game.current_screen
	for n in 4:
		for e in ([0, 1, 2] if n == 3 else [0]):
			cl.sel = n
			cl.end_i = e
			cl._labels()
			cl._idle()
			await runner.get_tree().process_frame
			cl.preview()
			for at in [0.2, 0.45, 0.8, 1.4, 2.0]:
				while cl.goal_show.active() and cl.goal_show.t < at:
					cl._process(1.0 / 60.0)
				await RenderingServer.frame_post_draw
				runner.get_viewport().get_texture().get_image().save_png("%s/celeb_%d_%d_%04d.png" % [dir, n, e, int(at * 1000)])
	for n in [1, 2]:
		for e in [1, 2]:
			cl.sel = n
			cl.end_i = e
			cl._idle()
			await runner.get_tree().process_frame
			cl.preview()
			while cl.goal_show.active() and cl.goal_show.t < 0.45:
				cl._process(1.0 / 60.0)
			await RenderingServer.frame_post_draw
			runner.get_viewport().get_texture().get_image().save_png("%s/celeb_%d_%d_0450.png" % [dir, n, e])
	Game.goto("visual_lab")
	for i in 3:
		await runner.get_tree().process_frame
	var lab = Game.current_screen
	lab.cat_i = 2
	lab._labels()
	for lv in [1, 2, 3]:
		lab.lv = lv
		lab.preview()
		lab.cheer = 0.0
		for i in 12:
			await runner.get_tree().process_frame
		await RenderingServer.frame_post_draw
		runner.get_viewport().get_texture().get_image().save_png("%s/crowd_%d.png" % [dir, lv])
	Game.settings.dev_mode = false

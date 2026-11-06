extends RefCounted
## Screenshots of a real goal's replay at each level, in the lab.
##   godot --path game -- --test replay_png <dir>   (needs a window)

static func run(runner, dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	runner.get_window().size = Vector2i(1440, 810)
	Game.settings.dev_mode = true
	Game.goto("visual_lab")
	for i in 3:
		await runner.get_tree().process_frame
	var lab = Game.current_screen
	lab.bar_goal = true
	lab._labels()
	lab.lv = 2
	lab.preview()
	var g := 0
	while lab.show == null and g < 3000:
		g += 1
		await runner.get_tree().process_frame
	for lv in [2, 3, 4]:
		lab.queue = [lv]
		lab._next_show()
		var s: ReplayShow = lab.show
		var n := 0
		var got := {}
		var mid := int(s.clip.shot) + (int(s.clip.net) - int(s.clip.shot)) / 2
		while not s.done and n < 1500:
			n += 1
			await runner.get_tree().process_frame
			var key := ""
			if s.frozen():
				key = "freeze"
			elif s.frame_index() >= mid and s.cam_mode() != "rec" or (lv == 2 and s.frame_index() >= mid):
				key = "shot"
			if key != "" and not got.has(key):
				got[key] = true
				await RenderingServer.frame_post_draw
				runner.get_viewport().get_texture().get_image().save_png("%s/lv%d_%s.png" % [dir, lv, key])
		lab.show = null
	Game.settings.dev_mode = false

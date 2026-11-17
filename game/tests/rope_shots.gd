extends RefCounted
## Screenshots of the floating side ropes (PoolArt._rope) on a real match screen: close up at the
## top and bottom of the pool, round both goals, mirrored (defending), and pulled back to the whole pool; each at two
## moments of the bob.
##   godot --path game -- --test rope_png <outdir>   (needs a window)

static func run(runner, dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	Game.match_cfg = {"us": League.make_team(2, 1), "them": League.make_team(3, 1), "seed": 9, "minutes": 2.0, "autoplay": false}
	Game.goto("match", Game.match_cfg)
	for _i in 3:
		await runner.get_tree().process_frame
	var ms = Game.current_screen
	ms.flow._start_attack(Play.Kind.HALF_COURT)
	await runner.get_tree().process_frame
	Engine.time_scale = 0.0
	var shots := {"top_right": [Vector2(24.0, 0.0), 1.0, false], "bottom_right": [Vector2(24.0, 20.0), 1.0, false],
		"top_mid": [Vector2(15.0, 0.0), 1.0, false], "bottom_left": [Vector2(4.0, 20.0), 1.0, true],
		"goal_left": [Vector2(2.0, 10.0), 1.0, false], "goal_right": [Vector2(28.0, 10.0), 1.0, false],
		"wide": [Vector2(15.0, 10.0), 0.0, false]}
	for name in shots:
		var s: Array = shots[name]
		ms.view.mirror = s[2]
		if s[1] == 0.0:
			ms.view.wide(true)
		else:
			ms.view.zoom_to = 1.0
			ms.view.zoom = 1.0
		for tt in [0.0, 0.7]:
			ms.t = 3.0 + tt
			ms.view.snap_to(s[0])
			ms.queue_redraw()
			await RenderingServer.frame_post_draw
			ms.view.snap_to(s[0])
			ms.queue_redraw()
			await RenderingServer.frame_post_draw
			runner.get_viewport().get_texture().get_image().save_png("%s/%s_%d.png" % [dir, name, int(tt * 10)])
	Engine.time_scale = 1.0
	Game.goto("title")

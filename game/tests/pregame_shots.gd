extends RefCounted
## Screenshots of the pregame entrance in a real match screen: every stage, a few schools,
## Reduce Motion.
##   godot --path game -- --test pregame_png <outdir>   (needs a window)

static func run(runner, dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	runner.get_window().size = Vector2i(1440, 810)
	var c := Career.new_setup(779)
	var ts: Array = c.teams.values()
	for pair in [[0, 1], [5, 9]]:
		Game.match_cfg = {"us": ts[pair[0]], "them": ts[pair[1]], "seed": 9, "minutes": 2.0, "home": true, "intro": true,
			"stage": "NCSA CHAMPIONSHIP" if pair[0] == 5 else "REGULAR SEASON", "venue": Colleges.venue_name(ts[pair[0]].id)}
		Game.goto("match", Game.match_cfg)
		for i in 3:
			await runner.get_tree().process_frame
		var ms = Game.current_screen
		for at in [0.3, 1.0, 1.4, 1.9, 2.3, 2.6, 3.1, 3.6, 4.1]:
			ms.intro.hold = at
			ms.intro.t = at
			for i in 2:
				await runner.get_tree().process_frame
			await RenderingServer.frame_post_draw
			runner.get_viewport().get_texture().get_image().save_png("%s/intro_%d_%03d.png" % [dir, pair[0], int(at * 100)])
	Game.settings.reduce_motion = true
	Game.match_cfg["intro"] = true
	Game.goto("match", Game.match_cfg)
	for i in 3:
		await runner.get_tree().process_frame
	var cm = Game.current_screen
	for at in [0.3, 0.8, 1.5]:
		cm.intro.hold = at
		cm.intro.t = at
		for i in 2:
			await runner.get_tree().process_frame
		await RenderingServer.frame_post_draw
		runner.get_viewport().get_texture().get_image().save_png("%s/intro_calm_%03d.png" % [dir, int(at * 100)])
	Game.settings.reduce_motion = false

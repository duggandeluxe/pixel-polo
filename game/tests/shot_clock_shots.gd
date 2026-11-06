extends RefCounted
## Screenshots of the shot clock (Hud.shot_clock) on a real match screen: 12, 6, then the final
## five's red heartbeat (each second's pop and ease down) and 0.
##   godot --path game -- --test shot_clock_png <outdir>   (needs a window)

static func run(runner, dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	Game.match_cfg = {"us": League.make_team(2, 1), "them": League.make_team(3, 1), "seed": 9, "minutes": 2.0, "autoplay": false}
	Game.goto("match", Game.match_cfg)
	var ms = Game.current_screen
	for _i in 3:
		await runner.get_tree().process_frame
	ms.flow._start_attack(Play.Kind.HALF_COURT)
	await runner.get_tree().process_frame
	Engine.time_scale = 0.0   # (the play held still: each shot at exactly its time)
	for secs in [12.0, 6.0, 5.0, 4.95, 4.9, 4.8, 4.75, 4.2, 3.0, 2.0, 1.0, 0.4, 0.0]:
		var p: Play = ms.flow.play
		p.shot_clock = secs
		ms.queue_redraw()
		await RenderingServer.frame_post_draw
		p.shot_clock = secs
		ms.queue_redraw()
		await RenderingServer.frame_post_draw
		runner.get_viewport().get_texture().get_image().save_png("%s/sc_%05.2f.png" % [dir, secs])
	Engine.time_scale = 1.0
	Game.goto("title")

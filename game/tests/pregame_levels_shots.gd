extends RefCounted
## Screenshots of the three Pregame Presentation levels at their key moments in a real match screen
## (the plain doors, Level 2's logo hall, Level 3's dark corridor and the flash).
##   godot --path game -- --test pregame_levels_png <outdir>   (needs a window)

const TIMES := {1: [0.3, 1.15, 2.3, 3.1, 4.2], 2: [0.3, 1.15, 2.3, 3.1, 4.2],
	3: [0.0, 0.6, 1.2, 1.7, 2.1, 2.75, 3.15, 3.95, 4.3, 5.6]}

static func run(runner, dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	runner.get_window().size = Vector2i(960, 540)
	Game.settings.reduce_motion = false
	var c := Career.new_setup(779)
	var ts: Array = c.teams.values()
	Store.reset_for_tests()
	for lv: int in TIMES:
		Store.looks.unlocked["pregame"] = lv
		Store.looks.equipped["pregame"] = lv
		Game.match_cfg = {"us": ts[0], "them": ts[1], "seed": 9, "minutes": 2.0, "home": true, "intro": true,
			"stage": "REGULAR SEASON", "venue": Colleges.venue_name(ts[0].id)}
		Game.goto("match", Game.match_cfg)
		for i in 3:
			await runner.get_tree().process_frame
		var ms = Game.current_screen
		for at: float in TIMES[lv]:
			ms.intro.hold = at
			ms.intro.t = at
			for i in 2:
				await runner.get_tree().process_frame
			await RenderingServer.frame_post_draw
			runner.get_viewport().get_texture().get_image().save_png("%s/L%d_%04d.png" % [dir, lv, int(at * 100)])
			print("L%d t=%.2f %s" % [lv, at, ms.intro.stage()])
	Store.reset_for_tests()
	Game.goto("title")

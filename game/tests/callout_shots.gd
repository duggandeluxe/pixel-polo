extends RefCounted
## Screenshots of the top-of-screen callouts (EventBanner, drawn in BAR-DOWN!'s style by
## Hud.callout) on a real match screen: each named event settled, plus GOAL!'s burst, hold and
## exit, and a long plain one, at 16:9, a wide phone and 4:3.
##   godot --path game -- --test callout_png <outdir>   (needs a window)

const SIZES := {"169": Vector2i(1280, 720), "phone": Vector2i(1560, 720), "43": Vector2i(960, 720)}

static func run(runner, dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	Game.match_cfg = {"us": League.make_team(2, 1), "them": League.make_team(3, 1), "seed": 9, "minutes": 2.0, "autoplay": false}
	Game.goto("match", Game.match_cfg)
	await runner.get_tree().process_frame
	var ms = Game.current_screen
	for _i in 3:
		await runner.get_tree().process_frame
	var shots := []
	for k in ["steal", "block", "save", "foul", "penalty", "turnover", "exclusion"]:
		shots.append([k, k, 0.5])
	for t in [0.04, 0.1, 0.2, 0.5, 0.9]:
		shots.append(["goal_%03d" % int(t * 100), "goal", t])
	shots.append(["long", "", 0.5])
	for sz: String in SIZES:
		runner.get_window().size = SIZES[sz]
		for s: Array in shots:
			if s[1] == "":
				ms.banner.show("HE'S SHOOTING!", EventBanner.RED)
			else:
				ms.banner.event(String(s[1]))
			ms.banner.cur.t = float(s[2])
			ms.banner.cur["dur"] = 99.0 if float(s[2]) < 0.8 else 1.0   # (held there while the frame draws)
			ms.banner.queued = {}
			await runner.get_tree().process_frame
			if not ms.banner.is_empty():
				ms.banner.cur.t = float(s[2])
			ms.queue_redraw()
			await RenderingServer.frame_post_draw
			runner.get_viewport().get_texture().get_image().save_png("%s/callout_%s_%s.png" % [dir, sz, s[0]])
			ms.banner.clear()
	Game.goto("title")

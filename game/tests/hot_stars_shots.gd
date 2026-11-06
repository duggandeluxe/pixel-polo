extends RefCounted
## Screenshots for the Hot Star Gameplay & Scouting Overhaul: the SCOUTING REPORT, HOT STAR
## TESTING's previews (0 / 1 / 2 Hot Stars shooting, the spark ring, a keeper, calm) and a real match with hot men on
## both sides.
##   godot --path game -- --test hot_stars_png <outdir>   (needs a window)

static func _shot(runner, dir: String, name: String, frames: int = 2) -> void:
	for i in frames:
		await runner.get_tree().process_frame
	await RenderingServer.frame_post_draw
	runner.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [dir, name])

static func run(runner, dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	runner.get_window().size = Vector2i(1440, 810)
	Store.reset_for_tests()
	var c := Career.new_game("GWU", "Hot", "Shots", 41)
	c.queue.clear()
	Game.career = c
	Game.goto("scout")
	await _shot(runner, dir, "scout", 4)
	# the lab
	Game.settings.dev_mode = true
	Game.goto("hot_star_lab")
	await _shot(runner, dir, "lab_0", 4)
	var lab = Game.current_screen
	lab.select(3)
	for lv in [0, 1, 2]:
		lab.preview_stars(lv)
		for i in 16:
			await runner.get_tree().process_frame
		lab.paused = true
		await _shot(runner, dir, "lab_stars_%d" % lv, 1)
	lab.set_stars(2)
	await _shot(runner, dir, "lab_ring_2", 3)
	lab.select(0)
	lab.set_stars(2)
	await _shot(runner, dir, "lab_keeper_2", 3)
	lab.select(3)
	lab.set_stars(2)
	lab.still = true
	lab._labels()
	await _shot(runner, dir, "lab_calm_2", 3)
	Game.settings.dev_mode = false
	# a real match: hot men on both sides
	var us := League.make_team(2, 1)
	var them := League.make_team(3, 1)
	var seven := us.starters()
	seven[3].heat = 2
	seven[1].heat = 1
	seven[0].heat = 2
	them.starters()[2].heat = 1
	them.starters()[4].heat = 2
	Game.match_cfg = {"us": us, "them": them, "seed": 9, "minutes": 2.0, "autoplay": true}
	Game.goto("match", Game.match_cfg)
	var ms = Game.current_screen
	for i in 3:
		await runner.get_tree().process_frame
	var n := 0
	for f in 900:
		await runner.get_tree().process_frame
		if f % 60 == 30 and n < 8:
			await RenderingServer.frame_post_draw
			runner.get_viewport().get_texture().get_image().save_png("%s/match_%d.png" % [dir, n])
			n += 1
		var b: Ball = ms.flow.play.ball if ms.flow.play != null else null
		if b != null and b.state == Ball.State.SHOT and HotFire.level_of(b.shooter) > 0 and b.t > 0.3 and n < 12:
			await RenderingServer.frame_post_draw
			runner.get_viewport().get_texture().get_image().save_png("%s/match_shot_%d.png" % [dir, n])
			n += 1
	Game.career = null

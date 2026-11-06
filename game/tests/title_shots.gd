extends RefCounted
## The title's highlight reel and logo, a frame every so often (needs a window).
##   godot --path game -- --test title_png <dir>
static func run(runner, out: String) -> void:
	DirAccess.make_dir_recursive_absolute(out)
	var tree: SceneTree = runner.get_tree()
	Game.goto("title")
	var shots := 0
	var t0 := Time.get_ticks_msec()
	var goals := 0
	var scenes := 0
	var last_scene := 0
	var was_scored := false
	while Time.get_ticks_msec() - t0 < 40000:
		await tree.create_timer(0.1).timeout
		var scr = Game.current_screen
		if scr.scene_no != last_scene:
			last_scene = scr.scene_no
			scenes += 1
		if scr.scored and not was_scored:
			goals += 1
		was_scored = scr.scored
		var want: bool = shots < 10 and (scr.demo.ball.state == Ball.State.SHOT or (Time.get_ticks_msec() - t0) > (shots + 1) * 3500)
		if want:
			await RenderingServer.frame_post_draw
			runner.get_viewport().get_texture().get_image().save_png(out.path_join("title_%02d.png" % shots))
			shots += 1
			await tree.create_timer(0.6).timeout
	print("  40 s of the reel: %d scenes, %d goals, %d shots saved" % [scenes, goals, shots])

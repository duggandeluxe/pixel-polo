extends RefCounted
## Screenshot tour of SIM TO END on the real match screen: the career pause menu, the confirmation
## popup, then full time straight away (no simulating screen). Needs a window:
##   godot --path game -- --test sim_end_png <dir>

static func run(runner: Node, out: String) -> void:
	DirAccess.make_dir_recursive_absolute(out)
	var tree := runner.get_tree()
	Game.career = Career.new_game("WAGN", "A", "B", 77)
	var c := Game.career
	var cfg := {"us": c.team(), "them": c.opponent(), "seed": 45, "career": true, "home": c.is_home()}
	Game.match_cfg = cfg
	Game.goto("match", cfg)
	await tree.create_timer(0.3).timeout
	var ms = Game.current_screen
	var f: MatchFlow = ms.flow
	ms.flow.auto_keeper = 0.5
	while not (f.phase == MatchFlow.Phase.ATTACK and f.play != null and f.play.elapsed > 2.0):
		await tree.process_frame
	ms._pause()
	await tree.create_timer(0.3).timeout
	await _shot(runner, out, "1_pause_menu")
	_press("SIM TO END")
	await tree.create_timer(0.3).timeout
	await _shot(runner, out, "2_confirm")
	_press("SIM TO END")
	print("  sim to end: %.2f ms" % ms.sim_end_ms)
	await _shot(runner, out, "3_full_time_at_once")
	await tree.create_timer(1.5).timeout
	await _shot(runner, out, "4_full_time")
	Game.career = null

static func _press(text: String) -> void:
	for b in Game.overlay.get_child(Game.overlay.get_child_count() - 1).find_children("*", "Button", true, false):
		if b.text == text:
			b.pressed.emit()
			return

static func _shot(runner: Node, out: String, name: String) -> void:
	await RenderingServer.frame_post_draw
	runner.get_viewport().get_texture().get_image().save_png(out.path_join(name + ".png"))
	print("  ", name)

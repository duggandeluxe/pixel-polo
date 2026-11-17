extends RefCounted
## Screenshot tour of LIVE SIM on the real match screen: the pause menu with SIM, the switch-on,
## the broadcast at speed, a goal slowed down, SIM's own pause menu, and play handed back; then the
## game preview's three buttons and the summary its SIM TO END goes straight to. Needs a
## window:
##   godot --path game -- --test sim_png <dir>

static func run(runner: Node, out: String) -> void:
	DirAccess.make_dir_recursive_absolute(out)
	var tree := runner.get_tree()
	Game.career = Career.new_game("WAGN", "A", "B", 77)
	var c := Game.career
	var cfg := {"us": c.team(), "them": c.opponent(), "seed": 45, "minutes": 2.0, "career": true, "home": c.is_home()}
	Game.match_cfg = cfg
	Game.goto("match", cfg)
	await tree.create_timer(0.3).timeout
	var ms = Game.current_screen
	var f: MatchFlow = ms.flow
	ms.flow.auto_keeper = 0.5
	while not (f.phase == MatchFlow.Phase.ATTACK and f.play != null and f.play.elapsed > 2.0):
		if f.phase == MatchFlow.Phase.BREAK:
			f.break_done()
		await tree.process_frame
	ms._pause()
	await tree.create_timer(0.3).timeout
	await _shot(runner, out, "1_pause_menu")
	for b in Game.overlay.get_child(Game.overlay.get_child_count() - 1).find_children("*", "Button", true, false):
		if b.text == "SIM":
			b.pressed.emit()
	await tree.create_timer(0.12).timeout
	await _shot(runner, out, "2_switch_on")
	await tree.create_timer(1.5).timeout
	await _shot(runner, out, "3_broadcast")
	while not ms.goal_show.active():
		await tree.process_frame
	await tree.create_timer(0.5).timeout
	await _shot(runner, out, "4_goal_slowed")
	await tree.create_timer(0.5).timeout
	await _shot(runner, out, "5_goal_board")
	await tree.create_timer(2.0).timeout
	ms._sim_pause()
	await tree.create_timer(0.3).timeout
	await _shot(runner, out, "6_sim_pause")
	for b in Game.overlay.get_child(Game.overlay.get_child_count() - 1).find_children("*", "Button", true, false):
		if b.text == "RETURN TO GAME":
			b.pressed.emit()
	while ms.sim:
		await tree.process_frame
	await tree.create_timer(0.3).timeout
	await _shot(runner, out, "7_back_to_game")
	# the game preview's PLAY GAME | START IN SIM | SIM TO END, then SIM TO END's summary
	Store.reset_for_tests()
	Store.starter_offered = true
	Game.career = Career.new_game("WAGN", "A", "B", 83)
	c = Game.career
	c.queue.clear()
	var guard := 0
	while not c.has_game() and guard < 5:
		guard += 1
		c.end_week()
	for q in c.upgrades_due():
		Development.ai_spend(q)
	Game.goto("matchup")
	await tree.create_timer(0.4).timeout
	await _shot(runner, out, "8_preview")
	(Game.current_screen.find_child("SimToEnd", true, false) as Button).pressed.emit()
	await tree.create_timer(0.6).timeout
	await _shot(runner, out, "9_sim_to_end_summary")
	Game.career = null

static func _shot(runner: Node, out: String, name: String) -> void:
	await RenderingServer.frame_post_draw
	runner.get_viewport().get_texture().get_image().save_png(out.path_join(name + ".png"))
	print("  ", name)

extends RefCounted
## Screenshot tour of penalties: the 5 m formation (in the match camera and the whole pool), a
## shootout penalty (only the shooter and the keeper), and their keeper's guess, caught mid-dive
## each way. Needs a window:  godot --path game -- --test penalty_png <dir>

static func run(runner: Node, out: String) -> void:
	DirAccess.make_dir_recursive_absolute(out)
	var tree := runner.get_tree()
	var cfg := {"us": League.make_team(3), "them": League.make_team(0), "seed": 21, "minutes": 3.0}
	Game.match_cfg = cfg
	Game.goto("match", cfg)
	await tree.create_timer(0.5).timeout
	var screen = Game.current_screen
	var flow: MatchFlow = screen.flow
	# 1) a 5 m penalty in the game
	flow._start_attack(Play.Kind.PENALTY)
	await tree.create_timer(0.6).timeout
	await _shot(runner, out, "1_penalty_formation")
	screen.view.wide(true)
	screen.view.snap_to(Vector2(Geo.LENGTH * 0.5 + 2.0, Geo.GOAL_Y))
	await tree.create_timer(0.1).timeout
	await _shot(runner, out, "1b_penalty_formation_whole_pool")
	# 2) a shootout penalty: just the shooter and their keeper
	flow.state.in_shootout = true
	flow._start_attack(Play.Kind.PENALTY)
	await tree.create_timer(0.7).timeout
	await _shot(runner, out, "2_shootout")
	# 3, 4) their keeper guesses at the release; keep taking the same penalty (at the same
	# corner) until he has gone each way, and catch him mid-dive
	flow.state.in_shootout = false
	for want in [-1.0, 1.0]:
		var name := "3_keeper_dives_left" if want < 0.0 else "4_keeper_dives_right"
		for attempt in 30:
			flow._start_attack(Play.Kind.PENALTY)
			await tree.create_timer(0.25).timeout
			var p: Play = flow.play
			Engine.time_scale = 0.08
			p.shoot_at(Vector2(Geo.GOAL_X, Geo.GOAL_Y - 1.25), 0.8)
			if float(p.ball.shot.guess) != want:
				Engine.time_scale = 1.0
				continue
			await _wait_for(tree, func(): return p.ball.state != Ball.State.SHOT or p.ball.t >= 0.85)
			await _shot(runner, out, name)
			Engine.time_scale = 1.0
			print("    (%s: aimed at the top corner, keeper guessed %s, %s)" % [name, "up" if want < 0.0 else "down", String(p.ball.shot.outcome)])
			break
		await tree.create_timer(0.3).timeout
	Engine.time_scale = 1.0
	# 5) their 5 m penalty, at your goal: the same formation, mirrored
	flow._start_defense(Play.Kind.PENALTY)
	flow.opp_hold = -99.0   # (he holds it for the picture)
	await tree.create_timer(0.6).timeout
	await _shot(runner, out, "5_their_penalty_formation")

static func _wait_for(tree: SceneTree, cond: Callable, limit: float = 6000.0) -> void:
	var n := 0.0
	while not cond.call() and n < limit:
		await tree.process_frame
		n += 1.0

static func _shot(runner: Node, out: String, name: String) -> void:
	await RenderingServer.frame_post_draw
	runner.get_viewport().get_texture().get_image().save_png(out.path_join(name + ".png"))
	print("  shot ", name)

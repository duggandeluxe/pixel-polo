extends RefCounted
## Screenshot tour of a goal: the ball over the line, against the back of the net, the GOAL!
## callout, a goal in your own net (the other end), and the quarter-break card. Needs a window:
##   godot --path game -- --test goal_png <dir>

static func run(runner: Node, out: String) -> void:
	DirAccess.make_dir_recursive_absolute(out)
	var tree := runner.get_tree()
	var cfg := {"us": League.make_team(3), "them": League.make_team(0), "seed": 11, "minutes": 3.0, "autoplay": true}
	Game.match_cfg = cfg
	Game.goto("match", cfg)
	await tree.create_timer(0.5).timeout
	var screen = Game.current_screen
	# your goal, at the right-hand end
	Engine.time_scale = 6.0
	await _wait_for(tree, func(): return _scoring(screen, MatchFlow.Phase.ATTACK))
	Engine.time_scale = 0.05
	await _wait_for(tree, func(): return screen.flow.play.ball.in_net())
	await _shot(runner, out, "goal_1_entering")
	await _wait_for(tree, func(): return screen.flow.play.ball.net_t >= 0.035)
	await _shot(runner, out, "goal_2_back_of_net")
	Engine.time_scale = 1.0
	await _wait_for(tree, func(): return screen.goal_show.active() and screen.goal_show.t >= 0.9)
	await _shot(runner, out, "goal_3_banner")
	# theirs, in your goal at the left-hand end (your bot keeper stays put): fast forward, but
	# slow down whenever they're shooting
	screen.flow.auto_keeper = 0.0
	var theirs := func():
		var f = screen.flow
		if f.phase == MatchFlow.Phase.BREAK and not f.state.is_last_quarter():
			f.break_done()
		var shooting: bool = f.phase == MatchFlow.Phase.DEFENSE and f.play != null and (f.duel != null or f.play.ball.state == Ball.State.SHOT)
		Engine.time_scale = 0.2 if shooting else 6.0
		return f.phase == MatchFlow.Phase.FINAL or (f.phase == MatchFlow.Phase.DEFENSE and f.play != null and f.play.ball.in_net())
	await _wait_for(tree, theirs, 20000.0)
	Engine.time_scale = 0.05
	await _wait_for(tree, func(): return screen.flow.play.ball.net_t >= 0.035)
	await _shot(runner, out, "goal_4_their_goal_back_of_net")
	Engine.time_scale = 1.0
	await _wait_for(tree, func(): return screen.goal_show.active() and screen.goal_show.t >= 0.9)
	await _shot(runner, out, "goal_5_their_goal_banner")
	# the next quarter break
	Engine.time_scale = 8.0
	await _wait_for(tree, func(): return screen.flow.phase == MatchFlow.Phase.BREAK)
	Engine.time_scale = 1.0
	await tree.create_timer(0.2).timeout
	await _shot(runner, out, "quarter_end_q%d" % screen.flow.state.quarter)

## A shot of yours on its way in that's a goal.
static func _scoring(screen, phase: int) -> bool:
	var p: Play = screen.flow.play
	if screen.flow.phase != phase or p == null or p.ball.state != Ball.State.SHOT:
		return false
	return String(p.ball.shot.get("outcome", "")) == "goal"

static func _wait_for(tree: SceneTree, cond: Callable, limit: float = 6000.0) -> void:
	var n := 0.0
	while not cond.call() and n < limit:
		await tree.process_frame
		n += 1.0

static func _shot(runner: Node, out: String, name: String) -> void:
	await RenderingServer.frame_post_draw
	runner.get_viewport().get_texture().get_image().save_png(out.path_join(name + ".png"))
	print("  shot ", name)

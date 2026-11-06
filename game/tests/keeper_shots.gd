extends RefCounted
## Screenshot tour of your keeper in their live attacks (the real match screen, real shots):
## tracking the ball, a LEFT lunge and a RIGHT lunge at full stretch, a CENTRE block, a corner
## shot saved at the moment it hits his hand (the dive timed), then a dive that's gone too soon:
## falling back into the water, and bobbing back up. Needs a window:
##   godot --path game -- --test keeper_png <dir>

static func run(runner: Node, out: String) -> void:
	DirAccess.make_dir_recursive_absolute(out)
	var tree := runner.get_tree()
	# autoplay keeps the coaching tips off the pictures; the keeper is still yours (auto_keeper -1)
	var cfg := {"us": League.make_team(3), "them": League.make_team(0), "seed": 33, "minutes": 8.0, "autoplay": true}
	Game.match_cfg = cfg
	Game.goto("match", cfg)
	await tree.create_timer(0.5).timeout
	var screen = Game.current_screen
	var flow: MatchFlow = screen.flow
	flow.auto_keeper = -1.0
	# 1) tracking: the ball out on a wing, your keeper shaded towards it
	await _defend(flow, tree)
	Engine.time_scale = 3.0
	await _wait_for(tree, func(): return flow.phase == MatchFlow.Phase.DEFENSE and flow.duel == null \
		and flow.play.ball.state == Ball.State.HELD and absf(flow.play.keeper.pos.y - Geo.GOAL_Y) > 0.3)
	Engine.time_scale = 1.0
	await _shot(runner, out, "keeper_1_tracking")
	print("    (tracking: ball at y %.1f, keeper %.2f m off the middle)" % [flow.play.ball.pos.y, flow.play.keeper.pos.y - Geo.GOAL_Y])
	# 2-4) a dive of each kind at a real shot, caught at full stretch
	for job in [[KeeperDive.LEFT, "keeper_2_lunge_left"], [KeeperDive.RIGHT, "keeper_3_lunge_right"], [KeeperDive.CENTRE, "keeper_4_centre_block"]]:
		await _next_duel(flow, tree, func(_d: KeeperDuel): return true)
		screen._press(_zone_point(screen, job[0]), 0)   # a real tap on that third of the goal
		Engine.time_scale = 0.1
		await _wait_for(tree, func(): return flow.play.keeper.pose != null and flow.play.keeper.pose.t >= flow.play.keeper.pose.extend_time())
		await _shot(runner, out, job[1])
		print("    (%s: side %d, stretch %.2f at %.3f s)" % [job[1], flow.play.keeper.pose.side, flow.play.keeper.pose.ext(), flow.play.keeper.pose.t])
		Engine.time_scale = 1.0
	# 5) a corner shot, the right way, saved: the frame it meets his hand
	for attempt in 40:
		await _next_duel(flow, tree, func(d: KeeperDuel): return absf(d.cross_y - Geo.GOAL_Y) > 0.9)
		var d := flow.duel
		var side := KeeperDive.LEFT if d.cross_y < Geo.GOAL_Y else KeeperDive.RIGHT
		Engine.time_scale = 0.5
		await _wait_for(tree, func(): return d.done() or d.t >= d.flight - d.ideal_up(0.3) * d.slowmo)
		screen._press(_zone_point(screen, side), 0)
		Engine.time_scale = 0.15
		await _wait_for(tree, func(): return flow.duel == null or flow.duel.done())
		var pose: KeeperDive = flow.play.keeper.pose
		if pose != null and pose.hit_t >= 0.0:
			Engine.time_scale = 0.05
			await tree.process_frame
			await _shot(runner, out, "keeper_5_corner_save")
			print("    (corner save: ball at %+.2f m, keeper dived %s, attempt %d)" % [pose.hit_y - Geo.GOAL_Y, "LEFT" if side < 0 else "RIGHT", attempt + 1])
			break
		Engine.time_scale = 1.0
	Engine.time_scale = 1.0
	# 6-7) gone too soon: tap as the shot leaves his hand on a long one, and catch him falling back,
	# then bobbing up out of his ring
	for job in [[KeeperDive.Phase.FALL, "keeper_6_falling"], [KeeperDive.Phase.RECOVER, "keeper_7_recovering"]]:
		await _next_duel(flow, tree, func(d: KeeperDuel): return d.flight / d.slowmo > 0.8)
		screen._press(_zone_point(screen, KeeperDive.LEFT), 0)
		Engine.time_scale = 0.1
		var ph: int = job[0]
		await _wait_for(tree, func(): return flow.play.keeper.pose != null and flow.play.keeper.pose.phase() >= ph)
		var pose: KeeperDive = flow.play.keeper.pose
		await _shot(runner, out, job[1])
		print("    (%s: phase %d at %.3f s)" % [job[1], pose.phase() if pose != null else -1, pose.t if pose != null else -1.0])
		Engine.time_scale = 1.0
	Engine.time_scale = 1.0

## A fresh defence of yours (their half-court attack), whatever the match was doing.
static func _defend(flow: MatchFlow, tree: SceneTree) -> void:
	flow._start_defense(Play.Kind.HALF_COURT)
	await tree.process_frame

## Fast forward their attacks until a shot on target comes at your keeper that `want` likes.
static func _next_duel(flow: MatchFlow, tree: SceneTree, want: Callable) -> void:
	# (the last shot first: its duel over and his dive played out)
	await _wait_for(tree, func(): return flow.duel == null and flow.keeper_anim == null)
	for tries in 200:
		if flow.phase != MatchFlow.Phase.DEFENSE or flow.play == null or flow.play.over:
			await _defend(flow, tree)
		Engine.time_scale = 4.0
		await _wait_for(tree, func(): return flow.phase != MatchFlow.Phase.DEFENSE or flow.play.over or flow.duel != null, 3000.0)
		Engine.time_scale = 1.0
		if flow.phase == MatchFlow.Phase.DEFENSE and flow.duel != null and not flow.duel.done() and flow.keeper_anim == null:
			if want.call(flow.duel):
				return
			await _wait_for(tree, func(): return flow.duel == null)

## A screen point level with the middle of that third of your goal (at the height shots cross).
static func _zone_point(screen, side: int) -> Vector2:
	var y := Geo.GOAL_Y + side * Geo.GOAL_HALF * 0.66
	return screen.view.to_screen(Vector2(Geo.GOAL_X, y), KeeperDive.BALL_Z)

static func _wait_for(tree: SceneTree, cond: Callable, limit: float = 6000.0) -> void:
	var n := 0.0
	while not cond.call() and n < limit:
		await tree.process_frame
		n += 1.0

static func _shot(runner: Node, out: String, name: String) -> void:
	await RenderingServer.frame_post_draw
	var scr = Game.current_screen
	if scr != null and scr.flow.play != null:
		print("    keeper on screen at ", scr.view.to_screen(scr.flow.play.keeper.pos))
	runner.get_viewport().get_texture().get_image().save_png(out.path_join(name + ".png"))
	print("  shot ", name)

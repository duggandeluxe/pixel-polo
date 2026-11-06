extends RefCounted
## Screenshot tour: title, team picker, and a bot-played match (sprint, attack, aiming,
## their card, a break, the final). Needs a window:  godot --path game -- --test shots_png <dir>

static func run(runner: Node, out: String, _names: Array) -> void:
	DirAccess.make_dir_recursive_absolute(out)
	var tree := runner.get_tree()
	Game.goto("title")
	await tree.create_timer(2.5).timeout
	await _shot(runner, out, "01_title")
	Game.goto("quick_match")
	await tree.create_timer(0.4).timeout
	await _shot(runner, out, "02_quick_match")
	var cfg := {"us": League.make_team(3), "them": League.make_team(0), "seed": 5, "minutes": 2.0, "autoplay": true}
	Game.match_cfg = cfg
	Game.goto("match", cfg)
	await tree.create_timer(0.9).timeout
	await _shot(runner, out, "03_sprint_countdown")
	await tree.create_timer(1.6).timeout
	await _shot(runner, out, "04_sprint_race")
	var screen = Game.current_screen
	await _wait_for(tree, func(): return screen.flow.phase == MatchFlow.Phase.ATTACK and screen.flow.play.can_throw() and screen.flow.play.elapsed > 2.0)
	screen.autoplay = false
	await _shot(runner, out, "05_attack")
	# the DRIVE call strip
	screen.calls.open = true
	await tree.create_timer(0.15).timeout
	await _shot(runner, out, "05b_drive_call")
	screen.calls.open = false
	# aim a shot at the far corner
	var p: Play = screen.flow.play
	var far_y := Geo.GOAL_Y + (1.1 if p.keeper.pos.y < Geo.GOAL_Y else -1.1)
	_aim_at(screen, Vector2(Geo.GOAL_X + 0.5, far_y))
	await tree.create_timer(0.1).timeout
	await _shot(runner, out, "06_aim_shot")
	# then a pass to the most open teammate, tapped: a pull never passes
	var best: Swimmer = null
	for a in p.attackers:
		if a != p.holder and (best == null or p.openness(a) > p.openness(best)):
			best = a
	var tap_at: Vector2 = screen.view.to_screen(best.pos) + Vector2(0, -4)
	screen.aim.begin(0, tap_at)
	screen._release()
	await tree.create_timer(0.35).timeout
	await _shot(runner, out, "08_pass_flight")
	screen.autoplay = true
	Engine.time_scale = 4.0
	await _wait_for(tree, func(): return screen.flow.play.over and screen.end_timer > 0.0)
	Engine.time_scale = 1.0
	await tree.create_timer(0.3).timeout
	await _shot(runner, out, "09_result_banner")
	Engine.time_scale = 4.0
	await _wait_for(tree, func(): return screen.flow.phase == MatchFlow.Phase.DEFENSE and screen.flow.play.elapsed > 2.5)
	Engine.time_scale = 1.0
	await _shot(runner, out, "10_defense")
	Engine.time_scale = 3.0
	await _wait_for(tree, func(): return screen.flow.duel != null and screen.flow.phase == MatchFlow.Phase.DEFENSE)
	Engine.time_scale = 1.0
	await tree.create_timer(0.15).timeout
	await _shot(runner, out, "10b_their_shot")
	Engine.time_scale = 6.0
	await _wait_for(tree, func(): return screen.flow.phase == MatchFlow.Phase.BREAK)
	Engine.time_scale = 1.0
	await tree.create_timer(0.2).timeout
	await _shot(runner, out, "11_break")
	# play the rest of the match on fast forward, tapping through the breaks
	Engine.time_scale = 8.0
	while screen.flow.phase != MatchFlow.Phase.FINAL:
		if screen.flow.phase == MatchFlow.Phase.BREAK:
			screen.flow.break_done()
		await tree.process_frame
	Engine.time_scale = 1.0
	await tree.create_timer(0.3).timeout
	await _shot(runner, out, "12_final")

## The shooting stick held pulled back to aim at `world` (ShotStick.knob_for): the only way to aim.
static func _aim_at(screen, world: Vector2) -> void:
	var p: Play = screen.flow.play
	var start: Vector2 = screen.stick.rest
	screen.aim.begin(0, start, true)
	screen.stick.take(start)
	screen.stick.drag(start + ShotStick.knob_for(p.holder.pos, world))

static func _wait_for(tree: SceneTree, cond: Callable, limit: float = 600.0) -> void:
	var waited := 0.0
	while not cond.call() and waited < limit:
		await tree.process_frame
		waited += 1.0 / 60.0

static func _shot(runner: Node, out: String, name: String) -> void:
	await RenderingServer.frame_post_draw
	runner.get_viewport().get_texture().get_image().save_png(out + "/" + name + ".png")
	print("shot " + name)

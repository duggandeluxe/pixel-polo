extends RefCounted
## Screenshot tour of their keeper on your shots (the real match screen, real shots): his lean on
## a long hold, a reaction dive the way the ball went, and a panic (committed the wrong way,
## clawing back). Needs a window:
##   godot --path game -- --test ai_keeper_png <dir>

static func run(runner: Node, out: String) -> void:
	DirAccess.make_dir_recursive_absolute(out)
	var tree := runner.get_tree()
	var cfg := {"us": League.make_team(3), "them": League.make_team(0), "seed": 41, "minutes": 8.0, "autoplay": true}
	Game.match_cfg = cfg
	Game.goto("match", cfg)
	await tree.create_timer(0.5).timeout
	var screen = Game.current_screen
	var flow: MatchFlow = screen.flow
	var got := {}
	for attempt in 400:
		if got.size() >= 3:
			break
		flow._start_attack(Play.Kind.HALF_COURT)
		var p := flow.play
		p.drive_timer = 99.0
		var shooter := PlaySetup._by_tag(p, "3")
		p.give_ball(shooter)
		shooter.pos = Vector2(25.0, 10.0 + (attempt % 3 - 1) * 0.6)
		shooter.target = shooter.pos
		for d in p.defenders:
			if d.pos.distance_to(shooter.pos) < 3.0:
				d.pos = Vector2(18.0, d.pos.y)
				d.target = d.pos
		# a long look at him: he reads it and leans
		p.hold_t = 1.8
		var t := 0.0
		while t < 0.4:
			await tree.process_frame
			t += 1.0 / 60.0
		if p.over or p.holder != shooter:
			continue
		if not got.has("lean") and p.gk_read != KeeperAI.NO_READ and p.gk_read != KeeperDive.CENTRE:
			await _shot(runner, out, "ai_keeper_1_lean")
			print("    (lean: read %d, keeper %.2f m off the middle)" % [p.gk_read, p.keeper.pos.y - Geo.GOAL_Y])
			got["lean"] = true
		var away := -1.0 if p.gk_read == KeeperDive.RIGHT else 1.0
		p.shoot_at(Vector2(Geo.GOAL_X, Geo.GOAL_Y + away * 1.15), 0.7)
		if p.ball.state != Ball.State.SHOT:
			continue
		var kind := String(p.ball.shot.get("gk", {}).get("kind", ""))
		var want := ""
		if kind == "panic" and not got.has("panic"):
			want = "panic"
		elif kind == "react" and not got.has("react") and int(p.ball.shot.guess) != KeeperDive.CENTRE:
			want = "react"
		Engine.time_scale = 0.1 if want != "" else 4.0
		var n := 0
		while not p.over and n < 3000:
			await tree.process_frame
			n += 1
			var pose := p.keeper.pose
			if want == "panic" and pose != null and pose.phase() == KeeperDive.Phase.PANIC and pose.t - pose.turn_t > 0.1:
				await _shot(runner, out, "ai_keeper_3_panic")
				print("    (panic: went %d, clawing back %+.0f, commitment %d, body %+.2f)" % [pose.side, pose.turn_dir(), pose.panic_commit(), pose.body_y() - Geo.GOAL_Y])
				got["panic"] = true
				break
			if want == "react" and pose != null and pose.phase() == KeeperDive.Phase.ACTIVE:
				await _shot(runner, out, "ai_keeper_2_react")
				print("    (reaction: dived %d at a ball going to %+.2f)" % [pose.side, float(p.ball.shot.cross_y) - Geo.GOAL_Y])
				got["react"] = true
				break
		Engine.time_scale = 1.0
	print("  ai keeper shots: %s" % str(got.keys()))

static func _shot(runner: Node, out: String, name: String) -> void:
	await RenderingServer.frame_post_draw
	runner.get_viewport().get_texture().get_image().save_png(out.path_join(name + ".png"))
	print("  shot ", name)

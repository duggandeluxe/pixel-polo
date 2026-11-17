extends RefCounted
## The exclusion box (Geo.REENTRY, between the red floats behind the goal line, PoolArt): a man sent
## out swims there and waits (Swimmer.out), and when he's let back in swims into the field
## (Swimmer.rejoin) rather than being snapped into it. Your 6 on 5 (attacking right) and theirs
## (the pool mirrored): checks, and a screenshot of each moment. Needs a window:
##   godot --path game -- --test exclusion_box_png <dir>

static func run(runner: Node, out: String) -> void:
	DirAccess.make_dir_recursive_absolute(out)
	var tree := runner.get_tree()
	var cfg := {"us": League.make_team(3), "them": League.make_team(0), "seed": 41, "minutes": 8.0, "autoplay": false}
	Game.match_cfg = cfg
	Game.goto("match", cfg)
	await tree.create_timer(0.5).timeout
	var screen = Game.current_screen
	var flow: MatchFlow = screen.flow
	var fails := 0
	for side in ["attack", "defense"]:
		if side == "attack":
			flow._start_attack(Play.Kind.HALF_COURT)
		else:
			flow._start_defense(Play.Kind.HALF_COURT)
		var p := flow.play
		p.drive_timer = 99.0
		await tree.create_timer(0.8).timeout
		if p.over:
			print("  (%s: the possession ended early, skipped)" % side)
			continue
		var d: Swimmer = p.defenders[3]
		p._exclusion(d, p.attackers[3])
		var t0 := Time.get_ticks_msec()
		await tree.create_timer(1.0).timeout
		await _shot(runner, screen, out, "%s_a_swimming_out" % side)
		while d.pos.distance_to(Geo.REENTRY) > 0.25 and Time.get_ticks_msec() - t0 < 12000 and not p.over:
			await tree.process_frame
		if p.over:
			print("  (%s: the possession ended before he got there, skipped)" % side)
			continue
		var took := (Time.get_ticks_msec() - t0) / 1000.0
		var ok := d.out and d.pos.distance_to(Geo.REENTRY) <= 0.25
		print("  %s: in the box after %.1f s, man_up left %.1f s: %s" % [side, took, p.man_up, "ok" if ok else "FAIL"])
		fails += 0 if ok else 1
		await _shot(runner, screen, out, "%s_b_waiting" % side)
		await tree.create_timer(0.5).timeout
		var still := d.pos.distance_to(Geo.REENTRY) <= 0.25
		print("  %s: still waiting there: %s" % [side, "ok" if still else "FAIL"])
		fails += 0 if still else 1
		p._end_man_up()
		var back := d.rejoin and not d.out and d.pos.x > Geo.LENGTH
		print("  %s: let back in, not snapped in (x %.2f): %s" % [side, d.pos.x, "ok" if back else "FAIL"])
		fails += 0 if back else 1
		await tree.create_timer(0.35).timeout
		await _shot(runner, screen, out, "%s_c_swimming_back" % side)
		await tree.create_timer(2.5).timeout
		var in_ok := not d.rejoin and Geo.in_pool(d.pos) and d.pos.x <= Geo.LENGTH - 0.3 + 0.001
		print("  %s: back in the field (%.2f, %.2f): %s" % [side, d.pos.x, d.pos.y, "ok" if in_ok else "FAIL"])
		fails += 0 if in_ok else 1
	print("  exclusion box: %s" % ("PASS" if fails == 0 else "%d FAIL" % fails))
	Game.goto("title")

## The box in view (the camera held on it, the play frozen for the frame).
static func _shot(runner: Node, screen, out: String, name: String) -> void:
	screen.paused = true
	var cam: ManUpCam = screen.mcam
	for _i in 2:
		cam.phase = ManUpCam.Phase.IDLE   # (the 6 on 5 push in off: the box is in the corner)
		cam.scale = 1.0
		cam.offset = Vector2.ZERO
		screen.view.cine = Transform2D.IDENTITY
		screen.view.snap_to(Geo.REENTRY - Vector2(4.0, 3.0))
		screen.canvas.queue_redraw()
		await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	runner.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out, name])
	screen.paused = false

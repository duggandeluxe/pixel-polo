extends RefCounted
## Screenshot tour of the 6 on 5 push in (ManUpCam) on the real match screen: before, partway in,
## the impact shake, settled, and on the way out; your power play (attacking right) and theirs
## (the pool mirrored). Needs a window:
##   godot --path game -- --test man_up_png <dir>

const DT := 1.0 / 60.0

static func run(runner: Node, out: String) -> void:
	DirAccess.make_dir_recursive_absolute(out)
	var tree := runner.get_tree()
	var cfg := {"us": League.make_team(3), "them": League.make_team(0), "seed": 41, "minutes": 8.0, "autoplay": true}
	Game.match_cfg = cfg
	Game.goto("match", cfg)
	await tree.create_timer(0.5).timeout
	var screen = Game.current_screen
	var flow: MatchFlow = screen.flow
	for side in ["attack", "defense"]:
		if side == "attack":
			flow._start_attack(Play.Kind.HALF_COURT)
		else:
			flow._start_defense(Play.Kind.HALF_COURT)
		var p := flow.play
		p.drive_timer = 99.0
		await tree.create_timer(1.0).timeout
		if p.over:
			print("  (%s: the possession ended early, skipped)" % side)
			continue
		p._exclusion(p.defenders[3], p.attackers[3])
		# the real thing first: the whistle, the push in, the formation setting up (and a frame mid-push)
		await tree.create_timer(0.2).timeout
		await _shot(runner, out, "%s_live_mid_push" % side)
		await tree.create_timer(2.6).timeout
		# then held still, the camera's timeline stepped to each moment
		screen.paused = true
		var cam: ManUpCam = screen.mcam
		for at in [0.0, 0.15, 0.3, 0.38, 0.45, 1.0]:
			cam.phase = ManUpCam.Phase.IDLE
			cam.scale = 1.0
			cam.offset = Vector2.ZERO
			if at > 0.0:
				cam.push()
				var tt := 0.0
				while tt < at - DT * 0.5:
					cam.step(DT, true)
					tt += DT
			await _frame(runner, screen, out, "%s_in_%03d" % [side, int(at * 100.0)], cam)
		for at in [0.25]:
			var tt := 0.0
			while tt < at:
				cam.step(DT, false)
				tt += DT
			await _frame(runner, screen, out, "%s_out_%03d" % [side, int(at * 100.0)], cam)
		screen.paused = false
	print("  6 on 5 camera shots done")

static func _frame(runner: Node, screen, out: String, name: String, cam: ManUpCam) -> void:
	if screen._man_up_on():
		cam.pivot = screen._man_up_pivot(screen.flow.play)
	screen.view.cine = cam.xform()
	screen.canvas.queue_redraw()
	print("    %s: scale %.3f, shake %s" % [name, cam.scale, str(cam.offset)])
	await _shot(runner, out, name)

static func _shot(runner: Node, out: String, name: String) -> void:
	await RenderingServer.frame_post_draw
	runner.get_viewport().get_texture().get_image().save_png(out.path_join(name + ".png"))

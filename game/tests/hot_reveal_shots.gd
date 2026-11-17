extends RefCounted
## Screenshot tour of the postgame HOT star reveal: the Developer Mode preview frozen through a
## first red star (in, warming, red, pulse, hold) and a second (ON FIRE!), then a real career
## game's summary on its reveal. Needs a window:
##   godot --path game -- --test hot_reveal_png <dir>

static func run(runner: Node, out: String) -> void:
	DirAccess.make_dir_recursive_absolute(out)
	var tree := runner.get_tree()
	Store.reset_for_tests()
	var c := Career.new_game("CULA", "Shot", "Coach", 4)
	Game.career = c
	Game.goto("hot_lab")
	await tree.create_timer(0.3).timeout
	var lab = Game.current_screen
	for test in [["first", "hr_first"], ["second", "hr_second"]]:
		lab.play(test[0])
		var rv: HotReveal = lab.reveal
		rv.set_process(false)
		var e: Dictionary = rv.plan[0]
		var at := float(e.steps[0].at)
		var times := [["in", float(e.start) + 0.12], ["warm", at + 0.1], ["flash", at + 0.22], ["red", at + 0.36],
			["pulse", at + StarFx.HEAT_TIME + 0.05], ["hold", float(e.out) - 0.05], ["out", float(e.out) + 0.1]]
		for tm in times:
			rv.t = tm[1]
			rv.layout()
			await _shot(runner, out, "%s_%s" % [test[1], tm[0]])
		rv.set_process(true)
		rv.skip()
	lab.play("none")
	await _shot(runner, out, "hr_none")
	# a real game: one man heats up
	var st := MatchState.new()
	st.score = [6, 3]
	var scorer: PoloPlayer = c.team().starters()[3]
	scorer.form = [1, 1]
	scorer.heat = 0
	for _i in 4:
		st.goal_by[0].append(scorer)
		st.shot_by[0].append(scorer)
	c.last_summary = c.finish_my_game(st.box(c.team(), c.opponent()))
	Store.starter_offered = true
	Game.goto("game_summary")
	await tree.create_timer(0.5).timeout
	var scr = Game.current_screen
	await _shot(runner, out, "hr_summary_final")
	scr.tap(Vector2(10, 10))
	scr.reveal.set_process(false)
	scr.reveal.motion = true
	scr.reveal.plan = HotReveal.plan_of(scr.reveal.items, true)
	scr.t = 1.0
	scr.reveal.t = float(scr.reveal.plan[0].steps[0].at) + 0.5
	scr.reveal.layout()
	await _shot(runner, out, "hr_summary_reveal")
	scr.reveal.set_process(true)
	scr.reveal.skip()
	await tree.create_timer(2.0).timeout
	await _shot(runner, out, "hr_summary_points")
	Game.career = null
	Game.goto("title")

static func _shot(runner: Node, out: String, name: String) -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	runner.get_viewport().get_texture().get_image().save_png(out.path_join(name + ".png"))
	print("  shot ", name)

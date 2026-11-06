extends RefCounted
## Screenshot tour of the tutorial: the title, each part's pop-up, each part in play, the callout
## handing on to the next part, TUTORIAL COMPLETE, a new career's SKIP question and TRAINING
## COMPLETE, and the pop-up and a part at a wide phone's aspect.
##   godot --path game -- --test tutorial_png <dir>

static func run(runner: Node, out: String) -> void:
	DirAccess.make_dir_recursive_absolute(out)
	var tree := runner.get_tree()
	Game.goto("title")
	await tree.create_timer(1.2).timeout
	await _shot(runner, out, "t0_title")
	var i := 1
	for id in Drill.ORDER:
		Game.goto("drill", {"id": id})
		await tree.create_timer(0.5).timeout
		var ms = Game.current_screen
		await _shot(runner, out, "t%d_%s_popup" % [i, id])
		ms._close_popup()
		await tree.create_timer(1.2).timeout
		if id == "keeper":
			# wait for the shot, so the dive hint is up
			var guard := 0
			while ms.flow.duel == null and guard < 300:
				guard += 1
				await tree.process_frame
		await _shot(runner, out, "t%d_%s" % [i, id])
		if id != "keeper":
			# done: the callout handing on to the next part
			ms.drill.complete = true
			ms.done_t = 0.0
			ms.segue_t = 0.3
			await tree.create_timer(0.2).timeout
			await _shot(runner, out, "t%d_%s_segue" % [i, id])
		else:
			ms.drill.complete = true
			ms.card_on = true
			await tree.create_timer(0.2).timeout
			await _shot(runner, out, "t%d_complete" % i)
		i += 1
	# a new career's run: SKIP TUTORIAL in the strip, the question, TRAINING COMPLETE
	var kept_career = Game.career
	Game.career = Career.new_game("WAGN", "Sam", "Rivera", 31)
	Game.career.tutorial = Career.TUTORIAL_PENDING
	Game.goto("drill", {"career": true})
	await tree.create_timer(0.5).timeout
	var cs = Game.current_screen
	await _shot(runner, out, "c1_career_popup")
	cs._close_popup()
	await tree.create_timer(0.8).timeout
	await _shot(runner, out, "c2_career_play")
	cs._ask_skip()
	await tree.create_timer(0.2).timeout
	await _shot(runner, out, "c3_skip_question")
	cs.popup = {}
	cs._start_part(Drill.ORDER.size() - 1, false, false)
	cs.drill.complete = true
	cs.done_t = 0.0
	while not cs.card_on:
		await tree.process_frame
	await tree.create_timer(0.2).timeout
	await _shot(runner, out, "c4_training_complete")
	# a phone wider than 16:9 (the viewport expands sideways)
	var win := runner.get_window()
	var was := win.size
	win.size = Vector2i(1170, 540)
	Game.goto("drill", {"career": true, "id": "counter"})
	await tree.create_timer(0.8).timeout
	await _shot(runner, out, "c5_popup_wide")
	Game.current_screen._close_popup()
	await tree.create_timer(0.8).timeout
	await _shot(runner, out, "c6_play_wide")
	Game.career = kept_career
	Game.goto("title")
	await tree.create_timer(1.0).timeout
	win.size = was

static func _shot(runner: Node, out: String, name: String) -> void:
	await RenderingServer.frame_post_draw
	runner.get_viewport().get_texture().get_image().save_png(out.path_join(name + ".png"))
	print("  shot ", name)

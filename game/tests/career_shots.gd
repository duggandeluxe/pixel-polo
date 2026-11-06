extends RefCounted
## Screenshot tour of the career: new career, hub, every management screen, a career game
## and its summary, and the season review. Needs a window:
##   godot --path game -- --test career_png <dir>

static func run(runner: Node, out: String) -> void:
	DirAccess.make_dir_recursive_absolute(out)
	var tree := runner.get_tree()
	Store.reset_for_tests()
	Game.goto("new_career")
	await tree.create_timer(0.5).timeout
	await _shot(runner, out, "c01_new_career")
	var c := Career.new_game("WAGN", "Sam", "Rivera", 31)
	Game.career = c
	# a few weeks in, so the tables and stats have numbers
	for _i in 4:
		while c.has_game():
			c.sim_my_game()
		c.end_week()
	c.queue.clear()
	c.credits = 140
	var r: Dictionary = c.market[3]
	Game.goto("recruiting", {"tab": "MARKET", "sel": (r.p as PoloPlayer).id})
	await tree.create_timer(0.4).timeout
	await _shot(runner, out, "c_recruiting_scouted")
	for s in ["hub", "more", "roster", "training", "facilities", "recruiting", "schedule", "top20", "store", "visual_shop", "records"]:
		Game.goto(s)
		await tree.create_timer(0.4).timeout
		await _shot(runner, out, "c_%s" % s)
	Game.goto("player", {"id": c.team().starters()[1].id, "list": c.team().roster.map(func(q): return q.id)})
	await tree.create_timer(0.4).timeout
	await _shot(runner, out, "c_player")
	var sch = null
	for tab in ["STANDINGS", "PLAYOFFS"]:
		Game.goto("conference")
		await tree.create_timer(0.3).timeout
		sch = Game.current_screen
		sch.tab = tab
		sch._render()
		await tree.create_timer(0.3).timeout
		await _shot(runner, out, "c_conference_" + tab.to_lower())
	# a career game in the venue
	Game.match_cfg = {"us": c.team(), "them": c.opponent(), "seed": 8, "minutes": 1.0, "career": true,
		"home": c.is_home(), "pool": c.venue().id, "autoplay": true}
	for q in Game.career.upgrades_due(): Development.ai_spend(q)   # (XP 2.0: upgrades are spent before the hub moves on)
	Game.goto("match", Game.match_cfg)
	await tree.create_timer(0.8).timeout
	await _shot(runner, out, "c_match_start")
	var ms = Game.current_screen
	# their attack: you defend, then you're in goal for their shot
	Engine.time_scale = 6.0
	while ms.flow.phase != MatchFlow.Phase.DEFENSE and ms.flow.phase != MatchFlow.Phase.FINAL:
		if ms.flow.phase == MatchFlow.Phase.BREAK:
			ms.flow.break_done()
		await tree.process_frame
	Engine.time_scale = 1.0
	await tree.create_timer(0.8).timeout
	await _shot(runner, out, "c_defense")
	Engine.time_scale = 3.0
	while ms.flow.duel == null and ms.flow.phase != MatchFlow.Phase.FINAL:
		if ms.flow.phase == MatchFlow.Phase.BREAK:
			ms.flow.break_done()
		await tree.process_frame
	Engine.time_scale = 1.0
	if ms.flow.duel != null:
		await _shot(runner, out, "c_their_shot")
	Engine.time_scale = 8.0
	while ms.flow.phase != MatchFlow.Phase.FINAL:
		if ms.flow.phase == MatchFlow.Phase.BREAK:
			ms.flow.break_done()
		await tree.process_frame
	Engine.time_scale = 1.0
	await tree.create_timer(0.4).timeout
	await _shot(runner, out, "c_match_final")
	ms._to_career()
	await tree.create_timer(0.5).timeout
	await _shot(runner, out, "c_game_summary")
	# the locker room (closing the one-time starter offer the summary may have shown)
	for ch in Game.overlay.get_children():
		if ch is Control and ch.mouse_filter == Control.MOUSE_FILTER_STOP:
			ch.queue_free()
	Game.current_screen._continue()
	await tree.create_timer(0.5).timeout
	await _shot(runner, out, "c_review")
	Game.current_screen._continue()
	await tree.create_timer(0.4).timeout
	if Game.current_name == "coach_event":
		await _shot(runner, out, "c_event")
		Game.current_screen.pick = 0
		Game.current_screen._confirm()
		Game.current_screen._leave()
		await tree.create_timer(0.4).timeout
	# an event card in the hub
	c.queue = [{"type": "card", "id": "center_touches", "pid": c.team().starters()[1].id}]
	for q in Game.career.upgrades_due(): Development.ai_spend(q)   # (XP 2.0: upgrades are spent before the hub moves on)
	Game.goto("hub")
	await tree.create_timer(0.6).timeout
	await _shot(runner, out, "c_card")
	for ch in Game.overlay.get_children():
		if ch is Control and ch.mouse_filter == Control.MOUSE_FILTER_STOP:
			ch.queue_free()
	c.queue.clear()
	# fast-forward to the end of the season for the review
	await tree.process_frame
	var label := c.season_label()
	while c.phase == "season":
		c.queue = c.queue.filter(func(q): return q.type == "recap")
		while c.has_game():
			c.sim_my_game()
		c.end_week()
	var recap: Dictionary = {}
	for q in c.queue:
		if q.type == "recap":
			recap = q
	Game.goto("recap", recap)
	await tree.create_timer(0.4).timeout
	await _shot(runner, out, "c_recap")
	# the season's done: the hub, then NEXT SEASON's question
	c.queue.clear()
	for q in Game.career.upgrades_due(): Development.ai_spend(q)   # (XP 2.0: upgrades are spent before the hub moves on)
	Game.goto("hub")
	await tree.create_timer(0.5).timeout
	await _shot(runner, out, "c_hub_done")
	Game.current_screen._next_season()
	await tree.create_timer(0.4).timeout
	await _shot(runner, out, "c_next_season_confirm")
	for ch in Game.overlay.get_children():
		if ch is Control and ch.mouse_filter == Control.MOUSE_FILTER_STOP:
			ch.queue_free()
	while c.season_label() == label:
		c.queue = c.queue.filter(func(q): return q.type == "recap")
		c.end_week()
	for q in c.queue:
		if q.type == "recap":
			recap = q
	Game.goto("recap", recap)
	await tree.create_timer(0.4).timeout
	await _shot(runner, out, "c_recap_lock")
	c.queue.clear()
	Game.goto("roster")
	await tree.create_timer(0.4).timeout
	await _shot(runner, out, "c_roster_next_season")
	Game.goto("records")
	await tree.create_timer(0.3).timeout
	Game.current_screen.tab = "AWARDS"
	Game.current_screen._render()
	await tree.create_timer(0.3).timeout
	await _shot(runner, out, "c_records_awards")
	Game.career = null

static func _shot(runner: Node, out: String, name: String) -> void:
	await RenderingServer.frame_post_draw
	runner.get_viewport().get_texture().get_image().save_png(out.path_join(name + ".png"))
	print("  shot ", name)

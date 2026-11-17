extends RefCounted
## The Season Review Redesign: a real season played out to its review (checked, then shot at the
## top and scrolled), DEV Mode's VIEW SEASON REVIEW lab, every sample scenario, and that a preview
## and SeasonReview.build never change the career. Needs a window:
##   godot --path game --resolution 480x270 -- --test season_review_png <dir>

static func run(runner: Node, out: String) -> void:
	DirAccess.make_dir_recursive_absolute(out)
	var tree := runner.get_tree()
	var fails := 0
	var check := func(ok: bool, what: String) -> int:
		print("  %s  %s" % ["PASS" if ok else "FAIL", what])
		return 0 if ok else 1
	Store.reset_for_tests()
	var dev_was: bool = Game.settings.get("dev_mode", false)
	var c := Career.new_game("LIUB", "Sam", "Rivera", 31)
	Game.career = c
	while c.phase == "season":
		c.queue = c.queue.filter(func(q): return q.type == "recap")
		while c.has_game():
			c.sim_my_game()
		c.end_week()
	var recap: Dictionary = {}
	for q in c.queue:
		if q.type == "recap":
			recap = q
	fails += check.call(String(recap.get("season", "")) == c.season_label(), "the review is queued with its season")
	var h: Dictionary = c.history[-1]
	fails += check.call(h.has("review") and (h.review.all_conf as Array).size() == 7, "the history entry keeps the All-Conference team (%d)" % (h.get("review", {}).get("all_conf", []) as Array).size())
	var before := JSON.stringify(c.to_dict())
	var m := SeasonReview.build(c, c.season_label())
	fails += check.call(JSON.stringify(c.to_dict()) == before, "SeasonReview.build changes nothing")
	fails += check.call(not (m.national as Dictionary).is_empty(), "the NCSA champion: %s" % m.national.get("team_name", ""))
	fails += check.call((m.confs as Array).size() >= 5, "every conference champion (%d)" % (m.confs as Array).size())
	fails += check.call((m.awards as Array).size() >= 6, "season awards (%d)" % (m.awards as Array).size())
	fails += check.call((m.teams as Array).size() == 3, "All-NCSA First, Second and All-Conference teams (%d)" % (m.teams as Array).size())
	fails += check.call(not (m.postseason as Array).is_empty(), "postseason honours (%d groups)" % (m.postseason as Array).size())
	var keys := {}
	var dup := false
	for r in m.records:
		var k := "%s|%s" % [r.level, r.key]
		dup = dup or keys.has(k)
		keys[k] = true
	fails += check.call(not dup, "no record twice (%d records)" % (m.records as Array).size())
	fails += check.call(int(m.totals.seasons) == c.history.size(), "dynasty totals")
	Game.goto("recap", recap)
	await tree.create_timer(0.5).timeout
	await _shot(runner, out, "r01_review_top")
	var sc: ScrollContainer = Game.current_screen.find_child("ReviewScroll", true, false)
	fails += check.call(sc != null, "the review scrolls")
	if sc != null:
		var maxv := int(sc.get_v_scroll_bar().max_value)
		var i := 2
		for y in range(200, maxv, 200):
			sc.scroll_vertical = y
			await tree.create_timer(0.15).timeout
			await _shot(runner, out, "r%02d_review_scroll" % i)
			i += 1
	fails += check.call(JSON.stringify(c.to_dict()) == before, "opening the review changes nothing until you move on")
	# DEV Mode
	Game.settings.dev_mode = true
	Game.goto("review_lab")
	await tree.create_timer(0.4).timeout
	await _shot(runner, out, "r20_lab")
	Game.goto("recap", {"preview": true, "season": c.season_label()})
	await tree.create_timer(0.4).timeout
	await _shot(runner, out, "r21_preview_real")
	var q_before := c.queue.size()
	Game.current_screen.on_back()
	await tree.create_timer(0.3).timeout
	fails += check.call(Game.current_name == "review_lab" and c.queue.size() == q_before, "back from a preview: the lab, the queue untouched")
	var n := 30
	for s in load("res://src/ui/screens/review_lab.gd").SCENARIOS:
		Game.goto("recap", {"preview": true, "sample": true, "model": load("res://src/ui/screens/review_lab.gd").sample(String(s[1]))})
		await tree.create_timer(0.35).timeout
		await _shot(runner, out, "r%d_%s" % [n, s[1]])
		var s2: ScrollContainer = Game.current_screen.find_child("ReviewScroll", true, false)
		if s2 != null and s2.get_v_scroll_bar().max_value > 300:
			s2.scroll_vertical = 330
			await tree.create_timer(0.15).timeout
			await _shot(runner, out, "r%d_%s_b" % [n, s[1]])
		n += 1
	fails += check.call(JSON.stringify(c.to_dict()) == before, "the samples and previews change nothing")
	Game.settings.dev_mode = dev_was
	Game.career = null
	print("season review: %s" % ("ALL PASS" if fails == 0 else "%d FAIL" % fails))

static func _shot(runner: Node, out: String, name: String) -> void:
	await RenderingServer.frame_post_draw
	runner.get_viewport().get_texture().get_image().save_png(out.path_join(name + ".png"))
	print("  shot ", name)

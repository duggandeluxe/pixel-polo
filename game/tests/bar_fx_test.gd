extends RefCounted
## The attribute bar's HOT fire and its new injury look (Deck.fire_span, Deck.attr_boxes), every
## player's #/10 beside his attribute names, and Developer Mode's ATTRIBUTE BAR EFFECTS (bar_lab).
##   godot --headless --path game -- --test bar_fx
##   godot --path game --resolution 1440x810 -- --test bar_fx_png <dir>   (the lab, a HOT and an injured page)

func run(runner) -> void:
	var n := [0, 0]   # checks, failed (an array: a lambda can't change the locals it captures)
	var check := func(ok: bool, what: String) -> void:
		n[0] += 1
		if not ok:
			n[1] += 1
			print("FAIL ", what)
		else:
			print("ok   ", what)
	check.call(Deck.fire_span(6.0, 0.5) == Vector2(6.0, 6.5), "HOT on 6: half a box of fire, right after his own")
	check.call(Deck.fire_span(6.0, 1.0) == Vector2(6.0, 7.0), "VERY HOT on 6: a whole box")
	check.call(Deck.fire_span(5.5, 0.5) == Vector2(5.5, 6.0), "HOT on 5.5: the rest of his part-way box")
	check.call(Deck.fire_span(10.0, 1.0) == Vector2(9.0, 10.0), "VERY HOT at 10: no room, the last box burns")
	check.call(Deck.fire_span(9.5, 1.0) == Vector2(9.0, 10.0), "VERY HOT at 9.5: still whole, inside the bar")
	check.call(Deck.BOX_INJ == Color("e8213a"), "injured boxes: plain red")
	check.call(Deck.FIRE_HZ <= 3.0, "the fire crackles calmly")
	# the box states (and so every test of them) are unchanged: fire is drawn on top
	check.call(Deck.box_states(6.0, 9.0, 1.0)[5] == "red", "box states unchanged (\"red\" is still the injured state)")
	# the lab and a HOT, injured player's page open
	var tree: SceneTree = runner.get_tree()
	Store.reset_for_tests()
	var c := Career.new_game("WAGN", "Sam", "Rivera", 31)
	c.hot_tip = true
	c.queue.clear()
	Game.career = c
	Game.goto("bar_lab")
	for _i in 3:
		await tree.process_frame
	var scr = Game.current_screen
	check.call(scr != null and scr.find_child("Rows", true, false) != null and scr.find_child("Rows", true, false).get_child_count() == 9, "ATTRIBUTE BAR EFFECTS opens with its nine cases")
	var p: PoloPlayer = c.team().roster[0]
	p.heat = 2
	Game.goto("player", {"id": p.id})
	for _i in 3:
		await tree.process_frame
	scr = Game.current_screen
	var nm = scr.find_child("Name_" + String(p.key_ratings()[0]), true, false)
	check.call(nm != null and String(nm.get_meta("value", "")) == DevArt.value_text(p.attr(String(p.key_ratings()[0]))), "an ordinary player's page shows #/10 beside each attribute")
	Game.career = null
	print("%d checks, %d failed" % [n[0], n[1]])

static func shots(runner, out: String) -> void:
	DirAccess.make_dir_recursive_absolute(out)
	var tree: SceneTree = runner.get_tree()
	Store.reset_for_tests()
	var c := Career.new_game("WAGN", "Sam", "Rivera", 31)
	c.hot_tip = true
	c.queue.clear()
	Game.career = c
	Game.goto("bar_lab")
	await tree.create_timer(0.4).timeout
	await _shot(runner, out, "bar_lab")
	var t := c.team()
	var hot: PoloPlayer = t.roster[1]
	hot.heat = 2
	Game.goto("player", {"id": hot.id})
	await tree.create_timer(0.6).timeout
	await _shot(runner, out, "page_very_hot")
	var hurt: PoloPlayer = t.roster[2]
	hurt.heat = 1
	Development.injure(hurt, RandomNumberGenerator.new(), "moderate")
	Game.goto("player", {"id": hurt.id})
	await tree.create_timer(0.6).timeout
	await _shot(runner, out, "page_hot_injured")
	Game.career = null
	Game.goto("title")

static func _shot(runner: Node, out: String, name: String) -> void:
	for n in runner.get_tree().root.find_children("*", "", true, false):
		if n.name.begins_with("Dialog") or n.name.begins_with("Tip"):
			n.queue_free()
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	runner.get_viewport().get_texture().get_image().save_png(out.path_join(name + ".png"))
	print("  shot ", name)

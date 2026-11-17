extends RefCounted
## ROSTER CUTS screen (the redesign: the Roster Set's look; VIEW PLAYER CARD, no attributes).
##   godot --headless --path game -- --test roster_cuts
##   godot --path game --resolution 1440x810 -- --test roster_cuts_png <outdir>

var r

static func _cuts_career() -> Career:
	Store.reset_for_tests()
	Store.starter_offered = true
	var c := Career.new_game("CULA", "Sam", "Rivera", 31)
	c.queue.clear()
	var ids: Array = c.market.duplicate()
	var added := 0
	for rec in ids:
		var p: PoloPlayer = (rec as Dictionary).get("p")
		if p == null:
			continue
		p.year = 1
		Offseason.join(c, c.team(), p)
		added += 1
		if c.team().roster.size() >= c.roster_max() + 2:
			break
	c.phase = "cuts"
	c.team().sync_lineup()
	return c

func run(runner) -> void:
	r = runner
	var tree: SceneTree = runner.get_tree()
	var c := _cuts_career()
	Game.career = c
	Game.goto("roster_cuts")
	for _i in 3:
		await tree.process_frame
	var s := Game.current_screen
	r.check(Game.current_name == "roster_cuts", "the cuts screen opens")
	var rows := s.find_children("Player_*", "", true, false)
	r.check(rows.size() == c.team().roster.size(), "a row a player (%d)" % rows.size())
	r.check(s.find_children("View", "Button", true, false).size() == rows.size(), "VIEW PLAYER CARD on every row")
	r.check(s.find_children("Cut", "Button", true, false).size() == rows.size(), "CUT PLAYER on every row")
	var txt := ""
	for n in s.find_children("*", "", true, false):
		if n is Label or n is Button:
			txt += n.text + "\n"
	r.check(not txt.contains("PAS ") and not txt.contains("SHO "), "no attributes on the screen")
	r.check(txt.contains("PLAYERS TO CUT: %d" % Offseason.cuts_needed(c)), "how many to cut")
	var cont: Button = s.find_child("Continue", true, false)
	r.check(cont != null and cont.disabled, "CONTINUE off while over the cap")
	# VIEW PLAYER CARD: his page, and back comes here
	var view: Button = s.find_children("View", "Button", true, false)[0]
	view.pressed.emit()
	for _i in 3:
		await tree.process_frame
	r.check(Game.current_name == "player", "VIEW PLAYER CARD opens his player card")
	Game.current_screen.on_back()
	for _i in 3:
		await tree.process_frame
	r.check(Game.current_name == "roster_cuts", "...and back returns to ROSTER CUTS")
	Game.career = null
	Game.goto("title")
	await tree.process_frame

static func shots(runner, out: String) -> void:
	DirAccess.make_dir_recursive_absolute(out)
	var tree: SceneTree = runner.get_tree()
	var c := _cuts_career()
	Game.career = c
	Game.goto("roster_cuts")
	await tree.create_timer(0.8).timeout
	await RenderingServer.frame_post_draw
	runner.get_viewport().get_texture().get_image().save_png(out.path_join("cuts_over.png"))
	print("  shot cuts_over")
	while not Offseason.roster_legal(c):
		var victim: PoloPlayer = null
		for p in c.team().roster:
			if Offseason.cut_block(c, p) == "" and not p.is_keeper():
				victim = p
		Offseason.cut(c, victim)
	Game.goto("roster_cuts")
	await tree.create_timer(0.8).timeout
	await RenderingServer.frame_post_draw
	runner.get_viewport().get_texture().get_image().save_png(out.path_join("cuts_legal.png"))
	print("  shot cuts_legal")
	Game.career = null

extends RefCounted
## Screenshot tour of the roster: the formation with every form (an injured man, the keeper), the
## cards coming in, a tapped card's flash, a card dragged over another place, an open spot, a card
## cooling, the DEV panel, a bench, and three players' pages. Needs a window:
##   godot --path game -- --test roster_png <dir>

static func run(runner: Node, out: String) -> void:
	DirAccess.make_dir_recursive_absolute(out)
	var tree := runner.get_tree()
	Store.reset_for_tests()
	var dev_was: bool = Game.settings.get("dev_mode", false)
	var test_was := Game.test_mode
	Game.test_mode = false     # the cards' own motion, to catch it mid-way
	Game.settings.dev_mode = false
	var c := Career.new_game("LIUB", "Shot", "Coach", 4)
	Game.career = c
	var t := c.team()
	var heats := [2, 1, 0, 0, 1, 0, 2]
	for i in t.roster.size():
		t.roster[i].heat = heats[i % heats.size()]
	Development.injure(t.roster[3], RandomNumberGenerator.new(), "moderate")
	t.roster[3].tokens = 1 # combined injury, upgrade and HOT badges on one card
	c.hot_tip = true     # the cards, not the one-time tip
	Game.goto("roster")
	await tree.create_timer(0.08).timeout
	await _shot(runner, out, "r_enter")
	await tree.create_timer(1.2).timeout
	await _shot(runner, out, "r_cards")
	var scr = Game.current_screen
	# a card picked up and held over RIGHT WING
	var lw := PoloTeam.LINEUP_SPOTS.find("lw")
	var rw := PoloTeam.LINEUP_SPOTS.find("rw")
	var held: PoloPlayer = scr.at(lw)
	scr.lift(held.id, scr.cards[held.id].global_position + Vector2(30, 20))
	scr.follow(scr.board.global_position + scr.slot_rect(rw).get_center() + Vector2(-8, 6))
	await _shot(runner, out, "r_drag")
	scr.drop(scr.board.global_position + scr.slot_rect(rw).get_center())
	await tree.create_timer(0.4).timeout
	await _shot(runner, out, "r_swapped")
	scr = Game.current_screen
	var first: PoloPlayer = scr.ordered(t.roster)[1]
	scr.cards[first.id].pressed.emit()
	await RenderingServer.frame_post_draw
	await _shot(runner, out, "r_pick")
	await tree.create_timer(0.5).timeout
	await _shot(runner, out, "r_player_%d" % 0)
	for i in [0, 4]:
		var p: PoloPlayer = load("res://src/ui/screens/roster.gd").ordered(t.roster)[i]
		Game.goto("player", {"id": p.id})
		await tree.create_timer(0.5).timeout
		await _shot(runner, out, "r_player_%d" % (i + 1))
	# one place empty, Developer Mode on, a card cooling
	var gone: PoloPlayer = t.roster.pop_back()
	Game.settings.dev_mode = true
	Game.goto("roster")
	await tree.create_timer(1.0).timeout
	await _shot(runner, out, "r_open_dev")
	scr = Game.current_screen
	var q: PoloPlayer = t.roster[2]
	scr._dev_toggle()
	scr._dev_select(q.id)
	scr._dev_form(1)
	scr._dev_form(1)
	scr._dev_form(-1)
	var fx: StarFx = scr.fxs[q.id]
	fx._tw.pause()
	fx.t = 0.3
	scr.cards[q.id].queue_redraw()
	await _shot(runner, out, "r_dev_cool")
	fx.t = 2.0
	fx._tw.kill()
	fx.kind = ""
	scr.cards[q.id].queue_redraw()
	await _shot(runner, out, "r_dev_cooled")
	t.roster.append(gone)
	# more than seven: the eighth on the bench
	Game.settings.dev_mode = false
	var extra := PoloPlayer.from_dict(t.roster[4].to_dict())
	extra.id = 99999
	extra.last = "Benchley"
	t.roster.append(extra)
	Game.goto("roster")
	await tree.create_timer(1.0).timeout
	await _shot(runner, out, "r_bench")
	t.roster.erase(extra)
	Game.goto("form_lab")
	await tree.create_timer(0.3).timeout
	await _shot(runner, out, "r_form_lab")
	Game.goto("hub")
	await tree.create_timer(0.4).timeout
	await _shot(runner, out, "r_hub_status")
	Game.settings.dev_mode = dev_was
	Game.test_mode = test_was
	Game.career = null
	Game.goto("title")

static func _shot(runner: Node, out: String, name: String) -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	runner.get_viewport().get_texture().get_image().save_png(out.path_join(name + ".png"))
	print("  shot ", name)

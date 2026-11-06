extends RefCounted
## Screenshot tour of the player profile: a healthy field player, an injured one (red boxes) with
## an upgrade token, the keeper (head injury), then the injured one after spending the token (the
## red boxes move right) and after a recovery. Needs a window:
##   godot --path game -- --test profile_png <dir>

static func run(runner: Node, out: String) -> void:
	DirAccess.make_dir_recursive_absolute(out)
	var tree := runner.get_tree()
	Store.reset_for_tests()
	var c := Career.new_game("WAGN", "Sam", "Rivera", 31)
	Game.career = c
	for _i in 4:
		while c.has_game():
			c.sim_my_game()
		c.end_week()
	c.queue.clear()
	c.credits = 50
	var team := c.team()
	var ids: Array = team.roster.map(func(q): return q.id)
	var field: PoloPlayer = team.starters()[1]
	var bench := team.roster.filter(func(q: PoloPlayer): return not team.starters().has(q))
	var bench_field := bench.filter(func(q: PoloPlayer): return not q.is_keeper())
	var hurt: PoloPlayer = bench_field[0] if not bench_field.is_empty() else team.starters()[2]
	Attributes.set_ceiling(hurt, "sho", 10.0)
	var rq := RandomNumberGenerator.new()
	Development.injure(hurt, rq, "moderate", "shoulder")
	hurt.tokens = 1
	Development.injure(team.keeper(), rq, "minor")
	for pair in [["p_field", field], ["p_injured", hurt], ["p_keeper", team.keeper()]]:
		Game.goto("player", {"id": (pair[1] as PoloPlayer).id, "list": ids})
		await tree.create_timer(0.5).timeout
		await _shot(runner, out, pair[0])
	# HOT form on the front, then the card's back: ON FIRE, and a HOT player cooling down
	c.hot_tip = true
	field.form = [1, 1, 1, 1]
	field.heat = 2
	Game.goto("player", {"id": field.id, "list": ids})
	await tree.create_timer(1.2).timeout
	await _shot(runner, out, "p_hot_front")
	Game.current_screen.flip()
	await tree.create_timer(0.6).timeout
	await _shot(runner, out, "p_hot_back")
	var cool: PoloPlayer = team.starters()[3]
	cool.form = [1, 1, 1, 0, -1]
	cool.heat = 1
	Game.goto("player", {"id": cool.id, "list": ids})
	await tree.create_timer(0.5).timeout
	Game.test_mode = false   # (motion on for the flip itself)
	Game.current_screen.flip()
	await tree.create_timer(0.09).timeout
	await _shot(runner, out, "p_flip_mid")
	await tree.create_timer(0.5).timeout
	Game.test_mode = true
	await _shot(runner, out, "p_cooling_back")
	Game.goto("roster")
	await tree.create_timer(1.5).timeout
	await _shot(runner, out, "p_roster_hot")
	# the injured one again: an upgrade on his injured Shooting (the red boxes move right), then
	# a recovery week
	Game.goto("player", {"id": hurt.id, "list": ids})
	await tree.create_timer(0.5).timeout
	var scr = Game.current_screen
	scr._buy("sho")
	await tree.create_timer(0.15).timeout
	await _shot(runner, out, "p_boost_anim")
	if Development.heal(hurt):
		scr._refresh()
	await tree.create_timer(0.5).timeout
	await _shot(runner, out, "p_recovered")

static func _shot(runner: Node, out: String, name: String) -> void:
	await RenderingServer.frame_post_draw
	runner.get_viewport().get_texture().get_image().save_png(out.path_join(name + ".png"))
	print("  shot ", name)

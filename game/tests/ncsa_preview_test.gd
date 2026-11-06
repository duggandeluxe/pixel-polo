extends RefCounted
## THE NCSA BRACKET PREVIEW: the national bracket from day one, seed places only.
##   godot --headless --path game -- --test ncsa_preview
##   godot --path game -- --test ncsa_preview_png <dir>

var r

func run(runner) -> void:
	r = runner
	print("ncsa bracket preview")
	Store.reset_for_tests()
	var c := Career.new_game("SJCU", "A", "B", 95)
	c.queue.clear()
	var before := JSON.stringify(c.season)
	var m := PlayoffBracket.model(c, "nat", "")
	r.check(not m.empty and m.preview and (m.rounds as Array).size() == 4, "1-3: the NCSA bracket from game 1: four rounds, a preview")
	r.check((m.seeds as Array) == range(1, 13).map(func(k): return "#%d" % k), "2: the twelve seed places")
	var ids := {}
	for rd in m.rounds:
		for mt in rd.matches:
			for k in [mt.a, mt.b, mt.win]:
				if String(k) != "" and String(k) != "?":
					ids[String(k)] = true
	r.check(ids.keys().all(func(k): return String(k).begins_with("#")), "3/4: no team anywhere: only seed places (%s)" % str(ids.keys()))
	var r1: Array = m.rounds[0].matches
	var byes: Array = r1.filter(func(mt): return mt.bye).map(func(mt): return String(mt.win))
	byes.sort()
	r.check(byes == ["#1", "#2", "#3", "#4"], "6: the top four seeds have the byes (%s)" % str(byes))
	var games: Array = r1.filter(func(mt): return not mt.bye).map(func(mt): return [String(mt.a), String(mt.b)])
	# the real bracket's own placing (Schedule._slots, the function the real field goes through)
	var slots: Array = Schedule._slots(m.seeds, 16)
	var want: Array = []
	for i in range(0, slots.size(), 2):
		if slots[i] != "" and slots[i + 1] != "":
			want.append([slots[i], slots[i + 1]])
	r.check(games == want and games.all(func(g): return int(g[0].substr(1)) >= 5 and int(g[1].substr(1)) >= 5), "5: the opening round exactly as the real bracket orders it, seeds 5-12 (%s)" % str(games))
	var qf: Array = m.rounds[1].matches
	var qa: Array = qf.map(func(mt): return String(mt.a if mt.a != "?" else mt.b))
	qa.sort()
	r.check(qa == ["#1", "#2", "#3", "#4"] and qf.all(func(mt): return mt.a == "?" or mt.b == "?"), "7: each bye seed waits in its quarterfinal for a first-round winner")
	r.check(m.rounds[2].matches.size() == 2 and m.rounds[3].matches.size() == 1 and m.champion == "", "8/9/10: semifinals, the final, no champion invented")
	r.check(JSON.stringify(c.season) == before and (c.season.get("nat_seeds", []) as Array).is_empty(), "the season is untouched (nothing saved)")
	# the field named: the same structure, the real teams in it
	var field: Array = c.teams.keys().slice(0, 12)
	c.season["nat_seeds"] = field
	var real := PlayoffBracket.model(c, "nat", "")
	r.check(not real.get("preview", false) and String(real.rounds[0].matches[1].a) == String(field[7]) and String(real.rounds[0].matches[1].b) == String(field[8]),
		"14: once the field is set the real teams take the same places (seed 8 v 9)")
	c.season["nat_seeds"] = []
	Game.career = null

static func shots(runner, out: String) -> void:
	DirAccess.make_dir_recursive_absolute(out)
	var tree: SceneTree = runner.get_tree()
	Store.reset_for_tests()
	var c := Career.new_game("SJCU", "A", "B", 95)
	c.queue.clear()
	Game.career = c
	Game.goto("conference")
	await tree.process_frame
	var scr = Game.current_screen
	scr.tab = "PLAYOFFS"
	scr.pfam = "nat"
	scr._render()
	await tree.create_timer(0.6).timeout
	await RenderingServer.frame_post_draw
	runner.get_viewport().get_texture().get_image().save_png(out.path_join("ncsa_preview.png"))
	print("  shot ncsa_preview")
	Game.career = null

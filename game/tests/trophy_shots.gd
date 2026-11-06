extends RefCounted
## Trophy Room screenshots (needs a window): a player given one of every honour (test data only),
## an empty room, and his page with TROPHY CASE.
##   godot --path game -- --test trophy_png <dir>
static func run(runner, out: String) -> void:
	DirAccess.make_dir_recursive_absolute(out)
	Store.reset_for_tests()
	var c := Career.new_game("NWPC" if false else "LIUB", "A", "B", 81)
	Game.career = c
	var p: PoloPlayer = c.team().starters()[2]
	var empty: PoloPlayer = c.team().starters()[3]
	var weekly := [["NWPC", "opotw", 0], ["NWPC", "opotw", 2], ["NWPC", "potw", 4], ["WCC", "rotw", 1], ["NWPC", "dpotw", 6], ["NWPC", "opotw", 9]]
	for i in weekly.size():
		var w: Array = weekly[i]
		var season := "2026-27" if i < 4 else "2027-28"
		c.conf_awards.append({"year": 2026 if i < 4 else 2027, "season": season, "week": int(w[2]), "label": "WEEK %d" % (int(w[2]) + 1),
			"conf": w[0], "cat": w[1], "pid": p.id, "team": c.school, "name": "%s %s" % [p.first, p.last], "pos": p.pos, "cls": 2,
			"stars": 3.0, "line": {"g": 6, "a": 3, "gp": 1}, "score": 30.0})
	for cat in ["pot", "opot", "dpot"]:
		c.tourney_awards.append({"year": 2027, "season": "2027-28", "tid": "conf:NWPC" if cat != "opot" else "nat", "conf": "NWPC", "cat": cat,
			"pid": p.id, "team": c.school, "name": p.last, "pos": p.pos, "cls": 2, "stars": 3.0, "line": {"gp": 3, "g": 12, "a": 6}, "score": 30.0})
	for a in [["poy", "2027-28"], ["dpoy", "2026-27"], ["foy", "2025-26"], ["arm", "2027-28"], ["wall", "2026-27"], ["first", "2026-27"], ["first", "2027-28"], ["second", "2025-26"]]:
		c.awards.append({"year": a[1], "award": a[0], "name": "%s %s" % [p.first, p.last], "team": c.school, "pid": p.id, "pos": p.pos,
			"conf": "NWPC", "line": {"gp": 21, "g": 91, "a": 37, "st": 7, "bl": 4, "sv": 205}, "slot": "ATK" if a[0] in ["first", "second"] else ""})
	for s in [["room_full", {"id": p.id, "back": {"id": p.id}}], ["room_empty", {"id": empty.id, "back": {"id": empty.id}}]]:
		Game.goto("trophy_room", s[1])
		await runner.get_tree().create_timer(0.6).timeout
		await RenderingServer.frame_post_draw
		runner.get_viewport().get_texture().get_image().save_png(out.path_join("%s.png" % s[0]))
		print("  shot ", s[0])
	Game.goto("player", {"id": p.id})
	await runner.get_tree().create_timer(0.6).timeout
	await RenderingServer.frame_post_draw
	runner.get_viewport().get_texture().get_image().save_png(out.path_join("profile.png"))
	print("  shot profile")
	Game.career = null

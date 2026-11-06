extends RefCounted
## THE TEAM TROPHY CASE (TeamHonours, trophy_room in team mode, the Dynasty Hub's TROPHY CASE).
##   godot --headless --path game -- --test team_trophies
##   godot --path game -- --test team_trophies_png <dir>

var r

func run(runner) -> void:
	r = runner
	print("team trophy case")
	Store.reset_for_tests()
	var c := Career.new_game("SJCU", "A", "B", 91)
	c.queue.clear()
	Game.career = c
	# the past's champions: every title in the legacy is some school's
	var all := 0
	for id in c.teams:
		all += TeamHonours.of(c, id).size()
	var expect := 0
	for e in c.legacy:
		expect += (e.conf as Dictionary).size() + (1 if String(e.nat) != "" else 0)
	r.check(all == expect and expect > 0, "every past title belongs to its school (%d of %d)" % [all, expect])
	# a season's champions logged once
	c.season.conf_champs = [c.school]
	c.season.champion = c.school
	TeamHonours.record_season(c)
	TeamHonours.record_season(c)
	var mine := TeamHonours.of(c, c.school)
	r.check(c.champions_log.size() == 1 and mine.filter(func(e): return e.season == c.season_label()).size() == 2,
		"a season's conference and NCSA titles logged once (%d)" % c.champions_log.size())
	var d := Career.from_dict(JSON.parse_string(JSON.stringify(c.to_dict())))
	r.check(TeamHonours.of(d, c.school).size() == mine.size(), "the log survives a save")
	# an older save: its coach's titles
	var old := Career.new_game("SJCU", "A", "B", 92)
	old.legacy = []
	old.coach.titles = ["2025-26 %s" % old.conf_name(), "2025-26 NCSA"]
	old.history = [{"year": "2025-26", "team": old.school}]
	r.check(TeamHonours.of(old, old.school).size() == 2, "an older save's titles are its own school's")
	# the hub's card and the room
	Game.goto("more")
	await r.get_tree().process_frame
	var card: Control = Game.current_screen.find_child("Card_team_trophies", true, false)
	r.check(card != null and Game.current_screen.find_child("Card_facilities", true, false) == null, "the Dynasty Hub's FACILITIES card is now the TROPHY CASE")
	card.pressed.emit()
	await r.get_tree().process_frame
	await r.get_tree().process_frame
	var room = Game.current_screen
	r.check(Game.current_name == "trophy_room" and String(room.team_id) == c.school, "it opens the team trophy case")
	var nodes: Array = room.find_children("*", "", true, false)
	r.check(nodes.filter(func(n): return n.has_meta("entry")).size() == mine.size(), "a plaque a title (%d)" % mine.size())
	r.check(nodes.filter(func(n): return n.has_meta("trophy")).size() == 2, "a trophy for each kind: the conference's and the NCSA's")
	room.on_back()
	await r.get_tree().process_frame
	r.check(Game.current_name == "more", "Back to the Dynasty Hub")
	Game.career = null
	Game.goto("title")
	await r.get_tree().process_frame

static func shots(runner, out: String) -> void:
	DirAccess.make_dir_recursive_absolute(out)
	var tree: SceneTree = runner.get_tree()
	Store.reset_for_tests()
	var c := Career.new_game("SJCU", "A", "B", 91)
	c.queue.clear()
	Game.career = c
	var best := ""
	var most := -1
	for id in c.teams:
		var n := TeamHonours.of(c, id).size()
		if n > most:
			most = n
			best = id
	c.season.conf_champs = [best]
	c.season.champion = best
	TeamHonours.record_season(c)
	var snap := func(name: String) -> void:
		await tree.create_timer(0.6).timeout
		await RenderingServer.frame_post_draw
		runner.get_viewport().get_texture().get_image().save_png(out.path_join(name + ".png"))
		print("  shot ", name)
	Game.goto("more")
	await snap.call("tt1_hub")
	Game.goto("trophy_room", {"team": best, "back_to": "more"})
	await snap.call("tt2_case")
	var empty := ""
	for id in c.teams:
		if TeamHonours.of(c, id).is_empty():
			empty = id
			break
	if empty != "":
		Game.goto("trophy_room", {"team": empty, "back_to": "more"})
		await snap.call("tt3_empty")
	Game.career = null

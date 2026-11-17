extends RefCounted
## FULL CAREER STATS (the player page): the button in PLAYER STATISTICS' heading opens a popup with
## a row a season (PoloPlayer.seasons, kept at each season's end by Offseason.begin), this season
## while it's going on, EARLIER for an older save's totals no season holds, then CAREER.
##   godot --headless --path game -- --test career_stats
##   godot --path game --resolution 1440x810 -- --test career_stats <dir>   (also a PNG of the popup)
static func run(runner, out: String = "") -> void:
	Store.reset_for_tests()
	var c := Career.new_game("LIUB", "A", "B", 81)
	Game.career = c
	var p: PoloPlayer = c.team().starters()[2]
	# two finished seasons, then this one going on
	p.year = 3
	p.seasons = [{"s": "2024-25", "yr": 1, "team": c.school, "stats": {"gp": 20, "g": 31, "a": 12, "st": 5, "bl": 2}},
		{"s": "2025-26", "yr": 2, "team": c.school, "ovr": 4.5, "stats": {"gp": 21, "g": 44, "a": 19, "st": 9, "bl": 4}}]
	p.stats = {"gp": 9, "g": 19, "a": 14, "st": 1, "bl": 1}
	p.totals = {"gp": 50, "g": 94, "a": 45, "st": 15, "bl": 7}
	var rows: Array = load("res://src/ui/screens/player.gd").career_rows(c, p)
	runner.check(rows.size() == 4, "two kept seasons, this one, CAREER (%d rows)" % rows.size())
	runner.check(String(rows[2][0]) == c.season_label() and String(rows[2][1]) == "JR", "this season, as a JR")
	runner.check(String(rows[-1][0]) == "CAREER" and int(rows[-1][3].g) == 94, "CAREER is his totals")
	runner.check(float(rows[0][2]) < 0.0 and is_equal_approx(float(rows[1][2]), Attributes.stars_of(4.5)) and is_equal_approx(float(rows[2][2]), p.stars) and rows[-1][2] == null,
		"OVR column: none for an old kept season, its season-end stars, his stars now, none on CAREER (%s / %s / %s)" % [rows[0][2], rows[1][2], rows[2][2]])
	# an older save: totals with no seasons kept -> EARLIER
	var q: PoloPlayer = c.team().starters()[3]
	q.seasons = []
	q.stats = {"gp": 5, "g": 3}
	q.totals = {"gp": 30, "g": 20}
	var qr: Array = load("res://src/ui/screens/player.gd").career_rows(c, q)
	runner.check(qr.size() == 3 and String(qr[1][0]) == "EARLIER" and int(qr[1][3].gp) == 25 and int(qr[1][3].g) == 17,
		"an older save's missing seasons show as EARLIER")
	# archiving: once a season, only if he played, and it round-trips a save
	var r := PoloPlayer.new()
	r.stats = {"gp": 4, "g": 2}
	r.archive_season("2026-27", "LIUB")
	r.archive_season("2026-27", "LIUB")
	runner.check(r.seasons.size() == 1, "a season is kept once")
	runner.check(r.seasons[0].has("stars") and is_equal_approx(float(r.seasons[0].stars), r.stars), "a kept season holds his stars")
	var back := PoloPlayer.from_dict(JSON.parse_string(JSON.stringify(r.to_dict())))
	runner.check(back.seasons.size() == 1 and int(back.seasons[0].stats.g) == 2 and back.seasons[0].stats.g is int, "the season log survives a save")
	var none := PoloPlayer.new()
	none.archive_season("2026-27", "LIUB")
	runner.check(none.seasons.is_empty(), "no season kept for a player who didn't play")
	# the button and the popup
	Game.goto("player", {"id": p.id})
	await runner.get_tree().process_frame
	await runner.get_tree().process_frame
	var btn: Button = Game.current_screen.find_child("FullCareer", true, false)
	runner.check(btn != null and btn.size.y <= 12, "FULL CAREER STATS in PLAYER STATISTICS' heading row")
	if btn != null and out != "":
		await runner.get_tree().create_timer(0.4).timeout
		await RenderingServer.frame_post_draw
		runner.get_viewport().get_texture().get_image().save_png(out.path_join("career_stats_page.png"))
	if btn != null:
		btn.pressed.emit()
		await runner.get_tree().process_frame
		var pop: Control = Game.overlay.find_child("CareerStatsPopup", true, false)
		runner.check(pop != null, "it opens a popup over the page (no new screen)")
		runner.check(Game.current_name == "player", "the page stays underneath")
		if pop != null:
			var tbl: Control = pop.find_child("CareerTable", true, false)
			runner.check(tbl != null and (tbl.get_meta("rows") as Array).size() == 4, "the popup's table has every season")
			if out != "":
				await runner.get_tree().create_timer(0.4).timeout
				await RenderingServer.frame_post_draw
				runner.get_viewport().get_texture().get_image().save_png(out.path_join("career_stats.png"))
				print("  shot career_stats")
			pop.queue_free()
	Game.goto("more")
	await runner.get_tree().process_frame
	Game.career = null

extends RefCounted
## The Dynasty Hub Overhaul: AD goals gone everywhere, the old MORE as the DYNASTY HUB (eight
## cards, 2 x 4), PROGRAM OVERVIEW, LEAGUE NEWS (LeagueNews), TEAM FACILITIES, the RECORD BOOK,
## the GAME GUIDE; and the Accolades update's profile section.
##   godot --headless --path game -- --test dynasty_hub
##   godot --path game -- --test dynasty_hub_png <dir>

var r

func _frames(n: int) -> void:
	for _i in n:
		await r.get_tree().process_frame

func _texts(root: Node) -> String:
	var out := PackedStringArray()
	for n in root.find_children("*", "", true, false):
		if n is Label or n is Button:
			out.append(n.text)
	return "\n".join(out)

func run(runner) -> void:
	r = runner
	print("dynasty hub")
	Store.reset_for_tests()
	# ---- AD goals: gone
	var c := Career.new_game("LIUB", "A", "B", 61)
	r.check(not c.has_method("goal_progress") and not c.has_method("_set_goals") and not c.season.has("goals"), "1: no AD goals in a career")
	r.check(not c.queue.any(func(q): return String(q.type) == "goals"), "2-3: no AD goals popup")
	var old: Dictionary = JSON.parse_string(JSON.stringify(c.to_dict()))
	old.season["goals"] = [{"type": "wins", "n": 9, "text": "Win 9 regular-season games"}]
	old.queue.append({"type": "goals"})
	var back := Career.from_dict(old)
	r.check(not back.season.has("goals"), "5, 21: an older save's AD goals are dropped on load")
	var credits := c.credits
	Game.career = c
	# ---- a few weeks, for the news, then the hub
	for _w in 4:
		c.queue.clear()
		while c.has_game():
			c.sim_my_game()
		for q in c.upgrades_due():
			Development.ai_spend(q)
		c.end_week()
	c.queue.clear()
	r.check(not c.league_news.is_empty(), "11: league news written from the weeks' results (%d)" % c.league_news.size())
	r.check(c.league_news.all(func(n): return String(n.team) == "" or c.teams.has(String(n.team))), "11: every story is about a real team")
	var ids := {}
	for n in c.league_news:
		ids[String(n.id)] = true
	r.check(ids.size() == c.league_news.size(), "11: no story twice")
	var again := Career.from_dict(JSON.parse_string(JSON.stringify(c.to_dict())))
	r.check(JSON.stringify(again.league_news) == JSON.stringify(c.league_news), "21: the news is saved")
	Game.goto("more")
	await _frames(3)
	var scr = Game.current_screen
	r.check(scr.title_label.text == "DYNASTY HUB", "6: MORE is the DYNASTY HUB")
	var grid: GridContainer = scr.find_child("Cards", true, false)
	r.check(grid != null and grid.columns == 4 and grid.get_child_count() == 8, "7-8: eight cards, two rows of four")
	var all := _texts(scr)
	r.check(not all.contains("AD GOALS") and not all.contains("AD GOAL") and not all.contains("ATHLETIC DIRECTOR"), "1: no athletic director anywhere")
	# every card opens its screen
	for pair in [["program", "program"], ["news", "news"], ["team_trophies", "trophy_room"], ["records", "records"], ["store", "store"], ["settings", "settings"], ["visual_shop", "visual_shop"], ["recruiting", "recruiting"]]:
		Game.goto("more")
		await _frames(2)
		var card: BaseButton = Game.current_screen.find_child("Card_" + String(pair[0]), true, false)
		r.check(card != null, "9: the %s card" % pair[0])
		if card != null:
			card.pressed.emit()
			await _frames(3)
			r.check(Game.current_name == String(pair[1]), "9, 15, 17: %s opens %s" % [pair[0], Game.current_name])
	# program
	Game.goto("program")
	await _frames(3)
	var pt := _texts(Game.current_screen)
	r.check(pt.contains(Colleges.venue_name(c.school).to_upper()) and pt.contains(c.record_text()) and pt.contains("%d-%d" % [int(c.coach.wins), int(c.coach.losses)]),
		"10: PROGRAM shows your home pool, record and the coach's dynasty record")
	# news
	Game.goto("news")
	await _frames(3)
	var stories: Node = Game.current_screen.find_child("Stories", true, false)
	r.check(stories != null and stories.get_child_count() == c.league_news.size(), "11: LEAGUE NEWS lists the stories")
	# facilities
	Game.goto("facilities")
	await _frames(3)
	r.check(["Group_AQUATICS", "Group_TRAINING", "Group_STAFF"].all(func(n): return Game.current_screen.find_child(n, true, false) != null)
		and (Game.current_screen.find_child("HomePool", true, false) as Label).text == Colleges.venue_name(c.school).to_upper(), "12: AQUATICS (your home pool), TRAINING, STAFF")
	var cost := c.facility_cost("weights")
	var before := c.fac("weights")
	c.credits = cost
	Game.current_screen.selected = "fac:weights"
	Game.current_screen._render()
	await _frames(1)
	c.upgrade_facility("weights")
	r.check(c.fac("weights") == before + 1 and c.credits == 0, "12: the upgrades still work as they did")
	c.credits = credits
	# record book
	Game.goto("records")
	await _frames(3)
	Game.current_screen.tab = "PLAYERS"
	Game.current_screen._render()
	await _frames(2)
	var rb := _texts(Game.current_screen)
	r.check(rb.contains("Assists, college career") and not rb.contains("NOT SET YET"), "13: player records, every one with a holder (RecordBook)")
	# the visual overhaul: navy panels, the data read as it always was, everything inside the screen
	Game.current_screen.tab = "TEAM"
	Game.current_screen._render()
	await _frames(2)
	var rb_scr: Control = Game.current_screen
	var panels := ["ProgramRecords", "ChampionshipHistory", "SchoolBook"].map(func(n): return rb_scr.find_child(n, true, false))
	r.check(panels.all(func(p): return p is PanelContainer), "RB: TEAM is three navy panels: PROGRAM RECORDS, CHAMPIONSHIP HISTORY, SCHOOL RECORD BOOK")
	var titles: Array = c.coach.get("titles", [])
	var nat := titles.filter(func(x): return String(x).ends_with("NCSA")).size()
	var conf_l: Label = rb_scr.find_child("ConfTitles", true, false).find_child("Value", true, false)
	var nat_l: Label = rb_scr.find_child("NatTitles", true, false).find_child("Value", true, false)
	r.check(conf_l.text == str(titles.size() - nat) and nat_l.text == str(nat), "RB: the title counts are the trophy case's (%s / %s)" % [conf_l.text, nat_l.text])
	var book := Records.school_book(c, c.school)
	var row: Node = rb_scr.find_child("Record_season_wins", true, false)
	r.check(row != null and (int(book.season_wins.v) <= 0 or _texts(row).contains(str(int(book.season_wins.v)))), "RB: a school record shows its saved value")
	var vp := rb_scr.get_viewport_rect()
	var inside := true
	for t in ["TEAM", "PLAYERS", "NCSA", "SEASON AWARDS"]:
		Game.current_screen.tab = t
		Game.current_screen._render()
		await _frames(2)
		var bk: Control = Game.current_screen.find_child("Book", true, false)
		inside = inside and bk != null and bk.get_child_count() > 0
		for p in bk.find_children("*", "PanelContainer", true, false):
			inside = inside and (p as Control).size.x <= vp.size.x and (p as Control).get_global_rect().position.x >= 0.0
	r.check(inside, "RB: every tab renders its panels, none wider than the screen")
	(Game.current_screen.find_child("WeeklyAwards", true, false) as BaseButton).pressed.emit()
	await _frames(3)
	r.check(Game.current_name == "awards", "13: the RECORD BOOK opens the conference awards")
	# game guide
	Game.goto("howto")
	await _frames(3)
	var gt := _texts(Game.current_screen)
	r.check(Game.current_screen.title_label.text == "GAME GUIDE" and gt.contains("CONTROLS") and gt.contains("DYNASTY") and Game.current_screen.find_child("Tutorial", true, false) != null,
		"16: the GAME GUIDE, its sections and the tutorial")
	r.check(not gt.contains("AD GOAL") and not gt.contains("recruiting points") and not gt.contains("nominat"), "16: nothing out of date in it")
	r.check(c.credits == credits, "22: looking around pays nothing")
	Game.goto("title")
	await _frames(1)
	Game.career = null

static func shots(runner, out: String) -> void:
	DirAccess.make_dir_recursive_absolute(out)
	Store.reset_for_tests()
	Store.mark_starter_offered()
	var c := Career.new_game("LIUB", "A", "B", 61)
	Game.career = c
	for _w in 6:
		c.queue.clear()
		while c.has_game():
			c.sim_my_game()
		for q in c.upgrades_due():
			Development.ai_spend(q)
		c.end_week()
	c.queue.clear()
	for q in c.upgrades_due():
		Development.ai_spend(q)
	var star: PoloPlayer = c.team().starters()[1]
	for s in [["more", {}], ["program", {}], ["news", {}], ["facilities", {}], ["records", {}], ["howto", {}], ["player", {"id": star.id}]]:
		Game.goto(String(s[0]), s[1])
		await runner.get_tree().create_timer(0.6).timeout
		await RenderingServer.frame_post_draw
		runner.get_viewport().get_texture().get_image().save_png(out.path_join("hub_%s.png" % s[0]))
		print("  shot ", s[0])
	Game.career = null

## The RECORD BOOK with a dynasty behind it: two seasons played to the end, then every tab.
##   godot --path game -- --test records_png <dir>
static func records_shots(runner, out: String) -> void:
	DirAccess.make_dir_recursive_absolute(out)
	Store.reset_for_tests()
	Store.mark_starter_offered()
	var c := Career.new_game("BUCK", "A", "B", 64)
	Game.career = c
	for _s in 2:
		var label := c.season_label()
		var guard := 0
		while c.season_label() == label and guard < 60:
			guard += 1
			c.queue.clear()
			for q in c.upgrades_due():
				Development.ai_spend(q)
			while c.has_game():
				c.sim_my_game()
				for q in c.upgrades_due():
					Development.ai_spend(q)
			c.end_week()
			runner._make_cuts(c)
	c.queue.clear()
	for q in c.upgrades_due():
		Development.ai_spend(q)
	for t in ["TEAM", "PLAYERS", "NCSA", "SEASON AWARDS"]:
		Game.goto("records")
		await runner.get_tree().process_frame
		Game.current_screen.tab = t
		Game.current_screen._render()
		await runner.get_tree().create_timer(0.6).timeout
		await RenderingServer.frame_post_draw
		runner.get_viewport().get_texture().get_image().save_png(out.path_join("records_%s.png" % t.replace(" ", "_").to_lower()))
		print("  shot ", t)
	Game.career = null

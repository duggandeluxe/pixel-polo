extends RefCounted
## COLLEGE WATER POLO (news.gd), to look at: before a game (NO RESULTS YET), after three weeks,
## scrolled down to AROUND THE CONFERENCE, YOUR PROGRAM, and the Dynasty Hub card.
##   godot --path game --resolution 480x270 -- --test news_png <dir>   (needs a window)

static func run(runner, dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	var c := Career.new_game("GWU", "S", "H", 640)
	c.queue.clear()
	Game.career = c
	var news: GDScript = load("res://src/ui/screens/news.gd")
	news.tab = "LEAGUE"
	Game.goto("news")
	await _shot(runner, dir, "news_0_empty")
	for _w in 3:
		c.queue.clear()
		while c.has_game():
			c.sim_my_game()
		c.end_week()
	c.queue.clear()
	Game.goto("news")
	await _shot(runner, dir, "news_1_league")
	var board: Control = Game.current_screen.find_child("AroundConference", true, false)
	var sc: Node = board.get_parent()
	while not (sc is ScrollContainer):
		sc = sc.get_parent()
	(sc as ScrollContainer).scroll_vertical = int(board.position.y)
	await _shot(runner, dir, "news_2_conference")
	news.tab = "YOUR PROGRAM"
	Game.goto("news")
	await _shot(runner, dir, "news_3_program")
	# every kind of story the game writes (and a long one to wrap), as add_news words them; then none
	var saved: Array = c.news.duplicate(true)
	var me := c.team().name
	for t in ["Released: J. Smith, K. Lee, M. Ortiz, P. Novak, R. Diaz, T. Walsh, A. Brooks, B. Carter, C. Dunn",
			"Roster set at 18. Released: A. Brooks", "J. Smith, cut by %s, signs with Rivals" % me,
			"Coach Duggan takes over at %s" % me, "REALIGNMENT: Old Name are now the %s of the East" % me,
			"PLAYOFF BUNDLE: ice baths, physio, a pep rally.",
			"NEW SEASON: +50{coin}", "Main Pool upgraded to level 3", "SIGNED: A. Brooks (CB, 4*) joins next season",
			"DEV RECRUIT SIGNED: Ann Brooks has committed to GWU!", "J. Smith grows into a Sniper",
			"Recovery week: 2 players healthy again", "J. Smith: Hamstring injury in training", "J. Smith: NEW ATTRIBUTE UPGRADE AVAILABLE!",
			"3 %s players named All-Conference" % me, "NCSA PLAYER OF THE YEAR! John Smith", "NCSA GOLDEN ARM AWARD: J. Smith",
			"ALL-NCSA PLAYER OF THE TOURNAMENT: John Smith", "COACH OF THE YEAR! Duggan's turnaround at %s" % me,
			"%s are the #3 seed in the East tournament (a first-round bye)" % me,
			"SELECTED! %s are the #5 seed for the NCSA Championship" % me, "CONFERENCE CHAMPIONS! %s win the East" % me,
			"SCHOOL RECORD! Goals in a game: 8, J. Smith", "NCSA RECORD! Team goals in a game: 35, %s" % me,
			"%s beat Rivals 4-3" % me]:
		c.add_news(t)
		var s: Dictionary = news.story(c, c.news[0])
		runner.check(String(s.cat) != "PROGRAM NEWS" and String(s.head) != "", "program news: a kind for \"%s\" (%s)" % [t, s.cat])
	# an older save's NCSA records set elsewhere: kept in the news, not shown in YOUR PROGRAM
	c.add_news("NCSA RECORD! Biggest win: 22, Rivals U")
	c.add_news("NCSA RECORD! Goals in a game: 9, C. Lee (Rivals U)")
	c.add_news("NCSA RECORD! Goals in a game: 10, J. Smith (%s)" % me)
	var shown: Array = news.program_news(c)
	runner.check(shown.size() == c.news.size() - 2 and shown[0].t.ends_with("(%s)" % me), "program news: another school's NCSA records left out, yours kept (%d of %d)" % [shown.size(), c.news.size()])
	Game.goto("news")
	var rows: Node = Game.current_screen.find_child("Stories", true, false)
	runner.check(rows.get_child_count() == shown.size(), "program news: a row a story (%d)" % shown.size())
	await _shot(runner, dir, "news_5_program_kinds")
	var sc2: Node = Game.current_screen.find_child("Stories", true, false)
	while not (sc2 is ScrollContainer):
		sc2 = sc2.get_parent()
	(sc2 as ScrollContainer).scroll_vertical = 100000
	await _shot(runner, dir, "news_6_program_end")
	c.news = []
	Game.goto("news")
	await _shot(runner, dir, "news_7_program_empty")
	c.news = saved
	# LEAGUE RECORDS: the NCSA book, every mark; a new one goes in the book (with its week) and
	# only your own makes your news
	var other := ""
	for id in c.teams:
		if id != c.school:
			other = id
			break
	var n0 := c.news.size()
	var l0 := Records.ncsa_log(c).size()
	runner.check(Records.ncsa_log(c).all(func(e): return str(e.year).length() > 4), "records: nothing from before the dynasty in LEAGUE RECORDS")
	var big := int(Records.ncsa_book(c).game_margin.v) + 1
	Records.breaks(c, "game_margin", big, c.teams[other].name, other)
	runner.check(c.news.size() == n0 and int(Records.ncsa_book(c).game_margin.v) == big and Records.ncsa_book(c).game_margin.has("w"),
		"records: another school's NCSA record is in the book, with its week, and not your news")
	var goals := int(Records.ncsa_book(c).game_team_goals.v) + 1
	Records.breaks(c, "game_team_goals", goals, me, c.school)
	# (it's your school's record too: that line comes after it, on top)
	runner.check(news.program_news(c).slice(0, 2).any(func(n): return String(n.t).begins_with("NCSA RECORD! Team goals in a game: %d" % goals)),
		"records: your own NCSA record makes YOUR PROGRAM")
	var recs: Array = news.league_records(c)
	runner.check(recs.size() == l0 + 2 and recs[-2].key == "game_margin" and recs[-1].key == "game_team_goals"
		and String(recs[-1].head).contains("%d" % goals) and String(recs[-1].when).begins_with("WEEK") and String(recs[-1].season) == c.season_label(),
		"records: each break listed, oldest first, with its week and season (%d)" % recs.size())
	runner.check(recs[-1].mine and not recs[-2].mine, "records: yours marked as yours")
	Records.breaks(c, "game_margin", big + 1, c.teams[other].name, other)
	recs = news.league_records(c)
	runner.check(recs.size() == l0 + 3 and recs.filter(func(r): return r.key == "game_margin").size() >= 2,
		"records: a mark broken again keeps its earlier break listed")
	var back := Career.from_dict(JSON.parse_string(JSON.stringify(c.to_dict())))
	runner.check(Records.ncsa_log(back).size() == l0 + 3, "records: the list survives a save and reload")
	news.tab = "LEAGUE RECORDS"
	Game.goto("news")
	await runner.get_tree().process_frame
	runner.check(Game.current_screen.find_child("LeagueRecords", true, false).get_child_count() == recs.size(), "records: a row a break")
	await _shot(runner, dir, "news_8_records")
	var sc3: Node = Game.current_screen.find_child("LeagueRecords", true, false)
	while not (sc3 is ScrollContainer):
		sc3 = sc3.get_parent()
	(sc3 as ScrollContainer).scroll_vertical = 100000
	await _shot(runner, dir, "news_9_records_end")
	c.news = saved
	news.tab = "LEAGUE"
	Game.goto("more")
	await _shot(runner, dir, "news_4_hub")
	Game.career = null

static func _shot(runner, dir: String, name: String) -> void:
	for i in 8:
		await runner.get_tree().process_frame
	runner.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [dir, name])

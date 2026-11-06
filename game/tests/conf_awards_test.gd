extends RefCounted
## The Conference Awards update: ConfAwards' weekly awards, from the games' own stats, every
## conference, saved for good; the AWARDS screen and the player page's accolades.
##   godot --headless --path game -- --test conf_awards
##   godot --path game -- --test conf_awards_png <dir>      (screenshots: needs a window)

var r

func run(runner) -> void:
	r = runner
	print("conference awards")
	Store.reset_for_tests()
	_scores()
	await _season()
	Game.career = null

func _frames(n: int) -> void:
	for _i in n:
		await r.get_tree().process_frame

## The formulas on their own.
func _scores() -> void:
	var f := PoloPlayer.new()
	f.pos = PoloPlayer.Pos.DRIVER
	var k := PoloPlayer.new()
	k.pos = PoloPlayer.Pos.GK
	r.check(is_equal_approx(ConfAwards.score(f, {"gp": 1, "g": 2, "a": 1, "st": 1, "bl": 1, "ed": 1, "pd": 1, "to": 1, "ex": 1}, "potw"), 10 + 4 + 4 + 4 + 2 + 3 - 2 - 2),
		"POTW: the field formula (5 goal, 4 assist, 4 steal, 4 block, 2 excl drawn, 3 pen drawn, -2 turnover, -2 excl)")
	r.check(ConfAwards.score(f, {"gp": 1, "g": 4, "a": 3}, "opotw") > ConfAwards.score(f, {"gp": 1, "g": 2}, "opotw"), "OPOTW: 4 goals and 3 assists beat 2 goals")
	r.check(ConfAwards.score(f, {"gp": 1, "g": 3, "sh": 4}, "opotw") > ConfAwards.score(f, {"gp": 1, "g": 3, "sh": 12}, "opotw"), "OPOTW: the same goals on fewer shots rate higher")
	r.check(ConfAwards.score(k, {"gp": 1, "sv": 2, "ga": 0}, "dpotw") > 0.0 and ConfAwards.score(k, {"gp": 1, "sv": 2, "ga": 0}, "dpot") == 0.0,
		"DPOTW: no minimum any more (the Exclusivity update); the tournament's still wants a real tournament")
	r.check(ConfAwards.score(k, {"gp": 1, "sv": 12, "ga": 3}, "dpotw") > ConfAwards.score(f, {"gp": 1, "bl": 1}, "dpotw"), "DPOTW: 12 saves from 15 shots counts strongly")
	r.check(ConfAwards.score(f, {"gp": 1, "st": 2, "bl": 1}, "dpotw") > ConfAwards.score(k, {"gp": 1, "sv": 8, "ga": 8}, "dpotw"), "DPOTW: a big field week beats an ordinary keeper's")
	r.check(ConfAwards.score(f, {"gp": 2, "g": 4}, "potw") < 2.0 * ConfAwards.score(f, {"gp": 1, "g": 2}, "potw"), "two games count, a little less than in full")
	r.check(ConfAwards.score(k, {"gp": 1, "sv": 15}, "opotw") <= 0.0 and not ConfAwards.eligible(k, {"sv": 15}, "opotw") and ConfAwards.eligible(k, {"a": 5}, "opotw"),
		"OPOTW: a keeper's saves aren't offence; only real offence (assists, goals) makes him eligible")
	# a goal in a game you played counts a little more (played games run to fewer goals)
	r.check(ConfAwards.score(f, {"gp": 1, "g": 3, "pg_g": 3}, "potw") > ConfAwards.score(f, {"gp": 1, "g": 3}, "potw")
		and ConfAwards.score(f, {"gp": 1, "g": 3, "pg_g": 3}, "potw") <= ConfAwards.score(f, {"gp": 1, "g": 5}, "potw"), "played games' goals count x%.2f" % ConfAwards.PLAYED_GOALS)
	# CAREER ACCOLADES: full names when they fit, else short, else two columns
	var Player = load("res://src/ui/screens/player.gd")
	var four := [[2, "PLAYER OF THE WEEK", "POTW"], [1, "ROOKIE OF THE WEEK", "ROTW"], [3, "OFFENSIVE PLAYER OF THE WEEK", "OPOTW"], [4, "DEFENSIVE PLAYER OF THE WEEK", "DPOTW"]]
	r.check(Player.accolade_layout(four, Vector2(280, 45)).mode == "full", "accolades 8: full names when there's room")
	r.check(Player.accolade_layout(four, Vector2(90, 45)).mode == "short", "accolades 9-10: POTW, ROTW, OPOTW, DPOTW when it's narrow")
	r.check(Player.accolade_layout(four, Vector2(280, 22)).mode == "two", "accolades: two columns when it's short")
	r.check(Player.accolades(Career.new(), 12345).is_empty(), "accolades 5: none won, none listed")

## A real season's weeks.
func _season() -> void:
	var c := Career.new_game("LIUB", "A", "B", 314)
	Game.career = c
	var weeks := 0
	var reconcile := true
	var matched := true
	var rookies_ok := true
	var no_rewards := true
	var keeper_d := 0
	var field_d := 0
	var cpu_win := false
	var losing_win := false
	var multi := false
	var guard := 0
	while c.week < Schedule.REGULAR_WEEKS + 2 and guard < 40:
		guard += 1
		c.queue.clear()
		while c.has_game():
			c.sim_my_game()
		for q in c.upgrades_due():
			Development.ai_spend(q)
		c._sim_others(Schedule.DAYS, true)   # (the week's games, all: as end_week does first)
		# what the week's lines say should win, worked out here on its own
		var expect := {}
		for conf in ConfAwards.CONF_ORDER:
			var lines := ConfAwards._lines(c, conf)
			var taken := {}
			for cat in ConfAwards.PICK_ORDER:
				var b := ConfAwards._best(lines.filter(func(e): return not taken.has((e.p as PoloPlayer).id)), cat)
				if not b.is_empty():
					taken[(b.p as PoloPlayer).id] = true
					expect["%s:%s" % [conf, cat]] = (b.p as PoloPlayer).id
			# the goals each team scored this week are its players' goals
			for id in c.teams:
				var t: PoloTeam = c.teams[id]
				if t.conf != conf:
					continue
				var scored := 0
				for g in c.cur().games:
					if g.r != null and (g.h == id or g.a == id):
						scored += int(g.r.s[0] if g.h == id else g.r.s[1])
				var by_players := 0
				for p: PoloPlayer in t.roster:
					by_players += int(c.week_line(p).get("g", 0))
				reconcile = reconcile and scored == by_players
		var credits := c.credits
		var xp := {}
		for id in c.teams:
			for p: PoloPlayer in c.teams[id].roster:
				xp[p.id] = [p.xp, p.tokens, p.attrs.duplicate(), p.stars]
		var made := ConfAwards.decide_week(c)   # (end_week would; deciding it first, to look)
		for id in c.teams:
			for p: PoloPlayer in c.teams[id].roster:
				no_rewards = no_rewards and xp[p.id] == [p.xp, p.tokens, p.attrs.duplicate(), p.stars]
		no_rewards = no_rewards and c.credits == credits
		r.check(ConfAwards.decide_week(c).is_empty(), "13: a week is decided once")
		for a in made:
			matched = matched and int(expect.get("%s:%s" % [a.conf, a.cat], -1)) == int(a.pid)
			var p := ConfAwards.player_of(c, a)
			if String(a.cat) == "rotw":
				rookies_ok = rookies_ok and p.year == 1
			if String(a.cat) == "dpotw":
				if p.is_keeper():
					keeper_d += 1
				else:
					field_d += 1
			cpu_win = cpu_win or String(a.team) != c.school
			for g in c.cur().games:
				if g.r != null and (g.h == a.team or g.a == a.team) and Schedule.winner(g) != String(a.team):
					losing_win = true
		var by_pid := {}
		for a in made:
			by_pid[a.pid] = int(by_pid.get(a.pid, 0)) + 1
		multi = multi or by_pid.values().any(func(n): return n > 1)   # (never: one award a player a week)
		if not made.is_empty():
			weeks += 1
		c.end_week()
	var confs := {}
	for a in c.conf_awards:
		confs[String(a.conf)] = true
	r.check(confs.size() == 5, "1: all five conferences name winners (%s)" % [confs.keys()])
	r.check(ConfAwards.CATS.all(func(cat): return c.conf_awards.any(func(a): return a.cat == cat)), "2: all four awards given")
	r.check(matched, "3: the winners are the week's best by its real stats")
	r.check(reconcile, "8, 11: a team's goals in a week are its players' recorded goals")
	r.check(cpu_win, "4: AI programs' players win")
	r.check(rookies_ok, "6: ROOKIE OF THE WEEK only ever a freshman")
	r.check(keeper_d > 0 and field_d == 0, "7-8: DEFENSIVE PLAYER OF THE WEEK is a goalkeeper's (the Accolades update): %d keepers, %d field" % [keeper_d, field_d])
	r.check(losing_win, "9: a player on a losing team can win")
	r.check(not multi, "one award a player a week")
	r.check(no_rewards, "22: no credits, XP, tokens, attributes or stars come with an award")
	r.check(weeks >= Schedule.REGULAR_WEEKS, "awards every week the games were played (%d weeks)" % weeks)
	r.check(c.conf_awards.filter(func(a): return not bool(a.get("hist", false))).size() <= weeks * 20, "at most 20 a week (this dynasty's: Legacy's past seasons apart)")
	# a conference that didn't play names nobody
	var quiet := c.conf_awards.filter(func(a): return int(a.week) >= Schedule.REGULAR_WEEKS)
	r.check(quiet.all(func(a): return ConfAwards._lines(c, String(a.conf)) != null), "12: postseason weeks only name players who played")
	# your player: a big week of his own wins
	var c2 := Career.new_game("LIUB", "A", "B", 315)
	var g2 := 0
	while not c2.has_game() and g2 < 5:   # (a week your team plays)
		g2 += 1
		c2.queue.clear()
		c2.end_week()
	while c2.has_game():
		c2.sim_my_game()
	c2._sim_others(Schedule.DAYS, true)
	var star: PoloPlayer = c2.team().starters()[2]
	star.add_stat("g", 30)   # (test only: a week no one else gets near)
	ConfAwards.decide_week(c2)
	var mine := ConfAwards.of(c2, c2.year, c2.week, c2.team().conf)
	r.check(int(mine.get("potw", {}).get("pid", -1)) == star.id, "5: your players win too")
	# saved for good
	var text := JSON.stringify(c.to_dict())
	var back := Career.from_dict(JSON.parse_string(text))
	r.check(JSON.stringify(back.conf_awards) == JSON.stringify(c.conf_awards) and back.awards_done == c.awards_done, "13: winners unchanged after a save")
	r.check(JSON.stringify(back.to_dict()) == text, "13: the save round-trips exactly")
	# a winner who's gone keeps his profile
	var rec: Dictionary = c.conf_awards.filter(func(a): return not bool(a.get("hist", false)))[0]
	for id in c.teams:
		var gone := (c.teams[id] as PoloTeam).find_id(int(rec.pid))
		if gone != null:
			c.teams[id].roster.erase(gone)
	var ghost := ConfAwards.player_of(c, rec)
	r.check(ghost != null and ghost.id == int(rec.pid), "18: a winner who left still opens, as he was")
	# the screen
	Game.career = back
	back.queue.clear()
	Game.goto("awards")
	await _frames(3)
	var scr = Game.current_screen
	r.check(Game.current_name == "awards", "the AWARDS screen opens")
	var shown := []
	for b in scr.find_children("*", "Button", true, false):
		shown.append((b as Button).text)
	r.check(["PEC", "GCC", "WWPC", "NCC", "AWPC"].all(func(t): return t in shown), "14: five conference tabs")
	var grid: GridContainer = scr.find_child("Cards", true, false)
	r.check(grid != null and grid.columns == 2 and grid.get_child_count() == 4, "16: four award cards, 2 x 2")
	r.check(scr.find_child("PrevWeek", true, false) != null and (scr.find_child("NextWeek", true, false) as Button).disabled, "15: the latest week first, none to come")
	var card: Node = null
	for ch in grid.get_children():
		if ch is BaseButton:
			card = ch
			break
	if card != null:
		var pid := int(card.get_meta("pid"))
		(card as BaseButton).pressed.emit()
		await _frames(3)
		r.check(Game.current_name == "player" and Game.current_screen.p.id == pid and Game.current_screen.viewonly, "18: a card opens the winner's profile, read only")
		var acc: Node = Game.current_screen.find_child("Accolades", true, false)
		var want: Array = Game.current_screen.accolades(back, pid)
		r.check(acc != null and acc.get_meta("entries") == want and not want.is_empty(), "20: his profile's CAREER ACCOLADES count his awards (%s)" % [want])
		var stats: Node = Game.current_screen.find_child("Heading_PLAYER_STATISTICS", true, false)
		r.check(stats != null and acc.get_global_rect().position.y > stats.get_global_rect().position.y and acc.get_parent() == stats.get_parent(), "accolades 4: directly under PLAYER STATISTICS")
		Game.current_screen.on_back()
		await _frames(3)
	Game.goto("awards")
	await _frames(2)
	(Game.current_screen.find_child("HistoryToggle", true, false) as BaseButton).pressed.emit()
	await _frames(2)
	var hist: Node = Game.current_screen.find_child("HistoryList", true, false)
	r.check(hist != null and hist.get_child_count() > 0, "19: AWARD HISTORY lists them")
	Game.current_screen.history = false
	for q in Game.career.upgrades_due():   # (an unspent upgrade would open before the home screen)
		Development.ai_spend(q)
	Game.goto("hub")
	await _frames(3)
	r.check(Game.current_screen.find_child("Awards", true, false) != null, "10: an AWARDS button on the home screen")
	Game.goto("title")
	await _frames(1)

static func shots(runner, out: String) -> void:
	DirAccess.make_dir_recursive_absolute(out)
	Store.reset_for_tests()
	Store.mark_starter_offered()
	var c := Career.new_game("LIUB", "A", "B", 314)
	Game.career = c
	for _w in 4:
		c.queue.clear()
		while c.has_game():
			c.sim_my_game()
		for q in c.upgrades_due():
			Development.ai_spend(q)
		c.end_week()
	c.queue.clear()
	for q in c.upgrades_due():
		Development.ai_spend(q)
	var tree: SceneTree = runner.get_tree()
	for shot in [["awards", {}, "awards_week"], ["hub", {}, "awards_hub"]]:
		Game.goto(String(shot[0]), shot[1])
		await tree.create_timer(0.6).timeout
		await RenderingServer.frame_post_draw
		runner.get_viewport().get_texture().get_image().save_png(out.path_join(String(shot[2]) + ".png"))
	Game.goto("awards")
	await tree.create_timer(0.3).timeout
	Game.current_screen.history = true
	Game.current_screen._render()
	await tree.create_timer(0.4).timeout
	await RenderingServer.frame_post_draw
	runner.get_viewport().get_texture().get_image().save_png(out.path_join("awards_history.png"))
	Game.current_screen.history = false
	Game.career = null

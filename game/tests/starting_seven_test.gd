extends RefCounted
## Pregame Presentation Level 4, the Starting Seven Showcase: both teams' real sevens, together, the
## Roster's own faces, the entrance kept around it, skipped once, nothing in the game changed.
##   godot --headless --path game -- --test starting_seven
## Screenshots (needs a window): --test starting_seven_png <dir>

var r

func run(runner) -> void:
	r = runner
	print("starting seven showcase")
	Store.reset_for_tests()
	_sevens()
	_faces()
	_timeline()
	_levels()
	_every_team()
	await _match()
	await _shop()
	await _lab()
	Store.reset_for_tests()

func _intro(a: PoloTeam, b: PoloTeam, us_home := true, lv := 4, calm := false) -> PregameIntro:
	var it := PregameIntro.new(a, b, us_home, "REGULAR SEASON", "")
	it.calm = calm
	it.set_level(lv)
	return it

func _sevens() -> void:
	var a := League.make_team(2, 1)
	var b := League.make_team(3, 1)
	var it := _intro(a, b)
	r.check(it.sevens[0].team == a and it.sevens[0].men == a.starters(), "1: the home team's actual seven")
	r.check(it.sevens[1].team == b and it.sevens[1].men == b.starters(), "2: the away team's actual seven")
	for s: Dictionary in it.sevens:
		var men: Array = s.men
		r.check(men.size() == 7 and men[0] == s.team.keeper() and men.slice(1).all(func(p: PoloPlayer): return not p.is_keeper()), "3, 9: a keeper first, six field players")
	var away := _intro(a, b, false)
	r.check(away.sevens[0].team == b and away.sevens[1].team == a, "14: you away: the home team still goes first, each with its own men")
	# 10, 11: a new man in the lineup is on the graphic, and it was read once
	var seven := a.starters()
	var bench: Array = a.roster.filter(func(q: PoloPlayer): return not seven.has(q) and not q.is_keeper())
	var ids: Array = []
	for p: PoloPlayer in seven:
		ids.append(p.id)
	var was: PoloPlayer = seven[2]
	ids[2] = (bench[0] as PoloPlayer).id
	a.lineup = ids
	var after := _intro(a, b)
	r.check(after.sevens[0].men.has(bench[0]) and not after.sevens[0].men.has(was), "10: a lineup change changes the faces")
	var young := PoloPlayer.new()
	young.id = 987654
	young.first = "NEW"
	young.last = "RECRUIT"
	young.number = 44
	young.pos = (bench[0] as PoloPlayer).pos
	a.roster.append(young)
	ids[2] = young.id
	a.lineup = ids
	var locked := _intro(a, b)
	r.check(locked.sevens[0].men.has(young), "11: a recruit who starts is there")
	a.lineup = []
	r.check(locked.sevens[0].men.has(young), "12: the lineup's locked when the cinematic's made")

func _faces() -> void:
	var a := League.make_team(2, 1)
	var b := League.make_team(3, 1)
	var it := _intro(a, b)
	var same := true
	for s: Dictionary in it.sevens:
		for p: PoloPlayer in s.men:
			var col := Portrait.colors_ours(p, s.team)
			same = same and PregameIntro.face(p, s.team, Vector2i(52, 58)) == Portrait.texture(p, col[0], col[1])
			same = same and PregameIntro.face(p, s.team, Portrait.SIZE) == Portrait.texture(p, col[0], col[1])
			same = same and PregameIntro.face(p, s.team, Portrait.CARD_ZOOM) == Portrait.texture_zoomed(p, col[0], col[1], Portrait.CARD_ZOOM)
	r.check(same, "5, 6: every face is the Roster's own texture")
	var fs := PregameIntro.face_size(Vector2(480, 270))
	r.check(fs == Vector2i(52, 58) and PregameIntro._row_w(fs) <= 472.0, "28: at 480 x 270: all seven at twice the portrait's size, across (%d px)" % PregameIntro._row_w(fs))
	r.check(fs.x % Portrait.SIZE.x == 0 and fs.y % Portrait.SIZE.y == 0, "16: a whole-number zoom: nothing stretched")
	for sz: Vector2 in [Vector2(290, 150), Vector2(300, 160), Vector2(380, 150)]:
		var f := PregameIntro.face_size(sz)
		r.check(PregameIntro._row_w(f) <= sz.x - 8.0, "4: a smaller screen (%s): still all seven, across, at %s" % [sz, f])

func _timeline() -> void:
	var a := League.make_team(2, 1)
	var b := League.make_team(3, 1)
	var it := _intro(a, b)
	var seen := []
	while it.t < it.length():
		if not seen.has(it.stage()):
			seen.append(it.stage())
		it.t += 1.0 / 30.0
	r.check(seen == ["CLOSED", "OPENING", "DOORWAY", "REVEAL", "HOME SEVEN", "AWAY SEVEN", "MATCHUP"], "18-20: doors, the walk in, the reveal, home, away, the matchup (%s)" % str(seen))
	r.check(it.lineup.is_empty() and it.card_index() == -1, "15: no one-at-a-time introductions at Level 4")
	r.check(is_equal_approx(PregameIntro.SHOW_TIME, 1.8) and is_equal_approx(PregameIntro.SHOW_GAP, 0.3), "1.8 s a team, 0.3 s between")
	r.check(it.length() < 8.7, "shorter than the old Level 4's 8.7 s (%.1f)" % it.length())
	var calm := _intro(a, b, true, 4, true)
	calm.t = calm.seven_at(0) + 0.5
	r.check(calm.in_showcase() and calm.seven_index() == 0, "29: Reduce Motion: the graphic is still there")
	calm.t = calm.seven_at(1) + 0.5
	r.check(calm.seven_index() == 1, "...both of them")
	r.check(calm.length() < 7.0, "...as stills, no wipes (%.1f s)" % calm.length())
	calm.t = calm.show_from() + calm.extra() + 0.2
	r.check(calm.matchup() > 0.0 and not calm.in_showcase(), "...then the matchup")
	var sk := _intro(a, b)
	sk.t = sk.seven_at(1)
	sk.skip()
	var once := sk.done and sk.skipped
	sk.skip()
	r.check(once, "21: it skips from a graphic")

func _levels() -> void:
	var a := League.make_team(2, 1)
	var b := League.make_team(3, 1)
	for lv in [1, 2]:
		var it := _intro(a, b, true, lv)
		r.check(it.sevens.is_empty() and it.lineup.is_empty() and is_equal_approx(it.length(), PregameIntro.TOTAL), "26: Level %d as it was" % lv)
	var three := _intro(a, b, true, 3)
	r.check(three.sevens.is_empty() and three.lineup.size() == 7 and is_equal_approx(three.length(), PregameIntro.TOTAL + 7 * 0.42), "26: Level 3's cards as they were")
	r.check(is_equal_approx(_intro(a, b, true, 1, true).length(), PregameIntro.CALM_TOTAL), "26: Reduce Motion below Level 4: as it was")
	var cd := VisualUpgrades.cat("pregame")
	r.check(String(cd.tiers[3][0]) == "STARTING SEVEN SHOWCASE" and String(cd.tiers[3][1]).contains("actual player portraits"), "Level 4's card")
	r.check(int(VisualUpgrades.PRICES[3]) == 500 and VisualUpgrades.top("pregame") == 4, "27: 500 Yellow Coins, four levels")
	var k := VisualUpgrades.from_dict({"unlocked": {"pregame": 4}, "equipped": {"pregame": 4}})
	r.check(k.level("pregame") == 4 and k.worn("pregame") == 4, "25: bought and worn stay so")

func _every_team() -> void:
	var c := Career.new_setup(777)
	var teams: Array = c.teams.values()
	r.check(teams.size() == 30, "30 schools")
	var ok := true
	var size := Vector2(480, 270)
	for i in teams.size():
		var a: PoloTeam = teams[i]
		var b: PoloTeam = teams[(i + 7) % 30]
		var it := _intro(a, b)
		ok = ok and it.sevens[0].men == a.starters() and it.sevens[1].men == b.starters() and it.sevens[0].team == a
		ok = ok and (it.sevens[0].men as Array).size() == 7 and (it.sevens[0].men[0] as PoloPlayer).is_keeper()
		ok = ok and TeamLogo.art_within(a, Vector2i(60, 60)) == TeamLogo.art_within(it.sevens[0].team, Vector2i(60, 60))
		ok = ok and it.sevens[0].team.c1 == a.c1
	r.check(ok, "7, 8, 13: all 30, their own men, logo and colours")
	r.check(size.x > 0, "(480 x 270)")

func _cfg() -> Dictionary:
	return {"us": League.make_team(2, 1), "them": League.make_team(3, 1), "seed": 77, "minutes": 2.0, "autoplay": true, "intro": true, "replay": false, "home": false}

func _match() -> void:
	Store.reset_for_tests()
	Store.bank.credit(875, "T-S7")
	for i in 3:
		Store.buy_tier("pregame")
	r.check(Store.looks.worn("pregame") == 4 and Store.vault == 0, "Level 4 worn")
	Game.match_cfg = _cfg()
	Game.goto("match", Game.match_cfg)
	for i in 3:
		await r.get_tree().process_frame
	var ms = Game.current_screen
	var it: PregameIntro = ms.intro
	var us: Array = it.sevens[1].men
	var them: Array = it.sevens[0].men
	r.check(it.sevens[1].team == ms.flow.us and it.sevens[0].team == ms.flow.them, "14: you're away: they're first in a real match")
	var on_water: Array = []
	for s: Swimmer in Sprint.new(ms.flow.us, ms.flow.them, 0.0).bodies():
		if s.side == Swimmer.Side.US:
			on_water.append(s.player)
	r.check(us.size() == 7 and us.all(func(p): return on_water.has(p)), "12: the faces are the seven the match lines up")
	var score: Array = ms.flow.state.score.duplicate()
	var clock: float = ms.flow.state.clock
	var stats := str(ms.flow.state.score) + str(ms.flow.state.quarter)
	while it.t < it.seven_at(1) + 0.5:
		ms._process(1.0 / 30.0)
	r.check(ms.flow.state.score == score and is_equal_approx(ms.flow.state.clock, clock) and str(ms.flow.state.score) + str(ms.flow.state.quarter) == stats, "23: nothing moves while it plays")
	it.skip()
	ms._end_intro()
	ms._end_intro()
	r.check(ms.intro == null and ms.flow.state.score == score, "21, 22: skipped once; the match goes on from where it was")
	var seven_now: Array = ms.flow.us.starters()
	r.check(us == seven_now and them == ms.flow.them.starters(), "the lineups are as they were")
	Game.goto("title")
	await r.get_tree().process_frame
	Store.reset_for_tests()

func _shop() -> void:
	Store.reset_for_tests()
	Store.bank.credit(40, "T-S7P")
	Game.settings.dev_mode = false
	var c := Career.new_game("GWU", "S", "H", 640)
	c.queue.clear()
	Game.career = c
	var before: Array = c.team().starters().duplicate()
	var save := str(c.week) + str(c.credits)
	Game.goto("upgrade_detail", {"cat": "pregame"})
	for i in 4:
		await r.get_tree().process_frame
	var d = Game.current_screen
	d.select(4)
	d.play_level()
	r.check(d.cine is PregameIntro and d.cine.level == 4 and d.cine.sevens.size() == 2, "24: Level 4's preview without owning it")
	r.check((d.cine.sevens[0].men as Array).size() == 7 and (d.cine.sevens[1].men as Array).size() == 7, "...the real thing: the portrait lineups")
	var seen := {}
	var n := 0
	while d.cine != null and n < 600:
		seen[d.cine.stage()] = true
		d._process(1.0 / 30.0)
		n += 1
	r.check(seen.has("CLOSED") and seen.has("HOME SEVEN") and seen.has("AWAY SEVEN") and seen.has("MATCHUP"), "...doors, both graphics, the matchup: %s" % str(seen.keys()))
	r.check(Store.vault == 40 and Store.looks.level("pregame") == 1, "no coins spent, nothing owned")
	r.check(c.team().starters() == before and str(c.week) + str(c.credits) == save, "no lineup or dynasty touched")
	Game.goto("title")
	await r.get_tree().process_frame
	Game.career = null

func _lab() -> void:
	Game.settings.dev_mode = true
	Game.goto("settings")
	for i in 3:
		await r.get_tree().process_frame
	for id in ["CinemaLab", "VisualLab", "RefineLab", "HotLab", "CoachLab"]:
		r.check(Game.current_screen.find_child(id, true, false) != null, "30: %s still there" % id)
	Game.goto("cinema_lab")
	for i in 3:
		await r.get_tree().process_frame
	var lab = Game.current_screen
	r.check(lab.intro.level == 1, "the lab starts as it did, at Level 1")
	for id in ["Showcase", "HomeSeven", "AwaySeven", "ChangeLineup", "PortraitTest", "FullSize", "TestSkip", "Motion", "NextHome", "NextAway"]:
		r.check(lab.find_child(id, true, false) != null, "lab control %s" % id)
	lab.showcase()
	r.check(lab.intro.level == 4 and is_equal_approx(lab.intro.t, 0.0) and lab.part_end < 0.0, "the complete Level 4")
	lab.seven(0)
	r.check(lab.intro.seven_index() == 0, "the home lineup")
	lab.seven(1)
	r.check(lab.intro.seven_index() == 1, "the away lineup")
	r.check(lab.portraits() == 14, "PORTRAITS: all 14")
	var real: Array = lab.home().starters().duplicate()
	var line: Array = lab.home().lineup.duplicate()
	lab.change_lineup()
	r.check(lab.intro.sevens[0].men != real and (lab.intro.sevens[0].men as Array).size() == 7, "LINEUP: a bench man on the graphic")
	r.check(lab.home().starters() == real and lab.home().lineup == line, "...the team itself untouched")
	lab.full_size()
	r.check(not lab.rows[0].visible, "FULL SIZE")
	lab.full_size()
	r.check(lab.rows[0].visible, "...and back")
	Game.settings.dev_mode = false
	Game.goto("title")
	await r.get_tree().process_frame

extends RefCounted
## THE SCOREBOARD UPGRADE (Scoreboard, VisualUpgrades "scoreboard") and Developer Mode's SCOREBOARD
## VISUAL PREVIEW (scoreboard_lab.gd).
##   godot --headless --path game -- --test scoreboard
## Screenshots (needs a window): --test scoreboard_png <dir>

var r
var rects := {}                # tier -> [board, shot clock] for each pair drawn (_measure)

func run(runner) -> void:
	r = runner
	print("scoreboard")
	_upgrade()
	_abbreviations()
	await _layout()
	_override()
	await _match_switch()
	await _lab()
	Scoreboard.override = 0
	Game.goto("title")
	await _frames(2)

func _frames(n: int = 3) -> void:
	for i in n:
		await r.get_tree().process_frame

func _school(id: String) -> PoloTeam:
	var s := Colleges.school(id)
	var t := PoloTeam.new()
	t.id = id
	t.name = String(s.name)
	t.mascot = String(s.mascot)
	t.c1 = Color(String(s.c1))
	t.c2 = Color(String(s.c2))
	return t

# ------------------------------------------------------------------ the upgrade
func _upgrade() -> void:
	var c := VisualUpgrades.cat("scoreboard")
	r.check(not c.is_empty() and String(c.name) == "SCOREBOARD" and VisualUpgrades.top("scoreboard") == 3 and Scoreboard.TOP == 3, "U1: a SCOREBOARD category with three levels")
	var names: Array = (c.tiers as Array).map(func(t): return String(t[0]))
	r.check(names == ["CLASSIC SCOREBOARD", "ENHANCED SCOREBOARD", "PREMIUM SCOREBOARD"] and Scoreboard.NAMES == ["CLASSIC", "ENHANCED", "PREMIUM"], "U2: Classic, Enhanced, Premium (no Elite)")
	r.check(int(VisualUpgrades.BUILT.get("scoreboard", 0)) == 3, "U3: all three built (on sale)")
	r.check([1, 2, 3].map(func(n): return VisualUpgrades.price_of("scoreboard", n)) == [0, 100, 200] and VisualUpgrades.category_cost("scoreboard") == 300, "U4: free, 100, 200")
	var lk := VisualUpgrades.new()
	r.check(lk.level("scoreboard") == 1 and lk.worn("scoreboard") == 1, "U5: everybody starts on Classic")
	# buying: one level at a time, Level 3 only after Level 2, any owned level worn
	var c2 := Career.new_game("GWU", "E", "C", 700)
	var v := CoinVault.new()
	v.credit(1000, "T-SB")
	var pp0 := Wallet.yellow(c2, v)
	r.check(lk.next_price("scoreboard") == 100 and lk.buy_tier("scoreboard", c2, v) == "" and lk.level("scoreboard") == 2 and lk.worn("scoreboard") == 2
		and Wallet.yellow(c2, v) == pp0 - 100, "U7: Level 2 for 100, worn at once; Level 3 not with it")
	r.check(lk.next_price("scoreboard") == 200 and lk.buy_tier("scoreboard", c2, v) == "" and lk.level("scoreboard") == 3
		and Wallet.yellow(c2, v) == pp0 - 300, "U8: then Level 3 for 200")
	r.check(lk.tier_block("scoreboard", c2, v) == "MAX LEVEL UNLOCKED" and lk.next_price("scoreboard") == 0, "U9: nothing past Level 3")
	r.check(lk.equip("scoreboard", 1) and lk.worn("scoreboard") == 1 and lk.equip("scoreboard", 2) and not lk.equip("scoreboard", 4), "U10: any owned level worn, never a Level 4")
	# an older save that had Level 4 ELITE
	var old := VisualUpgrades.from_dict({"unlocked": {"scoreboard": 4, "crowd": 4}, "equipped": {"scoreboard": 4, "crowd": 2}})
	r.check(old.level("scoreboard") == 3 and old.worn("scoreboard") == 3 and int(old.unlocked.scoreboard) == 3 and int(old.equipped.scoreboard) == 3,
		"S1: an old save's Level 4: owns Levels 1-3, wears Level 3, no 4 left in it")
	r.check(old.level("crowd") == 3 and old.worn("crowd") == 2, "S2: the other upgrades kept (Crowd's old 4 -> its new 3)")
	var mid := VisualUpgrades.from_dict({"unlocked": {"scoreboard": 4}, "equipped": {"scoreboard": 2}})
	r.check(mid.level("scoreboard") == 3 and mid.worn("scoreboard") == 2, "S3: Level 4 owned, Level 2 worn: Level 2 stays on")
	var two := VisualUpgrades.from_dict({"unlocked": {"scoreboard": 2}, "equipped": {"scoreboard": 2}})
	r.check(two.level("scoreboard") == 2 and two.worn("scoreboard") == 2 and two.next_price("scoreboard") == 200, "S4: Level 2 owned stays owned; Level 3 is 200")
	r.check(UpgradeArt.TAGS.has("scoreboard"), "U6: the gallery card has its line")

# ------------------------------------------------------------------ abbreviations
func _abbreviations() -> void:
	var seen := {}
	var ok := true
	var wide := true
	for s in Colleges.SCHOOLS:
		var a := Scoreboard.abbr(_school(String(s.short)))
		ok = ok and not seen.has(a) and a.length() >= 2 and a.length() <= 4
		wide = wide and UI.text_width(a, 8, "caps") <= Hud.NAME_MIN
		seen[a] = true
	r.check(ok and seen.size() == Colleges.SCHOOLS.size(), "A1: every school has its own abbreviation (%s)" % ", ".join(seen.keys()))
	r.check(wide, "A2: each fits Classic's narrowest name slot")
	r.check(Scoreboard.abbr(_school("FORDU")) == "BRO" and Scoreboard.abbr(_school("CUSD")) == "SD", "A3: BRONX: BRO, SAN DIEGO: SD")
	var bk := Colleges.SCHOOLS.filter(func(s): return Colleges.place(String(s.short)) == "Brooklyn")
	r.check(bk.size() == 1 and Scoreboard.abbr(_school(String(bk[0].short))) == "BKN", "A3b: BROOKLYN: BKN (not BRONX's BRO)")
	r.check(Scoreboard.abbr(_school("CULA")) != Scoreboard.abbr(_school("CUSC")), "A4: the two Los Angeles schools differ (%s, %s)" % [Scoreboard.abbr(_school("CULA")), Scoreboard.abbr(_school("CUSC"))])
	var club := League.make_team(2, 1)
	r.check(Scoreboard.abbr(club) != "", "A5: a made-up club has one too (%s)" % Scoreboard.abbr(club))
	var lm := Scoreboard.name_label(_school("USAF"), Scoreboard.P_SLOT[1])
	r.check(lm.lines == [Scoreboard.abbr(_school("USAF"))], "A7: COLORADO SPRINGS doesn't fit Premium's slot: its abbreviation")
	r.check(Scoreboard.name_label(_school("FORDU"), Scoreboard.P_SLOT[1]).lines == ["BRONX"], "A8: BRONX fits whole")

# ------------------------------------------------------------------ the layout
## Every tier, every school against the widest names: on screen, centred, clear of the pause
## button and the play calls, the shot clock on screen, nothing below MAX_BOTTOM.
func _layout() -> void:
	var ids: Array = Colleges.SCHOOLS.map(func(s): return String(s.short))
	var st := MatchState.new()
	st.score = [21, 19]
	st.quarter = 4
	var pairs: Array = []
	for i in ids.size():
		pairs.append([ids[i], ids[(i + 13) % ids.size()]])
	var cv := UI.canvas(480, 270, func(ci: Control):
		for tier in range(1, Scoreboard.TOP + 1):
			var all: Array = []
			for pr in pairs:
				var a := _school(pr[0])
				var b := _school(pr[1])
				var board := Hud.scoreboard(ci, 480.0, st, a, b, Color("f2f2e9"), b.c1, b.c2, {}, tier)
				var sc := Scoreboard.shot_clock(ci, tier, board, 3.0)
				all.append([board, sc])
			rects[tier] = all)
	Game.screen_root.add_child(cv)
	cv.size = Vector2(480, 270)
	cv.queue_redraw()
	await _frames(3)
	cv.queue_free()
	r.check(rects.size() == Scoreboard.TOP, "L0: all three drawn")
	for tier in rects:
		var ok := true
		var why := ""
		for pair in rects[tier]:
			var b: Rect2 = pair[0]
			var sc: Rect2 = pair[1]
			var centred := absf(b.get_center().x - 240.0) <= 2.0
			if not (b.position.x >= 0.0 and b.end.x <= 480.0 - 24.0 - 54.0 - 4.0 and sc.position.x >= 2.0 and b.end.y <= Scoreboard.MAX_BOTTOM + 1.0 and centred and sc.end.x <= b.position.x + 2.0):
				ok = false
				why = "%s / %s" % [str(b), str(sc)]
		r.check(ok, "L%d: tier %d on screen, centred, clear of the pause button and the play calls %s" % [tier, tier, why])
	var widths: Array = []
	for tier in range(1, Scoreboard.TOP + 1):
		widths.append((rects[tier] as Array).map(func(p): return (p[0] as Rect2).size.x).max())
	r.check(widths[1] > widths[0], "L5: Enhanced is bigger than Classic (%s)" % str(widths))
	r.check(Scoreboard.below(rects[1][0][0]) == 25.0, "L6: under Classic, the man-up pill stays where it always was")

# ------------------------------------------------------------------ the override
func _override() -> void:
	var dev = Game.settings.get("dev_mode", false)
	var worn := Store.looks.worn("scoreboard")
	Game.settings.dev_mode = true
	Scoreboard.override = 3
	r.check(Scoreboard.tier() == 3, "O1: Developer Mode's override is the tier shown")
	Game.settings.dev_mode = false
	r.check(Scoreboard.tier() == worn, "O2: Developer Mode off: the level worn again (the override does nothing)")
	Game.settings.dev_mode = dev
	Scoreboard.override = 0
	r.check(Scoreboard.tier() == worn, "O3: no override: the level worn")
	var src := FileAccess.get_file_as_string("res://src/match/scoreboard.gd")
	r.check(src.contains("static var override") and not FileAccess.get_file_as_string("res://src/autoload/store.gd").contains("Scoreboard.override"), "O4: the override is a session value, never in the store's file")

# ------------------------------------------------------------------ switching mid-match
func _match_switch() -> void:
	var dev = Game.settings.get("dev_mode", false)
	Game.settings.dev_mode = true
	Game.match_cfg = {"us": League.make_team(2, 1), "them": League.make_team(3, 1), "seed": 9, "minutes": 2.0, "autoplay": false}
	Game.goto("match", Game.match_cfg)
	await _frames(3)
	var ms = Game.current_screen
	if ms.intro != null:
		ms.intro.skip()
		ms._end_intro()
	ms.flow._start_attack(Play.Kind.HALF_COURT)
	await _frames(2)
	var play = ms.flow.play
	var before := [ms.flow.state.clock, (ms.flow.state.score as Array).duplicate(), ms.flow.phase, play.shot_clock, ms.flow.state.quarter]
	var looks := JSON.stringify(Store.looks.to_dict())
	var tiers := []
	UI.drawn_log = []
	for k in 3:
		ms.cycle_board()
		tiers.append(Scoreboard.tier())
		ms.queue_redraw()
	var after := [ms.flow.state.clock, (ms.flow.state.score as Array).duplicate(), ms.flow.phase, play.shot_clock, ms.flow.state.quarter]
	r.check(tiers.all(func(t): return t >= 1 and t <= 3) and tiers.size() == 3 and _distinct(tiers) == 3, "M1: BOARD / F8 steps through all three (%s)" % str(tiers))
	r.check(ms.flow.play == play and before == after, "M2: switching never touches the match: the play, both clocks, the score, the phase, the quarter")
	r.check(JSON.stringify(Store.looks.to_dict()) == looks, "M3: nothing owned or worn changes")
	await _frames(3)
	r.check(ms.flow.play == play and not play.over, "M4: the possession carries on after a switch")
	UI.drawn_log = null
	Game.settings.dev_mode = false
	var t0 := Scoreboard.tier()
	ms.cycle_board()
	r.check(Scoreboard.tier() == t0, "M5: Developer Mode off: no switching in a match")
	Game.settings.dev_mode = dev
	Scoreboard.override = 0

func _distinct(a: Array) -> int:
	var d := {}
	for x in a:
		d[x] = true
	return d.size()

# ------------------------------------------------------------------ SCOREBOARD VISUAL PREVIEW
func _lab() -> void:
	var dev = Game.settings.get("dev_mode", false)
	Game.settings.dev_mode = true
	var looks := JSON.stringify(Store.looks.to_dict())
	DevGate.try_unlock("8008")   # (the developer tools: the DEV screen, behind its code)
	Game.goto("dev_settings")
	await _frames(3)
	r.check(Game.current_screen.find_child("ScoreboardLab", true, false) != null, "D1: Developer Mode's tools list SCOREBOARD VISUAL PREVIEW")
	Game.goto("scoreboard_lab")
	await _frames(4)
	var lab = Game.current_screen
	r.check(lab.title_label.text == "SCOREBOARD VISUAL PREVIEW", "D2: its title")
	for n in 3:
		r.check(lab.find_child("Tier%d" % (n + 1), true, false) != null, "D3.%d: a TIER %d button" % [n + 1, n + 1])
	r.check(lab.find_child("Tier4", true, false) == null, "D3.4: no TIER 4")
	await _frames(10)
	var play = lab.play
	var sc0: float = play.shot_clock
	var st := [lab.board_st.clock, (lab.board_st.score as Array).duplicate()]
	for n in [3, 2, 1]:
		lab.set_tier(n)
	r.check(lab.tier == 1 and lab.play == play, "D4: tiers switch instantly, the same possession on")
	await _frames(10)
	r.check(lab.play == play and play.shot_clock < sc0 and lab.board_st.clock < float(st[0]), "D5: the live play's shot clock and the game clock keep running (%.2f -> %.2f)" % [sc0, play.shot_clock])
	r.check(lab.board_st.score == st[1], "D6: the score is untouched by a switch")
	lab.next_team(0)
	lab.next_team(1)
	r.check(lab.home() != lab.away() and lab.home().roster != lab.away().roster, "D7: HOME / AWAY: two different schools, different players")
	var seen := {}
	for i in 33:
		lab.next_team(0)
		seen[lab.home()] = true
	r.check(lab.squads.all(func(q): return seen.has(q)) and seen.size() >= 31, "D8: HOME runs through the schools and the made-up clubs (%d)" % seen.size())
	var s0 := (lab.board_st.score as Array).duplicate()
	lab.test_goal(0)
	r.check(not lab.board_fx().is_empty() and lab.board_st.score == s0, "D9: GOAL HOME: the board's animation, the point not yet counted")
	for i in 120:
		lab.lab_tick(1.0 / 60.0)
	r.check(lab.board_fx().is_empty() and int(lab.board_st.score[0]) == int(s0[0]) + 1, "D10: ...then it counts")
	var qs := []
	for i in 5:
		lab.next_quarter()
		qs.append("SO" if lab.board_st.in_shootout else str(lab.board_st.quarter))
	r.check(qs.has("SO") and qs.has("1") and qs.has("4"), "D11: the quarters and the shootout cycle (%s)" % str(qs))
	lab.next_score()
	lab.next_clock()
	lab.all_view = true
	lab.stage_cv.queue_redraw()
	await _frames(2)
	r.check(lab.all_view, "D12: ALL TIERS draws")
	Scoreboard.override = 0
	lab.toggle_override()
	r.check(Scoreboard.override == lab.tier, "D13: MATCHES: the tier picked becomes the session's override")
	lab.set_tier(3)
	r.check(Scoreboard.override == 3 and Scoreboard.tier() == 3, "D14: ...and follows the tier picked")
	lab.toggle_override()
	r.check(Scoreboard.override == 0, "D15: ...off again")
	r.check(JSON.stringify(Store.looks.to_dict()) == looks, "D16: nothing owned, worn or saved changes")
	Game.settings.dev_mode = dev

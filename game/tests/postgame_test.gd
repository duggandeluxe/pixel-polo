extends RefCounted
## THE POSTGAME REVIEW & DYNAMIC EVENTS: the locker room gone, the bulletin board from the game's
## own numbers, the coaching events (when they're true of the game, ~60%, never twice running),
## the weekly awards decided on the week's real stats, XP into the development system, HEATING UP
## resets only where chosen, and nothing paid twice. The numbered checks follow the spec's
## REQUIRED TESTING list.
##   godot --headless --path game -- --test postgame
##   godot --path game -- --test postgame_png <dir>   (the board and an event, for a look)

var r   # the test runner

func run(runner) -> void:
	r = runner
	print("postgame review & events")
	Store.reset_for_tests()
	Game.progress = Progression.fresh()
	_locker_gone()
	await _board()
	_sim_review()
	_frequency()
	_no_nominations()
	_multi_upgrade()
	_maxed()
	await _save_reload()
	Game.career = null
	Game.goto("title")
	await r.get_tree().process_frame

func _frames(n: int = 2) -> void:
	for _i in n:
		await r.get_tree().process_frame

## A career at the first game, nothing queued.
func _career(seed_value: int = 31, school: String = "SJCU") -> Career:
	var c := Career.new_game(school, "A", "B", seed_value)
	c.queue.clear()
	var guard := 0
	while not c.has_game() and guard < 5:
		guard += 1
		c.end_week()
	return c

## A played game with these events: [scorer index...] etc. (indices into your seven).
func _box(c: Career, us_goals: Array, them_goals: int, extra: Dictionary = {}) -> Dictionary:
	var st := MatchState.new()
	var seven := c.team().starters()
	var them: PoloTeam = c.opponent()
	var tseven := them.starters()
	st.score = [us_goals.size(), them_goals]
	for i in us_goals:
		st.goal_by[0].append(seven[i])
		st.shot_by[0].append(seven[i])
	for k in extra.get("misses", 0):
		st.shot_by[0].append(seven[1 + k % 6])
	for i in extra.get("assists", []):
		st.assist_by[0].append(seven[i])
	for i in extra.get("steals", []):
		st.steal_by[0].append(seven[i])
	for i in extra.get("blocks", []):
		st.block_by[0].append(seven[i])
	for k in extra.get("turnovers", 0):
		st.turnover_by[0].append(seven[1 + k % 6])
	for k in extra.get("excl", 0):
		st.excl_by[0].append(seven[1 + k % 6])
	for k in them_goals:
		st.goal_by[1].append(tseven[1 + k % 6])
		st.shot_by[1].append(tseven[1 + k % 6])
	st.saves = [int(extra.get("saves", 5)), 3]
	return st.box(c.team(), them)

# ------------------------------------------------------------------ T1, T2
func _locker_gone() -> void:
	r.check(not ResourceLoader.exists("res://src/ui/screens/locker.gd"), "T1: the locker room screen is gone")
	var src := FileAccess.get_file_as_string("res://src/data/locker_data.gd")
	r.check(not src.contains("TALKS") and not src.contains("PIZZA") and not src.contains("STRUGGLE"), "T1: its talks, pizza night and the word with the struggler are gone")
	var ev_src := FileAccess.get_file_as_string("res://src/core/coach_events.gd") + FileAccess.get_file_as_string("res://src/core/postgame.gd")
	r.check(not ev_src.contains(".morale") and not ev_src.contains("\"morale\""), "T2: the events never touch morale")

# ------------------------------------------------------------------ T45
func _board() -> void:
	var c := _career()
	Game.career = c
	var box := _box(c, [1, 1, 1, 2, 3, 3, 4, 5], 6, {"misses": 6, "assists": [2, 2, 4], "steals": [3, 3, 5], "blocks": [3], "turnovers": 4, "excl": 2, "saves": 9})
	var sm := c.finish_my_game(box)
	var rv: Dictionary = sm.get("review", {})
	r.check(not rv.is_empty(), "T45: a played game comes with its review")
	var t: Dictionary = rv.team
	r.check(t.g == [8, 6] and t.sh[0] == 14 and t.pct[0] == 57 and t.a[0] == 3 and t.st[0] == 3 and t.bl[0] == 1 and t.to[0] == 4 and t.ex[0] == 2,
		"T45: the team sheet is the game's own events (%s)" % str(t))
	var seven := c.team().starters()
	r.check(Postgame.top_scorer(rv).pid == seven[1].id and int(Postgame.top_scorer(rv).g) == 3, "T45: top scorer: the man with three")
	r.check(Postgame.top_playmaker(rv).pid == seven[2].id and Postgame.top_defender(rv).pid == seven[3].id and Postgame.keeper(rv).pid == seven[0].id,
		"T45: playmaker, defender and keeper are the real ones")
	r.check(not rv.notes.is_empty() and rv.notes.size() <= 3, "T45: two or three coach's notes (%s)" % str(rv.notes))
	r.check("CLINICAL SHOOTING. WE TOOK OUR CHANCES." in rv.notes, "T7: 57%% shooting is noted as such")
	var bad := Postgame.notes({"team": {"g": [5, 9], "sh": [20, 15], "pct": [25, 60], "a": [1, 4], "st": [1, 2], "bl": [0, 1], "ed": [1, 2], "ex": [2, 1], "pd": [0, 0], "to": [10, 3], "sv": [4, 6]}, "players": []})
	r.check("WE STRUGGLED TO FINISH OUR CHANCES." in bad and "BALL SECURITY NEEDS WORK." in bad, "T7: 25%% shooting and 10 turnovers are what the notes say (%s)" % str(bad))
	var again := Postgame.notes({"team": {"g": [5, 9], "sh": [20, 15], "pct": [25, 60], "a": [1, 4], "st": [1, 2], "bl": [0, 1], "ed": [1, 2], "ex": [6, 1], "pd": [0, 0], "to": [10, 3], "sv": [4, 6]}, "players": []}, bad)
	r.check(again[0] == "TOO MANY EXCLUSIONS COMMITTED.", "T7: a new true note goes first the next game (%s)" % str(again))
	# the screen
	c.last_summary = sm
	Game.goto("postgame_review")
	await _frames(3)
	var scr = Game.current_screen
	r.check(Game.current_name == "postgame_review" and scr.find_child("Board", true, false) != null and scr.find_child("Continue", true, false) != null, "T45: the board, and CONTINUE")
	r.check(c.pending_event.is_empty(), "T34: no event while the board is up")
	var log0 := c.event_log.size()
	scr._continue()
	await _frames(3)
	r.check(c.event_log.size() == log0 + 1, "T46: CONTINUE draws (at most) one event")
	if Game.current_name == "coach_event":
		r.check(not c.pending_event.is_empty(), "T46: the event is saved until it's answered")
		var ev = Game.current_screen
		r.check(ev.find_child("Headline", true, false) != null and ev.find_child("Choice0", true, false) != null and ev.find_child("Choice1", true, false) != null, "T43: headline and two choices")
		ev.pick = 1
		ev._render()
		await _frames(1)
		ev._confirm()
		await _frames(1)
		r.check(c.pending_event.is_empty() and c.last_summary.is_empty() and ev.find_child("Result", true, false) != null, "T46: answered once: cleared, the result shown")
		ev._leave()
		await _frames(2)
	r.check(Game.current_name in ["hub", "player"], "T33: then the season (or the upgrades first): %s" % Game.current_name)
	Game.goto("title")
	await _frames(1)
	Game.career = null

## A simmed game: its steals and turnovers estimated (marked), the same each time.
func _sim_review() -> void:
	var c := _career(44)
	var sm := c.sim_my_game()
	var rv: Dictionary = sm.get("review", {})
	r.check(not rv.is_empty() and rv.get("estimated", []) == ["st", "to"] and rv.team.st != null and rv.team.to != null and rv.team.pd == null,
		"T6: a simmed game's board: steals and turnovers estimated and marked, 5 m drawn not simulated")
	var opp: PoloTeam = c.teams[sm.opp]
	var rng1 := RandomNumberGenerator.new()
	rng1.seed = 5
	var rng2 := RandomNumberGenerator.new()
	rng2.seed = 5
	r.check(Postgame.estimate_steals(c.team(), opp, rng1) == Postgame.estimate_steals(c.team(), opp, rng2), "T6: the estimate is the same for the same game")
	var total := 0
	for pl in rv.players:
		total += int(pl.st)
	r.check(total == int(rv.team.st[0]) and int(rv.team.to[1]) >= int(rv.team.st[0]), "T6: your steals are your players', and their turnovers include them")

# ------------------------------------------------------------------ T47
func _review(won: bool, us: int, them: int, extra: Dictionary = {}) -> Dictionary:
	var c: Career = extra.get("c")
	var players: Array = []
	for p: PoloPlayer in c.team().starters():
		players.append({"pid": p.id, "name": p.short_name(), "last": p.last, "pos": p.pos, "year": p.year, "gk": p.is_keeper(),
			"g": 0, "a": 0, "sh": 0, "st": 0, "bl": 0, "ed": 0, "sv": int(extra.get("sv", 6)) if p.is_keeper() else 0, "ga": them if p.is_keeper() else 0})
	return {"team": {"g": [us, them], "sh": [20, 20], "pct": [50, 50], "a": [2, 2], "st": [2, 2], "bl": [1, 1], "ed": [2, 2], "ex": [2, 2], "pd": [0, 0], "to": [3, 3], "sv": [6, 6]},
		"players": players, "won": won, "streak": int(extra.get("streak", 1 if won else 0)), "notes": []}

func _frequency() -> void:
	var c := _career(7)
	# a game that makes three scenarios true: a close loss, a keeper's big night, and (fresh) none other
	var rv := _review(false, 8, 9, {"c": c, "sv": 14})
	var n := 0
	var ok := true
	var repeat := false
	var last := ""
	var trials := 400
	for i in trials:
		var ev := CoachEvents.roll(c, rv)
		var id := String(ev.get("id", ""))
		if id != "":
			n += 1
			ok = ok and not CoachEvents.when(id, c, rv).is_empty()
			repeat = repeat or id == last
		last = id   # (consecutive games: an empty game in between breaks the run)
	var share := float(n) / trials
	r.check(share > 0.5 and share < 0.7, "T47: about 60%% of games bring an event when some fit (%.2f)" % share)
	r.check(ok, "T47/T40: every event drawn is true of the game")
	r.check(not repeat, "T11: never the same scenario twice in a row")
	var dull := _review(true, 9, 8, {"c": c, "streak": 1})
	var other := 0
	for i in 100:
		var id := String(CoachEvents.roll(c, dull).get("id", ""))
		# (nobody did anything: no event about a player's game; the close win, the practice week,
		# the next opponent and the bench can still bring one)
		other += 1 if id in ["star_in_making", "backup_breakout", "captains_speech", "keeper_confidence", "rough_night",
			"defensive_masterclass", "recruiting_ripple", "learning_experience"] else 0
	r.check(other == 0, "T11: a quiet one-goal win: no event about anybody's game (%d)" % other)
	r.check(CoachEvents.when("learning_experience", c, _review(true, 9, 8, {"c": c})).is_empty() and CoachEvents.when("recruiting_ripple", c, _review(false, 7, 8, {"c": c, "streak": 5})).is_empty(),
		"T11: no learning-from-a-loss after a win, no recruiting ripple after a loss")
	r.check(not CoachEvents.when("recruiting_ripple", c, _review(true, 9, 8, {"c": c, "streak": 4})).is_empty(), "T26: four straight wins: the recruiting ripple fits")

# ------------------------------------------------------------------ T48
func _xp_total(p: PoloPlayer) -> int:
	var t := p.xp
	for n in Development.level_index(p):
		t += Development.xp_required(n)
	return t

# ------------------------------------------------------------------ T49
## Gives `p` this week's line by adding stats after the week's snapshot.
func _week(p: PoloPlayer, g: int, a: int) -> void:
	p.add_stat("gp")
	p.add_stat("g", g)
	p.add_stat("a", a)

## The Accolades update: no coaching event is ever an award nomination (the conferences' awards
## are earned: ConfAwards); every other event is still there.
func _no_nominations() -> void:
	r.check(CoachEvents.EVENTS.all(func(e): return String(e.get("cat", "")) != "award" and not String(e.id).begins_with("award")), "award nomination events are gone")
	r.check(["star_in_making", "backup_breakout", "captains_speech", "keeper_confidence", "rough_night", "defensive_masterclass", "recruiting_ripple",
		"practice_discipline", "big_rivalry", "learning_experience", "cost_of_victory", "prove_me_wrong"].all(func(id): return not CoachEvents.scenario(id).is_empty()),
		"the Decisions & Consequences events are all there")
	r.check(not "nominations" in Career.new(), "no nominations kept")
	var c := _career(16)
	c._snap_week()
	var me: PoloPlayer = c.team().starters()[1]
	_week(me, 9, 4)   # (a week that once drew a nomination)
	var seen := {}
	for i in 300:
		var ev := CoachEvents.roll(c, _review(true, 12, 3, {"c": c}))
		seen[String(ev.get("id", ""))] = true
		c.event_log = []
	r.check(not seen.keys().any(func(id): return String(id).begins_with("award")), "300 rolls after a huge week: never an award event (%s)" % [seen.keys()])

# ------------------------------------------------------------------ T51, T52
func _multi_upgrade() -> void:
	var c := _career(17)
	var p: PoloPlayer = null
	for q in c.team().roster:
		if Development.boxes_left(q) >= 3:
			p = q
			break
	p.tokens = 0
	p.xp = 0
	var need := Development.xp_required(Development.level_index(p)) + Development.xp_required(Development.level_index(p) + 1)
	var lines := CoachEvents.give_xp([p], need + 5)
	r.check(p.tokens == 2 and p.xp == 5, "T51: one big award, two upgrades, the rest carried over (%d tokens, %d XP)" % [p.tokens, p.xp])
	r.check(lines.any(func(l): return "2 NEW ATTRIBUTE UPGRADES" in String(l)), "T51: and it says so")
	r.check(not c.upgrades_due().is_empty(), "T35: they're due before the next game")

func _maxed() -> void:
	var c := _career(18)
	var p: PoloPlayer = c.team().starters()[2]
	for k in p.key_ratings():
		p.attr_pot[k] = p.attrs[k]
	Development.reconcile(p)
	var x0 := p.xp
	var t0 := p.tokens
	var lines := CoachEvents.give_xp([p], 100)
	r.check(p.xp == x0 and p.tokens == t0 and lines.any(func(l): return "fully developed" in String(l)), "T52: a fully developed player gets no XP and no tokens")
	p.heat = 2
	r.check(CoachEvents.cool(p) and p.heat == 0, "T52: his HEATING UP still works")

# ------------------------------------------------------------------ T53
func _save_reload() -> void:
	var c := _career(19)
	c._snap_week()
	var k: PoloPlayer = c.team().starters()[0]
	var ev := {"id": "keeper_confidence", "pid": k.id, "story": 0, "vars": {"name": k.short_name(), "saves": "12", "save_pct": "70", "line": "12 saves"}}
	ev["pids"] = c.team().starters().map(func(p): return p.id)
	c.pending_event = ev.duplicate(true)
	var d := Career.from_dict(JSON.parse_string(JSON.stringify(c.to_dict())))
	r.check(String(d.pending_event.get("id", "")) == "keeper_confidence", "T53: an unanswered event survives a save")
	Game.career = d
	Game.goto("hub")
	await _frames(3)
	r.check(Game.current_name == "coach_event", "T53: reloaded, the event comes back first")
	var p0: PoloPlayer = d.team().starters()[0]
	var x0 := _xp_total(p0)
	Game.current_screen.pick = 0
	Game.current_screen._confirm()
	await _frames(1)
	var x1 := _xp_total(p0)
	r.check(d.pending_event.is_empty() and x1 >= x0, "T53: answered once")
	var d2 := Career.from_dict(JSON.parse_string(JSON.stringify(d.to_dict())))
	r.check(d2.pending_event.is_empty() and _xp_total(d2.team().find_id(p0.id)) == x1, "T53: reloading pays nothing again")
	# an older save waiting on an award nomination: that event is gone, so it's cleared
	var old: Dictionary = JSON.parse_string(JSON.stringify(c.to_dict()))
	old.pending_event = {"id": "award_opow", "pid": p0.id, "pids": [], "vars": {}}
	old["nominations"] = [{"pid": p0.id, "cat": "opow", "status": "pending"}]
	var d3 := Career.from_dict(old)
	r.check(d3.pending_event.is_empty(), "an older save's award nomination event is dropped on load")
	Game.goto("title")
	await _frames(1)
	Game.career = null

# ------------------------------------------------------------------ shots
static func shots(runner, out: String) -> void:
	DirAccess.make_dir_recursive_absolute(out)
	var tree: SceneTree = runner.get_tree()
	Store.reset_for_tests()
	Game.progress = Progression.fresh()
	var c := Career.new_game("SJCU", "A", "B", 31)
	c.queue.clear()
	Game.career = c
	var t := new()
	t.r = runner
	for sz in [Vector2i(1440, 810), Vector2i(1752, 810)]:
		DisplayServer.window_set_size(sz)
		await tree.create_timer(0.3).timeout
		var cc := Career.new_game("SJCU", "A", "B", 31)
		cc.queue.clear()
		Game.career = cc
		var sm := cc.finish_my_game(t._box(cc, [1, 1, 1, 2, 3, 3, 4, 5], 6, {"misses": 6, "assists": [2, 2, 4], "steals": [3, 3, 5], "blocks": [3], "turnovers": 4, "excl": 2, "saves": 11}))
		cc.last_summary = sm
		Game.goto("postgame_review")
		await tree.create_timer(0.6).timeout
		runner.get_viewport().get_texture().get_image().save_png(out.path_join("p01_board_%dx%d.png" % [sz.x, sz.y]))
		cc.pending_event = {"id": "keeper_confidence", "pid": cc.team().starters()[0].id, "pids": cc.team().starters().map(func(p): return p.id), "field": [], "story": 0,
			"vars": {"name": cc.team().starters()[0].short_name().to_upper(), "saves": "11", "save_pct": "65", "line": "11 saves"}, "year": cc.year, "week": cc.week}
		Game.goto("coach_event")
		await tree.create_timer(0.5).timeout
		Game.current_screen.pick = 0
		Game.current_screen._render()
		await tree.create_timer(0.3).timeout
		runner.get_viewport().get_texture().get_image().save_png(out.path_join("p02_event_%dx%d.png" % [sz.x, sz.y]))
		Game.current_screen._confirm()
		await tree.create_timer(0.3).timeout
		runner.get_viewport().get_texture().get_image().save_png(out.path_join("p03_result_%dx%d.png" % [sz.x, sz.y]))
	var cs := Career.new_game("SJCU", "A", "B", 32)
	cs.queue.clear()
	Game.career = cs
	cs.last_summary = cs.sim_my_game()
	Game.goto("postgame_review")
	await tree.create_timer(0.6).timeout
	runner.get_viewport().get_texture().get_image().save_png(out.path_join("p04_board_simmed.png"))
	DisplayServer.window_set_size(Vector2i(1440, 810))
	Game.career = null
	print("  postgame shots in ", out)

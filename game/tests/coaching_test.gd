extends RefCounted
## The Coaching Strategy Update: the COACHING screen (PICK YOUR DEFENSE, RECRUITING), SCOUT
## OPPONENT, the top three recruiting targets, PRESS + your drop on the bar, the one halftime
## MID-GAME ADJUSTMENT and their frozen first-half numbers. The numbered checks follow the
## spec's REQUIRED TESTING list.
##   godot --headless --path game -- --test coaching
##   godot --path game -- --test coaching_png <outdir>

const DT := 1.0 / 30.0
const F := DefenseFormation.F

var r   # the test runner

func run(runner) -> void:
	r = runner
	print("coaching strategy update")
	Store.reset_for_tests()
	await _coaching_screen()
	await _selection()
	await _scout()
	await _recruiting()
	await _first_half()
	await _halftime()
	_stats()
	await _timing()
	_cpu()
	await _default_kept()
	_saves()
	_press_transition()
	await _layout()
	Game.career = null
	Game.goto("title")
	await r.get_tree().process_frame

# ------------------------------------------------------------------ helpers
func _frames(n: int = 2) -> void:
	for i in n:
		await r.get_tree().process_frame

func _career(seed_value: int = 41) -> Career:
	var c := Career.new_game("GWU", "A", "B", seed_value)
	c.queue.clear()
	Game.career = c
	return c

func _scr() -> Control:
	return Game.current_screen

func _node(name: String) -> Node:
	return _scr().find_child(name, true, false)

## Every label's text on the screen, upper-cased, one string.
func _texts(root: Node) -> String:
	var out := ""
	for n in root.find_children("*", "Label", true, false):
		if not (n as Node).is_queued_for_deletion():
			out += (n as Label).text.to_upper() + "\n"
	return out

func _roundtrip(c: Career) -> Career:
	return Career.from_dict(JSON.parse_string(JSON.stringify(c.to_dict())))

## A match flow at kick-off with Coaching's `drop`.
func _flow(drop: int, seed_value: int = 5) -> MatchFlow:
	var teams: Array = r._teams()
	var f := MatchFlow.new(teams[0], teams[1], seed_value, MatchState.QUARTER_MIN)
	f.auto_keeper = 0.5
	f.set_gameplan(drop)
	return f

## Straight to the halftime break (the end of Q2).
func _to_half(f: MatchFlow) -> void:
	f.state.quarter = 2
	f._quarter_end()

func _career_match(c: Career) -> Control:
	var opp: PoloTeam = c.opponent() if c.opponent() != null else c.teams.values().filter(func(t): return t != c.team())[0]
	Game.match_cfg = {"us": c.team(), "them": opp, "seed": 9, "minutes": 2.0, "career": true}
	Game.goto("match", Game.match_cfg)
	await _frames(2)
	var ms = _scr()
	return ms

# ------------------------------------------------------------------ 1: the Coaching screen
func _coaching_screen() -> void:
	var c := _career()
	Game.goto("hub")
	await _frames(3)
	var nav = _node("Nav_coaching")
	r.check(nav != null, "T1: the hub's COACHING button opens Coaching")
	Game.goto("coaching")
	await _frames(3)
	var all := _texts(_scr())
	r.check(_scr().title_label.text == "COACHING", "T1: titled COACHING")
	r.check(not all.contains("FACILIT") and not all.contains("STAFF") and not all.contains("UPGRADE") and not all.contains(" CR"),
		"T1: no facilities, no coaching staff, no upgrades")
	var dp: Control = _node("DefensePanel")
	var rp: Control = _node("RecruitingPanel")
	r.check(dp != null and rp != null and dp.get_global_rect().end.x <= rp.get_global_rect().position.x,
		"T1: PICK YOUR DEFENSE on the left, RECRUITING on the right")
	var view := _scr().get_viewport_rect()
	var scout: Control = _node("ScoutOpponent")
	r.check(scout != null and view.encloses(scout.get_global_rect()), "T1: SCOUT OPPONENT visible without scrolling")
	r.check(_node("OpenRecruiting") != null, "T1: OPEN RECRUITING")
	r.check(_node("NoTargets") != null, "T1: a new career: NO RECRUITS SIGNED YET")
	r.check(not all.contains("PRESS"), "T1: PRESS isn't a pre-game pick")
	r.check(_scr().find_child("Drop_%d" % F.PRESS, true, false) == null and DefenseFormation.DROPS.all(func(f): return _node("Drop_%d" % f) != null),
		"T1: the four drops, M-DROP, 4-5, 5, 3-4")
	r.check(c.gameplan == DefenseFormation.DEFAULT_DROP and _node("Drop_%d" % F.M_DROP).get_meta("selected"), "T1: a new career starts on M-DROP")
	# the credits / season chips stay
	r.check(all.contains(c.season_label().to_upper()), "T1: the season chip is there")

# ------------------------------------------------------------------ 2: picking a defence
func _selection() -> void:
	var c := _career(42)
	c.gameplan = F.FIVE_DROP
	Game.goto("coaching")
	await _frames(2)
	_scr().pick(F.M_DROP)
	await _frames(1)
	r.check(_node("Drop_%d" % F.M_DROP).get_meta("selected") and not _node("Drop_%d" % F.FIVE_DROP).get_meta("selected"), "T2: M-DROP highlighted, alone")
	r.check((_node("ActiveGameplan") as Label).text == "ACTIVE GAMEPLAN: M-DROP", "T2: ACTIVE GAMEPLAN: M-DROP")
	r.check(_roundtrip(c).gameplan == F.M_DROP, "T2: saved with the career")
	r.check((_node("DropText") as Label).text == DefenseFormation.DROP_TEXT[F.M_DROP], "T2: its description")
	_scr().pick(F.FOUR_FIVE)
	await _frames(1)
	var sel := DefenseFormation.DROPS.filter(func(f): return _node("Drop_%d" % f).get_meta("selected"))
	r.check(sel == [F.FOUR_FIVE], "T2: 4-5 DROP highlighted, M-DROP no longer")
	r.check((_node("ActiveGameplan") as Label).text == "ACTIVE GAMEPLAN: 4-5 DROP" and c.gameplan == F.FOUR_FIVE, "T2: ACTIVE GAMEPLAN updated")
	_scr().pick(F.PRESS)
	r.check(c.gameplan == F.FOUR_FIVE, "T2: PRESS can't be the gameplan")
	Game.goto("hub")
	await _frames(2)
	Game.goto("coaching")
	await _frames(2)
	r.check((_node("ActiveGameplan") as Label).text == "ACTIVE GAMEPLAN: 4-5 DROP", "T2: still there after leaving Coaching")

# ------------------------------------------------------------------ 3: scouting
func _scout() -> void:
	var c := _career(43)
	c.gameplan = F.THREE_FOUR
	var g := c.next_game()
	var opp: PoloTeam = c.teams[g.opp]
	# a half-star man, to see it shown as it is
	var half: PoloPlayer = opp.roster.filter(func(q): return not q.is_keeper())[0]
	for k in Attributes.FIELD:
		half.attrs[k] = 6.2
	Attributes.sync(half)
	var before := JSON.stringify(opp.to_dict())
	var cr := c.wallet()
	Game.goto("coaching")
	await _frames(2)
	(_node("ScoutOpponent") as BaseButton).pressed.emit()
	await _frames(3)
	r.check(Game.current_name == "scout", "T3: SCOUT OPPONENT opens scouting")
	var s = _scr()
	r.check(s.scout_team == opp, "T3: the next opponent (%s)" % opp.name)
	var head := String(_node("ScoutTeam").get_meta("text"))
	r.check(head.contains(opp.name.to_upper()) and head.contains(c.record_text(opp.id)) and head.contains("RATING %d" % opp.overall_display()),
		"T3: his name, record and the game's team rating in the head (%s)" % head)
	r.check(_node("Roster") == null and _node("Detail") == null and _node("Board") != null, "Scout 1/2: no table: the Roster screen's deck of cards")
	var seven := opp.starters()
	var placed := true
	for i in seven.size():
		placed = placed and s.at(i) == seven[i]
	r.check(placed, "Scout 3: his seven in their places, his own lineup's")
	r.check(opp.roster.all(func(q): return s.page_ids().has(q.id)) and s.cards.size() == mini(opp.roster.size(), PoloTeam.LINEUP_SPOTS.size()),
		"T3 / Scout 4/5: his whole roster on the page, the bench under SUBS (%d)" % opp.roster.size())
	r.check(is_equal_approx(half.stars, 3.5), "T3: current stars, half stars as they are (%.1f)" % half.stars)
	r.check(not s.lift(seven[1].id, Vector2.ZERO), "Scout 25: nothing to drag: his lineup isn't yours")
	# a card: his page, scouting
	var k: PoloPlayer = opp.keeper()
	Game.goto("player", {"id": k.id, "view": true, "scout": true})
	await _frames(3)
	var page = _scr()
	var det := _texts(page)
	var boxes := func(keys: Array) -> bool: return keys.all(func(key): return _node("Boxes_" + key) != null)
	r.check(page.scouting and page.p == k and boxes.call(["com", "lun", "blk", "leg"]) and _node("Boxes_sho") == null,
		"T3 / Scout 16: a keeper's page: his four")
	r.check(_node("Stars_Potential") == null and _node("Stars_Current") != null and _node("XpLine") == null and _node("FlipHint") == null,
		"Scout 9/18/19: CURRENT OVERALL only: no POTENTIAL row, no XP, no flip")
	r.check(page.find_children("Up_*", "", true, false).is_empty() and page.find_children("*", "Button", true, false).all(func(b): return not String(b.tooltip_text).begins_with("Edit")),
		"Scout 25: nothing to edit or upgrade")
	r.check(_node("Accolades") != null and _node("Heading_PLAYER_STATISTICS") != null, "Scout 20-22: his statistics and Career Accolades")
	page.on_back()
	await _frames(2)
	r.check(Game.current_name == "scout", "Scout 26: back from his page: scouting")
	Game.goto("player", {"id": half.id, "view": true, "scout": true})
	await _frames(3)
	det = _texts(_scr())
	r.check(boxes.call(["pas", "sho", "str", "dfn"]), "T3 / Scout 15: a field player's page: his four")
	var all := det
	r.check(not all.contains("POTENTIAL") and not all.contains("XP") and not all.contains("CEILING") and not all.contains("LEVEL"),
		"T3: no potential, XP, levels or ceilings")
	_scr().on_back()
	await _frames(2)
	r.check(JSON.stringify(opp.to_dict()) == before and c.wallet() == cr, "T3: looking changes nobody, costs nothing (his lineup untouched)")
	_scr().on_back()
	await _frames(2)
	r.check(Game.current_name == "coaching" and c.gameplan == F.THREE_FOUR and (_node("ActiveGameplan") as Label).text.ends_with("3-4 DROP"),
		"T3 / Scout 27: back to Coaching, the gameplan kept")
	# the next opponent moves on with the schedule
	c.sim_my_game()
	c.end_week()
	var g2 := c.next_game()
	var want = c.teams.get(String(g2.get("opp", "")))
	Game.goto("scout")
	await _frames(2)
	r.check(_scr().scout_team == want, "T3: after a game, the next one's opponent (%s)" % (want.name if want else "none"))
	var wk := c.week
	c.week = c.schedule.size()
	Game.goto("scout")
	await _frames(2)
	r.check(_scr().scout_team == null and _node("NoOpponent") != null, "T3: no game left: a message, no team")
	c.week = wk

# ------------------------------------------------------------------ 4: recruiting
## Coaching's RECRUITING panel: the season's signings and the projected roster, then up to three
## incoming recruits, each opening his own profile on the Recruiting screen.
func _recruiting() -> void:
	var c := _career(44)
	c.credits = 500
	var hs: Array = c.market.duplicate()
	hs.sort_custom(func(a, b): return (a.p as PoloPlayer).id < (b.p as PoloPlayer).id)
	for x in hs.slice(0, 3):
		r.check(Recruiting.sign(c, x) == "", "(sign)")
	Game.goto("coaching")
	await _frames(2)
	var rows: Array = _node("Targets").get_children().filter(func(n): return n.name.begins_with("Target_"))
	r.check(rows.size() == 3, "T4: Coaching shows the three signed")
	var st: Label = _node("RecruitingStatus")
	r.check(st != null and st.text.contains("SIGNED 3 / %d" % Recruiting.SIGN_MAX) and st.text.contains("PROJECTED %d / %d" % [Recruiting.projected(c), c.roster_max()]),
		"T4: signings and the projected roster (%s)" % (st.text if st else ""))
	UI.drawn_log = []
	_node("RecruitingPanel").propagate_call("queue_redraw")
	await _frames(2)
	var shown := _texts(_node("RecruitingPanel")) + "\n".join(UI.drawn_log)
	UI.drawn_log = null
	var pd: PoloPlayer = hs[0].p
	r.check(shown.contains("%s. %s" % [pd.first.substr(0, 1), pd.last.to_upper()]) and shown.contains(PoloPlayer.POS_SHORT[pd.pos]) and shown.contains("NEXT SEASON"),
		"T4: name, position, joins next season")
	r.check(not shown.contains("POTENTIAL") and not shown.contains("OVR") and not shown.contains("POINTS"), "T4: nothing your scouts haven't found, no recruiting points")
	(rows[0] as BaseButton).pressed.emit()
	await _frames(3)
	var Rec = load("res://src/ui/screens/recruiting.gd")
	r.check(Game.current_name == "recruiting" and Rec.sel == pd.id and Rec.tab == "INCOMING", "T4: a signed recruit opens his own recruiting profile")
	_scr().on_back()
	await _frames(2)
	r.check(Game.current_name == "coaching", "T4: back to Coaching")
	r.check(_node("CutWarning") == null or Recruiting.over_by(c) > 0, "T4: the cut warning only when it's over")
	# one: only him
	var c2 := _career(45)
	c2.credits = 200
	Recruiting.sign(c2, c2.market[3])
	Game.goto("coaching")
	await _frames(2)
	rows = _node("Targets").get_children().filter(func(n): return n.name.begins_with("Target_"))
	r.check(rows.size() == 1 and _node("NoTargets") == null, "T4: one signing: one row, nothing made up")

# ------------------------------------------------------------------ 5: the first half
func _first_half() -> void:
	var f := _flow(F.FIVE_DROP)
	r.check(f.user_formations() == [F.PRESS, F.FIVE_DROP], "T5: PRESS and 5 DROP")
	f._start_defense(Play.Kind.HALF_COURT)
	var refused := true
	for x in [F.M_DROP, F.FOUR_FIVE, F.THREE_FOUR]:
		refused = refused and not f.select_formation(x)
	r.check(refused and not f.play.formation_locked, "T5: the other three drops refused, even called directly")
	r.check(f.select_formation(F.FIVE_DROP) and f.play.formation == F.FIVE_DROP, "T5: 5 DROP picks")
	f.play._turnover(f.play.defenders[1], "STOLEN!", "steal")
	f.defense_done()
	f.play._turnover(f.play.defenders[1], "STOLEN!", "steal")
	f.attack_done()
	r.check(f.select_formation(F.PRESS) and f.play.formation == F.PRESS, "T5: ...and PRESS")
	r.check(not f.adjust_drop(F.M_DROP) and f.drop == F.FIVE_DROP, "T5: the drop can't change in the first half")
	# in the career match: Coaching's drop, two buttons
	var c := _career(46)
	c.gameplan = F.FIVE_DROP
	var ms = await _career_match(c)
	r.check(ms.flow.drop == F.FIVE_DROP and ms.flow.user_formations() == [F.PRESS, F.FIVE_DROP], "T5: the match starts with Coaching's drop")
	ms.flow._start_defense(Play.Kind.HALF_COURT)
	ms._process(DT)
	await _frames(1)
	var rects: Array[Rect2] = ms.fbar.rects
	r.check(rects.size() == 2, "T5: two buttons on the bar")
	var names := []
	DefenseFormation.NAMES.map(func(n): names.append(n))
	UI.drawn_log = []
	ms.canvas.queue_redraw()
	await _frames(2)
	var drawn: Array = UI.drawn_log
	UI.drawn_log = null
	r.check(drawn.has("PRESS") and drawn.has("5 DROP") and not drawn.has("M-DROP") and not drawn.has("4-5 DROP") and not drawn.has("3-4 DROP"),
		"T5: PRESS | 5 DROP, no other drop shown")
	for i in 2:
		ms.flow._start_defense(Play.Kind.HALF_COURT)
		ms._process(DT)
		await _frames(1)
		var at: Vector2 = ms.fbar.rects[i].get_center()
		ms.fbar.press(at, ms.flow)
		r.check(ms.flow.play.formation == [F.PRESS, F.FIVE_DROP][i] and ms.flow.play.formation_locked, "T5: a tap on button %d calls %s" % [i, ["PRESS", "5 DROP"][i]])
	r.check(c.gameplan == F.FIVE_DROP, "T5: the match never touches Coaching's pick")
	Game.goto("title")
	await _frames(1)

# ------------------------------------------------------------------ 6 / 7: halftime
func _halftime() -> void:
	var c := _career(47)
	c.gameplan = F.FIVE_DROP
	var ms = await _career_match(c)
	var f: MatchFlow = ms.flow
	f.state.score = [3, 4]
	_to_half(f)
	ms._process(DT)
	await _frames(2)
	r.check(f.phase == MatchFlow.Phase.BREAK and f.can_adjust(), "T6: halftime: the adjustment is open")
	var hp: HalftimePanel = ms.halftime
	r.check(hp.button.size.x > 0.0 and not hp.open, "T6: MID-GAME ADJUSTMENT on the halftime card")
	ms._input(_tap(hp.button.get_center()))
	await _frames(1)
	r.check(hp.open and hp.pick == F.FIVE_DROP, "T6: open, the current drop highlighted")
	r.check(hp.drops.size() == 4 and hp.confirm.size.y >= 26.0, "T6: four drops and CONFIRM ADJUSTMENT")
	UI.drawn_log = []
	ms.canvas.queue_redraw()
	await _frames(2)
	var drawn: Array = UI.drawn_log
	UI.drawn_log = null
	# (HalftimePanel.score_line: the full line, or a shorter one when the names are long)
	var us_n := [Colleges.short_name(f.us).to_upper(), f.us.mascot.to_upper()]
	var score_line := ""
	for t in drawn:
		if " 3 - 4 " in String(t) and us_n.any(func(n): return n in String(t)):
			score_line = String(t)
	r.check(score_line != "", "T6: the halftime score, whole (%s)" % score_line)
	r.check(["CENTER GOALS", "PERIMETER GOALS", "TOTAL SHOTS", "SHOOTING %", "EXCLUSIONS DRAWN", "5-METER PENALTIES DRAWN"].all(func(x): return drawn.has(x)),
		"T6: the six numbers")
	r.check(drawn.has("CONFIRM ADJUSTMENT") and drawn.has(DefenseFormation.NAMES[F.FIVE_DROP]), "T6: the confirm and the drops drawn")
	# a tap anywhere else while it's open: Q3 waits
	ms._input(_tap(Vector2(2, 2)))
	await _frames(1)
	r.check(f.phase == MatchFlow.Phase.BREAK and hp.open, "T6: Q3 can't start with the adjustment open")
	ms._input(_tap(hp.drops[3].get_center()))
	r.check(hp.pick == F.THREE_FOUR and f.drop == F.FIVE_DROP and not f.adjusted, "T6: 3-4 picked, not yet taken")
	ms._input(_tap(hp.confirm.get_center()))
	await _frames(1)
	r.check(not hp.open and f.adjusted and f.drop == F.THREE_FOUR, "T6: confirmed: 3-4 DROP is the second half's")
	r.check(not f.can_adjust() and not f.adjust_drop(F.M_DROP) and f.drop == F.THREE_FOUR, "T6: one decision: locked")
	r.check(not hp.tap(hp.button.get_center(), f) and not hp.open, "T6: the button can't reopen it (a tap there just goes on)")
	ms._input(_tap(Vector2(2, 2)))
	await _frames(2)
	# 7: the second half
	r.check(f.phase == MatchFlow.Phase.SPRINT and f.state.quarter == 3, "T7: Q3")
	r.check(f.user_formations() == [F.PRESS, F.THREE_FOUR], "T7: PRESS and 3-4 DROP")
	f._start_defense(Play.Kind.HALF_COURT)
	r.check(not f.select_formation(F.FIVE_DROP) and f.select_formation(F.THREE_FOUR), "T7: the first half's drop is gone")
	r.check(not f.can_adjust(), "T7: no second adjustment")
	r.check(c.gameplan == F.FIVE_DROP, "T7: Coaching still has 5 DROP")
	Game.goto("title")
	await _frames(1)

func _tap(at: Vector2) -> InputEventScreenTouch:
	var ev := InputEventScreenTouch.new()
	ev.pressed = true
	ev.position = at
	ev.index = 0
	return ev

# ------------------------------------------------------------------ 8: their first half
func _stats() -> void:
	var f := _flow(F.M_DROP, 8)
	f._start_defense(Play.Kind.HALF_COURT)
	var att: Array = f.play.attackers
	var centre: PoloPlayer = att.filter(func(a): return a.tag == "C")[0].player
	var wing: PoloPlayer = att.filter(func(a): return a.tag == "2")[0].player
	# ten shots, released (the events the box score counts)
	for i in 10:
		f.play.events.append({"k": "shot", "by": centre if i < 3 else wing})
	for i in 4:
		f.play.events.append({"k": "exclusion", "drawn_by": wing, "by": f.play.defenders[0].player})
	f._collect(1)
	f._collect(1)   # (seen again: still once each)
	var goals := [centre, centre, centre, wing, wing]
	for who in goals:
		f._start_defense(Play.Kind.HALF_COURT)
		f.play.result = {"outcome": "goal", "scorer": who}
		f.defense_done()
	f._start_defense(Play.Kind.HALF_COURT)
	f.play.result = {"outcome": "penalty", "fouled": wing}
	f.defense_done()
	_to_half(f)
	var s := f.half_stats
	r.check(s.centre == 3 and s.perimeter == 2, "T8: center goals 3, perimeter goals 2 (%d, %d)" % [s.centre, s.perimeter])
	r.check(s.shots == 10 and s.pct == 50, "T8: 10 shots, 50%% (%d, %d%%)" % [s.shots, s.pct])
	r.check(s.exclusions == 4 and s.penalties == 1, "T8: 4 exclusions, 1 penalty drawn (%d, %d)" % [s.exclusions, s.penalties])
	r.check(s.score == [0, 5], "T8: the score at the half")
	# Q3 changes nothing in it
	f.break_done()
	f._start_defense(Play.Kind.HALF_COURT)
	f.play.events.append({"k": "shot", "by": wing})
	f._collect(1)
	f.play.result = {"outcome": "goal", "scorer": centre}
	f.defense_done()
	r.check(f.half_stats.centre == 3 and f.half_stats.shots == 10 and f.opp_stats().shots == 11 and f.opp_stats().centre == 4,
		"T8: frozen at the half (the game's own totals go on)")
	var z := _flow(F.M_DROP, 9)
	_to_half(z)
	r.check(z.half_stats.shots == 0 and z.half_stats.pct == 0, "T8: no shots: 0%")
	# a keeper's goal is neither
	var k := _flow(F.M_DROP, 10)
	k._start_defense(Play.Kind.HALF_COURT)
	k.play.result = {"outcome": "goal", "scorer": k.them.keeper()}
	k.defense_done()
	r.check(k.opp_stats().centre == 0 and k.opp_stats().perimeter == 0 and k.opp_stats().goals == 1, "T8: a keeper's goal: neither center nor perimeter")

# ------------------------------------------------------------------ 9: only at halftime
func _timing() -> void:
	var f := _flow(F.M_DROP, 11)
	var open := []
	f._start_defense(Play.Kind.HALF_COURT)
	open.append(["Q1", f.can_adjust()])
	f._quarter_end()
	open.append(["Q1-Q2", f.can_adjust()])
	f.break_done()
	f._start_defense(Play.Kind.HALF_COURT)
	open.append(["Q2", f.can_adjust()])
	f._quarter_end()
	var half := f.can_adjust()
	f.break_done()
	f._start_defense(Play.Kind.HALF_COURT)
	open.append(["Q3", f.can_adjust()])
	f._quarter_end()
	open.append(["Q3-Q4", f.can_adjust()])
	f.break_done()
	f._start_defense(Play.Kind.HALF_COURT)
	open.append(["Q4", f.can_adjust()])
	f.state.score = [2, 1]
	f._quarter_end()
	f.break_done()
	open.append(["FINAL", f.can_adjust()])
	r.check(half, "T9: open between Q2 and Q3")
	r.check(open.all(func(x): return not x[1]), "T9: closed in Q1, Q1-Q2, Q2, Q3, Q3-Q4, Q4 and after (%s)" % str(open.filter(func(x): return x[1])))
	r.check(f.phase == MatchFlow.Phase.FINAL and not f.adjust_drop(F.THREE_FOUR) and f.drop == F.M_DROP, "T9: nothing changes it outside halftime")
	# the halftime card's button isn't there at the other breaks
	var c := _career(48)
	var ms = await _career_match(c)
	ms.flow._quarter_end()   # end of Q1
	ms._process(DT)
	await _frames(2)
	ms.halftime.button = Rect2(200, 190, 80, 20)   # (as if one had been left from earlier)
	r.check(not ms.halftime.tap(Vector2(240, 200), ms.flow) and not ms.halftime.open, "T9: no adjustment at the end of Q1")
	Game.goto("title")
	await _frames(1)

# ------------------------------------------------------------------ 10: the computer's defence
func _cpu() -> void:
	var picks := []
	for drop in [-1, F.FIVE_DROP]:
		var f := _flow(drop, 12)
		var seen := []
		for i in 120:
			f.state.clock = f.state.quarter_len   # (turnovers take time off: the quarter never ends here)
			f._start_attack(Play.Kind.HALF_COURT)
			seen.append([f.play.formation, f.play.ai_drop])
			f.play._turnover(f.play.defenders[1], "STOLEN!", "steal")
			f.attack_done()
			f.play._turnover(f.play.defenders[1], "STOLEN!", "steal")
			f.defense_done()
		picks.append(seen)
	r.check(picks[0] == picks[1], "T10: their defence is the same whatever your gameplan")
	r.check(picks[1].all(func(x): return x[0] == F.PRESS and DefenseFormation.is_drop(int(x[1])) and x[1] == picks[1][0][1]),
		"T10: theirs is its own game plan (DropCall): PRESS to start every possession, its one drop to call (%s)" % DefenseFormation.NAMES[int(picks[1][0][1])])

# ------------------------------------------------------------------ 11: the default stays
func _default_kept() -> void:
	var c := _career(49)
	c.gameplan = F.FOUR_FIVE
	var ms = await _career_match(c)
	var f: MatchFlow = ms.flow
	_to_half(f)
	r.check(f.adjust_drop(F.M_DROP), "T11: M-DROP at halftime")
	f.break_done()
	f.state.quarter = 4
	f.state.score = [5, 3]
	f._quarter_end()
	f.break_done()
	ms._to_career()
	await _frames(3)
	r.check(c.gameplan == F.FOUR_FIVE and _roundtrip(c).gameplan == F.FOUR_FIVE, "T11: after the game Coaching still has 4-5 DROP")
	Game.goto("coaching")
	await _frames(2)
	r.check((_node("ActiveGameplan") as Label).text == "ACTIVE GAMEPLAN: 4-5 DROP", "T11: ACTIVE GAMEPLAN: 4-5 DROP")
	# the next match: a fresh halftime decision, from Coaching's drop again
	var ms2 = await _career_match(c)
	r.check(ms2.flow.drop == F.FOUR_FIVE and not ms2.flow.adjusted, "T11: the next match starts on 4-5 DROP, a new halftime decision to make")
	Game.goto("title")
	await _frames(1)

# ------------------------------------------------------------------ 12: saves
func _saves() -> void:
	var c := _career(50)
	c.gameplan = F.THREE_FOUR
	r.check(_roundtrip(c).gameplan == F.THREE_FOUR, "T12: the gameplan saves and loads")
	var d := c.to_dict()
	d.erase("gameplan")
	var old := Career.from_dict(JSON.parse_string(JSON.stringify(d)))
	r.check(old.gameplan == DefenseFormation.DEFAULT_DROP, "T12: an older save starts on M-DROP")
	r.check(old.team().roster.size() == c.team().roster.size() and old.credits == c.credits and old.market.size() == c.market.size(),
		"T12: ...and nothing else moves")
	d.gameplan = F.PRESS
	r.check(Career.from_dict(JSON.parse_string(JSON.stringify(d))).gameplan == DefenseFormation.DEFAULT_DROP, "T12: a save with PRESS (not a drop) is put right")
	# a match isn't saved part-way (a career saves before and after games), so its halftime state
	# lives and dies with the match: a reload starts the game again, decision unmade
	var f := _flow(F.THREE_FOUR, 13)
	_to_half(f)
	f.adjust_drop(F.M_DROP)
	var g := _flow(c.gameplan, 13)
	r.check(not g.adjusted and g.drop == F.THREE_FOUR and g.half_stats.is_empty(), "T12: a new match: its own halftime, nothing carried over")

# ------------------------------------------------------------------ 13: PRESS at halftime
func _press_transition() -> void:
	var f := _flow(F.M_DROP, 14)
	f._start_defense(Play.Kind.HALF_COURT)
	f.select_formation(F.PRESS)
	_to_half(f)
	r.check(f.play == null, "T13: at the break no possession is running")
	f.adjust_drop(F.FOUR_FIVE)
	f.break_done()
	f.sprint_done(false)
	r.check(f.phase == MatchFlow.Phase.DEFENSE and f.play.formation == F.PRESS and not f.play.formation_locked, "T13: Q3 starts on PRESS")
	r.check(f.user_formations()[1] == F.FOUR_FIVE, "T13: the drop button is now 4-5 DROP")
	r.check(f.select_formation(F.FOUR_FIVE) and f.play.formation == F.FOUR_FIVE, "T13: picking it calls 4-5 DROP")
	# ...and it plays as 4-5 DROP always has: its pistons take their drop duties
	var duties := {}
	var t := 0.0
	while t < 6.0 and not f.play.over:
		f.tick_defense(DT)
		for d in f.play.defenders:
			duties[d.duty] = true
		t += DT
	r.check(duties.has(DefenseFormation.Duty.DROP), "T13: the formation's own mechanics run (a DROP duty seen)")

# ------------------------------------------------------------------ 14: layout
## With a window: 16:9, a wide phone and 4:3 (the game is 480 px wide at any of them; the height
## and the phone's sides follow the screen). Headless has no real window: one pass at whatever
## the viewport is.
func _layout() -> void:
	var headless := DisplayServer.get_name() == "headless"
	var shapes: Array = [[Vector2i.ZERO, "headless"]] if headless else [[Vector2i(1440, 810), "16:9"], [Vector2i(1752, 810), "phone"], [Vector2i(1080, 810), "4:3"]]
	for shape in shapes:
		if not headless:
			DisplayServer.window_set_size(shape[0])
			await r.get_tree().create_timer(0.3).timeout
		await _layout_at(String(shape[1]), headless)
	if not headless:
		DisplayServer.window_set_size(Vector2i(1440, 810))

func _layout_at(label: String, headless: bool) -> void:
	var c := _career(51)
	c.credits = 300
	for i in 3:
		Recruiting.sign(c, c.market[0])
	Game.goto("coaching")
	await _frames(3)
	var view := _scr().get_viewport_rect()
	if not headless:
		r.check(view.size.x >= 480.0 and view.size.y >= 270.0 and minf(view.size.x / 480.0, view.size.y / 270.0) == 1.0, "T14 %s: the game's own 480 x 270 view, widened only to the screen's shape (%s)" % [label, str(view.size)])
	var ok := true
	var buttons: Array = _scr().find_children("*", "BaseButton", true, false)
	for b: Control in buttons:
		ok = ok and view.grow(0.5).encloses(b.get_global_rect())
	for i in buttons.size():
		for j in range(i + 1, buttons.size()):
			ok = ok and not (buttons[i] as Control).get_global_rect().grow(-0.5).intersects((buttons[j] as Control).get_global_rect().grow(-0.5))
	r.check(ok and buttons.size() >= 9, "T14 %s: Coaching: every button on screen, none overlapping (%d)" % [label, buttons.size()])
	var big := 0
	for b: Control in buttons:
		big += 1 if b.size.y >= 26.0 else 0
	r.check(big >= 9, "T14 %s: touch targets 26 px tall or more" % label)
	var page := _scr().body.get_parent() as ScrollContainer
	r.check(_scr().body.get_combined_minimum_size().y <= page.size.y + 0.5, "T14 %s: Coaching needs no scrolling" % label)
	for f in [F.M_DROP, F.FOUR_FIVE]:   # (4-5's description is the longest)
		_scr().pick(f)
		await _frames(2)
		var desc: Label = _node("DropText")
		r.check(desc.get_global_rect().end.y < _node("ActiveGameplan").get_global_rect().position.y + 0.5 and view.encloses(_node("ScoutOpponent").get_global_rect()),
			"T14 %s: %s's description fits, SCOUT OPPONENT on screen" % [label, DefenseFormation.NAMES[f]])
	Game.goto("scout")
	await _frames(3)
	var board: Control = _node("Board")
	var on_screen := board != null and view.encloses(board.get_global_rect())
	for n in ["ScoutTeam", "ScoutReport"]:
		on_screen = on_screen and _node(n) != null and view.encloses((_node(n) as Control).get_global_rect())
	r.check(on_screen, "T14 %s: scouting: every card and the team's two panels on screen, no scrolling" % label)
	var head_ok := _node("ScoutTeam") != null
	r.check(head_ok, "T14 %s: scouting head fits" % label)
	# the halftime panel
	var ms = await _career_match(c)
	_to_half(ms.flow)
	ms._process(DT)
	await _frames(2)
	ms.halftime.tap(ms.halftime.button.get_center(), ms.flow)
	var size: Vector2 = ms.get_viewport_rect().size
	var fit := true
	for f in DefenseFormation.DROPS:
		ms.halftime.pick = f
		ms.canvas.queue_redraw()
		await _frames(2)
		var hp: HalftimePanel = ms.halftime
		var lines := HalftimePanel.wrap_text(String(DefenseFormation.DROP_TEXT[f]), hp.drops[1].end.x - hp.drops[0].position.x)
		var text_end: float = hp.drops[2].end.y + 12.0 + lines.size() * 10.0
		fit = fit and text_end < hp.confirm.position.y - 14.0
		for b in hp.drops + [hp.confirm]:
			fit = fit and Rect2(Vector2.ZERO, size).encloses(b) and b.size.y >= 26.0
	var hp2: HalftimePanel = ms.halftime
	r.check(fit and not hp2.drops[0].intersects(hp2.drops[1]) and not hp2.drops[1].intersects(hp2.drops[3]),
		"T14 %s: halftime: buttons on screen, big, apart; every description clear of the confirm" % label)
	var stats_w := (size.x - HalftimePanel.MARGIN * 2.0 - HalftimePanel.GAP) / 2.0 - 16.0
	var widest := 0.0
	var lx := TeamLogo.box(TeamLogo.MEDIUM).x + 6.0
	var line := HalftimePanel.score_line(ms.flow.us, ms.flow.them, [99, 99], stats_w - lx)
	r.check("99 - 99" in line, "T14 %s: the halftime score line always keeps the score whole (%s)" % [label, line])
	for t in ["5-METER PENALTIES DRAWN 99", line]:
		widest = maxf(widest, Deck.text_w(t) + (lx if t == line else 0.0))
	r.check(widest <= stats_w, "T14 %s: the stats panel's longest lines fit (%.0f / %.0f)" % [label, widest, stats_w])
	Game.goto("title")
	await _frames(1)

# ------------------------------------------------------------------ screenshots
static func shots(runner, out: String) -> void:
	DirAccess.make_dir_recursive_absolute(out)
	var tree: SceneTree = runner.get_tree()
	Store.reset_for_tests()
	var c := Career.new_game("GWU", "Sam", "Rivera", 31)
	c.queue.clear()
	c.hot_tip = true
	c.credits = 200
	Game.career = c
	Recruiting.sign(c, c.market[0])
	Recruiting.sign(c, c.market[1])
	c.gameplan = DefenseFormation.F.FOUR_FIVE
	for shot in [["coaching", "c_coaching"], ["scout", "c_scout"]]:
		Game.goto(String(shot[0]))
		await tree.create_timer(0.6).timeout
		await RenderingServer.frame_post_draw
		runner.get_viewport().get_texture().get_image().save_png(out.path_join(String(shot[1]) + ".png"))
		print("  shot ", shot[1])
	var opp: PoloTeam = c.opponent()
	Game.match_cfg = {"us": c.team(), "them": opp, "seed": 9, "minutes": 2.0, "career": true}
	Game.goto("match", Game.match_cfg)
	await tree.create_timer(0.5).timeout
	var ms = Game.current_screen
	var f: MatchFlow = ms.flow
	f._start_defense(Play.Kind.HALF_COURT)
	await tree.create_timer(0.4).timeout
	await RenderingServer.frame_post_draw
	runner.get_viewport().get_texture().get_image().save_png(out.path_join("c_bar.png"))
	f.state.score = [3, 4]
	f.state.shots[1] = 9
	f.state.exclusions[1] = 2
	f.goal_spots[1].centre = 3
	f.goal_spots[1].perimeter = 1
	f.state.quarter = 2
	f._quarter_end()
	await tree.create_timer(0.4).timeout
	await RenderingServer.frame_post_draw
	runner.get_viewport().get_texture().get_image().save_png(out.path_join("c_halftime.png"))
	ms.halftime.tap(ms.halftime.button.get_center(), f)
	ms.halftime.pick = DefenseFormation.F.FOUR_FIVE
	await tree.create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	runner.get_viewport().get_texture().get_image().save_png(out.path_join("c_adjust.png"))
	print("  shots done")
	Game.career = null
	Game.goto("title")

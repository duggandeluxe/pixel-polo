extends RefCounted
## THE COACHING EVENTS DEVELOPER PANEL (coach_lab): the spec's REQUIRED TESTING (1-26).
##   godot --headless --path game -- --test coach_lab
##   godot --path game -- --test coach_lab_png <dir>

var r
var ce   # (the coaching events test: careers, players, played games)
var L    # (the lab's script: its static data functions)

func run(runner) -> void:
	r = runner
	ce = load("res://tests/coaching_events_test.gd").new()
	ce.r = runner
	ce.pg = load("res://tests/postgame_test.gd").new()
	L = load("res://src/ui/screens/coach_lab.gd")
	print("coaching events developer panel")
	Store.reset_for_tests()
	Game.progress = Progression.fresh()
	var dev_was: bool = Game.settings.get("dev_mode", false)
	await _access()
	var c: Career = ce._career(611)
	_review(c)
	await _list_and_details(c)
	await _preview(c)
	_players(c)
	await _trigger(c)
	_specials(c)
	await _active_and_sim(c)
	await _coins_and_suspensions()
	_generation_and_saves()
	Game.settings.dev_mode = dev_was
	Game.career = null
	Game.goto("title")
	await r.get_tree().process_frame

func _frames(n: int = 3) -> void:
	for _i in n:
		await r.get_tree().process_frame

func _find(name: String) -> Node:
	return Game.current_screen.find_child(name, true, false) if Game.current_screen != null else null

func _press(name: String) -> void:
	var b = _find(name)
	if b != null:
		b.emit_signal("pressed")

func _texts(n: Node) -> String:
	var out := PackedStringArray()
	for l in n.find_children("*", "Label", true, false):
		out.append((l as Label).text)
	return "\n".join(out)

## A real played game's review in memory (as roll() keeps it), the postgame then closed.
func _review(c: Career) -> void:
	var s: Dictionary = ce._play(c, true)
	CoachEvents.last_review = s.get("review", {})
	c.last_summary = {}
	c.pending_event = {}
	var guard := 0
	while not c.has_game() and guard < 5:
		guard += 1
		c.end_week()

func _lab(c: Career) -> void:
	Game.career = c
	Game.goto("coach_lab")
	await _frames()

# ------------------------------------------------------------------ 1, 26
func _access() -> void:
	Game.career = null
	Game.settings.dev_mode = false
	Game.goto("settings")
	await _frames()
	r.check(_find("CoachLab") == null, "26: Developer Mode off: no COACHING EVENTS button in Settings")
	Game.goto("coach_lab")
	await _frames()
	r.check(Game.current_name == "settings", "26: Developer Mode off: the panel can't be opened (back to Settings)")
	Game.settings.dev_mode = true
	Game.goto("settings")
	await _frames()
	r.check(_find("CoachLab") != null and _find("RecordLab") != null and _find("ResetGame") != null, "1: Developer Mode on: COACHING EVENTS beside the other developer tools (they're all still there)")
	_press("CoachLab")
	await _frames()
	r.check(Game.current_name == "coach_lab" and _find("Tab_EVENTS") != null and _find("Tab_ACTIVE") != null and _find("Tab_HISTORY") != null and _find("Tab_GENERATION") != null,
		"1: it opens: EVENTS, ACTIVE CHALLENGES, HISTORY, GENERATION")
	r.check(_find("EventList").get_child_count() == 12, "1: with no career loaded it still lists every event (mock data)")
	Game.current_screen.on_back()
	await _frames()
	r.check(Game.current_name == "settings", "1: Back returns to Settings")

# ------------------------------------------------------------------ 2-5
func _list_and_details(c: Career) -> void:
	await _lab(c)
	var names := ["A STAR IN THE MAKING", "THE BACKUP BREAKOUT", "THE CAPTAIN'S SPEECH", "A GOALKEEPER'S CONFIDENCE", "A ROUGH NIGHT", "DEFENSIVE MASTERCLASS",
		"RECRUITING RIPPLE", "PRACTICE DISCIPLINE", "THE BIG RIVALRY", "THE LEARNING EXPERIENCE", "THE COST OF VICTORY", "PROVE ME WRONG"]
	var list: Node = _find("EventList")
	var listed := _texts(list)
	r.check(list.get_child_count() == 12 and names.all(func(n): return listed.contains(n)), "2: all 12 events listed, in the system's order")
	r.check(CoachEvents.EVENTS.all(func(e): return list.find_child("Event_" + String(e.id), true, false) != null), "2: from CoachEvents.EVENTS itself (no second list)")
	var bad: Array = []
	for e in CoachEvents.EVENTS:
		var id := String(e.id)
		_press("Event_" + id)
		await _frames(2)
		var det: Node = _find("Details")
		var t := _texts(det)
		var ex: Dictionary = L.sample(c, id, L.pick_pid, false)
		var c2: Career = ex.career
		ex.special = false
		var want: Array = CoachEvents.stakes(c2, ex, 0) + CoachEvents.stakes(c2, ex, 1)
		var chs: Array = CoachEvents.choices_of(e)
		var ok: bool = (_find("Headline") as Label).text == String(e.headline) and t.contains("ID: " + id)
		ok = ok and want.all(func(s): return t.contains(String(s[0])))
		ok = ok and t.contains("CHOICE A - " + String(chs[0].label)) and t.contains("CHOICE B - " + String(chs[1].label))
		ok = ok and t.contains(String(CoachEvents.ELIGIBILITY[id][0])) and t.contains(String(CoachEvents.ELIGIBILITY[id][1]))
		ok = ok and t.contains("COOLDOWN %d" % int(e.cooldown))
		ok = ok and t.contains("SPECIAL VERSION AVAILABLE: " + ("YES" if CoachEvents.SPECIAL.has(id) else "NO"))
		if not ok:
			bad.append(id)
	r.check(bad.is_empty(), "3/4/5: each event's details: name, id, story, who, when, frequency, both choices with stakes()'s own rewards and penalties %s" % str(bad))
	# the spec's examples, as the game has them now (for a field player with a BAD grade to forgive)
	var fp: PoloPlayer = ce._dev(c)
	fp.form = [PlayerForm.BAD]
	L.ignore_reqs = true
	L.pick_pid = fp.id
	_press("Event_star_in_making")
	await _frames(2)
	var t := _texts(_find("Details"))
	r.check(t.contains("+80 XP") and t.contains("+20% HOT STAR PROGRESS") and t.contains("3 GOALS + ASSISTS") and t.contains("SUCCESS: 2X GAME XP")
		and t.contains("FAILURE: 0.75X GAME XP") and t.contains("FAILURE: -10% HOT STAR PROGRESS") and t.contains("5 GOALS") and t.contains("SUCCESS: 3X GAME XP")
		and t.contains("SPECIAL APPEARANCE PROBABILITY: 5%"), "3/15: A STAR IN THE MAKING: +80 XP, +20% HOT; 3 G+A for 2X, 0.75X and -10% HOT; special 5 GOALS for 3X, 5%")
	var expect := {"backup_breakout": ["+40 XP", "SUCCESS: +150 XP"], "rough_night": ["+60 XP", "DOUBLE COLD RECOVERY", "SUCCESS: +160 XP"],
		"recruiting_ripple": ["+20 CREDITS NOW", "-15 CREDITS NOW", "WIN NEXT GAME: +50 CREDITS"], "practice_discipline": ["-15 CREDITS NOW", "+40 XP", "MISSES THE NEXT GAME"],
		"cost_of_victory": ["-15 CREDITS NOW", "+30 XP EACH", "SUCCESS: +120 XP"]}
	var wrong: Array = []
	for id in expect:
		L.pick_pid = fp.id
		_press("Event_" + id)
		await _frames(2)
		var tt := _texts(_find("Details"))
		if not (expect[id] as Array).all(func(s): return tt.contains(s)):
			wrong.append(id)
	r.check(wrong.is_empty(), "15: the HIGH STAKES values shown: BACKUP +40/+150, ROUGH +60/+160, RIPPLE 20/15/50, DISCIPLINE 15 + 40, COST 15/30/120 %s" % str(wrong))

# ------------------------------------------------------------------ 6, 7, 22
func _preview(c: Career) -> void:
	var before := JSON.stringify(c.to_dict())
	var st := c.rng.state
	var w0 := c.wallet()
	var shown: Array = []
	var applied: Array = []
	for e in CoachEvents.EVENTS:
		var id := String(e.id)
		for sp in ([false, true] if CoachEvents.SPECIAL.has(id) else [false]):
			Game.goto("coach_lab")
			await _frames(2)
			Game.goto("coach_event", L.preview_params(id, -1, sp, true))
			await _frames()
			var scr = Game.current_screen
			var ok: bool = Game.current_name == "coach_event" and scr.preview and (_find("Headline") as Label).text == String(e.headline)
			ok = ok and _find("DevBanner") != null and (_find("DevBanner") as Label).text.begins_with("DEVELOPER PREVIEW") and _find("Confirm") == null and _find("ClosePreview") != null
			ok = ok and (_find("Portrait") != null or _find("Logo") != null) and _find("Choice0") != null and _find("Choice1") != null
			ok = ok and (_find("Special") != null) == sp
			if not ok:
				shown.append("%s%s" % [id, " sp" if sp else ""])
			for i in 2:
				_press("Choice%d" % i)
				await _frames(1)
				scr._confirm()   # (a preview's confirm does nothing)
				await _frames(1)
			if scr.answered:
				applied.append(id)
			_press("ClosePreview")
			await _frames()
	r.check(shown.is_empty(), "6: PREVIEW EVENT opens the real event screen for all 12 (and the four special versions): title, portrait or logo, both choices, PREVIEW marked %s" % str(shown))
	r.check(applied.is_empty() and Game.current_name == "coach_lab", "7: both answers can be looked at, neither applied; CLOSE PREVIEW returns to the panel")
	r.check(JSON.stringify(c.to_dict()) == before and c.rng.state == st and c.wallet() == w0 and c.pending_event.is_empty(),
		"7/22: after previewing everything: the save is byte for byte as it was (no XP, credits, HOT, suspension, challenge, lineup, event or dice used)")
	r.check(c.team().roster.all(func(p): return p.susp == 0), "22: previewing PRACTICE DISCIPLINE's suspension suspends nobody")
	# no career at all: mock data, labelled
	Game.career = null
	Game.goto("coach_event", L.preview_params("keeper_confidence", -1, false, true))
	await _frames()
	r.check(Game.current_screen.mock and (_find("DevBanner") as Label).text.contains("MOCK DATA"), "7: no career (or nobody eligible): the preview uses mock data, labelled MOCK DATA")
	r.check(L.trigger_block(null, "keeper_confidence", -1, true) != "", "Part 7: mock data can never be triggered")
	Game.career = c

# ------------------------------------------------------------------ 10-12
func _players(c: Career) -> void:
	var t := c.team()
	var all_ok := true
	for e in CoachEvents.EVENTS:
		for p in L.candidates(c, String(e.id)):
			if not p in t.roster or p.is_suspended():
				all_ok = false
	r.check(all_ok, "10: every selectable player is on your roster now, not suspended")
	var keepers: Array = L.candidates(c, "keeper_confidence")
	r.check(not keepers.is_empty() and keepers.all(func(p): return p.is_keeper()), "11: A GOALKEEPER'S CONFIDENCE lists keepers only (%d)" % keepers.size())
	var field: PoloPlayer = t.starters()[2]
	r.check(L.build_event(c, "keeper_confidence", field.id, false, true).has("error"), "11: a field player can't be made its keeper")
	var subs: Array = L.candidates(c, "backup_breakout")
	r.check(not subs.is_empty() and subs.all(func(p): return not p in t.starters()), "12: THE BACKUP BREAKOUT lists substitutes only (%d)" % subs.size())
	var pmw: Array = L.candidates(c, "prove_me_wrong")
	r.check(pmw.all(func(p): return not p in t.starters() and not CoachEvents.promotion(t, p).is_empty()), "12: PROVE ME WRONG lists backups who can legally start")
	var lead: Array = L.candidates(c, "captains_speech")
	r.check(lead.size() == 1 and lead[0] == CoachEvents.leader(c), "THE CAPTAIN'S SPEECH: the team leader (the game has no named captain)")
	var disc: Array = L.candidates(c, "practice_discipline")
	r.check(disc.all(func(p): return not p.is_keeper() and CoachEvents.suspension_ok(t, p) != null), "8/Part 8: PRACTICE DISCIPLINE: field starters whose suspension leaves a legal seven")
	r.check(L.build_event(c, "rough_night", 999999, false, true).has("error"), "Part 8: no invented player ids, even with the requirements ignored")
	# the requirements: the last game's real conditions, or ignored on request
	var real: Dictionary = L.build_event(c, "keeper_confidence", -1, false, false)
	var forced: Dictionary = L.build_event(c, "keeper_confidence", keepers[0].id, false, true)
	r.check(not forced.has("error") and int(forced.pid) == keepers[0].id, "Part 8: IGNORE REQUIREMENTS: the event for the chosen player (%s)" % str(real.get("error", "the last game qualified too")))
	var saved: Dictionary = CoachEvents.last_review
	CoachEvents.last_review = {}
	r.check(L.build_event(c, "rough_night", -1, false, false).has("error"), "Part 8: requirements on, no game in memory: nothing is made up")
	CoachEvents.last_review = saved

# ------------------------------------------------------------------ 8, 9, 13, 20
func _trigger(c: Career) -> void:
	await _lab(c)
	var p: PoloPlayer = ce._dev(c)
	var x0: int = ce._xp_total(p)
	var wk := c.week
	var log0 := CoachEvents.decisions.size()
	r.check(L.trigger_block(c, "star_in_making", p.id, true) == "", "8: TRIGGER EVENT is open for an eligible player")
	L.trigger(c, "star_in_making", p.id, false, true)
	await _frames()
	r.check(Game.current_name == "coach_event" and (_find("Headline") as Label).text == "A STAR IN THE MAKING" and (_find("DevBanner") as Label).text.contains("CHANGES YOUR SAVE")
		and _find("Confirm") != null, "8/13: the real event screen, marked as changing the save")
	r.check(bool(c.pending_event.get("dev", false)) and int(c.pending_event.pid) == p.id, "8: saved as the career's event (a reload shows it again)")
	var scr = Game.current_screen
	scr.pick = 0
	scr._confirm()
	scr._confirm()   # (twice: once only)
	await _frames()
	r.check(ce._xp_total(p) - x0 == CoachEvents.XP.star_praise, "9/20: PRAISE HIM applied by apply(), once: +%d XP (%d)" % [CoachEvents.XP.star_praise, ce._xp_total(p) - x0])
	r.check(c.pending_event.is_empty() and c.week == wk, "9: the event used up; no postgame closed, the week where it was")
	r.check(CoachEvents.decisions.size() == log0 + 1 and String(CoachEvents.decisions.back().choice) == "PRAISE HIM" and int(CoachEvents.decisions.back().xp) == CoachEvents.XP.star_praise,
		"Part 11: the decision in the session history: PRAISE HIM, +80 XP")
	_press("Continue")
	await _frames()
	r.check(Game.current_name == "coach_lab", "8: CONTINUE returns to the panel")
	c.pending_event = {"id": "rough_night", "pid": p.id}
	r.check(L.trigger_block(c, "rough_night", p.id, true).contains("WAITING"), "Part 8: a real waiting event is never overwritten")
	c.pending_event = {}

# ------------------------------------------------------------------ 13, 14, 15, 16
func _specials(c: Career) -> void:
	var forced: Array = []
	for id in CoachEvents.SPECIAL:
		var cands: Array = L.candidates(c, id)
		if cands.is_empty():
			forced.append(id + " (nobody)")
			continue
		var ev: Dictionary = L.build_event(c, id, cands[0].id, true, true)
		var st: Array = CoachEvents.stakes(c, ev, 1)
		if not CoachEvents.is_special(ev) or float(CoachEvents.challenge(c, ev).get("mult", 0.0)) != 3.0 or not st.any(func(s): return String(s[0]).contains("3X")):
			forced.append(id)
		if CoachEvents.choices_for(ev)[1].label != CoachEvents.SPECIAL[id]:
			forced.append(id + " label")
	r.check(forced.is_empty(), "13: all four rare 3X versions can be forced: special, 3X, their own choice %s" % str(forced))
	var leaked: Array = []
	for e in CoachEvents.EVENTS:
		var id := String(e.id)
		if CoachEvents.SPECIAL.has(id):
			continue
		var cands: Array = L.candidates(c, id)
		var ev: Dictionary = L.build_event(c, id, cands[0].id if not cands.is_empty() else -1, true, true)
		if ev.has("error"):
			continue
		if CoachEvents.is_special(ev) or bool(ev.special):
			leaked.append(id)
	r.check(leaked.is_empty(), "14: the other eight never get a special version, even when asked %s" % str(leaked))
	var b: PoloPlayer = L.candidates(c, "prove_me_wrong")[0] if not L.candidates(c, "prove_me_wrong").is_empty() else null
	if b != null:
		var ev: Dictionary = L.build_event(c, "prove_me_wrong", b.id, true, true)
		var s0: Array = CoachEvents.stakes(c, ev, 0)
		var s1: Array = CoachEvents.stakes(c, ev, 1)
		r.check(not CoachEvents.is_special(ev) and String(s0[0][0]).begins_with("+25 XP") and String(s1[1][0]).begins_with("WIN: TEAM 1.5X GAME XP") and String(s1[2][0]) == "LOSE: TEAM 0.75X GAME XP"
			and String(s1[3][0]).contains("XP BAR RESET TO 0") and CoachEvents.PMW_WIN == 1.5 and CoachEvents.PMW_LOSS == 0.75 and CoachEvents.XP.pmw_safe == 25,
			"15: PROVE ME WRONG exactly as it was: +25 XP; start him: team 1.5X, him 2X; lose: 0.75X and his bar reset")
	else:
		r.check(false, "15: a backup for PROVE ME WRONG")
	# the 5%: untouched by forcing
	var n := 0
	var cc := Career.new_game("SJCU", "A", "B", 77)
	for i in 4000:
		cc.week = i % 20
		cc.year = 2026 + i / 20
		if CoachEvents.roll_special(cc, "star_in_making"):
			n += 1
	r.check(CoachEvents.SPECIAL_CHANCE == 0.05 and n > 4000 * 0.035 and n < 4000 * 0.065 and not CoachEvents.roll_special(cc, "rough_night"),
		"16: the normal special chance is still 5%% (%d of 4000), and only for the four" % n)

# ------------------------------------------------------------------ 17, 18, 19, 20
func _active_and_sim(c: Career) -> void:
	var p: PoloPlayer = ce._dev(c)
	c.pending_event = {}
	L.trigger(c, "star_in_making", p.id, true, true)
	await _frames()
	var scr = Game.current_screen
	r.check(_find("Special") != null, "13: the forced special shows its SPECIAL CHALLENGE mark")
	scr.pick = 1
	scr._confirm()
	await _frames()
	var e: Dictionary = c.coach_pending.back()
	r.check(bool(e.special) and bool(e.get("dev", false)) and float(e.mult) == 3.0 and int(e.n) == 5 and String(e.stat) == "g" and float(e.fail_mult) == 0.75,
		"13: PROVE HE'S ELITE in the save: 5 goals for 3X, 0.75X if missed, marked dev")
	_press("Continue")
	await _frames()
	L.tab = "ACTIVE"
	Game.current_screen._refresh()
	await _frames()
	var panel: Node = _find("Pending_%d" % int(e.eid))
	var t := _texts(panel) if panel != null else ""
	r.check(panel != null and t.contains("A STAR IN THE MAKING") and t.contains("SPECIAL - 3X") and t.contains("5 GOALS") and t.contains("REWARD: 3X GAME XP")
		and t.contains("FAILURE: 0.75X GAME XP, -10% HOT STAR PROGRESS") and t.contains("STATUS: PENDING") and t.contains("DEV-TRIGGERED") and t.contains("YOUR NEXT GAME"),
		"17: ACTIVE CHALLENGES: event, player, objective, game, reward, penalty, variant, status (from the save)")
	var before := JSON.stringify(c.to_dict())
	var ok: Dictionary = L.simulate(c, int(e.eid), true)
	var g: Dictionary = ok.got.get(p.id, {})
	r.check(ok.outcome == "ok" and is_equal_approx(float(g.get("mult", 0)), 3.0) and int(g.xp) == roundi(int(g.base) * 3.0), "18: SIMULATE SUCCESS: award_game's 3X (%d -> %d)" % [int(g.get("base", 0)), int(g.get("xp", 0))])
	var fail: Dictionary = L.simulate(c, int(e.eid), false)
	var gf: Dictionary = fail.got.get(p.id, {})
	var copy: Career = fail.copy
	r.check(fail.outcome == "fail" and is_equal_approx(float(gf.get("mult", 0)), 0.75) and (fail.lines as Array).any(func(l): return String(l[0]).contains("HOT STAR PROGRESS")),
		"19: SIMULATE FAILURE: 0.75X and the HOT STAR loss (%d -> %d)" % [int(gf.get("base", 0)), int(gf.get("xp", 0))])
	r.check(String(fail.lines[0][0]).begins_with("TEST INPUTS, NOT A REAL GAME") and (fail.lines as Array).back()[0].contains("NOTHING SAVED"), "Part 9: labelled test inputs, never shown as a real game")
	r.check(JSON.stringify(c.to_dict()) == before and c.coach_pending.size() == 1 and copy != c, "18/19/20: simulating changes nothing in the save: the challenge still waits, no XP or stats added")
	_press("SimOk_%d" % int(e.eid))
	await _frames()
	r.check(_texts(_find("Pending_%d" % int(e.eid))).contains("TEST INPUTS"), "Part 9: SIMULATE shows its result under the challenge")
	# the real next game settles it once
	var n0 := c.coach_results.size()
	ce._play(c, true)
	c.last_summary = {}
	var settled: Array = c.coach_results.slice(n0).filter(func(x): return int(x.eid) == int(e.eid))
	r.check(settled.size() == 1 and c.coach_pending.is_empty(), "20: the real game settles it exactly once (%s)" % String(settled[0].outcome if not settled.is_empty() else "?"))
	if c.has_game():
		ce._play(c, true)
		c.last_summary = {}
	r.check(c.coach_results.filter(func(x): return int(x.eid) == int(e.eid)).size() == 1, "20: and never again")
	L.tab = "HISTORY"
	Game.current_screen._refresh()
	await _frames()
	var h := _texts(_find("History"))
	r.check(h.contains("PROVE HE'S ELITE") and h.contains("SETTLED CHALLENGES") and h.contains("A STAR IN THE MAKING"), "Part 11: HISTORY: this session's decisions and the saved settled results")
	L.tab = "EVENTS"

# ------------------------------------------------------------------ 21, 23
func _coins_and_suspensions() -> void:
	var c: Career = ce._career(612)
	c.credits = 0
	Store.vault = 0
	await _lab(c)
	L.trigger(c, "recruiting_ripple", -1, false, true)
	await _frames()
	var scr = Game.current_screen
	r.check(String(_find("Choice1").get_meta("blocked")) != "", "21: no credits: INVEST IN RECRUITING can't be picked")
	scr.pick = 1
	scr._confirm()
	r.check(c.wallet() == 0 and not scr.answered, "21: and confirming it anyway spends nothing (never below zero)")
	scr.pick = 0
	scr._confirm()
	await _frames()
	r.check(c.wallet() == CoachEvents.COINS.ripple_now, "21: TAKE THE REWARD: +%d credits" % CoachEvents.COINS.ripple_now)
	_press("Continue")
	await _frames()
	# a real suspension
	var cands: Array = L.candidates(c, "practice_discipline")
	var p: PoloPlayer = cands[0]
	L.trigger(c, "practice_discipline", p.id, false, true)
	await _frames()
	scr = Game.current_screen
	scr.pick = 1
	scr._confirm()
	await _frames()
	var seven := c.team().starters()
	r.check(p.susp == 1 and not p in seven and PoloTeam.legal(seven) and seven[0].is_keeper(), "23: SUSPEND HIM: out of the next game, a legal seven in his place")
	_press("Continue")
	await _frames()
	ce._play(c, true)
	c.last_summary = {}
	r.check(p.susp == 0, "23: the suspension is served by the next game")

# ------------------------------------------------------------------ 24, 25
func _generation_and_saves() -> void:
	r.check(CoachEvents.CHANCE == 0.6 and CoachEvents.CATEGORY_WEIGHT == {"dev": 45.0, "challenge": 30.0, "money": 20.0, "discipline": 5.0}
		and CoachEvents.EVENTS.filter(func(e): return e.weight != 1.0).map(func(e): return e.id) == ["prove_me_wrong"] and CoachEvents.scenario("prove_me_wrong").weight == 0.35,
		"24: the event chance (60%), category weights and event weights as they were")
	# the panel never draws from a career's dice: identical careers roll identical events
	var a: Career = ce._career(613)
	var b: Career = Career.from_dict(a.to_dict())
	Game.career = a
	for e in CoachEvents.EVENTS:
		L.when_safe(a, String(e.id), CoachEvents.last_review)
		L.trigger_block(a, String(e.id), -1, false)
	var rv: Dictionary = CoachEvents.last_review
	r.check(a.rng.state == b.rng.state and JSON.stringify(CoachEvents.roll(a, rv)) == JSON.stringify(CoachEvents.roll(b, rv)), "24: looking at events never moves the dice: the same game draws the same event")
	# saves: a triggered event and its challenge reload as they were; older ones never had the mark
	var c: Career = ce._career(614)
	var p: PoloPlayer = ce._dev(c)
	c.pending_event = L.build_event(c, "keeper_confidence", L.candidates(c, "keeper_confidence")[0].id, true, true)
	var re := Career.from_dict(JSON.parse_string(JSON.stringify(c.to_dict())))
	r.check(bool(re.pending_event.dev) and CoachEvents.is_special(re.pending_event), "25: a triggered event saves and reloads (special and all)")
	c.pending_event = {}
	CoachEvents.apply(c, ce._ev(c, "star_in_making", p), 1)
	r.check(not (c.coach_pending.back() as Dictionary).has("dev"), "25: an ordinary event's challenge is saved exactly as before (no dev mark)")
	L.tab = "EVENTS"
	Game.career = null

static func shots(runner, out: String) -> void:
	DirAccess.make_dir_recursive_absolute(out)
	var tree: SceneTree = runner.get_tree()
	var t = load("res://tests/coach_lab_test.gd").new()
	t.r = runner
	t.ce = load("res://tests/coaching_events_test.gd").new()
	t.ce.r = runner
	t.ce.pg = load("res://tests/postgame_test.gd").new()
	t.L = load("res://src/ui/screens/coach_lab.gd")
	Store.reset_for_tests()
	Game.progress = Progression.fresh()
	Game.settings.dev_mode = true
	var c: Career = t.ce._career(611)
	t._review(c)
	var snap := func(name: String) -> void:
		await tree.create_timer(0.4).timeout
		await RenderingServer.frame_post_draw
		runner.get_viewport().get_texture().get_image().save_png(out.path_join(name))
	var L = t.L
	L.tab = "EVENTS"
	L.sel = "star_in_making"
	L.special = true
	L.ignore_reqs = true
	Game.goto("coach_lab")
	await snap.call("l1_star_special.png")
	L.sel = "prove_me_wrong"
	L.special = false
	Game.current_screen._refresh()
	await snap.call("l2_pmw.png")
	Game.goto("coach_event", L.preview_params("star_in_making", -1, true, true))
	await snap.call("l3_preview_special.png")
	Game.goto("coach_lab")
	await tree.create_timer(0.3).timeout
	L.trigger(c, "defensive_masterclass", L.candidates(c, "defensive_masterclass")[0].id, true, true)
	await snap.call("l4_trigger.png")
	var scr = Game.current_screen
	scr.pick = 1
	scr._confirm()
	scr._leave()
	await tree.create_timer(0.3).timeout
	L.tab = "ACTIVE"
	var eid := int(c.coach_pending.back().eid)
	L.sim_out[eid] = L.simulate(c, eid, true).lines
	Game.current_screen._refresh()
	await snap.call("l5_active.png")
	L.tab = "HISTORY"
	Game.current_screen._refresh()
	await snap.call("l6_history.png")
	L.tab = "GENERATION"
	Game.current_screen._refresh()
	await snap.call("l7_generation.png")
	L.tab = "EVENTS"
	print("  shots")
	Game.career = null

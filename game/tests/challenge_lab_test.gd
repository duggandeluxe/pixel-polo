extends RefCounted
## THE CHALLENGE ANIMATIONS DEVELOPER TAB (coach_lab, CHALLENGE ANIMATIONS): the spec's REQUIRED
## TESTING (1-34).
##   godot --headless --path game -- --test challenge_lab
##   godot --path game -- --test challenge_lab_png <dir>

var r
var ce
var L

func run(runner) -> void:
	r = runner
	ce = load("res://tests/coaching_events_test.gd").new()
	ce.r = runner
	ce.pg = load("res://tests/postgame_test.gd").new()
	L = load("res://src/ui/screens/coach_lab.gd")
	print("challenge animations developer tab")
	Store.reset_for_tests()
	Game.progress = Progression.fresh()
	var dev_was: bool = Game.settings.get("dev_mode", false)
	Game.settings.dev_mode = true
	var c: Career = ce._career(901)
	# a real challenge already waiting in the save: previews must never touch it
	CoachEvents.apply(c, ce._ev(c, "star_in_making", ce._dev(c)), 1)
	var before := JSON.stringify(c.to_dict())
	var w0 := c.wallet()
	await _tab()
	_values(c)
	await _buttons()
	r.check(JSON.stringify(c.to_dict()) == before and c.wallet() == w0 and c.coach_pending.size() == 1 and c.coach_results.is_empty(),
		"25-29: after every preview: the save byte for byte as it was (no XP, credits, HOT/COLD, stats, the real challenge still waiting)")
	r.check(L.trigger_block(c, "rough_night", c.team().starters()[0].id, true) == "", "30: live testing (EVENTS > TRIGGER EVENT) as it was")
	Game.settings.dev_mode = dev_was
	Game.career = null
	Game.goto("title")
	await r.get_tree().process_frame

func _frames(n: int = 3) -> void:
	for _i in n:
		await r.get_tree().process_frame

func _find(name: String) -> Node:
	return Game.current_screen.find_child(name, true, false)

func _press(name: String) -> void:
	var b = _find(name)
	if b != null:
		b.emit_signal("pressed")

func _texts(n: Node) -> String:
	var out := PackedStringArray()
	for l in n.find_children("*", "Label", true, false):
		out.append((l as Label).text)
	return "\n".join(out)

# ------------------------------------------------------------------ 1-5
func _tab() -> void:
	L.tab = "EVENTS"
	Game.goto("coach_lab")
	await _frames()
	r.check(_find("Tab_ANIM") != null and _find("Tab_EVENTS") != null and _find("Tab_ACTIVE") != null and _find("Tab_HISTORY") != null and _find("Tab_GENERATION") != null,
		"1/16: CHALLENGE ANIMATIONS beside the panel's other tabs")
	_press("Tab_ANIM")
	await _frames()
	var list: Node = _find("AnimList")
	var ids: Array = list.get_children().map(func(b): return String(b.name).trim_prefix("Anim_"))
	r.check(ids == ["star_in_making", "backup_breakout", "keeper_confidence", "rough_night", "defensive_masterclass", "big_rivalry", "learning_experience", "cost_of_victory"],
		"2: the eight with a statistical objective %s" % str(ids))
	r.check(not ids.has("captains_speech") and not ids.has("recruiting_ripple") and not ids.has("practice_discipline") and not ids.has("prove_me_wrong") and _texts(list).contains("THE BIG RIVALRY - SPECIAL"),
		"3/31: none without one (PROVE ME WRONG untouched); THE BIG RIVALRY as its special version only")
	_press("Anim_rough_night")
	await _frames()
	var keepers: Array = L.candidates(Game.career, "rough_night").filter(func(p): return p.is_keeper())
	L.anim_pid = keepers[0].id
	Game.current_screen._refresh()
	await _frames()
	var t := _texts(_find("AnimDetails"))
	r.check(t.contains("A ROUGH NIGHT") and t.contains("CHALLENGE: 8 SAVES") and t.contains("SUCCESS: +160 XP") and t.contains("FAILURE: 0.5X GAME XP"), "4: A ROUGH NIGHT for a keeper: 8 SAVES, +160 XP, 0.5X (from the event itself)")
	var name0 := (_find("AnimPlayer") as Label).text
	_press("AnimNext")
	await _frames()
	r.check((_find("AnimPlayer") as Label).text != name0, "5: the player picker moves to another man (%s -> %s)" % [name0, (_find("AnimPlayer") as Label).text])

# ------------------------------------------------------------------ 6-21
func _values(c: Career) -> void:
	var k: PoloPlayer = c.team().starters()[0]
	var f: PoloPlayer = ce._dev(c)
	var a: Dictionary = L.preview_custom("rough_night", k.id, false, {"sv": 10}, true, -1)
	var b: Dictionary = L.preview_custom("rough_night", k.id, false, {"sv": 5}, true, -1)
	r.check(a.res.outcome == "ok" and ChallengeShow.title_of(a.res) == "CHALLENGE COMPLETE!" and ChallengeShow.consequence(a.res)[1] == "+160 XP" and ChallengeShow.progress_text(a.res) == "10 / 8 SAVES",
		"6/9/17: 10 saves of 8: CHALLENGE COMPLETE!, +160 XP")
	r.check(b.res.outcome == "fail" and ChallengeShow.title_of(b.res) == "CHALLENGE FAILED" and ChallengeShow.consequence(b.res)[1] == "0.5X GAME XP" and ChallengeShow.progress_text(b.res) == "5 / 8 SAVES",
		"6/9/13: 5 of 8: CHALLENGE FAILED, 0.5X GAME XP")
	var other: PoloPlayer = c.team().starters()[3] if c.team().starters()[3] != f else c.team().starters()[4]
	var g: Dictionary = L.preview_custom("star_in_making", other.id, false, {"g": 2, "a": 2}, true, -1)
	r.check(int(g.res.have) == 4 and ChallengeShow.parts_text(g.res) == "2 GOALS + 2 ASSISTS" and g.res.outcome == "ok" and ChallengeShow.consequence(g.res)[1] == "2X GAME XP", "7/12/18: 2 goals + 2 assists = 4 of 3: 2X GAME XP")
	var d: Dictionary = L.preview_custom("defensive_masterclass", other.id, true, {"st": 2, "bl": 1}, true, -1)
	r.check(int(d.res.have) == 3 and ChallengeShow.progress_text(d.res) == "3 / 5 STL+BLK" and ChallengeShow.title_of(d.res) == "CHALLENGE FAILED" and ChallengeShow.consequence(d.res)[1] == "0.75X GAME XP",
		"7/16: the special DEFENSIVE LEGEND, 3 of 5: the ordinary failure, 0.75X (no extra penalty)")
	var s: Dictionary = L.preview_custom("star_in_making", other.id, true, {"g": 6}, true, -1)
	r.check(ChallengeShow.title_of(s.res) == "LEGENDARY CHALLENGE COMPLETE!" and ChallengeShow.consequence(s.res)[1] == "3X GAME XP" and ChallengeShow.progress_text(s.res) == "6 / 5 GOALS",
		"14/15: special chosen directly: 6 / 5 GOALS, LEGENDARY, 3X")
	var bk: Array = L.candidates(c, "backup_breakout").filter(func(q): return not Development.is_maxed(q) and q.tokens < Development.boxes_left(q))
	var bb: Dictionary = L.preview_custom("backup_breakout", bk[0].id, false, {"g": 2}, true, -1)
	r.check(not bk.is_empty() and ChallengeShow.consequence(bb.res)[1] == "+150 XP", "17: THE BACKUP BREAKOUT made: +150 XP (%s)" % str(ChallengeShow.consequence(bb.res)))
	# 8: the result conditions
	var lead := CoachEvents.leader(c)
	var lw: Dictionary = L.preview_custom("big_rivalry", lead.id, true, L.case_vals(String(CoachEvents.challenge(c, {"id": "big_rivalry", "pid": lead.id, "special": true}).stat), 16 if lead.is_keeper() else 5, true), true, -1)
	var ll: Dictionary = L.preview_custom("big_rivalry", lead.id, true, lw.res.line if not lead.is_keeper() else {"sv": 16}, false, -1)
	var lm: Dictionary = L.preview_custom("big_rivalry", lead.id, true, {"sv": 3} if lead.is_keeper() else {"g": 1, "a": 1}, true, -1)
	r.check(lw.res.outcome == "ok" and ChallengeShow.consequence(lw.res)[1] == "3X GAME XP", "8: THE BIG RIVALRY special: a win and his line: complete, 3X")
	r.check(ll.res.outcome == "fail" and ChallengeShow.consequence(ll.res)[1] == "0.5X GAME XP" and ChallengeShow.conditions(ll.res)[0][1] == false, "8: a loss, his line made: failed, 0.5X")
	r.check(lm.res.outcome == "even" and ChallengeShow.consequence(lm.res)[1] == "NORMAL GAME XP" and ChallengeShow.title_of(lm.res) == "CHALLENGE FAILED", "8/21: a win, his line missed: failed, normal game XP (the event's own rule)")
	var lw2: Dictionary = L.preview_custom("learning_experience", other.id, false, {"g": 2}, true, -1)
	var ll2: Dictionary = L.preview_custom("learning_experience", other.id, false, {"g": 2}, false, -1)
	r.check(not lw2.popup and ll2.popup and ll2.res.outcome == "ok", "8: THE LEARNING EXPERIENCE: won, no popup in the game (normal XP); lost with 2 G+A, complete")
	# 10/11: the cases
	var bad: Array = []
	for it in L.ANIM_EVENTS:
		for sp in ([true] if it[1] else ([false, true] if CoachEvents.SPECIAL.has(it[0]) else [false])):
			var ok: Dictionary = L.preview_result(String(it[0]), -1, true, sp)
			var no: Dictionary = L.preview_result(String(it[0]), -1, false, sp)
			if ok.has("error") or no.has("error") or ok.res.outcome != "ok" or no.res.outcome != "fail" or not ok.popup or not no.popup:
				bad.append("%s %s" % [it[0], sp])
	r.check(bad.is_empty(), "10/11: SUCCESS and FAILURE cases pass and fail through the game's own evaluation, every challenge and variant %s" % str(bad))
	# 19/20: the bar
	var fills: Array = [0, 4, 8, 12].map(func(v): return ChallengeShow.fill(L.preview_custom("rough_night", k.id, false, {"sv": v}, true, -1).res))
	r.check(fills == [0.0, 0.5, 1.0, 1.0], "19/20: 0, 4, 8, 12 of 8 saves: 0%%, 50%%, 100%%, and full (not past it) %s" % str(fills))
	# 21: long names fit
	var long := Deck.fit("MAXIMILIAN VANDERBERGH-SZABO", 220.0, 16, "big")
	r.check(Deck.text_w(long, 16, "big") <= 220.0, "21: a long name is fitted to its space")

# ------------------------------------------------------------------ 22-24
func _buttons() -> void:
	L.anim_sel = "rough_night"
	L.anim_pid = Game.career.team().starters()[0].id
	Game.current_screen._refresh()
	await _frames()
	L.anim_vals = {"sv": 10}
	L.anim_won = true
	L.anim_target = -1
	_press("AnimResult")
	await _frames()
	var sh := Game.current_screen.find_children("*", "ChallengeShow", true, false)
	r.check(sh.size() == 1 and ChallengeShow.look((sh[0] as ChallengeShow).rec()) == "ok" and (sh[0] as ChallengeShow).tag.begins_with("DEVELOPER PREVIEW"), "9/24: PREVIEW RESULT: the real popup, marked a preview")
	r.check((sh[0] as ChallengeShow).motion == Juice.enabled(), "23: Reduce Motion (and tests): no motion, the result still shown")
	(sh[0] as ChallengeShow)._next()
	await _frames()
	r.check(Game.current_screen.find_children("*", "ChallengeShow", true, false).is_empty() and Game.current_name == "coach_lab", "24: CONTINUE: back to the panel")
	L.anim_vals = {"sv": 5}
	Game.current_screen._refresh()
	await _frames()
	_press("AnimResult")
	await _frames()
	sh = Game.current_screen.find_children("*", "ChallengeShow", true, false)
	r.check(sh.size() == 1 and ChallengeShow.look((sh[0] as ChallengeShow).rec()) == "fail", "9: 5 saves: the failure")
	(sh[0] as ChallengeShow)._next()
	await _frames()
	for _i in 2:
		_press("AnimReplay")
		await _frames()
		sh = Game.current_screen.find_children("*", "ChallengeShow", true, false)
		r.check(sh.size() == 1 and ChallengeShow.look((sh[0] as ChallengeShow).rec()) == "fail", "22: REPLAY: the last again")
		(sh[0] as ChallengeShow)._next()
		await _frames()
	_press("AnimOk")
	await _frames()
	sh = Game.current_screen.find_children("*", "ChallengeShow", true, false)
	r.check(sh.size() == 1 and ChallengeShow.look((sh[0] as ChallengeShow).rec()) == "ok" and int(L.anim_vals.sv) == 8, "10: SUCCESS loads a passing line (8 of 8)")
	(sh[0] as ChallengeShow)._next()
	await _frames()

static func shots(runner, out: String) -> void:
	DirAccess.make_dir_recursive_absolute(out)
	var tree: SceneTree = runner.get_tree()
	var t = load("res://tests/challenge_lab_test.gd").new()
	t.ce = load("res://tests/coaching_events_test.gd").new()
	t.ce.r = runner
	t.ce.pg = load("res://tests/postgame_test.gd").new()
	var Lb = load("res://src/ui/screens/coach_lab.gd")
	Store.reset_for_tests()
	Game.settings.dev_mode = true
	var c: Career = t.ce._career(901)
	Lb.tab = "ANIM"
	Lb.anim_sel = "defensive_masterclass"
	Lb.anim_sp = true
	Lb.anim_vals = {"st": 2, "bl": 1}
	Lb.anim_stat = "stbl"
	Game.goto("coach_lab")
	await tree.create_timer(0.5).timeout
	await RenderingServer.frame_post_draw
	runner.get_viewport().get_texture().get_image().save_png(out.path_join("a1_tab.png"))
	Lb.anim_sel = "big_rivalry"
	Game.current_screen._refresh()
	await tree.create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	runner.get_viewport().get_texture().get_image().save_png(out.path_join("a2_rivalry.png"))
	Lb.tab = "EVENTS"
	print("  shots")
	Game.career = null

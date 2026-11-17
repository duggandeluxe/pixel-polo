extends RefCounted
## The postgame HOT star reveal (HotReveal) and its Developer Mode preview: who shows (only a
## player whose form went up in that game), the timings (in, heat, pulse, hold, out; a second
## red star longer; several players one after another), the summary's flow (FINAL, the reveal
## only if someone heated up, then the round; no PLAYER FORM table), that playing it changes no
## player, form or save, and that the preview works with no career.
##   godot --headless --path game -- --test hot_reveal

const N := PlayerForm.NORMAL
const H := PlayerForm.HOT
const V := PlayerForm.VERY_HOT

var r   # the test runner

func run(runner) -> void:
	r = runner
	print("hot star reveal")
	Store.reset_for_tests()
	var test_was := Game.test_mode
	Game.test_mode = true
	_who()
	_timing()
	_frames_of()
	_pose()
	await _drawing()
	await _summary_heats()
	await _summary_quiet()
	await _lab()
	await _settings()
	Game.test_mode = test_was

func _row(p, before: String, after: String) -> Dictionary:
	return {"p": p, "before": before, "after": after}

func _who() -> void:
	var cases := [[N, N, false], [N, H, true], [H, H, false], [H, V, true], [V, V, false], [V, H, false], [H, N, false],
		[V, N, false], [N, V, true]]
	for cs in cases:
		var got := HotReveal.heaters([_row(PoloPlayer.new(), cs[0], cs[1])])
		r.check((got.size() == 1) == bool(cs[2]), "%s -> %s: %s" % [cs[0], cs[1], "shown" if cs[2] else "no animation"])
	var a := PoloPlayer.new()
	var b := PoloPlayer.new()
	var rows := [_row(PoloPlayer.new(), N, N), _row(a, N, H), _row(PoloPlayer.new(), V, H), _row(b, H, V), _row(PoloPlayer.new(), H, H)]
	var hs := HotReveal.heaters(rows)
	r.check(hs.size() == 2 and hs[0].p == a and hs[1].p == b and hs[0].to == H and hs[1].from == H and hs[1].to == V,
		"only the two who heated up, in the rows' order, with their own levels")
	r.check(HotReveal.heaters([]).is_empty() and HotReveal.heaters([_row(PoloPlayer.new(), H, N)]).is_empty(), "nobody heated up: nothing to show")
	r.check(HotReveal.steps_of(N, H) == [[N, H]] and HotReveal.steps_of(H, V) == [[H, V]] and HotReveal.steps_of(N, V) == [[N, H], [H, V]]
		and HotReveal.steps_of(H, H).is_empty(), "the stars to heat: one a level, NORMAL to VERY HOT is both, in order")
	r.check(HotReveal.word_for(H) == "HEATING UP!" and HotReveal.word_for(V) == "ON FIRE!", "HEATING UP! for a first red star, ON FIRE! for a second")

func _item(from: String, to: String) -> Dictionary:
	return {"p": PoloPlayer.new(), "from": from, "to": to}

func _timing() -> void:
	var one := HotReveal.plan_of([_item(N, H)], true)
	var t1 := HotReveal.total_of(one)
	r.check_between(t1, 2.0, 3.0, "one player heating up: 2-3 s all told")
	var fire := HotReveal.total_of(HotReveal.plan_of([_item(H, V)], true))
	r.check_between(fire, 2.0, 3.0, "a second red star: 2-3 s too")
	r.check(fire > t1 and HotReveal.PULSE[V] > HotReveal.PULSE[H], "...and its pulse is longer")
	var e: Dictionary = one[0]
	r.check(is_equal_approx(float(e.steps[0].at) - float(e.start), HotReveal.SLIDE_IN) and is_equal_approx(HotReveal.SLIDE_IN, 0.3),
		"the card slides in for 0.3 s, then the star heats")
	var two := HotReveal.plan_of([_item(N, H), _item(H, V)], true)
	r.check(is_equal_approx(float(two[1].start), float(two[0].end)), "two players: the second card comes in as the first leaves")
	r.check(HotReveal.frame_at(two, float(two[0].end) - 0.01).i == 0 and HotReveal.frame_at(two, float(two[1].start) + 0.01).i == 1,
		"...one card at a time")
	var both := HotReveal.plan_of([_item(N, V)], true)
	var st: Array = both[0].steps
	r.check(st.size() == 2 and st[0].to == H and st[1].from == H and st[1].to == V and float(st[1].at) >= float(st[0].at) + StarFx.HEAT_TIME,
		"NORMAL to VERY HOT: both stars on the one card, the second after the first has heated")
	var many: Array = []
	for i in 4:
		many.append(_item(N, H))
	var m := HotReveal.plan_of(many, true)
	r.check(float(m[0].end) - float(m[0].start) < t1 - HotReveal.LEAD - 0.2, "with 3+ players each card holds for less")
	var still := HotReveal.plan_of([_item(N, H), _item(H, V)], false)
	r.check(is_equal_approx(HotReveal.total_of(still), HotReveal.STILL * 2.0), "reduce motion: each card just shows, finished, %.1f s" % HotReveal.STILL)
	r.check(HotReveal.total_of([]) == 0.0, "an empty plan takes no time")

func _frames_of() -> void:
	var p := HotReveal.plan_of([_item(N, H)], true)
	var e: Dictionary = p[0]
	var f0 := HotReveal.frame_at(p, float(e.start))
	var fin := HotReveal.frame_at(p, float(e.start) + HotReveal.SLIDE_IN * 0.5)
	var mid := HotReveal.frame_at(p, float(e.steps[0].at) + 0.5)
	var leaving := HotReveal.frame_at(p, float(e.out) + HotReveal.SLIDE_OUT * 0.5)
	r.check(is_equal_approx(float(f0.slide), 1.0) and float(fin.slide) > 0.0 and float(fin.slide) < 1.0, "the card starts off to the right and slides in")
	r.check(float(mid.slide) == 0.0 and int(mid.step) == 0 and is_equal_approx(float(mid.since), 0.5), "in the middle while its star heats")
	r.check(float(leaving.slide) < 0.0, "...then slides out to the left")
	r.check(int(HotReveal.frame_at(p, 0.0).i) == -1 and int(HotReveal.frame_at(p, 99.0).i) == -1, "nothing before it starts or after it ends")
	r.check(int(f0.step) == -1, "the star hasn't started heating as the card comes in")

func _pose() -> void:
	var fx := StarFx.new()
	r.check(fx.pose(N, H, -1.0) == N and fx.kind == "", "posed before it starts: as he was")
	r.check(fx.pose(N, H, 0.4) == H and fx.kind == "heat" and is_equal_approx(fx.t, 0.4), "posed mid-way: the heat animation at that time")
	r.check(fx.pose(N, H, 5.0) == H and fx.kind == "", "posed after: settled, the new red star")
	r.check(fx.pose(H, V, 0.1) == V and fx.from_state == H and fx.to_state == V, "the second red star heats from HOT")
	fx.free()

## Draws a reveal through: his card (name, position, year), the words, no old table.
func _drawing() -> void:
	var tree: SceneTree = r.get_tree()
	var c := Career.new_game("CULA", "A", "B", 11)
	var host := Control.new()
	host.size = Vector2(480, 270)
	r.add_child(host)
	var rv := HotReveal.new()
	host.add_child(rv)
	await tree.process_frame
	rv.set_process(false)
	var p: PoloPlayer = c.team().starters()[2]
	var q: PoloPlayer = c.team().starters()[4]
	r.check(rv.start([{"p": p, "from": N, "to": H}, {"p": q, "from": H, "to": V}], c.team(), true), "the reveal starts for two players")
	var logs := {}
	var plan: Array = rv.plan
	for k in [["p_in", float(plan[0].start) + 0.1], ["p_hot", float(plan[0].steps[0].at) + 0.6], ["q_fire", float(plan[1].steps[0].at) + 0.6]]:
		rv.t = k[1]
		rv.layout()
		UI.drawn_log = []
		await _frames()
		logs[k[0]] = UI.drawn_log
		if k[0] == "p_hot":
			r.check(rv.card.visible and rv.card.scale == Vector2(2, 2) and rv.card.size == preload("res://src/ui/screens/roster.gd").CARD,
				"his roster card, at twice its size")
			r.check(rv.fx.get_parent() == rv.card, "...its stars by StarFx, the roster's own star animation")
	UI.drawn_log = null
	var lp: Array = logs.p_hot
	r.check(lp.has(p.short_name()) and lp.has(Deck.pos_tag(p)) and lp.has(p.year_text()), "the card: name, position, class year")
	r.check(lp.has("HEATING UP!") and not lp.has("ON FIRE!"), "a first red star: HEATING UP!")
	r.check(not (logs.p_in as Array).has("HEATING UP!"), "...not until the star has turned red")
	r.check((logs.q_fire as Array).has("ON FIRE!") and (logs.q_fire as Array).has(q.short_name()), "the second player: ON FIRE!")
	r.check(lp.has("PLAYER FORM  1 / 2") and (logs.q_fire as Array).has("PLAYER FORM  2 / 2"), "which of how many")
	var all_text: Array = lp + (logs.q_fire as Array)
	r.check(not (all_text.has("RAW") or all_text.has("EXP") or all_text.has("GRADE") or all_text.has("+/-") or all_text.has("EFF")),
		"no PLAYER FORM table columns")
	var done := [false]
	rv.finished.connect(func(): done[0] = true)
	rv.t = 0.3
	rv.skip()
	r.check(done[0] and not rv.running and not rv.card.visible, "a tap skips the rest")
	host.queue_free()

## A real career game where one man heats up: the summary shows him (and only him), playing it
## changes nothing, and the career moves on once.
func _summary_heats() -> void:
	var tree: SceneTree = r.get_tree()
	Game.career = Career.new_game("WAGN", "A", "B", 57)
	var c := Game.career
	var st := MatchState.new()
	st.score = [6, 3]
	st.saves = [9, 5]
	var seven := c.team().starters()
	var scorer: PoloPlayer = seven[3]
	scorer.form = [1, 1]   # a third GOOD game heats him up
	scorer.heat = 0
	var hot_one: PoloPlayer = seven[5]
	hot_one.form = [1, 1, 1]
	hot_one.heat = 1       # HOT already: staying HOT isn't shown
	for _i in 4:
		st.goal_by[0].append(scorer)
		st.shot_by[0].append(scorer)
	var before := {}
	var looks := {}
	for p: PoloPlayer in c.team().roster:
		before[p.id] = p.heat
		looks[p.id] = JSON.stringify([p.attrs, p.attr_pot, p.stars, p.pot_stars])
	c.last_summary = c.finish_my_game(st.box(c.team(), c.opponent()))
	var rose: Array = c.team().roster.filter(func(p: PoloPlayer): return p.heat > int(before[p.id]))
	var forms := {}
	for p: PoloPlayer in c.team().roster:
		forms[p.id] = [p.form.duplicate(), p.heat]
	r.check(scorer.heat == 1 and rose.has(scorer), "four goals, his third GOOD game: HOT")
	Store.starter_offered = true
	var week := c.week
	Game.goto("game_summary")
	await tree.process_frame
	await tree.process_frame
	var scr = Game.current_screen
	r.check(scr.form.size() == 7 and scr.form.all(func(row): return row.has("raw") and row.has("exp") and row.has("pm") and row.has("grade")),
		"the grades are still made: RAW, EXPECTED, +/-, the grade, all seven")
	var shown: Array = scr.heaters.map(func(h): return h.p)
	r.check(shown.size() == rose.size() and rose.all(func(p): return shown.has(p)), "the reveal shows exactly the players whose form went up (%d)" % shown.size())
	r.check(not shown.has(hot_one) or int(before[hot_one.id]) < hot_one.heat, "a player who stayed HOT isn't shown")
	r.check(scr.heaters.all(func(h): return h.to == (h.p as PoloPlayer).form_state()), "...each ending on his saved form")
	scr.t = 1.0
	UI.drawn_log = []
	scr.tap(Vector2(10, 10))
	r.check(scr.stage == 1 and scr.reveal.running, "a tap on FINAL: the HOT reveal")
	scr.t = 0.05
	scr.tap(Vector2(10, 10))
	r.check(scr.stage == 1 and scr.reveal.running, "a tap right away can't skip it (no double tap)")
	await _frames()
	var log: Array = UI.drawn_log
	UI.drawn_log = null
	r.check(not (log.has("RAW") or log.has("EXP") or log.has("GRADE") or log.has("EFF")), "the old PLAYER FORM table is gone")
	# let it play to the end by itself
	var guard := 0
	while scr.stage == 1 and guard < 400:
		scr.reveal._process(0.05)
		scr._process(0.05)
		guard += 1
	await _frames()
	r.check(guard < 400 and Game.current_name == "player_development", "when it's done it goes on to PLAYER DEVELOPMENT by itself (%.1f s)" % (guard * 0.05))
	var same := true
	var same_looks := true
	for p: PoloPlayer in c.team().roster:
		same = same and JSON.stringify(forms[p.id]) == JSON.stringify([p.form, p.heat])
		same_looks = same_looks and looks[p.id] == JSON.stringify([p.attrs, p.attr_pot, p.stars, p.pot_stars])
	r.check(same, "playing it graded nobody again: every form and heat as the game left them")
	r.check(same_looks, "...and no attribute or star changed")
	r.check(c.week == week, "the career hasn't moved on yet")
	var back := Career.from_dict(JSON.parse_string(JSON.stringify(c.to_dict())))
	var bp: PoloPlayer = back.team().find_id(scorer.id)
	r.check(bp != null and bp.heat == scorer.heat and bp.form == scorer.form, "saved and loaded: his HOT star is still there")
	Game.career = null
	Game.goto("title")
	await tree.process_frame

## Nobody heats up: FINAL goes straight on to PLAYER DEVELOPMENT.
func _summary_quiet() -> void:
	var tree: SceneTree = r.get_tree()
	Game.career = Career.new_game("WAGN", "A", "B", 58)
	var c := Game.career
	for p: PoloPlayer in c.team().roster:
		p.form = []     # one game can't make a run of three
		p.heat = 0
	var st := MatchState.new()
	st.score = [2, 4]
	c.last_summary = c.finish_my_game(st.box(c.team(), c.opponent()))
	Store.starter_offered = true
	Game.goto("game_summary")
	await tree.process_frame
	var scr = Game.current_screen
	r.check(scr.heaters.is_empty() and scr.form.size() == 7, "nobody heated up (the seven were still graded)")
	scr.t = 1.0
	scr.tap(Vector2(10, 10))
	r.check(scr.done and not scr.reveal.running, "FINAL, tap: no reveal")
	await tree.process_frame
	await tree.process_frame
	r.check(Game.current_name == "player_development", "...straight on to PLAYER DEVELOPMENT")
	Game.career = null
	Game.goto("title")
	await tree.process_frame

func _lab() -> void:
	var tree: SceneTree = r.get_tree()
	Game.career = null
	Game.goto("hot_lab")
	await tree.process_frame
	var lab = Game.current_screen
	r.check(Game.current_name == "hot_lab" and lab.reveal != null, "the preview opens with no career")
	var expect := {"first": [[N, H]], "second": [[H, V]], "two": [[N, H], [H, V]], "none": [], "double": [[N, V]]}
	for test in expect:
		lab.play(test)
		var items: Array = lab.reveal.items
		var got: Array = items.map(func(it): return [it.from, it.to])
		r.check(JSON.stringify(got) == JSON.stringify(expect[test]), "TEST %s: %s" % [test, str(got)])
		r.check(lab.reveal.running == (not items.is_empty()) and lab.reveal.motion, "...%s" % ("plays, with motion" if not items.is_empty() else "skipped"))
	lab.play("none")
	r.check(lab.status.begins_with("NOBODY") and not lab.reveal.running, "NO HOT STARS: the reveal is skipped")
	lab.play("second")
	lab.reveal.skip()
	r.check(not lab.reveal.running, "a tap skips it")
	lab.play(lab.last)
	r.check(lab.reveal.running and lab.reveal.items[0].to == V, "REPLAY plays the last test again")
	r.check(Game.career == null, "no career made")
	# with a career loaded: it wears your caps and changes nothing
	var c := Career.new_game("CULA", "A", "B", 12)
	Game.career = c
	var saved := JSON.stringify(c.to_dict())
	Game.goto("hot_lab")
	await tree.process_frame
	lab = Game.current_screen
	r.check(lab.team == c.team() and lab.seven.all(func(p): return c.team().find_id(p.id) == null), "with a career: your caps, made-up players")
	for test in expect:
		lab.play(test)
		lab.reveal.t = 1.0
		lab.reveal.layout()
		await _frames()
	r.check(JSON.stringify(c.to_dict()) == saved, "...and the career is exactly as it was")
	Game.career = null
	Game.goto("title")
	await tree.process_frame

func _settings() -> void:
	var tree: SceneTree = r.get_tree()
	var dev_was: bool = Game.settings.get("dev_mode", false)
	Game.settings.dev_mode = false
	Game.goto("settings")
	await tree.process_frame
	r.check(not _has_button(Game.current_screen, "HOT STAR REVEAL"), "Developer Mode off: no reveal preview")
	Game.settings.dev_mode = true
	DevGate.try_unlock("8008")   # (the developer tools: the DEV screen, behind its code)
	Game.goto("dev_settings", {}, false)
	await tree.process_frame
	r.check(_has_button(Game.current_screen, "HOT STAR REVEAL"), "Developer Mode on: HOT STAR REVEAL")
	Game.settings.dev_mode = dev_was
	Game.goto("title")
	await tree.process_frame

## Two frames: the redraw queued in one is drawn by the next (headless has no frame_post_draw).
func _frames() -> void:
	await r.get_tree().process_frame
	await r.get_tree().process_frame

func _has_button(n: Node, text: String) -> bool:
	if n is Button and (n as Button).text == text and not n.is_queued_for_deletion():
		return true
	for ch in n.get_children():
		if not ch.is_queued_for_deletion() and _has_button(ch, text):
			return true
	return false

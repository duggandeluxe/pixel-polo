extends RefCounted
## The HOT star animations (StarFx) and Developer Mode: which change plays which, the phases of
## each, particles that stay small and finish in time, the faint idle, once-per-change
## on the real screens, no overlap, speed and loop, reduce motion, the form lab, and the roster's
## DEV panel leaving the career exactly as it was; the roster's cards (the bigger star, open
## spots, the bench, every player's own looks), the formation they stand in, and dragging them
## to swap places (the lineup the match plays, saved).
##   godot --headless --path game -- --test star_fx

var r   # the test runner

func run(runner) -> void:
	r = runner
	print("star fx")
	Store.reset_for_tests()
	var test_was := Game.test_mode
	Game.test_mode = true     # the game's own screens show no motion in tests (Juice.enabled)
	_kinds()
	_phases()
	_particles()
	_idle()
	_slots()
	await _playing()
	await _watch()
	await _lab()
	await _roster_dev()
	await _roster_cards()
	await _roster_drag()
	await _settings()
	Game.test_mode = test_was

func _kinds() -> void:
	var F := PlayerForm
	var cases := [[F.NORMAL, F.HOT, "heat"], [F.HOT, F.VERY_HOT, "heat"], [F.NORMAL, F.VERY_HOT, "heat"],
		[F.VERY_HOT, F.HOT, "cool"], [F.HOT, F.NORMAL, "cool"], [F.VERY_HOT, F.NORMAL, "cool"], [F.HOT, F.HOT, ""]]
	for cs in cases:
		r.check(StarFx.kind_of(cs[0], cs[1]) == cs[2], "%s -> %s plays %s" % [cs[0], cs[1], cs[2] if cs[2] != "" else "nothing"])
	r.check(is_equal_approx(StarFx.duration("heat"), 0.9) and is_equal_approx(StarFx.duration("cool"), 0.4), "heating 0.9 s, cooling 0.4 s")
	r.check(StarFx.step(F.NORMAL, 1) == F.HOT and StarFx.step(F.HOT, 1) == F.VERY_HOT and StarFx.step(F.VERY_HOT, 1) == F.VERY_HOT
		and StarFx.step(F.NORMAL, -1) == F.NORMAL and StarFx.step(F.VERY_HOT, -1) == F.HOT,
		"HEAT UP / COOL DOWN move one level along, stopping at VERY HOT and NORMAL (nothing colder)")

func _phases() -> void:
	var L := func(k, t): return StarFx.look(k, t)
	# heating up: the star itself flashes yellow/orange, grows, turns red, pops, sparkles, settles
	var w1: Dictionary = L.call("heat", 0.05)
	var w2: Dictionary = L.call("heat", 0.2)
	r.check(w1.stage == "from" and Color(w1.outline).a > 0.0 and w2.stage == "flash" and w2.size == 1 and Color(w2.flash).r > Color(w2.flash).b,
		"heating, warming up: a warm edge, then it flashes yellow/orange and grows")
	var pop: Dictionary = L.call("heat", 0.35)
	var bounce: Dictionary = L.call("heat", 0.46)
	r.check(pop.stage == "to" and pop.size == 1 and pop.sparkle > 0 and L.call("heat", 0.41).size == 0 and bounce.size == 1, "ignition: red, a pop, a bounce and a sparkle")
	var st: Dictionary = L.call("heat", 0.8)
	r.check(st.stage == "to" and st.size == 0 and st.sparkle == 0 and Color(st.glow).a == 0.0 and Color(st.outline).a == 0.0, "settling: normal size, nothing round it")
	# cooling a level: a pulse, its colour steps back, a sparkle
	r.check(L.call("cool", 0.05).size == 1 and L.call("cool", 0.2).stage == "blend" and L.call("cool", 0.2).sparkle == 1 and L.call("cool", 0.35).stage == "to",
		"cooling: a pulse, its colour steps back, a sparkle")
	var seen := {}
	for i in 50:
		seen[str(L.call("heat", i * 0.005).flash)] = true
	r.check(seen.size() <= 3, "the warm-up flash moves in flat steps, not a gradient (%d colours)" % seen.size())

func _particles() -> void:
	var heat := StarFx.make_particles("heat", 7)
	r.check(heat.size() <= 6, "a few single pixels, not a shower (%d)" % heat.size())
	r.check(heat.all(func(p): return float(p.t1) <= 0.62), "the sparks are gone as it settles")
	r.check(JSON.stringify(heat) == JSON.stringify(StarFx.make_particles("heat", 7)), "the same change throws the same pixels")
	var warm := [StarFx.EMBER_Y, StarFx.WARM, StarFx.EMBER_R]
	r.check(heat.all(func(p): return warm.has(p.col)), "yellow, orange and red sparks")
	r.check(StarFx.make_particles("cool", 7).is_empty(), "cooling throws none (just the sparkle)")

func _idle() -> void:
	var F := PlayerForm
	for state in [F.HOT, F.VERY_HOT]:
		var plain := 0
		var embers := 0
		for i in 720:
			var il := StarFx.idle_look(state, i / 60.0)
			if not il.warm and il.ember < 0:
				plain += 1
			if il.ember >= 0:
				embers += 1
		r.check(plain > 720 * 0.75, "%s at rest: plain most of the time (%d of 720 frames)" % [state, plain])
		r.check(embers > 0 and embers < 720 * 0.15, "%s: the odd ember" % state)
	var n := StarFx.idle_look(F.NORMAL, 1.3)
	r.check(not n.warm and n.ember == -1, "NORMAL has no idle")

func _slots() -> void:
	var F := PlayerForm
	var C := func(cur, a, b): return StarFx.changed_places(cur, 5.0, a, b)
	# the red stars sit straight after the gold, inside the five places
	r.check(C.call(3.0, F.NORMAL, F.HOT) == [3] and C.call(3.0, F.HOT, F.VERY_HOT) == [4], "heating a three-star: the fourth place, then the fifth, turn red")
	r.check(C.call(3.0, F.VERY_HOT, F.NORMAL) == [3, 4], "VERY HOT to NORMAL: both red stars go")
	r.check(C.call(5.0, F.NORMAL, F.VERY_HOT) == [3, 4] and C.call(4.0, F.HOT, F.VERY_HOT) == [3], "no room left in the five: the red stars take the top places (the gold gives way)")
	r.check(C.call(4.0, F.HOT, F.HOT).is_empty(), "no change, nothing moves")
	r.check(StarFx.form_place(3.0, 5.0, F.VERY_HOT) == 4 and StarFx.form_place(3.0, 5.0, F.HOT) == 3 and StarFx.form_place(3.0, 5.0, F.NORMAL) == -1,
		"the idle sits on the last red star")

func _playing() -> void:
	var tree: SceneTree = r.get_tree()
	var host := Control.new()
	tree.root.add_child.call_deferred(host)
	await tree.process_frame
	var fx := StarFx.new()
	host.add_child(fx)
	fx.play(PlayerForm.NORMAL, PlayerForm.HOT)
	r.check(not fx.playing(), "reduce motion / tests: nothing plays, the bar just shows the new form")
	fx.play(PlayerForm.NORMAL, PlayerForm.HOT, true)
	r.check(fx.playing() and fx.kind == "heat", "forced (Developer Mode): it plays")
	var first: Tween = fx._tw
	fx.play(PlayerForm.HOT, PlayerForm.VERY_HOT)
	r.check(fx.kind == "heat" and fx.t == 0.0 and not first.is_valid() and fx._tw.is_valid(), "a change mid-animation replaces it, never stacks")
	await tree.create_timer(0.4).timeout
	r.check(fx.t > 0.2 and fx.playing(), "it runs on a tween (%.2f s in)" % fx.t)
	await tree.create_timer(0.8).timeout
	r.check(not fx.playing(), "and finishes")
	fx.speed = 2.0
	fx.replay()
	r.check(fx.kind == "heat" and fx.from_state == PlayerForm.HOT and fx.to_state == PlayerForm.VERY_HOT, "REPLAY plays the last change again")
	await tree.create_timer(0.65).timeout
	r.check(not fx.playing(), "at 2x a 0.9 s heat is over in 0.45 s")
	fx.speed = 1.0
	fx.loop = true
	fx.replay()
	await tree.create_timer(1.3).timeout
	r.check(fx.playing(), "LOOP keeps replaying")
	fx.loop = false
	fx.particles = false
	fx.replay()
	r.check(fx._parts.is_empty(), "PARTICLES OFF: no flame pixels")
	host.queue_free()

func _watch() -> void:
	var tree: SceneTree = r.get_tree()
	var host := Control.new()
	tree.root.add_child.call_deferred(host)
	await tree.process_frame
	var key := "test %d" % Time.get_ticks_usec()
	var a := StarFx.new()
	a.force = true
	host.add_child(a)
	a.watch(key, PlayerForm.HOT)
	r.check(not a.playing(), "first sight, no change since his last game: no animation")
	var b := StarFx.new()
	b.force = true
	host.add_child(b)
	b.watch(key, PlayerForm.HOT)
	r.check(not b.playing(), "the screen again (a refresh, a rebuild): no animation")
	var c := StarFx.new()
	c.force = true
	host.add_child(c)
	c.watch(key, PlayerForm.NORMAL)
	r.check(c.playing() and c.kind == "cool", "his form changed since: it plays, once")
	var d := StarFx.new()
	d.force = true
	host.add_child(d)
	d.watch(key, PlayerForm.NORMAL)
	r.check(not d.playing(), "...and not again")
	var e := StarFx.new()
	e.force = true
	e.watch(key + " new", PlayerForm.HOT, PlayerForm.NORMAL)
	host.add_child(e)
	await tree.process_frame
	r.check(e.playing() and e.kind == "heat", "first sight after a game that changed his form: it plays (started once on screen)")
	host.queue_free()

func _lab() -> void:
	var tree: SceneTree = r.get_tree()
	Game.career = null
	Game.goto("form_lab")
	await tree.process_frame
	var lab = Game.current_screen
	r.check(Game.current_name == "form_lab" and lab.fx != null, "the form lab opens")
	UI.drawn_log = []
	lab.card.queue_redraw()
	await _frames()
	var log: Array = UI.drawn_log
	UI.drawn_log = null
	r.check(log.has("SAM PIXEL") and log.has("CURRENT") and log.has("POTENTIAL") and log.has("FORM") and log.has("ADJUSTMENT"),
		"the sample card: name, current, potential, form, adjustment")
	lab.set_form(StarFx.step(lab.state, 1))
	r.check(lab.state == PlayerForm.HOT and lab.fx.kind == "heat", "HEAT UP: HOT, heating plays")
	lab.set_form(StarFx.step(lab.state, -1))
	r.check(lab.state == PlayerForm.NORMAL and lab.fx.kind == "cool", "COOL DOWN from HOT: NORMAL, cooling plays")
	lab.set_form(StarFx.step(lab.state, -1))
	r.check(lab.state == PlayerForm.NORMAL, "COOL DOWN from NORMAL: nothing colder")
	lab.set_form(PlayerForm.VERY_HOT)
	r.check(lab.state == PlayerForm.VERY_HOT and lab.fx.kind == "heat", "VERY HOT: heating plays")
	lab.set_form(PlayerForm.NORMAL)
	r.check(lab.state == PlayerForm.NORMAL and lab.fx.kind == "cool", "RESET: NORMAL, cooling plays")
	r.check(not _has_button(lab, "MAX COLD"), "no MAX COLD in the lab")
	for i in 6:
		var was: String = lab.state
		lab.random_form()
		r.check(lab.state != was and lab.fx.kind == StarFx.kind_of(was, lab.state), "RANDOM FORM %d: a new form and its animation" % i)
	for i in 10:
		lab.set_stars("cur", 0.5)
	r.check(lab.cur == 5.0 and lab.pot == 5.0, "CURRENT tops out at 5 and takes POTENTIAL with it")
	for i in 10:
		lab.set_stars("pot", -0.5)
	r.check(lab.cur == PlayerForm.MIN_STARS and lab.pot == PlayerForm.MIN_STARS, "POTENTIAL bottoms out at 0 and takes CURRENT with it")
	lab.set_stars("pot", 1.5)
	r.check(lab.cur == PlayerForm.MIN_STARS and lab.pot == PlayerForm.MIN_STARS + 1.5, "POTENTIAL moves on its own above CURRENT")
	# every combination draws (nothing to crash on), big and at the game's size
	for ci in range(2, 11, 2):
		for s in StarFx.LADDER:
			lab.cur = ci * 0.5
			lab.pot = 5.0
			lab.state = s
			lab.card.queue_redraw()
			await _frames()
	r.check(is_instance_valid(lab), "every CURRENT and form drawn in the lab")
	var lab_src := FileAccess.get_file_as_string("res://src/ui/screens/form_lab.gd")
	var roster_src := FileAccess.get_file_as_string("res://src/ui/screens/roster.gd")
	var card_src := roster_src.substr(roster_src.find("func _paint_card("), roster_src.find("func _paint_open(") - roster_src.find("func _paint_card("))
	r.check(lab_src.count("fx.draw(ci") == 2 and card_src.contains("fx.draw(ci") and not lab_src.contains("Deck.star_bar(") and not lab_src.contains("Deck.star_place(") and not card_src.contains("Deck.star_bar("),
		"the lab (big and IN GAME) and the roster cards draw stars through the one StarFx (the bench's small rows use the plain bar)")

func _roster_dev() -> void:
	var tree: SceneTree = r.get_tree()
	var c := Career.new_game("WAGN", "Dev", "Coach", 41)
	Game.career = c
	var dev_was: bool = Game.settings.get("dev_mode", false)
	Game.settings.dev_mode = false
	Game.goto("roster")
	await tree.process_frame
	var scr = Game.current_screen
	r.check(not _has_button(scr, "DEV"), "Developer Mode off: no DEV on the roster")
	Game.settings.dev_mode = true
	var before := JSON.stringify(c.to_dict())
	Game.goto("roster")
	await tree.process_frame
	scr = Game.current_screen
	r.check(_has_button(scr, "DEV"), "Developer Mode on: DEV in the header")
	r.check(scr.fxs.size() == c.team().roster.size() and scr.fxs.values().all(func(f): return f is StarFx), "every card has its own StarFx")
	scr._dev_toggle()
	r.check(scr.dev_on and _has_button(scr.bottom, "HEAT UP") and _has_button(scr.bottom, "COOL DOWN") and _has_button(scr.bottom, "RESET"), "DEV: the test panel")
	var p: PoloPlayer = c.team().roster[2]
	var real := p.form_state()
	scr._dev_select(p.id)
	await tree.process_frame
	r.check(scr.dev_pick == p.id and Game.current_name == "roster", "tapping a card picks him (no page)")
	scr._dev_form(1)
	var hot: String = StarFx.step(real, 1)
	r.check(scr.shown_form(p) == hot and scr.fxs[p.id].kind == StarFx.kind_of(real, hot), "HEAT UP on the real card: his card heats up")
	var line: Dictionary = scr.star_line(p, scr.shown_form(p))
	r.check(is_equal_approx(line.eff, PlayerForm.effective(p.stars, hot)) and p.form_state() == real, "the card shows the test form; the player's own is unchanged")
	scr._dev_form(-1)
	scr._dev_form(-1)
	r.check(scr.fxs[p.id].kind == "cool", "COOL DOWN on the real card")
	scr._dev_form(0)
	r.check(scr.shown_form(p) == PlayerForm.NORMAL, "RESET on the real card")
	scr._dev_form(-1)
	await _frames()
	scr._dev_toggle()
	r.check(scr.dev_forms.is_empty() and not scr.dev_on and scr.shown_form(p) == real, "DONE: back to his real form")
	r.check(JSON.stringify(c.to_dict()) == before, "testing form on the roster leaves the career exactly as it was")
	Game.settings.dev_mode = dev_was
	Game.career = null

func _roster_cards() -> void:
	var tree: SceneTree = r.get_tree()
	# the game's one star: 9x9, a gap between places, five places and no extra form place
	r.check(Deck.STAR.size() == 9 and Deck.STAR.all(func(row): return row.length() == 9), "the star is 9x9")
	r.check(is_equal_approx(Deck.star_bar_w(), (Deck.STAR_PLACES - 1) * Deck.STAR_STEP + 9.0) and Deck.star_bar_w() <= 49.0
		and Deck.STAR_STEP > int(Deck.STAR_SHAPE.w), "five places, no extra form place; the bar fits a card, its stars apart")
	var c := Career.new_game("WAGN", "Dev", "Coach", 41)
	Game.career = c
	var t := c.team()
	_seven_man(t)
	Game.goto("roster")
	await tree.process_frame
	await tree.process_frame
	var scr = Game.current_screen
	var rs = load("res://src/ui/screens/roster.gd")
	var lineup: Dictionary = rs.formation(t)
	r.check(scr.cards.size() == t.roster.size() and lineup.spots.size() == 7 and lineup.bench.is_empty(), "a full roster: all seven in the pool, nobody on the bench")
	# the formation: every spot where it should be, the 2 m line nearest the goal, the keeper on his own below
	var at := {}
	for k in rs.SPOTS:
		var b: Button = scr.find_child("Spot_" + k, true, false)
		at[k] = Rect2(b.position, b.size) if b != null else Rect2()
	r.check(at.lw.position.y == at.cf.position.y and at.cf.position.y == at.rw.position.y and at.lw.position.x < at.cf.position.x and at.cf.position.x < at.rw.position.x,
		"LEFT WING, CENTER FORWARD, RIGHT WING across the 2 m line, left to right")
	r.check(at.lf.position.y == at.pt.position.y and at.pt.position.y == at.rf.position.y and at.lf.position.y > at.lw.position.y
		and at.lf.position.x < at.pt.position.x and at.pt.position.x < at.rf.position.x, "LEFT FLAT, POINT, RIGHT FLAT behind them, on the perimeter")
	r.check(at.gk.position.y > at.pt.position.y and is_equal_approx(at.gk.position.x, at.pt.position.x), "the keeper apart, below the six")
	var overlap := false
	for a in rs.SPOTS:
		for b in rs.SPOTS:
			if a != b and (at[a] as Rect2).grow(-0.5).intersects(at[b]):
				overlap = true
	r.check(not overlap, "no two cards overlap")
	var board_sz: Vector2 = rs.board_size()
	r.check(at.values().all(func(rc: Rect2): return rc.position.x >= 0.0 and rc.end.x <= board_sz.x and rc.position.y >= 0.0 and rc.end.y <= board_sz.y),
		"every card on the table")
	r.check(board_sz.x <= 480 - 8 and board_sz.y <= 270 - 30, "the seven and the bench column fit the 480 x 270 screen under the header, no scrolling")
	var sub_at: Array = ["s1", "s2", "s3"].map(func(k): return Rect2(rs.spot_pos(k), rs.CARD))
	r.check(sub_at.all(func(rc: Rect2): return rc.position.x >= at.rw.end.x + 6.0 and rc.position.x == (sub_at[0] as Rect2).position.x and rc.end.x <= board_sz.x and rc.end.y <= board_sz.y)
		and sub_at[0].position.y == at.rw.position.y and sub_at[1].position.y == at.rf.position.y and sub_at[2].position.y == at.gk.position.y,
		"three bench places in a column right of the seven, a little apart, one beside each row")
	r.check(sub_at.all(func(rc: Rect2): return at.values().all(func(o: Rect2): return not rc.grow(-0.5).intersects(o))) and not sub_at[0].grow(-0.5).intersects(sub_at[1]) and not sub_at[1].grow(-0.5).intersects(sub_at[2]),
		"no bench card overlaps another card")
	r.check(rs.slot_at(sub_at[1].get_center()) == PoloTeam.LINEUP_SPOTS.find("s2") and rs.slot_at(at.gk.get_center()) == PoloTeam.LINEUP_SPOTS.find("gk"), "the drop targets follow the cards")
	r.check(scr.find_children("Empty_*", "", true, false).size() == 3, "a seven-man roster: three EMPTY bench places, nobody made up")
	var page_buttons: Array = scr.find_children("*", "Button", true, false).map(func(b: Button): return b.text)
	r.check(not page_buttons.has("VIEW PLAN") and not FileAccess.get_file_as_string("res://src/ui/screens/roster.gd").contains("\"NEXT SEASON\"") and not ("BAR" in scr) and not ("SIDE_W" in scr) and not ("POOL_BG" in scr),
		"no NEXT SEASON panel, no ROSTER / TEAM / FORM bar, no pool or goal behind the cards")
	var keeper: PoloPlayer = lineup.spots.gk
	r.check(keeper.is_keeper() and keeper == t.starters()[0], "the keeper's card is the team's own starting keeper")
	r.check((lineup.spots.cf as PoloPlayer).pos == PoloPlayer.Pos.CENTER and (lineup.spots.pt as PoloPlayer).pos == PoloPlayer.Pos.DEFENDER,
		"the center at center forward, the 2MD at point")
	r.check([lineup.spots.lw, lineup.spots.rw].all(func(p): return p.pos == PoloPlayer.Pos.WING) and [lineup.spots.lf, lineup.spots.rf].all(func(p): return p.pos == PoloPlayer.Pos.DRIVER),
		"wings on the wings, attackers on the flats (a lefty on the right side)")
	var positions_before := t.roster.map(func(p): return p.pos)
	r.check(t.roster.map(func(p): return p.pos) == positions_before and rs.formation(t).spots == lineup.spots, "the formation never changes anyone's position, and it's the same every time")
	# the cards: no OVR or POT numbers any more
	UI.drawn_log = []
	for b in scr.cards.values():
		b.queue_redraw()
		b.get_child(0).queue_redraw()
	await _frames()
	var log: Array = UI.drawn_log
	UI.drawn_log = null
	var first_p: PoloPlayer = lineup.spots.cf
	r.check(log.has(first_p.short_name()) and log.has(first_p.year_text()), "a card still shows his name and class year")
	var ni := log.find(first_p.short_name())
	r.check(ni >= 0 and ni + 1 < log.size() and log[ni + 1] == first_p.year_text() and log[ni - 1] != first_p.year_text(), "the class year right after his surname, not up by his position")
	r.check(not log.has("OVR") and not log.has("POT") and not log.has(first_p.ovr_text()), "no OVR or POT numbers on the cards")
	# one place empty (not saved): an OPEN SPOT in the pool, no one made up for it
	var gone: PoloPlayer = t.roster.pop_back()
	Game.goto("roster", {}, false)
	await tree.process_frame
	scr = Game.current_screen
	var open := 0
	for k in rs.SPOTS:
		var b: Button = scr.find_child("Spot_" + k, true, false)
		if b != null and String(b.tooltip_text).contains("open place"):
			open += 1
	r.check(scr.cards.size() == t.roster.size() and open == 1 and t.roster.size() == 6, "one short: an OPEN SPOT in his place, nobody made up")
	t.roster.append(gone)
	# more than seven (a test roster): the eighth on the bench, tap him for his page
	var extra := PoloPlayer.from_dict(t.roster[3].to_dict())
	extra.id = 987654
	extra.lefty = false
	for key in extra.key_ratings():
		extra.attrs[key] = 1.0   # (a sub: nobody he'd start ahead of)
	Attributes.sync(extra)
	t.roster.append(extra)
	Game.goto("roster", {}, false)
	await tree.process_frame
	scr = Game.current_screen
	var bench_btn: Button = scr.find_child("Bench_%d" % extra.id, true, false)
	r.check(bench_btn != null and rs.formation(t).bench == [extra] and scr.cards.size() == 8 and t.lineup.find(extra.id) == PoloTeam.STARTERS,
		"an eighth player sits on the bench, the first SUB")
	bench_btn.pressed.emit()
	await tree.process_frame
	r.check(Game.current_name == "player" and Game.current_screen.pid == extra.id, "tapping a bench player opens his page")
	t.roster.erase(extra)
	Game.goto("roster", {}, false)
	await tree.process_frame
	scr = Game.current_screen
	# a card tap opens his page (straight away in tests: no motion)
	var first: PoloPlayer = lineup.spots.lw
	scr.cards[first.id].pressed.emit()
	await tree.process_frame
	r.check(Game.current_name == "player" and Game.current_screen.pid == first.id, "tapping a card opens his page")
	# looks: the same player always looks the same (a save and load too), and the roster isn't all one face
	var lk := PlayerArt.looks(first)
	r.check(str(PlayerArt.looks(first)) == str(lk) and str(PlayerArt.looks(PoloPlayer.from_dict(first.to_dict()))) == str(lk),
		"a player's looks never change, saved and loaded")
	var seen := {}
	for team: PoloTeam in c.teams.values():
		for p: PoloPlayer in team.roster:
			var l := PlayerArt.looks(p)
			seen["%s %s %s %d" % [l.hair.to_html(), l.hairdo, l.face, int(l.build)]] = true
	r.check(seen.size() >= 40, "players look different from each other (%d looks)" % seen.size())
	# a lefty pair: the lefty plays the right side
	var t2 := PoloTeam.new()
	for i in 7:
		var q := PoloPlayer.new()
		q.id = 500 + i
		q.pos = [PoloPlayer.Pos.GK, PoloPlayer.Pos.CENTER, PoloPlayer.Pos.DEFENDER, PoloPlayer.Pos.DRIVER, PoloPlayer.Pos.DRIVER, PoloPlayer.Pos.UTILITY, PoloPlayer.Pos.UTILITY][i]
		q.lefty = i == 3
		t2.roster.append(q)
	var f2: Dictionary = rs.formation(t2)
	r.check(((f2.spots.rw as PoloPlayer).lefty or (f2.spots.rf as PoloPlayer).lefty) and not (f2.spots.lw as PoloPlayer).lefty and not (f2.spots.lf as PoloPlayer).lefty,
		"a lefty attacker goes to the right side (ATK/LFTY or WG/LFTY)")
	Game.career = null

## A seven-man roster with no lineup yet (an older career's: a new one starts with three subs
## and its lineup set): the fixture the roster screen's first-visit tests are built on.
func _seven_man(t: PoloTeam) -> void:
	var seven := t.starters()
	for p in t.roster.duplicate():
		if not seven.has(p):
			t.roster.erase(p)
	t.lineup = []

## Dragging cards: starters swap places, a sub comes on and the starter goes to his bench place,
## subs reorder; a keeper never goes in the field (or a field player in goal), and a drop
## nowhere changes nothing. A tap still opens his page, a drag never does. The match plays the
## lineup, and it's saved; an older save (no lineup) gets one, the seven as they stood.
func _roster_drag() -> void:
	var tree: SceneTree = r.get_tree()
	var c := Career.new_game("WAGN", "Dev", "Coach", 43)
	Game.career = c
	var t := c.team()
	_seven_man(t)
	var auto_seven: Array = t.starters().map(func(p): return p.id)
	r.check(not t.has_lineup(), "a new career has no lineup yet: the team picks its own seven")
	# two subs (test players: copies of a field starter and the keeper), the third place empty
	var weakest: PoloPlayer = t.starters()[1]
	for q: PoloPlayer in t.starters().slice(1):
		if q.overall() < weakest.overall():
			weakest = q
	var sub := PoloPlayer.from_dict(weakest.to_dict())   # (the weakest field starter's copy, a point under him)
	sub.id = 880001
	sub.last = "Subbs"
	sub.number = 30
	var k0: String = sub.key_ratings()[0]
	Attributes.set_value(sub, k0, sub.attr(k0) - 1.0)   # (a point under the man he copies: never a tie for a starting place)
	var gk2 := PoloPlayer.from_dict(t.starters()[0].to_dict())
	gk2.id = 880002
	gk2.last = "Backup"
	gk2.number = 21
	t.roster.append(sub)
	t.roster.append(gk2)
	Game.goto("roster")
	await tree.process_frame
	var scr = Game.current_screen
	r.check(t.has_lineup() and t.lineup.size() == 10 and t.lineup.slice(0, 7).all(func(pid): return auto_seven.has(pid)), "the first visit sets the lineup: the seven who already started")
	r.check(t.lineup.slice(7).count(-1) == 1 and t.lineup.has(sub.id) and t.lineup.has(gk2.id), "the other two on the bench, one place EMPTY")
	var gk := PoloTeam.LINEUP_SPOTS.find("gk")
	var lw := PoloTeam.LINEUP_SPOTS.find("lw")
	var rw := PoloTeam.LINEUP_SPOTS.find("rw")
	var s1 := PoloTeam.LINEUP_SPOTS.find("s1")
	var s3 := PoloTeam.LINEUP_SPOTS.find("s3")
	var at_sub := t.lineup.find(sub.id)
	var at_gk2 := t.lineup.find(gk2.id)
	var empty := t.lineup.find(-1)
	# the grey bench
	UI.drawn_log = []
	scr.cards[sub.id].get_child(0).queue_redraw()
	await _frames()
	UI.drawn_log = null
	r.check(scr.on_bench(sub) and not scr.on_bench(t.starters()[1]), "a sub is on the bench, a starter isn't")
	# a tap: his page; a drag: no page
	var a: PoloPlayer = scr.at(lw)
	var b: PoloPlayer = scr.at(rw)
	var card: Button = scr.cards[a.id]
	var c0: Vector2 = card.global_position + Vector2(20, 20)
	_press(card, c0, true)
	_move(card, c0 + Vector2(3, 2))
	r.check(scr.drag_pid == -1, "a few pixels is still a tap, not a drag")
	_move(card, scr.board.global_position + scr.slot_rect(rw).get_center())
	r.check(scr.drag_pid == a.id and card.z_index > 0, "past the threshold it lifts, over the others")
	r.check(scr.hover == rw, "over another starter: that place lights up")
	_press(card, scr.board.global_position + scr.slot_rect(rw).get_center(), false)
	card.pressed.emit()   # what the button does on a release over itself
	await tree.process_frame
	r.check(Game.current_name == "roster", "a drag never opens his page")
	r.check(scr.at(lw) == b and scr.at(rw) == a, "starter to starter: LEFT WING and RIGHT WING swap")
	r.check(t.starters()[rw] == a and t.starters()[lw] == b, "...and the match lines them up that way")
	await _frames()
	scr = Game.current_screen
	# a sub on for a starter, through the screen's own drop
	var starter: PoloPlayer = scr.at(lw)
	r.check(_drag(scr, sub.id, lw), "sub to starter: dropped on LEFT WING")
	r.check(scr.at(lw) == sub and scr.at(at_sub) == starter and t.starters().has(sub) and not t.starters().has(starter), "the sub starts, the starter takes his bench place")
	await _frames()
	scr = Game.current_screen
	# subs reorder, into the empty place too
	r.check(_drag(scr, gk2.id, empty) and scr.at(empty) == gk2 and scr.at(at_gk2) == null, "sub to sub: the backup keeper to the EMPTY place")
	await _frames()
	scr = Game.current_screen
	var x: PoloPlayer = scr.at(at_sub)
	r.check(_drag(scr, x.id, empty) and scr.at(empty) == x and scr.at(at_sub) == gk2, "sub to sub: two swap")
	await _frames()
	scr = Game.current_screen
	# refused: a keeper in the field, a field player in goal, a starter to an empty bench place, nowhere
	var before: Array = t.lineup.duplicate()
	r.check(not _drag(scr, gk2.id, lw) and t.lineup == before, "the backup keeper can't play LEFT WING")
	r.check(not _drag(scr, scr.at(rw).id, gk) and t.lineup == before, "a field player can't go in goal")
	r.check(not _drag(scr, scr.at(rw).id, t.lineup.find(-1)) and t.lineup == before, "a starter can't leave his place empty for the bench")
	r.check(scr.at(s3) == x and not scr.can_swap(gk, s3) and not scr.can_swap(s3, gk), "the starting keeper can't swap with a field sub")
	var d: PoloPlayer = scr.at(rw)
	scr.lift(d.id, scr.cards[d.id].global_position + Vector2(10, 10))
	r.check(scr.drop(scr.board.global_position + Vector2(-50, -50)) == false and t.lineup == before and scr.cards[d.id].position == scr.slot_rect(rw).position,
		"dropped nowhere: back to his place, nothing changed")
	r.check(_drag(scr, gk2.id, gk) and scr.at(gk) == gk2 and t.starters()[0] == gk2, "keeper for keeper: the backup goes in goal, and keeps goal in the match")
	await _frames()
	# a hurt starter keeps his place (injuries only lower his attributes for now)
	var hurt: PoloPlayer = scr.at(rw)
	var rq := RandomNumberGenerator.new()
	Development.injure(hurt, rq, "moderate")
	var seven := t.starters()
	r.check(seven.size() == 7 and seven[rw] == hurt and t.lineup[rw] == hurt.id, "a hurt starter still plays his place")
	Development.heal(hurt)
	# saved, and loaded back the same
	var c2 := Career.from_dict(JSON.parse_string(JSON.stringify(c.to_dict())))
	var t2 := c2.team()
	r.check(t2.lineup == t.lineup and t2.starters().map(func(p): return p.id) == t.starters().map(func(p): return p.id), "the lineup saves and loads: the same seven in the same places, the same bench")
	var p2 := t2.find_id(sub.id)
	var sub_rt := PoloPlayer.from_dict(JSON.parse_string(JSON.stringify(sub.to_dict())))
	r.check(p2 != null and p2.number == 30 and JSON.stringify(p2.to_dict()) == JSON.stringify(sub_rt.to_dict()),
		"a moved player is just who he was: number, stats, form and stars")
	# an older save: no lineup, the team's own seven, and a first visit keeps them
	var old := c.to_dict()
	old.teams[c.school].erase("lineup")
	var c3 := Career.from_dict(JSON.parse_string(JSON.stringify(old)))
	r.check(not c3.team().has_lineup() and c3.team().starters().size() == 7, "an older save loads with no lineup: its own seven play")
	var seven3: Array = c3.team().starters().map(func(p): return p.id)
	load("res://src/ui/screens/roster.gd").set_lineup(c3.team())
	r.check(c3.team().lineup.slice(0, 7).all(func(pid): return seven3.has(pid)), "its first roster visit keeps those seven as the starters")
	# a starter leaves (graduates): the best fit sub moves up, nobody made up
	var gone: PoloPlayer = t.find_id(int(t.lineup[lw]))
	t.roster.erase(gone)
	t.sync_lineup()
	r.check(t.lineup[lw] != -1 and t.find_id(int(t.lineup[lw])) != null and not t.find_id(int(t.lineup[lw])).is_keeper() and not t.lineup.has(gone.id),
		"a starter gone: a field sub takes his place")
	# the AI's teams never get a lineup
	r.check(c.teams.values().filter(func(tt: PoloTeam): return tt != t and tt.has_lineup()).is_empty(), "only your team has a lineup")
	Game.career = null

## Drags `pid`'s card onto lineup place `to` with the screen's own lift and drop. Returns
## whether they swapped.
func _drag(scr, pid: int, to: int) -> bool:
	var card: Button = scr.cards[pid]
	if not scr.lift(pid, card.global_position + Vector2(10, 10)):
		return false
	var gp: Vector2 = scr.board.global_position + scr.slot_rect(to).get_center()
	scr.follow(gp)
	return scr.drop(gp)

func _press(card: Control, gp: Vector2, down: bool) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = down
	ev.global_position = gp
	ev.position = gp - card.global_position
	card.gui_input.emit(ev)

func _move(card: Control, gp: Vector2) -> void:
	var ev := InputEventMouseMotion.new()
	ev.button_mask = MOUSE_BUTTON_MASK_LEFT
	ev.global_position = gp
	ev.position = gp - card.global_position
	card.gui_input.emit(ev)

func _settings() -> void:
	var tree: SceneTree = r.get_tree()
	var dev_was: bool = Game.settings.get("dev_mode", false)
	Game.settings.dev_mode = false
	Game.goto("settings")
	await tree.process_frame
	r.check(not _has_button(Game.current_screen, "TEST PLAYER FORM"), "Settings: Developer Mode, off, no form lab")
	Game.settings.dev_mode = true
	Game.goto("settings", {}, false)
	await tree.process_frame
	r.check(_has_button(Game.current_screen, "TEST PLAYER FORM"), "Developer Mode on: TEST PLAYER FORM")
	Game.settings.dev_mode = dev_was
	Game.goto("title")
	await tree.process_frame

func _rising(a: Array) -> bool:
	for i in range(1, a.size()):
		if int(a[i]) < int(a[i - 1]):
			return false
	return true

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

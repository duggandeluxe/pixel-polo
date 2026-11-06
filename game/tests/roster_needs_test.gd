extends RefCounted
## THE ROSTER NEEDS & RECRUITING DEADLINE update: RosterNeeds (next season's places), PINNED
## RECRUITS (Recruiting pins), the deadline warnings (hub). Numbered by the spec's REQUIRED
## TESTING (21 roster needs, 22 warnings, 23 saves).
##   godot --headless --path game -- --test roster_needs

var r
const P := PoloPlayer.Pos

func run(runner) -> void:
	r = runner
	print("roster needs & recruiting deadline")
	Store.reset_for_tests()
	_matching()
	_career_needs()
	_pins()
	_deadline()
	await _screens()
	Game.career = null
	Game.goto("title")
	await r.get_tree().process_frame

func _frames(n := 2) -> void:
	for _i in n:
		await r.get_tree().process_frame

func _man(pos: int, lefty := false, year := 2) -> PoloPlayer:
	var p := AttrBench.player({}, pos == P.GK, {}, pos)
	p.lefty = lefty
	p.year = year
	return p

func _team(spec: Array) -> Array:
	return spec.map(func(s): return _man(s[0], s.size() > 1 and bool(s[1])) if s is Array else _man(int(s)))

# ------------------------------------------------------------------ 21: the matching
func _matching() -> void:
	var seven := _team([P.GK, P.CENTER, P.DEFENDER, P.DRIVER, P.DRIVER, P.WING, P.WING])
	var e := RosterNeeds.evaluate(seven)
	r.check(e.legal and RosterNeeds.GROUPS.all(func(g): return e[g].status == RosterNeeds.THIN) and e.ready == "DEPTH RECOMMENDED",
		"21: exactly a seven: a legal lineup, every place THIN, DEPTH RECOMMENDED (%s)" % RosterNeeds.strip_text(e))
	var no_gk := RosterNeeds.evaluate(_team([P.CENTER, P.DEFENDER, P.DRIVER, P.DRIVER, P.WING, P.WING, P.UTILITY]))
	r.check(no_gk.GK.status == RosterNeeds.NEED and not no_gk.legal and no_gk.ready == "NEEDS ATTENTION", "21: no keeper: GK NEED, NEEDS ATTENTION")
	# one utility can't be an attacker and a wing at once
	var util := RosterNeeds.evaluate(_team([P.GK, P.CENTER, P.DEFENDER, P.DRIVER, P.WING, P.UTILITY]))
	r.check(not util.legal and (util.ATK.status == RosterNeeds.NEED or util.WG.status == RosterNeeds.NEED),
		"21: an attacker, a wing and a utility are three men for four places: never a complete lineup (%s)" % RosterNeeds.strip_text(util))
	r.check(int(util.ATK.eligible) == 3 and int(util.WG.eligible) == 3, "21: ...though each could play either kind (eligible 3 each, one man one place)")
	# lefties only on the lefty side: three lefties and one wing can't make the four perimeter places
	var lefties := RosterNeeds.evaluate(_team([P.GK, P.CENTER, P.DEFENDER, [P.DRIVER, true], [P.WING, true], [P.UTILITY, true], P.WING]))
	r.check(not lefties.legal, "21: three lefties: only two lefty places, so the plain attacker's place is a NEED (%s)" % RosterNeeds.strip_text(lefties))
	var c_for_2md := RosterNeeds.evaluate(_team([P.GK, P.CENTER, P.CENTER, P.DRIVER, P.DRIVER, P.WING, P.WING]))
	r.check(c_for_2md.legal and c_for_2md["2MD"].status == RosterNeeds.THIN, "21: a second centre covers 2MD (the lineup's own rule)")
	var deep := RosterNeeds.evaluate(_team([P.GK, P.GK, P.CENTER, P.DEFENDER, P.CENTER, P.DRIVER, P.DRIVER, P.WING, P.WING, P.UTILITY]))
	r.check(deep.legal and RosterNeeds.GROUPS.all(func(g): return deep[g].status == RosterNeeds.COVERED) and deep.ready == "READY",
		"21: ten with a backup keeper, a spare post and a utility: all COVERED, READY within the cap of 10 (%s)" % RosterNeeds.strip_text(deep))

# ------------------------------------------------------------------ 21: next season's roster
func _career_needs() -> void:
	var c := Career.new_game("SJCU", "A", "B", 71)
	var t := c.team()
	# every keeper a senior: next season has none
	for p in t.roster:
		if p.is_keeper():
			p.year = 4
	var n0 := RosterNeeds.of(c)
	r.check(n0.GK.status == RosterNeeds.NEED, "21: the graduating keepers don't count: GK NEED")
	var cur := RosterNeeds.evaluate(t.roster)
	r.check(cur.GK.status != RosterNeeds.NEED, "21: (this season's roster still has them: it's next season that's counted)")
	# a keeper on the market: TEAM NEED; pinned: no change; signed: counted
	var k := Recruiting.make(c.rng, 3.0, 3.5, "normal", {}, P.GK)
	k.id = c.new_id()
	var rk := {"p": k, "price": Recruiting.price_of(k), "legacy": false}
	c.market.append(rk)
	r.check("GK" in RosterNeeds.fills(c, k), "21: a keeper on the market fills the GK NEED (TEAM NEED: GK)")
	c.credits = 500
	Recruiting.toggle_pin(c, rk)
	r.check(RosterNeeds.of(c).GK.status == RosterNeeds.NEED, "21: pinning him changes nothing")
	Recruiting.refresh(c)
	r.check(RosterNeeds.of(c).GK.status == RosterNeeds.NEED, "21: nor does a refresh")
	var w0 := c.wallet()
	r.check(Recruiting.sign(c, rk) == "" and c.wallet() == w0 - int(rk.price), "21: signing him (his price, as ever)")
	var n1 := RosterNeeds.of(c)
	r.check(n1.GK.status == RosterNeeds.THIN, "21: signed: GK NEED -> THIN at once")
	r.check(not "GK" in RosterNeeds.fills(c, k), "21: and the tag moves on (no longer a need he fills)")
	r.check(Recruiting.projected(c) == t.roster.size() - Recruiting.graduating(c).size() + c.incoming.size(), "21: the projected roster count is unchanged in method")
	# a departure (a player let go) is counted
	var gone: PoloPlayer = t.roster.filter(func(p: PoloPlayer): return p.year < 4 and p.pos == P.CENTER)[0] if t.roster.any(func(p: PoloPlayer): return p.year < 4 and p.pos == P.CENTER) else null
	if gone != null:
		var before := int(RosterNeeds.of(c).C.eligible)
		t.roster.erase(gone)
		r.check(int(RosterNeeds.of(c).C.eligible) == before - 1, "21: a player leaving is gone from next season's count")

# ------------------------------------------------------------------ pins
func _pins() -> void:
	var c := Career.new_game("SJCU", "A", "B", 72)
	c.credits = 200
	var pinned_ids: Array = []
	for i in Recruiting.PIN_MAX:
		var err := Recruiting.toggle_pin(c, c.market[i])
		if i == 0:
			r.check(err == "", "pin a prospect (free: %s)" % err)
		pinned_ids.append((c.market[i].p as PoloPlayer).id)
	r.check(Recruiting.toggle_pin(c, c.market[Recruiting.PIN_MAX]) != "", "pins: %d at most" % Recruiting.PIN_MAX)
	var others: Array = c.market.filter(func(x): return not Recruiting.is_pinned(x)).map(func(x): return (x.p as PoloPlayer).id)
	Recruiting.refresh(c)
	var now: Array = c.market.map(func(x): return (x.p as PoloPlayer).id)
	r.check(pinned_ids.all(func(id): return id in now) and others.all(func(id): return not id in now) and c.market.size() == Recruiting.MARKET_SIZE,
		"pins survive a refresh; only the unpinned are replaced; still %d on the market" % Recruiting.MARKET_SIZE)
	var d := Career.from_dict(JSON.parse_string(JSON.stringify(c.to_dict())))
	r.check(Recruiting.pinned(d).map(func(x): return (x.p as PoloPlayer).id) == pinned_ids, "23: pins survive a save")
	r.check(d.market.map(func(x): return [(x.p as PoloPlayer).id, int(x.price)]) == c.market.map(func(x): return [(x.p as PoloPlayer).id, int(x.price)]), "23: the market and its prices exactly as saved")
	Recruiting.toggle_pin(c, Recruiting.pinned(c)[0])
	r.check(Recruiting.pinned(c).size() == Recruiting.PIN_MAX - 1, "unpin")
	Recruiting.start_season(c)
	r.check(Recruiting.pinned(c).is_empty(), "the recruiting class closes (a new season's market): the pins expire with it")

# ------------------------------------------------------------------ 22: the deadline
func _deadline() -> void:
	var c := Career.new_game("SJCU", "A", "B", 73)
	c.credits = 300
	var w0 := c.wallet()
	var d0 := Recruiting.deadline(c)
	r.check((d0.pinned as Array).is_empty() and int(d0.slots) == Recruiting.SIGN_MAX and int(d0.credits) == w0, "22: nothing pinned, all four signings left, the credits as they are")
	Recruiting.toggle_pin(c, c.market[0])
	Recruiting.toggle_pin(c, c.market[1])
	var d1 := Recruiting.deadline(c)
	r.check((d1.pinned as Array).size() == 2 and bool(d1.issues) and c.wallet() == w0, "22: two pinned unsigned: worth a warning; nothing charged")
	r.check(Recruiting.deadline_text(d1).contains("2 UNSIGNED PINNED RECRUITS") and Recruiting.deadline_text(d1).contains("SIGNING SLOTS REMAINING: 4"), "22: the warning's numbers")
	# a full class: no slots, said plainly
	for i in 4:
		var x := Recruiting.make(c.rng, 2.0, 2.5, "normal", {}, P.DRIVER)
		x.id = c.new_id()
		c.incoming.append({"p": x, "price": 10, "legacy": false})
	var d2 := Recruiting.deadline(c)
	r.check(int(d2.slots) == 0 and Recruiting.deadline_text(d2).contains("class is full"), "22/15: a full class: 0 slots, and these pinned can't be signed")
	r.check(Recruiting.sign_block(c, Recruiting.pinned(c)[0]) != "", "15: the limit still holds for a pinned recruit")
	# nothing to warn about
	var c2 := Career.new_game("SJCU", "A", "B", 74)
	var d3 := Recruiting.deadline(c2)
	r.check(not bool(d3.issues) or not (d3.need as Array).is_empty() or int(d3.over) > 0, "18: no pins, no NEED, no cuts: no warning")

func _press(label: String) -> bool:
	for b in Game.overlay.find_children("*", "Button", true, false):
		if (b as Button).text == label or String(b.get_meta("label", "")) == label or (b as Button).text.begins_with(label):
			(b as Button).pressed.emit()
			return true
	return false

func _dialog_title() -> String:
	for l in Game.overlay.find_children("*", "", true, false):
		var t := ""
		if l is Label:
			t = (l as Label).text
		elif l is RichTextLabel:
			t = (l as RichTextLabel).get_parsed_text()
		if t.contains("RECRUITING DEADLINE") or t.contains("FINAL RECRUITING") or t.begins_with("START"):
			return t
	return ""

func _clear_dialogs() -> void:
	for ch in Game.overlay.get_children():
		if ch != Game._fade:   # (the dialogs; never the screen fade)
			ch.queue_free()

func _screens() -> void:
	# the market screen: the strip, the PINNED tab, the tags
	var c := Career.new_game("SJCU", "A", "B", 75)
	c.queue.clear()
	Game.career = c
	for p in c.team().roster:
		if p.is_keeper():
			p.year = 4
	var k := Recruiting.make(c.rng, 3.0, 3.5, "normal", {}, P.GK)
	k.id = c.new_id()
	c.market[0] = {"p": k, "price": Recruiting.price_of(k), "legacy": false}
	Game.goto("recruiting", {"tab": "MARKET"})
	await _frames(3)
	var scr = Game.current_screen
	r.check(scr.find_child("RosterNeeds", true, false) == null and scr.find_child("Need_GK", true, false) == null \
		and scr.find_child("Projection", true, false) != null and scr.find_child("ProjectedCount", true, false) != null,
		"21: the projected-roster banner, and no TEAM NEEDS strip on the recruiting screen (removed)")
	var card: Control = scr.find_child("Card_%d" % k.id, true, false)
	r.check(card != null and not card.has_meta("fills") and RosterNeeds.fills(c, k, RosterNeeds.of(c)).has("GK"), "21: he still fills the GK NEED (RosterNeeds), not shown on his card")
	var sz: Vector2 = card.size
	r.check(sz.y >= 80.0, "21: the cards keep their size (%s)" % str(sz))
	Recruiting.toggle_pin(c, c.market[0])
	scr.tab = "PINNED"
	scr._render()
	await _frames(2)
	r.check(scr.find_children("Card_*", "", true, false).size() == 1, "the PINNED tab: the pinned prospect")
	scr.tab = "MARKET"
	# the hub: the early warning once, the final one at NEXT SEASON
	c.phase = "done"
	c.recruit_warned = ""
	_clear_dialogs()
	Game.goto("hub")
	await _frames(4)
	r.check(_dialog_title().contains("RECRUITING DEADLINE APPROACHING"), "22: the season over, a pin unsigned and a NEED: RECRUITING DEADLINE APPROACHING!")
	r.check(c.recruit_warned == c.season_label(), "22: acknowledged for this season (saved)")
	var d := Career.from_dict(JSON.parse_string(JSON.stringify(c.to_dict())))
	r.check(d.recruit_warned == c.season_label(), "23: the acknowledgment survives a save")
	_clear_dialogs()
	await _frames(1)
	Game.goto("hub")
	await _frames(4)
	r.check(not _dialog_title().contains("APPROACHING"), "22: not again this season")
	var hub = Game.current_screen
	var signed0 := c.incoming.size()
	var w0 := c.wallet()
	hub._next_season()
	await _frames(1)
	r.check(_dialog_title().contains("FINAL RECRUITING WARNING"), "22: NEXT SEASON with unresolved matters: FINAL RECRUITING WARNING")
	r.check(_press("RETURN TO RECRUITING"), "22: RETURN TO RECRUITING")
	await _frames(3)
	r.check(Game.current_name == "recruiting" and c.phase == "done" and Recruiting.pinned(c).size() == 1 and c.incoming.size() == signed0 and c.wallet() == w0,
		"22: ...cancels: still the season's end, the pin and the signings untouched, nothing charged")
	_clear_dialogs()
	Game.goto("hub")
	await _frames(4)
	Game.current_screen._next_season()
	await _frames(1)
	r.check(_press("CONTINUE TO OFFSEASON"), "22: CONTINUE TO OFFSEASON")
	await _frames(4)
	r.check(c.phase != "done" and c.incoming.is_empty() and Recruiting.pinned(c).is_empty() or c.phase == "cuts", "22: ...the transition as ever: the class joins, the pins expire (phase %s)" % c.phase)
	_clear_dialogs()
	# nothing unresolved: the plain START dialog, no warning
	var c3 := Career.new_game("SJCU", "A", "B", 76)
	c3.queue.clear()
	c3.phase = "done"
	Game.career = c3
	Game.goto("hub")
	await _frames(4)
	_clear_dialogs()
	if not bool(Recruiting.deadline(c3).issues):
		Game.current_screen._next_season()
		await _frames(1)
		r.check(_dialog_title().begins_with("START"), "18: nothing unresolved: the usual START dialog, no warning")
	_clear_dialogs()
	Game.goto("title")
	await _frames(1)

##   godot --path game -- --test roster_needs_png <dir>
static func shots(runner, out: String) -> void:
	DirAccess.make_dir_recursive_absolute(out)
	var tree: SceneTree = runner.get_tree()
	Store.reset_for_tests()
	var c := Career.new_game("SJCU", "A", "B", 75)
	c.queue.clear()
	c.credits = 120
	Game.career = c
	for p in c.team().roster:
		if p.is_keeper():
			p.year = 4
	var k := Recruiting.make(c.rng, 3.0, 3.5, "normal", {}, PoloPlayer.Pos.GK)
	k.id = c.new_id()
	c.market[0] = {"p": k, "price": Recruiting.price_of(k), "legacy": false}
	Recruiting.toggle_pin(c, c.market[0])
	Recruiting.toggle_pin(c, c.market[3])
	var snap := func(name: String) -> void:
		await tree.create_timer(0.5).timeout
		await RenderingServer.frame_post_draw
		runner.get_viewport().get_texture().get_image().save_png(out.path_join(name + ".png"))
		print("  shot ", name)
	Game.goto("recruiting", {"tab": "MARKET"})
	await snap.call("n1_market")
	Game.goto("recruiting", {"tab": "PINNED"})
	await snap.call("n3_pinned")
	c.phase = "done"
	c.recruit_warned = ""
	Game.goto("hub")
	await snap.call("n4_early_warning")
	Game.goto("hub")
	await tree.process_frame
	Game.current_screen._next_season()
	await snap.call("n5_final_warning")
	Game.career = null

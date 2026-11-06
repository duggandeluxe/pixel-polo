extends RefCounted
## HOT star consistency, the player card flip and its PLAYER MOMENTUM back, and the one-time HOT
## tip (docs: "Hot Star Consistency, Player Card Flip Animation & Momentum Progress System").
##   godot --headless --path game -- --test hot_card

const Roster := preload("res://src/ui/screens/roster.gd")

var r   # the test runner

func run(runner) -> void:
	r = runner
	print("hot card")
	Store.reset_for_tests()
	_star_rule()
	_momentum()
	await _profile()
	await _tip()

## [gold places, red places] a bar shows (a half gold counts 0.5).
func _counts(cur: float, red: int) -> Array:
	var gold := 0.0
	var reds := 0
	for f in Deck.star_fills(cur, cur, red):
		gold += float(f.gold)
		if float(f.form) > float(f.gold) and float(f.form) >= 1.0:
			reds += 1
	return [gold, reds]

func _star_rule() -> void:
	r.check(_counts(5.0, 0) == [5.0, 0], "a five-star, NORMAL: five gold")
	r.check(_counts(5.0, 1) == [4.0, 1], "a five-star, HOT: four gold and one red")
	r.check(_counts(5.0, 2) == [3.0, 2], "a five-star, VERY HOT: three gold and two red")
	r.check(_counts(3.0, 1) == [3.0, 1] and _counts(3.0, 2) == [3.0, 2], "a three-star: his three gold, then one or two red")
	r.check(_counts(4.5, 1) == [4.0, 1] and _counts(4.0, 2) == [3.0, 2], "4.5 HOT and 4 VERY HOT: the red still whole stars (no half red)")
	r.check(_counts(3.5, 1) == [3.5, 1] and _counts(3.5, 2) == [3.0, 2], "3.5: HOT keeps the half gold; VERY HOT needs the room, three gold and two red")
	var ok := true
	for h in range(1, 11):
		for st in PlayerForm.LEVELS:
			var red := PlayerForm.red_stars(st)
			var cnt := _counts(h * 0.5, red)
			ok = ok and int(cnt[1]) == red
	r.check(ok, "every star rating, every form: exactly as many red stars as his HOT level")
	# the roster word and the stars are one state
	var p := AttrBench.player({"pas": 9, "sho": 9, "str": 9, "dfn": 9})
	var same := true
	for h in 3:
		p.heat = h
		var line: Dictionary = Roster.star_line(p)
		same = same and (String(line.word) != "") == (_counts(float(line.cur), PlayerForm.red_stars(String(line.state)))[1] > 0)
	r.check(same and is_equal_approx(p.stars, 5.0), "a five-star's HOT / VERY HOT word always comes with his red stars")
	p.heat = 0
	r.check(StarFx.changed_places(5.0, 5.0, PlayerForm.NORMAL, PlayerForm.HOT) == [4], "a five-star going HOT: his fifth star animates gold to red")

func _momentum() -> void:
	var p := PoloPlayer.new()
	var m := func(form: Array, heat: int) -> Dictionary:
		p.form = form
		p.heat = heat
		return PlayerForm.momentum(p)
	var a: Dictionary = m.call([], 0)
	r.check(a.status == "NEUTRAL" and is_equal_approx(a.bar, 0.0) and a.next == "1ST HOT STAR" and a.stars == 0, "no games: NEUTRAL, 0%, next the first HOT star")
	a = m.call([1, -1, 0], 0)
	r.check(a.status == "NEUTRAL" and is_equal_approx(a.bar, 0.0), "a GOOD and a BAD cancel out: NEUTRAL")
	a = m.call([1, 0, 1], 0)
	r.check(a.status == "HEATING UP" and is_equal_approx(a.bar, 2.0 / 3.0), "two GOOD of the three his run needs: HEATING UP, 67%")
	a = m.call([1, 1, 1], 1)
	r.check(a.status == "HOT" and a.stars == 1 and is_equal_approx(a.bar, 0.75) and a.next == "2ND HOT STAR", "HOT on a run of 3: 75% of the 4 VERY HOT needs")
	a = m.call([1, 1, 1, 0, -1], 1)
	r.check(a.status == "COOLING DOWN" and a.cooling and a.stars == 1 and is_equal_approx(a.bar, 0.5), "HOT on a run of 2 (what he needs to keep it): COOLING DOWN, half left")
	a = m.call([1, 1, 1, 1, 1], 2)
	r.check(a.status == "ON FIRE" and a.stars == 2 and is_equal_approx(a.bar, 1.0) and a.next == "MAX HOT STARS", "VERY HOT on five GOOD: ON FIRE, the most there is")
	a = m.call([1, 1, 1, 1, 0], 2)
	r.check(a.status == "COOLING DOWN" and a.stars == 2 and is_equal_approx(a.bar, 0.5), "VERY HOT after a NORMAL game at the edge: COOLING DOWN")
	# the bar is the heat's own numbers: it fills to exactly where heat moves
	p.form = []
	p.heat = 0
	var steps: Array = []
	for _i in 3:
		PlayerForm.push_grade(p, PlayerForm.GOOD)
		steps.append([PlayerForm.momentum(p).status, snappedf(float(PlayerForm.momentum(p).bar), 0.01), p.heat])
	r.check(steps == [["HEATING UP", 0.33, 0], ["HEATING UP", 0.67, 0], ["HOT", 0.75, 1]], "three GOOD games: 33%%, 67%%, then HOT (%s)" % [steps])
	PlayerForm.push_grade(p, PlayerForm.BAD)
	r.check(PlayerForm.momentum(p).status == "COOLING DOWN" and p.heat == 1, "a BAD game after: still HOT, COOLING DOWN")
	PlayerForm.push_grade(p, PlayerForm.BAD)
	r.check(p.heat == 0 and PlayerForm.momentum(p).status == "HEATING UP" and is_equal_approx(PlayerForm.momentum(p).bar, 1.0 / 3.0),
		"another: he drops back to NORMAL, his run down to 1 (33%%): progress isn't kept")
	# over random seasons: the back's red stars are always his heat's
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var agree := true
	p.form = []
	p.heat = 0
	for _i in 2000:
		PlayerForm.push_grade(p, rng.randi_range(-1, 1))
		var mm := PlayerForm.momentum(p)
		agree = agree and int(mm.stars) == PlayerForm.red_stars(p.form_state()) and float(mm.bar) >= 0.0 and float(mm.bar) <= 1.0
	r.check(agree, "2000 random games: the momentum's red stars always match his HOT level")

func _find(n: Node, name: String) -> Node:
	if String(n.name) == name and not n.is_queued_for_deletion():
		return n
	for ch in n.get_children():
		var f := _find(ch, name)
		if f != null:
			return f
	return null

func _profile() -> void:
	var tree: SceneTree = r.get_tree()
	var c := Career.new_game("CULA", "A", "B", 17)
	Game.career = c
	c.hot_tip = true
	var p: PoloPlayer = c.team().starters()[2]
	p.form = [1, 1, 1, 1]
	p.heat = 2
	var before := JSON.stringify(p.to_dict())
	Game.goto("player", {"id": p.id})
	await tree.process_frame
	await tree.process_frame
	var scr = Game.current_screen
	var cur: Node = _find(scr, "Stars_Current")
	var pot: Node = _find(scr, "Stars_Potential")
	r.check(int(cur.get_meta("red")) == 2 and int(cur.get_meta("red")) == PlayerForm.red_stars(Roster.star_line(p).state), "VERY HOT: his page's CURRENT row has the roster card's two red stars")
	r.check(int(pot.get_meta("red")) == 0 and is_equal_approx(float(pot.get_meta("stars")), p.pot_stars), "POTENTIAL never shows form")
	r.check(JSON.stringify(p.to_dict()) == before, "opening his page changes nothing about his form")
	# the flip
	var card: Control = scr.card
	r.check(_find(card, "Front").visible and not _find(card, "Back").visible and _find(scr, "FlipHint") != null, "the card opens on its front, the flip hint on it")
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	scr._card_input(ev)
	await tree.process_frame
	r.check(scr.back_side and _find(card, "Back").visible and not _find(card, "Front").visible, "a click on the card flips it to PLAYER MOMENTUM")
	var m: Dictionary = _find(card, "Back").get_meta("momentum")
	r.check(m == PlayerForm.momentum(p) and m.status == "ON FIRE", "...which reads his real momentum (%s)" % m.status)
	scr._card_input(ev)
	await tree.process_frame
	r.check(not scr.back_side and _find(card, "Front").visible, "another click flips it back to his portrait")
	scr.flipping = true
	scr.flip()
	r.check(not scr.back_side, "a tap while it's turning does nothing")
	scr.flipping = false
	# the edit button is its own (a Button takes its click; the card never sees it)
	var edit: Button = null
	for b in _all(card):
		if b is Button and (b as Button).tooltip_text.begins_with("EDIT PLAYER"):
			edit = b
	r.check(edit != null and edit.mouse_filter == Control.MOUSE_FILTER_STOP, "the portrait's edit button is still there, taking its own clicks")
	# the flip lasts through a refresh (an upgrade), and an upgrade doesn't touch form
	scr.flip()
	scr._refresh()
	await tree.process_frame
	r.check(scr.back_side and _find(scr.card, "Back").visible, "the card stays on the side you left it through a refresh")
	# progress follows games
	var c2 := Career.new_game("GWU", "A", "B", 23)
	Game.career = c2
	c2.hot_tip = true
	var q: PoloPlayer = c2.team().starters()[1]
	var n0 := q.form.size()
	c2.sim_my_game()
	Game.goto("player", {"id": q.id})
	await tree.process_frame
	await tree.process_frame
	scr = Game.current_screen
	scr.flip()
	r.check(q.form.size() == n0 + 1 and _find(scr.card, "Back").get_meta("momentum") == PlayerForm.momentum(q), "after a game his card's back shows the new grade's momentum")
	var back := Career.from_dict(JSON.parse_string(JSON.stringify(c2.to_dict())))
	var q2: PoloPlayer = back.team().find_id(q.id)
	r.check(q2.heat == q.heat and q2.form == q.form and PlayerForm.momentum(q2) == PlayerForm.momentum(q), "momentum comes back the same from a save")

func _all(n: Node) -> Array:
	var out: Array = [n]
	for ch in n.get_children():
		out.append_array(_all(ch))
	return out

func _tip() -> void:
	var tree: SceneTree = r.get_tree()
	var c := Career.new_game("BUCK", "A", "B", 29)
	Game.career = c
	for q: PoloPlayer in c.team().roster:
		q.form = []
		q.heat = 0
	Game.goto("roster")
	await tree.process_frame
	r.check(not c.hot_tip and not Game.current_screen.hot_tip(), "nobody heating up: no tip")
	(c.team().starters()[3] as PoloPlayer).form = [1, 1]
	r.check(Game.current_screen.hot_tip() and c.hot_tip, "the first time one of yours heats up: PLAYERS CAN HEAT UP!")
	r.check(not Game.current_screen.hot_tip(), "...and never again")
	_close_dialogs()
	var saved := JSON.stringify(c.to_dict())
	r.check(saved.contains("\"hot_tip\":true") and Career.from_dict(JSON.parse_string(saved)).hot_tip, "seen is saved with the career")
	var old: Dictionary = JSON.parse_string(saved)
	old.erase("hot_tip")
	r.check(not Career.from_dict(old).hot_tip, "an older save hasn't seen it (it shows once)")
	Game.goto("hub")

func _close_dialogs() -> void:
	var ov = Game.get("overlay")
	if ov is Node:
		for ch in (ov as Node).get_children():
			if ch != Game.get("_fade"):   # (the screen fade lives there too: only the dialogs go)
				ch.queue_free()

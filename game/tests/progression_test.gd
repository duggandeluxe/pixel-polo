extends RefCounted
## Player development, star ratings and dynamic recruiting (docs: "Complete Player Development,
## Star Ratings & Dynamic Recruiting Overhaul"): the star steps (Attributes.stars_of), the
## player page's ten-box upgrades (the old yearly classes went with the recruiting overhaul), each
## prospect's ceilings from his development profile (CollegeGen.make_prospect), and saves.
##   godot --headless --path game -- --test progression

var r   # the test runner

func run(runner) -> void:
	r = runner
	print("progression")
	Store.reset_for_tests()
	_star_steps()
	_boxes()
	await _upgrades_screen()
	_saves()
	_hot_cold()

func _p(vals: Dictionary, keeper := false, pots := {}, pos := PoloPlayer.Pos.UTILITY) -> PoloPlayer:
	return AttrBench.player(vals, keeper, pots, pos)

# ------------------------------------------------------------------ stars
func _star_steps() -> void:
	var table := [[0.0, 0.5], [0.99, 0.5], [1.0, 1.0], [1.99, 1.0], [2.0, 1.5], [3.0, 2.0], [4.0, 2.5], [5.0, 3.0],
		[5.5, 3.0], [5.99, 3.0], [6.0, 3.5], [6.75, 3.5], [7.0, 4.0], [7.49, 4.0], [7.5, 4.5], [7.99, 4.5], [8.0, 5.0], [10.0, 5.0]]
	var bad: Array = []
	for row in table:
		if not is_equal_approx(Attributes.stars_of(float(row[0])), float(row[1])):
			bad.append(row)
	r.check(bad.is_empty(), "the star steps: 5.5 = 3, 6.75 = 3.5, 7.49 = 4, 7.5 = 4.5, 7.99 = 4.5, 8.0 = 5, 10 = 5 (wrong: %s)" % [bad])
	# the spec's players: five stars without perfect attributes, and still different players
	var shooter := _p({"pas": 8, "sho": 10, "str": 6, "dfn": 8})
	var stopper := _p({"pas": 6, "sho": 7, "str": 9, "dfn": 10})
	var even := _p({"pas": 8, "sho": 8, "str": 8, "dfn": 8})
	r.check([shooter, stopper, even].all(func(q): return is_equal_approx(q.rating10(), 8.0) and is_equal_approx(q.stars, 5.0)),
		"elite shooter, defensive specialist, balanced 8s: all 8.0, all five stars")
	r.check(shooter.shoot > even.shoot and stopper.defense > even.defense and Attributes.release_mult(shooter) < Attributes.release_mult(stopper),
		"...and they still play differently (the shooter shoots, the stopper defends)")
	var gk := _p({"com": 7, "lun": 9, "blk": 8, "leg": 8}, true)
	r.check(is_equal_approx(gk.stars, 5.0) and is_equal_approx(_p({"com": 7, "lun": 8, "blk": 7, "leg": 7}, true).stars, 4.0),
		"goalkeepers: the same average and steps (8.0 = 5, 7.25 = 4)")
	# no float dust: 7.1 + 7.9 + 7.3 + 7.7 is 7.5 exactly however it adds up
	var dust := _p({"pas": 7.1, "sho": 7.9, "str": 7.3, "dfn": 7.7})
	r.check(is_equal_approx(dust.stars, 4.5), "an average of exactly 7.5 from fractions is 4.5 stars")
	var pot := _p({"pas": 6, "sho": 7, "str": 5, "dfn": 6}, false, {"pas": 9, "sho": 8, "str": 7, "dfn": 10})
	r.check(is_equal_approx(pot.stars, Attributes.stars_of(pot.rating10())) and is_equal_approx(pot.pot_stars, Attributes.stars_of(pot.potential10()))
		and is_equal_approx(pot.stars, 3.5) and is_equal_approx(pot.pot_stars, 5.0),
		"CURRENT (6.0: 3.5 stars) and POTENTIAL ((9 + 8 + 7 + 10) / 4 = 8.5: 5 stars) use the one calculation")
	# the team overall counts the stepped stars (2.0 team overall: 34.5 + 13 x stars / 7)
	var c := Career.new_game("LIUB", "A", "B", 5)
	var t: PoloTeam = c.team()
	var total := 0.0
	for q: PoloPlayer in t.starters():
		total += q.stars
	r.check(is_equal_approx(t.team_overall(false), 34.5 + 13.0 * total / 7.0) and t.base_ovr() == 65, "a team's BASE counts its seven's stars, the ones on screen (LIUB 65)")

# ------------------------------------------------------------------ the ten boxes
func _boxes() -> void:
	# PASSING 6 of a ceiling 9, no token: six green, three hollow cyan, one grey
	var states: Array = Deck.box_states(6.0, 9.0)
	r.check(states.size() == 10 and states == ["green", "green", "green", "green", "green", "green", "hollow", "hollow", "hollow", "grey"],
		"6 of 9: six green, three hollow, one grey (%s)" % [states])
	r.check(Deck.box_states(6.0, 9.0, 0.0, 1)[6] == "buy" and Deck.buy_box(6.0, 9.0) == 6, "...a token: the seventh filled cyan")
	r.check(Deck.buy_box(9.0, 9.0) == -1 and Deck.buy_box(10.0, 10.0) == -1, "at his ceiling (or 10): nothing to buy")
	r.check(Deck.box_state(6.0, -1.0, 7) == "unknown" and Deck.box_state(6.0, -1.0, 9) == "unknown",
		"a ceiling not scouted: every box past him the same unknown box")
	# fractions: the bar is exactly his number, the next box the one he's part way through
	r.check(Deck.box_state(6.4, 9.0, 6) == "hollow" and Deck.box_state(6.4, 9.0, 5) == "green" and Deck.buy_box(6.4, 9.0) == 6,
		"6.4: six green, the seventh part filled")
	r.check(Deck.box_state(6.0, 8.5, 8) == "hollow" and Deck.box_state(6.0, 8.5, 9) == "grey", "a ceiling of 8.5: the ninth box part open, the tenth grey")
	r.check(Deck.box_state(6.13, 6.13, 6) == "grey" and Deck.buy_box(6.13, 6.13) == -1, "6.13 at a ceiling of 6.13: the part-filled box is grey, nothing to buy")
	var w := 200.0
	var rs: Array = []
	for i in Deck.BOX_N:
		rs.append(Deck.box_rect(Rect2(0, 0, w, 15), i))
	r.check(rs.all(func(b): return b.size.x == (rs[0] as Rect2).size.x) and (rs[9] as Rect2).end.x <= w and (rs[1] as Rect2).position.x > (rs[0] as Rect2).end.x,
		"ten boxes the same size, apart, inside the row")

func _find_all(n: Node, prefix: String) -> Array:
	var out: Array = []
	if String(n.name).begins_with(prefix) and not n.is_queued_for_deletion():
		out.append(n)
	for ch in n.get_children():
		out.append_array(_find_all(ch, prefix))
	return out

func _up(scr: Node, key: String) -> Button:
	var all := _find_all(scr, "Up_" + key)
	return all[0] if not all.is_empty() else null

func _upgrades_screen() -> void:
	var tree: SceneTree = r.get_tree()
	var c := Career.new_game("GWU", "A", "B", 41)
	Game.career = c
	var p: PoloPlayer = c.team().starters()[2]
	for k in p.key_ratings():
		p.attrs[k] = 8.0
		p.attr_pot[k] = 10.0
	p.attrs["pas"] = 6.0
	p.attrs["dfn"] = 7.9
	p.attr_pot["pas"] = 9.0
	p.attr_pot["str"] = 8.0
	Attributes.sync(p)
	p.tokens = 3
	Game.goto("player", {"id": p.id})
	await tree.process_frame
	await tree.process_frame
	var scr = Game.current_screen
	r.check(_find_all(scr, "Boxes_").size() == 4 and _find_all(scr, "Up_").size() == 4, "the page: four attributes of ten boxes, a buy button each")
	var b := _up(scr, "pas")
	r.check(b != null and b.visible and int(b.get_meta("box")) == 6, "PASSING 6 of 9 with tokens: the seventh box to buy")
	var str_b := _up(scr, "str")
	r.check(str_b != null and not str_b.visible, "STRENGTH at its ceiling: nothing to buy, no MAXED")
	r.check(is_equal_approx(p.stars, 4.0) and is_equal_approx(float((_find_all(scr, "Stars_Current")[0] as Node).get_meta("stars")), 4.0),
		"7.475 average: CURRENT OVERALL four stars")
	var w0 := c.wallet()
	b.pressed.emit()
	b.pressed.emit()   # a second tap on the same box: one upgrade, not two
	await tree.process_frame
	r.check(is_equal_approx(p.attr("pas"), 7.0) and c.wallet() == w0 and p.tokens == 2, "a tap buys exactly one upgrade for one token, no credits (%.1f, %d tokens)" % [p.attr("pas"), p.tokens])
	r.check(is_equal_approx(p.stars, 4.5) and is_equal_approx(float((_find_all(scr, "Stars_Current")[0] as Node).get_meta("stars")), 4.5) and not scr.improved.is_empty(),
		"7.725: four and a half stars at once")
	var b2 := _up(scr, "pas")
	r.check(b2 != null and int(b2.get_meta("box")) == 7, "the cyan box moves to the eighth")
	r.check(String(scr.up.get("key", "")) == "pas" and int(scr.up.box) == 6, "...and the bought box flashes")
	var saved := Career.from_dict(JSON.parse_string(JSON.stringify(c.to_dict())))
	var sp: PoloPlayer = saved.team().find_id(p.id)
	r.check(sp.attrs == p.attrs and sp.attr_pot == p.attr_pot and sp.tokens == 2 and is_equal_approx(sp.stars, 4.5), "the upgrade survives a save")
	# up to the ceiling and no further
	b2.pressed.emit()
	await tree.process_frame
	var b3 := _up(scr, "pas")
	r.check(is_equal_approx(p.attr("pas"), 8.0) and b3 != null and int(b3.get_meta("box")) == 8, "8 of 9: the ninth box to buy")
	b3.pressed.emit()
	await tree.process_frame
	r.check(is_equal_approx(p.attr("pas"), 9.0) and not _up(scr, "pas").visible and not c.boost(p, "pas"), "at the ceiling: nothing to buy, and Career.boost refuses")
	# out of tokens: no cyan box anywhere, nothing bought
	r.check(p.tokens == 0, "three taps, three tokens spent")
	scr._refresh()
	await tree.process_frame
	var before := p.attr("dfn")
	scr._buy("dfn")
	r.check(not _up(scr, "dfn").visible and is_equal_approx(p.attr("dfn"), before), "no tokens: nothing to buy, nothing changes")
	# a goalkeeper the same way
	var gk: PoloPlayer = c.team().keeper()
	Attributes.set_ceiling(gk, "blk", 10.0)
	Attributes.set_value(gk, "blk", 5.0)
	gk.tokens = 2
	Game.goto("player", {"id": gk.id})
	await tree.process_frame
	await tree.process_frame
	scr = Game.current_screen
	var gb := _up(scr, "blk")
	var gw := c.wallet()
	gb.pressed.emit()
	await tree.process_frame
	r.check(_find_all(scr, "Boxes_").size() == 4 and is_equal_approx(gk.attr("blk"), 6.0) and c.wallet() == gw and gk.tokens == 1, "a goalkeeper's BLOCKING upgrades the same way")
	# fractional attributes: never rounded, the buy box where he is
	Attributes.set_ceiling(gk, "com", 9.0)
	Attributes.set_value(gk, "com", 4.37)
	scr._refresh()
	await tree.process_frame
	r.check(int(_up(scr, "com").get_meta("box")) == 4 and is_equal_approx(gk.attr("com"), 4.37), "4.37: the fifth box to buy, the value left as it is")
	_up(scr, "com").pressed.emit()
	await tree.process_frame
	r.check(is_equal_approx(gk.attr("com"), 5.37), "...and an upgrade is exactly +1 (5.37)")

# ------------------------------------------------------------------ the classes
# ------------------------------------------------------------------ saves
func _saves() -> void:
	var c := Career.new_game("BUCK", "A", "B", 71)
	var d := c.to_dict()
	var text := JSON.stringify(d)
	var back := Career.from_dict(JSON.parse_string(text))
	r.check(JSON.stringify(Recruiting.to_save(back.market)) == JSON.stringify(Recruiting.to_save(c.market)),
		"a saved market loads exactly as it was")
	r.check(JSON.stringify(back.to_dict()) == text, "loading changes nothing (no prospect made again)")
	# an older save: no development profile, last lock on the old scale
	var od: Dictionary = JSON.parse_string(text)
	var pd: Dictionary = od.teams[c.school].roster[0]
	pd.erase("dev")
	pd.stars_locked = snappedf(float(pd.attrs.values().reduce(func(x, v): return x + float(v), 0.0)) / 8.0, 0.0001)
	var old := Career.from_dict(JSON.parse_string(JSON.stringify(od)))
	var op: PoloPlayer = old.team().roster[0]
	r.check(is_equal_approx(op.stars_locked, op.stars), "an older save's last lock moves onto the star steps (no phantom 'stars moved')")
	r.check(old.credits == c.credits and old.team().roster.size() == c.team().roster.size(), "credits and rosters as they were")
	# before 2.0: no attributes, stars on the old halves -> converted at the same OVERALL
	var pre := c.team().roster[1].to_dict()
	pre.erase("attrs")
	pre.erase("attr_pot")
	pre.erase("stars_locked")
	pre.erase("dev")
	pre.stars = 3.5
	pre.pot_stars = 4.5
	var pp := PoloPlayer.from_dict(JSON.parse_string(JSON.stringify(pre)))
	r.check(absf(pp.rating10() - 7.0) < 1e-4 and absf(pp.potential10() - 9.0) < 1e-4 and is_equal_approx(pp.stars, 4.0) and is_equal_approx(pp.pot_stars, 5.0),
		"a pre-2.0 player: OVERALL 7.0 and POTENTIAL 9.0 kept, now 4 and 5 stars")

# ------------------------------------------------------------------ HOT form
func _hot_cold() -> void:
	var c := Career.new_game("SCCU", "A", "B", 81)
	var p: PoloPlayer = c.team().starters()[3]
	var looks := [p.attrs.duplicate(), p.attr_pot.duplicate(), p.stars, p.pot_stars, p.tokens, p.xp]
	p.heat = 2
	r.check(is_equal_approx(p.eff_stars(), p.stars + 1.0) and p.live("shoot") > p.shoot, "VERY HOT still lifts him a star in play")
	r.check([p.attrs, p.attr_pot, p.stars, p.pot_stars, p.tokens, p.xp] == looks, "...without touching his attributes, ceilings, stars, XP or tokens")
	r.check(c.team().live_ovr() > c.team().base_ovr(), "...and the team's LIVE rating feels it")

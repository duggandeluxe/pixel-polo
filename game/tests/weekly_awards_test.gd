extends RefCounted
## The Weekly Awards Evaluation & Exclusivity update (ConfAwards.pick_week): POTW first, then
## OPOTW / DPOTW / ROTW to distinct winners with no minimums, a keeper POTW only for an
## extraordinary week.
##   godot --headless --path game -- --test weekly_awards

var r
var next_id := 1

func run(runner) -> void:
	r = runner
	print("weekly awards")
	_rules()
	_keepers()
	_allocation()
	_no_sweeps()

func _p(pos: int, year := 2) -> PoloPlayer:
	var p := AttrBench.player({}, pos == PoloPlayer.Pos.GK, {}, pos)
	p.year = year
	p.id = next_id
	next_id += 1
	return p

func _e(p: PoloPlayer, line: Dictionary, team := "") -> Dictionary:
	var ln := line.duplicate()
	ln["gp"] = ln.get("gp", 1)
	return {"p": p, "team": team if team != "" else "T%d" % p.id, "line": ln}

func _who(w: Dictionary, cat: String) -> PoloPlayer:
	return w[cat].p if w.has(cat) else null

func _rules() -> void:
	var a := _p(PoloPlayer.Pos.DRIVER, 1)
	var b := _p(PoloPlayer.Pos.DRIVER, 1)
	var c := _p(PoloPlayer.Pos.WING)
	var k1 := _p(PoloPlayer.Pos.GK, 1)
	var k2 := _p(PoloPlayer.Pos.GK)
	var lines := [_e(a, {"g": 10, "a": 4}), _e(b, {"g": 7, "a": 3}), _e(c, {"g": 6, "a": 3}),
		_e(k1, {"sv": 9, "ga": 6}), _e(k2, {"sv": 3, "ga": 12})]
	var w := ConfAwards.pick_week(lines)
	r.check(_who(w, "potw") == a, "5/9: POTW the best overall week (freshman A)")
	r.check(_who(w, "opotw") != a and _who(w, "rotw") != a, "8/10: A off every other award")
	r.check(_who(w, "dpotw") == k1 and _who(w, "rotw") == b and _who(w, "opotw") == c,
		"11/13: all four, each near its best: DPOTW the best keeper (a freshman), ROTW the other freshman B, OPOTW C")
	var ids := {}
	for cat in w:
		ids[(w[cat].p as PoloPlayer).id] = true
	r.check(ids.size() == w.size(), "8: no player twice")
	# no minimums: a poor keeper week still wins DPOTW, a quiet freshman still ROTW
	var f := _p(PoloPlayer.Pos.WING, 1)
	var low := ConfAwards.pick_week([_e(a, {"g": 3}), _e(c, {"g": 1}), _e(k2, {"sv": 2, "ga": 9}), _e(f, {"to": 1})])
	r.check(_who(low, "dpotw") == k2 and _who(low, "rotw") == f, "14: no thresholds: 2 saves / 9 against is DPOTW, a freshman with a turnover is ROTW")
	r.check(not low.has("dpotw") or (low.dpotw.p as PoloPlayer).is_keeper(), "11: DPOTW only ever a keeper")
	# a keeper POTW can't be DPOTW: the other keeper is
	var big := _p(PoloPlayer.Pos.GK)
	var gw := ConfAwards.pick_week([_e(big, {"sv": 26, "ga": 2, "st": 2, "gp": 2}), _e(c, {"g": 3}), _e(k2, {"sv": 5, "ga": 8})])
	r.check(_who(gw, "potw") == big and _who(gw, "dpotw") == k2, "8/11: an extraordinary keeper is POTW; DPOTW goes to the other keeper")
	var solo := ConfAwards.pick_week([_e(big, {"sv": 26, "ga": 2, "st": 2, "gp": 2}), _e(c, {"g": 3})])
	r.check(_who(solo, "potw") == big and not solo.has("dpotw"), "13: the only keeper is POTW: DPOTW left empty, never a field player or a duplicate")
	# deterministic
	r.check(str(ConfAwards.pick_week(lines).keys()) == str(w.keys()) and _who(ConfAwards.pick_week(lines), "rotw") == _who(w, "rotw"), "16: the same week, the same four")

func _keepers() -> void:
	var striker := _p(PoloPlayer.Pos.DRIVER)
	var ok_gk := _p(PoloPlayer.Pos.GK)
	var w := ConfAwards.pick_week([_e(striker, {"g": 7, "a": 3}), _e(ok_gk, {"sv": 14, "ga": 7})])
	r.check(_who(w, "potw") == striker and _who(w, "dpotw") == ok_gk, "6: 14 saves / 7 against: DPOTW, not POTW over a typical best field week (7 G, 3 A)")
	var sv9 := _p(PoloPlayer.Pos.GK)
	r.check(ConfAwards.score(sv9, {"sv": 9, "ga": 8, "gp": 1}, "potw") < ConfAwards.score(striker, {"g": 4, "a": 2, "gp": 1}, "potw"), "6: 9 saves / 8 against never beats a solid attacking week")
	var wall := _p(PoloPlayer.Pos.GK)
	r.check(ConfAwards.score(wall, {"sv": 38, "ga": 9, "st": 4, "gp": 2}, "potw") > ConfAwards.score(striker, {"g": 7, "a": 3, "gp": 2}, "potw"), "6: 38 saves / 9 against / 4 steals over two games beats a good field week")

func _allocation() -> void:
	# the best OPOTW candidate is also the only freshman: OPOTW goes to the next attacker so ROTW can be given
	var star := _p(PoloPlayer.Pos.CENTER)
	var fr := _p(PoloPlayer.Pos.DRIVER, 1)
	var two := _p(PoloPlayer.Pos.WING)
	var gk := _p(PoloPlayer.Pos.GK)
	var w := ConfAwards.pick_week([_e(star, {"g": 12, "a": 5}), _e(fr, {"g": 6, "a": 2}), _e(two, {"g": 5, "a": 2}), _e(gk, {"sv": 6, "ga": 8})])
	r.check(w.size() == 4 and _who(w, "rotw") == fr and _who(w, "opotw") == two, "13: allocation gives all four (OPOTW to the next attacker, the only freshman ROTW)")

func _no_sweeps() -> void:
	# one school's four best weeks: it keeps two, the rest go to the next best from other schools
	var a := _p(PoloPlayer.Pos.CENTER)
	var b := _p(PoloPlayer.Pos.WING)
	var fr := _p(PoloPlayer.Pos.DRIVER, 1)
	var gk := _p(PoloPlayer.Pos.GK)
	var o_fr := _p(PoloPlayer.Pos.WING, 1)
	var o_gk := _p(PoloPlayer.Pos.GK)
	var o_att := _p(PoloPlayer.Pos.DRIVER)
	var lines := [_e(a, {"g": 9, "a": 4}, "H"), _e(b, {"g": 7, "a": 3}, "H"), _e(fr, {"g": 6, "a": 2}, "H"), _e(gk, {"sv": 12, "ga": 5}, "H"),
		_e(o_fr, {"g": 1}, "O"), _e(o_gk, {"sv": 4, "ga": 9}, "P"), _e(o_att, {"g": 2}, "Q")]
	var w := ConfAwards.pick_week(lines)
	var n := {}
	for cat in w:
		n[String(w[cat].team)] = int(n.get(String(w[cat].team), 0)) + 1
	r.check(w.size() == 4 and int(n.get("H", 0)) == ConfAwards.MAX_PER_TEAM, "no sweeps: all four given, one school wins only %d" % ConfAwards.MAX_PER_TEAM)
	r.check(_who(w, "potw") == a, "no sweeps: POTW still the best week")

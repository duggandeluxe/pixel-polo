extends RefCounted
## The Position Identity, Lefty & Roster Structure Update: C, 2MD, ATK, WG, UT and LFTY; the
## generation odds and leans; the seven places (PoloTeam.SLOTS) and who may play them; the
## right side's LFTY labels; position-aware lineups and roll-out subs; the roster screen; an
## older save; lefties on the right on attack and the left on defence; left-hand art.
##   godot --headless --path game -- --test positions
##   godot --path game -- --test positions_png <dir>

const ROSTER := preload("res://src/ui/screens/roster.gd")

var r
var _next := 100

func _frames(n: int) -> void:
	for _i in n:
		await r.get_tree().process_frame

## A made-up player: `pos`, every attribute `v`, a lefty or not.
func _man(pos: int, v: float, lefty := false) -> PoloPlayer:
	var p := AttrBench.player({"sho": v, "pas": v, "str": v, "dfn": v, "com": v, "lun": v, "blk": v, "leg": v}, pos == PoloPlayer.Pos.GK, {}, pos)
	p.lefty = lefty
	_next += 1
	p.id = _next
	p.number = _next % 90 + 1
	p.last = "P%d" % _next
	return p

## A team of `men` ([pos, v, lefty?] each).
func _team(men: Array) -> PoloTeam:
	var t := PoloTeam.new()
	t.id = "TST"
	t.name = "Test"
	for m in men:
		t.roster.append(_man(int(m[0]), float(m[1]), m.size() > 2 and bool(m[2])))
	return t

const GK := PoloPlayer.Pos.GK
const C := PoloPlayer.Pos.CENTER
const MD := PoloPlayer.Pos.DEFENDER
const ATK := PoloPlayer.Pos.DRIVER
const WG := PoloPlayer.Pos.WING
const UT := PoloPlayer.Pos.UTILITY

func run(runner) -> void:
	r = runner
	print("positions")
	Store.reset_for_tests()
	_labels()
	_generation()
	_eligibility()
	_lineups()
	_subs()
	_old_save()
	_match()
	_art()
	await _roster_screen()

# ------------------------------------------------------------------ names
func _labels() -> void:
	r.check(PoloPlayer.POS_SHORT == ["GK", "C", "ATK", "WG", "UT", "2MD"], "DEF is 2MD, DRV is ATK (%s)" % [PoloPlayer.POS_SHORT])
	r.check(not PoloPlayer.POS_LONG.has("Driver") and not PoloPlayer.POS_LONG.has("Center-D"), "...the long names too")
	var lefty := _man(ATK, 6, true)
	r.check(lefty.pos_text() == "LFTY" and _man(ATK, 6).pos_text() == "ATK" and _man(MD, 6).pos_text() == "2MD", "a lefty attacker shows as LFTY")
	var src := ""
	for f in ["src/ui/screens/roster.gd", "src/ui/screens/player.gd", "src/ui/screens/recruiting.gd", "src/ui/screens/scout.gd",
			"src/ui/screens/roster_cuts.gd", "src/ui/screens/coaching.gd", "src/match/hud.gd", "src/core/recruiting.gd", "src/core/offseason.gd"]:
		src += FileAccess.get_file_as_string("res://" + f)
	r.check(not src.contains("POS_SHORT[") and not src.contains("\"DRV\""), "every screen reads the position through pos_text (LFTY included)")

# ------------------------------------------------------------------ generation
func _generation() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var n := {}
	var field := 0
	var atk := 0
	var lefties := 0
	var stray := 0
	var sums := {}
	for i in 5000:
		var p := CollegeGen.make_prospect(rng, [1.0, 2.0, 3.0, 4.0][i % 4], "normal", {})
		if p.is_keeper():
			continue
		field += 1
		n[p.pos] = int(n.get(p.pos, 0)) + 1
		if p.pos == ATK:
			atk += 1
			if p.lefty:
				lefties += 1
		elif p.lefty:
			stray += 1
		var key: int = -1 if p.lefty else p.pos
		if not sums.has(key):
			sums[key] = {"sho": 0.0, "pas": 0.0, "str": 0.0, "dfn": 0.0, "n": 0}
		for k in ["sho", "pas", "str", "dfn"]:
			sums[key][k] += p.attr(k) - p.rating10()
		sums[key].n += 1
	var want := {C: 0.15, MD: 0.17, ATK: 0.30, WG: 0.28, UT: 0.10}
	var odds := true
	var got := []
	for pos in want:
		var share := float(n.get(pos, 0)) / field
		got.append("%s %.3f" % [PoloPlayer.POS_SHORT[pos], share])
		odds = odds and absf(share - float(want[pos])) < 0.025
	r.check(odds, "field odds: C 15%%, 2MD 17%%, ATK 30%%, WG 28%%, UT 10%% (%s)" % ", ".join(got))
	var ls := float(lefties) / maxf(1.0, atk)
	r.check(absf(ls - 0.08) < 0.025 and stray == 0, "8%% of attackers are lefties (%.3f), nobody else (%d)" % [ls, stray])
	# the leans: tendencies on average
	var top2 := func(key: int) -> Array:
		var d: Dictionary = sums[key]
		var ks := ["sho", "pas", "str", "dfn"]
		ks.sort_custom(func(a, b): return float(d[a]) > float(d[b]))
		var out := ks.slice(0, 2)
		out.sort()
		return out
	r.check(top2.call(C) == ["sho", "str"], "C leans Strength and Shooting (%s)" % [top2.call(C)])
	r.check(top2.call(MD) == ["dfn", "str"], "2MD leans Strength and Defense (%s)" % [top2.call(MD)])
	r.check(top2.call(ATK) == ["pas", "sho"] and top2.call(-1) == ["pas", "sho"], "ATK and LFTY lean Shooting and Passing")
	r.check(top2.call(WG) == ["pas", "sho"], "WG leans Passing and Shooting")
	var ut: Dictionary = sums[UT]
	var spread := 0.0
	for k in ["sho", "pas", "str", "dfn"]:
		spread = maxf(spread, absf(float(ut[k]) / int(ut.n)))
	r.check(spread < 0.35, "UT is balanced (largest average lean %.2f)" % spread)
	# whole leagues
	var c := Career.new_setup(77)
	var shaped := true
	var legal := true
	var made_lefty := 0
	for id in c.teams:
		var t: PoloTeam = c.teams[id]
		var seven := t.starters()
		legal = legal and PoloTeam.legal(seven)
		for p in t.roster:
			if p.is_lefty():
				made_lefty += 1
		var pos: Array = t.roster.slice(0, 7).map(func(p: PoloPlayer): return p.pos)
		pos.sort()
		var shape: Array = CollegeGen.ROSTER_POS.duplicate()
		shape.sort()
		shaped = shaped and pos == shape
	r.check(shaped, "every program's seven: GK, C, 2MD, ATK, ATK, WG, WG")
	r.check(legal, "every program starts a legal seven")
	r.check(made_lefty < c.teams.size(), "no team is made to have a lefty (%d lefties in %d teams)" % [made_lefty, c.teams.size()])

# ------------------------------------------------------------------ the places
func _eligibility() -> void:
	r.check(PoloTeam.LINEUP_SPOTS.slice(0, 7) == ["gk", "cf", "rw", "rf", "pt", "lf", "lw"], "the seven places in the match's order")
	var t := _team([[GK, 6], [C, 6], [MD, 6], [ATK, 6], [ATK, 6], [WG, 6], [WG, 6]])
	var names: Array = range(7).map(func(i): return t.slot_name(i))
	r.check(names == ["GK", "C", "WG", "ATK", "2MD", "ATK", "WG"], "no lefty: C | 2MD | ATK | ATK | WG | WG | GK (%s)" % [names])
	var lefty := _man(ATK, 5, true)
	t.roster.append(lefty)
	names = range(7).map(func(i): return t.slot_name(i))
	r.check(names == ["GK", "C", "WG/LFTY", "ATK/LFTY", "2MD", "ATK", "WG"], "a lefty on the roster (even on the bench): ATK/LFTY and WG/LFTY (%s)" % [names])
	t.roster.erase(lefty)
	r.check(t.slot_name(2) == "WG" and t.slot_name(3) == "ATK", "...back to ATK and WG when he's gone")
	var m := {"GK": _man(GK, 6), "C": _man(C, 6), "2MD": _man(MD, 6), "ATK": _man(ATK, 6), "WG": _man(WG, 6), "UT": _man(UT, 6), "LFTY": _man(ATK, 6, true)}
	# [place, who may play it]
	var table := [[0, ["GK"]], [1, ["C", "2MD"]], [4, ["2MD", "C"]], [5, ["ATK", "WG", "UT"]], [6, ["ATK", "WG", "UT"]],
		[3, ["ATK", "WG", "UT", "LFTY"]], [2, ["ATK", "WG", "UT", "LFTY"]], [7, m.keys()], [9, m.keys()]]
	var ok := true
	var wrong := []
	for row in table:
		for k in m:
			if PoloTeam.fits(m[k], int(row[0])) != (k in row[1]):
				ok = false
				wrong.append("%s at %d" % [k, int(row[0])])
	r.check(ok, "who may play where: GK only in goal; C, 2MD on the posts; ATK, WG, UT outside, a LFTY only on the right side's two; anybody on the bench %s" % [wrong])
	r.check(PoloTeam.fit_rank(m.C, 1) == 0 and PoloTeam.fit_rank(m["2MD"], 1) == 1 and PoloTeam.fit_rank(m["2MD"], 4) == 0 and PoloTeam.fit_rank(m.C, 4) == 1, "C prefers a centre, 2MD a 2MD")

# ------------------------------------------------------------------ lineups
func _lineups() -> void:
	# a better wing than the centre: the centre still plays C (position-aware, not the best seven)
	var t := _team([[GK, 6], [C, 4], [MD, 5], [ATK, 7], [ATK, 7], [WG, 7], [WG, 7], [WG, 8], [UT, 3]])
	var s := t.starters()
	r.check(s[1].pos == C and s[4].pos == MD and PoloTeam.legal(s), "the centre at C, the 2MD at 2MD, though wings are better")
	r.check(s.has(t.roster[7]) and not s.has(t.roster[8]), "the best perimeter men take the perimeter")
	# lefties on the right
	var tl := _team([[GK, 6], [C, 6], [MD, 6], [ATK, 7], [ATK, 6, true], [WG, 6], [WG, 6]])
	s = tl.starters()
	r.check(s[3].is_lefty() and PoloTeam.legal(s), "a lefty in ATK/LFTY (rf, spot 2): %s" % [s.map(func(p): return p.pos_text())])
	var t3 := _team([[GK, 6], [C, 6], [MD, 6], [ATK, 8, true], [ATK, 8, true], [ATK, 8, true], [WG, 6], [WG, 6]])
	s = t3.starters()
	r.check(s.filter(func(p): return p.is_lefty()).size() == 2 and s[2].is_lefty() and s[3].is_lefty() and PoloTeam.legal(s), "three lefties: two start, on the right side")
	# posts: two centres, the better at C
	var tc := _team([[GK, 6], [C, 5], [C, 7], [ATK, 6], [ATK, 6], [WG, 6], [WG, 6]])
	s = tc.starters()
	r.check(s[1] == tc.roster[2] and s[4] == tc.roster[1], "no 2MD: the better centre at C, the other at 2MD")
	# a lineup with a lefty in a plain place is made legal
	var tx := _team([[GK, 6], [C, 6], [MD, 6], [ATK, 6], [ATK, 6, true], [WG, 6], [WG, 6]])
	tx.lineup = [tx.roster[0].id, tx.roster[1].id, tx.roster[5].id, tx.roster[3].id, tx.roster[2].id, tx.roster[4].id, tx.roster[6].id, -1, -1, -1]
	tx.sync_lineup()
	var seven: Array = tx.lineup.slice(0, 7).map(func(pid): return tx.find_id(int(pid)))
	r.check(PoloTeam.legal(seven) and seven.has(tx.roster[4]) and seven.find(tx.roster[4]) in [2, 3], "a lineup with a lefty on the left is made legal (him on the right)")

# ------------------------------------------------------------------ third-exclusion subs
func _subs() -> void:
	var t := _team([[GK, 6], [C, 6], [MD, 6], [ATK, 6], [ATK, 6], [WG, 6], [WG, 6], [GK, 4], [WG, 5], [ATK, 5, true]])
	t.lineup = [t.roster[0].id, t.roster[1].id, t.roster[5].id, t.roster[3].id, t.roster[2].id, t.roster[4].id, t.roster[6].id, t.roster[7].id, t.roster[8].id, t.roster[9].id]
	t.sync_lineup()
	var lw: PoloPlayer = t.find_id(int(t.lineup[6]))
	lw.rolled = true
	var s := t.starters()
	r.check(s[6] == t.roster[8] and PoloTeam.legal(s), "a rolled WG: the bench wing, in his place")
	t.roster[8].rolled = true
	s = t.starters()
	r.check(PoloTeam.legal(s) and s.has(t.roster[9]) and s.find(t.roster[9]) in [2, 3] and s.size() == 7,
		"only a lefty left: the right side moves over and the lefty plays there (%s)" % [s.map(func(p): return p.pos_text())])
	# a 2MD with no post man left: an emergency, the best wrestler (no lefty)
	var e := _team([[GK, 6], [C, 6], [MD, 6], [ATK, 6], [ATK, 6], [WG, 6], [WG, 6], [GK, 4], [ATK, 8, true], [UT, 4], [WG, 4]])
	e.roster[9].attrs["str"] = 9.0
	e.roster[9].attrs["dfn"] = 9.0
	e.lineup = [e.roster[0].id, e.roster[1].id, e.roster[5].id, e.roster[3].id, e.roster[2].id, e.roster[4].id, e.roster[6].id, e.roster[8].id, e.roster[9].id, e.roster[10].id]
	e.sync_lineup()
	e.roster[2].rolled = true
	s = e.starters()
	r.check(s[4] == e.roster[9] and not s[4].is_lefty(), "a rolled 2MD, no post man left: the strongest, best defender comes in (not the lefty)")
	for p in e.roster:
		p.rolled = false
	# the match's own roll-out: MatchFlow finds the sub from starters()
	var c := Career.new_game("SJCU", "A", "B", 61)
	c.queue.clear()
	var f := MatchFlow.new(c.team(), c.teams["CULA"], 5, 2.0)
	var victim: PoloPlayer = c.team().starters()[5]
	f.state.pf[victim.id] = 2
	f._personal_foul(victim, 0)
	r.check(PoloTeam.legal(c.team().starters()) and not c.team().starters().has(victim), "in a game: three fouls, a legal seven without him")

# ------------------------------------------------------------------ an older save
func _old_save() -> void:
	var c := Career.new_game("LIUB", "A", "B", 33)
	c.queue.clear()
	var d: Dictionary = JSON.parse_string(JSON.stringify(c.to_dict()))
	var mine: Dictionary = d.teams[c.school]
	# the old ways: a lefty utility with the old trait, and an illegal lineup (a utility at C)
	var ut_i := -1
	for i in mine.roster.size():
		if int(mine.roster[i].pos) == UT or int(mine.roster[i].pos) == WG:
			ut_i = i
			break
	mine.roster[ut_i].pos = UT
	mine.roster[ut_i].lefty = true
	mine.roster[ut_i].trait_id = "lefty_sniper"
	var lefty_id := int(mine.roster[ut_i].id)
	var lu: Array = mine.lineup
	var at := lu.find(lefty_id)
	if at >= 0:
		lu[at] = lu[1]
	lu[1] = lefty_id
	var ids: Array = mine.roster.map(func(p): return int(p.id))
	var back := Career.from_dict(d)
	var t: PoloTeam = back.teams[c.school]
	var q := t.find_id(lefty_id)
	r.check(q.pos == ATK and q.lefty and q.pos_text() == "LFTY" and q.trait_id != "lefty_sniper", "an old lefty is a LFTY (an attacker), the old trait worked out again")
	r.check(t.roster.map(func(p): return p.id) == ids and t.roster.size() == ids.size(), "nobody lost, nobody added")
	var seven: Array = t.lineup.slice(0, 7).map(func(pid): return t.find_id(int(pid)))
	r.check(PoloTeam.legal(seven) and seven.find(q) in [-1, 2, 3], "the lineup is made legal")
	var lefty_n := 0
	for id in back.teams:
		for p in back.teams[id].roster:
			if p.lefty:
				lefty_n += 1
	var was_n := 0
	for id in d.teams:
		for p in d.teams[id].roster:
			if bool(p.get("lefty", false)) and int(p.pos) != GK:
				was_n += 1
	r.check(lefty_n == was_n, "nobody made a lefty on load (%d = %d)" % [lefty_n, was_n])
	var again := Career.from_dict(JSON.parse_string(JSON.stringify(back.to_dict())))
	r.check(JSON.stringify(again.teams[c.school].to_dict()) == JSON.stringify(t.to_dict()), "converted once: a second load changes nothing")

# ------------------------------------------------------------------ in the pool
func _match() -> void:
	var us := _team([[GK, 6], [C, 6], [MD, 6], [ATK, 6], [ATK, 6, true], [WG, 6], [WG, 6]])
	var them := _team([[GK, 6], [C, 6], [MD, 6], [ATK, 6], [ATK, 6, true], [WG, 6], [WG, 6]])
	them.id = "OPP"
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var p := Play.new(us, them, Play.Kind.HALF_COURT, rng)
	var a: Swimmer = p.attackers.filter(func(s): return s.player.is_lefty())[0]
	var d: Swimmer = p.defenders.filter(func(s): return s.player.is_lefty())[0]
	r.check(a.tag in ["1", "2"], "on attack a lefty plays the right side (spot %s)" % a.tag)
	r.check(d.dtag in ["1", "2"], "on defence he guards the right of their attack: his own left side of the goal (%s)" % d.dtag)
	r.check(PlaySetup.marking(them.starters())[0].pos != ATK or not PlaySetup.marking(them.starters())[0].is_lefty(), "never the centre's guard while there's anyone else")
	# the CPU's defence too (the same tags at either end), and every drop is by these tags
	var p2 := Play.new(them, us, Play.Kind.HALF_COURT, rng)
	r.check(p2.attackers.filter(func(s): return s.player.is_lefty())[0].tag in ["1", "2"] and p2.defenders.filter(func(s): return s.player.is_lefty())[0].dtag in ["1", "2"],
		"...at the other end the same")
	# left hand: the ball up in his left
	a.arm = 1.0
	var righty: Swimmer = p.attackers.filter(func(s): return not s.player.is_lefty() and s.tag != "C")[0]
	righty.arm = 1.0
	righty.facing = 1.0
	a.facing = 1.0
	r.check(Play.held_at(a).x < a.pos.x and Play.held_at(righty).x > righty.pos.x, "a lefty holds it up in his left hand (behind his head, where his art has it)")
	# no lefty bonus
	var src := FileAccess.get_file_as_string("res://src/core/traits.gd") + FileAccess.get_file_as_string("res://src/core/shot_model.gd")
	r.check(not src.contains(".lefty") and not src.contains("is_lefty") and not Traits.ALL.has("lefty_sniper"), "no lefty bonus anywhere in the shot or the traits")
	var l := _man(ATK, 9.9, true)
	var rr := _man(ATK, 9.9)
	r.check(Traits.best_for(l) == Traits.best_for(rr) and Traits.shot_mods(l, Vector2(25, 15), false) == Traits.shot_mods(rr, Vector2(25, 15), false), "...the same shot as a righty's")

# ------------------------------------------------------------------ the art
func _art() -> void:
	var drawn: Array = []
	var px := func(dx: int, dy: int, w: int, h: int, _c: Color) -> void: drawn.append([dx, dy, w, h])
	PoolArt.arm_px(px, true).call(4, -16, 2, 12, Color.WHITE)
	PoolArt.arm_px(px, false).call(4, -16, 2, 12, Color.WHITE)
	r.check(drawn == [[-6, -16, 2, 12], [4, -16, 2, 12]], "the left hand is the right mirrored about him")
	# a raised block: the hand drawn is the hand the collision is on
	var ok := true
	for facing in [1.0, -1.0]:
		for side in [1.0, -1.0]:
			for shooter in [Vector2(20, 8), Vector2(20, 13), Vector2(28, 4)]:
				var s := Swimmer.new(_man(MD, 6), Swimmer.Side.THEM)
				s.pos = Vector2(24, 10)
				s.facing = facing
				var m := Swimmer.new(_man(ATK, 6), Swimmer.Side.US)
				m.pos = shooter
				s.press_on = m
				s.press = DefenseFormation.Press.BLOCK
				s.block_side = side
				var z := DefenseFormation.arm_zone(s)
				var hand_y: float = (z.hand as Vector2).y - s.pos.y
				var right := signf(hand_y) == signf(facing)
				if absf(hand_y) > 0.01 and (PoolArt.block_hand(s) > 0.0) != right:
					ok = false
	r.check(ok, "a block's arm is drawn on the side its collision is (his right on the +y side facing +x)")
	var dv := Swimmer.new(_man(MD, 6), Swimmer.Side.THEM)
	dv.facing = -1.0
	dv.dive = 1.0
	r.check(PoolArt.dive_hand(dv) < 0.0, "reaching for a shot: the hand on that side")

# ------------------------------------------------------------------ the roster screen
func _roster_screen() -> void:
	var c := Career.new_game("LIUB", "A", "B", 91)
	c.queue.clear()
	c.hot_tip = true
	var t := c.team()
	# a lefty on the bench, a utility to put on the right side
	var bench_i := PoloTeam.STARTERS
	var lefty := t.find_id(int(t.lineup[bench_i]))
	if lefty.is_keeper():
		bench_i += 1
		lefty = t.find_id(int(t.lineup[bench_i]))
	lefty.pos = ATK
	lefty.lefty = true
	Game.career = c
	Game.goto("roster")
	await _frames(3)
	var scr = Game.current_screen
	r.check(t.slot_name(2) == "WG/LFTY" and t.slot_name(3) == "ATK/LFTY", "a lefty on the bench: the right side reads WG/LFTY and ATK/LFTY")
	r.check(scr.can_swap(bench_i, 2) or not PoloTeam.fits(t.find_id(int(t.lineup[2])), bench_i), "the lefty may go to WG/LFTY")
	r.check(not scr.can_swap(bench_i, 6) and not scr.can_swap(bench_i, 5), "...never to a plain WG or ATK")
	r.check(not scr.can_swap(bench_i, 1) and not scr.can_swap(bench_i, 4), "...nor the posts")
	var ut := _man(UT, 5)
	r.check(PoloTeam.fits(ut, 2) and ut.pos_text() == "UT", "a UT in WG/LFTY is still a UT")
	var card: Control = scr.find_child("Spot_rw", true, false)
	r.check(card != null and String(card.tooltip_text).contains("WG/LFTY"), "the place's name with the man: %s" % (card.tooltip_text if card != null else "-"))
	Game.goto("title")
	await _frames(1)
	Game.career = null

static func shots(runner, out: String) -> void:
	DirAccess.make_dir_recursive_absolute(out)
	Store.reset_for_tests()
	var c := Career.new_game("LIUB", "A", "B", 91)
	c.queue.clear()
	c.hot_tip = true
	var t := c.team()
	var lefty := t.find_id(int(t.lineup[2]))
	lefty.pos = PoloPlayer.Pos.DRIVER
	lefty.lefty = true
	Game.career = c
	Game.goto("roster")
	await runner.get_tree().create_timer(0.8).timeout
	await RenderingServer.frame_post_draw
	runner.get_viewport().get_texture().get_image().save_png(out.path_join("pos_roster.png"))
	print("  shot roster")
	Game.goto("player", {"id": lefty.id})
	await runner.get_tree().create_timer(0.6).timeout
	await RenderingServer.frame_post_draw
	runner.get_viewport().get_texture().get_image().save_png(out.path_join("pos_player.png"))
	print("  shot player")
	Game.career = null

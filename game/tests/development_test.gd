extends RefCounted
## Player development, XP, training and injuries (docs: "Complete Player Development, XP,
## Training & Injury Overhaul"): hidden levels, the XP curve and tokens (Development), the five
## box states (Deck.box_state), game XP from recorded stats, training XP by focus and intensity,
## injuries as temporary attribute penalties, Recovery, AI development, saves and migration, and
## that stars, the team overall, HOT form and the gameplay formulas didn't move. The numbered
## checks follow the spec's REQUIRED TESTING list.
##   godot --headless --path game -- --test development
##   godot --headless --path game -- --test dev_balance [seasons]   (the season simulation report)

var r   # the test runner

func run(runner) -> void:
	r = runner
	print("development")
	Store.reset_for_tests()
	_xp_and_levels()
	_game_xp()
	_boxes()
	_upgrades()
	_training()
	await _training_screen()
	_injuries()
	_red_boxes()
	_recovery()
	await _no_bandage()
	_ai()
	_saves()
	await _no_duplicates()
	_regression()

func _p(vals: Dictionary, keeper := false, pots := {}, pos := PoloPlayer.Pos.UTILITY) -> PoloPlayer:
	var p := AttrBench.player(vals, keeper, pots, pos)
	p.id = 1 + randi() % 100000
	Development.ensure(p)
	return p

func _field(v: float, pot: float = 10.0) -> PoloPlayer:
	return _p({"pas": v, "sho": v, "str": v, "dfn": v}, false, {"pas": pot, "sho": pot, "str": pot, "dfn": pot})

func _rng(seed_value: int = 7) -> RandomNumberGenerator:
	var g := RandomNumberGenerator.new()
	g.seed = seed_value
	return g

# ------------------------------------------------------------------ XP, hidden levels, tokens
func _xp_and_levels() -> void:
	# 3: stronger players start at higher hidden levels: MAX(1, FLOOR(average x 2))
	var levels := [0.0, 1.0, 3.0, 5.0, 5.5, 8.0, 10.0].map(func(v): return Development.initial_level(_field(v)))
	r.check(levels == [1, 2, 6, 10, 11, 16, 20], "3: hidden level = MAX(1, FLOOR(avg x 2)) (%s)" % [levels])
	var gk := _p({"com": 6, "lun": 7, "blk": 8, "leg": 7}, true)
	r.check(gk.xp_level == 14, "3: a keeper's from his four (avg 7 -> 14, got %d)" % gk.xp_level)
	# 4: XP required = ROUND(76 x 1.11 ^ level)
	# (Long-Term Player Development: CEIL(450 x 1.38^n), n levels into his development; the
	# Development Maturity rebalance's modifier on top: +15% at the start .. -15% from 8 levels in)
	var want := {0: 518, 1: 691, 2: 922, 4: 1633, 8: 5032, 10: 9582}
	var bad := []
	for lv in want:
		var v := Development.xp_required(lv)
		if v != int(want[lv]):
			bad.append([lv, v])
	r.check(bad.is_empty(), "4: XP curve CEIL(450 x 1.38^n x 1.15..0.85) (wrong: %s)" % [bad])
	r.check(Development.xp_required(10) > Development.xp_required(9) and Development.xp_required(0) >= 1, "4: rising, always a positive whole number")
	# 6: one level-up, exactly one token
	var p := _field(6.0)
	var lv0 := p.xp_level
	var need := Development.xp_needed(p)
	var got := Development.award_xp(p, need)
	r.check(got == 1 and p.tokens == 1 and p.xp_level == lv0 + 1 and p.xp == 0, "6: exactly the requirement: one token, one hidden level, XP back to 0")
	# 7: excess carries over
	var need2 := Development.xp_needed(p)
	Development.award_xp(p, need2 + 37)
	r.check(p.tokens == 2 and p.xp == 37, "7: the excess carries over (%d)" % p.xp)
	# 8: several level-ups from one award
	var q := _field(4.0)
	var l := q.xp_level
	var two := Development.xp_required(Development.level_index(q)) + Development.xp_required(Development.level_index(q) + 1) + 5
	r.check(Development.award_xp(q, two) == 2 and q.tokens == 2 and q.xp_level == l + 2 and q.xp == 5, "8: two levels from one award: two tokens, 5 XP left")
	var big := _field(4.0)
	Development.award_xp(big, 100000)
	r.check(big.tokens > 10 and big.xp >= 0 and big.xp < Development.xp_needed(big), "8: a huge award works through every level, XP below the next requirement")
	# 9: never negative
	var n := _field(5.0)
	n.xp = 10
	Development.award_xp(n, -50)
	r.check(n.xp == 10 and n.tokens == 0, "9: a negative award does nothing (XP %d)" % n.xp)
	r.check(Development.game_xp(_field(5.0), {"to": 5, "ex": 5}, false) == 0, "9: a game's XP never goes below 0")
	# the level only moves with XP: upgrades don't recalculate it
	var u := _field(5.0)
	u.tokens = 3
	var ul := u.xp_level
	Development.spend(u, "sho")
	Development.spend(u, "pas")
	Development.spend(u, "dfn")
	r.check(u.xp_level == ul and Development.initial_level(u) != ul, "the hidden level isn't recalculated by upgrades (%d, would be %d)" % [u.xp_level, Development.initial_level(u)])

# ------------------------------------------------------------------ game XP
func _game_xp() -> void:
	var f := _field(5.0)
	var k := _p({"com": 5, "lun": 5, "blk": 5, "leg": 5}, true)
	# 2: per recorded stat (XP Development Update 2.0 values; the base, before his class)
	f.year = 4
	k.year = 4
	r.check(Development.base_game_xp(f, {"g": 2, "a": 1, "st": 1, "bl": 1, "ed": 1}, true) == 8 + 8 + 40 + 15 + 14 + 14 + 10, "2: field: goals 20, assist 15, steal 14, block 14, drawn exclusion 10, +8 played, +8 win")
	r.check(Development.base_game_xp(f, {"pd": 1, "to": 1, "ex": 1}, false) == 8 + 18 - 4 - 4, "2: drawn penalty +18, turnover -4, exclusion -4")
	r.check(Development.base_game_xp(f, {"ga": 9}, false) == 8, "2: a field player's goals against cost him nothing")
	r.check(Development.base_game_xp(k, {"sv": 10, "ga": 8, "st": 1, "a": 1}, false) == 8 + 100 - 8 + 14 + 15, "2: keeper: saves 10, conceded -1, steal 14, assist 15")
	# 10: no cap any more
	r.check(Development.game_xp(f, {"g": 9, "a": 4}, true) == ((8 + 8 + 180 + 60) * Development.class_pct(f) + 50) / 100, "10: a big game pays all of it (no cap)")
	# a real game through Career.finish_my_game: everyone who played, from what was recorded
	var c := Career.new_game("GWU", "A", "B", 314)
	Game.career = c
	var t := c.team()
	for q in t.roster:
		q.xp = 0
		q.xp_level = 60   # (a requirement far away, so XP stays XP here)
	var seven := t.starters()
	var a: PoloPlayer = seven[1]
	var b: PoloPlayer = seven[2]
	var bench := t.roster.filter(func(q): return not seven.has(q))
	for q in [a, b]:
		# (room to grow: a fully developed man holds no XP, Development.reconcile)
		for key in q.key_ratings():
			Attributes.set_ceiling(q, key, 10.0)
	var box := {"score": [5, 3], "so": [], "won": true, "goals": [a, a, b], "assists": [b], "steals": [a], "blocks": [b],
		"excl_drawn": [a], "keeper": seven[0], "saves": 7, "played": seven, "them": {"lists": {}, "saves": 4}}
	var out := c.finish_my_game(box)
	var times := func(q: PoloPlayer, base: int) -> int: return (base * Development.class_pct(q) + 50) / 100
	r.check(a.xp == times.call(a, 8 + 8 + 40 + 14 + 10) and b.xp == times.call(b, 8 + 8 + 20 + 15 + 14), "2: a played game's XP from its recorded stats, x his class (%d, %d)" % [a.xp, b.xp])
	r.check(seven[0].xp == times.call(seven[0], 8 + 8 + 70 - 3), "2: the keeper: saves and goals against (%d)" % seven[0].xp)
	r.check(not bench.is_empty() and bench.all(func(q): return q.xp == 0), "an unused sub gets no participation XP")
	r.check(out.has("xp") and int(out.xp[a.id].xp) == a.xp, "the summary gets each player's XP")
	var g: Dictionary = out.game
	r.check(bool(g.get("xp", false)), "the game is marked as counted")
	var before := seven.map(func(q): return q.xp)
	var again := c._award_game_xp(g, {}, {})
	r.check(again.is_empty() and seven.map(func(q): return q.xp) == before, "44: the same game never awards XP twice")
	# the opponent's players got theirs from the same rules
	var opp: PoloTeam = c.teams[out.opp]
	r.check(opp.starters().all(func(q): return Development.is_maxed(q) or q.xp > 0 or q.tokens > 0 or q.xp_level > Development.initial_level(q)), "39: the AI side earned XP from the same game (all but the fully developed)")

# ------------------------------------------------------------------ the five box states
func _boxes() -> void:
	var g := "green"
	var h := "hollow"
	var x := "grey"
	r.check(Deck.box_states(6.0, 9.0) == [g, g, g, g, g, g, h, h, h, x], "11/13/14: owned light green, future hollow cyan, past potential grey")
	r.check(not Deck.box_states(6.0, 9.0).has("buy"), "12: no token, no filled cyan")
	r.check(Deck.box_states(6.0, 9.0, 0.0, 1) == [g, g, g, g, g, g, "buy", h, h, x], "12: a token: the next box filled cyan")
	var three := Deck.box_states(6.0, 9.0, 0.0, 3)
	r.check(three.count("buy") == 1 and three[6] == "buy" and three[7] == h, "16: three tokens still light only the next box in the row")
	r.check(not Deck.box_states(9.0, 9.0, 0.0, 2).has("buy"), "17: at potential nothing to buy, whatever the tokens")
	r.check(Deck.BOX_PERM != Deck.BOX_FILL and Deck.BOX_PERM != Deck.BOX_OPEN_EDGE and Deck.BOX_GREY != Deck.BOX_OPEN, "11: light green is not the cyan, grey not hollow")

# ------------------------------------------------------------------ spending tokens
func _upgrades() -> void:
	var c := Career.new_game("GWU", "A", "B", 101)
	var p: PoloPlayer = c.team().starters()[3]
	Attributes.set_ceiling(p, "sho", 10.0)
	Attributes.set_value(p, "sho", 5.0)
	# 1: no coins
	c.credits = 5000
	var w := c.wallet()
	p.tokens = 0
	r.check(not c.boost(p, "sho") and is_equal_approx(p.attr("sho"), 5.0) and c.wallet() == w, "1: credits can't buy an attribute point")
	p.tokens = 1
	r.check(c.boost(p, "sho") and is_equal_approx(p.attr("sho"), 6.0) and p.tokens == 0 and c.wallet() == w, "1/15: one token, exactly one point, no credits")
	r.check(not c.boost(p, "sho") and p.tokens == 0, "15: no negative tokens, no second point")
	# 17: never past potential; the token is kept
	Attributes.set_ceiling(p, "pas", p.attr("pas"))
	p.tokens = 2
	r.check(not Development.spend(p, "pas") and p.tokens == 2, "17: at its ceiling: refused, the token kept")
	var full := _field(7.0, 7.0)
	full.tokens = 3
	full.xp = 40
	Development.reconcile(full)
	r.check(not Development.has_room(full) and Development.ai_spend(full) == 0 and full.tokens == 0 and full.xp == 0, "no room anywhere: unusable tokens and XP are dropped")
	# stars follow the permanent attribute; the team overall with them
	var o0 := c.team().team_overall(false)
	var st: PoloPlayer = c.team().starters()[2]
	for k2 in st.key_ratings():
		Attributes.set_ceiling(st, k2, 10.0)
	st.tokens = 8
	var s0 := st.stars
	for i in 8:
		Development.spend(st, st.key_ratings()[i % 4])
	r.check(st.stars > s0 and c.team().team_overall(false) > o0, "upgrades move stars (%.1f -> %.1f) and the team overall" % [s0, st.stars])

# ------------------------------------------------------------------ training
func _training() -> void:
	var f := _field(5.0)
	# 18: balanced
	r.check([1, 2, 3].map(func(i): return Development.training_xp(f, "balanced", i)) == [9, 12, 18], "18/21: balanced 12 x 0.75 / 1 / 1.5 = 9 / 12 / 18")
	# 19/21: specialised, the spec's Shooting 4
	var s4 := _p({"pas": 5, "sho": 4, "str": 5, "dfn": 5})
	r.check([1, 2, 3].map(func(i): return Development.training_xp(s4, "shooting", i)) == [15, 20, 30], "19/21: Shooting 4: 15 / 20 / 30")
	var table := [[0, 28], [2, 24], [4, 20], [5, 18], [6, 16], [8, 12], [10, 8]]
	var wrong := []
	for row in table:
		var q := _p({"pas": 5, "sho": float(row[0]), "str": 5, "dfn": 5})
		if Development.training_base(q, "shooting") != int(row[1]):
			wrong.append(row)
	r.check(wrong.is_empty(), "19: 8 + (10 - attribute) x 2 for every row of the table (wrong: %s)" % [wrong])
	var weak := _p({"pas": 3, "sho": 5, "str": 5, "dfn": 5})
	var strong := _p({"pas": 9, "sho": 5, "str": 5, "dfn": 5})
	r.check(Development.training_xp(weak, "passing", 2) > Development.training_xp(strong, "passing", 2), "19: weaker Passing earns more from Passing training")
	r.check(Development.training_xp(_p({"pas": 5, "sho": 5, "str": 5, "dfn": 3}), "swimming", 2) == 22 and Development.training_xp(_p({"pas": 5, "sho": 5, "str": 3, "dfn": 5}), "strength", 2) == 22,
		"19: Swimming works field Defense, Strength works Strength")
	# specialised training never touches attributes
	var before := s4.attrs.duplicate()
	var t := PoloTeam.new()
	t.roster = [s4]
	Development.train_team(t, "shooting", 3, _rng(), 1)
	r.check(s4.attrs == before, "training never changes an attribute directly")
	# 20: keepers
	var gk := _p({"com": 2, "lun": 4, "blk": 6, "leg": 8}, true)
	var ks := ["passing", "swimming", "defense", "strength", "shooting"].map(func(fo): return Development.training_base(gk, fo))
	r.check(ks == [24, 20, 16, 12, Development.GOALKEEPER_SHOOTING_TRAINING_XP], "20: keeper: Passing->Communication, Swimming->Lunge, Defense->Blocking, Strength->Leg, Shooting 5 (%s)" % [ks])
	r.check(Development.training_xp(gk, "recovery", 3) == 0, "21: Recovery gives no XP at any intensity")
	# 22: once per cycle
	var c := Career.new_game("STAM", "A", "B", 55)
	var p: PoloPlayer = c.team().starters()[1]
	var x0 := p.xp + p.tokens * 1000
	var rep := c.train_week()
	var x1 := p.xp + p.tokens * 1000
	var rep2 := c.train_week()
	r.check(not rep.is_empty() and x1 != x0 and rep2.is_empty() and p.xp + p.tokens * 1000 == x1, "22: a week's training happens once, a second call does nothing")
	# 45: a reload doesn't train the week again
	var back := Career.from_dict(JSON.parse_string(JSON.stringify(c.to_dict())))
	var bp: PoloPlayer = back.team().find_id(p.id)
	var bx := bp.xp
	r.check(back.train_week().is_empty() and bp.xp == bx, "45: reloading a save doesn't repeat the week's training")
	# injury risk by intensity (a large sample, fixed seed)
	var rates := []
	for inten in [1, 2, 3]:
		var hurt := 0
		var g := _rng(900 + inten)
		var n := 6000
		var team := PoloTeam.new()
		for i in n:
			team.roster.append(_field(5.0))
		hurt = (Development.train_team(team, "balanced", inten, g, 1).hurt as Array).size()
		rates.append(float(hurt) / n)
	r.check(absf(rates[0] - 0.01) < 0.005 and absf(rates[1] - 0.03) < 0.008 and absf(rates[2] - 0.08) < 0.012,
		"21: injury risk 1%% / 3%% / 8%% a week (%.3f, %.3f, %.3f)" % rates)

func _training_screen() -> void:
	var tree: SceneTree = r.get_tree()
	var c := Career.new_game("HURST", "A", "B", 66)
	Game.career = c
	var look := func() -> Array: return c.team().roster.map(func(q): return [q.xp, q.tokens, q.inj_type])
	var before: Array = look.call()
	for i in 4:
		Game.goto("training")
		await tree.process_frame
		var scr = Game.current_screen
		scr._set_focus(["shooting", "defense", "recovery", "balanced"][i])
		scr._set_intensity(3)
	r.check(look.call() == before, "23: opening Training and changing the plan repeatedly gives no XP and rolls no injuries")
	c.training.focus = "recovery"
	Game.goto("training")
	await tree.process_frame
	var hard: Button = Game.current_screen.find_child("Intensity_HARD", true, false)
	r.check(hard != null and hard.disabled, "21: Recovery: the intensity buttons are inactive")
	Game.goto("title")
	await tree.process_frame

# ------------------------------------------------------------------ injuries
func _injuries() -> void:
	var p := _field(6.0)
	var keep := p.attrs.duplicate()
	var s0 := p.stars
	Development.injure(p, _rng(), "minor", "shoulder")
	r.check(Development.penalties(p) == {"sho": 1}, "24: minor shoulder: Shooting -1, Passing 0")
	Development.heal(p)
	Development.injure(p, _rng(), "moderate", "shoulder")
	r.check(Development.penalties(p) == {"sho": 2, "pas": 1} and is_equal_approx(Development.eff_value(p, "str"), 6.0) and is_equal_approx(Development.eff_value(p, "dfn"), 6.0),
		"24: moderate shoulder: Shooting -2, Passing -1, nothing else")
	# 29: never permanent
	r.check(p.attrs == keep and is_equal_approx(p.stars, s0), "29: an injury changes no permanent attribute or star")
	# 30: no stacking
	r.check(not Development.injure(p, _rng(), "minor", "hip") and p.inj_type == "shoulder" and p.inj_sev == "moderate", "30: a second injury doesn't stack or replace the first")
	Development.heal(p)
	Development.injure(p, _rng(), "moderate", "hip")
	r.check(Development.penalties(p) == {"str": 2}, "25: hip: Strength only")
	Development.heal(p)
	Development.injure(p, _rng(), "minor", "head")
	r.check(Development.penalties(p) == {"dfn": 1}, "26: field head: Defense only")
	Development.heal(p)
	var gk := _p({"com": 8, "lun": 8, "blk": 8, "leg": 8}, true)
	Development.injure(gk, _rng(), "moderate", "shoulder")
	r.check(gk.inj_type == "head" and Development.penalties(gk) == {"com": 2, "lun": 2, "blk": 2, "leg": 2}, "27: a keeper's injury is always head, all four -2")
	var fit := _p({"com": 8, "lun": 8, "blk": 8, "leg": 8}, true)
	r.check(is_equal_approx(Attributes.lunge_mult(gk), Attributes.lunge_mult(_p({"com": 6, "lun": 6, "blk": 6, "leg": 6}, true))) and Attributes.lunge_mult(gk) > Attributes.lunge_mult(fit)
		and Attributes.dive_window(gk) < Attributes.dive_window(fit) and gk.keeping < fit.keeping and is_equal_approx(gk.stars, fit.stars),
		"27: ...his dive plays at the lowered values, his stars don't move")
	# 31: never below zero
	var low := _field(1.0)
	Development.injure(low, _rng(), "moderate", "hip")
	r.check(Development.eff_value(low, "str") == 0.0 and Attributes.play_value(low, "str") == 0.0, "31: effective attributes stop at 0")
	# odds: type 40/35/25, severity 75/25 (fixed seed, a big sample)
	var g := _rng(4242)
	var types := {"shoulder": 0, "hip": 0, "head": 0}
	var mod := 0
	var n := 8000
	for i in n:
		var q := _field(5.0)
		Development.injure(q, g)
		types[q.inj_type] += 1
		mod += 1 if q.inj_sev == "moderate" else 0
	r.check(absf(types.shoulder / float(n) - 0.40) < 0.02 and absf(types.hip / float(n) - 0.35) < 0.02 and absf(types.head / float(n) - 0.25) < 0.02,
		"18 (odds): shoulder %.2f, hip %.2f, head %.2f" % [types.shoulder / float(n), types.hip / float(n), types.head / float(n)])
	r.check(absf(mod / float(n) - 0.25) < 0.02, "18 (odds): moderate %.2f of injuries" % (mod / float(n)))
	# 28: injured players keep playing
	var c := Career.new_game("CULA", "A", "B", 12)
	var t := c.team()
	var seven := t.starters()
	for q in seven:
		Development.injure(q, g, "moderate")
	r.check(t.starters() == seven and seven.all(func(q): return q.is_available()), "28: seven injured starters all still start")
	# the team overall and HOT form never see an injury
	for q in seven:
		Development.heal(q)
	var ovr := t.team_overall(true)
	var heat_p: PoloPlayer = seven[2]
	heat_p.heat = 2
	var eff := heat_p.eff_stars()
	for q in seven:
		Development.injure(q, g, "moderate")
	r.check(is_equal_approx(heat_p.eff_stars(), eff) and is_equal_approx(t.team_overall(true), ovr + PlayerForm.red_stars(heat_p.form_state()) * 13.0 / 7.0),
		"48: HOT stars untouched by an injury, and the live overall still counts them")
	heat_p.heat = 0
	for q in seven:
		Development.heal(q)
	var o2 := t.team_overall(false)
	for q in seven:
		Development.injure(q, g, "moderate")
	r.check(is_equal_approx(t.team_overall(false), o2), "47: the team overall doesn't move with injuries (%.2f)" % o2)
	for q in seven:
		Development.heal(q)

# ------------------------------------------------------------------ red boxes
func _red_boxes() -> void:
	var g := "green"
	var red := "red"
	var h := "hollow"
	var x := "grey"
	r.check(Deck.box_states(6.0, 9.0, 1.0) == [g, g, g, g, g, red, h, h, h, x], "32/33: minor -1 on 6 of 9: one red box, the rightmost owned")
	r.check(Deck.box_states(6.0, 9.0, 2.0) == [g, g, g, g, red, red, h, h, h, x], "34: moderate -2: two red boxes")
	r.check(Deck.box_states(8.0, 9.0, 2.0) == [g, g, g, g, g, g, red, red, h, x], "the keeper example: Blocking 8 of 9, -2")
	r.check(Deck.box_states(1.0, 9.0, 2.0)[0] == red and Deck.box_states(1.0, 9.0, 2.0).count(red) == 1, "a penalty bigger than the attribute: only his owned boxes go red")
	# 35/36: the spec's example, through a real upgrade
	var p := _p({"pas": 6, "sho": 6, "str": 6, "dfn": 6}, false, {"pas": 9, "sho": 9, "str": 9, "dfn": 9})
	Development.injure(p, _rng(), "moderate", "shoulder")
	p.tokens = 1
	var sb := func() -> Array: return Deck.box_states(p.attr("sho"), Attributes.ceiling(p, "sho"), Development.penalty(p, "sho"), p.tokens)
	r.check(sb.call() == [g, g, g, g, red, red, "buy", h, h, x], "35: before: G G G G R R CYAN H H GREY (%s)" % [sb.call()])
	r.check(Development.spend(p, "sho"), "...one token on Shooting")
	r.check(sb.call() == [g, g, g, g, g, red, red, h, h, x], "35: after: G G G G G R R H H GREY (%s)" % [sb.call()])
	r.check(Development.penalty(p, "sho") == 2 and is_equal_approx(Development.eff_value(p, "sho"), 5.0), "36: the penalty stays -2; effective Shooting 4 -> 5")

func _recovery() -> void:
	var t := PoloTeam.new()
	var a := _field(6.0)
	var b := _p({"com": 6, "lun": 6, "blk": 6, "leg": 6}, true)
	var c2 := _field(6.0)
	Development.injure(a, _rng(), "moderate", "hip")
	Development.injure(b, _rng(), "minor")
	c2.tokens = 1
	t.roster = [a, b, c2]
	var xps := t.roster.map(func(q): return q.xp)
	var rep := Development.train_team(t, "recovery", 3, _rng(), 1)
	r.check(not a.is_injured() and not b.is_injured() and (rep.healed as Array).size() == 2, "37: Recovery heals every injury, keepers too")
	r.check(t.roster.map(func(q): return q.xp) == xps and (rep.hurt as Array).is_empty(), "37: ...no XP, no new injuries")
	r.check(Deck.box_states(a.attr("str"), Attributes.ceiling(a, "str"), Development.penalty(a, "str")).count("red") == 0, "37: the red boxes are green again")
	r.check(Deck.box_states(c2.attr("sho"), Attributes.ceiling(c2, "sho"), 0, c2.tokens).has("buy"), "37: a token's cyan box is still there")

func _no_bandage() -> void:
	# 38: no red bandage / medical cross, no INJ tag, no weeks out
	var player_src := FileAccess.get_file_as_string("res://src/ui/screens/player.gd")
	var roster_src := FileAccess.get_file_as_string("res://src/ui/screens/roster.gd")
	r.check(not player_src.contains("_injury_banner") and not player_src.contains("INJURED: OUT") and not player_src.contains("RUSH RECOVERY"),
		"38: the injury banner with its cross, and rush recovery, are gone")
	r.check(not roster_src.contains("\"INJ\""), "38: the roster card's INJ tag is gone")
	# 5: the hidden level never reaches a screen
	var leaks := []
	var stack := ["res://src/ui"]
	while not stack.is_empty():
		var dir: String = stack.pop_back()
		for sub in DirAccess.get_directories_at(dir):
			stack.append(dir.path_join(sub))
		for f in DirAccess.get_files_at(dir):
			if f.ends_with(".gd"):
				var src := FileAccess.get_file_as_string(dir.path_join(f))
				# (POSTGAME PLAYER DEVELOPMENT says LEVEL UP! for each token a game paid, as asked
				# for; it never reads the level itself: only the token counts either side of it)
				var says_level := src.to_upper().contains("LEVEL UP") and f != "player_development.gd"
				if src.contains("xp_level") or says_level or src.contains("HIDDEN LEVEL"):
					leaks.append(f)
	r.check(leaks.is_empty(), "5: no screen reads or shows the hidden level (%s)" % [leaks])
	var tree: SceneTree = r.get_tree()
	var c := Career.new_game("GWU", "A", "B", 8)
	Game.career = c
	var p: PoloPlayer = c.team().starters()[1]
	p.xp = 85
	p.tokens = 1
	Game.goto("player", {"id": p.id})
	await tree.process_frame
	var line: Control = Game.current_screen.find_child("XpLine", true, false)
	var txt := String(line.get_meta("text")) if line else ""
	r.check(txt == "XP TO NEXT LEVEL: %d  UPGRADES AVAILABLE: 1" % (Development.xp_needed(p) - 85), "6: the profile shows XP to go and upgrades available (%s)" % txt)
	r.check(not txt.contains("LV") and not txt.contains("LEVEL %d" % p.xp_level), "5: ...never his level number")
	r.check(Game.current_screen.find_child("UpgradeNote", true, false) == null, "6: no NEW ATTRIBUTE UPGRADE AVAILABLE! line (UPGRADES AVAILABLE flashes instead)")
	Game.goto("title")
	await tree.process_frame

# ------------------------------------------------------------------ AI
func _ai() -> void:
	var c := Career.new_game("SCCU", "A", "B", 2024)
	Game.career = c
	var start := {}
	for id in c.teams:
		for q in (c.teams[id] as PoloTeam).roster:
			start[q.id] = q.attrs.duplicate()
	for w in 6:
		while c.has_game():
			c.sim_my_game()
		c.end_week()
		c.queue.clear()
	var earned := 0
	var grew := 0
	var over := 0
	var players := 0
	for id in c.teams:
		if id == c.school:
			continue
		for q in (c.teams[id] as PoloTeam).roster:
			players += 1
			if q.xp_level > Development.initial_level(q) or q.xp > 0:
				earned += 1
			elif Development.is_maxed(q) and start.has(q.id) and q.key_ratings().all(func(k): return Attributes.room(q, k) < Attributes.PRECISION):
				players -= 1   # (fully developed: XP 2.0 gives him none)
			if start.has(q.id) and q.attrs != start[q.id]:
				grew += 1
			for k in q.key_ratings():
				if q.attr(k) > Attributes.ceiling(q, k) + 1e-6 or q.attr(k) > float(q.attr_pot.get(k, 10.0)) + 1e-6:
					over += 1
	r.check(earned > players * 0.9, "39: AI players earn XP (%d of %d)" % [earned, players])
	r.check(grew > players * 0.3, "39: ...and spend tokens on attributes (%d of %d grew)" % [grew, players])
	r.check(over == 0, "40: no AI attribute past its ceiling")
	var ctr := _p({"pas": 5, "sho": 5, "str": 5, "dfn": 5}, false, {"pas": 9, "sho": 9, "str": 9, "dfn": 9}, PoloPlayer.Pos.CENTER)
	var dfd := _p({"pas": 5, "sho": 5, "str": 5, "dfn": 5}, false, {"pas": 9, "sho": 9, "str": 9, "dfn": 9}, PoloPlayer.Pos.DEFENDER)
	r.check(Development.ai_choice(ctr) == "str" and Development.ai_choice(dfd) == "dfn", "AI picks by role: a centre Strength, a centre-D Defense")
	# 41: difficulty changes nothing in development
	var sig := []
	for mode in ["EASY", "HARD"]:
		var d := Career.new_game("SCCU", "A", "B", 77)
		d.difficulty = mode
		d.dyn_ai = 0.0 if mode == "EASY" else 1.0
		Game.career = d
		for w in 3:
			while d.has_game():
				d.sim_my_game()
			d.end_week()
			d.queue.clear()
		var s := 0
		for id in d.teams:
			for q in (d.teams[id] as PoloTeam).roster:
				s += q.xp + q.xp_level * 1000 + q.tokens * 7
		sig.append(s)
	r.check(sig[0] == sig[1], "41: the same league develops identically on EASY and HARD (%s)" % [sig])

# ------------------------------------------------------------------ saves
func _saves() -> void:
	var c := Career.new_game("STAM", "A", "B", 111)
	var p: PoloPlayer = c.team().starters()[2]
	for k in p.key_ratings():
		Attributes.set_ceiling(p, k, 10.0)   # (room to grow: one token spent never finishes him)
	p.xp = 77
	p.tokens = 2
	p.xp_level = 13
	Development.injure(p, _rng(), "moderate", "shoulder")
	Attributes.set_ceiling(p, "dfn", 10.0)
	Development.spend(p, "dfn")
	var back := Career.from_dict(JSON.parse_string(JSON.stringify(c.to_dict())))
	var q: PoloPlayer = back.team().find_id(p.id)
	r.check(q.xp == 77 and q.tokens == 1 and q.xp_level == 13 and q.inj_type == "shoulder" and q.inj_sev == "moderate",
		"43: XP, tokens, the hidden level and the injury survive a save")
	r.check(q.attrs == p.attrs and q.attr_pot == p.attr_pot and is_equal_approx(q.stars, p.stars) and q.shoot == p.shoot, "43: permanent upgrades, ceilings, stars and the injured ratings too")
	var d := p.to_dict()
	r.check((d.development as Dictionary).has("hidden_level") and not d.has("injury") and not d.has("boosts"), "saved as one development entry, no duplicate attributes")
	r.check(not JSON.stringify(d).contains("red"), "no red-box positions are saved")
	# 42: an older save: no development entry, weeks-out injuries, coin boosts
	var old := p.to_dict()
	old.erase("development")
	old["injury"] = 3
	old["boosts"] = 4
	old["prog"] = {"shoot": 0.5}
	var m := PoloPlayer.from_dict(JSON.parse_string(JSON.stringify(old)))
	r.check(m.xp_level == Development.initial_level(m) and m.xp == 0 and m.tokens == 0, "42: an older player starts at his attributes' level, no XP, no tokens")
	r.check(m.inj_type != "" and m.inj_sev == "moderate" and m.attrs == p.attrs and m.attr_pot == p.attr_pot, "42: his 3-week injury becomes a moderate penalty; attributes and ceilings kept")
	var m2 := PoloPlayer.from_dict(JSON.parse_string(JSON.stringify(old)))
	r.check(m2.inj_type == m.inj_type, "42: ...the same one every load")
	m.tokens = 1
	Attributes.set_ceiling(m, "sho", 10.0)
	var lv := m.xp_level
	Development.spend(m, "sho")
	var m3 := PoloPlayer.from_dict(JSON.parse_string(JSON.stringify(m.to_dict())))
	r.check(m3.xp_level == lv, "42: the level isn't reset or recalculated on later loads")

# ------------------------------------------------------------------ no duplicate awards
func _no_duplicates() -> void:
	var tree: SceneTree = r.get_tree()
	var c := Career.new_game("GWU", "A", "B", 909)
	Game.career = c
	c.last_summary = c.sim_my_game()
	var look := func() -> Array: return c.team().roster.map(func(q): return [q.xp, q.tokens, q.xp_level])
	var before: Array = look.call()
	for i in 3:
		Game.goto("game_summary")
		await tree.process_frame
	r.check(look.call() == before, "44: reopening the results screen awards nothing")
	var back := Career.from_dict(JSON.parse_string(JSON.stringify(c.to_dict())))
	var g: Dictionary = back.my_game() if back.has_game() else {}
	var played := 0
	for gm in back.cur().games:
		if gm.r != null:
			played += 1
			r.check(bool(gm.get("xp", false)), "44: a finished game is saved as counted")
			break
	var b2 := back.team().roster.map(func(q): return [q.xp, q.tokens, q.xp_level])
	back.catch_up()
	r.check(back.team().roster.map(func(q): return [q.xp, q.tokens, q.xp_level]) == b2 and played > 0 and g.is_empty() == g.is_empty(), "44: loading a completed game awards nothing")
	Game.goto("title")
	await tree.process_frame

# ------------------------------------------------------------------ regression
func _regression() -> void:
	# 46: the star steps
	var table := [[0.99, 0.5], [1.0, 1.0], [5.0, 3.0], [6.0, 3.5], [7.0, 4.0], [7.49, 4.0], [7.5, 4.5], [8.0, 5.0]]
	r.check(table.all(func(row): return is_equal_approx(Attributes.stars_of(float(row[0])), float(row[1]))), "46: the star steps are unchanged")
	# 47: 34.5 + 13 x average starter stars (HOT stars added), from the seven only
	var c := Career.new_game("LIUB", "A", "B", 3)
	var t := c.team()
	var total := 0.0
	for q in t.starters():
		total += q.stars
	r.check(is_equal_approx(t.team_overall(false), 34.5 + 13.0 * total / 7.0), "47: team overall = 34.5 + 13 x the starters' average stars")
	# 48: HOT form
	var p: PoloPlayer = t.starters()[3]
	p.heat = 2
	r.check(is_equal_approx(p.eff_stars(), p.stars + 1.0) and is_equal_approx(t.team_overall(true), 34.5 + 13.0 * (total + PlayerForm.red_stars(p.form_state())) / 7.0),
		"48: HEAT UP unchanged: VERY HOT adds its stars on top")
	p.heat = 0
	# 49/50: the gameplay formulas read the same values for a healthy player, the lowered ones injured
	var h := _p({"pas": 7, "sho": 8, "str": 6, "dfn": 5})
	r.check(Attributes.play_value(h, "sho") == 8.0 and is_equal_approx(Attributes.release_mult(h), 1.0 - 3.0 * Attributes.RELEASE_PER_POINT), "50: a healthy shooter's release as before")
	var sh0 := h.shoot
	Development.injure(h, _rng(), "moderate", "shoulder")
	r.check(Attributes.play_value(h, "sho") == 6.0 and is_equal_approx(Attributes.release_mult(h), 1.0 - 1.0 * Attributes.RELEASE_PER_POINT) and h.shoot < sh0,
		"50: injured: the release and the 0-100 shooting read Shooting 6")
	Development.heal(h)
	r.check(h.shoot == sh0, "50: healed: back exactly")
	var k := _p({"com": 5, "lun": 5, "blk": 5, "leg": 5}, true)
	r.check(is_equal_approx(Attributes.lunge_mult(k), 1.0) and is_equal_approx(Attributes.dive_window(k), Attributes.WINDOW_AT_5), "49: an all-5 keeper's dive timing unchanged")

# ------------------------------------------------------------------ season simulation (report)
## Plays whole careers (every game simulated, your program on BALANCED / NORMAL) and reports what
## development looks like over each 16-game season: XP per game and per training week, tokens,
## attribute growth and star moves by player type, injuries and recoveries, AI growth.
static func balance(runner, seasons: int = 1) -> void:
	print("development balance: %d season(s)" % seasons)
	for plan in [["balanced", 2], ["shooting", 3], ["balanced", 1]]:
		var c := Career.new_game("STAM", "A", "B", 4040)
		Game.career = c
		c.training = {"focus": plan[0], "intensity": plan[1]}
		var start := {}
		for id in c.teams:
			for q in (c.teams[id] as PoloTeam).roster:
				start[q.id] = {"o": q.rating10(), "st": q.stars, "lv": q.xp_level, "room": (q.potential10() - q.rating10()) * 4.0,
					"type": _type(q, c.teams[id].starters().has(q)), "mine": id == c.school}
		var hurt_weeks := 0
		var injuries := 0
		var recoveries := 0
		var game_xp := 0
		var game_n := 0
		var train_xp := 0
		var train_n := 0
		var weeks := 0
		var done := 0
		while done < seasons:
			if c.in_offseason():
				c.end_week()
				c.queue.clear()
				continue
			while c.has_game():
				var res := c.sim_my_game()
				for id in res.get("xp", {}):
					game_xp += int(res.xp[id].xp)
					game_n += 1
			var before := {}
			for q in c.team().roster:
				before[q.id] = q.inj_type
			# (end_week runs the week's training exactly once; measured from the players around it)
			var xp_before := _xp_total(c.team(), start)
			var was_recovery: bool = c.training.focus == "recovery"
			c.end_week()
			c.queue.clear()
			weeks += 1
			if c.in_offseason():
				done += 1
				if done < seasons:
					while c.in_offseason():
						c.end_week()
						c.queue.clear()
					for id in c.teams:
						for q in (c.teams[id] as PoloTeam).roster:
							if not start.has(q.id):
								start[q.id] = {"o": q.rating10(), "st": q.stars, "lv": q.xp_level, "type": _type(q, c.teams[id].starters().has(q)), "mine": id == c.school, "late": true}
				continue
			train_xp += _xp_total(c.team(), start) - xp_before
			train_n += c.team().roster.size()
			var after_hurt := c.team().roster.filter(func(q): return q.is_injured()).size()
			hurt_weeks += after_hurt
			for q in c.team().roster:
				if String(before.get(q.id, "")) == "" and q.is_injured():
					injuries += 1
			# a recovery week once two are hurt (a sensible coach), then back to the plan
			if after_hurt >= 2 and not was_recovery:
				c.training.focus = "recovery"
				recoveries += 1
			else:
				c.training.focus = plan[0]
		print("\n  YOUR PLAN %s / %s  (%d weeks)" % [String(plan[0]).to_upper(), Training.INTENSITY[int(plan[1])], weeks])
		print("    game XP per appearance: %.1f   training XP per player-week: %.1f" % [float(game_xp) / maxf(1, game_n), float(train_xp) / maxf(1, train_n)])
		print("    injuries on your roster: %d   injured player-weeks: %d   recovery weeks: %d" % [injuries, hurt_weeks, recoveries])
		var rows := {}
		for id in c.teams:
			for q in (c.teams[id] as PoloTeam).roster:
				if not start.has(q.id) or start[q.id].has("late"):
					continue
				var s: Dictionary = start[q.id]
				var key := ("YOURS " if s.mine else "AI    ") + String(s.type)
				if not rows.has(key):
					rows[key] = {"n": 0, "lv": 0.0, "grow": 0.0, "stars": 0.0, "up": 0, "o": 0.0, "reach": 0, "room": 0.0}
				var row: Dictionary = rows[key]
				row.n += 1
				row.lv += q.xp_level - int(s.lv)
				row.grow += (q.rating10() - float(s.o)) * 4.0
				row.stars += q.stars - float(s.st)
				row.up += 1 if q.stars > float(s.st) else 0
				row.o += float(s.o)
				row.room += float(s.room)
				row.reach += 1 if q.potential10() - q.rating10() < 0.01 else 0
		var keys := rows.keys()
		keys.sort()
		print("    %-22s %4s %6s %6s %8s %8s %8s %6s" % ["type", "n", "avg", "room", "tokens", "points", "stars+", "maxed"])
		for key in keys:
			var row: Dictionary = rows[key]
			print("    %-22s %4d %6.2f %6.2f %8.2f %8.2f %8.2f %5d%%" % [key, row.n, row.o / row.n, row.room / row.n, row.lv / row.n, row.grow / row.n, row.stars / row.n, roundi(100.0 * row.reach / row.n)])
		var ovr := 0.0
		for id in c.teams:
			ovr += (c.teams[id] as PoloTeam).team_overall(false)
		print("    league average team overall now: %.1f" % (ovr / c.teams.size()))

static func _xp_total(t: PoloTeam, start: Dictionary) -> int:
	var s := 0
	for q in t.roster:
		# XP plus every requirement already paid for since the start (so tokens count as XP earned)
		s += q.xp
		for lv in range(int(start[q.id].lv) if start.has(q.id) else q.xp_level, q.xp_level):
			s += Development.xp_required(lv - q.xp_start)
	return s

static func _type(q: PoloPlayer, starter: bool) -> String:
	var o := q.rating10()
	var tier := "WEAK" if o < 4.5 else "AVERAGE" if o < 6.0 else "STRONG" if o < 7.5 else "ELITE"
	return ("GK " if q.is_keeper() else "") + tier + ("" if starter else " SUB")

# ------------------------------------------------------------------ screenshots
## The Training screen in each state and a profile with tokens. Needs a window:
##   godot --path game -- --test dev_png <dir>
static func shots(runner, out: String) -> void:
	DirAccess.make_dir_recursive_absolute(out)
	var tree: SceneTree = runner.get_tree()
	Store.reset_for_tests()
	var c := Career.new_game("WAGN", "Sam", "Rivera", 31)
	c.hot_tip = true
	c.queue.clear()
	Game.career = c
	for plan in [["balanced", 2, "d_train_balanced"], ["shooting", 3, "d_train_shooting_hard"], ["passing", 1, "d_train_passing_light"], ["recovery", 3, "d_train_recovery"]]:
		c.training = {"focus": plan[0], "intensity": plan[1]}
		Game.goto("training")
		await tree.create_timer(0.4).timeout
		for n in tree.root.find_children("*", "", true, false):
			if n.name.begins_with("Dialog") or n.name.begins_with("Tip"):
				n.queue_free()
		await tree.process_frame
		await RenderingServer.frame_post_draw
		runner.get_viewport().get_texture().get_image().save_png(out.path_join(String(plan[2]) + ".png"))
		print("  shot ", plan[2])

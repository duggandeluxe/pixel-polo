extends RefCounted
## The 2.0 team overall and the first rosters (docs: "Retro Polo 2.0 — Complete Team Overall,
## Initial Roster Generation & Attribute-Based Gameplay System"):
##   the formula      34.5 + 13 x the seven starters' EFFECTIVE stars / 7, rounded once at the end
##   A all 30         every school's first roster shows its original OVR (the table printed)
##   B hierarchy      stronger programs start stronger
##   C attributes     every player's stars are his four attributes'; natural, positional players
##   D seven only     the bench never counts until it's in the lineup
##   E target         the original target, changed afterwards, changes nothing
##   F seasons        teams rise and fall with their players, never pushed back to the target
##   G HEAT UP        whole red stars, past five stars and past 100, gone when it cools
##   H gameplay       the same players, seeds and inputs play the same, whatever the ratings say
##   I saves          loading keeps every player and the lineup; the overall is recalculated
##   godot --headless --path game -- --test team_ovr

var r   # the test runner

const SEEDS := [2026, 3, 77]

func run(runner) -> void:
	r = runner
	print("team overall")
	Store.reset_for_tests()
	_formula()
	_all_thirty()
	_seven_only()
	_target_unused()
	_heat_up()
	_gameplay()
	_saves()
	_seasons()

## The team overall worked out by hand from the spec (an exact half rounds down: seven
## five-stars are 99).
func _by_hand(t: PoloTeam, heat := true) -> int:
	var total := 0.0
	for p: PoloPlayer in t.starters():
		total += p.stars + (float(PlayerForm.red_stars(p.form_state())) if heat else 0.0)
	return int(ceilf(snappedf(34.5 + 13.0 * total / 7.0, 0.000001) - 0.5))

## A made-up player of four attributes, all `v`.
func _flat(v: float, keeper := false) -> PoloPlayer:
	var keys := Attributes.KEEPER if keeper else Attributes.FIELD
	var vals := {}
	for k in keys:
		vals[k] = v
	return AttrBench.player(vals, keeper)

## Seven made-up starters: a keeper of `gk` and six field players of `field` (all four attributes).
func _team(gk: float, field: Array) -> PoloTeam:
	var t := PoloTeam.new()
	var g := _flat(gk, true)
	g.id = 1
	t.roster.append(g)
	for i in field.size():
		var p := _flat(float(field[i]))
		p.id = 2 + i
		t.roster.append(p)
	return t

# ------------------------------------------------------------------ the formula
func _formula() -> void:
	r.check(is_equal_approx(CollegeGen.target_stars(90.0), 55.5 / 13.0) and absf(CollegeGen.target_stars(99.0) - 4.9615) < 0.0001
		and absf(CollegeGen.target_stars(55.0) - 1.5769) < 0.0001, "target stars = (OVR - 34.5) / 13 (90: 4.2692, 99: 4.9615, 55: 1.5769)")
	# the spec's 90 OVR example: 5, 4.5, 4.5, 4, 4, 4 and a 4-star keeper = 30 stars
	var ex := _team(7.0, [8.0, 7.5, 7.5, 7.0, 7.0, 7.0])
	var ex_stars: Array = ex.starters().map(func(p): return p.stars)
	var ex_field: Array = ex_stars.slice(1)
	ex_field.sort()
	r.check(ex_stars[0] == 4.0 and ex_field == [4.0, 4.0, 4.0, 4.5, 4.5, 5.0], "the example's seven are 4 (GK), 5, 4.5, 4.5, 4, 4, 4 stars (in their places)")
	r.check(absf(ex.team_overall() - (34.5 + 13.0 * 30.0 / 7.0)) < 1e-9 and ex.overall_display() == 90, "30 stars: ACTUAL 90.2143 unrounded, shown 90 (%.4f)" % ex.team_overall())
	var fives := _team(8.0, [8.0, 8.0, 8.0, 8.0, 8.0, 8.0])
	r.check(is_equal_approx(fives.team_overall(), 99.5) and fives.overall_display() == 99, "seven five-stars: 99.5, shown 99")
	var fours := _team(7.0, [7.0, 7.0, 7.0, 7.0, 7.0, 7.0])
	r.check(is_equal_approx(fours.team_overall(), 86.5) and fours.overall_display() == 86, "seven four-stars: 86.5, shown 86 (an exact half rounds down)")
	r.check(PoloTeam.display_ovr(90.501) == 91 and PoloTeam.display_ovr(90.4999) == 90 and PoloTeam.display_ovr(90.5000000001) == 90,
		"only an exact half rounds down (float dust past six decimals is no half)")
	# never rounded on the way: 31 stars is 92.07, not round(4.43) stars
	var odd := _team(7.0, [8.0, 8.0, 7.5, 7.5, 7.0, 7.0])
	r.check(absf(odd.team_overall() - (34.5 + 13.0 * 31.0 / 7.0)) < 1e-9, "no intermediate rounding (31 stars: %.4f)" % odd.team_overall())

# ------------------------------------------------------------------ A, B, C
func _all_thirty() -> void:
	var exact := true
	var hierarchy := true
	var from_attrs := true
	var whole := true
	var pots := true
	var varied := true
	var shaped := true
	var fixed_pot := true
	var worst := 0
	var near_top := 0      # a strong program's player close to his ceiling
	var rising_low := 0    # a weak program's player with a lot of room
	var lean := {"C": 0.0, "D": 0.0, "DR": 0.0}
	var lean_n := {"C": 0, "D": 0, "DR": 0}
	var table: Array = []
	for seed in SEEDS:
		var c := Career.new_game("WAGN", "A", "B", seed)
		var made := {}
		# (XP Development 2.0: a team that has already played its first game may have spent the
		# upgrades it earned there: its roster isn't its first one any more)
		var played := {}
		for g in c.cur().games:
			if g.r != null:
				played[g.h] = true
				played[g.a] = true
		for s in Colleges.SCHOOLS:
			var t: PoloTeam = c.teams[s.short]
			var want := int(s.ovr)
			var got := t.overall_display()
			made[s.short] = t.team_overall(false)
			if played.has(s.short):
				made.erase(s.short)
				got = want
			worst = maxi(worst, absi(got - want))
			if got != want or (not played.has(s.short) and (t.base_ovr() != want or _by_hand(t) != want)) or t.initial_strength_target != float(want):
				exact = false
			if seed == SEEDS[0]:
				table.append([s.short, s.name, want, got, t.team_overall(false), t.starters().map(func(p): return p.stars)])
			var seven := t.starters()
			if seven.size() != 7 or not seven[0].is_keeper() or seven.slice(1).any(func(p): return p.is_keeper()):
				shaped = false
			var pos := seven.map(func(p: PoloPlayer): return p.pos)
			pos.sort()
			var want_pos := CollegeGen.ROSTER_POS.duplicate()
			want_pos.sort()
			if pos != want_pos:
				shaped = false
			var st := seven.map(func(p): return p.stars)
			if st.all(func(v): return is_equal_approx(float(v), float(st[0]))):
				varied = false
			for p: PoloPlayer in t.roster:
				if p.key_ratings() != (Attributes.KEEPER if p.is_keeper() else Attributes.FIELD) or p.attrs.size() != 4:
					from_attrs = false
				if not is_equal_approx(p.stars, Attributes.stars_of(Attributes.overall(p))) or not is_equal_approx(p.pot_stars, Attributes.stars_of(Attributes.potential(p))):
					from_attrs = false
				for k in p.key_ratings():
					var a := p.attr(k)
					var cap := float(p.attr_pot[k])
					if a != roundf(a) or a < 0.0 or a > 10.0:
						whole = false
					if cap < a or cap > 10.0:
						pots = false
				var room := p.potential10() - p.rating10()
				if want >= 85 and room <= 0.25:
					near_top += 1
				if want <= 70 and room >= 2.0:
					rising_low += 1
				var tag: String = {PoloPlayer.Pos.CENTER: "C", PoloPlayer.Pos.DEFENDER: "D", PoloPlayer.Pos.DRIVER: "DR"}.get(p.pos, "")
				if tag == "C":
					lean.C += p.attr("str") - p.attr("pas")
				elif tag == "D":
					lean.D += p.attr("dfn") - p.attr("sho")
				elif tag == "DR":
					lean.DR += p.attr("sho") - p.attr("str")
				if tag != "":
					lean_n[tag] += 1
			# ceilings are fixed: a week of the season changes no ceiling
		for a in Colleges.SCHOOLS:
			for b in Colleges.SCHOOLS:
				if made.has(a.short) and made.has(b.short) and int(a.ovr) > int(b.ovr) and float(made[a.short]) <= float(made[b.short]):
					hierarchy = false
		var caps := {}
		for id in c.teams:
			for p: PoloPlayer in c.teams[id].roster:
				caps[p.id] = p.attr_pot.duplicate()
		c.queue.clear()
		while c.has_game():
			c.sim_my_game()
		c.end_week()
		for id in c.teams:
			for p: PoloPlayer in c.teams[id].roster:
				if caps.has(p.id) and p.attr_pot != caps[p.id]:
					fixed_pot = false
	print("  A: original OVR target vs the first roster (seed %d)" % SEEDS[0])
	print("    TEAM   TARGET  GENERATED  DIFF   ACTUAL    STARTERS' STARS")
	table.sort_custom(func(x, y): return x[2] > y[2] if x[2] != y[2] else String(x[0]) < String(y[0]))
	for row in table:
		print("    %-6s %6d  %9d  %+4d   %7.3f   %s" % [row[0], row[2], row[3], row[3] - row[2], row[4], ", ".join(row[5].map(func(v): return PlayerForm.star_text(v)))])
	r.check(exact, "A: all 30 schools' first rosters show their original OVR exactly, seeds %s (worst %d off)" % [str(SEEDS), worst])
	r.check(hierarchy, "B: a higher original OVR always starts with a stronger seven")
	r.check(from_attrs, "C: every player's CURRENT and POTENTIAL stars are read off his four attributes and ceilings")
	r.check(whole, "C: the attributes are whole numbers, 0-10")
	r.check(pots, "potential: every ceiling between the attribute and 10")
	r.check(fixed_pot, "potential: the ceilings never move once made")
	r.check(near_top > 0 and rising_low > 0, "potential: strong programs have men near their ceiling (%d), weak ones men with room to grow (%d)" % [near_top, rising_low])
	r.check(varied, "no team's seven are all the same stars")
	r.check(shaped, "every seven: one keeper, a centre, a defender, two drivers, two utilities")
	r.check(lean.C / lean_n.C > 0.5 and lean.D / lean_n.D > 0.5 and lean.DR / lean_n.DR > 0.5,
		"positions keep their shape: centres strong, defenders defend, drivers shoot (%.1f, %.1f, %.1f)" % [lean.C / lean_n.C, lean.D / lean_n.D, lean.DR / lean_n.DR])
	# every target the table could ask for is met (exactly where half stars allow it)
	var reach := true
	for target in range(55, 100):
		var rng := RandomNumberGenerator.new()
		rng.seed = target
		var stars := CollegeGen.starter_stars(rng, float(target))
		var total := 0.0
		for v in stars:
			total += float(v)
		if PoloTeam.display_ovr(CollegeGen.ovr_of_total(total)) != target or stars.any(func(v): return float(v) < 0.5 or float(v) > 5.0):
			reach = false
	r.check(reach, "every target from 55 to 99 can be built exactly, with stars 0.5-5")

# ------------------------------------------------------------------ D
func _seven_only() -> void:
	var c := Career.new_game("SJCU", "A", "B", 5)
	var t := c.team()
	var seven := t.starters()
	var subs := t.roster.filter(func(p): return not seven.has(p))
	r.check(t.roster.size() == 10 and subs.size() == 3 and t.has_lineup(), "your program starts with seven starters, three subs and a lineup")
	r.check(subs.filter(func(p): return p.is_keeper()).size() == 1, "one of the subs is a backup keeper")
	var before := t.team_overall()
	var sub: PoloPlayer = subs.filter(func(p): return not p.is_keeper())[0]
	for k in sub.key_ratings():
		Attributes.set_ceiling(sub, k, 10.0)
		Attributes.set_value(sub, k, 10.0)
	sub.heat = 2
	r.check(is_equal_approx(t.team_overall(), before) and t.starters() == seven, "D: a sub made a VERY HOT five-star changes nothing on the bench (%.3f)" % t.team_overall())
	# into the lineup: the weakest field starter's place
	var out: PoloPlayer = seven[1]
	for q: PoloPlayer in seven.slice(1):
		if q.stars < out.stars:
			out = q
	var i := t.lineup.find(out.id)
	var j := t.lineup.find(sub.id)
	t.lineup[i] = sub.id
	t.lineup[j] = out.id
	var want := before + 13.0 * (sub.stars + 2.0 - out.stars - float(PlayerForm.red_stars(out.form_state()))) / 7.0
	r.check(absf(t.team_overall() - want) < 1e-9 and t.overall_display() == _by_hand(t), "D: subbed in, he counts: %.3f -> %.3f" % [before, t.team_overall()])
	# AI programs: seven, no bench
	r.check(c.teams.keys().all(func(id): return id == c.school or c.teams[id].roster.size() == c.roster_cap(id)), "AI programs keep their full rosters (benches since the Roll-Out update)")

# ------------------------------------------------------------------ E
func _target_unused() -> void:
	var c := Career.new_game("CULA", "A", "B", 8)
	var t: PoloTeam = c.teams["ICU"]
	var o: PoloTeam = c.teams["LMMU"]
	var r0 := t.ratings()
	var ovr0 := t.overall_display()
	var games0: Array = []
	for sd in 40:
		games0.append(GameSim.play(t, o, 900 + sd).score)
	t.initial_strength_target = 40.0
	o.initial_strength_target = 99.0
	var games1: Array = []
	for sd in 40:
		games1.append(GameSim.play(t, o, 900 + sd).score)
	r.check(t.ratings() == r0 and t.overall_display() == ovr0, "E: a changed original target changes no rating (ICU %d)" % ovr0)
	r.check(games1 == games0, "E: ...and no simulated result (40 games)")
	# the school table itself is never read after the first roster: no source file reads the
	# target back, and only Career.new_game reads a school's `ovr`
	var readers: Array = []
	for f in _sources("res://src"):
		var src := FileAccess.get_file_as_string(f)
		if f.ends_with("polo_team.gd") or f.ends_with("college_gen.gd"):   # (its home, and the generator)
			continue
		if src.contains("initial_strength_target"):
			readers.append(f.get_file())
	r.check(readers.is_empty(), "E: nothing outside the generator reads the original target %s" % str(readers))
	var ovr_readers: Array = []
	for f in _sources("res://src"):
		var src := FileAccess.get_file_as_string(f)
		for needle in ["s.ovr", "sd.ovr", "\"ovr\"", ".ovr)"]:
			# (the school table itself; the Road to Glory orders its tiers by it, never a team's strength)
			if src.contains(needle) and not f.ends_with("career.gd") and not f.ends_with("colleges.gd") and not f.ends_with("progression.gd") and not f.ends_with("college_gen.gd"):
				ovr_readers.append("%s (%s)" % [f.get_file(), needle])
	var career_src := FileAccess.get_file_as_string("res://src/core/career.gd")
	r.check(ovr_readers.is_empty() and career_src.count("s.ovr") == 2 and career_src.contains("make_initial_roster(t, c.rng, c.new_id, float(s.ovr)") and career_src.contains("add_initial_bench(t, c.rng, c.new_id, float(s.ovr)"),
		"E: a school's original `ovr` is read in one place, the brand-new career's first rosters (starters and bench) %s" % str(ovr_readers))

func _sources(dir: String) -> Array:
	var out: Array = []
	var d := DirAccess.open(dir)
	if d == null:
		return out
	for f in d.get_files():
		if f.ends_with(".gd"):
			out.append(dir + "/" + f)
	for sub in d.get_directories():
		out.append_array(_sources(dir + "/" + sub))
	return out

# ------------------------------------------------------------------ G
func _heat_up() -> void:
	# the spec's examples: 3 + 1 = 4, 4 + 2 = 6, 5 + 2 = 7
	var three := _flat(5.0)
	var four := _flat(7.0)
	var five := _flat(8.0)
	three.heat = 1
	four.heat = 2
	five.heat = 2
	r.check(PoloTeam.ovr_stars(three) == 4.0 and PoloTeam.ovr_stars(four) == 6.0 and PoloTeam.ovr_stars(five) == 7.0, "G: 3 + 1 = 4, 4 + 2 = 6, 5 + 2 = 7 effective stars (never capped at five)")
	r.check(PoloTeam.ovr_stars(five, false) == 5.0, "...and permanent stars without it")
	# a team of four-stars, one HOT then another VERY HOT, then cooled
	var t := _team(7.0, [7.0, 7.0, 7.0, 7.0, 7.0, 7.0])
	var base := t.team_overall()
	t.roster[3].heat = 1
	r.check(absf(t.team_overall() - (base + 13.0 / 7.0)) < 1e-9 and t.overall_display() == 88, "G: one HOT starter: +1 star, 86.5 -> 88.36, shown 88 (%.2f)" % t.team_overall())
	t.roster[0].heat = 2
	r.check(absf(t.team_overall() - (base + 3.0 * 13.0 / 7.0)) < 1e-9 and t.base_ovr() == 86, "G: and a VERY HOT keeper: +3 stars in all; BASE still 86 (%.2f)" % t.team_overall())
	t.roster[3].heat = 0
	t.roster[0].heat = 0
	r.check(is_equal_approx(t.team_overall(), base) and t.overall_display() == 86, "G: cooled down, the overall is back to its permanent stars")
	# past 100: seven five-stars, all VERY HOT, 7 effective stars each
	var top := _team(8.0, [9.0, 9.0, 9.0, 9.0, 9.0, 9.0])
	for p in top.roster:
		p.heat = 2
	r.check(is_equal_approx(top.team_overall(), 125.5) and top.overall_display() == 125, "G: seven five-stars VERY HOT: 125.5, shown 125, never capped at 99 or 100")
	for p in top.roster:
		p.heat = 1
	r.check(is_equal_approx(top.team_overall(), 112.5) and top.overall_display() == 112, "G: all HOT: 112")
	# in a career, through the season: the overall follows heat as it comes and goes
	var c := Career.new_game("PRIN", "A", "B", 19)
	var always := true
	var heated := false
	for _w in 6:
		c.queue.clear()
		while c.has_game():
			c.sim_my_game()
		for id in c.teams:
			var tm: PoloTeam = c.teams[id]
			if tm.overall_display() != _by_hand(tm) or tm.base_ovr() != _by_hand(tm, false):
				always = false
			if tm.overall_display() > tm.base_ovr():
				heated = true
		c.end_week()
	r.check(always and heated, "G: through six weeks, every overall is its seven's stars plus their red ones (HEAT UP came: %s)" % heated)
	# HEAT UP's own gameplay effect is the one it always had (PoloPlayer.live), not more
	var hp := _flat(6.0)
	var cold := hp.live("shoot")
	hp.heat = 2
	r.check(is_equal_approx(hp.live("shoot") - cold, PlayerForm.RATING_PER_STAR * float(PlayerForm.FORM_STARS[PlayerForm.VERY_HOT])), "G: VERY HOT still plays exactly as it did (+%.0f shooting)" % (hp.live("shoot") - cold))

# ------------------------------------------------------------------ H
## A whole short match between two teams, the bots on both sides: everything that happened.
func _match(us: PoloTeam, them: PoloTeam, seed_value: int) -> String:
	var f := MatchFlow.new(us, them, seed_value, 2.0)
	r._finish_flow(f)
	var st := f.state
	return JSON.stringify([st.score, st.shots, st.saves, st.exclusions, st.steals, st.blocks, st.scorers, st.shootout])

func _gameplay() -> void:
	var c := Career.new_game("LBSC", "A", "B", 23)
	var us: PoloTeam = c.teams["LBSC"]
	var them: PoloTeam = c.teams["CUSD"]
	var runs: Array = []
	for sd in 4:
		runs.append(_match(PoloTeam.from_dict(us.to_dict()), PoloTeam.from_dict(them.to_dict()), 600 + sd))
	var again: Array = []
	for sd in 4:
		again.append(_match(PoloTeam.from_dict(us.to_dict()), PoloTeam.from_dict(them.to_dict()), 600 + sd))
	r.check(again == runs, "H: the same players, seeds and inputs play the same match (the control)")
	var relabelled: Array = []
	for sd in 4:
		var a := PoloTeam.from_dict(us.to_dict())
		var b := PoloTeam.from_dict(them.to_dict())
		a.initial_strength_target = 55.0
		b.initial_strength_target = 99.0
		relabelled.append(_match(a, b, 600 + sd))
	r.check(relabelled == runs, "H: change only the original targets: the same matches, shot for shot")
	var reads: Array = []
	var files := _sources("res://src/match") + ["res://src/core/shot_model.gd", "res://src/core/tempo.gd", "res://src/core/attributes.gd"]
	for f in files:
		var src := FileAccess.get_file_as_string(f)
		for needle in [".rating()", "ratings()", "team_overall", "overall_display", "base_ovr", "live_ovr", "initial_strength_target", "off_rating", "def_rating", "attack_rating", "defense_rating", "power()", "form_delta", "team_ovr"]:
			if src.contains(needle):
				reads.append("%s: %s" % [f.get_file(), needle])
	r.check(reads.is_empty(), "H: nothing in the pool reads a team rating or overall %s" % str(reads))
	var tempo := FileAccess.get_file_as_string("res://src/core/tempo.gd")
	r.check(not tempo.contains("TEAM_") and not tempo.contains("ovr"), "H: Tempo has no team curves left (shot pace, pass pace, decisions)")

# ------------------------------------------------------------------ I
func _saves() -> void:
	var c := Career.new_game("CCSB", "A", "B", 47)
	r._sim_to(c, 5)
	c.team().starters()[2].heat = 1
	var d: Dictionary = JSON.parse_string(JSON.stringify(c.to_dict()))
	var c2 := Career.from_dict(d)
	var players_same := true
	for id in c.teams:
		var a: PoloTeam = c.teams[id]
		var b: PoloTeam = c2.teams[id]
		if JSON.stringify(a.roster.map(func(p): return p.to_dict())) != JSON.stringify(b.roster.map(func(p): return p.to_dict())):
			players_same = false
		if a.lineup != b.lineup or a.overall_display() != b.overall_display() or not is_equal_approx(a.team_overall(), b.team_overall()):
			players_same = false
	r.check(players_same, "I: a save keeps every player (attributes, ceilings, ages, positions, heat), the lineup and the overall")
	r.check(c2.team().initial_strength_target == float(Colleges.school("CCSB").ovr), "I: the original target is kept for the record")
	r.check(JSON.stringify(c2.to_dict()) == JSON.stringify(c.to_dict()), "I: the save round-trips exactly")
	# an older save: the locked "ovr"/"off"/"def" of before, no target. Nothing is regenerated
	var od: Dictionary = JSON.parse_string(JSON.stringify(c.to_dict()))
	for id in od.teams:
		od.teams[id].erase("init_target")
		od.teams[id]["ovr"] = 50
		od.teams[id]["off"] = 50
		od.teams[id]["def"] = 50
	var o2 := Career.from_dict(od)
	var kept := true
	for id in c.teams:
		var a: PoloTeam = c.teams[id]
		var b: PoloTeam = o2.teams[id]
		if JSON.stringify(a.roster.map(func(p): return p.to_dict())) != JSON.stringify(b.roster.map(func(p): return p.to_dict())) or a.lineup != b.lineup:
			kept = false
		if b.overall_display() != _by_hand(b) or b.overall_display() != a.overall_display() or b.initial_strength_target != 0.0:
			kept = false
	r.check(kept, "I: an older save keeps its players and lineup; its overall is its seven's, whatever it saved")
	r.check(not o2.trimmed and not o2.upgraded, "I: ...and nothing about its rosters is converted")

# ------------------------------------------------------------------ F
func _seasons() -> void:
	var c := Career.new_game("HURST", "A", "B", 61)
	var start := {}
	var ids0 := {}
	for id in c.teams:
		start[id] = c.teams[id].team_overall(false)
		ids0[id] = c.teams[id].roster.map(func(p): return p.id)
	var base: Dictionary = JSON.parse_string(JSON.stringify(c.to_dict()))
	var seasons := 3
	var a := _play_seasons(Career.from_dict(JSON.parse_string(JSON.stringify(base))), seasons, false)
	var b := _play_seasons(Career.from_dict(JSON.parse_string(JSON.stringify(base))), seasons, true)
	r.check(a.trace == b.trace, "F: %d seasons with every original target scrambled play out exactly the same (results, rosters, overalls)" % seasons)
	var end: Dictionary = a.ovr
	var moved := 0
	var far := 0
	var toward := 0
	var away := 0
	for id in end:
		var target := float(Colleges.school(id).ovr)
		var d := float(end[id]) - float(start[id])
		if absf(d) >= 3.0:
			moved += 1
		# (5, not 6, since the Long-Term Development curve: the league no longer inflates ~6 in a
		# season, so teams move both ways from their start rather than all upwards together)
		if absf(float(end[id]) - target) >= 5.0:
			far += 1
	print("  F: after %d seasons, overall vs the original (target -> now):" % seasons)
	var rows: Array = []
	for s in Colleges.SCHOOLS:
		rows.append("%s %d->%d" % [s.short, int(s.ovr), PoloTeam.display_ovr(float(end[s.short]))])
	print("    " + ", ".join(rows))
	r.check(moved >= 10, "F: team strength changes with the players (%d of 30 moved 3+)" % moved)
	r.check(far >= 3, "F: nobody is pushed back to the rating they started with (%d of 30 are 5+ from it)" % far)
	r.check(a.formula_ok, "F: every week of every season, each overall is its seven starters' (34.5 + 13 x stars / 7)")
	r.check(a.kept_players, "F: a new season never regenerates a returning player (same id, attributes carried on)")

## `n` seasons of a career, simulated: {trace (everything that happened, as text), ovr: {id: the
## permanent overall at the end}, formula_ok, kept_players}. `scramble`: every team's original
## target set to nonsense first.
func _play_seasons(c: Career, n: int, scramble: bool) -> Dictionary:
	if scramble:
		for id in c.teams:
			c.teams[id].initial_strength_target = 1.0 + float(id.length() * 13 % 97)
	var trace := PackedStringArray()
	var formula_ok := true
	var kept := true
	var y0 := c.year
	var guard := 0
	while c.year < y0 + n and guard < 400:
		guard += 1
		c.queue.clear()
		var before := {}
		if c.phase == "done":   # (the roster transition is next)
			for id in c.teams:
				for p: PoloPlayer in c.teams[id].roster:
					before[p.id] = p.attrs.duplicate()
		while c.has_game():
			c.sim_my_game()
		c.end_week()
		for id in c.teams:
			var t: PoloTeam = c.teams[id]
			if t.overall_display() != _by_hand(t):
				formula_ok = false
			for p: PoloPlayer in t.roster:
				if before.has(p.id):
					for k in p.key_ratings():
						if p.attr(k) + 1e-6 < float(before[p.id].get(k, 0.0)) - 3.0:
							kept = false
		trace.append("%d %s %d %s" % [c.year, c.phase, c.week, JSON.stringify(c.table)])
	var ovr := {}
	for id in c.teams:
		ovr[id] = c.teams[id].team_overall(false)
		trace.append("%s %s %.4f" % [id, str(c.teams[id].roster.map(func(p): return p.id)), float(ovr[id])])
	return {"trace": "\n".join(trace), "ovr": ovr, "formula_ok": formula_ok, "kept_players": kept}

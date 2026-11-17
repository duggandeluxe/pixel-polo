extends RefCounted
## Player stars, seven-man rosters and HOT form (PlayerForm, docs "Player Stars & 7-Player
## Rosters"): the star scale, the three form levels, heat over the rolling five games, the postgame grade
## (RAW, EXPECTED, +/-, GOOD / NORMAL / BAD), BASE and LIVE OVR, form in the scoring engine (once)
## and in the pool, the roster's colours, saves old and new, and a season through the lock.
##   godot --headless --path game -- --test form

## The spec's initial seed: every school's OVR from its seven.
const SPEC_OVR := {
	"CULA": 91, "CUSC": 90, "STAM": 89, "ALC": 88, "FORDU": 86, "SJCU": 83, "LBSC": 82, "CUSD": 81,
	"PRIN": 80, "PPCU": 79, "UCDS": 78, "ICU": 78, "CRBU": 77, "LMMU": 77, "UPAC": 76, "HVRD": 76,
	"CCSB": 75, "NANA": 74, "BROW": 74, "GWU": 73, "SCCU": 72, "USAF": 71, "SMCC": 70, "CSFU": 70,
	"BUCK": 69, "WAGN": 68, "MSMU": 67, "IONA": 66, "LIUB": 65, "HURST": 62,
}

var r   # the test runner

func run(runner) -> void:
	r = runner
	print("form")
	Store.reset_for_tests()
	_star_scale()
	_form_states()
	_rolling()
	_heat_rarity()
	_raw_points()
	_thresholds()
	_expected()
	_seed()
	_base_live()
	_engine_once()
	_goals_unchanged()
	_in_the_pool()
	_colors()
	_saves()
	_old_saves()
	_legacy_form()
	_season()

func _player(stars: float, pos: int = PoloPlayer.Pos.DRIVER) -> PoloPlayer:
	var p := PoloPlayer.new()
	p.pos = pos
	p.stars = stars
	p.pot_stars = maxf(stars, 4.0)
	p.shoot = 60
	p.passing = 60
	p.defense = 60
	p.strength = 60
	p.keeping = 60
	return p

# 8. the star scale, 5.5 and 6.0 included
func _star_scale() -> void:
	var want := {1.0: 44, 1.5: 50, 2.0: 56, 2.5: 62, 3.0: 68, 3.5: 74, 4.0: 80, 4.5: 86, 5.0: 92, 5.5: 96, 6.0: 99}
	for st in want:
		r.check(PlayerForm.star_value(st) == want[st], "%.1f stars = %d" % [st, want[st]])
	var p := _player(5.0)
	p.heat = 1
	r.check(is_equal_approx(p.eff_stars(), 5.5) and PlayerForm.star_value(p.eff_stars()) == 96, "a HOT five-star plays as 5.5 stars (96)")
	p.heat = 2
	r.check(is_equal_approx(p.eff_stars(), 6.0) and PlayerForm.star_value(p.eff_stars()) == 99, "a VERY HOT five-star plays as 6.0 stars (99)")
	r.check(PlayerForm.clamp_stars(5.5) == 5.0 and PlayerForm.clamp_stars(-0.5) == 0.0, "CURRENT and POTENTIAL stay 0-5 (2.0: OVERALL 0-10 halved)")

# 1. the three form levels and what they do to a player's stars; no cold form at all
func _form_states() -> void:
	var cases := [[0, "normal", 0.0, 0], [1, "hot", 0.5, 1], [2, "very_hot", 1.0, 2]]
	for cs in cases:
		var st := PlayerForm.state_of(int(cs[0]))
		r.check(st == cs[1] and is_equal_approx(float(PlayerForm.FORM_STARS[st]), float(cs[2])) and PlayerForm.red_stars(st) == int(cs[3]),
			"HEAT %d is %s (%+.1f star, %d red)" % [cs[0], PlayerForm.FORM_NAMES[cs[1]], cs[2], cs[3]])
	r.check(PlayerForm.LEVELS.size() == 3 and PlayerForm.FORM_NAMES.size() == 3 and PlayerForm.FORM_STARS.values().all(func(v): return float(v) >= 0.0),
		"three levels only, none of them takes a star away")
	r.check(not PlayerForm.FORM_NAMES.has("cold") and not PlayerForm.FORM_NAMES.has("ice_cold"), "no COLD or ICE COLD form")
	var src := FileAccess.get_file_as_string("res://src/core/player_form.gd")
	r.check(not src.contains("ICE_BLUE") and not src.contains("ICE_COLD :=") and not src.contains("COLD :="), "the cold constants are gone")
	var ex := [[3.0, 1, 3.5, "a 3-star HOT plays as 3.5"], [4.0, 2, 5.0, "a 4-star VERY HOT plays as 5.0"],
		[5.0, 1, 5.5, "a 5-star HOT plays as 5.5"], [5.0, 2, 6.0, "a 5-star VERY HOT plays as 6.0"],
		[3.0, 0, 3.0, "a 3-star NORMAL plays as 3.0"], [0.5, 0, 0.5, "a half-star NORMAL plays as 0.5"]]
	for e in ex:
		var p := _player(float(e[0]))
		p.heat = int(e[1])
		r.check(is_equal_approx(p.eff_stars(), float(e[2])), e[3])
	var bad := _player(3.0)
	for i in 5:
		PlayerForm.push_grade(bad, PlayerForm.BAD)
	r.check(bad.form_state() == PlayerForm.NORMAL and is_equal_approx(bad.eff_stars(), 3.0) and is_equal_approx(bad.live("shoot"), 60.0),
		"five BAD games: still NORMAL, his own stars and ratings (no cold penalty)")

# 2, 3. heat over the rolling five games: a level a game, up and down
func _rolling() -> void:
	var p := _player(3.0)
	r.check(p.form_state() == PlayerForm.NORMAL and p.form.is_empty() and p.heat == 0, "a new player starts NORMAL with no grades")
	PlayerForm.push_grade(p, PlayerForm.GOOD)
	r.check(p.form_state() == PlayerForm.NORMAL, "one GOOD game is not enough: still NORMAL")
	PlayerForm.push_grade(p, PlayerForm.GOOD)
	r.check(p.form_state() == PlayerForm.NORMAL, "two GOOD games: still NORMAL")
	PlayerForm.push_grade(p, PlayerForm.GOOD)
	r.check(p.form_state() == PlayerForm.HOT and is_equal_approx(p.eff_stars(), 3.5), "three GOOD games: HOT, one red star")
	PlayerForm.push_grade(p, PlayerForm.GOOD)
	r.check(p.form_state() == PlayerForm.VERY_HOT and is_equal_approx(p.eff_stars(), 4.0), "a fourth GOOD game: VERY HOT, two red stars")
	PlayerForm.push_grade(p, PlayerForm.GOOD)
	PlayerForm.push_grade(p, PlayerForm.GOOD)
	r.check(p.form.size() == PlayerForm.FORM_GAMES and PlayerForm.FORM_GAMES == 5 and p.heat == 2, "never more than five grades kept; VERY HOT is the top")
	# cooling: a level at a time, never straight from VERY HOT to NORMAL
	var steps: Array = []
	for g in [0, 0, 0, 0]:
		PlayerForm.push_grade(p, g)
		steps.append(p.heat)
	r.check(steps == [2, 1, 1, 0], "NORMAL games cool him gradually: VERY HOT, HOT, HOT, NORMAL (%s)" % [steps])
	var q := _player(3.0)
	for g in [1, 1, 1, 1, 1]:
		PlayerForm.push_grade(q, g)
	steps = []
	for g in [-1, -1, -1]:
		PlayerForm.push_grade(q, g)
		steps.append(q.heat)
	r.check(steps == [1, 0, 0], "even BAD games take it a level at a time: VERY HOT to HOT, then NORMAL (%s)" % [steps])
	# heating: a level at a time too
	var h := _player(3.0)
	h.form = [1, 1, 1, 1]
	PlayerForm.push_grade(h, PlayerForm.GOOD)
	r.check(h.heat == 1, "a NORMAL player on a five-game run goes to HOT first, not straight to VERY HOT")
	# a BAD game cancels a GOOD one
	var m := _player(3.0)
	for g in [1, -1, 1, 1, 0]:
		PlayerForm.push_grade(m, g)
	r.check(m.form_state() == PlayerForm.NORMAL, "GOOD, BAD, GOOD, GOOD, NORMAL: a run of +2, still NORMAL")
	var k := _player(3.0)
	for g in [1, 1, 1, -1]:
		PlayerForm.push_grade(k, g)
	r.check(k.heat == 1, "HOT holds through one BAD game while the run stays +2")
	PlayerForm.push_grade(k, PlayerForm.BAD)
	r.check(k.heat == 0, "...a second BAD game ends it")
	# no randomness: the same games make the same heat
	var a1 := _player(3.0)
	var a2 := _player(3.0)
	for g in [1, 0, 1, 1, 1, 0, -1, 1]:
		PlayerForm.push_grade(a1, g)
		PlayerForm.push_grade(a2, g)
	r.check(a1.heat == a2.heat and a1.form == a2.form, "heat follows the games and nothing else")

## HOT takes a run of good games and VERY HOT a much better one: over many runs of grades with a
## real GOOD / BAD mix (measured from graded games), VERY HOT is far rarer than HOT.
func _heat_rarity() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var c := Career.new_game("WAGN", "A", "B", 81)
	var counts := {-1: 0, 0: 0, 1: 0}
	for id in c.teams:
		var t: PoloTeam = c.teams[id]
		for g in 4:
			var opp: PoloTeam = c.teams[c.teams.keys()[(g * 7 + id.length()) % c.teams.size()]]
			if opp == t:
				continue
			var res := GameSim.play(t, opp, rng.randi())
			var exp := PlayerForm.expected(t, GameSim.pregame_expected(t, opp, true, false), "sim")
			for p: PoloPlayer in t.starters():
				var gr := PlayerForm.grade_of(PlayerForm.raw_points(res.lines[0].get(p.id, {})) - float(exp.get(p.id, 0.0)))
				counts[gr] += 1
	var n := float(counts[-1] + counts[0] + counts[1])
	var pg: float = counts[1] / n
	var pb: float = counts[-1] / n
	print("    grades from engine games: GOOD %.2f, NORMAL %.2f, BAD %.2f" % [pg, 1.0 - pg - pb, pb])
	var weeks := {0: 0, 1: 0, 2: 0}
	var ever := {1: 0, 2: 0}
	var players := 4000
	for i in players:
		var p := _player(3.0)
		var top := 0
		for game in 16:
			var u := rng.randf()
			PlayerForm.push_grade(p, PlayerForm.GOOD if u < pg else (PlayerForm.BAD if u < pg + pb else 0))
			weeks[p.heat] += 1
			top = maxi(top, p.heat)
		if top >= 1:
			ever[1] += 1
		if top >= 2:
			ever[2] += 1
	var tot := float(players * 16)
	var hot_share: float = (weeks[1] + weeks[2]) / tot
	var very_share: float = weeks[2] / tot
	print("    a 16-game season: HOT or better %.1f%% of games (VERY HOT %.1f%%); ever HOT %.1f%%, ever VERY HOT %.1f%% of players"
		% [hot_share * 100.0, very_share * 100.0, ever[1] * 100.0 / players, ever[2] * 100.0 / players])
	# (rarer since GOOD takes +5.85: the Hot Star Balancing update made stars 1.30x harder to earn)
	r.check(hot_share > 0.005 and hot_share < 0.2, "HOT is achievable but uncommon (%.1f%% of games)" % (hot_share * 100.0))
	r.check(very_share * 4.0 < hot_share and very_share < 0.03, "VERY HOT is much rarer than HOT (%.1f%% vs %.1f%%)" % [very_share * 100.0, hot_share * 100.0])
	r.check(ever[2] * 3 < ever[1], "far fewer players ever reach VERY HOT than HOT (%d vs %d of %d)" % [ever[2], ever[1], players])

# 4, 5. RAW points: the spec's worked examples
func _raw_points() -> void:
	var field := {"g": 3, "sh": 7, "ed": 2, "bl": 1, "ga": 8}
	r.check(is_equal_approx(PlayerForm.raw_points(field), 7.0), "field: 3 goals, 2 drawn, 1 block, 4 misses, 8 against = RAW +7")
	var keeper := {"gk": true, "sv": 14, "ga": 9}
	r.check(is_equal_approx(PlayerForm.raw_points(keeper), 14.5), "keeper: 14 saves, 9 against = RAW +14.5")
	r.check(is_equal_approx(PlayerForm.raw_points({"gk": true, "sv": 3, "ga": 0, "bl": 5}), 6.0), "a keeper's saves aren't field blocks too")
	# graded against EXPECTED +1.15: +/- = +5.85, GOOD (the bar since the Hot Star Balancing update:
	# 4.5 x 1.30); against +3 it's +4: NORMAL
	var t := PoloTeam.new()
	t.id = "TST"
	for i in 7:
		var p := _player(3.0, PoloPlayer.Pos.GK if i == 0 else PoloPlayer.Pos.DRIVER)
		p.id = i + 1
		t.roster.append(p)
	var fp: PoloPlayer = t.roster[3]
	r.check(PlayerForm.grade_of(PlayerForm.raw_points(field) - 3.0) == 0, "RAW +7 against EXPECTED +3: +/- +4, NORMAL (GOOD starts at +5.85)")
	var rows := PlayerForm.grade_team(t, {fp.id: field}, {fp.id: 1.15})
	var row: Dictionary = rows.filter(func(x): return x.p == fp)[0]
	r.check(is_equal_approx(float(row.pm), 5.85) and int(row.grade) == PlayerForm.GOOD, "RAW +7 against EXPECTED +1.15: +/- +5.85, GOOD")
	r.check(fp.form == [1] and fp.form_state() == PlayerForm.NORMAL and int(fp.last_game.gr) == 1, "the grade goes into his form (one GOOD game alone isn't HOT)")
	for _i in 2:
		PlayerForm.grade_team(t, {fp.id: field}, {fp.id: 1.15})
	r.check(fp.form == [1, 1, 1] and fp.form_state() == PlayerForm.HOT, "three GOOD games graded: HOT")
	r.check(rows.size() == 7 and rows.all(func(x): return x.has("raw") and x.has("exp") and x.has("pm") and x.has("grade")), "all seven get RAW, EXPECTED, +/- and a grade")
	r.check(is_equal_approx(fp.stars, 3.0) and is_equal_approx(fp.pot_stars, 4.0), "a grade never moves CURRENT or POTENTIAL")

# 7. the thresholds
func _thresholds() -> void:
	var cases := [[5.85, 1], [5.84, 0], [4.5, 0], [3.0, 0], [0.0, 0], [-2.99, 0], [-3.0, -1], [9.5, 1], [-12.0, -1], [5.854, 1], [-3.004, -1]]
	for cs in cases:
		r.check(PlayerForm.grade_of(float(cs[0])) == int(cs[1]), "+/- %+.2f is %s" % [cs[0], PlayerForm.GRADE_NAMES[int(cs[1])]])

# 6. EXPECTED adjusts for the opponent, the venue and the player
func _expected() -> void:
	var c := Career.new_game("LIUB", "A", "B", 3)
	var liub: PoloTeam = c.teams["LIUB"]
	var cula: PoloTeam = c.teams["CULA"]
	var hurst: PoloTeam = c.teams["HURST"]
	var vs_cula := PlayerForm.expected(liub, GameSim.pregame_expected(liub, cula, true, false), "sim")
	var vs_hurst := PlayerForm.expected(liub, GameSim.pregame_expected(liub, hurst, true, false), "sim")
	var all_lower := true
	for p: PoloPlayer in liub.starters():
		if float(vs_cula[p.id]) >= float(vs_hurst[p.id]):
			all_lower = false
	r.check(all_lower, "every LIUB player is expected less against CULA than against HURST")
	var fp: PoloPlayer = liub.starters()[2]
	var line := {"g": 3, "sh": 5, "ed": 1, "bl": 0, "ga": 10}
	var raw := PlayerForm.raw_points(line)
	r.check(raw - float(vs_cula[fp.id]) > raw - float(vs_hurst[fp.id]), "3 goals against CULA grade higher than 3 against HURST")
	var away := PlayerForm.expected(liub, GameSim.pregame_expected(liub, hurst, false, false), "sim")
	r.check(float(away[fp.id]) < float(vs_hurst[fp.id]), "a road game expects a little less than the same game at home")
	var neutral := PlayerForm.expected(liub, GameSim.pregame_expected(liub, hurst, true, true), "sim")
	r.check(float(neutral[fp.id]) < float(vs_hurst[fp.id]) and float(neutral[fp.id]) > float(away[fp.id]), "a neutral site sits between home and away")
	# a better roster is expected more, field and keeper alike
	var cula_vs := PlayerForm.expected(cula, GameSim.pregame_expected(cula, hurst, true, false), "sim")
	var sum := func(d: Dictionary, t: PoloTeam) -> float:
		var s := 0.0
		for p: PoloPlayer in t.starters().slice(1):
			s += float(d[p.id])
		return s
	r.check(sum.call(cula_vs, cula) > sum.call(vs_hurst, liub), "CULA's seven are expected more than LIUB's against the same team")
	r.check(float(cula_vs[cula.keeper().id]) > float(vs_hurst[liub.keeper().id]), "...and CULA's keeper more than LIUB's")
	# position: a centre-defender (little shooting) is expected less from goals than a driver
	var d_def: PoloPlayer = liub.starters().filter(func(p): return p.pos == PoloPlayer.Pos.DEFENDER)[0]
	var drivers := liub.starters().filter(func(p): return p.pos == PoloPlayer.Pos.DRIVER)
	r.check(drivers.all(func(p): return PlayerForm.shot_weight(p) > PlayerForm.shot_weight(d_def)), "drivers carry more of the shooting expectation than the centre-defender")
	# deterministic
	r.check(PlayerForm.expected(liub, GameSim.pregame_expected(liub, cula, true, false), "sim") == vs_cula, "EXPECTED is the same every time for the same game")
	r.check(PlayerForm.expected(liub, [10.0, 10.0], "played") != PlayerForm.expected(liub, [10.0, 10.0], "sim"), "played and engine games have their own volumes")

## A team's BASE worked out by hand from the spec's formula: 34.5 + 13 x the seven starters'
## CURRENT stars / 7, an exact half rounded down.
func _by_hand(t: PoloTeam, heat := false) -> int:
	var total := 0.0
	for p: PoloPlayer in t.starters():
		total += p.stars + (float(PlayerForm.red_stars(p.form_state())) if heat else 0.0)
	var actual := 34.5 + 13.0 * total / 7.0
	return int(ceilf(snappedf(actual, 0.000001) - 0.5))

# 16, 17. the seed: seven starters a school (and your three subs), every OVR the school's original
func _seed() -> void:
	# (the first rosters as made: before the season's opening days play out and the AI's players
	# spend the XP they earn there)
	var c := Career.new_setup(11)
	r.check(c.teams.size() == 30, "30 schools")
	var seven := true
	var shape := true
	var ovr := true
	for id in c.teams:
		var t: PoloTeam = c.teams[id]
		var subs := c.roster_cap(id) - Career.ROSTER_MAX
		if t.roster.size() != 7 + subs or t.starters().size() != 7:
			seven = false
		var gks := t.roster.filter(func(p): return p.is_keeper()).size()
		if gks != (2 if subs > 0 else 1) or t.roster.size() - gks != (8 if subs > 0 else 6):
			shape = false
		if t.base_ovr() != int(SPEC_OVR[id]) or _by_hand(t) != int(SPEC_OVR[id]) or t.initial_strength_target != float(SPEC_OVR[id]):
			ovr = false
			print("    %s: BASE %d, by hand %d, spec %d" % [id, t.base_ovr(), _by_hand(t), SPEC_OVR[id]])
		if t.roster.any(func(p: PoloPlayer): return not is_equal_approx(p.stars, Attributes.stars_of(p.rating10()))):
			ovr = false
			print("    %s: a player's stars aren't his attributes'" % id)
	r.check(seven, "every school has its seven starters, and all seven play (yours three subs too)")
	r.check(shape, "every school: one goalkeeper and six field players (yours a backup keeper and two more)")
	r.check(ovr, "all 30 schools' seven compute to their original OVR, from stars read off their attributes")
	var liub: PoloTeam = c.teams["LIUB"]
	r.check(liub.base_ovr() == 65 and _by_hand(liub) == 65, "LIUB's first seven make 65 (%d)" % liub.base_ovr())
	var ok_pot := true
	for id in c.teams:
		for p: PoloPlayer in c.teams[id].roster:
			if p.pot_stars < p.stars or p.pot_stars > 5.0 or p.stars < 0.5 or fmod(p.stars * 2.0, 1.0) != 0.0 or fmod(p.pot_stars * 2.0, 1.0) != 0.0:
				ok_pot = false
	r.check(ok_pot, "CURRENT and POTENTIAL are 0.5-5.0 in halves, POTENTIAL never below CURRENT")
	# the stars mean something on the field: a team's ratings follow its stars
	r.check(c.teams["CULA"].power() > c.teams["HURST"].power(), "a 91 roster plays better than a 62 one")

# 11. BASE stays, LIVE moves with form: each HEAT UP star counts a whole star in the team overall
func _base_live() -> void:
	var c := Career.new_game("LIUB", "A", "B", 21)
	var t: PoloTeam = c.teams["LIUB"]
	var seven := t.starters()
	var total := 0.0
	for p: PoloPlayer in seven:
		total += p.stars
	var shows := func(extra: float) -> int: return PoloTeam.display_ovr(34.5 + 13.0 * (total + extra) / 7.0)
	seven[1].heat = 1
	seven[2].heat = 1
	r.check(t.base_ovr() == 65 and t.live_ovr() == shows.call(2.0) and t.live_ovr() > 65, "two starters HOT: BASE stays 65, LIVE %d (%d)" % [shows.call(2.0), t.live_ovr()])
	r.check(is_equal_approx(t.team_overall(false), 34.5 + 13.0 * total / 7.0), "LIVE never writes over BASE")
	seven[1].heat = 0
	seven[2].heat = 0
	for p in t.roster:
		p.form = [-1, -1, -1, -1, -1]
	r.check(t.base_ovr() == 65 and t.live_ovr() == 65, "the same two NORMAL again, however badly they played: LIVE 65, never under BASE (%d)" % t.live_ovr())
	for p in t.roster:
		p.heat = 2
	var hot_live := t.live_ovr()
	r.check(hot_live == shows.call(14.0) and hot_live > 65, "all seven VERY HOT: two whole stars each, LIUB %d (%d)" % [shows.call(14.0), hot_live])

# 12. form goes into the scoring engine exactly once
func _engine_once() -> void:
	var c := Career.new_game("LIUB", "A", "B", 31)
	var h: PoloTeam = c.teams["LIUB"]
	var a: PoloTeam = c.teams["IONA"]
	var base := GameSim.sim_ratings(h)
	r.check(GameSim.live_ratings(h) == base, "everyone NORMAL: the engine plays BASE")
	for p in h.roster:
		p.heat = 1
	var d := h.form_delta()
	var live := GameSim.live_ratings(h)
	r.check(d > 0 and is_equal_approx(float(live[1]), float(base[1]) + d) and is_equal_approx(float(live[2]), float(base[2]) + d), "the engine's form term (%d) is added to OFF and to DEF" % d)
	r.check(is_equal_approx(float(live[1]) - float(live[0]), float(base[1]) - float(base[0])), "the starters' style (OFF - OVR) is kept")
	var res := GameSim.play(h, a, 1234)
	var played: Array = res.rt   # (BASE as played, to 4 decimals: what a replay reads back)
	r.check(range(3).all(func(i): return absf(float(played[0][i]) - float(base[i])) < 0.0001) \
		and res.xg == GameSim.expected(GameSim.live_ratings(h, null, played[0]), GameSim.live_ratings(a, null, played[1]), false), "the game is played on LIVE ratings")
	var flat := GameSim.expected(base, GameSim.sim_ratings(a), false)
	r.check(float(res.xg[0]) > float(flat[0]) and float(res.xg[1]) < float(flat[1]), "a HOT team scores more and lets in less")
	# only the team delta: the engine never reads a player's form-moved ratings, and the pool never
	# reads the team's
	var sim_src := FileAccess.get_file_as_string("res://src/core/game_sim.gd")
	var opp_src := FileAccess.get_file_as_string("res://src/core/opp_sim.gd")
	r.check(not sim_src.contains(".live(") and not opp_src.contains(".live("), "the scoring engine doesn't also use players' form-moved ratings")
	var ok := true
	for f in ["play.gd", "play_ai.gd", "match_flow.gd", "keeper_duel.gd", "offense_ai.gd", "play_defense.gd"]:
		var src := FileAccess.get_file_as_string("res://src/match/" + f)
		if src.contains("live_ratings") or src.contains("form_delta") or src.contains("live_ovr"):
			ok = false
	r.check(ok, "a game played in the pool uses each man's own form, never the team's LIVE too")
	# a weak hot school is still not an elite one
	var cula: PoloTeam = c.teams["CULA"]
	for p in h.roster:
		p.heat = 2
	var vs := GameSim.expected(GameSim.live_ratings(h), GameSim.live_ratings(cula), true)
	r.check(float(vs[0]) < float(vs[1]), "LIUB all VERY HOT is still expected to lose to CULA on neutral water")

# 18. form and grading never change a game's goals or the scorekeeping
func _goals_unchanged() -> void:
	var c := Career.new_game("WAGN", "A", "B", 41)
	var ids: Array = c.teams.keys()
	var same := true
	var lines_ok := true
	for i in 60:
		var h: PoloTeam = c.teams[ids[i % ids.size()]]
		var a: PoloTeam = c.teams[ids[(i * 7 + 3) % ids.size()]]
		if h == a:
			continue
		var seed_value := 900 + i
		var res := GameSim.play(h, a, seed_value)
		# the score the engine made before any stat lines existed: the same dice, the same order
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		var sc := GameSim.score(GameSim.expected(GameSim.sim_ratings(h), GameSim.sim_ratings(a), false), rng)
		if sc.s != res.score:
			same = false
		var again := GameSim.play(h, a, seed_value)
		if again.score != res.score or again.saves != res.saves or again.goals != res.goals:
			same = false
		for side in 2:
			var team: PoloTeam = h if side == 0 else a
			var lines: Dictionary = res.lines[side]
			var g := 0
			for id in lines:
				g += int(lines[id].get("g", 0))
				if int(lines[id].ga) != int(res.score[1 - side]):
					lines_ok = false
				if not lines[id].get("gk", false) and int(lines[id].sh) < int(lines[id].g):
					lines_ok = false
			if g != int(res.score[side]) or int(lines[team.keeper().id].sv) != int(res.saves[side]) or lines.size() != 7:
				lines_ok = false
	r.check(same, "NORMAL form: every engine score is exactly what it was before stat lines and form")
	r.check(lines_ok, "stat lines add up: goals to the score, saves to the keeper, goals against to every man")
	# the played game's box: the same counts the scoreboard has
	var st := MatchState.new()
	var us: PoloTeam = c.teams["WAGN"]
	var them: PoloTeam = c.teams["IONA"]
	var s1: PoloPlayer = us.starters()[2]
	st.add_goal(0, s1)
	st.shot_by[0].append(s1)
	st.shot_by[0].append(s1)
	st.add_goal(1, them.starters()[1])
	st.saves[0] = 4
	st.block_by[0].append(us.starters()[3])
	st.excl_drawn_by[0].append(us.starters()[1])
	var bx := st.box(us, them)
	var mine: Dictionary = bx.lines[0]
	r.check(int(mine[s1.id].g) == 1 and int(mine[s1.id].sh) == 2 and int(mine[s1.id].ga) == 1, "a played game's line: his goals, his shots, the goals against")
	r.check(int(mine[us.keeper().id].sv) == 4 and int(mine[us.starters()[3].id].bl) == 1 and int(mine[us.starters()[1].id].ed) == 1, "...the keeper's saves, blocks and exclusions drawn")
	r.check(bx.score == [1, 1] and (bx.lines[1] as Dictionary).size() == 7, "the box score is untouched, and the other seven get lines too")

# form in a game played in the pool: shooting, passing, defence, blocks, keeping
func _in_the_pool() -> void:
	var hot := _player(3.0)
	hot.heat = 2
	var warm := _player(3.0)
	warm.heat = 1
	var flat := _player(3.0)
	flat.form = [-1, -1, -1, -1, -1]
	r.check(is_equal_approx(hot.live("shoot"), 60.0 + PlayerForm.RATING_PER_STAR) and is_equal_approx(warm.live("passing"), 60.0 + PlayerForm.RATING_PER_STAR * 0.5),
		"VERY HOT +%d to his ratings in play, HOT +%d" % [int(PlayerForm.RATING_PER_STAR), int(PlayerForm.RATING_PER_STAR * 0.5)])
	r.check(is_equal_approx(flat.live("defense"), 60.0) and hot.shoot == 60, "NORMAL plays his ratings (bad games never lower them); form never writes over them")
	var b_hot := ShotModel.blocker(Vector2(5, 10), hot)
	var b_flat := ShotModel.blocker(Vector2(5, 10), flat)
	var reach_hot := float(ShotModel.block_reach(b_hot, Vector2(8, 10), 4.0, 12.0).reach)
	var reach_flat := float(ShotModel.block_reach(b_flat, Vector2(8, 10), 4.0, 12.0).reach)
	r.check(reach_hot > reach_flat, "a HOT defender gets more of a hand to a shot (block reach %.2f vs %.2f)" % [reach_hot, reach_flat])
	var gk_hot := _player(3.0, PoloPlayer.Pos.GK)
	gk_hot.heat = 2
	var gk_flat := _player(3.0, PoloPlayer.Pos.GK)
	var dh := KeeperDuel.new().setup_given(gk_hot, Vector2(8, 10), 10.5, 0.6, Geo.GOAL_X, 10.0, 0.0)
	var dc := KeeperDuel.new().setup_given(gk_flat, Vector2(8, 10), 10.5, 0.6, Geo.GOAL_X, 10.0, 0.0)
	r.check(dh.reach > dc.reach, "your keeper VERY HOT reaches further than NORMAL (%.2f vs %.2f)" % [dh.reach, dc.reach])
	# shots: the same shot, hotter shooter, more goals (ShotModel takes the form-moved skill)
	var rng := RandomNumberGenerator.new()
	var goals := [0, 0]
	var spots := [Vector2(5.5, 8.5), Vector2(4.0, 10.0), Vector2(7.0, 7.0), Vector2(6.0, 12.5)]
	for i in 3000:
		for k in 2:
			rng.seed = 100 + i
			var skill := (hot if k == 0 else flat).live("shoot")
			# (into the corner: their keeper reads the ball now, so a tidier shot at one he can reach is just a save)
			var res := ShotModel.resolve(spots[i % spots.size()], 11.3, 0.9, skill, 3.0, [], 10.0, 60.0, rng)
			if String(res.outcome) == "goal":
				goals[k] += 1
	r.check(goals[0] > goals[1], "a VERY HOT shooter scores more of the same shots than a NORMAL one (%d vs %d of 3000)" % goals)
	var play_src := FileAccess.get_file_as_string("res://src/match/play.gd")
	var attr_src := FileAccess.get_file_as_string("res://src/core/attributes.gd")
	r.check(play_src.contains("player.live(\"shoot\")") and play_src.contains("player.live(\"keeping\")") and play_src.contains("player.live(\"passing\")")
		and play_src.contains("Attributes.eff_defense_legacy(") and attr_src.contains("d.live(\"defense\")"),
		"the pool's shots, saves, passes and steals take each man's form")

# 13. the roster's colours and the one star bar
func _colors() -> void:
	var roster_screen = load("res://src/ui/screens/roster.gd")
	var cases := [[2, PlayerForm.FIRE_RED, "VERY HOT"], [1, PlayerForm.FIRE_RED, "HOT"], [0, PlayerForm.GOLD, ""]]
	for cs in cases:
		var p := _player(3.0)
		p.pot_stars = 4.5
		p.heat = int(cs[0])
		var line: Dictionary = roster_screen.star_line(p)
		var nm: String = cs[2] if cs[2] != "" else "NORMAL"
		r.check(line.color == cs[1] and line.word == cs[2], "the form %s is %s" % [nm, "fiery red" if cs[1] == PlayerForm.FIRE_RED else "gold"])
		r.check(is_equal_approx(line.cur, 3.0) and is_equal_approx(line.pot, 4.5) and is_equal_approx(line.eff, p.eff_stars()), "the bar carries CURRENT, POTENTIAL, EFFECTIVE (%s)" % nm)
	# the unified star bar: five places, gold CURRENT, then his red HOT stars straight after the
	# gold, then empty POTENTIAL. _row: G gold, R red, . empty, a place a token; lower case a half
	r.check(_row(3.0, 5.0, 0) == "G G G . .", "3 stars NORMAL: 3 gold, 2 empty")
	r.check(_row(3.0, 5.0, 1) == "G G G R .", "3 stars HOT: 3 gold, a red star straight after them")
	r.check(_row(3.0, 5.0, 2) == "G G G R R", "3 stars VERY HOT: 3 gold, two red stars")
	r.check(_row(2.5, 5.0, 1) == "G G g R .", "2.5 stars HOT: a whole red star in the next place after the gold")
	r.check(_row(5.0, 5.0, 2) == "G G G G G R R", "a five-star VERY HOT: five gold, then two red (seven places)")
	r.check(_row(5.0, 5.0, 1) == "G G G G G R", "a five-star HOT: five gold, then one red (six places)")
	r.check(_row(4.0, 5.0, 2) == "G G G G R R", "a four-star VERY HOT: four gold, then two red (the gold never gives way)")
	r.check(_row(1.0, 2.0, 1) == "G R", "a one-star HOT: his red star in the place after the gold (the bar ends at his POTENTIAL)")
	var f4 := Deck.star_fills(3.0, 4.0, 0)
	r.check(f4.size() == 4 and f4[3].pot == 1.0, "3 of 4 POTENTIAL: four places, no fifth past his POTENTIAL")
	var hot4 := Deck.star_fills(3.0, 4.0, 1)
	r.check(hot4.size() == 4 and hot4[3].pot == 1.0 and float(hot4[3].gold) == 0.0, "red is temporary: POTENTIAL and CURRENT read the same under it")
	var all_five := true
	for ci in range(0, 11):
		for pi in range(ci, 11):
			for red in 3:
				var fs := Deck.star_fills(ci * 0.5, pi * 0.5, red)
				var lit := 0.0
				for f in fs:
					lit += maxf(float(f.gold), float(f.form))
				if fs.size() != Deck.star_count(ci * 0.5, pi * 0.5, red) or fs.size() > Deck.STAR_PLACES + red or not is_equal_approx(lit, ci * 0.5 + red):
					all_five = false
	r.check(all_five, "every CURRENT x POTENTIAL x form: star_count places (five plus his red at most), lit = his gold + his red")
	var src := FileAccess.get_file_as_string("res://src/ui/deck.gd") + FileAccess.get_file_as_string("res://src/ui/star_fx.gd")
	r.check(not src.contains("ICE_STAR") and not src.contains("ICE_COLS") and not src.contains("FORM_PLACES") and not src.contains("COLD"),
		"no frozen stars, cold colours or form place left in the star bar")
	r.check(not src.contains("FLAME") and not src.contains("FROST :=") and not src.contains("snowflake"), "no flame or snowflake icons left in the star bar")

## A bar as tokens, a place each: G gold, R red, . empty; lower case for a half (gR: half gold,
## then red).
func _row(cur: float, pot: float, red: int) -> String:
	var out: Array = []
	for f in Deck.star_fills(cur, pot, red):
		var g := float(f.gold)
		var fm := float(f.form) if float(f.form) > g else 0.0
		if g >= 0.99:
			out.append("G")
		elif g > 0.0:
			out.append("g" + ("R" if fm >= 0.99 else ""))
		elif fm >= 0.99:
			out.append("R")
		elif fm > 0.0:
			out.append("r")
		else:
			out.append(".")
	return " ".join(out)

# 14. saves keep everything: stars, the grades, the form
func _saves() -> void:
	var c := Career.new_game("GWU", "A", "B", 51)
	for _w in 5:
		while c.has_game():
			c.sim_my_game()
		c.queue.clear()
		c.end_week()
	var before := {}
	var any := false
	for id in c.teams:
		for p: PoloPlayer in c.teams[id].roster:
			before[p.id] = [p.stars, p.pot_stars, p.form.duplicate(), p.form_state(), p.eff_stars(), p.last_game.duplicate(), p.heat]
			if p.form_state() != PlayerForm.NORMAL:
				any = true
	r.check(any, "a few weeks in, some players are HOT")
	var text := JSON.stringify(c.to_dict())
	var c2 := Career.from_dict(JSON.parse_string(text))
	var same := true
	for id in c2.teams:
		for p: PoloPlayer in c2.teams[id].roster:
			var b: Array = before[p.id]
			if not is_equal_approx(p.stars, b[0]) or not is_equal_approx(p.pot_stars, b[1]) or p.form != b[2] or p.form_state() != b[3] or not is_equal_approx(p.eff_stars(), b[4]) or p.heat != int(b[6]):
				same = false
			if p.last_game.size() != (b[5] as Dictionary).size() or (not p.last_game.is_empty() and (not is_equal_approx(float(p.last_game.pm), float(b[5].pm)) or int(p.last_game.gr) != int(b[5].gr))):
				same = false
	r.check(same, "saved and loaded: CURRENT, POTENTIAL, the last grades, heat and EFFECTIVE all come back")
	r.check(JSON.stringify(c2.to_dict()) == text, "the save round-trips exactly")
	r.check(not c2.trimmed and not c2.rated, "a current save loads as it is")
	var t1: PoloTeam = c.team()
	var t2: PoloTeam = c2.team()
	r.check(t1.live_ovr() == t2.live_ovr() and t1.base_ovr() == t2.base_ovr(), "BASE and LIVE are the same after loading (%d / %d)" % [t2.base_ovr(), t2.live_ovr()])

# 15. older saves: 18-man rosters and no stars or form
func _old_saves() -> void:
	var c := Career.new_game("BUCK", "A", "B", 61)
	for id in c.teams:
		var t: PoloTeam = c.teams[id]
		CollegeGen.make_roster_18(t, c.rng, c.new_id, float(Colleges.school(id).ovr))
		t.lineup = []
	var d := c.to_dict()
	d.v = 6
	for id in d.teams:
		for pd in d.teams[id].roster:
			for k in ["stars", "pot_stars", "star_base", "form", "last_game", "attrs", "attr_pot", "stars_locked"]:
				pd.erase(k)
	var starters := {}
	var ratings := {}
	for id in c.teams:
		# (who starts as the old save's players are read in: converted from their ratings)
		starters[id] = PoloTeam.from_dict(JSON.parse_string(JSON.stringify(d.teams[id]))).starters().map(func(p): return p.id)
		ratings[id] = PoloTeam.from_dict(JSON.parse_string(JSON.stringify(d.teams[id]))).base_ovr()
	var old := Career.from_dict(JSON.parse_string(JSON.stringify(d)))
	var seven := true
	var kept := true
	var rated := true
	var normal := true
	for id in old.teams:
		var t: PoloTeam = old.teams[id]
		if t.roster.size() != old.roster_cap(id) or t.roster.filter(func(p): return p.is_keeper()).size() < 1 or t.roster.filter(func(p): return p.is_keeper()).size() > old.keeper_cap(id):
			seven = false
		var now := t.roster.map(func(p): return p.id)
		for e in starters[id]:
			if not now.has(e):
				kept = false
		if t.base_ovr() != ratings[id]:
			rated = false
		for p: PoloPlayer in t.roster:
			if p.form_state() != PlayerForm.NORMAL or not p.form.is_empty() or p.stars < 0.0 or p.pot_stars < p.stars or p.attrs.size() != 4:
				normal = false
	r.check(old.trimmed, "an 18-man save is converted (and so backed up by Game.load_career)")
	r.check(seven, "an older save's rosters become seven, one keeper and six field players (yours ten: a bench)")
	r.check(kept, "the seven kept are the starting seven")
	r.check(rated, "every team overall is still its starting seven's")
	r.check(normal, "everyone gets stars from his ratings and starts NORMAL")
	var schol := true
	for id in old.teams:
		if old.teams[id].roster.filter(func(p): return p.schol).size() > Career.SCHOL_MAX:
			schol = false
	r.check(schol, "no more scholarships than the seven-man program has")
	var again := Career.from_dict(JSON.parse_string(JSON.stringify(old.to_dict())))
	r.check(JSON.stringify(again.to_dict()) == JSON.stringify(old.to_dict()), "the converted save round-trips")
	# and plays on: a week's games, graded
	while old.has_game():
		old.sim_my_game()
	r.check(old.team().starters().all(func(p): return not p.last_game.is_empty()), "the converted career's starters are graded after a game (the bench sits out)")

## A save from before two-level heat: its three grades (cold ones too) and no "heat". It loads
## with no cold form, HOT only for a real run, and everything else exactly as saved.
func _legacy_form() -> void:
	var c := Career.new_game("CUSD", "A", "B", 91)
	var t: PoloTeam = c.team()
	var olds := [[[1, 1, 1], "on_fire", 1], [[1], "hot", 0], [[1, 1, 0], "hot", 0], [[-1, -1, -1], "ice_cold", 0], [[-1], "cold", 0], [[], "normal", 0]]
	var d := c.to_dict()
	var before := {}
	for i in olds.size():
		var pd: Dictionary = d.teams[c.school].roster[i]
		pd.form = olds[i][0]
		pd.erase("heat")
		pd.last_game = {"raw": 1.0, "exp": 0.0, "pm": 1.0, "gr": 0, "was": olds[i][1], "g": 1, "bl": 0, "ed": 0}
		before[int(pd.id)] = [pd.stars, pd.pot_stars, pd.attrs.duplicate(), pd.attr_pot.duplicate()]
	var back := Career.from_dict(JSON.parse_string(JSON.stringify(d)))
	var ok := true
	var kept := true
	for i in olds.size():
		var p: PoloPlayer = back.team().find_id(int(d.teams[c.school].roster[i].id))
		if p.heat != int(olds[i][2]) or p.form != olds[i][0] or not PlayerForm.FORM_NAMES.has(String(p.last_game.was)):
			ok = false
			print("    legacy %s: heat %d, was %s" % [olds[i][0], p.heat, p.last_game.was])
		var b: Array = before[p.id]
		if not is_equal_approx(p.stars, float(b[0])) or not is_equal_approx(p.pot_stars, float(b[1])):
			kept = false
	r.check(ok, "an old save's form loads safely: ON FIRE (three GOOD) is HOT, the rest (COLD and ICE COLD too) NORMAL")
	r.check(kept, "...and every player's CURRENT and POTENTIAL stars exactly as saved")
	r.check(back.team().roster.all(func(p): return p.eff_stars() >= p.stars), "nobody loads below his own stars")
	var again := Career.from_dict(JSON.parse_string(JSON.stringify(back.to_dict())))
	r.check(JSON.stringify(again.to_dict()) == JSON.stringify(back.to_dict()), "the loaded old save round-trips")

# 9, 10, 16. a season: CURRENT, POTENTIAL and BASE stay put, every man is graded every game;
# then the lock: seven again, development into the stars, BASE from the stars, form reset
func _season() -> void:
	var c := Career.new_game("LIUB", "A", "B", 71)
	Game.career = c
	var stars := {}
	for id in c.teams:
		for p: PoloPlayer in c.teams[id].roster:
			stars[p.id] = [p.stars, p.pot_stars]
	var graded := true
	var live_moved := false
	var states := {}
	var weeks := 0
	while c.phase == "season" and weeks < 30:
		weeks += 1
		c.queue.clear()
		while c.has_game():
			var out := c.sim_my_game()
			if (out.form as Array).size() != 7:
				graded = false
		for id in c.teams:
			var t: PoloTeam = c.teams[id]
			if t.live_ovr() != t.base_ovr():
				live_moved = true
			for p: PoloPlayer in t.roster:
				states[p.form_state()] = int(states.get(p.form_state(), 0)) + 1
				if p.form.size() > PlayerForm.FORM_GAMES:
					graded = false
		if c.week < Schedule.REGULAR_WEEKS:
			for id in c.teams:
				for p: PoloPlayer in c.teams[id].roster:
					if p.last_game.is_empty() and int(p.stats.get("gp", 0)) > 0:
						graded = false
		c.end_week()
	# (2.0: CURRENT is his attributes' average, so practice moves it during the season; games
	# never do, and nothing moves POTENTIAL, his ceilings)
	var unchanged := true
	for id in c.teams:
		for p: PoloPlayer in c.teams[id].roster:
			if stars.has(p.id) and (not is_equal_approx(p.pot_stars, stars[p.id][1]) or p.stars > p.pot_stars + 1e-6 or not is_equal_approx(p.stars, Attributes.stars_of(p.rating10()))):
				unchanged = false
	r.check(unchanged, "a whole season never moves a player's POTENTIAL; CURRENT is always his attributes' stars")
	var base_same := true
	for id in c.teams:
		if c.teams[id].base_ovr() != _by_hand(c.teams[id]) or c.teams[id].live_ovr() != _by_hand(c.teams[id], true):
			base_same = false
	r.check(base_same and c.rating_history.size() >= 1, "BASE and LIVE OVR are always the seven starters' (34.5 + 13 x stars / 7), whatever the results")
	r.check(graded, "every player is graded after every game (form never more than five games)")
	r.check(live_moved, "LIVE OVR moves away from BASE as form comes and goes")
	print("    form states over the season: %s" % states)
	r.check(int(states.get("hot", 0)) > 0 and int(states.get("normal", 0)) > 0, "HOT and NORMAL both come up")
	r.check(states.keys().all(func(k): return PlayerForm.FORM_NAMES.has(k)), "no COLD form ever")
	r.check(int(states.get("very_hot", 0)) * 4 < int(states.get("hot", 0)), "VERY HOT is much rarer than HOT over a season")
	# through the off-season to the lock
	var guard := 0
	var label := c.season_label()
	while c.season_label() == label and guard < 30:
		guard += 1
		c.queue.clear()
		c.end_week()
	var ok7 := true
	var star_base := true
	var reset := true
	for id in c.teams:
		var t: PoloTeam = c.teams[id]
		if t.roster.size() < 7 or t.roster.size() > c.roster_cap(id) or t.roster.filter(func(p): return p.is_keeper()).size() < 1 or t.roster.filter(func(p): return p.is_keeper()).size() > c.keeper_cap(id):
			ok7 = false
		if t.base_ovr() != _by_hand(t):
			star_base = false
		for p: PoloPlayer in t.roster:
			# (the league's first day may already be played: those players have a grade)
			if p.pot_stars < p.stars or (int(p.stats.get("gp", 0)) == 0 and (not p.form.is_empty() or not p.last_game.is_empty())):
				reset = false
	r.check(ok7, "after the lock: every roster seven again, one keeper and six field players")
	r.check(star_base, "next season's BASE OVR is the new seven's CURRENT stars (34.5 + 13 x stars / 7)")
	r.check(reset, "a new season starts everyone NORMAL with no grades")
	r.check(c.team().roster.all(func(p): return p.form.is_empty() and p.heat == 0 and p.form_state() == PlayerForm.NORMAL), "your seven start the new season NORMAL")
	var grew := 0
	for id in c.teams:
		for p: PoloPlayer in c.teams[id].roster:
			if stars.has(p.id) and p.stars > float(stars[p.id][0]):
				grew += 1
	r.check(grew > 0, "development at the lock moved some returning players' stars (%d)" % grew)
	Game.career = null

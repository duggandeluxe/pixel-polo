extends RefCounted
## The Long-Term Player Development Update: a token costs CEIL(450 x 1.38^n), n levels into the
## player's development (his first is n = 0), instead of 76 x 1.11^hidden level. XP rewards,
## class multipliers, training and potential untouched; old saves keep their attributes, levels
## and tokens, their XP converted to the same share of the next token. Then whole simmed seasons
## (dev_career_test) against the four-year targets.
##   godot --headless --path game -- --test long_term_dev

const ROSTER := preload("res://src/ui/screens/roster.gd")

var r

func run(runner) -> void:
	r = runner
	print("long-term development")
	_curve()
	_rewards()
	_tokens()
	_training()
	_saves()
	_roster_bar()
	_careers(runner)

# ------------------------------------------------------------------ 1, 2: the curve
func _curve() -> void:
	var ok := true
	var steeper := true
	for n in 21:
		var v := Development.xp_required(n)
		ok = ok and v == ceili(snappedf(450.0 * pow(1.38, n) * Development.req_mod(n), 0.000001))
		steeper = steeper and v >= 3 * Development.old_xp_required(n)
		if n > 0:
			ok = ok and float(v) / Development.xp_required(n - 1) > 1.3 and float(v) / Development.xp_required(n - 1) < 1.39
	r.check(ok, "1: CEIL(450 x 1.38^n x the maturity modifier): still about 1.38 a level (518, 691, 922 ...)")
	r.check(steeper, "1: at least three times the old curve at every level (n 0-20)")
	r.check(Development.xp_required(5) > 2 * Development.xp_required(2) and Development.xp_required(10) > 4 * Development.xp_required(5),
		"2: exponential: later levels far dearer than early ones, never flat")
	# every new player's first token is level 0, whatever his attributes
	var c := Career.new_game("STAM", "A", "B", 31)
	var all_zero := true
	for id in c.teams:
		for p in (c.teams[id] as PoloTeam).roster:
			all_zero = all_zero and Development.level_index(p) == 0 and Development.xp_needed(p) == Development.xp_required(0)
	r.check(all_zero, "2: every player in a new career: his first token costs the curve's first (%d, level 0)" % Development.xp_required(0))
	var p := _field(7.0)
	r.check(p.xp_level == Development.initial_level(p) and Development.level_index(p) == 0, "2: the hidden level still starts from his attributes; the curve counts from there")

# ------------------------------------------------------------------ 10, 11: rewards untouched
func _rewards() -> void:
	var D := Development
	r.check([D.GOAL_XP, D.ASSIST_XP, D.STEAL_XP, D.BLOCK_XP, D.DRAWN_EXCLUSION_XP, D.DRAWN_PENALTY_XP, D.TURNOVER_XP,
		D.EXCLUSION_COMMITTED_XP, D.GOALKEEPER_SAVE_XP, D.GOAL_CONCEDED_XP, D.PARTICIPATION_XP, D.WIN_BONUS_XP]
		== [20, 15, 14, 14, 10, 18, -4, -4, 10, -1, 8, 8], "10: every game XP reward as it was")
	r.check(D.CLASS_XP_PCT == [100, 80, 95, 110, 125], "11: class multipliers FR 80 / SO 95 / JR 110 / SR 125 (Development Maturity)")
	var p := _field(5.0)
	var line := {"g": 2, "a": 1, "st": 1, "to": 1}
	var base := 8 + 8 + 40 + 15 + 14 - 4
	var got := []
	for y in [1, 2, 3, 4]:
		p.year = y
		got.append(D.game_xp(p, line, true))
	r.check(D.base_game_xp(p, line, true) == base and got == [(base * 80 + 50) / 100, (base * 95 + 50) / 100, (base * 110 + 50) / 100, (base * 125 + 50) / 100],
		"11: a game pays the same XP as before, year by year (%s)" % str(got))
	r.check([D.BALANCED_TRAINING_XP, D.SPECIALIZED_BASE_XP, D.SPECIALIZED_WEAKNESS_MULTIPLIER, D.GOALKEEPER_SHOOTING_TRAINING_XP]
		== [12, 8, 2, 5] and D.XP_MULT == [0.0, 0.75, 1.0, 1.5] and D.INJURY_RISK == [0.0, 0.01, 0.03, 0.08],
		"9: training XP, intensities and injury risks as they were")

# ------------------------------------------------------------------ 14: one threshold, one token
func _tokens() -> void:
	var p := _field(4.0)
	var lv := p.xp_level
	var n0 := Development.xp_required(0)
	var n1 := Development.xp_required(1)
	r.check(Development.award_xp(p, n0 - 1) == 0 and p.tokens == 0 and p.xp == n0 - 1, "14: %d XP: no token yet" % (n0 - 1))
	r.check(Development.award_xp(p, 1) == 1 and p.tokens == 1 and p.xp == 0 and p.xp_level == lv + 1, "14: the %dth: exactly one token, one level" % n0)
	r.check(Development.xp_needed(p) == n1, "14: the next costs %d" % n1)
	var a0 := Attributes.value(p, "sho")
	Development.spend(p, "sho")
	r.check(is_equal_approx(Attributes.value(p, "sho"), a0 + 1.0) and p.tokens == 0 and Development.xp_needed(p) == n1,
		"14: spending it: one point; the next requirement unchanged by the spend")
	var q := _field(4.0)
	r.check(Development.award_xp(q, n0 + n1 + Development.xp_required(2) + 3) == 3 and q.xp == 3, "14: three thresholds in one award: three tokens, nothing doubled")
	# a player near his ceilings still stops there (potential untouched)
	var m := _p({"pas": 6, "sho": 6, "str": 6, "dfn": 6}, false, {"pas": 7, "sho": 6, "str": 6, "dfn": 6})
	var pots := m.attr_pot.duplicate()
	Development.award_xp(m, 100000)
	r.check(m.tokens == 1 and m.xp == 0 and m.attr_pot == pots, "12: one box left: one token, ceilings unchanged")

# ------------------------------------------------------------------ 9: training on the new curve
func _training() -> void:
	var c := Career.new_game("GWU", "A", "B", 909)
	Game.career = c
	c.training = {"focus": "balanced", "intensity": 3}
	var p: PoloPlayer = c.team().roster[3]
	var q: PoloPlayer = c.team().roster[4]
	for x in [p, q]:
		_roomy(x)
		x.tokens = 0
	var week := Development.training_xp(p, "balanced", 3)
	p.xp = Development.xp_required(0) - week
	q.xp = Development.old_xp_required(q.xp_level) - week   # (a token on the old curve, not now)
	var rep := c.train_week()
	r.check(int(rep.xp.get(p.id, 0)) == week and week == 18, "9: a HARD balanced week pays 18 XP, as before")
	r.check(p.tokens == 1 and p.xp == 0, "9: training XP reaching his first threshold: his first token")
	r.check(q.tokens == 0 or Development.old_xp_required(q.xp_level - 1) >= Development.xp_required(0), "9: what the old curve's threshold was no longer pays a token")
	# a season of the hardest training alone: at most one or two tokens, nowhere near his ceilings
	var b := _field(3.0)
	var weeks := 0
	for i in 20:
		Development.award_xp(b, Development.training_xp(b, "shooting", 3))
		weeks += 1
	r.check(b.tokens <= 1, "9: 20 weeks of the hardest focused training: %d token(s) (it can't skip the curve)" % b.tokens)
	Game.career = null

# ------------------------------------------------------------------ 15, 16: saves
func _saves() -> void:
	var c := Career.new_game("STAM", "A", "B", 1515)
	var p: PoloPlayer = c.team().roster[2]
	_roomy(p)
	# an old save: two points bought, a token held, XP halfway to the old curve's next
	var d := p.to_dict()
	var dev: Dictionary = d.development
	dev.erase("level_start")
	var lvl := Development.initial_level(p) + 4
	dev["hidden_level"] = lvl
	dev["available_upgrade_tokens"] = 1
	dev["current_xp"] = Development.old_xp_required(lvl) / 2
	var keep := [d.attrs.duplicate(), d.attr_pot.duplicate(), d.stars, d.pot_stars]
	var q := PoloPlayer.from_dict(d)
	r.check([q.attrs, q.attr_pot, q.stars, q.pot_stars] == keep and q.xp_level == lvl and q.tokens == 1,
		"15: an old save: attributes, ceilings, stars, hidden level and token exactly as saved")
	r.check(absf(Development.progress(q) - 0.5) < 0.01, "16: halfway to his next token stays halfway (%.3f)" % Development.progress(q))
	r.check(Development.level_index(q) >= 1 and q.xp_start <= q.xp_level, "16: the levels he has earned count (index %d)" % Development.level_index(q))
	var back := PoloPlayer.from_dict(q.to_dict())
	r.check(back.xp_start == q.xp_start and back.xp == q.xp and back.xp_level == q.xp_level, "16: saved again: no second conversion")
	# a fully developed player in an old save: still fully developed, nothing banked
	var m: PoloPlayer = c.team().roster[5]
	for k in m.key_ratings():
		m.attr_pot[k] = m.attrs[k]
	Attributes.sync(m)
	var md := m.to_dict()
	md.development.erase("level_start")
	md.development["current_xp"] = 0
	var m2 := PoloPlayer.from_dict(md)
	r.check(Development.is_maxed(m2) and m2.xp == 0 and m2.tokens == 0 and m2.attrs == m.attrs, "15: a maxed player in an old save stays exactly as he was")
	# a save from before XP development (no entry at all): starts at level 0
	var od := p.to_dict()
	od.erase("development")
	var o := PoloPlayer.from_dict(od)
	r.check(Development.level_index(o) == 0 and o.xp == 0, "15: an older save still: development from level 0")
	# a whole career through save and load
	var c2 := Career.from_dict(c.to_dict())
	if true:
		var same := true
		for i in c.team().roster.size():
			var a: PoloPlayer = c.team().roster[i]
			var b: PoloPlayer = c2.team().roster[i]
			same = same and a.xp == b.xp and a.xp_level == b.xp_level and a.xp_start == b.xp_start and a.attrs == b.attrs
		r.check(same, "15: a career saved and loaded: every player's development the same")

# ------------------------------------------------------------------ 17: roster bars
func _roster_bar() -> void:
	var p := _field(5.0)
	Development.award_xp(p, Development.xp_required(0) + 310)
	r.check(is_equal_approx(ROSTER.xp_fill(p), 1.0), "17: an unspent token keeps the bar full (as before)")
	Development.spend(p, "sho")
	var nxt := float(Development.xp_required(1))
	r.check(is_equal_approx(ROSTER.xp_fill(p), 310.0 / nxt) and is_equal_approx(Development.progress(p), 310.0 / nxt),
		"17: spent: the roster's XP bar reads 310 / %d toward the next (the adjusted requirement)" % int(nxt))
	r.check(is_equal_approx(ROSTER.xp_fill(p), 1.0) == false, "17: not full until the next threshold")

# ------------------------------------------------------------------ 3-8, 12, 13: four-year careers
func _careers(runner) -> void:
	var o: Dictionary = load("res://tests/dev_career_test.gd").report(runner, 5, 4040)
	var strong: Array = o.get("1 strong starter", [])
	var avg: Array = o.get("2 average starter", [])
	var bench: Array = o.get("3 bench", [])
	var gk: Array = o.get("4 GK strong starter", [])
	var gk2: Array = o.get("5 GK average/backup", [])
	var mid: Array = o.get("room c 4-8 starter", [])
	var high: Array = o.get("room d 9+ all", [])
	var mid_gk: Array = o.get("room c 4-8 GK", [])
	if strong.is_empty() or avg.is_empty() or bench.is_empty() or gk.is_empty() or mid.is_empty() or high.is_empty():
		r.check(false, "careers: every career type present")
		return
	r.check(float(o.fr4_maxed) < 0.10, "4: freshmen with room to grow (4+ upgrades) rarely max out in year one (%d%%)" % roundi(100.0 * o.fr4_maxed))
	r.check(strong[0].up >= 1.5 and mid[0].up >= 1.5, "3: strong freshmen still earn upgrades (%.1f; moderate-room starters %.1f)" % [strong[0].up, mid[0].up])
	r.check(mid[0].maxed < 0.25, "4: a typical starter (4-8 room) is rarely maxed after year one (%d%%)" % roundi(100.0 * mid[0].maxed))
	r.check(mid[1].used > mid[0].used + 0.1 and mid[2].used > mid[1].used + 0.05 and avg[1].up + avg[2].up >= 1.0,
		"5: sophomore and junior years still move him on (%d%% -> %d%% -> %d%% of his room)" % [roundi(mid[0].used * 100), roundi(mid[1].used * 100), roundi(mid[2].used * 100)])
	r.check(mid[3].maxed > 0.25 and mid[3].maxed < 0.95, "6: some seniors reach their potential, not all (%d%% of moderate-room starters)" % roundi(100.0 * mid[3].maxed))
	r.check(high[3].maxed < 0.25, "6: a high-ceiling player rarely fills it in four years (%d%%)" % roundi(100.0 * high[3].maxed))
	var b_ups := 0.0
	var s_ups := 0.0
	for y in 4:
		b_ups += float(bench[y].up)
		s_ups += float(strong[y].up)
	r.check(b_ups >= 0.5 and b_ups < s_ups, "7: bench players develop slower than starters, not never (%.1f vs %.1f upgrades)" % [b_ups, s_ups])
	r.check(gk[0].up >= 1.0 and (mid_gk.is_empty() or mid_gk[0].maxed < 0.25), "8: starting keepers develop, rarely maxed in year one (%.1f upgrades)" % gk[0].up)
	var g_ups := 0.0
	for y in 4:
		g_ups += float(gk2[y].up)
	r.check(g_ups >= 0.5, "8: even a backup keeper develops over four years (%.1f)" % g_ups)
	var poss := ["2MD", "ATK", "C", "GK", "UT", "WG"]
	var dev_all := poss.all(func(k): return o.has("pos " + k) and float(o["pos " + k].up) > 0.3)
	r.check(dev_all, "8: every position develops in its freshman year (%s)" % ", ".join(poss.map(func(k): return "%s %.1f" % [k, float(o.get("pos " + k, {}).get("up", 0.0))])))
	r.check(int(o.ceilings_changed) == 0, "12: no ceiling moved in five seasons (%d)" % int(o.ceilings_changed))

# ------------------------------------------------------------------ helpers
func _p(vals: Dictionary, keeper := false, pots := {}) -> PoloPlayer:
	var p := AttrBench.player(vals, keeper, pots, PoloPlayer.Pos.UTILITY)
	p.id = 1 + randi() % 100000
	Development.ensure(p)
	return p

func _field(v: float, pot: float = 10.0) -> PoloPlayer:
	return _p({"pas": v, "sho": v, "str": v, "dfn": v}, false, {"pas": pot, "sho": pot, "str": pot, "dfn": pot})

func _roomy(p: PoloPlayer) -> void:
	for k in p.key_ratings():
		p.attr_pot[k] = minf(Attributes.MAX, maxf(float(p.attr_pot[k]), p.attrs[k] + 4.0))
	Attributes.sync(p)

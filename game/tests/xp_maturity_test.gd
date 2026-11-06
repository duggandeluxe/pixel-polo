extends RefCounted
## The Player Development Maturity & XP Curve Rebalance: class multipliers FR 80 / SO 95 / JR 110 /
## SR 125 (game XP, as before), and the curve's requirement x 1.15 at his first token easing evenly
## to x 0.85 from Development.REQ_REF_LEVELS levels in, on top of CEIL(450 x 1.38^n). Saves keep
## each player's share of the way to his next token.
##   godot --headless --path game -- --test xp_maturity

var r

func run(runner) -> void:
	r = runner
	print("xp maturity")
	_multipliers()
	_curve()
	_separate()
	_leveling()
	_saves()

func _field(v: float, year := 1) -> PoloPlayer:
	var p := AttrBench.player({"pas": v, "sho": v, "str": v, "dfn": v}, false, {"pas": 10, "sho": 10, "str": 10, "dfn": 10})
	p.year = year
	Development.ensure(p)
	return p

func _keeper(v: float, year := 1) -> PoloPlayer:
	var p := AttrBench.player({"com": v, "lun": v, "blk": v, "leg": v}, true, {"com": 10, "lun": 10, "blk": 10, "leg": 10})
	p.year = year
	Development.ensure(p)
	return p

# ------------------------------------------------------------------ 1-5, 13, 17: what he earns
func _multipliers() -> void:
	r.check(Development.CLASS_XP_PCT == [100, 80, 95, 110, 125], "1-4: FR 0.80, SO 0.95, JR 1.10, SR 1.25")
	# a game worth exactly 100 base XP: 80 / 95 / 110 / 125 (replaced, not on top of 150 / 130 / 115 / 100)
	var line := {"g": 4, "ed": 1, "st": 1}   # 8 + 80 + 10 + 14 = 112 with a win's 8: 120... so without the win:
	var p := _field(5.0)
	var base := Development.base_game_xp(p, line, false)
	var got := []
	for y in [1, 2, 3, 4]:
		p.year = y
		got.append(Development.game_xp(p, line, false))
	r.check(got == [roundi(base * 0.8), roundi(base * 0.95), roundi(base * 1.1), roundi(base * 1.25)],
		"5: a %d-XP game pays %s by year (one multiplier, the new one)" % [base, str(got)])
	r.check(Development.game_xp(_field(5.0, 1), {"g": 4, "a": 1, "st": 1, "ed": 0}, false) < base * 1.5 * 0.9, "5: nothing of the old 1.5 freshman multiplier left")
	# the year moves, the multiplier moves with it; nothing else does
	var m := _field(5.0, 1)
	var keep := [m.attrs.duplicate(), m.attr_pot.duplicate(), m.xp_level, m.xp_start]
	var pcts := []
	for y in [1, 2, 3, 4]:
		m.year = y
		pcts.append(Development.class_pct(m))
	r.check(pcts == [80, 95, 110, 125] and [m.attrs, m.attr_pot, m.xp_level, m.xp_start] == keep, "13: FR -> SO -> JR -> SR: the multiplier follows his year, nothing else")
	# keepers: the same years, the same percents
	var k := _keeper(5.0)
	var kp := []
	for y in [1, 2, 3, 4]:
		k.year = y
		kp.append(Development.class_pct(k))
	r.check(kp == pcts, "17: keepers and field players: the same class rules")
	# rewards and training untouched; training never saw the class multiplier and still doesn't
	r.check([Development.GOAL_XP, Development.ASSIST_XP, Development.STEAL_XP, Development.BLOCK_XP, Development.DRAWN_EXCLUSION_XP, Development.DRAWN_PENALTY_XP, Development.TURNOVER_XP,
		Development.EXCLUSION_COMMITTED_XP, Development.GOALKEEPER_SAVE_XP, Development.GOAL_CONCEDED_XP, Development.PARTICIPATION_XP, Development.WIN_BONUS_XP]
		== [20, 15, 14, 14, 10, 18, -4, -4, 10, -1, 8, 8], "15: every game XP reward as it was")
	var fr := _field(4.0, 1)
	var sr := _field(4.0, 4)
	r.check(Development.training_xp(fr, "shooting", 3) == Development.training_xp(sr, "shooting", 3) and Development.training_xp(fr, "balanced", 2) == Development.BALANCED_TRAINING_XP,
		"16: training XP as it was (no class multiplier: game XP only, as the system always had it)")

# ------------------------------------------------------------------ 6-12: what it costs
func _curve() -> void:
	var lt := func(n: int) -> int: return Development.lt_xp_required(n)
	r.check(Development.xp_required(0) == ceili(450.0 * 1.15) and absf(float(Development.xp_required(0)) / lt.call(0) - 1.15) < 0.003,
		"6: his first token: %d, 15%% more than %d" % [Development.xp_required(0), lt.call(0)])
	var high := true
	for n in range(int(Development.REQ_REF_LEVELS), 30):
		high = high and absf(float(Development.xp_required(n)) / lt.call(n) - 0.85) < 0.002
	r.check(high, "7: from %d levels in: 15%% less than before (%d for %d at 10)" % [int(Development.REQ_REF_LEVELS), Development.xp_required(10), lt.call(10)])
	var mid := int(Development.REQ_REF_LEVELS / 2.0)
	r.check(Development.xp_required(mid) == lt.call(mid), "9: the middle (%d levels in): the requirement it had (%d)" % [mid, Development.xp_required(mid)])
	var smooth := true
	var rising := true
	var expo := true
	for n in range(1, 40):
		smooth = smooth and absf(Development.req_mod(n) - Development.req_mod(n - 1)) <= 0.0376
		rising = rising and Development.xp_required(n) > Development.xp_required(n - 1)
		var ratio := float(Development.xp_required(n)) / Development.xp_required(n - 1)
		expo = expo and ratio > 1.3 and ratio < 1.39
	r.check(smooth, "8/12: the modifier moves evenly (at most %.4f a level): no jump from +15%% to -15%%" % (0.3 / Development.REQ_REF_LEVELS))
	r.check(rising, "11: every token still costs more than the last (0-40)")
	r.check(expo, "10: still exponential: each level ~1.33-1.38 x the one before")
	r.check(Development.req_mod(0) == 1.15 and is_equal_approx(Development.req_mod(int(Development.REQ_REF_LEVELS) / 4), 1.075) and is_equal_approx(Development.req_mod(int(Development.REQ_REF_LEVELS) * 3 / 4), 0.925),
		"8: 1.15 -> 1.075 -> 1.00 -> 0.925 -> 0.85")
	# still far dearer than the original curve (76 x 1.11^level) everywhere
	var dear := true
	for n in 30:
		dear = dear and Development.xp_required(n) >= 3 * Development.old_xp_required(n)
	r.check(dear, "4: still at least three times the original, easier curve at every level")
	# a pure function: asking again never compounds it
	r.check(Development.xp_required(5) == Development.xp_required(5) and Development.xp_required(5) == ceili(snappedf(450.0 * pow(1.38, 5) * Development.req_mod(5), 0.000001)),
		"15: the modifier is worked out fresh each time, never compounded")

# ------------------------------------------------------------------ 14: year earns, level costs
func _separate() -> void:
	var sr := _field(4.0, 4)
	r.check(Development.xp_needed(sr) == Development.xp_required(0), "14: a senior who's barely developed: the +15%% low-level cost (%d)" % Development.xp_needed(sr))
	var so := _field(4.0, 2)
	so.xp_level = so.xp_start + 9
	r.check(Development.xp_needed(so) == Development.xp_required(9) and absf(float(Development.xp_needed(so)) / Development.lt_xp_required(9) - 0.85) < 0.002,
		"14: a sophomore well into his development: the -15%% high-level cost (%d)" % Development.xp_needed(so))

# ------------------------------------------------------------------ 18-22: levelling
func _leveling() -> void:
	var p := _field(4.0)
	var lv := p.xp_level
	var n0 := Development.xp_required(0)
	r.check(Development.award_xp(p, n0 - 1) == 0 and p.xp == n0 - 1 and p.tokens == 0, "18: one short: no token")
	r.check(Development.award_xp(p, 1) == 1 and p.xp == 0 and p.xp_level == lv + 1 and p.tokens == 1, "18: the threshold: one token, one level, nothing left over")
	var q := _field(4.0)
	var three := Development.xp_required(0) + Development.xp_required(1) + Development.xp_required(2)
	r.check(Development.award_xp(q, three + 7) == 3 and q.xp == 7 and q.tokens == 3, "19: three thresholds in one award: three tokens, 7 XP carried over")
	var attrs := q.attrs.duplicate()
	var pots := q.attr_pot.duplicate()
	r.check(q.attrs == attrs and q.attr_pot == pots, "21/22: tokens alone change no attribute or ceiling")
	Development.spend(q, "sho")
	r.check(is_equal_approx(Attributes.value(q, "sho"), float(attrs.sho) + 1.0) and q.attr_pot == pots, "21/22: one spent: one point, ceilings untouched")
	var bar := _field(4.0)
	Development.award_xp(bar, 200)
	r.check(is_equal_approx(Development.progress(bar), 200.0 / Development.xp_required(0)), "24: the XP bar reads against the adjusted requirement (200 / %d)" % Development.xp_required(0))

# ------------------------------------------------------------------ 23: saves
func _saves() -> void:
	var p := _field(5.0, 2)
	p.xp_level = p.xp_start + 3
	p.tokens = 1
	# saved before the rebalance (no "curve"): 40% of the way to his next token on CEIL(450 x 1.38^n)
	var d := p.to_dict()
	d.development.erase("curve")
	d.development["current_xp"] = floori(0.4 * Development.lt_xp_required(3))
	var keep := [d.attrs.duplicate(), d.attr_pot.duplicate(), d.stars, d.pot_stars, d.year]
	var q := PoloPlayer.from_dict(d)
	r.check([q.attrs, q.attr_pot, q.stars, q.pot_stars, q.year] == keep and q.xp_level == p.xp_level and q.xp_start == p.xp_start and q.tokens == 1,
		"23: a save from before: attributes, ceilings, stars, year, hidden level and token as saved")
	r.check(absf(Development.progress(q) - 0.4) < 0.01, "23: 40%% of the way to his next token stays 40%% (%.3f)" % Development.progress(q))
	var again := PoloPlayer.from_dict(q.to_dict())
	r.check(again.xp == q.xp and again.xp_level == q.xp_level and int(q.to_dict().development.curve) == Development.CURVE_VERSION,
		"23: saved again on the new curve: no second conversion")
	# a just-levelled player in an old save gains nothing for loading it
	var z := _field(5.0, 3)
	var zd := z.to_dict()
	zd.development.erase("curve")
	zd.development["current_xp"] = Development.lt_xp_required(0) - 1
	var zl := PoloPlayer.from_dict(zd)
	r.check(zl.tokens == 0 and zl.xp < Development.xp_required(0) and zl.xp_level == z.xp_level, "23: loading never pays a token (%d / %d)" % [zl.xp, Development.xp_required(0)])

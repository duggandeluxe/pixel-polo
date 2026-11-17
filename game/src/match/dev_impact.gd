class_name DevImpact
## Developer Mode's OP ATTRIBUTE IMPACT (the DEV RECRUITS panel, dev_lab): what a DEV Recruit's
## attribute past the normal ten really does in the pool, against the same man at an ordinary
## elite 10, measured with the game's own code (AttrBench, ShotModel, Tempo, PlayAI,
## DefenseFormation, KeeperDuel). Nothing here is a made-up bonus: every number is an engine
## function's, or the share of outcomes the engine's own dice gave.
##
## CONTROLLED CONDITIONS: the two players are the same DEV Recruit (DevRecruits.make: his own other
## three attributes, position, speed, NORMAL form, no injury, no trait), both his kind (so the cap
## is the same for both) with ONLY the compared attribute changed: 10 against his real value. Every
## opponent is the same made-up all-5 player or keeper (AttrBench.player), every shot comes from the
## same spots with the same aim, and every simulation runs on the same fixed seeds for both, so the
## dice they face are identical. CALC rows are deterministic engine values; SIM rows are observed
## shares of a seeded sample (n shots or draws), and say so.
##
## Nothing here reads or writes a career, a save, a real player, his XP or his stats.

## The comparisons: the DEV Recruit, the attribute, its name on the panel.
const COMPARISONS := [
	{"id": "blake_dfn", "key": "blake", "attr": "dfn"},
	{"id": "logan_sho", "key": "logan", "attr": "sho"},
]
const ELITE := 10.0                  # the ordinary player's ceiling: Attributes.MAX
const N_SHOTS := 600                 # shots behind each SIM shooting share
const N_DUELS := 400                 # shootout duels behind the SIM keeper share
const SEED := 7                      # the one seed every SIM row uses, for both players
const DISTANCES := [4.0, 6.0, 8.0]   # metres out from the goal line (AttrBench.SHOT_FROM's 6 m, closer and further)
const CONTACT := 0.5                 # the contested shot's contact (Play.contact_on: 0 free .. 1 smothered)
const LANE_AT := 1.6                 # m out from the shooter, the guard in a contested shot's lane...
const LANE_OFF := 0.45               # ...this far off its line
const BLOCK_ALONG := 3.0             # the block test: the defender 3 m down the shot's path...
const BLOCK_PERP := 0.35             # ...the ball passing this far from him
const BESIDE_D := 0.6                # the contact test: the guard this far in front of the centre

static func find(id: String) -> Dictionary:
	for c in COMPARISONS:
		if String(c.id) == id:
			return c
	return {}

## The DEV Recruit `key` with `attr` at `v` and nothing else changed (its ceiling with it, so his
## record is valid; a ceiling never plays). A copy for the bench: nobody's, never saved.
static func subject(key: String, attr: String, v: float) -> PoloPlayer:
	var p := DevRecruits.make(key)
	p.attrs[attr] = v
	p.attr_pot[attr] = v
	Attributes.sync(p)
	return p

## His real value for `attr` (DevRecruits.DEFS).
static func dev_value(key: String, attr: String) -> float:
	return float(DevRecruits.DEFS[key].attrs[attr])

## Runs comparison `id`: {title, key, attr, base_v, dev_v, rows: [{label, base, dev, fmt, better,
## kind ("CALC" | "SIM"), prob, src, n?, bound?}], notes: [text], valid (every probability in
## 0..1 and none certain), conditions: [text]}. Deterministic: the same numbers every run.
static func run(id: String) -> Dictionary:
	var cmp := find(id)
	if cmp.is_empty():
		return {}
	var key := String(cmp.key)
	var attr := String(cmp.attr)
	var dv := dev_value(key, attr)
	var base := subject(key, attr, ELITE)
	var dev := subject(key, attr, dv)
	var out := {"id": id, "key": key, "attr": attr, "base_v": ELITE, "dev_v": dv,
		"title": "%s — %s" % [DevRecruits.full_name(key), String(Attributes.NAMES[attr]).to_upper()],
		"rows": [], "notes": [], "conditions": []}
	match attr:
		"sho":
			_shooting(out, base, dev)
		"dfn":
			_defense(out, base, dev)
		"str":
			_strength(out, base, dev)
	_check(out)
	return out

static func _row(out: Dictionary, label: String, b: float, d: float, fmt: String, better: int, kind: String, src: String,
		extra: Dictionary = {}) -> void:
	var r := {"label": label, "base": b, "dev": d, "fmt": fmt, "better": better, "kind": kind, "src": src,
		"prob": fmt == "pct"}
	r.merge(extra)
	(out.rows as Array).append(r)

# ------------------------------------------------------------------ SHOOTING
static func _shooting(out: Dictionary, base: PoloPlayer, dev: PoloPlayer) -> void:
	var gk := AttrBench.player({}, true)
	var elite_gk := AttrBench.player({"com": 9.0, "lun": 9.0, "blk": 9.0, "leg": 9.0}, true)
	var mine := AttrBench.player({}, true)
	(out.conditions as Array).append_array([
		"SAME MAN BOTH SIDES: %s'S OTHER THREE, NORMAL FORM, NO INJURY, NO TRAIT" % String(DevRecruits.DEFS[out.key].last).to_upper(),
		"SHOTS: 80%% PULL, AIMED %.2f M OFF CENTRE (ALTERNATE CORNERS), NOBODY IN THE WAY, NO PASS" % AttrBench.SHOT_AIM,
		"KEEPERS: ALL-5 (AVERAGE) AND ALL-9 (ELITE), MEDIUM; SIM: %d SHOTS A SPOT, SEED %d, THE SAME DICE FOR BOTH" % [N_SHOTS, SEED]])
	var top_b := Attributes.rating_top(base)
	var top_d := Attributes.rating_top(dev)
	_row(out, "SHOT RATING (0-100)", float(base.shoot), float(dev.shoot), "num", 1, "CALC", "PoloPlayer.shoot (Attributes.sync)")
	_row(out, "AIM SPREAD (x)", ShotModel.skill_spread(float(base.shoot), top_b), ShotModel.skill_spread(float(dev.shoot), top_d), "x", -1, "CALC",
		"ShotModel.skill_spread", {"bound": "SHOT RATING READ UP TO 100 (A DEV RECRUIT'S %d)" % Attributes.DEV_LEGACY_TOP})
	_row(out, "RELEASE TIME (x)", Attributes.release_mult(base), Attributes.release_mult(dev), "x", -1, "CALC",
		"Attributes.release_mult", {"bound": "RELEASE FLOOR x%.2f" % Attributes.RELEASE_FLOOR})
	_row(out, "KEEPER READS IT LATE BY", Attributes.release_read(base), Attributes.release_read(dev), "s", 1, "CALC", "Attributes.release_read")
	_row(out, "PACE RATING", Attributes.shot_pace(base), Attributes.shot_pace(dev), "num", 1, "CALC", "Attributes.shot_pace")
	_row(out, "SHOT SPEED, 80% PULL", ShotModel.shot_speed(0.8, Attributes.shot_pace(base), {}, 0.0, top_b),
		ShotModel.shot_speed(0.8, Attributes.shot_pace(dev), {}, 0.0, top_d), "ms", 1, "CALC", "ShotModel.shot_speed")
	_row(out, "SHOT SPEED, FULL PULL", ShotModel.shot_speed(1.0, Attributes.shot_pace(base), {}, 0.0, top_b),
		ShotModel.shot_speed(1.0, Attributes.shot_pace(dev), {}, 0.0, top_d), "ms", 1, "CALC", "ShotModel.shot_speed",
		{"bound": "SOFT CAP %.0f M/S, x%.1f PAST IT (Tempo.SHOT_MAX)" % [Tempo.SHOT_MAX, Tempo.SHOT_SOFT]})
	_row(out, "THEIR WIND-UP AT YOUR GOAL", AttrBench.windup(base), AttrBench.windup(dev), "s", -1, "CALC", "AttrBench.windup")
	for d in DISTANCES:
		var from := Vector2(Geo.GOAL_X - float(d), AttrBench.SHOT_FROM.y)
		var sb := AttrBench.shots(base, null, gk, INF, N_SHOTS, SEED, from, false, AttrBench.SHOT_AIM, true)
		var sd := AttrBench.shots(dev, null, gk, INF, N_SHOTS, SEED, from, false, AttrBench.SHOT_AIM, true)
		_row(out, "GOALS FROM %d M (AVG KEEPER)" % int(d), sb.goal, sd.goal, "pct", 1, "SIM", "ShotModel.resolve", {"n": N_SHOTS})
		if is_equal_approx(float(d), 6.0):
			_row(out, "SAVED FROM 6 M (AVG KEEPER)", sb.save, sd.save, "pct", -1, "SIM", "ShotModel.resolve", {"n": N_SHOTS})
			_row(out, "KEEPER REACTION, 6 M", sb.reaction, sd.reaction, "s", 1, "SIM", "ShotModel.resolve", {"n": N_SHOTS})
	var from6 := Vector2(Geo.GOAL_X - 6.0, AttrBench.SHOT_FROM.y)
	_row(out, "GOALS FROM 6 M (ELITE KEEPER)", AttrBench.shots(base, null, elite_gk, INF, N_SHOTS, SEED, from6, false, AttrBench.SHOT_AIM, true).goal,
		AttrBench.shots(dev, null, elite_gk, INF, N_SHOTS, SEED, from6, false, AttrBench.SHOT_AIM, true).goal, "pct", 1, "SIM", "ShotModel.resolve", {"n": N_SHOTS})
	_row(out, "SHOOTOUT: YOUR KEEPER SAVES", AttrBench.duel_saves(mine, base, 0.7, N_DUELS, SEED), AttrBench.duel_saves(mine, dev, 0.7, N_DUELS, SEED),
		"pct", -1, "SIM", "KeeperDuel (bot keeper 0.7)", {"n": N_DUELS})
	# UNDER PRESSURE: a man on him (Play.contact_on's share of contact slows every shot the same
	# way, ShotModel.CONTACT_SLOW) and a guard standing in the lane (ShotModel's own blocks)
	_row(out, "SHOT SPEED, 80% PULL, CONTACT 0.5", ShotModel.shot_speed(0.8, Attributes.shot_pace(base), {}, CONTACT, top_b),
		ShotModel.shot_speed(0.8, Attributes.shot_pace(dev), {}, CONTACT, top_d), "ms", 1, "CALC", "ShotModel.shot_speed (contact)")
	var lane := contested_blockers(from6)
	var cb := AttrBench.shots(base, null, gk, INF, N_SHOTS, SEED, from6, false, AttrBench.SHOT_AIM, true, lane, LANE_AT)
	var cd := AttrBench.shots(dev, null, gk, INF, N_SHOTS, SEED, from6, false, AttrBench.SHOT_AIM, true, lane, LANE_AT)
	_row(out, "CONTESTED 6 M: GOALS (AVG KEEPER)", cb.goal, cd.goal, "pct", 1, "SIM", "ShotModel.resolve (a guard in the lane)", {"n": N_SHOTS})
	_row(out, "CONTESTED 6 M: BLOCKED", cb.block, cd.block, "pct", -1, "SIM", "ShotModel._blocks", {"n": N_SHOTS})
	(out.conditions as Array).append("CONTESTED: AN ALL-5 GUARD %.1f M OUT IN THE LANE, %.2f M OFF ITS LINE" % [LANE_AT, LANE_OFF])

## The guard in a contested shot's lane from `from`: an all-5 man LANE_AT m out towards the
## middle of the goal, LANE_OFF m to one side of that line (ShotModel.blocker, not set: no hand up yet).
static func contested_blockers(from: Vector2) -> Array:
	var dir := (Vector2(Geo.GOAL_X, Geo.GOAL_Y) - from).normalized()
	var at := from + dir * LANE_AT + dir.orthogonal() * LANE_OFF
	return [ShotModel.blocker(at, AttrBench.player({}), 0, false, false)]

## A field defender `p` against a shot from 6 m that passes BLOCK_PERP m from him BLOCK_ALONG m
## down its path at Play.BOT_SHOT_SPEED (ShotModel.block_reach, block_chance: off the ball).
static func block_test(p: PoloPlayer) -> Dictionary:
	var from := Vector2(Geo.GOAL_X - 6.0, Geo.GOAL_Y)
	var b := ShotModel.blocker(from + Vector2(BLOCK_ALONG, 0.0), p, 0, false, false)
	var r := ShotModel.block_reach(b, from, BLOCK_ALONG, Play.BOT_SHOT_SPEED)
	return {"reach": float(r.reach), "chance": ShotModel.block_chance(r, BLOCK_PERP, Play.BOT_SHOT_SPEED)}

## The 2 m battle's own sums with `guard` on an all-5 centre (CenterDefense: his challenge for the
## ball, a missed one whistled, the centre's shot getting away when pulled from behind) and the
## contact he puts on a man BESIDE_D m in front of him (Play.contact_on: how much it slows his shot).
static func centre_sums(guard: PoloPlayer) -> Dictionary:
	var b := AttrBench.centre_play(AttrBench.player({}, false, {}, PoloPlayer.Pos.CENTER), guard)
	var p: Play = b.play
	var c: Swimmer = b.c
	var g: Swimmer = b.g
	var out := {"steal": CenterDefense.steal_chance(p, g, c), "fail": CenterDefense.fail_foul(p, g, c), "through": CenterDefense.through_chance(g, c)}
	g.pos = c.pos + (Geo.goal_center() - c.pos).normalized() * BESIDE_D
	out["contact"] = p.contact_on(c)
	out["slowed"] = ShotModel.shot_speed(0.8, Attributes.shot_pace(c.player), {}, float(out.contact))
	return out

# ------------------------------------------------------------------ DEFENSE
static func _defense(out: Dictionary, base: PoloPlayer, dev: PoloPlayer) -> void:
	var avg := AttrBench.player({})
	var avg_c := AttrBench.player({}, false, {}, PoloPlayer.Pos.CENTER)
	(out.conditions as Array).append_array([
		"SAME MAN BOTH SIDES: %s'S OTHER THREE, NORMAL FORM, NO INJURY, NO TRAIT" % String(DevRecruits.DEFS[out.key].last).to_upper(),
		"OPPONENTS: AN ALL-5 PASSER, ATTACKER AND CENTRE; AN ALL-5 KEEPER BEHIND (NO ORGANISING EITHER WAY)",
		"2 M BATTLE: A REAL PLAY (LEAGUE CLUBS), 200 FIGHT DRAWS ON THE PLAY'S FIXED SEED, THE SAME FOR BOTH"])
	_row(out, "EFFECTIVE DEFENSE", Attributes.eff_defense(base, 0.0), Attributes.eff_defense(dev, 0.0), "num", 1, "CALC",
		"Attributes.eff_defense", {"bound": "HIS OWN CAP (Attributes.cap)"})
	_row(out, "LANE-READ SHARE", Attributes.unit(Attributes.eff_defense(base, 0.0)), Attributes.unit(Attributes.eff_defense(dev, 0.0)), "x", 1, "CALC",
		"Attributes.unit (first entry reach, reaction)")
	_row(out, "TIP CHANCE, PASS THROUGH HIM", DefenseFormation.tip_chance(base, avg), DefenseFormation.tip_chance(dev, avg), "pct", 1, "CALC",
		"DefenseFormation.tip_chance", {"bound": "TIP_RANGE %d-%d%%" % [roundi(DefenseFormation.TIP_RANGE.x * 100.0), roundi(DefenseFormation.TIP_RANGE.y * 100.0)],
		"cap": DefenseFormation.TIP_RANGE.y})
	_row(out, "PICK-OFF CHANCE (REAL PLAY)", AttrBench.intercept(base), AttrBench.intercept(dev), "pct", 1, "CALC", "Play._intercept_chance")
	_row(out, "PRESSING: FOULS FORCED", AttrBench.foul_rate(base, avg), AttrBench.foul_rate(dev, avg), "rate", 1, "CALC",
		"Play.foul_pressure", {"bound": "FOUL_RANGE x%.1f-%.1f" % [Attributes.FOUL_RANGE.x, Attributes.FOUL_RANGE.y], "cap": DefenseFormation.FOUL_RATE * Attributes.FOUL_RANGE.y})
	var cb := AttrBench.centre(avg_c, base)
	var cd := AttrBench.centre(avg_c, dev)
	_row(out, "GUARDING: SWITCH WAIT", cb.switch, cd.switch, "s", -1, "CALC", "PlayAI.center_switch_wait", {"bound": "x0.7-1.3 FOR STRENGTH"})
	_row(out, "GUARDING: CENTRE'S WIN EDGE", _edge(avg_c, base), _edge(avg_c, dev), "s", -1, "CALC", "PlayAI.win_edge")
	_row(out, "GUARDING: CENTRE WINS IN", cb.win, cd.win, "s", 1, "SIM", "PlayAI._win_time",
		{"n": 200, "bound": "CENTER_WIN %.0f-%.0f S" % [PlayAI.CENTER_WIN.x, PlayAI.CENTER_WIN.y], "cap": PlayAI.CENTER_WIN.y})
	_row(out, "GUARDING: SEAL HELD (x)", cb.seal, cd.seal, "x", -1, "CALC", "PlayAI.seal_mult", {"bound": "SEAL x0.70-1.30", "cap": 0.7})
	var sb := centre_sums(base)
	var sd := centre_sums(dev)
	_row(out, "2 M: CHALLENGE WINS THE BALL", sb.steal, sd.steal, "pct", 1, "CALC", "CenterDefense.steal_chance")
	_row(out, "2 M: MISSED CHALLENGE WHISTLED", sb.fail, sd.fail, "pct", -1, "CALC", "CenterDefense.fail_foul")
	_shot_blocking(out, base, dev)
	_row(out, "PRESSING: ARM-UP DELAY", DefenseFormation.arm_delay(base), DefenseFormation.arm_delay(dev), "s", -1, "CALC",
		"DefenseFormation.arm_delay", {"bound": "ARM_DELAY_RANGE %.2f-%.2f S" % [DefenseFormation.ARM_DELAY_RANGE.x, DefenseFormation.ARM_DELAY_RANGE.y],
		"cap": DefenseFormation.ARM_DELAY_RANGE.x})

## SHOT BLOCKING (ShotModel.block_reach: his Defense and Strength both): how far he reaches and his
## chance on a ball BLOCK_PERP m off him.
static func _shot_blocking(out: Dictionary, base: PoloPlayer, dev: PoloPlayer) -> void:
	var bb := block_test(base)
	var bd := block_test(dev)
	var bound := "block_reach READS HIS 0-100 RATINGS UP TO 100"
	_row(out, "SHOT BLOCK: REACH, 3 M DOWN THE SHOT", bb.reach, bd.reach, "m", 1, "CALC", "ShotModel.block_reach", {"bound": bound})
	_row(out, "SHOT BLOCK: CHANCE, %.2f M OFF HIM" % BLOCK_PERP, bb.chance, bd.chance, "pct", 1, "CALC", "ShotModel.block_chance", {"bound": bound})

# ------------------------------------------------------------------ STRENGTH
static func _strength(out: Dictionary, base: PoloPlayer, dev: PoloPlayer) -> void:
	var avg := AttrBench.player({})
	var avg_c := AttrBench.player({}, false, {}, PoloPlayer.Pos.CENTER)
	(out.conditions as Array).append_array([
		"SAME MAN BOTH SIDES: %s'S OTHER THREE, NORMAL FORM, NO INJURY, NO TRAIT" % String(DevRecruits.DEFS[out.key].last).to_upper(),
		"OPPONENTS: AN ALL-5 CENTRE, GUARD AND PRESSING DEFENDER; AN ALL-5 KEEPER BEHIND",
		"2 M BATTLE: A REAL PLAY (LEAGUE CLUBS), 200 FIGHT DRAWS ON THE PLAY'S FIXED SEED, THE SAME FOR BOTH"])
	_row(out, "STRENGTH IN PLAY", Attributes.strength(base), Attributes.strength(dev), "num", 1, "CALC", "Attributes.strength")
	var ab := AttrBench.centre(base, avg)
	var ad := AttrBench.centre(dev, avg)
	_row(out, "AS CENTRE: WIN EDGE", _edge(base, avg), _edge(dev, avg), "s", 1, "CALC", "PlayAI.win_edge")
	_row(out, "AS CENTRE: WINS INSIDE IN", ab.win, ad.win, "s", -1, "SIM", "PlayAI._win_time",
		{"n": 200, "bound": "CENTER_WIN %.0f-%.0f S" % [PlayAI.CENTER_WIN.x, PlayAI.CENTER_WIN.y], "cap": PlayAI.CENTER_WIN.x})
	_row(out, "AS CENTRE: HOLDS HIS SEAL (x)", ab.seal, ad.seal, "x", 1, "CALC", "PlayAI.seal_mult", {"bound": "SEAL x0.70-1.30", "cap": 1.3})
	var gb := AttrBench.centre(avg_c, base)
	var gd := AttrBench.centre(avg_c, dev)
	_row(out, "GUARDING: CENTRE'S WIN EDGE", _edge(avg_c, base), _edge(avg_c, dev), "s", -1, "CALC", "PlayAI.win_edge")
	_row(out, "GUARDING: CENTRE WINS IN", gb.win, gd.win, "s", 1, "SIM", "PlayAI._win_time",
		{"n": 200, "bound": "CENTER_WIN %.0f-%.0f S" % [PlayAI.CENTER_WIN.x, PlayAI.CENTER_WIN.y], "cap": PlayAI.CENTER_WIN.y})
	_row(out, "GUARDING: SEAL HELD (x)", gb.seal, gd.seal, "x", -1, "CALC", "PlayAI.seal_mult", {"bound": "SEAL x0.70-1.30", "cap": 0.7})
	_row(out, "GUARDING: SWITCH WAIT", gb.switch, gd.switch, "s", -1, "CALC", "PlayAI.center_switch_wait", {"bound": "x0.7-1.3 FOR STRENGTH"})
	_row(out, "PRESSED: FOULED ON HIM", AttrBench.foul_rate(avg, base), AttrBench.foul_rate(avg, dev), "rate", -1, "CALC",
		"Play.foul_pressure", {"bound": "FOUL_RANGE x%.1f-%.1f" % [Attributes.FOUL_RANGE.x, Attributes.FOUL_RANGE.y], "cap": DefenseFormation.FOUL_RATE * Attributes.FOUL_RANGE.x})
	var sb := centre_sums(base)
	var sd := centre_sums(dev)
	_row(out, "GUARDING: CONTACT ON THE SHOOTER", sb.contact, sd.contact, "x", 1, "CALC", "Play.contact_on", {"bound": "x0.5-1.5 FOR STRENGTH"})
	_row(out, "GUARDING: HIS SHOT SLOWED TO", sb.slowed, sd.slowed, "ms", -1, "CALC", "ShotModel.shot_speed (contact)")
	_row(out, "PULLED FROM BEHIND: SHOT GETS AWAY", sb.through, sd.through, "pct", -1, "CALC", "CenterDefense.through_chance",
		{"bound": "x0.5-1.5 FOR STRENGTH"})
	# (shot blocking, ShotModel.block_reach, reads his 0-100 Defense and Strength ratings, which
	# Attributes.sync spreads round his overall: more Strength lifts the overall and nudges his
	# Defense rating down, so the two cancel there. Shown under Defense, where it's his own.)

## The centre's edge in the 2 m battle (PlayAI.win_edge, s sooner he wins inside water) with these
## two in a real Play.
static func _edge(attacker: PoloPlayer, defender: PoloPlayer) -> float:
	var b := AttrBench.centre_play(attacker, defender)
	return PlayAI.win_edge(b.play, b.c, b.g)

# ------------------------------------------------------------------ the checks
## Every probability within 0..1 and none certain (valid), and a note wherever the engine's own
## bounds hold the boosted value back: no difference at all, or the DEV value sitting on a bound.
static func _check(out: Dictionary) -> void:
	var valid := true
	for r in out.rows:
		for v in [float(r.base), float(r.dev)]:
			if is_nan(v) or is_inf(v):
				valid = false
			if bool(r.prob) and (v < 0.0 or v >= 1.0):
				valid = false
		var same: bool = absf(float(r.dev) - float(r.base)) < 0.00005
		var at_cap: bool = r.has("cap") and absf(float(r.dev) - float(r.cap)) < 0.00005
		if same:
			(out.notes as Array).append("%s: NO DIFFERENCE%s." % [r.label, (" — HELD BY " + String(r.bound)) if r.has("bound") else ""])
		elif at_cap:
			(out.notes as Array).append("%s: THE DEV VALUE SITS ON ITS BOUND (%s); THE REST OF HIS EDGE THERE IS LOST." % [r.label, String(r.get("bound", ""))])
	out["valid"] = valid

## A row's value as the panel shows it.
static func fmt(v: float, kind: String) -> String:
	match kind:
		"pct":
			return "%.1f%%" % (v * 100.0)
		"s":
			return "%.2f S" % v
		"x":
			return "x%.3f" % v
		"ms":
			return "%.2f M/S" % v
		"rate":
			return "%.3f/S" % v
		"m":
			return "%.2f M" % v
	return "%.1f" % v

## The difference, DEV minus 10: percentage points for a probability, else the change and its
## share of the 10's value.
static func diff_text(r: Dictionary) -> String:
	var b := float(r.base)
	var d := float(r.dev)
	if absf(d - b) < 0.00005:
		return "SAME"
	if bool(r.prob):
		return "%+.1f PTS" % ((d - b) * 100.0)
	var rel := "" if absf(b) < 0.000001 else "  (%+.0f%%)" % ((d - b) / absf(b) * 100.0)
	match String(r.fmt):
		"s":
			return "%+.2f S%s" % [d - b, rel]
		"x":
			return "%+.3f%s" % [d - b, rel]
		"ms", "m":
			return "%+.2f%s" % [d - b, rel]
		"rate":
			return "%+.3f%s" % [d - b, rel]
	return "%+.1f%s" % [d - b, rel]

## Is the DEV value the better one for him (by the row's `better`), worse, or the same (0)?
static func edge_sign(r: Dictionary) -> int:
	var dlt := float(r.dev) - float(r.base)
	if absf(dlt) < 0.00005:
		return 0
	return 1 if signf(dlt) == float(r.better) else -1

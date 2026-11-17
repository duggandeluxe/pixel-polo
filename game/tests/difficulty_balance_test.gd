extends RefCounted
## THE DIFFICULTY GAMEPLAY BALANCING update: the CPU's shot speed (by the pull), its keeper's
## reaction and its defenders' arm-raise delay at EASY / MEDIUM / HARD / DYNAMIC (Difficulty.CPU),
## MEDIUM exactly as before, never your players, never a simulated game. Numbered by the spec's
## REQUIRED TESTING (17 shot speed, 18 keepers, 19 blocking, 20 dynamic, 21 preservation).
##   godot --headless --path game -- --test difficulty_balance

var r
const LV := {"easy": 0.0, "normal": 0.5, "hard": 1.0}
const FROM := [Vector2(24.0, 10.0), Vector2(24.2, 8.0), Vector2(24.2, 12.0), Vector2(24.6, 6.8), Vector2(24.6, 13.2), Vector2(27.6, 10.0)]

func run(runner) -> void:
	r = runner
	print("difficulty gameplay balancing")
	_table()
	_shot_speed()
	_keeper()
	_arms()
	_play_scope()
	_catch_shoot()
	_preservation()

# ------------------------------------------------------------------ the table
func _table() -> void:
	var near := func(a: float, b: float) -> bool: return absf(a - b) < 0.0001
	r.check(near.call(Difficulty.cpu_shot_speed(0.0, 0.2), 1.0) and near.call(Difficulty.cpu_shot_speed(0.0, 1.0), 1.0), "17: EASY: exactly 1x (the game as first tuned)")
	r.check(near.call(Difficulty.cpu_shot_speed(0.5, 0.2), 1.12) and near.call(Difficulty.cpu_shot_speed(0.5, 1.0), 1.28), "17: MEDIUM: 1.12x a soft shot, 1.28x a full one")
	r.check(near.call(Difficulty.cpu_shot_speed(1.0, 0.2), 1.2) and near.call(Difficulty.cpu_shot_speed(1.0, 1.0), 1.4), "17: HARD: 1.2x a soft shot, 1.4x a full one")
	var smooth := true
	for i in 9:
		smooth = smooth and Difficulty.cpu_shot_speed(1.0, 0.2 + i * 0.1) >= Difficulty.cpu_shot_speed(1.0, 0.2 + maxf(0.0, i - 1) * 0.1)
	r.check(smooth and near.call(Difficulty.cpu_shot_speed(1.0, 0.6), 1.30), "17: smooth from a soft pull to a full one (power 0.6 on HARD: 1.30x)")
	r.check(near.call(Difficulty.cpu_keeper_react(0.0), 1.0) and near.call(Difficulty.cpu_keeper_react(0.5), 0.65) and near.call(Difficulty.cpu_keeper_react(1.0), 0.5), "18: keeper reaction delay 1x / 0.65x / 0.5x")
	r.check(near.call(Difficulty.cpu_arm_delay(0.0), 1.0) and near.call(Difficulty.cpu_arm_delay(0.5), 0.65) and near.call(Difficulty.cpu_arm_delay(1.0), 0.5), "19: arm-raise delay 1x / 0.65x / 0.5x")
	var d := 0.8   # (a DYNAMIC level between MEDIUM and HARD)
	r.check(Difficulty.cpu_shot_speed(d, 1.0) > 1.28 and Difficulty.cpu_shot_speed(d, 1.0) < 1.4 and Difficulty.cpu_keeper_react(d) < 0.65 and Difficulty.cpu_keeper_react(d) > 0.5
		and Difficulty.cpu_arm_delay(d) < 0.65 and Difficulty.cpu_arm_delay(d) > 0.5, "20: a DYNAMIC level in between gets in-between values, on the same lines")

# ------------------------------------------------------------------ 17
func _resolve(k: PoloPlayer, from: Vector2, power: float, seed_v: int, extra: Dictionary, aim_y := 9.4, shooter_sho := 5.0) -> Dictionary:
	var sh := AttrBench.player({"sho": shooter_sho})
	var ctx := AttrBench.shot_ctx(sh, null, k, INF)
	ctx["exact"] = true
	ctx["iq"] = 0.5
	ctx["pace"] = Attributes.shot_pace(sh)
	ctx.merge(extra, true)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	return ShotModel.resolve(from, aim_y, power, 70.0, 99.0, [], Geo.GOAL_Y, k.keeping, rng, false, {}, ctx)

func _shot_speed() -> void:
	var k := AttrBench.player({}, true)
	var same := true
	var ratio_ok := true
	for i in 20:
		var from: Vector2 = FROM[i % FROM.size()]
		var power := 0.3 + 0.035 * i
		var base := _resolve(k, from, power, 500 + i, {})
		var hard := _resolve(k, from, power, 500 + i, {"speed_k": Difficulty.cpu_shot_speed(1.0, power)})
		var easy := _resolve(k, from, power, 500 + i, {"speed_k": Difficulty.cpu_shot_speed(0.0, power)})
		same = same and float(hard.cross_y) == float(base.cross_y) and float(easy.cross_y) == float(base.cross_y)
		ratio_ok = ratio_ok and absf(float(hard.speed) / float(base.speed) - Difficulty.cpu_shot_speed(1.0, power)) < 0.0001 \
			and float(easy.speed) == float(base.speed) and (hard.outcome != base.outcome or float(hard.flight) < float(base.flight))
	r.check(ratio_ok, "17: the speed is the shot's own, then the difficulty's multiplier: EASY as first tuned, HARD faster, the flight with it")
	r.check(same, "17: accuracy untouched: the same shot crosses exactly where it would have")
	var soft := _resolve(k, FROM[0], 0.3, 7, {"speed_k": Difficulty.cpu_shot_speed(1.0, 0.3)})
	var soft0 := _resolve(k, FROM[0], 0.3, 7, {})
	var full := _resolve(k, FROM[0], 1.0, 7, {"speed_k": Difficulty.cpu_shot_speed(1.0, 1.0)})
	var full0 := _resolve(k, FROM[0], 1.0, 7, {})
	r.check(float(full.speed) - float(full0.speed) > (float(soft.speed) - float(soft0.speed)) * 1.8, "17: HARD: a full pull gains far more than a soft one (+%.1f vs +%.1f m/s)" % [float(full.speed) - float(full0.speed), float(soft.speed) - float(soft0.speed)])
	r.check(float(soft.speed) < float(full0.speed), "17: a soft shot on HARD is still slower than a full one on MEDIUM (%.1f < %.1f m/s)" % [float(soft.speed), float(full0.speed)])
	var weak := _resolve(k, FROM[0], 1.0, 8, {"speed_k": Difficulty.cpu_shot_speed(1.0, 1.0)}, 9.4, 3.0)
	var strong := _resolve(k, FROM[0], 1.0, 8, {"speed_k": Difficulty.cpu_shot_speed(1.0, 1.0)}, 9.4, 9.0)
	r.check(float(strong.speed) > float(weak.speed), "17: SHOOTING still matters on HARD: a 9's full shot %.1f m/s, a 3's %.1f" % [float(strong.speed), float(weak.speed)])

# ------------------------------------------------------------------ 18
func _save_rate(k: PoloPlayer, gk_k: float, n := 1500) -> float:
	var saves := 0
	for i in n:
		var from: Vector2 = FROM[i % FROM.size()]
		var aim := Geo.GOAL_Y + (0.55 if i % 2 == 0 else -0.55) + (i % 7) * 0.02
		var res := _resolve(k, from, 0.8, 9000 + i, {"gk_k": gk_k, "hold": 0.6 / gk_k}, aim)
		saves += 1 if String(res.outcome) in ["save", "parry"] else 0
	return float(saves) / n

func _keeper() -> void:
	var k := AttrBench.player({}, true)
	var e := _save_rate(k, Difficulty.cpu_keeper_react(0.0))
	var m := _save_rate(k, Difficulty.cpu_keeper_react(0.5))
	var h := _save_rate(k, Difficulty.cpu_keeper_react(1.0))
	print("    keeper save rate: easy %.3f  normal %.3f  hard %.3f" % [e, m, h])
	r.check(e < m and m < h, "18: the CPU keeper saves more the harder it is (%.3f / %.3f / %.3f)" % [e, m, h])
	r.check(h < 0.9, "18: still beatable on HARD (%.3f saved): no automatic saves" % h)
	var weak := _save_rate(AttrBench.player({"lun": 3.0, "blk": 3.0, "leg": 3.0, "com": 3.0}, true), Difficulty.cpu_keeper_react(1.0))
	var strong := _save_rate(AttrBench.player({"lun": 9.0, "blk": 9.0, "leg": 9.0, "com": 9.0}, true), Difficulty.cpu_keeper_react(1.0))
	r.check(strong > weak, "18: his attributes still matter on HARD: a 9 keeper %.3f, a 3 keeper %.3f" % [strong, weak])
	var strong_easy := _save_rate(AttrBench.player({"lun": 9.0, "blk": 9.0, "leg": 9.0, "com": 9.0}, true), Difficulty.cpu_keeper_react(0.0))
	r.check(strong_easy > weak, "13: a strong keeper on EASY can still beat a weak one on HARD (%.3f vs %.3f)" % [strong_easy, weak])
	# his body is his own at every level: the same dive, the same reach
	var a := _resolve(k, FROM[0], 0.8, 77, {"gk_k": 1.0, "dive_side": 1})
	var b := _resolve(k, FROM[0], 0.8, 77, {"gk_k": 0.75, "dive_side": 1})
	var body := func(d: Dictionary) -> Array: return [d.lunge, d.arm, d.quick, d.window, d.reach_k, d.push, d.rise]
	r.check(a.has("dive") and b.has("dive") and body.call(a.dive) == body.call(b.dive) and float(b.keeper_go) <= float(a.keeper_go),
		"18: on HARD he only goes sooner: the same dive body, the same reach (no teleport, no longer arms)")
	# never the aim before the release: his pick is made before any aim-dependent die
	var g1 := _resolve(k, FROM[1], 0.8, 31, {"gk_k": 0.75, "hold": 1.4}, Geo.GOAL_Y + 0.6)
	var g2 := _resolve(k, FROM[1], 0.8, 31, {"gk_k": 0.75, "hold": 1.4}, Geo.GOAL_Y - 0.6)
	r.check(int(g1.get("guess", 9)) == int(g2.get("guess", 9)), "18: HARD reads the shooter sooner, never the aim: the same anticipation whichever corner he aims at")

# ------------------------------------------------------------------ 19
func _arms() -> void:
	var good := AttrBench.player({"dfn": 9.0})
	var poor := AttrBench.player({"dfn": 3.0})
	var base := DefenseFormation.arm_delay(good)
	r.check(absf(DefenseFormation.arm_delay(good, Difficulty.cpu_arm_delay(1.0)) - base * 0.5) < 0.0001 and absf(DefenseFormation.arm_delay(good, Difficulty.cpu_arm_delay(0.0)) - base) < 0.0001,
		"19: the arm starts up 0.5x as late on HARD, as first tuned on EASY")
	r.check(DefenseFormation.arm_delay(good, Difficulty.cpu_arm_delay(0.0)) == DefenseFormation.arm_delay(good), "19: EASY exactly as first tuned")
	r.check(DefenseFormation.arm_delay(good, 0.75) < DefenseFormation.arm_delay(poor, 0.75), "19: Defense still matters at every level")
	# an arm on its way up isn't a block till it's up: the rise itself (ARM_RAISE) is never shortened
	var s := Swimmer.new(good, Swimmer.Side.THEM)
	s.pos = Vector2(26.0, 10.0)
	var on := Swimmer.new(poor, Swimmer.Side.US)
	on.pos = Vector2(24.0, 10.0)
	s.press_on = on
	s.press = DefenseFormation.Press.RAISE
	s.press_t = DefenseFormation.arm_delay(good, 0.75)
	var z := DefenseFormation.arm_zone(s, 0, 0.75)
	r.check(absf(float(z.ready) - DefenseFormation.ARM_RAISE) < 0.0001, "19: the arm still rises in full (%.2f s) before it blocks" % float(z.ready))
	var hit := ShotModel.arm_contact(on.pos, Vector2(Geo.GOAL_X, 10.0) - on.pos, 15.0, z)
	r.check(hit.is_empty(), "19: a ball there before the arm's up goes past it (the same rule as ever)")

# ------------------------------------------------------------------ 20, 21: whose side it is
func _play_scope() -> void:
	var us := League.make_team(0, 0)
	var them := League.make_team(3, 0)
	var rng := RandomNumberGenerator.new()
	rng.seed = 4
	var att := Play.new(us, them, Play.Kind.HALF_COURT, rng)
	att.set_level(1.0)
	att.cpu_level = 1.0
	r.check(att.cpu_speed_k(1.0) == 1.0, "21: your own shots: never faster or slower, at any difficulty")
	r.check(absf(att.gk_k() - 0.5) < 0.0001 and absf(att.arm_k() - 0.5) < 0.0001, "18/19: you attacking on HARD: their keeper and arms quicker")
	var dfn := Play.new(them, us, Play.Kind.HALF_COURT, rng)
	dfn.defending = true
	dfn.set_level(Difficulty.TEAMMATES)
	dfn.cpu_level = 1.0
	r.check(absf(dfn.cpu_speed_k(1.0) - 1.4) < 0.0001 and absf(dfn.cpu_speed_k(0.2) - 1.2) < 0.0001, "17: you defending on HARD: their shots 1.2x .. 1.4x")
	r.check(dfn.gk_k() == 1.0 and dfn.arm_k() == 1.0, "21: your keeper and your defenders: untouched at any difficulty")
	var easy := Play.new(them, us, Play.Kind.HALF_COURT, rng)
	easy.defending = true
	easy.cpu_level = 0.0
	r.check(easy.cpu_speed_k(1.0) == 1.0, "17: EASY: their shots as first tuned")
	# the flow sets the CPU's level on every possession, from the one fixed at the start (DYNAMIC included)
	var f := MatchFlow.new(League.make_team(1, 0), League.make_team(4, 0), 77, MatchState.QUARTER_MIN, 0.85)
	var lv_ok := true
	var steps := 0
	while f.phase != MatchFlow.Phase.FINAL and steps < 4000:
		steps += 1
		match f.phase:
			MatchFlow.Phase.SPRINT:
				f.sprint_done(true)
			MatchFlow.Phase.ATTACK:
				lv_ok = lv_ok and f.play.cpu_level == 0.85 and f.play.level == 0.85
				f.tick_attack(1.0 / 30.0)
				if f.play.over:
					f.attack_done()
			MatchFlow.Phase.DEFENSE:
				lv_ok = lv_ok and f.play.cpu_level == 0.85 and f.play.level == Difficulty.TEAMMATES
				f.auto_defense(0.5)
				f.defense_done()
			MatchFlow.Phase.THEIR_SHOT:
				f.auto_duel(0.5)
				f.duel_done()
			MatchFlow.Phase.SHOOTOUT_THEM:
				f.their_ball_done()
			MatchFlow.Phase.BREAK:
				f.break_done()
		if steps > 1500:
			break
	r.check(lv_ok, "20: the match's one level (fixed at the start: no change mid-shot) is the CPU's at both ends")

func _preservation() -> void:
	r.check(Difficulty.MODES == ["dynamic", "easy", "normal", "hard"], "21: the same four difficulties")
	var sim_src := FileAccess.get_file_as_string("res://src/core/game_sim.gd")
	r.check(not sim_src.contains("Difficulty") and not sim_src.contains("cpu_shot_speed"), "14: simulated games never read the difficulty")
	var dv := Difficulty.params(1.0)
	r.check(not dv.has("shot_low") and not dv.has("gk_react"), "the decision table is unchanged (the CPU's timing and pace kept apart)")

# ------------------------------------------------------------------ catch and shoot
func _catch_shoot() -> void:
	var near := func(a: float, b: float) -> bool: return absf(a - b) < 0.0001
	r.check(near.call(Difficulty.catch_shoot_k(0.0), 0.9) and near.call(Difficulty.catch_shoot_k(0.5), 0.75) and near.call(Difficulty.catch_shoot_k(1.0), 0.5),
		"catch and shoot: the window 10% / 25% / 50% smaller on EASY / MEDIUM / HARD")
	var w := ShotModel.CATCH_SHOOT_WINDOW
	r.check(ShotModel.catch_shoot(w * 0.5, 0.5) == 1.0 and ShotModel.catch_shoot(w * 0.5 + 0.01, 0.5) < 1.0 and ShotModel.catch_shoot(w * 1.0, 0.5) == 0.0 and ShotModel.catch_shoot(w, 1.0) == 1.0,
		"catch and shoot: HARD's full bonus and fade are half as long; unscaled as before")
	var f := MatchFlow.new(League.make_team(1, 0), League.make_team(4, 0), 78, MatchState.QUARTER_MIN, 1.0)
	f._start_attack(Play.Kind.HALF_COURT)
	var att_k := f.play.cs_k
	f._start_defense(Play.Kind.HALF_COURT)
	var def_k := f.play.cs_k
	r.check(near.call(att_k, 0.5) and def_k == 1.0, "catch and shoot: only your attack against the CPU (HARD %.2f); their shots keep the full window (%.2f)" % [att_k, def_k])

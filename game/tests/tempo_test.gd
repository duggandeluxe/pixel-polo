extends RefCounted
## Player skill in the pool (Tempo, TempoBench): shot pace from the shooter alone, never his
## team's overall (2.0 team overall: information only), one speed for a shot wherever it ends up
## (in, saved, parried, off the post, blocked, wide), the same on screen when you're in goal,
## accuracy untouched, keepers still in it, and their attack quicker on the ball the better its
## players pass, with your own controls as instant as ever.
##   godot --headless --path game -- --test tempo

var r   # the test runner

func run(runner) -> void:
	r = runner
	print("tempo")
	_shooter_first()
	_one_speed_every_outcome()
	_drawn_at_its_speed()
	_wide_on_screen()
	_duel_one_speed()
	_accuracy_untouched()
	_keepers_still_save()
	_passes()
	_their_tempo()
	_your_controls()

# 1, 2: the shooter is the only thing: his team's rating never moves a shot's pace
func _shooter_first() -> void:
	var last := 0.0
	var rising := true
	for s in [40, 55, 70, 85, 95]:
		var v := float(TempoBench.shot(75, s, Geo.GOAL_Y + 1.1).speed)
		rising = rising and v > last
		last = v
	r.check(rising, "a better shooter shoots harder (same team, same pull)")
	var paces: Array = []
	for t in [50, 65, 75, 85, 95, 100]:
		paces.append(float(TempoBench.shot(t, 70, Geo.GOAL_Y + 1.1).speed))
	r.check(paces.all(func(v): return is_equal_approx(float(v), float(paces[0]))), "the same shooter shoots just as hard on every team (%s)" % str(paces))
	var sniper := float(TempoBench.shot(55, 90, Geo.GOAL_Y + 1.1).speed)
	var poor := float(TempoBench.shot(95, 40, Geo.GOAL_Y + 1.1).speed)
	r.check(sniper > poor, "a sniper on a weak team outguns a poor shooter on an elite one (%.1f vs %.1f m/s)" % [sniper, poor])
	var elite := float(TempoBench.shot(95, 80, Geo.GOAL_Y + 1.1).speed)
	var weak := float(TempoBench.shot(60, 55, Geo.GOAL_Y + 1.1).speed)
	print("  elite team, good shooter %.1f m/s; weak team, so-so shooter %.1f m/s" % [elite, weak])
	r.check(elite / weak > 1.05, "a good shooter's shots are noticeably harder (x%.2f)" % (elite / weak))
	# form moves it only through his rating (PoloPlayer.live): HOT shoots harder
	var p := PoloPlayer.new()
	p.shoot = 70
	p.stars = 3.0
	var cold := p.live("shoot")
	p.heat = 2
	r.check(Tempo.shooter_shot(p.live("shoot")) > Tempo.shooter_shot(cold), "a HOT shooter's rating, and so his pace, is up")
	# never a blur: even the hardest pull by the best man on the best team
	var rng := RandomNumberGenerator.new()
	var top := 0.0
	for i in 200:
		rng.seed = i
		var res := ShotModel.resolve(Vector2(23, 10), 11.0, 1.0, 120.0, 9.0, [], 10.0, 60.0, rng, false,
			{"speed": 1.12}, {})
		top = maxf(top, float(res.speed))
	r.check(top <= Tempo.SHOT_MAX + 1e-4, "no shot leaves the hand faster than SHOT_MAX (%.1f m/s)" % top)

# 6, 7: one speed, whatever happens to it: flight = distance / speed for every outcome
func _one_speed_every_outcome() -> void:
	var outcomes := {}
	var worst := 0.0
	var speeds_differ := false
	for sd in 600:
		var rng := RandomNumberGenerator.new()
		rng.seed = 900 + sd
		var from := Vector2(rng.randf_range(21.0, 27.5), rng.randf_range(4.0, 16.0))
		var aim := Geo.GOAL_Y + rng.randf_range(-2.6, 2.6)
		var blockers: Array = []
		if sd % 3 == 0:
			var u := rng.randf_range(0.3, 0.7)
			blockers.append({"pos": from.lerp(Vector2(Geo.GOAL_X, aim), u) + Vector2(0, rng.randf_range(-0.4, 0.4)),
				"defense": 60, "strength": 60, "speed": 60, "on_ball": false, "ready": false})
		var keeper_y := Geo.GOAL_Y + rng.randf_range(-0.8, 0.8)
		var speed := -1.0
		# the same shot by the same man, over and over with different dice: different endings
		for k in 4:
			var sub := RandomNumberGenerator.new()
			sub.seed = sd * 10 + k
			var res := ShotModel.resolve(from, aim, 0.8, 70.0, 3.0, blockers, keeper_y, 65.0, sub, false, {}, {"team_ovr": 85.0})
			outcomes[res.outcome] = int(outcomes.get(res.outcome, 0)) + 1
			if speed < 0.0:
				speed = float(res.speed)
			speeds_differ = speeds_differ or not is_equal_approx(speed, float(res.speed))
			var v := from.distance_to(res.end) / float(res.flight)
			worst = maxf(worst, absf(v - float(res.speed)) / float(res.speed))
	print("  outcomes %s, worst speed mismatch %.6f" % [str(outcomes), worst])
	for o in ["goal", "save", "parry", "post", "miss", "block"]:
		r.check(outcomes.has(o), "the speed check saw a %s" % o)
	r.check(not speeds_differ, "the same shot has the same speed whatever happens to it")
	r.check(worst < 1e-4, "goals, saves, parries, posts, blocks and misses all fly distance / speed (%.6f off)" % worst)

# 7, 11: in a real Play the ball moves at exactly that speed every frame, along its line
func _drawn_at_its_speed() -> void:
	var worst := 0.0
	var seen := {}
	for sd in 60:
		var rng := RandomNumberGenerator.new()
		rng.seed = 3300 + sd
		var p := Play.new(TempoBench.lab_team(50 + (sd % 6) * 10), TempoBench.lab_team(75, 2), Play.Kind.HALF_COURT, rng)
		p.holder.pos = Vector2(23.5 + (sd % 4), 6.0 + (sd % 9))
		for i in p.defenders.size():
			p.defenders[i].pos = Vector2(2.0 + i, 2.0)
		p.keeper.pos = Vector2(Geo.KEEPER_X, Geo.GOAL_Y + (sd % 3 - 1) * 0.6)
		var aims := [Geo.GOAL_Y + 1.1, Geo.GOAL_Y - 0.2, Geo.GOAL_Y + 2.6, Geo.GOAL_Y - 1.52]
		p._shoot(aims[sd % 4], 0.6 + (sd % 4) * 0.1, true)
		var sh: Dictionary = p.ball.shot
		seen[sh.outcome] = true
		r.check(absf(p.ball.lead + p.ball.dur - float(sh.flight)) < 1e-4, "the drawn flight plus the hand's length is the shot's flight")
		var dt := 1.0 / 60.0
		var prev := p.ball.pos
		while p.ball.state == Ball.State.SHOT:
			var t0 := p.ball.t
			p.step(dt)
			if p.ball.state == Ball.State.SHOT and t0 > 0.0 and p.ball.t < 1.0:
				worst = maxf(worst, absf(p.ball.pos.distance_to(prev) / dt - float(sh.speed)) / float(sh.speed))
			prev = p.ball.pos
	print("  drawn: outcomes %s, worst frame speed off by %.5f" % [str(seen.keys()), worst])
	r.check(worst < 1e-3, "on screen every shot moves at its own speed, every frame (%.5f off)" % worst)

# 3, 6: you in goal. A shot going wide used to fly at full speed while one on target was slowed
# for your dive: now both are shown at the duel's pace, so the same shot looks the same.
func _wide_on_screen() -> void:
	var speeds := {}
	for aim in [["in", Geo.GOAL_Y + 1.0], ["wide", Geo.GOAL_Y + Geo.GOAL_HALF + 0.9], ["post", Geo.GOAL_Y - Geo.GOAL_HALF - 0.02]]:
		var flow := MatchFlow.new(TempoBench.lab_team(75, 2), TempoBench.lab_team(85, 1), 77, 99.0, Difficulty.MEDIUM)
		flow.auto_keeper = 0.0   # (no dive: we're watching the ball)
		flow._start_defense(Play.Kind.HALF_COURT)
		var p := flow.play
		p.holder.pos = Vector2(23.0, 7.0)
		for i in p.defenders.size():
			p.defenders[i].pos = Vector2(2.0 + i, 2.0)
		p.keeper.pos = Vector2(Geo.KEEPER_X, Geo.GOAL_Y)
		p._shoot(float(aim[1]), 0.8, true)
		var real := 1.0 / 60.0
		var moved := 0.0
		var secs := 0.0
		var prev := p.ball.pos
		var guard := 0
		while p.ball.state == Ball.State.SHOT and guard < 600:
			flow.tick_defense(real)
			guard += 1
			var step := p.ball.pos.distance_to(prev)
			prev = p.ball.pos
			if step > 1e-6 and p.ball.t < 0.97:
				moved += step
				secs += real
		speeds[aim[0]] = moved / maxf(secs, 1e-6)
	print("  your goal, on screen: in %.2f, wide %.2f, post %.2f m/s" % [speeds.in, speeds.wide, speeds.post])
	r.check(absf(speeds.wide / speeds["in"] - 1.0) < 0.03, "your goal: a shot going wide looks as fast as one on target")
	r.check(absf(speeds.post / speeds["in"] - 1.0) < 0.03, "your goal: one off the post too")

# 6: their shootout penalty (KeeperDuel's own shot): one pace, in or wide
func _duel_one_speed() -> void:
	var team := TempoBench.lab_team(90, 1)
	var gk := TempoBench.lab_team(75, 2).keeper()
	var worst := 0.0
	var wide := 0
	for sd in 300:
		var rng := RandomNumberGenerator.new()
		rng.seed = 40 + sd
		var shooter: PoloPlayer = team.starters()[1 + sd % 6]
		var from := Vector2(5.0, Geo.GOAL_Y)
		var d := KeeperDuel.new().setup(shooter, gk, from, 0.0, rng, 0.8, true)
		var want := lerpf(10.0, 15.0, d.shooter_skill) * 1.1
		worst = maxf(worst, absf(from.distance_to(Vector2(0.0, d.cross_y)) / d.flight - want) / want)
		if not d.on_target:
			wide += 1
	r.check(wide > 0, "the shootout check saw a shot wide (%d)" % wide)
	r.check(worst < 1e-4, "a shootout penalty flies at its shooter's pace, in or wide (%.6f off)" % worst)

# 8, 9: a shot never reads the team: the same dice, the same crossing, pace and bonuses
func _accuracy_untouched() -> void:
	var same := true
	var bonuses := true
	for sd in 300:
		var from := Vector2(22.0 + (sd % 6), 5.0 + (sd % 11))
		var keeper_y := Geo.GOAL_Y + 0.5 * signf(from.y - Geo.GOAL_Y + 0.01)
		var res := []
		for t in [50.0, 75.0, 100.0]:
			var rng := RandomNumberGenerator.new()
			rng.seed = 7000 + sd
			res.append(ShotModel.resolve(from, Geo.GOAL_Y - 1.1 * signf(from.y - Geo.GOAL_Y + 0.01), 0.75, 70.0, 2.0, [], keeper_y,
				65.0, rng, false, {}, {"team_ovr": t, "catch_t": 0.2 if sd % 2 == 0 else INF}))
		for x in res:
			same = same and is_equal_approx(float(x.cross_y), float(res[0].cross_y)) and is_equal_approx(float(x.speed), float(res[0].speed))
			bonuses = bonuses and is_equal_approx(float(x.cross), float(res[0].cross)) and is_equal_approx(float(x.catch_shoot), float(res[0].catch_shoot))
	r.check(same, "the AI's spread and pace are the same whatever a team's rating says")
	r.check(bonuses, "cross-cage and catch-and-shoot are the same for every team")

# 10: a team's rating never makes its shots harder to stop
func _keepers_still_save() -> void:
	var rates := {}
	for t in [55.0, 100.0]:
		var saves := 0
		var n := 2000
		for i in n:
			var rng := RandomNumberGenerator.new()
			rng.seed = 11000 + i
			var res := ShotModel.resolve(Vector2(23.0, 8.0), Geo.GOAL_Y + 1.1, 0.85, 90.0, 3.0, [], Geo.GOAL_Y + 0.3, 85.0,
				rng, false, {}, {"team_ovr": t})
			if String(res.outcome) in ["save", "parry"]:
				saves += 1
		rates[t] = saves / float(n)
	print("  a good keeper's saves from 7 m: weak team %.2f, elite team %.2f" % [rates[55.0], rates[100.0]])
	r.check(is_equal_approx(rates[100.0], rates[55.0]), "the same shot is saved just as often whatever the team's rating")
	r.check(rates[100.0] > 0.15, "a good keeper saves plenty of them (%.2f)" % rates[100.0])

func _passes() -> void:
	r.check(is_equal_approx(Tempo.pass_mult(Tempo.PASS_MID), 1.0), "an average passer passes as before")
	r.check(Tempo.pass_mult(90.0) > Tempo.pass_mult(50.0), "a better passer's passes are quicker")
	var rng := RandomNumberGenerator.new()
	var good := Play.new(TempoBench.lab_team(95), TempoBench.lab_team(75, 2), Play.Kind.HALF_COURT, rng)
	var bad := Play.new(TempoBench.lab_team(55), TempoBench.lab_team(75, 2), Play.Kind.HALF_COURT, rng)
	r.check(good.pass_speed(good.holder) > bad.pass_speed(bad.holder), "in the pool too, better passers (%.1f vs %.1f m/s)" % [good.pass_speed(good.holder), bad.pass_speed(bad.holder)])

# 3, 4: their attack: better passers decide and move it quicker, weaker ones still play to score
func _their_tempo() -> void:
	r.check(Tempo.think_mult(80.0) < Tempo.think_mult(65.0) and Tempo.think_mult(65.0) < Tempo.think_mult(50.0),
		"the better his passing, the quicker the man on the ball decides (never his team's rating)")
	# (90 a side: since the defensive formations, 30 was within the noise of the elite team's edge)
	var elite := TempoBench.possessions(95, 90, 21)
	var weak := TempoBench.possessions(55, 90, 21)
	for x in [weak, elite]:
		print("  team %d: %.1f passes, %.2f s between, %.1f m/s, shot after %.1f s (%d shots, %d goals of %d)" % [
			x.rating, x.passes, x.gap, x.pass_speed, x.to_shot, x.shots, x.goals, x.n])
	r.check(elite.gap < weak.gap, "an elite team swings it quicker between passes")
	r.check(elite.pass_speed > weak.pass_speed, "an elite team's passes travel faster")
	r.check(elite.to_shot < weak.to_shot, "an elite team gets its shot off sooner")
	r.check(elite.passes < 9.0, "...without passing for ever (%.1f a possession)" % elite.passes)
	r.check(weak.shots >= weak.n * 0.6, "a weak team still gets its shots off (%d of %d)" % [weak.shots, weak.n])
	r.check(weak.gap > 0.4 and elite.gap > 0.4, "nobody passes rapid-fire: every catch is a catch")

# 5: your controls: a tap is a pass at once, a pull a shot at once, whatever the team
func _your_controls() -> void:
	for t in [50.0, 100.0]:
		var rng := RandomNumberGenerator.new()
		rng.seed = 5
		var p := Play.new(TempoBench.lab_team(t), TempoBench.lab_team(75, 2), Play.Kind.HALF_COURT, rng)
		var mate: Swimmer = null
		for a in p.attackers:
			if a != p.holder:
				mate = a
				break
		r.check(p.pass_to(mate) and p.ball.state == Ball.State.PASS, "team %d: a tap on a teammate passes at once" % t)
		var q := Play.new(TempoBench.lab_team(t), TempoBench.lab_team(75, 2), Play.Kind.HALF_COURT, rng)
		q.holder.pos = Vector2(24.0, 10.0)
		for i in q.defenders.size():
			q.defenders[i].pos = Vector2(2.0 + i, 2.0)
		r.check(q.shoot_at(Vector2(Geo.GOAL_X + 0.5, Geo.GOAL_Y + 1.0), 0.8) == "shot" and q.ball.state == Ball.State.SHOT,
			"team %d: a pull to shoot shoots at once" % t)

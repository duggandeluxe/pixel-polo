extends RefCounted
## THE INDIVIDUAL SHOOTING POWER UPDATE: a shot's pace is the shooter's own SHOOTING
## (Attributes.shot_pace) and the pull, never his team's overall, form or anyone else's
## attributes; the same for you and the CPU. Real shots through Play._shoot with a career's own
## players. The numbered checks follow the spec's REQUIRED TESTING list.
##   godot --headless --path game -- --test shot_power

var r   # the test runner
var c: Career
var strong: PoloTeam
var weak: PoloTeam

const FROM := Vector2(23.0, 7.0)
const AIM := 10.6

func run(runner) -> void:
	r = runner
	print("individual shooting power")
	c = Career.new_game("CULA", "A", "B", 11)
	var ids: Array = c.teams.keys()
	ids.sort_custom(func(a, b): return (c.teams[a] as PoloTeam).team_overall(false) > (c.teams[b] as PoloTeam).team_overall(false))
	strong = c.teams[ids[0]]
	weak = c.teams[ids[-1]]
	print("    strong %s %.1f   weak %s %.1f" % [ids[0], strong.team_overall(false), ids[-1], weak.team_overall(false)])

	# T1: the same team, 3 against 9
	var s3 := _speed(strong, 3.0)
	var s9 := _speed(strong, 9.0)
	print("    shooting 3: %.2f m/s   9: %.2f m/s (pull 0.8)" % [s3, s9])
	r.check(s9 > s3 * 1.08, "T1: the same team: a 9 shoots clearly harder than a 3 (%.2f vs %.2f)" % [s9, s3])

	# T2: different teams, both 7; the team's form (momentum) and the shooter's morale don't count
	var a7 := _speed(strong, 7.0)
	var b7 := _speed(weak, 7.0)
	r.check(is_equal_approx(a7, b7), "T2: a 7 shoots the same pace for the best and the worst team (%.3f vs %.3f)" % [a7, b7])
	r.check(not "shoot_bonus" in Play.new(strong, weak, Play.Kind.HALF_COURT, RandomNumberGenerator.new()) and not "morale" in PoloPlayer.new(),
		"T2: ...and there's no team form or morale any more to change it")
	var other := _speed(strong, 7.0, 0.8, {"others": 10.0})
	r.check(is_equal_approx(other, a7), "T2: his passing, strength and defence never count (%.3f vs %.3f)" % [other, a7])

	# T3 / T4: an elite shooter on a weak team, a weak shooter on a strong team
	r.check(_speed(weak, 10.0) > _speed(strong, 5.0), "T3: a weak team's 10 outshoots a strong team's 5")
	r.check(_speed(strong, 3.0) < _speed(weak, 9.0), "T4: a strong team's 3 shoots softer than a weak team's 9")

	# T5: an upgrade (5 -> 6) is faster at once
	var before := _speed(weak, 5.0)
	var after := _speed(weak, 6.0)
	r.check(after > before, "T5: SHOOTING 5 -> 6 shoots harder (%.3f -> %.3f)" % [before, after])

	# T6: the pull decides how much of it he uses
	for sho in [3.0, 9.0]:
		r.check(_speed(strong, sho, 0.3) < _speed(strong, sho, 1.0) * 0.75, "T6: a short pull (%d) is well under a full one" % int(sho))
	r.check(_speed(strong, 9.0, 0.3) < _speed(strong, 3.0, 1.0), "T6: a 9's short pull is softer than a 3's full one")

	# T7: the CPU's shooters are paced exactly the same way
	r.check(is_equal_approx(_speed(strong, 8.0, 0.8, {"cpu": true}), _speed(strong, 8.0)), "T7: the CPU shooting: the same pace")
	r.check(is_equal_approx(_speed(weak, 4.0, 0.8, {"cpu": true}), _speed(strong, 4.0, 0.8, {"cpu": true})), "T7: ...whichever CPU team")

	# T8: against the same keeper, harder shooters beat him more; nobody's automatic
	var rates := []
	for sho in [3.0, 6.0, 9.0]:
		rates.append(_goal_rate(sho))
	print("    goals: shooting 3 %.2f   6 %.2f   9 %.2f" % rates)
	r.check(rates[0] <= rates[1] + 0.02 and rates[1] <= rates[2] + 0.02 and rates[2] > rates[0], "T8: the keeper saves fewer the harder they shoot")
	r.check(rates[0] > 0.05, "T8: a weak shooter still scores (%.2f)" % rates[0])
	r.check(_goal_rate(10.0) < 0.95, "T8: a 10 isn't a guaranteed goal")

	# T9: a substitute shoots with his own Shooting
	var starter: PoloPlayer = _shooter(strong)
	var sub: PoloPlayer = null
	for p: PoloPlayer in strong.roster:
		if not p.is_keeper() and not strong.starters().has(p):
			sub = p
			break
	_set_sho(starter, 9.0)
	_set_sho(sub, 4.0)
	var sp := _speed_of(strong, sub)
	r.check(sp < _speed_of(strong, starter) and is_equal_approx(sp, _speed(weak, 4.0)), "T9: a substitute shoots at his own 4's pace, not the 9's he replaced")

	# T10: BAR-IN! / BAR-DOWN! still come off goals at any pace
	for sho in [3.0, 9.0]:
		r.check(_bar_hit(sho), "T10: a BAR-IN! / BAR-DOWN! off a shooting-%d goal" % int(sho))

	r.check(Attributes.shot_pace(starter) == Tempo.SHOT_PIVOT + (9.0 - Attributes.PACE_MID) * Attributes.PACE_PER_POINT, "the pace rating is his Shooting's alone")
	Development.injure(starter, RandomNumberGenerator.new(), "minor", "shoulder")
	r.check(Attributes.shot_pace(starter) < Tempo.SHOT_PIVOT + (9.0 - Attributes.PACE_MID) * Attributes.PACE_PER_POINT, "an injury's Shooting penalty slows him")

func _shooter(t: PoloTeam) -> PoloPlayer:
	return t.starters()[1]

func _set_sho(p: PoloPlayer, v: float) -> void:
	Attributes.set_ceiling(p, "sho", 10.0)
	Attributes.set_value(p, "sho", v)
	p.trait_id = ""
	p.heat = 0   # (no HOT: his own form would move it)

## A shot by `t`'s first field starter with Shooting `sho`, `power` of a full pull, aimed exactly.
## opts: others (his other three), cpu (the CPU shooting).
func _speed(t: PoloTeam, sho: float, power := 0.8, opts := {}) -> float:
	var p := _shooter(t)
	_set_sho(p, sho)
	if opts.has("others"):
		for k in ["pas", "str", "dfn"]:
			Attributes.set_ceiling(p, k, 10.0)
			Attributes.set_value(p, k, float(opts.others))
		p.trait_id = ""
	return _speed_of(t, p, power, opts)

func _play(t: PoloTeam, p: PoloPlayer, seed_value: int, opts := {}) -> Play:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var opp: PoloTeam = weak if t == strong else strong
	var play := Play.new(t, opp, Play.Kind.HALF_COURT, rng)
	play.holder.player = p
	play.defending = bool(opts.get("cpu", false))
	play.holder.pos = FROM
	play.catch_t = INF
	for i in play.defenders.size():
		play.defenders[i].pos = Vector2(2.0 + i, 2.0)
	play.keeper.pos = Vector2(Geo.KEEPER_X, Geo.GOAL_Y)
	return play

func _speed_of(t: PoloTeam, p: PoloPlayer, power := 0.8, opts := {}) -> float:
	var play := _play(t, p, 1, opts)
	play._shoot(AIM, power, true)
	return float(play.ball.shot.speed)

## Share of goals for a weak team's shooter with Shooting `sho` against the strong team's keeper,
## full-ish pulls aimed across the goal.
func _goal_rate(sho: float) -> float:
	var p := _shooter(weak)
	_set_sho(p, sho)
	var goals := 0
	const N := 240
	for i in N:
		var play := _play(weak, p, 900 + i)
		var aim := Geo.GOAL_Y + lerpf(-1.3, 1.3, float(i % 12) / 11.0)
		play._shoot(aim, 0.9, true)
		goals += 1 if String(play.ball.shot.outcome) == "goal" else 0
	return float(goals) / N

func _bar_hit(sho: float) -> bool:
	var p := _shooter(weak)
	_set_sho(p, sho)
	for i in 200:
		var play := _play(weak, p, 300 + i)
		play.bar_fx = true
		play.bar_mode = BarHit.Override.ALWAYS
		play.keeper.pos = Vector2(Geo.KEEPER_X, Geo.GOAL_Y - 1.2)
		play._shoot(Geo.GOAL_Y + Geo.GOAL_HALF - 0.08, 1.0, true)
		if bool(play.ball.bar.get("on", false)):
			return true
	return false

## The shooter's power streak (PoolArt.draw_power_trail), a weak, an average and a great shooter's
## shot side by side over the water: --test shot_trail_png <dir> (needs a window).
static func trail_shots(runner, out: String) -> void:
	DirAccess.make_dir_recursive_absolute(out)
	var view := PoolView.new()
	var cv := UI.canvas(480, 270, func(ci: Control):
		ci.draw_rect(Rect2(0, 0, 480, 270), Color("1d4fd0"))
		for i in 3:
			var power: float = [0.07, 0.53, 0.87][i]
			var at := view.to_world(Vector2(150 + i * 120, 135))
			PoolArt.draw_power_trail(ci, view, Vector3(at.x, at.y, 0.9), Vector2(1, 0.15), power)
			var b := Ball.new()
			b.pos = at
			b.z = 0.9
			PoolArt.draw_ball(ci, view, b)
			Deck.text(ci, 100 + i * 120, 170, ["SHOOTING 3", "SHOOTING 6-7", "SHOOTING 9"][i], 8, UI.TEXT))
	await runner.get_tree().process_frame
	Game.overlay.add_child(cv)
	await runner.get_tree().create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	runner.get_viewport().get_texture().get_image().save_png(out.path_join("shot_trails.png"))
	cv.queue_free()

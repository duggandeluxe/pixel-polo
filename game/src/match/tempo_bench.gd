class_name TempoBench
## Developer Mode's SHOT & TEMPO TEST (TempoLab) and the tests (tests/tempo_test.gd) measure
## player quality in the pool here, with the game's own code: real shots through Play._shoot, real
## possessions of their attack through MatchFlow (OffenseAI deciding, Tempo timing it). Every
## team is made up on the spot: nothing touches a career, a save or a real player.

const KEYS := ["shoot", "passing", "speed", "strength", "defense"]
const SHOT_FROM := Vector2(23.0, 7.0)      # 7 m out, off to one side
const SHOT_POWER := 0.8
const AVERAGE := 75.0                      # the other side's players

## A club whose seven play to `rating`: a League roster moved up or down until its field players
## average that, no traits (a PLAYMAKER or a CANNON would muddy the numbers).
static func lab_team(rating: float, index: int = 1, seed_value: int = 0) -> PoloTeam:
	var t := League.make_team(index, seed_value)
	var field := t.starters().slice(1)
	var avg := 0.0
	for p: PoloPlayer in field:
		avg += p.overall()
	avg /= maxf(1.0, field.size())
	var delta := rating - avg
	for p in t.roster:
		for k in KEYS + (["keeping"] if p.is_keeper() else []):
			p.set(k, clampi(roundi(float(p.get(k)) + delta), 20, 99))
		p.trait_id = ""
	return t

## One shot by a man rated `shooter` (shooting) for a team rated `team_rating`, from `from` at
## `cross_y` on the goal line, `power` of a full pull, aimed (exact, so it goes exactly there).
## Nobody in the way; the keeper in the middle. {speed, shooter_k, outcome, from, to,
## dur, lead, flight (from the hand to where it stops), line_t (to the goal line), dist}.
static func shot(team_rating: float, shooter: float, cross_y: float, from := SHOT_FROM,
		power := SHOT_POWER, seed_value: int = 1) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var p := Play.new(lab_team(team_rating, 1), lab_team(AVERAGE, 2), Play.Kind.HALF_COURT, rng)
	var s := p.holder
	s.player.shoot = clampi(roundi(shooter), 1, 99)
	s.pos = from   # (7 m out: never the centre on his spot, so never his power shot)
	p.catch_t = INF
	for i in p.defenders.size():
		p.defenders[i].pos = Vector2(2.0 + i, 2.0)   # out of the way: down the other end
	p.keeper.pos = Vector2(Geo.KEEPER_X, Geo.GOAL_Y)
	p._shoot(cross_y, power, true)
	var b := p.ball
	var sh: Dictionary = b.shot
	var speed := float(sh.speed)
	return {"speed": speed, "shooter_k": Tempo.shooter_shot(p.shot_pace(s)),
		"outcome": String(sh.outcome), "from": b.from, "to": b.to, "dur": b.dur, "lead": b.lead,
		"flight": b.lead + b.dur, "line_t": from.distance_to(Vector2(Geo.GOAL_X, cross_y)) / speed,
		"dist": from.distance_to(b.to), "drawn_speed": b.from.distance_to(b.to) / b.dur}

## `n` half-court possessions of their attack by a team rated `rating` against an average one,
## played out by the AI with the bot in goal. {passes (a possession), gap (s between passes),
## pass_speed (m/s), to_shot (s from the start to the shot, when there was one), shots, goals,
## think (Tempo.think_mult, his first man's)}. Times are game seconds (Play.elapsed).
static func possessions(rating: float, n: int = 8, seed_value: int = 5) -> Dictionary:
	var att := lab_team(rating, 1, seed_value)
	var flow := MatchFlow.new(lab_team(AVERAGE, 2, seed_value), att, seed_value, 99.0, Difficulty.MEDIUM)
	flow.auto_keeper = 0.5
	var passes := 0
	var gaps := 0.0
	var gap_n := 0
	var speed := 0.0
	var to_shot := 0.0
	var shots := 0
	var goals := 0
	var think := 0.0
	var dt := 1.0 / 30.0
	for i in n:
		flow._start_defense(Play.Kind.HALF_COURT)
		var p := flow.play
		think += Tempo.think_mult(p.holder.player.live("passing")) if p.holder != null else 1.0
		var last := -1.0
		var shot_at := -1.0
		var guard := 0
		while not p.over and guard < 3000:
			flow.tick_defense(dt)
			guard += 1
			for e in flow.events:
				match String(e.k):
					"pass":
						passes += 1
						speed += p.ball.from.distance_to(p.ball.to) / p.ball.dur
						if last >= 0.0:
							gaps += p.elapsed - last
							gap_n += 1
						last = p.elapsed
					"shot":
						if shot_at < 0.0:
							shot_at = p.elapsed
			flow.events.clear()
		if shot_at >= 0.0:
			shots += 1
			to_shot += shot_at
		if String(p.result.get("outcome", "")) == "goal":
			goals += 1
	return {"rating": rating, "passes": passes / float(n), "gap": gaps / maxf(1.0, gap_n),
		"pass_speed": speed / maxf(1.0, passes), "to_shot": to_shot / maxf(1.0, shots),
		"shots": shots, "goals": goals, "n": n, "think": think / float(n)}

extends RefCounted
## Whole bot-played matches, counted: steals (by where they came from), pass completion,
## possession length, shots, goals and counterattacks, per game and for each side.
##   godot --headless --path game -- --test stats [matches]

const DT := 1.0 / 30.0

var n := 0
var tot := {}

func run(_runner, matches: int) -> void:
	for i in matches:
		var teams := [League.make_team(i % 8, 0), League.make_team((i + 3) % 8, 0)]
		_match(MatchFlow.new(teams[0], teams[1], 5000 + i, MatchState.QUARTER_MIN))
	n = matches
	var g := func(k: String) -> float: return float(tot.get(k, 0)) / n
	print("stats over %d matches (per game, both teams)" % n)
	print("  steals            %.2f  (picked off %.2f, stripped %.2f; yours %.2f, theirs %.2f)" % [
		g.call("steals"), g.call("st_pass"), g.call("st_ball"), g.call("st_us"), g.call("st_them")])
	print("  yours: picked off %.2f, stripped %.2f; theirs: picked off %.2f, stripped %.2f" % [
		g.call("st_pass_us"), g.call("st_ball_us"), g.call("st_pass_them"), g.call("st_ball_them")])
	print("  keeper claims     %.2f" % g.call("claims"))
	var passes := float(tot.get("passes", 0))
	print("  passes            %.1f, completed %.1f%%" % [g.call("passes"), 100.0 * float(tot.get("caught", 0)) / maxf(1.0, passes)])
	print("  possessions       %.1f, average %.1f s live" % [g.call("poss"), float(tot.get("poss_t", 0.0)) / maxf(1.0, float(tot.get("poss", 0)))])
	print("  your attacks %.1f s, theirs %.1f s; fouls on yours %.1f, on theirs %.1f" % [
		float(tot.get("poss_t_us", 0.0)) / maxf(1.0, float(tot.get("poss_us", 0))),
		float(tot.get("poss_t_them", 0.0)) / maxf(1.0, float(tot.get("poss_them", 0))), g.call("fouls_us"), g.call("fouls_them")])
	print("  shots             %.1f (yours %.1f, theirs %.1f)" % [g.call("shots"), g.call("shots_us"), g.call("shots_them")])
	print("  goals             %.1f (yours %.1f, theirs %.1f)" % [g.call("goals"), g.call("goals_us"), g.call("goals_them")])
	print("  your passes %.1f, completed %.1f%%; theirs %.1f, completed %.1f%%" % [g.call("passes_us"),
		100.0 * float(tot.get("caught_us", 0)) / maxf(1.0, float(tot.get("passes_us", 0))), g.call("passes_them"),
		100.0 * float(tot.get("caught_them", 0)) / maxf(1.0, float(tot.get("passes_them", 0)))])
	print("  counterattacks    %.2f" % g.call("counters"))
	print("  exclusions        %.2f (drawn by you %.2f, them %.2f)   fouls %.1f   penalties %.2f   blocks %.2f" % [
		g.call("excl"), g.call("excl_us"), g.call("excl_them"), g.call("fouls"), g.call("pens"), g.call("blocks")])

func _add(k: String, v: float = 1.0) -> void:
	tot[k] = float(tot.get(k, 0.0)) + v

func _match(f: MatchFlow) -> void:
	var steps := 0
	while f.phase != MatchFlow.Phase.FINAL and steps < 200000:
		steps += 1
		match f.phase:
			MatchFlow.Phase.SPRINT:
				f.sprint_done(f.rng.randf() < 0.5)
			MatchFlow.Phase.ATTACK:
				_possession(f, true)
				f.attack_done()
			MatchFlow.Phase.DEFENSE:
				_possession(f, false)
				f.defense_done()
			MatchFlow.Phase.SHOOTOUT_THEM:
				f.their_ball_done()
			MatchFlow.Phase.THEIR_SHOT:
				f.auto_duel(0.5)
				f.duel_done()
			MatchFlow.Phase.BREAK:
				f.break_done()
	var s := f.state
	_add("steals", s.steals[0] + s.steals[1])
	_add("st_us", s.steals[0])
	_add("st_them", s.steals[1])
	_add("shots", s.shots[0] + s.shots[1])
	_add("goals", s.score[0] + s.score[1])
	_add("shots_us", s.shots[0])
	_add("shots_them", s.shots[1])
	_add("goals_us", s.score[0])
	_add("goals_them", s.score[1])
	_add("excl", s.exclusions[0] + s.exclusions[1])
	_add("excl_us", s.exclusions[0])
	_add("excl_them", s.exclusions[1])
	_add("blocks", s.blocks[0] + s.blocks[1])

## One possession played out by the bots (your attack by PlayBot, their attack by MatchFlow's
## brain, your keeper by the duel bot), counting its events as they happen.
func _possession(f: MatchFlow, ours: bool) -> void:
	var p := f.play
	if p.kind == Play.Kind.COUNTER:
		_add("counters")
	var think := 0.0
	var t := 0.0
	var in_air := false
	if not ours:
		if "auto_defend" in f:
			f.set("auto_defend", true)   # (before the AI took over your field defenders)
		f.auto_keeper = 0.5
	while not p.over and t < 90.0:
		if ours:
			think -= DT
			if think <= 0.0:
				think = PlayBot.THINK_EVERY
				var d := PlayBot.think(p, f.rng)
				if not d.is_empty():
					p.throw(d.target, d.power)
			f.tick_attack(DT)
		else:
			f.tick_defense(DT)
		t += DT
		for e in f.events:
			match String(e.k):
				"pass":
					_add("passes")
					_add("passes_us" if ours else "passes_them")
					in_air = true
				"catch":
					if in_air:
						_add("caught")
						_add("caught_us" if ours else "caught_them")
					in_air = false
				"recover", "shot":
					in_air = false
				"foul":
					_add("fouls")
					_add("fouls_us" if ours else "fouls_them")
				"penalty":
					_add("pens")
		f.events.clear()
		if p.ball.state != Ball.State.PASS:
			in_air = false
	var r := p.result
	var oc := String(r.get("outcome", ""))
	if p.kind != Play.Kind.PENALTY:
		_add("poss")
		_add("poss_t", p.elapsed)
		_add("poss_us" if ours else "poss_them")
		_add("poss_t_us" if ours else "poss_t_them", p.elapsed)
	if oc == "steal":
		if MatchState.is_steal(oc, r):
			var how := "st_pass" if String(r.text) == "PICKED OFF!" else "st_ball"
			_add(how)
			_add(how + ("_them" if ours else "_us"))
		else:
			_add("claims")

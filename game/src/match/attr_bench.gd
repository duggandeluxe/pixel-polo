class_name AttrBench
## Developer Mode's ATTRIBUTE TEST LAB (AttrLab) and the tests (tests/attr_test.gd) measure what
## each attribute does here, with the game's own code: ShotModel.resolve for shots (the same ctx
## Play._shoot builds), KeeperDuel and KeeperDive for your keeper, a real Play for the 2 m battle,
## interceptions and the press. Every player and team is made up on the spot: nothing touches a
## career, a save or a real player.

const SHOT_FROM := Vector2(24.0, 8.2)      # 6 m out, a little off to one side
const SHOT_AIM := 0.95                     # aimed this far off the middle of the goal
const N := 600                             # shots a Monte Carlo number is made of

## A made-up player with these attributes and ceilings ({key: 0-10}); a field player at `pos`
## unless `keeper`. Anything not given is 5 (ceilings: the attribute).
static func player(vals: Dictionary, keeper: bool = false, pots: Dictionary = {}, pos: int = PoloPlayer.Pos.UTILITY) -> PoloPlayer:
	var p := PoloPlayer.new()
	p.first = "LAB"
	p.last = "KEEPER" if keeper else "PLAYER"
	p.pos = PoloPlayer.Pos.GK if keeper else pos
	for k in Attributes.keys_for(p):
		p.attrs[k] = float(vals.get(k, 5.0))
		p.attr_pot[k] = maxf(float(pots.get(k, p.attrs[k])), p.attrs[k])
	if not keeper:
		p.keeping = 20
	Attributes.sync(p)
	p.speed = clampi(roundi(Attributes.legacy_of(p.rating10()) + float(Attributes.POS_SPEED.get(p.pos, 0.0))), 1, 99)
	return p

## The ctx Play._shoot hands ShotModel for a shot by `shooter`, passed to him by `passer` (null:
## no pass), at keeper `keeper`, `catch_t` s after the catch.
static func shot_ctx(shooter: PoloPlayer, passer: PoloPlayer, keeper: PoloPlayer, catch_t: float) -> Dictionary:
	return {"catch_t": catch_t, "home_keeper": false, "exact": false,
		"pass_mod": Attributes.pass_mod(passer) if passer != null and catch_t < INF else 0.0,
		"release": Attributes.release_read(shooter),
		"lunge": Attributes.lunge_mult(keeper), "leg": Attributes.leg_reach(keeper), "block": Attributes.block_mod(keeper),
		"lunge_k": Attributes.keeper_skill(keeper, "lun"), "leg_k": Attributes.keeper_skill(keeper, "leg"),
		"window": Attributes.dive_window(keeper), "wall": Traits.has(keeper, "wall")}

## `n` shots by `shooter` at their AI keeper `keeper` (ShotModel.resolve, nobody in the way),
## from SHOT_FROM aimed SHOT_AIM off the middle (alternating corners), `catch_t` after a catch from
## `passer`. {goal (share), save, reaction (s, his average), reach (m, his average when it was
## a save or a touch)}.
## `right_way`: their keeper dives the way each shot goes (his anticipation out of it: only his body
## and hands are measured).
static func shots(shooter: PoloPlayer, passer: PoloPlayer, keeper: PoloPlayer, catch_t: float = INF, n: int = N, seed_value: int = 7,
		from: Vector2 = SHOT_FROM, right_way := false, aim_off: float = SHOT_AIM) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var ctx := shot_ctx(shooter, passer, keeper, catch_t)
	var goals := 0
	var saves := 0
	var react := 0.0
	for i in n:
		var aim := Geo.GOAL_Y + (aim_off if i % 2 == 0 else -aim_off)
		if right_way:
			ctx["dive_side"] = KeeperDive.RIGHT if i % 2 == 0 else KeeperDive.LEFT
		var res := ShotModel.resolve(from, aim, 0.8, float(shooter.shoot), 9.0, [],
			Geo.GOAL_Y, float(keeper.keeping), rng, false, {}, ctx)
		react += float(res.reaction)
		match String(res.outcome):
			"goal":
				goals += 1
			"save", "parry":
				saves += 1
	return {"goal": float(goals) / n, "save": float(saves) / n, "reaction": react / n}

## The keeper's reaction (s) to a plain shot by an average shooter, without the dice.
static func reaction(keeper: PoloPlayer, shooter: PoloPlayer = null) -> float:
	var s := shooter if shooter != null else player({})
	return float(shots(s, null, keeper, INF, 80).reaction) - 0.02   # (less the average of the 0.04 jitter)

## Your keeper's dive with these attributes (KeeperDuel's numbers): {extend (s to full stretch),
## react (s before he moves), lunge (m his body goes), reach (m past it), span (m, body and arm),
## window (s he's up at full stretch), falls (s from the tap), again (s until he can dive again)}.
static func dive(keeper: PoloPlayer) -> Dictionary:
	var d := KeeperDuel.new().setup_given(keeper, Vector2(24, Geo.GOAL_Y), Geo.GOAL_Y + 1.0, 0.5, 0.0, Geo.GOAL_Y, 0.0)
	var kd := d._new_dive(KeeperDive.RIGHT)
	return {"extend": kd.extend_time(), "react": kd.react_time(), "lunge": d.lunge, "reach": d.reach,
		"span": d.lunge + d.reach, "window": kd.window, "falls": kd.fall_at(), "again": kd.down_at() + KeeperDive.RECOVERY}

## Your keeper against `n` shots that cross the line `along` of the way out along his reach
## (0 body .. 1 his fingertips), diving the right way in good time (the ball arriving early in
## his window): the share kept out (BLOCKING).
static func blocking(keeper: PoloPlayer, along: float, n: int = N, seed_value: int = 3) -> float:
	var held := 0
	var dv := dive(keeper)
	for i in n:
		var cross := Geo.GOAL_Y + float(dv.lunge) + float(dv.reach) * along
		var d := KeeperDuel.new().setup_given(keeper, Vector2(24, Geo.GOAL_Y + 0.5), cross, 0.35, 0.0, Geo.GOAL_Y, 0.0)
		d.rng.seed = hash([seed_value, i])
		while d.t < d.flight - d.ideal_up(0.3) * d.slowmo:
			d.step(0.005)
		d.dive(KeeperDive.RIGHT)
		var guard := 0
		while not d.done() and guard < 400:
			guard += 1
			d.step(0.01)
		if d.saved():
			held += 1
	return float(held) / n

## The share of shootout-style duels (KeeperDuel.setup: their wind-up, your bot keeper of
## `skill`) a `keeper` saves against an average shooter `shooter`.
static func duel_saves(keeper: PoloPlayer, shooter: PoloPlayer = null, skill: float = 0.7, n: int = 400, seed_value: int = 11) -> float:
	var s := shooter if shooter != null else player({})
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var brng := RandomNumberGenerator.new()
	brng.seed = seed_value + 1
	var saved := 0
	for _i in n:
		var d := KeeperDuel.new().setup(s, keeper, Vector2(25.0, Geo.GOAL_Y), 0.0, rng, 0.0, true)
		d.auto(skill, brng)
		if d.saved():
			saved += 1
	return float(saved) / n

## A real possession (Play) between two League clubs, with `attacker` put in as the centre ("C")
## and `defender` as his guard, `keeper` in their goal. {play, c (the centre), g (his guard)}.
static func centre_play(attacker: PoloPlayer, defender: PoloPlayer, keeper: PoloPlayer = null, seed_value: int = 5) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var p := Play.new(League.make_team(1), League.make_team(2), Play.Kind.HALF_COURT, rng)
	var c: Swimmer = null
	for a in p.attackers:
		if a.tag == "C":
			c = a
	var g: Swimmer = null
	for d in p.defenders:
		if d.mark == c:
			g = d
	c.player = attacker
	g.player = defender
	p.keeper.player = keeper if keeper != null else player({}, true)   # (an all-5 keeper: no organising either way)
	return {"play": p, "c": c, "g": g}

## The 2 m battle with these two: {win (s, his average time to inside water), seal (share of
## the normal time he holds it), switch (s his guard waits to go round)}.
static func centre(attacker: PoloPlayer, defender: PoloPlayer, keeper: PoloPlayer = null) -> Dictionary:
	var b := centre_play(attacker, defender, keeper)
	var p: Play = b.play
	var c: Swimmer = b.c
	var g: Swimmer = b.g
	var total := 0.0
	for _i in 200:
		total += PlayAI._win_time(p, c, g)
	return {"win": total / 200.0, "seal": PlayAI.seal_mult(p, c, g), "switch": PlayAI.center_switch_wait(g, p.comm())}

## The chance `defender` picks off a pass from an average passer going right through him
## (Play._intercept_chance: his reach unchanged, only the chance), with `keeper` organising.
static func intercept(defender: PoloPlayer, keeper: PoloPlayer = null, passer: PoloPlayer = null) -> float:
	var b := centre_play(player({}, false, {}, PoloPlayer.Pos.CENTER), player({}), keeper)
	var p: Play = b.play
	var d: Swimmer = p.defenders[2]
	d.player = defender
	var a: Swimmer = p.attackers[0]
	a.player = passer if passer != null else player({})
	p.ball.passer = a
	p.ball.from = d.pos + Vector2(-4.0, 0.0)
	p.ball.to = d.pos + Vector2(4.0, 0.0)
	return p._intercept_chance(d, 0.5)

## How often (a second) the press of `defender` forces an ordinary foul on `attacker`, with
## `keeper` organising the defence, once his contact is held (DefenseFormation.FOUL_SETTLE):
## DefenseFormation.FOUL_RATE x Play.foul_pressure.
static func foul_rate(defender: PoloPlayer, attacker: PoloPlayer, keeper: PoloPlayer = null) -> float:
	var b := centre_play(player({}, false, {}, PoloPlayer.Pos.CENTER), player({}), keeper)
	var p: Play = b.play
	var d: Swimmer = p.defenders[2]
	var a: Swimmer = p.attackers[2]
	d.player = defender
	a.player = attacker
	return DefenseFormation.FOUL_RATE * p.foul_pressure(d, a)

## Their wind-up before a shot at your goal (MatchFlow's: the same at every difficulty), for `shooter`.
static func windup(shooter: PoloPlayer) -> float:
	return MatchFlow.OPP_SHOT_WINDUP * KeeperDuel.WINDUP * Attributes.release_mult(shooter)

class_name SimFinish
## SIM TO END (the Simulation Realism & Instant Sim update): the rest of a live match worked out
## at once, with no frames played, from exactly where it is, by the scoring engine every simulated
## game uses (GameSim): the two teams' ratings (OVR, OFF, DEF, GK, their form), the home pool or
## neutral site.
##
## Only what's left is played: the share of regulation still on the clocks (remaining_share) is
## sampled the way GameSim samples a whole game, scaled to that share (GameSim.regulation), so a
## mismatch tells most with most of the game left, and a late lead is only the last minutes'
## to lose. Nothing that already happened changes: the score, the box score, the fouls and who's
## rolled out stand, and the new events are added to the same MatchState lists a played game
## fills (goals, assists, shots, saves, blocks, steals, turnovers, exclusions), on the same rules
## (three personal fouls roll a man out; his sub plays on). Level after the fourth: the shootout,
## as in every played game, carried on from where it is if it's already under way. Then full time.

## The share of regulation left (1 at kickoff, 0 at the end of the fourth): the clock of the
## quarter under way (0:00 at a break) and the quarters still to come.
static func remaining_share(st: MatchState) -> float:
	var full := st.quarter_len * MatchState.QUARTERS
	if full <= 0.0 or st.in_shootout:
		return 0.0
	var left := st.clock + maxi(0, MatchState.QUARTERS - st.quarter) * st.quarter_len
	return clampf(left / full, 0.0, 1.0)

## Expected goals [yours, theirs] for a whole game between flow's two teams, as GameSim would
## play it: their ratings now (form included), the home pool unless it's a neutral site.
static func expected(flow: MatchFlow, neutral: bool) -> Array:
	var mine := GameSim.live_ratings(flow.us)
	var theirs := GameSim.live_ratings(flow.them)
	if flow.home:
		return GameSim.expected(mine, theirs, neutral)
	var e := GameSim.expected(theirs, mine, neutral)
	return [e[1], e[0]]

## Plays the rest of `flow`'s match and leaves it at full time (Phase.FINAL). Returns what it
## added: {share, goals: [yours, theirs], xg: [the rest's expected goals], shootout: bool}.
static func run(flow: MatchFlow, neutral: bool, seed_value: int) -> Dictionary:
	var st := flow.state
	var out := {"share": 0.0, "goals": [0, 0], "xg": [0.0, 0.0], "shootout": false}
	if flow.phase == MatchFlow.Phase.FINAL:
		return out
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	if not st.in_shootout:
		var share := remaining_share(st)
		var xg := expected(flow, neutral)
		var goals := GameSim.regulation(xg, rng, share)
		out.share = share
		out.goals = goals
		out.xg = [float(xg[0]) * share, float(xg[1]) * share]
		_play_out(flow, goals, share, _ball_side(flow), rng)
		st.quarter = MatchState.QUARTERS
		st.clock = 0.0
		if st.tied():
			st.in_shootout = true
			st.shootout = [0, 0]
			flow.shootout_round = 0
	if st.in_shootout:
		out.shootout = true
		_finish_shootout(flow, rng)
	flow.play = null
	flow.duel = null
	flow.opp = {}
	flow.opp_plan = {}
	flow.keeper_anim = null
	flow.events.clear()   # (nothing for the screen to announce: full time comes straight up)
	flow.phase = MatchFlow.Phase.FINAL
	return out

## Who has the ball as it stops (0 you, 1 them, -1 nobody: a sprint, a break).
static func _ball_side(flow: MatchFlow) -> int:
	match flow.phase:
		MatchFlow.Phase.ATTACK:
			return 0
		MatchFlow.Phase.DEFENSE, MatchFlow.Phase.THEIR_SHOT:
			return 1
	return -1

## The rest of regulation as a run of events in the order they happen (each at a random moment
## of what's left), so a man rolled out by his third foul is replaced for everything after it.
## `goals`: [yours, theirs] still to come. Each side's other possessions end as GameSim's do: a
## save, a field block, a shot wide, a turnover (most often a steal) or no shot at all; and its
## exclusions drawn, at GameSim's rates for the share left.
static func _play_out(flow: MatchFlow, goals: Array, share: float, ball: int, rng: RandomNumberGenerator) -> void:
	var timeline: Array = []
	for side in 2:
		for _i in int(goals[side]):
			timeline.append([rng.randf(), side, "goal"])
		# possessions left: the side with the ball now has the one under way still to finish
		var poss := roundi(GameSim.POSSESSIONS * share + rng.randfn(0.0, 1.7 * sqrt(share)) + (0.5 if ball == side else 0.0))
		poss = maxi(poss, int(goals[side]) + roundi(4.0 * share))
		for _i in poss - int(goals[side]):
			var kind := "none"
			if rng.randf() < GameSim.SAVE_SHARE:
				kind = "save"
			else:
				var roll := rng.randf()
				if roll < GameSim.BLOCK_SHARE:
					kind = "block"
				elif roll < GameSim.BLOCK_SHARE + GameSim.WIDE_SHARE:
					kind = "wide"
				elif rng.randf() < GameSim.TURNOVER_SHARE:
					kind = "turnover"
			timeline.append([rng.randf(), side, kind])
		for _i in GameSim.poisson(GameSim.EXCL_MEAN * share, rng):
			timeline.append([rng.randf(), side, "excl"])
	timeline.sort_custom(func(a, b): return a[0] < b[0])
	# who's in the water: each side's seven, worked out again only when an exclusion may have
	# rolled a man out (PoloTeam.starters is the expensive part of an event)
	var sevens := [flow.us.starters(), flow.them.starters()]
	for side in 2:
		_appear(flow.state, side, sevens[side])
	for ev in timeline:
		var side := int(ev[1])
		_event(flow, side, String(ev[2]), sevens, rng)
		if String(ev[2]) == "excl":
			var def: PoloTeam = flow.them if side == 0 else flow.us
			sevens[1 - side] = def.starters()
			_appear(flow.state, 1 - side, sevens[1 - side])

## One event of `side`'s attack, into the box score, by whoever's in the water now.
## `sevens`: [yours, theirs] in the water now.
static func _event(flow: MatchFlow, side: int, kind: String, sevens: Array, rng: RandomNumberGenerator) -> void:
	var st := flow.state
	var a_field: Array = (sevens[side] as Array).slice(1)
	var d_field: Array = (sevens[1 - side] as Array).slice(1)
	match kind:
		"goal", "save", "block", "wide":
			var shooter := GameSim._pick(a_field, func(p): return PlayerForm.shot_weight(p), rng)
			st.shots[side] += 1
			if shooter != null:
				st.shot_by[side].append(shooter)
			match kind:
				"goal":
					st.add_goal(side, shooter)
					if rng.randf() < GameSim.ASSIST_SHARE:
						var others := a_field.filter(func(p): return p != shooter)
						if not others.is_empty():
							st.assist_by[side].append(others[rng.randi() % others.size()])
				"save":
					st.saves[1 - side] += 1
				"block":
					st.blocks[1 - side] += 1
					var b := GameSim._pick(d_field, func(p): return PlayerForm.block_weight(p), rng)
					if b != null:
						st.block_by[1 - side].append(b)
		"turnover":
			var lost := GameSim._pick(a_field, func(p): return PlayerForm.turnover_weight(p), rng)
			if lost != null:
				st.turnover_by[side].append(lost)
			if rng.randf() < GameSim.STEAL_SHARE:
				var thief := GameSim._pick(d_field, func(p): return PlayerForm.block_weight(p), rng)
				if thief != null:
					st.steals[1 - side] += 1
					st.steal_by[1 - side].append(thief)
		"excl":
			var drawer := GameSim._pick(a_field, func(p): return PlayerForm.excl_weight(p, GameSim.CENTER_EXCL), rng)
			st.exclusions[side] += 1
			if drawer != null:
				st.excl_drawn_by[side].append(drawer)
			var x := GameSim._pick(d_field, func(p): return PlayerForm.excl_commit_weight(p, drawer), rng)
			if x != null:
				st.excl_by[1 - side].append(x)
				flow._personal_foul(x, 1 - side)   # (his third: rolled out, his sub on from here)

static func _appear(st: MatchState, side: int, seven: Array) -> void:
	for p in seven:
		if not p in st.appeared[side]:
			st.appeared[side].append(p)

## The shootout to its end, from where it is: your penalty then theirs each round
## (MatchFlow.shootout_decided after each full round, as in play), GameSim's penalty odds.
static func _finish_shootout(flow: MatchFlow, rng: RandomNumberGenerator) -> void:
	var st := flow.state
	var teams := [flow.us, flow.them]
	# yours already taken this round (their card or their shot is up): theirs is next
	var theirs_next := flow.phase in [MatchFlow.Phase.SHOOTOUT_THEM, MatchFlow.Phase.THEIR_SHOT]
	var guard := 0
	while guard < 60:
		guard += 1
		if not theirs_next:
			if GameSim.penalty_scores(OppSim._pick_shooter(teams[0], rng), teams[1].keeper(), rng):
				st.shootout[0] += 1
		theirs_next = false
		if GameSim.penalty_scores(OppSim._pick_shooter(teams[1], rng), teams[0].keeper(), rng):
			st.shootout[1] += 1
		flow.shootout_round += 1
		if MatchFlow.shootout_decided(st.shootout[0], st.shootout[1], flow.shootout_round):
			return
	st.shootout[rng.randi() % 2] += 1   # (never in practice: sudden death that never ends)

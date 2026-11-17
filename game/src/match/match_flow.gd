class_name MatchFlow
extends RefCounted
## A match as a run of phases: sprint, your attack, their attack (live: you defend, and when
## they shoot you're the keeper), quarter breaks, a penalty shootout if it's level after four.
## Pure logic: MatchScreen shows each phase and calls the *_done() methods; tests call them
## directly.

enum Phase { SPRINT, ATTACK, DEFENSE, BREAK, SHOOTOUT_THEM, FINAL, THEIR_SHOT }

const SHOOTOUT_ROUNDS := 5
const SWIM_IN_TIME := 0.0     # clock taken off while a half-court attack sets up (off: the clock only runs with play)
const OPP_THINK := 0.4        # their ball carrier looks for a pass or a shot this often
const OPP_REACT := Vector2(0.1, 0.35)
const OPP_CATCH_SHOOT := 0.35   # ...and this quickly once he's caught it open in range
const OPP_EXPLOIT := 0.2      # ...or once he's spotted a gap the formation has left (OffenseAI.exploit)
const OPP_PRESSED_R := 1.45 # a defender this close is in his face: he hurries
const OPP_PASS_WINDUP := 0.25 # ball up to pass...
const OPP_SHOT_WINDUP := 0.35 # ...or to shoot (times KeeperDuel.WINDUP and the shooter's release)
const WINDUP_SLOWMO := 0.6    # the pool slows while he winds up a shot at your goal

var us: PoloTeam
var them: PoloTeam
var rng: RandomNumberGenerator
var state: MatchState
var phase: int = Phase.SPRINT
var play: Play = null
var opp: Dictionary = {}          # their shootout penalty: {shooter, from, penalty, lines}
var next_kind: int = Play.Kind.HALF_COURT
var shootout_round := 0
var events: Array[Dictionary] = []   # for the screen: sounds and banners
var play_no := 0                     # possessions so far: with event_no, each event's occurrence (MatchState.once)
var event_no := 0
## The difficulty (Difficulty, 0 EASY .. 0.5 MEDIUM .. 1 HARD): their AI's, fixed for the match
## (DYNAMIC included: it only moves between games). Their defence and keeper on your attack,
## their offence on theirs; your own AI defenders always play at Difficulty.TEAMMATES.
var level := Difficulty.BASELINE
var gk_memory := Vector3.ZERO       # where your shots have gone today, as their keeper has seen them (KeeperAI)
var home := true                     # you're the home team (your keeper gets the home dive)
var duel: KeeperDuel = null          # their shot, with you in goal
var duel_n := 0                      # live defence: which shot of the possession the duel is
## Their attack's brain (OffenseAI decides; this times it): a throw he's winding up ({target,
## power, t, shot}), how long the man on the ball has had it, and when he next looks.
var opp_plan: Dictionary = {}
var opp_holder: Swimmer = null
var opp_hold := 0.0
var opp_think := 0.0
var opp_pressed := false
var opp_rng := RandomNumberGenerator.new()
var opp_ai := OffenseAI.new()       # ...and what it's thinking (OffenseAI: one per possession)
var their_shots: Array = []          # where their attack's last few shots came from (OffenseAI.history: not the same shot every time)
var our_shots: Array = []            # ...and yours, in SIM, when the same brain runs your attack
var brain_level := Difficulty.BASELINE   # ...and the level it plays at (theirs: `level`; yours in SIM: TEAMMATES)
## SIM (MatchScreen's live simulation): your attack is played by that same brain, timed the same
## way (_tick_opp), at your teammates' level, and your defence calls your gameplan's drop the way
## theirs calls theirs (DropCall). Nothing else changes: the same rules, the same players.
var sim_us := false
## Tests and autoplay: the bot plays your keeper (auto_keeper 0..1; below 0, you do). Your
## field defenders are always the AI's.
var auto_keeper := -1.0
## Your keeper on their attack. He shades a little towards the ball as they move it round
## (on the angle, PlayAI.keeper_set_y, never more than TRACK_MAX off the middle), smoothly; the moment
## a shot leaves the hand he stops, and the save is yours: tap and he dives (KeeperDive). He
## never dives or saves by himself. You can go during their wind-up too, guessing: the dive runs
## its course (KeeperDive's phases) whether the ball's come or not. After a dive he falls back,
## recovers, then tracks again.
const TRACK_SKILL := 0.6
const TRACK_MAX := Geo.GOAL_HALF - PlayAI.KEEPER_POST_GAP   # m off the middle of the goal at most
const TRACK_RATE := 2.5          # how quickly he settles on the ball's side (1/s)...
const TRACK_SPEED := 0.6         # ...and never faster than this (m/s): a shuffle, not a swim
var track_y := Geo.GOAL_Y        # where tracking has him
var keeper_anim: KeeperDive = null   # his dive while it plays out with no shot in the air (an early one, the fall, the recovery)
var last_timing := ""            # your last shot faced: "early" / "late" if a dive the right way mistimed it (KeeperDuel.timing)
var keeper_out := false          # he came out for a ball thrown past their centre (Play.keeper_rush)
## Defensive formations (DefenseFormation). Yours is whatever you pick on the bar
## (select_formation), PRESS until you do. Theirs (DropCall): one drop game-planned from your
## roster before the game (their_drop), PRESS at the start of every possession and that drop
## called once your centre has position on their 2MD; at halftime they keep it or change it
## (their_half), from their first half (their_log), and that's the second half's.
var scored_by := [{"centre": 0, "outside": 0}, {"centre": 0, "outside": 0}]   # [yours, theirs]: goals and exclusions drawn
var their_drop: int = DefenseFormation.DEFAULT_DROP
var their_first_drop: int = DefenseFormation.DEFAULT_DROP   # ...the first half's, kept
var their_half := {}                 # their halftime decision (DropCall.halftime), once made
var their_log := DropCall.new_log()  # their defence's first half: your attack against it
## Your gameplan this match: your bar has PRESS and this one drop (user_formations), copied
## from Coaching at the start (set_gameplan; Career.gameplan is never written from here). At
## halftime, and only then, you get one decision (adjust_drop): the drop for Q3 and Q4.
var drop: int = DefenseFormation.DEFAULT_DROP
var first_drop: int = DefenseFormation.DEFAULT_DROP   # ...the first half's, kept
var adjusted := false                # the halftime decision is made: locked for the match
## Goals by where the scorer was playing when it went in: his tag in the possession ("C" the
## centre, "1".."5" the perimeter); a keeper's (or anyone not in the six) is neither. [yours, theirs]
var goal_spots := [{"centre": 0, "perimeter": 0, "other": 0}, {"centre": 0, "perimeter": 0, "other": 0}]
var half_stats := {}                 # their first half, frozen at the end of Q2 (opp_stats)

func _init(p_us: PoloTeam, p_them: PoloTeam, seed_value: int, minutes: float, p_level: float = Difficulty.BASELINE) -> void:
	us = p_us
	them = p_them
	rng = RandomNumberGenerator.new()
	rng.seed = seed_value
	opp_rng.seed = seed_value + 7
	state = MatchState.new(minutes)
	level = clampf(p_level, 0.0, 1.0)
	PoloTeam.clear_rolls(us)   # (a new game: everybody can play, every count at 0)
	PoloTeam.clear_rolls(them)
	their_drop = DropCall.scout(them, us)   # their game plan: your roster scouted against theirs
	their_first_drop = their_drop

# ------------------------------------------------------------------ sprint
## Their sprinter's speed in m/s; the screen races your taps against it.
func their_sprint_speed() -> float:
	return sprint_speed_of(them, rng)

## A team's sprinter's speed in m/s when the computer swims it (their sprinter; yours in SIM):
## its fastest starter, rolled with `r`.
static func sprint_speed_of(team: PoloTeam, r: RandomNumberGenerator) -> float:
	var best: PoloPlayer = null
	for p: PoloPlayer in team.starters().slice(1):
		if best == null or p.speed > best.speed:
			best = p
	var jet := Sprint.JET_BONUS if Traits.has(best, "jet") else 0.0
	return (lerpf(2.4, 3.2, best.speed / 100.0) + jet) * r.randf_range(0.95, 1.05)

func sprint_done(we_won: bool) -> void:
	var mu := carry_man_up
	carry_man_up = {}
	if we_won:
		_start_attack(Play.Kind.HALF_COURT)
	else:
		_start_defense(Play.Kind.HALF_COURT)
	# the 6 on 5 the last period ended in: only if the team that had it wins the sprint
	if not mu.is_empty() and int(mu.side) == (0 if we_won else 1) and play != null:
		play.open_man_up(float(mu.secs), mu.who)

## A 6 on 5 still running when the period ended (not ended by a goal): {side (0 yours, 1 theirs:
## who was a man up), secs left, who (the excluded man)}. Empty: none. Used by the next sprint.
var carry_man_up := {}

## The possession that ended the period: a 6 on 5 it was still in carries over to the sprint.
func _note_carry(side: int, outcome: String) -> void:
	carry_man_up = {}
	if play == null or play.kind == Play.Kind.PENALTY or state.in_shootout or outcome == "goal":
		return
	if play.man_up > 0.0 and play.excl_player != null:
		carry_man_up = {"side": side, "secs": play.man_up, "who": play.excl_player}

# ------------------------------------------------------------------ attack
## `snap`: where everybody was when we won the ball (Play.snapshot), for a counter.
func _start_attack(kind: int, snap: Dictionary = {}) -> void:
	if kind == Play.Kind.PENALTY and state.in_shootout:
		snap = {"shootout": true}   # just your shooter and their keeper
	play = _possession(us, them, kind, snap)
	_appeared(play)
	play.home_keeper = not home
	play.set_level(level)                 # their defence and keeper
	play.cpu_level = level
	play.cs_k = Difficulty.catch_shoot_k(level)   # your catch-and-shoot window against the CPU
	play.gk_memory = gk_memory
	if play.kind != Play.Kind.PENALTY:
		play.ai_drop = their_drop   # their defence: PRESS, and this drop once your centre has position (DropCall)
		play.pf = state.pf
	if sim_us:
		_reset_brain(Difficulty.TEAMMATES)
		opp_ai.history = our_shots
	phase = Phase.ATTACK

## SIM on or off (MatchScreen), from wherever the match is: the possession on the water carries on
## as it is, only who decides for your side changes.
func set_sim(on: bool) -> void:
	if on == sim_us:
		return
	sim_us = on
	if play == null or play.over:
		return
	if phase == Phase.ATTACK:
		if on:
			_reset_brain(Difficulty.TEAMMATES)
			opp_ai.history = our_shots
		elif not opp_plan.is_empty():
			opp_plan = {}            # (a throw the brain was winding up: yours to make now)
			play.raise_ball(false)
	elif phase == Phase.DEFENSE and play.defending and not play.formation_locked:
		_sim_defense(play, on)

## Your defence in SIM: PRESS, and your gameplan's drop once their centre has position, called as
## the computer calls its own (DropCall). Off: the CALL DROP button's again.
func _sim_defense(pl: Play, on: bool) -> void:
	if pl.kind == Play.Kind.PENALTY:
		return
	pl.ai_drop = drop if on else -1
	pl.pf = state.pf

## A possession's brain from scratch (OffenseAI), playing at `lvl`.
func _reset_brain(lvl: float) -> void:
	opp_plan = {}
	opp_holder = null
	opp_hold = 0.0
	opp_think = 0.0
	opp_ai.reset()
	opp_ai.iq = lvl
	brain_level = lvl

## Your attack's possession over (attack_done, counted once): into their defence's first-half log.
func _log_their_defense(outcome: String) -> void:
	if play == null or play.kind == Play.Kind.PENALTY or state.in_shootout or not their_half.is_empty():
		return
	var lg := their_log
	lg.poss += 1
	var in_drop := play.drop_t > 0.0
	if in_drop:
		lg.drop_poss += 1
	else:
		lg.press_poss += 1
	if not play.last_shot.is_empty():
		DropCall.log_shot(lg, play.last_shot, outcome, in_drop)

## Their halftime adjustment (the end of Q2: the break you make yours in): from their first half
## and their 2MD now (his fouls, a sub's if the starter's ROLLED, and who's on the bench for him).
func _their_halftime() -> void:
	if not their_half.is_empty():
		return
	var m := DropCall.matchup(them, us)
	var g: PoloPlayer = m.def.get("C")
	var bench := false
	for q in them.roster:
		if not q.rolled and not them.starters().has(q) and q.pos == PoloPlayer.Pos.DEFENDER:
			bench = true
	var first := their_drop
	their_half = DropCall.halftime(first, m, their_log, state.pf_of(g), bench)
	their_half["first"] = first
	their_drop = int(their_half.drop)
	events.append({"k": "their_halftime", "first": first, "drop": their_drop, "keep": their_half.keep,
		"reason": their_half.reason})

## Your call on the formation bar (CALL DROP: your gameplan's drop): only while you're defending
## (their attack) at even strength, once a possession, and only PRESS or your gameplan's drop.
func select_formation(f: int) -> bool:
	if phase != Phase.DEFENSE or play == null or play.over or not play.defending or play.man_up > 0.0:
		return false   # (a 6 on 5: its own defence, nothing to call)
	if not f in user_formations():
		return false
	return play.select_formation(f)

## The match's gameplan from Coaching (a drop; anything else leaves the default).
func set_gameplan(f: int) -> void:
	if DefenseFormation.is_drop(f):
		drop = f
		first_drop = f

## What your bar offers: PRESS, then the drop.
func user_formations() -> Array:
	return [DefenseFormation.F.PRESS, drop]

## The break between Q2 and Q3 (and only that one).
func at_halftime() -> bool:
	return phase == Phase.BREAK and state.quarter == 2 and not state.in_shootout

## Can you still make your halftime decision?
func can_adjust() -> bool:
	return at_halftime() and not adjusted

## Your halftime decision, confirmed: `f` (a drop; the one you had is fine) is your drop for the
## second half, and that's the only one. Once a match, at halftime only.
func adjust_drop(f: int) -> bool:
	if not can_adjust() or not DefenseFormation.is_drop(f):
		return false
	drop = f
	adjusted = true
	return true

## Their attack's numbers so far (the halftime screen shows the first half's, half_stats): goals by
## where the scorer was, shots (every one released: goals, saves, blocks, misses), shooting %,
## exclusions and 5 m penalties drawn, and the score.
func opp_stats() -> Dictionary:
	var goals := int(state.score[1])
	var shots := int(state.shots[1])
	return {"score": [int(state.score[0]), goals], "centre": int(goal_spots[1].centre), "perimeter": int(goal_spots[1].perimeter),
		"goals": goals, "shots": shots, "pct": roundi(100.0 * goals / shots) if shots > 0 else 0,
		"exclusions": int(state.exclusions[1]), "penalties": state.pen_drawn_by[1].size()}

## A goal for `side`, by where its scorer is playing in this possession.
func _note_goal(side: int, who: PoloPlayer) -> void:
	var spot := "other"
	if play != null and who != null and not who.is_keeper():
		for a in play.attackers:
			if a.player == who:
				spot = "centre" if a.tag == "C" else "perimeter"
	goal_spots[side][spot] += 1

## A goal (or an exclusion drawn) for `side`: through the centre or from outside.
func _note_scoring(side: int, who: PoloPlayer) -> void:
	if play == null or who == null:
		return
	var at_centre := false
	for a in play.attackers:
		if a.player == who:
			at_centre = a.tag == "C"
	scored_by[side]["centre" if at_centre else "outside"] += 1

## A new possession for `att`. A counter is only a counter with a man up on the break
## (Play.is_break, from where everybody is): otherwise it's a normal possession, swim-in and all.
func _possession(att: PoloTeam, def: PoloTeam, kind: int, snap: Dictionary) -> Play:
	play_no += 1
	if kind == Play.Kind.PENALTY:
		return Play.new(att, def, kind, rng, snap)
	var shot := next_shot_clock
	next_shot_clock = Play.SHOT_CLOCK   # (used once: the next possession starts over)
	if kind == Play.Kind.COUNTER:
		var p := Play.new(att, def, kind, rng, snap)
		if p.kind == Play.Kind.COUNTER:
			p.start_shot_clock(shot)
			return p
		kind = Play.Kind.HALF_COURT
	if kind == Play.Kind.HALF_COURT:
		state.tick(minf(SWIM_IN_TIME, state.clock - 1.0))
	var hp := Play.new(att, def, kind, rng)
	hp.start_shot_clock(shot)
	return hp

## The ball changed hands in live play (a steal, a turnover, a keeper's save, a shot wide, the
## shot clock): the transition takes TURNOVER_TIME off the game clock on top of the play, once,
## here, and the same off the next possession's shot clock (30 s becomes 20 s). A goal, a
## penalty, the buzzer and the start of a period aren't changes of possession in play: the shot
## clock starts over at 30.
const POSSESSION_CHANGES := ["steal", "turnover", "save", "miss", "shotclock"]
var next_shot_clock := Play.SHOT_CLOCK

func _possession_change(outcome: String) -> void:
	next_shot_clock = Play.SHOT_CLOCK
	if outcome in POSSESSION_CHANGES:
		next_shot_clock = maxf(0.0, Play.SHOT_CLOCK - state.transition())

## One frame of your attack. The game clock only runs while the ball is live.
func tick_attack(dt: float) -> void:
	if play == null:
		return
	if sim_us:
		_tick_opp(dt)   # SIM: the brain plays your attack
	var before := play.elapsed
	play.step(dt)
	_run_clock(play.elapsed - before)
	_collect(0)

func _run_clock(live: float) -> void:
	play.clutch = state.is_last_quarter() and state.clock < 60.0
	if play.kind != Play.Kind.PENALTY:
		state.run(live)
		if state.clock <= 0.0:
			play.buzzer()

## The play's events go to the box score (for `side`, the attacking team) and the screen.
func _collect(side: int) -> void:
	for e in play.events:
		# each event is one occurrence: stamped the first time it's seen, counted only then
		if not e.has("occ"):
			e["occ"] = "%d:%d" % [play_no, event_no]
			event_no += 1
		if state.once(String(e.occ)):
			_count(e, side)
		events.append(e)
	play.events.clear()

func _count(e: Dictionary, side: int) -> void:
	match String(e.k):
		"shot":
			state.shots[side] += 1
			if e.get("by") != null and not state.in_shootout:
				state.shot_by[side].append(e.by)
		"save":
			state.saves[1 - side] += 1
		"block":
			state.blocks[1 - side] += 1
			if e.get("by") != null:
				state.block_by[1 - side].append(e.by)
		"exclusion":
			state.exclusions[side] += 1
			if e.get("drawn_by") != null:
				state.excl_drawn_by[side].append(e.drawn_by)
				_note_scoring(side, e.drawn_by)
				if side == 0 and their_half.is_empty() and _is_centre(e.drawn_by):
					their_log.c_excl += 1
			if e.get("by") != null:
				state.excl_by[1 - side].append(e.by)
				_personal_foul(e.by, 1 - side)
		# your attack against their defence (DropCall's first-half log; frozen once they've decided)
		"c_position":
			if side == 0 and their_half.is_empty():
				their_log.c_threats += 1
		"formation":
			if side == 0 and their_half.is_empty() and bool(e.get("ai", false)) and DefenseFormation.is_drop(int(e.f)):
				their_log.drop_calls += 1
		"catch":
			if side == 0 and their_half.is_empty() and String(e.get("tag", "")) == "C" and DefenseFormation.is_drop(int(e.get("f", 0))):
				their_log.drop_entries += 1   # the ball into your centre with their drop on: it didn't stop it

## `who` is the centre in this possession.
func _is_centre(who: PoloPlayer) -> bool:
	if play != null:
		for a in play.attackers:
			if a.player == who:
				return a.tag == "C"
	return false

## A personal foul for `p` of side `team_side` (0 yours): an exclusion or a penalty foul he
## committed, counted once (the event's own occurrence). Two: FOUL TROUBLE. ROLL_AT: he's ROLLED,
## out for the rest of the game; his replacement (PoloTeam.starters' pick: the bench, by position)
## plays from the next possession, or from the end of the man-up if he's sitting it out now.
func _personal_foul(p: PoloPlayer, team_side: int) -> void:
	if p == null or p.rolled:
		return
	var team: PoloTeam = us if team_side == 0 else them
	var before := team.starters()
	var n := state.add_pf(p)
	if n == 2:
		events.append({"k": "foul_trouble", "p": p, "side": team_side})
	if n >= MatchState.ROLL_AT:
		p.rolled = true
		var sub: PoloPlayer = null
		for q in team.starters():
			if not before.has(q):
				sub = q
		events.append({"k": "rolled", "p": p, "side": team_side, "sub": sub})

## Who took part this possession, both sides (the box score's "played").
func _appeared(pl: Play) -> void:
	# (a Play's attackers are whoever has the ball: yours on attack, theirs when you defend)
	var mine: Array = (pl.defenders + [pl.keeper]) if pl.defending else pl.attackers
	var theirs: Array = pl.attackers if pl.defending else (pl.defenders + [pl.keeper])
	for s in mine:
		if not s.player in state.appeared[0]:
			state.appeared[0].append(s.player)
	for s in theirs:
		if not s.player in state.appeared[1]:
			state.appeared[1].append(s.player)

## The attack is over and its banner has been shown.
func attack_done() -> void:
	var r := play.result
	gk_memory = play.gk_memory   # (their keeper remembers where your shots went)
	var outcome := String(r.get("outcome", ""))
	if in_shootout():
		if outcome == "goal":
			state.shootout[0] += 1
		phase = Phase.SHOOTOUT_THEM
		opp = _their_penalty()
		return
	var their_kind := Play.Kind.HALF_COURT
	var snap := {}
	var first := state.once("%d:end" % play_no)   # (a possession's result counts once)
	if first:
		_log_their_defense(outcome)
	match outcome:
		"goal":
			if first:
				_note_scoring(0, r.scorer)
				_note_goal(0, r.scorer)
				state.add_goal(0, r.scorer)
				if r.has("assist"):
					state.assist_by[0].append(r.assist)
		"penalty":
			if first and r.get("fouled") != null:
				state.pen_drawn_by[0].append(r.fouled)
			if first and r.get("fouled_by") != null:
				state.pen_by[1].append(r.fouled_by)
				_personal_foul(r.fouled_by, 1)
			_start_attack(Play.Kind.PENALTY)
			return
		"steal", "turnover", "save":
			if first:
				_count_lost(outcome, r, 1)
			# a counter if where everybody is makes one (see _possession)
			their_kind = Play.Kind.COUNTER
			snap = play.snapshot()
	_possession_change(outcome)
	if state.quarter_over():
		_note_carry(0, outcome)
		_quarter_end()
	else:
		_start_defense(their_kind, snap)

## The ball won by side `won`: its steal (a field player's real steal, MatchState.is_steal, or
## its keeper taking a pass off them), and the turnover of the man who lost it.
func _count_lost(outcome: String, r: Dictionary, won: int) -> void:
	if MatchState.is_steal(outcome, r):
		state.steals[won] += 1
		state.steal_by[won].append(r.by)
	elif outcome == "steal" and r.get("by") != null:
		state.keeper_steal_by[won].append(r.by)
	if r.get("turnover_by") != null:
		state.turnover_by[1 - won].append(r.turnover_by)

# ------------------------------------------------------------------ their attack: you defend
func _start_defense(kind: int, snap: Dictionary = {}) -> void:
	play = _possession(them, us, kind, snap)
	play.home_keeper = home
	play.defending = true
	_appeared(play)
	play.set_level(Difficulty.TEAMMATES)  # your defenders are yours: the same at every difficulty
	play.cpu_level = level                # (their shots' pace: Difficulty.cpu_shot_speed)
	play.remote_keeper = true            # a shot on target is yours to save (the duel)
	_reset_brain(level)
	opp_ai.history = their_shots
	if sim_us:
		_sim_defense(play, true)
	duel = null
	track_y = Geo.GOAL_Y   # a new possession: he starts in the middle
	keeper_anim = null
	keeper_out = false
	play.keeper.pose = null
	phase = Phase.DEFENSE

## One frame of their attack: their brain, the play (the AI defends), and the keeper duel
## when a shot is on its way.
func tick_defense(dt: float) -> void:
	if play == null:
		return
	var game_dt := dt
	if duel != null:
		game_dt = dt * duel.slowmo
	elif play.ball.state == Ball.State.SHOT:
		# every shot at your goal is shown at the duel's pace, whatever it turns out to be: one
		# going wide (or into a hand) mustn't race past at full speed while one on target crawls
		game_dt = dt * Difficulty.duel_slowmo(level)
	elif bool(opp_plan.get("shot", false)):
		game_dt = dt * WINDUP_SLOWMO
	_tick_opp(game_dt)
	_steer_keeper(dt)
	var before := play.elapsed
	play.step(game_dt)
	_run_clock(play.elapsed - before)
	for e in play.events:
		if String(e.k) == "duel":
			_open_duel(e)
	_collect(1)
	_tick_duel(game_dt)

func _tick_opp(dt: float) -> void:
	var p := play
	if p.over or not p.can_throw():
		opp_plan = {}
		p.raise_ball(false)
		return
	if p.holder != opp_holder:
		opp_holder = p.holder
		opp_hold = 0.0
		opp_plan = {}
		opp_pressed = false
	opp_hold += dt
	if not opp_plan.is_empty():
		opp_plan.t -= dt
		if opp_plan.t <= 0.0:
			p.throw(opp_plan.target, opp_plan.power)
			opp_plan = {}
			if p.ball.state == Ball.State.PASS:
				opp_ai.passed(p, p.ball.passer, p.ball.receiver, opp_rng)
		return
	# he takes a look before he throws, unless the press is right on him or time's nearly up
	var pressed := p.openness(p.holder) <= OPP_PRESSED_R
	var clock := p.shot_clock if p.kind == Play.Kind.PENALTY else minf(p.shot_clock, state.clock)
	# the period's last seconds (the game clock): no looking round, a look every frame or so (OffenseAI._final)
	var quarter_left := INF if p.kind == Play.Kind.PENALTY else state.clock
	var at_buzzer := quarter_left <= OffenseAI.FINAL
	opp_ai.quarter_left = quarter_left
	var pace := opp_tempo(p)
	opp_ai.pace = pace
	var hold := 0.5 if p.kind == Play.Kind.PENALTY else Difficulty.value("hold", brain_level) * pace
	if opp_ai.quick_shot(p):
		hold = minf(hold, OPP_CATCH_SHOOT * pace)   # caught it with a look on: he lets fly
	if opp_ai.exploit(p, opp_rng):
		hold = minf(hold, OPP_EXPLOIT * pace)   # a gap in the formation: before they close it
	if p.holder.tag == "C" and DefenseFormation.center_time(p, p.holder) < OffenseAI.CENTER_HURRY:
		hold = 0.0   # the dropper's coming: no looking round (OffenseAI.think: a shot, or out with it)
		opp_think = minf(opp_think, OPP_REACT.x)
	if opp_hold < hold and not pressed and clock > OffenseAI.DEADLINE and not at_buzzer:
		return
	if pressed and not opp_pressed:
		# the press has got to him: he looks to move it, some quicker than others
		opp_think = minf(opp_think, opp_rng.randf_range(OPP_REACT.x, OPP_REACT.y) * pace - Difficulty.value("press_react", brain_level))
	opp_pressed = pressed
	if at_buzzer:
		opp_think = minf(opp_think, 0.0 if quarter_left <= OffenseAI.LAST_GASP else OffenseAI.FINAL_THINK)
	opp_think -= dt
	if opp_think > 0.0:
		return
	opp_think = OPP_THINK * pace
	var d := opp_ai.think(p, opp_rng, pressed, clock)
	if d.is_empty():
		return
	var shot: bool = p.aim_info(d.target).mode == "shot"
	p.raise_ball(true)
	# (a shot's wind-up isn't sped up by the team's tempo: it's your cue to get set. Only the
	# shooter's own release is: SHOOTING, Attributes.release_mult)
	opp_plan = {"target": d.target, "power": d.power, "shot": shot,
		"t": OPP_SHOT_WINDUP * KeeperDuel.WINDUP * Attributes.release_mult(p.holder.player) if shot else OPP_PASS_WINDUP * pace}
	if shot:
		events.append({"k": "windup"})

## How quickly their man on the ball looks, reacts and gets it away, as a share of the normal
## time (Tempo.think_mult): his own passing, never his team's OVR. Only the timing: what he decides
## is OffenseAI's, the same for every team.
static func opp_tempo(p: Play) -> float:
	if p.holder == null:
		return 1.0
	return Tempo.think_mult(p.holder.player.live("passing"))

## Their shot is past your defenders: you're in goal for it, on target or not (Play._shoot). Still in his last
## dive (a rebound shot)? Then that dive is the one that has to stop it.
func _open_duel(e: Dictionary) -> void:
	duel = KeeperDuel.new().setup_given(us.keeper(), e.from, float(e.cross_y), float(e.flight),
		Geo.GOAL_X, float(e.keeper_y), level, float(e.get("height", 0.5)), bool(e.get("on_target", true)), float(e.get("strain", 0.0)))
	duel.home = home
	duel_n = int(e.n)
	if keeper_anim != null:
		duel.adopt(keeper_anim)
		keeper_anim = null   # (the duel runs it now)

func _tick_duel(dt: float) -> void:
	if duel == null:
		return
	if not duel.done():
		if auto_keeper >= 0.0:
			duel.bot(dt, auto_keeper, opp_rng)
		duel.step(dt)
	play.keeper.pos.y = duel.keeper_y
	play.keeper.pose = duel.anim
	if duel.done():
		last_timing = duel.timing()
		play.set_verdict(duel.outcome, duel_n)
		keeper_anim = duel.anim   # (plays on in _steer_keeper: the fall, the recovery)
		duel = null

## Your keeper, every frame of their attack (`dt` on-screen seconds), before the play moves
## him: a dive playing out, or tracking the ball. Never while their shot is in the air.
func _steer_keeper(dt: float) -> void:
	var k := play.keeper
	if play.keeper_rush:
		keeper_out = true
		return   # out for a ball thrown past their centre: the play swims him (PlayAI._keeper_out)
	if keeper_out:
		if play.over or play.holder == k:
			keeper_out = false   # he got it: he stays where he took it
		else:
			# beaten to it: he swims back to his line, then tracks again
			k.target = Vector2(Geo.KEEPER_X, track_y)
			k.boost = 1.3
			if k.pos.distance_to(k.target) < 0.1:
				k.pos = k.target
				keeper_out = false
			return
	k.vel = Vector2.ZERO
	k.target = k.pos
	if duel != null:
		return
	if keeper_anim != null:
		keeper_anim.advance(dt)
		k.pos.y = keeper_anim.body_y()
		k.pose = keeper_anim
		if keeper_anim.done():
			keeper_anim = null
			k.pose = null
			track_y = k.pos.y
		k.target = k.pos
		return
	if play.over or play.holder == k or play.ball.state == Ball.State.SHOT or bool(opp_plan.get("shot", false)):
		return
	track_y = move_toward(track_y, lerpf(track_y, track_target(play.ball.pos), 1.0 - exp(-TRACK_RATE * dt)), TRACK_SPEED * dt)
	k.pos = Vector2(move_toward(k.pos.x, PlayAI.keeper_set_x(play.ball.pos), TRACK_SPEED * dt), track_y)
	k.target = k.pos

## Where tracking wants him for the ball at `b` (pool metres, attacking x = GOAL_X): on the
## angle, as the CPU's keeper sets (PlayAI.keeper_set_y), as a keeper of ordinary skill does.
static func track_target(b: Vector2) -> float:
	return PlayAI.keeper_set_y(b, TRACK_SKILL)

## Can a tap dive him now? With their shot in the air (the duel), or their shooter winding up
## (a guess), and never while a dive is still running: rising, up, falling or bobbing back up.
func can_dive() -> bool:
	if keeper_anim != null and not keeper_anim.done():
		return false
	if duel != null:
		return duel.can_dive()
	return phase == Phase.DEFENSE and play != null and not play.over and not keeper_out \
		and bool(opp_plan.get("shot", false))

## Tap during their shot: your keeper dives LEFT (-1), CENTRE (0) or RIGHT (+1). During their
## wind-up the dive starts now and the shot, when it comes, has to beat it (KeeperDuel.adopt).
func dive_side(side: int) -> void:
	if not can_dive():
		return
	if duel != null:
		duel.dive(side)
		return
	var gk := us.keeper()
	var probe := KeeperDuel.new().setup_given(gk, play.keeper.pos, play.keeper.pos.y, 1.0, Geo.GOAL_X, play.keeper.pos.y, level)
	probe.home = home
	keeper_anim = probe._new_dive(clampi(side, -1, 1))
	play.keeper.pose = keeper_anim

## The same from a pool height (KeeperDive.zone_for), for the bots and tests.
func dive(y: float) -> void:
	dive_side(KeeperDive.zone_for(y))

## Their attack is over and its banner has been shown.
func defense_done() -> void:
	var r := play.result
	var outcome := String(r.get("outcome", ""))
	next_kind = Play.Kind.HALF_COURT
	var snap := {}
	var first := state.once("%d:end" % play_no)
	match outcome:
		"goal":
			if first:
				_note_scoring(1, r.scorer)
				_note_goal(1, r.scorer)
				state.add_goal(1, r.scorer)
				if r.has("assist"):
					state.assist_by[1].append(r.assist)
		"penalty":
			if first and r.get("fouled") != null:
				state.pen_drawn_by[1].append(r.fouled)
			if first and r.get("fouled_by") != null:
				state.pen_by[0].append(r.fouled_by)
				_personal_foul(r.fouled_by, 0)
			_start_defense(Play.Kind.PENALTY)
			return
		"steal", "turnover", "save":
			if first:
				_count_lost(outcome, r, 0)
			next_kind = Play.Kind.COUNTER
			snap = play.snapshot()
	_possession_change(outcome)
	if state.quarter_over():
		_note_carry(1, outcome)
		_quarter_end()
	else:
		_start_attack(next_kind, snap)

## Tests: plays their whole possession to the end, the bot in goal.
func auto_defense(keeper_skill: float, limit: float = 90.0) -> float:
	auto_keeper = keeper_skill
	var t := 0.0
	var dt := 1.0 / 30.0
	while not play.over and t < limit:
		tick_defense(dt)
		t += dt
	events.clear()
	return t

# ------------------------------------------------------------------ the shootout: their penalties
## Their shootout penalty has been read. You're in goal for it.
func their_ball_done() -> void:
	if opp.get("shot", false) and duel == null:
		duel = KeeperDuel.new().setup(opp.shooter, us.keeper(), opp.from, 0.0, rng, level, true)
		duel.home = home
		phase = Phase.THEIR_SHOT

## The shootout duel is over and its banner has been shown.
func duel_done() -> void:
	var d := duel
	duel = null
	if d.outcome == "goal":
		state.shootout[1] += 1
	_shootout_next()

## Tests and autoplay: the bot keeper plays the duel. skill 0..1 (see KeeperDuel.bot).
func auto_duel(skill: float) -> String:
	var brng := RandomNumberGenerator.new()
	brng.seed = rng.randi()
	return duel.auto(skill, brng)

# ------------------------------------------------------------------ breaks, shootout
func _quarter_end() -> void:
	if state.quarter == 2 and not state.in_shootout and half_stats.is_empty():
		half_stats = opp_stats()   # the first half, frozen: nothing after Q2 changes it
	if state.quarter == 2 and not state.in_shootout:
		_their_halftime()          # ...and their defence's look at it: keep the drop, or change it
	play = null
	phase = Phase.BREAK

func break_done() -> void:
	next_shot_clock = Play.SHOT_CLOCK   # a new period: a fresh shot clock
	if not state.is_last_quarter():
		state.next_quarter()
		phase = Phase.SPRINT
		return
	if state.tied():
		state.in_shootout = true
		shootout_round = 0
		_start_attack(Play.Kind.PENALTY)
	else:
		phase = Phase.FINAL

func in_shootout() -> bool:
	return state.in_shootout and phase != Phase.FINAL

## Their penalty in the shootout: a card to set it up, then you're in goal for it.
func _their_penalty() -> Dictionary:
	var shooter := OppSim._pick_shooter(them, rng)
	return {"shot": true, "penalty": true, "shooter": shooter, "from": Vector2(Geo.LENGTH - Geo.FIVE_M, Geo.GOAL_Y),
		"tone": "neutral", "lines": ["%s STEPS UP..." % shooter.tag()]}

func _shootout_next() -> void:
	shootout_round += 1
	if shootout_decided(state.shootout[0], state.shootout[1], shootout_round):
		phase = Phase.FINAL
	else:
		_start_attack(Play.Kind.PENALTY)

## Is the shootout over at `a` - `b` (yours - theirs) after `rounds` full rounds? Within
## SHOOTOUT_ROUNDS only once one side can't be caught; after them, sudden death.
static func shootout_decided(a: int, b: int, rounds: int) -> bool:
	if rounds >= SHOOTOUT_ROUNDS:
		return a != b
	var left := SHOOTOUT_ROUNDS - rounds
	return a > b + left or b > a + left

## Their shootout penalty is in (the duel, before duel_done counts it): does it win them the
## game? Yours never can: they always take theirs after it.
func their_penalty_wins() -> bool:
	var a: int = state.shootout[0]
	var b: int = state.shootout[1] + 1
	return b > a and shootout_decided(a, b, shootout_round + 1)

func result_text() -> String:
	var w := state.winner()
	if w == 0:
		return "WIN"
	if w == 1:
		return "LOSS"
	return "DRAW"

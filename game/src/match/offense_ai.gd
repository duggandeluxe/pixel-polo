class_name OffenseAI
extends RefCounted
## Their attack's brain in single player (MatchFlow runs one per possession). It plays to score:
## every look at the ball weighs his own shot against every pass and a drive, and the bar for a
## shot comes down as the possession goes on, so a settled attack swings the ball, feeds the
## centre and attacks the gaps, then shoots. It remembers the possession's passes, so it doesn't
## ping-pong between two men, and it never runs the shot clock out on purpose: from DEADLINE it
## takes the best shot it has.
##
## Shot quality (shot_quality) is a rough 0..1 for "how good a look is this": range and angle,
## the man on him, a raised hand in the lane, catch and shoot, cross-cage with the keeper on the
## near post, the centre at 2 m, the shooter's rating. Only the decisions use it; ShotModel still
## decides the shot itself.
##
## How well it decides is its difficulty (`iq`, Difficulty 0..1): how far off its judgement of a
## look or a pass is ("eval_noise"), how often it doesn't see a teammate ("overlook"), how much it
## wants the ball in to the man at 2 m ("center_use"), how often the shooter picks the open side
## rather than a spot you can read ("aim_smart"), and a plain mistake now and then ("mistake").
## Once it has chosen, the throw is the same at every level: the passer's Passing, the shooter's
## Shooting, ShotModel's flight.

## Decisions
const DEADLINE := 4.0          # shot clock (or game clock) below this: shoot whatever he has
const RESTART_MOVE := 2.0      # a free throw held this long (the shot clock stopped): he moves it on, any pass
const LAST_PASS := 7.0         # below this a pass has to set up a better shot than his own
const PATIENT := 5.5           # seconds into a settled possession before the bar starts to drop...
const URGENT := 16.0           # ...and by here it's down to the floor
const SHOT_BAR := Vector2(0.84, 0.28)   # the shot quality he needs: patient .. urgent
const BREAK_BAR := 0.32        # on the break, any decent look
const MAN_UP_BAR := 0.5        # a power play works it to the free man, then shoots
const PASS_EDGE := 0.1         # a pass has to beat his own shot by this...
const PASS_ROOM := 0.7         # nobody closer than this to the line of a pass he chooses to make
const PASS_ROOM_C := 0.75      # ...more into the crowd at 2 m
const PASS_MIN := 0.42         # ...and a swing has to find a man with at least this good a look
const SWING_PASSES := 4        # a pass that only swings it (to the side the defence has left) is
                               # worth making for the first few passes...
const SWING_LEAN := 0.4        # ...once the defence has shifted this far (m) to one side
const BACK_PASS := 0.3         # straight back to the man who gave it to him
const BACK_PASS_ANY := 1.5     # ...when he just has to get rid of it, metres of room it costs
const BACK_PASS_OK := 0.25     # ...unless that's a clearly better shot (a give-and-go)
const IN_RANGE_ANY := 1.0      # ...and inside 6 m (allowed to shoot it), worth this much room
const PAIR_REPEAT := 0.15      # each earlier pass between the same two men
const PASSES_SOFT := 3         # from this many passes on, each more costs PASS_TIRED
const PASS_TIRED := 0.1
const SWING_BONUS := 0.08      # the ball to the side the defence has left
const CENTER_FEED := 0.07      # into the centre from the side his guard isn't on (it draws exclusions)...
const CENTER_FEED_STRAIGHT := 0.03   # ...or straight down from the point, his guard beside him
const CENTER_SWING := 0.1      # the centre's guard is on this side: the ball round to the other side
const DRIVER_BONUS := 0.08     # hitting a driver in stride
const PRESSED_EDGE := -0.06    # the press in his face: he moves it on for less...
const PRESSED_SHOT := 0.06     # ...or shoots over it, if it's this close to good enough
const PRESS_MOVE := 0.9        # pressed this long (Play.pressure) and any decent pass will do...
const PRESS_LIMIT := 1.8       # ...this long and he gets rid of it, one way or the other
const QUICK_RANGE := 6.5       # straight off the catch only inside this range...
const QUICK_OPEN := 1.3        # ...and with this much room
## Driving with the ball: open water in front of him and out of range, he swims at the goal.
const DRIVE_FROM := 4.6        # further than this from the goal...
const DRIVE_CLEAR := 1.2       # ...nobody within this of his path...
const DRIVE_LEN := 2.4         # ...for this far
const DRIVE_TIME := 1.4
const DRIVE_GAIN := 0.07       # ...and it has to be at least this much better a place to shoot from
const DRIVE_GUARD_OFF := 2.0   # his own man in front of him and closer than this: no way past
const IN_RANGE_DEPTH := 0.8    # outside 6 m: a drive this far inside the line...
const IN_RANGE_GAIN := 0.15    # ...worth this much more (it's somewhere he's allowed to shoot)
const IN_RANGE_SLANT := 2.0    # ...or slanting this far across, off his man's shoulder
const GIVE_AND_GO := 0.3      # after a pass, the passer cuts for the goal this often (if it's open)
## Reading the defence's formation (DefenseFormation), from where its men are, never from what
## anybody's about to do:
const PRESS_CENTER := 1.3     # the centre against PRESS has only his own man on him: worth more to feed
const DROP_FEED := -0.12      # ...an entry with a dropper set in front of him is worth less than nothing
const LEFT_OPEN := 0.08       # a man his own defender has left (a help, a drop, a split) with room...
const LEFT_OPEN_ROOM := 2.0   # ...this much of it (and he takes the water in front of him: OPEN_DRIVE_CLEAR)
const OPEN_DRIVE_CLEAR := 0.75
const OPEN_LOOK := 0.25       # ...and with the ball in range, that open look is worth taking this much sooner
const OPEN_QUICK := 7.5       # ...straight off the catch from as far as this
const PISTON_SWING := 0.08    # the quick ball between the two pistons' men...
const PISTON_SEE := 0.6       # ...when he spots it (not every look: it's a habit, not a script)
const CENTER_HURRY := 0.9     # the centre with the ball and the dropper this many seconds off: act now
const HURRY_SHOT := 0.3       # ...a shot this good, or the ball back out
## The end of a period (the game clock, `quarter_left`, never the shot clock): a shot before the
## buzzer, from wherever he is. See _final.
const FINAL := 5.0             # game-clock seconds left: every look is a look for the last shot
const SURE := 3.0              # ...from here he shoots whatever he has, bar a much better look a pass away
const LAST_GASP := 1.0         # ...and from here he just lets it go
const FINAL_THINK := 0.1       # (MatchFlow: he looks this often in the last seconds, every frame from LAST_GASP)
const FINAL_PASSES := 1        # passes he'll make in the last seconds: one quick one at most
const FINAL_EDGE := Vector2(0.15, 0.3)   # how much better the pass's look has to be: FINAL..SURE, SURE..LAST_GASP
const FINAL_MARGIN := 0.3      # game-clock seconds to spare on a last pass (the catch, a bobble)
## Not the same shot every time: the team remembers where its last few shots came from (`history`,
## this match, MatchFlow's per team), and a look from that same water is worth less for each, the
## most recent the most. So once a drop has given up one spot a few times, the attack works the
## ball for something else (it still takes it when nothing better turns up as the clock runs down).
const REPEAT_KEEP := 6         # shots remembered
const REPEAT_R := 1.5          # m: a look this close to one of them is "the same spot"
const REPEAT_COST := 0.06      # ...worth this much less for each (the latest; older ones less: REPEAT_FADE)
const REPEAT_FADE := 0.8
const REPEAT_MAX := 0.18
## The shooter's side of the goal: most shots go across the keeper (the side he isn't on), but
## this often he goes near post instead, more often when the keeper's cheated across (NEAR_CHEAT).
const NEAR_POST := 0.2
const NEAR_CHEAT := 0.35       # ...more by this, the keeper a full metre off the middle away from the shooter's side

var passes := 0
var pairs := {}                # "a|b" (the two men, either way round) -> passes between them
var last_from: Swimmer = null  # who gave the man with the ball the ball
var why := ""                  # the last decision (for the stats): deadline, look, pass, pressed, drive, late, wait
var why_q := 0.0               # ...and the shot quality he had
var tally := {}                # every decision this possession, by `why`
## How quickly his team plays (MatchFlow.opp_tempo, a share of the normal time): the possession
## runs on its clock, so an elite team gets through its patient phase and to its shot sooner.
var pace := 1.0
var iq := Difficulty.BASELINE
var seen_for: Swimmer = null   # who the last look at the defence's gaps was for (exploit), and what he saw
var seen := false
## Game-clock seconds left in the period (MatchFlow sets it every look; INF: no buzzer to beat).
var quarter_left := INF
var late_passes := 0           # passes made inside the last FINAL seconds
var history: Array = []        # this team's last REPEAT_KEEP shots this match (Vector2), MatchFlow's: never reset here

func reset() -> void:
	passes = 0
	late_passes = 0
	quarter_left = INF
	pairs.clear()
	last_from = null
	tally.clear()
	seen_for = null
	seen = false

## The ball has been passed (MatchFlow tells it as the throw goes): remember who to whom. Now
## and then the passer cuts for the goal behind it (a give-and-go), if he has the water to.
func passed(p: Play, from: Swimmer, to: Swimmer, rng: RandomNumberGenerator) -> void:
	passes += 1
	if quarter_left <= FINAL:
		late_passes += 1
	last_from = from
	if to != null:
		var k := _pair(from, to)
		pairs[k] = int(pairs.get(k, 0)) + 1
	if from == null or from.tag == "C" or p.man_up > 0.0 or p.carry or rng.randf() > GIVE_AND_GO:
		return
	if from.pos.distance_to(Geo.goal_center()) < DRIVE_FROM or PlayAI.releasing(p):
		return
	var cut := PlayAI.release_to(from, Vector2(Geo.TWO_M - 0.6, lerpf(from.pos.y, Geo.GOAL_Y, 0.5)))
	if PlayAI.lane_space(p, from.pos, cut) < DRIVE_CLEAR - 0.5:
		return
	from.drive_t = PlayAI.DRIVE_TIME
	from.drive_goal = cut

## How far into the possession it is, 0 (patient) .. 1 (shoot the next decent look).
func urgency(p: Play) -> float:
	var used := (p.shot_start - p.shot_clock) / pace   # (this possession's: a transition's 10 s isn't his)
	var u := clampf((used - PATIENT) / (URGENT - PATIENT), 0.0, 1.0)
	if passes >= PASSES_SOFT:
		u += 0.1 * (passes - PASSES_SOFT + 1)
	return clampf(u, 0.0, 1.0)

## The shot quality he needs right now.
func bar(p: Play) -> float:
	if p.carry or p.counter_t > 0.0:
		return BREAK_BAR
	var b := lerpf(SHOT_BAR.x, SHOT_BAR.y, urgency(p))
	if p.man_up > 0.0:
		b = minf(b, MAN_UP_BAR)
	return b

## Should he let it go straight off the catch (MatchFlow skips his look round)? Caught open in
## range, as before, and with a look good enough to take.
func quick_shot(p: Play) -> bool:
	var h := p.holder
	if h == null or not _can_shoot(p):
		return false
	var reach := OPEN_QUICK if left_open_look(p, h) else QUICK_RANGE
	return Geo.range_to_goal(h.pos) < reach and p.openness(h) > QUICK_OPEN \
		and shot_quality(p, h, h.pos, p.catch_t) >= bar(p) - (OPEN_LOOK if left_open_look(p, h) else 0.0)

## `s` is the man the formation has left (his own defender off him on another job) and he has the
## water: the look the formation gives away, worth taking before they're back (OPEN_LOOK,
## OPEN_QUICK). Only a fresh one: his man gone to help, closing on someone else, crashing or still
## on his way back. A drop's standing gap (his man sat on his SAG / DROP / SPLIT spot all
## possession) isn't going anywhere: against that the attack stays patient and works the ball (it's
## still a good look: LEFT_OPEN on a pass to him, and shot_quality's open water).
func left_open_look(p: Play, s: Swimmer) -> bool:
	return DefenseFormation.left_open(p, s) and _space(p, s, s.pos) > LEFT_OPEN_ROOM and not standing_gap(p, s)

const STANDING := [DefenseFormation.Duty.SAG, DefenseFormation.Duty.DROP, DefenseFormation.Duty.SPLIT]

## `s`'s own defender is off him on the formation's standing job (STANDING), not a passing one.
func standing_gap(p: Play, s: Swimmer) -> bool:
	var own := DefenseFormation.by_tag(p.defenders, s.tag, true)
	return own != null and own.duty in STANDING

## One look at the ball. `clock`: the time left to get a shot off (the shot clock, or the game
## clock if that's shorter). Returns {} (keep it) or {target, power}.
func think(p: Play, rng: RandomNumberGenerator, pressed: bool, clock: float) -> Dictionary:
	if not p.can_throw():
		return {}
	var h := p.holder
	if p.kind == Play.Kind.PENALTY:
		return _shot(p, rng)
	if quarter_left <= FINAL:
		return _final(p, rng)
	var can_shoot := _can_shoot(p)
	# the centre with the ball and the dropper coming at him: he has a moment, then it's the
	# dropper's (DefenseFormation.interference). A shot if there's one, else back out with it.
	if h.tag == "C" and DefenseFormation.center_time(p, h) < CENTER_HURRY:
		var cq := shot_quality(p, h, h.pos, p.catch_t) if can_shoot else -1.0
		if can_shoot and cq >= HURRY_SHOT:
			_decided("hurry", cq)
			return _shot(p, rng)
		var out := _best_pass(p, rng, 0.0, 0.0, true)
		if not out.is_empty():
			_decided("hurry", cq)
			return out.throw
	# a plain mistake: he rushes it (the first thing he sees) or sits on it
	if clock >= DEADLINE and rng.randf() < Difficulty.value("mistake", iq):
		var r := rng.randf()
		if r < 0.35 and can_shoot:
			_decided("mistake", shot_quality(p, h, h.pos, p.catch_t))
			return _shot(p, rng)
		if r < 0.7:
			var any := _best_pass(p, rng, 0.0, 0.0, true)
			if not any.is_empty():
				_decided("mistake", 0.0)
				return any.throw
		_decided("mistake", 0.0)
		return {}
	# out of time: the best shot he has, or (a free throw inside 6 m) the safest pass
	if clock < DEADLINE:
		_decided("deadline", 0.0)
		if can_shoot:
			return _shot(p, rng)
		var last := _best_pass(p, rng, 0.0, 0.0, true, true)
		return {} if last.is_empty() else last.throw
	var own := shot_quality(p, h, h.pos, p.catch_t) + rng.randfn(0.0, Difficulty.value("eval_noise", iq)) if can_shoot else -1.0
	var need := bar(p)
	if can_shoot and left_open_look(p, h):
		need -= OPEN_LOOK   # the formation's left him: take it before they're back
	var best := _best_pass(p, rng, own, need, false)
	var edge := PASS_EDGE + (PRESSED_EDGE if pressed else 0.0)
	var moving_on := pressed and p.pressure > PRESS_MOVE
	# a pass has to beat his own shot and have a point: see _best_pass's `purpose` (a free throw
	# inside 6 m has to be passed, so any pass will do; outside 6 m he can't shoot either, but he
	# only moves it on with a point to it: otherwise he swims it in or waits, as with a poor look)
	var must_pass := p.shot_barred() or (p.restart and p.restart_t >= RESTART_MOVE)
	var pass_ok := not best.is_empty() and float(best.value) > own + edge \
		and (String(best.purpose) != "" or moving_on or must_pass) \
		and (clock > LAST_PASS or float(best.q) > own + 0.1)
	# a free throw he can't shoot (fouled inside 6 m, Play.shot_barred): any pass that's there, the
	# safest if nothing better, never holding it (the shot clock's stopped: Play.restart)
	if must_pass and not can_shoot:
		var fallback := best if not best.is_empty() else _best_pass(p, rng, 0.0, 0.0, true)
		if fallback.is_empty() and p.restart_t >= RESTART_MOVE:
			fallback = _freest_mate(p)   # everybody's covered: the most open man all the same
		if not fallback.is_empty():
			_decided("free_throw", own)
			return fallback.throw
	# A: a good enough look, and no pass makes a clearly better one
	if can_shoot and own >= need and not pass_ok:
		_decided("look", own)
		return _shot(p, rng)
	# B: move it on with a purpose: the open man, the centre, the driver, the weak side
	if pass_ok:
		_decided("pass", own)
		return best.throw
	# C: the press is on him: over the top if it's nearly good enough; pressed a while (he'd be
	# stripped), whatever he has: a shot or the safest pass
	if pressed and can_shoot and own >= need - PRESSED_SHOT:
		_decided("pressed", own)
		return _shot(p, rng)
	if pressed and p.pressure > PRESS_LIMIT:
		if can_shoot and own > 0.2:
			_decided("pressed", own)
			return _shot(p, rng)
		# outside 6 m he has no shot to fall back on: a pass nobody can get a hand to, or out of
		# his man's way with it, before he just gets rid of it
		var out := {}
		if not can_shoot and not must_pass:
			out = _best_pass(p, rng, 0.0, 0.0, false)
			if out.is_empty() and _start_drive(p, rng):
				_decided("drive", own)
				return {}
		if out.is_empty():
			out = _best_pass(p, rng, 0.0, 0.0, true)
		if not out.is_empty():
			_decided("pass", own)
			return out.throw
	# D: open water: swim it in, or into the slot for a better angle
	if _start_drive(p, rng):
		_decided("drive", own)
		return {}
	# E: late in the possession, the best he has
	if can_shoot and urgency(p) >= 0.9 and own > 0.12:
		_decided("late", own)
		return _shot(p, rng)
	# F: hold it while the others move (the bar comes down as the clock runs)
	_decided("wait", own)
	return {}

## The period's last FINAL seconds: he gets a shot away before the buzzer. Outside 6 m too (the
## only time the AI shoots from out there): a desperation shot, as hard as ShotModel makes any
## shot from that far. Until SURE, one quick pass to a clearly better look in range if it gets
## there with time to shoot, or the break / a drive carrying him in out of range; then only a
## much better look is worth the pass; from LAST_GASP, the shot. None of it gets round the
## rules: a free throw inside 6 m still has to be passed (Play.shot_barred), to a man in range.
## The wind-up is as ever (MatchFlow): let it go too late and the buzzer beats it.
func _final(p: Play, rng: RandomNumberGenerator) -> Dictionary:
	var h := p.holder
	var t := quarter_left
	if p.shot_barred():
		var out := _best_pass(p, rng, 0.0, 0.0, true, true)
		if out.is_empty():
			out = _freest_mate(p)
		_decided("final_pass", 0.0)
		return {} if out.is_empty() else out.throw
	var own := shot_quality(p, h, h.pos, p.catch_t) + rng.randfn(0.0, Difficulty.value("eval_noise", iq))
	if t > LAST_GASP and late_passes < FINAL_PASSES:
		var feed := _final_pass(p, rng, own + (FINAL_EDGE.x if t > SURE else FINAL_EDGE.y))
		if not feed.is_empty():
			_decided("final_pass", own)
			return feed
	if t > SURE and not Geo.in_shot_range(h.pos):
		# out of range with a moment yet: the break carries him in, or he swims it in
		if p.carry or h.drive_t > 0.0 or _start_drive(p, rng):
			_decided("final_move", own)
			return {}
	_decided("final", own)
	return _shot(p, rng)

## The last-seconds pass: the best look (shot_quality where he'd catch it) better than `beat`, at
## a man inside 6 m with a safe lane, that gets there with time for him to shoot. {} if none.
func _final_pass(p: Play, rng: RandomNumberGenerator, beat: float) -> Dictionary:
	var h := p.holder
	var no_back := p.back_pass_barred()
	var overlook := Difficulty.value("overlook", iq)
	var best := {}
	var best_q := beat
	for a in p.attackers:
		if a == h or a.out or rng.randf() < overlook:
			continue
		var lead := a.pos + a.vel * 0.3
		var at := p.lead_point(a)
		if not Geo.in_shot_range(at) or (no_back and Play.is_back_pass(h.pos, lead)):
			continue
		if p.pass_risk(lead, a) != null or _lane_room(p, h.pos, lead, a) < PASS_ROOM:
			continue
		if quarter_left <= _pass_cost(h, a, at):
			continue   # it wouldn't get there with time to shoot it
		var q := shot_quality(p, a, at, 0.0 if _space(p, a, a.pos) > QUICK_OPEN else INF)
		if q > best_q:
			best_q = q
			best = {"target": lead, "power": 0.5}
	return best

## Game-clock seconds from now until `to` lets a shot go, if `from` passes it to him at `at`: the
## pass's wind-up and flight, his look and his wind-up (MatchFlow's timings), and a little spare.
func _pass_cost(from: Swimmer, to: Swimmer, at: Vector2) -> float:
	var live := MatchFlow.OPP_PASS_WINDUP * pace + from.pos.distance_to(at) / Play.PASS_SPEED \
		+ FINAL_THINK + MatchFlow.OPP_SHOT_WINDUP * KeeperDuel.WINDUP * Attributes.release_mult(to.player)
	return live * MatchState.CLOCK_SPEED + FINAL_MARGIN

func _decided(w: String, q: float) -> void:
	why = w
	why_q = q
	tally[w] = int(tally.get(w, 0)) + 1

# ------------------------------------------------------------------ shots
## Never from outside 6 m (Geo.in_shot_range), however late the shot clock is: from out there he
## passes or swims it in, and if the clock runs out first that's a shot clock violation. (The end
## of a period is the one exception: _final.)
func _can_shoot(p: Play) -> bool:
	return Geo.in_shot_range(p.holder.pos) and not p.shot_barred()

## How good a look `s` has from `at` (0..1): see the top. `catch_t` as Play's.
func shot_quality(p: Play, s: Swimmer, at: Vector2, catch_t: float) -> float:
	var d := at.distance_to(Geo.goal_center())
	var q := spot_quality(at)
	var o := _space(p, s, at)
	var centre := s.tag == "C" and at.distance_to(PlaySetup.HOME_6V6["C"]) <= Play.CENTER_SPOT_R
	if centre:
		q *= 0.78 if o < 1.0 else 1.0   # his man's on his back: he turns and shoots anyway
	elif o < 1.0:
		q *= 0.55
	elif o < 1.6:
		q *= 0.8
	elif o > 2.6:
		q *= 1.1
	if s == p.holder and _lane_shut(p):
		q *= 0.4
	q += 0.12 * ShotModel.catch_shoot(catch_t, p.cs_k)
	var aim_y := _aim_y(p, at)
	q += 0.1 * ShotModel.cross_cage(at, aim_y, p.keeper.pos.y)
	if centre:
		q += 0.06
	q *= lerpf(0.85, 1.15, clampf(s.player.live("shoot") / 100.0, 0.0, 1.0))
	if s.player.trait_id in ["cannon", "ice"] and d < 8.0:
		q += 0.04
	return q - repeat_cost(at)

## How much less a look from `at` is worth for the team's recent shots from the same water.
func repeat_cost(at: Vector2) -> float:
	var c := 0.0
	var w := 1.0
	for i in range(history.size() - 1, -1, -1):
		if (history[i] as Vector2).distance_to(at) <= REPEAT_R:
			c += REPEAT_COST * w
		w *= REPEAT_FADE
	return minf(c, REPEAT_MAX)

## The man with the ball's guard has a hand up in both his lanes (far post and near post).
func _lane_shut(p: Play) -> bool:
	var far := Vector2(Geo.GOAL_X + 0.4, _aim_y(p, p.holder.pos))
	var near := Vector2(Geo.GOAL_X + 0.4, 2.0 * Geo.GOAL_Y - far.y)
	return p.lane_blocked(far) and p.lane_blocked(near)

## Where he aims from `at`: the side of the goal the keeper isn't on.
func _aim_y(p: Play, _at: Vector2) -> float:
	return Geo.GOAL_Y + (1.15 if p.keeper.pos.y < Geo.GOAL_Y else -1.15)

## The shot itself: far side of the keeper, or now and then (NEAR_POST, more with the keeper
## cheating across) the near post; the other side if a hand is up in that lane; or, when he
## doesn't pick it well ("aim_smart"), a spot you can read: his own side of the goal, the near
## post. Power and the wrist are as before (ShotModel's spread is the AI's accuracy, the same at
## every level). Remembered for `history`.
func _shot(p: Play, rng: RandomNumberGenerator) -> Dictionary:
	why_q += repeat_cost(p.holder.pos)   # (the stats: the look he took, not what the memory made of it)
	history.append(p.holder.pos)
	while history.size() > REPEAT_KEEP:
		history.pop_front()
	var y := _aim_y(p, p.holder.pos) + rng.randf_range(-0.2, 0.2) * signf(Geo.GOAL_Y - p.keeper.pos.y + 0.001)
	var side := signf(p.holder.pos.y - Geo.GOAL_Y) if absf(p.holder.pos.y - Geo.GOAL_Y) > 0.5 else 0.0
	if side != 0.0:
		var cheat := clampf((Geo.GOAL_Y - p.keeper.pos.y) * side, 0.0, 1.0)   # (the keeper off the middle, away from the shooter's side)
		if rng.randf() < NEAR_POST + NEAR_CHEAT * cheat:
			y = Geo.GOAL_Y + side * rng.randf_range(0.95, 1.2)   # near post
	if rng.randf() >= Difficulty.value("aim_smart", iq):
		var own_side := signf(p.holder.pos.y - Geo.GOAL_Y)
		y = Geo.GOAL_Y + (own_side if own_side != 0.0 else 1.0) * rng.randf_range(0.6, 1.0)
	var target := Vector2(Geo.GOAL_X + 0.4, y)
	if p.lane_blocked(target):
		var near := Vector2(Geo.GOAL_X + 0.4, 2.0 * Geo.GOAL_Y - y)
		if not p.lane_blocked(near):
			target = near
	return {"target": target, "power": rng.randf_range(0.65, 0.9)}

# ------------------------------------------------------------------ passes
## The best pass: {throw, value, q, to, purpose} or {}. Each open teammate is worth the shot
## he'd have when it gets there, plus what the pass does (the weak side, the centre, a driver),
## minus going back where it came from and passing between the same two again. `purpose` is why
## it's worth making at all: "shot" (it sets up a look good enough to take, `need`), "centre" (in
## to the centre with position), "driver" (a man cutting, in stride), "swing" (reversing it to
## the side the defence has left, early on); "" is just moving it about. `any`: the safest one
## (`to_range`: out of time, the safest to a man inside 6 m, who can shoot it, if there is one).
func _best_pass(p: Play, rng: RandomNumberGenerator, own: float, need: float, any: bool, to_range := false) -> Dictionary:
	var h := p.holder
	var lean := _defence_lean(p)
	# the centre's guard on our side of him: swinging it to the other side opens the entry
	var c := PlaySetup._by_tag(p, "C")
	var fronted := p.center_entry(h.pos, c) == "fronted" if h != c else false
	var best := {}
	var best_v := -INF
	var overlook := Difficulty.value("overlook", iq)
	var noise := Difficulty.value("eval_noise", iq)
	var no_back := p.back_pass_barred()
	for a in p.attackers:
		if a == h or a.out:
			continue
		if not any and rng.randf() < overlook:
			continue   # he doesn't see him this look
		var lead := a.pos + a.vel * 0.3
		if no_back and Play.is_back_pass(h.pos, lead):
			continue   # on the counter, with men still to come over halfway: forward or square only
		if p.pass_risk(lead, a) != null:
			continue
		if not any and a.tag == "C" and p.entry_closing(a):
			continue   # his guard's on his way round to this side: by the time it's thrown, it's his
		if not any and _lane_room(p, h.pos, lead, a) < (PASS_ROOM_C if a.tag == "C" else PASS_ROOM):
			continue   # a hand could still get to it: not a pass he plans to make
		var open := _space(p, a, a.pos)
		if open < 0.9 and a.tag != "C":
			continue
		var at := p.lead_point(a)
		var q := shot_quality(p, a, at, 0.0 if open > 1.3 else INF)
		var v := q
		var purpose := ""
		if any:
			v = open - (BACK_PASS_ANY if a == last_from else 0.0)   # (still not straight back, if there's anyone else)
			if to_range and Geo.in_shot_range(at):
				v += IN_RANGE_ANY   # out of time: to a man who's allowed to shoot it
		else:
			var weak := signf(a.pos.y - Geo.GOAL_Y) == -signf(lean) and absf(lean) > SWING_LEAN
			if weak:
				v += SWING_BONUS * clampf(absf(lean), 0.0, 1.5)
			if fronted and a.tag != "C" and Play.entry_side(a.pos, c) == -Play.entry_side(h.pos, c):
				v += CENTER_SWING
				weak = true
			var feed := _center_feed(p, a) * Difficulty.value("center_use", iq) if a.tag == "C" else 0.0
			if feed > 0.0:
				v += feed
				purpose = "centre"
			if a.drive_t > 0.0 and open > 1.2:
				v += DRIVER_BONUS
				purpose = "driver"
			if DefenseFormation.left_open(p, a) and open > LEFT_OPEN_ROOM:
				v += LEFT_OPEN   # his man's gone to help (or dropped off him): hit him before he's back
			var pair := DefenseFormation.piston_tags(p)
			if h.tag in pair and a.tag in pair and DefenseFormation.active(p) and rng.randf() < PISTON_SEE:
				v += PISTON_SWING   # the quick ball across the pistons: one of them has to swim
				if purpose == "":
					purpose = "swing"
			if q >= need - 0.05 and Geo.in_shot_range(at):
				purpose = "shot"
			elif purpose == "" and weak and passes < SWING_PASSES and q >= PASS_MIN:
				purpose = "swing"
			if a == last_from:
				v -= BACK_PASS_OK * 0.4 if q > own + BACK_PASS_OK else BACK_PASS
			v -= PAIR_REPEAT * int(pairs.get(_pair(h, a), 0))
			if passes >= PASSES_SOFT:
				v -= PASS_TIRED * (passes - PASSES_SOFT + 1)
			v += rng.randf() * 0.05 + rng.randfn(0.0, noise)
		if v > best_v:
			best_v = v
			best = {"throw": {"target": lead, "power": 0.5}, "value": v, "q": q, "to": a,
				"purpose": purpose}
	return best

## The teammate with the most water round him (and a lane he can be found in if there is one):
## the free throw that has to go to someone, when no pass is safe. {} with nobody to throw to.
func _freest_mate(p: Play) -> Dictionary:
	var h := p.holder
	var best := {}
	var best_v := -INF
	var no_back := p.back_pass_barred()
	for a in p.attackers:
		if a == h or a.out:
			continue
		var lead := a.pos + a.vel * 0.3
		if no_back and Play.is_back_pass(h.pos, lead):
			continue   # (the counter: see _best_pass)
		var v := _space(p, a, a.pos) - (1.0 if p.pass_risk(lead, a) != null else 0.0)
		if v > best_v:
			best_v = v
			best = {"throw": {"target": lead, "power": 0.5}, "value": v, "q": 0.0, "to": a, "purpose": "free_throw"}
	return best

## Which way the defence has shifted (metres, + towards higher y): where they are on average.
func _defence_lean(p: Play) -> float:
	var sum := 0.0
	var n := 0
	for d in p.defenders:
		if not d.out:
			sum += d.pos.y - Geo.GOAL_Y
			n += 1
	return sum / maxf(1.0, n)

## What feeding the centre from here is worth (Play.center_entry): from the open side, the most;
## straight down from the point, a little; into the side his guard is on, or with him on his way
## round to this side, nothing.
func _center_feed(p: Play, c: Swimmer) -> float:
	if DefenseFormation.entry_covered(p, c):
		return DROP_FEED   # a man in front of him (or close enough to get there) as well as the one behind
	if p.entry_closing(c):
		return 0.0
	var k := _press_center(p, c)
	match p.center_entry(p.holder.pos, c):
		"open", "":
			return CENTER_FEED * k
		"straight":
			return CENTER_FEED_STRAIGHT * k
	return 0.0

## Against PRESS the centre has only his own man on him: worth more to feed when he's set on his
## spot, stronger than his man, and the passer can put it on him (up to PRESS_CENTER).
func _press_center(p: Play, c: Swimmer) -> float:
	if p.formation != DefenseFormation.F.PRESS or c.pos.distance_to(c.home) > Play.CENTER_SPOT_R \
			or DefenseFormation.passing(p.holder.player) < 5.0:
		return 1.0
	var g := p.on_ball_guard(c)
	var edge := Attributes.strength(c.player) - (Attributes.strength(g.player) if g != null else 5.0)
	return lerpf(1.0, PRESS_CENTER, clampf(edge / 2.0, 0.0, 1.0))

## Has the man with the ball spotted a gap the formation has left right now (a man left open by a
## help or a drop with room, a piston still swimming back, the dropper about to get to the
## centre)? Then he moves it on quickly (MatchFlow: a shorter look). One look a catch, and he
## only sees it Difficulty "exploit_see" of the time (his iq): not every opening, not instantly.
func exploit(p: Play, rng: RandomNumberGenerator) -> bool:
	var h := p.holder
	if h == null or not DefenseFormation.active(p) or not DefenseFormation.drops(p.formation):
		return false
	if h != seen_for:
		seen_for = h
		var gap := h.tag == "C" and DefenseFormation.center_time(p, h) < CENTER_HURRY * 2.0
		var dr := p.f_dropper
		if dr != null and dr.duty == DefenseFormation.Duty.RECOVER:
			gap = true   # the dropper's not back in front of the centre yet
		for a in p.attackers:
			if a != h and DefenseFormation.left_open(p, a) and _space(p, a, a.pos) > LEFT_OPEN_ROOM + 0.5:
				gap = true
		seen = gap and rng.randf() < Difficulty.value("exploit_see", iq)
	return seen

## Metres from the line of a pass to `to` (its middle, where it can be picked off) to the nearest
## defender who could get to it: not one behind the receiver, and on a ball into the centre not
## his guard, nor from the open side the passer's own man (Play._entry_guard).
func _lane_room(p: Play, from: Vector2, to: Vector2, receiver: Swimmer) -> float:
	var a := from.lerp(to, 0.15)
	var b := from.lerp(to, 0.9)
	var entry := p.center_entry(from, receiver)
	var best := INF
	for d in p.defenders:
		if d.out:
			continue
		if entry not in ["", "trailed"] and d.mark != null and (d.mark == receiver or (entry == "open" and d.mark == p.holder)):
			continue
		var c := Geometry2D.get_closest_point_to_segment(d.pos, a, b)
		if receiver.pos.distance_to(c) < d.pos.distance_to(c):
			continue
		best = minf(best, d.pos.distance_to(c))
	return best

## Metres from `s` (if he were at `at`) to the closest defender.
func _space(p: Play, s: Swimmer, at: Vector2) -> float:
	var best := 99.0
	for d in p.defenders:
		if not d.out:
			best = minf(best, d.pos.distance_to(at))
	return best

static func _pair(a: Swimmer, b: Swimmer) -> String:
	var x := str(a.get_instance_id())
	var y := str(b.get_instance_id())
	return x + "|" + y if x < y else y + "|" + x

# ------------------------------------------------------------------ drives
## Open water: he swims the ball into it (PlayAI moves him) and looks again on the way. Either
## straight at the goal, only with his own man not set in front of him (beaten, beside him, or
## sagging off), or, from out wide, across into the slot for a better angle. Either way the swim
## has to be clear of everybody else and a clearly better place to shoot from.
func _start_drive(p: Play, rng: RandomNumberGenerator) -> bool:
	var h := p.holder
	if h.tag == "C" or h.drive_t > 0.0 or p.man_up > 0.0 or p.carry or p.raised:
		return false
	var goal := Geo.goal_center()
	if h.pos.distance_to(goal) < DRIVE_FROM:
		return false
	var guard := p.on_ball_guard(h)
	var beaten := guard == null or guard.pos.distance_to(h.pos) > DRIVE_GUARD_OFF \
		or PlayDefense.side_of(guard, h) != PlayDefense.Zone.FRONT
	var here := spot_quality(h.pos) - repeat_cost(h.pos)   # (a spot the team keeps shooting from: worth swimming off)
	# his own man is off him (splitting, dropped, helping) with room: the water's there to take
	var open := DefenseFormation.left_open(p, h) and _space(p, h, h.pos) > LEFT_OPEN_ROOM
	var clear := DRIVE_CLEAR * (OPEN_DRIVE_CLEAR if open else 1.0)
	var best_to := Vector2.INF
	var best_gain := DRIVE_GAIN
	var options: Array[Vector2] = []
	if beaten:
		options.append(Vector2(Geo.TWO_M + 0.6, lerpf(h.pos.y, Geo.GOAL_Y, 0.5)))
	# into the slot from out wide: his man just goes with him, but the angle opens up
	if absf(h.pos.y - Geo.GOAL_Y) > 2.5:
		options.append(Vector2(clampf(h.pos.x - 0.3, 24.5, 26.5), lerpf(h.pos.y, Geo.GOAL_Y, 0.6)))
	# outside 6 m he can't shoot (Geo.in_shot_range): in to it, straight or slanting off either
	# side of his man into a shooting lane, round him rather than through him
	var out_of_range := not Geo.in_shot_range(h.pos)
	var first_in := options.size()
	if out_of_range:
		for slant in [0.0, -IN_RANGE_SLANT, IN_RANGE_SLANT]:
			options.append(Vector2(Geo.SIX_M + IN_RANGE_DEPTH, lerpf(h.pos.y, Geo.GOAL_Y, 0.3) + slant))
	for i in options.size():
		var aim := options[i]
		var dir := (aim - h.pos).normalized()
		var to := PlayAI.release_to(h, h.pos + dir * minf(DRIVE_LEN, h.pos.distance_to(aim)))
		if to.distance_to(h.pos) < 0.5:
			continue   # already as far off his spot as a drive goes
		var into_range := i >= first_in
		if PlayAI.lane_space(p, h.pos + dir * 0.6, to, null if into_range and not beaten else guard) < clear:
			continue
		var gain := spot_quality(to) - repeat_cost(to) - here
		if out_of_range and Geo.in_shot_range(to):
			gain += IN_RANGE_GAIN
		if gain > best_gain:
			best_gain = gain
			best_to = to
	if best_to == Vector2.INF or (not open and rng.randf() > 0.7):
		return false
	h.drive_t = DRIVE_TIME
	h.drive_goal = best_to
	p.events.append({"k": "drive_ball", "tag": h.tag})
	return true

## How good a place `at` is to shoot from, on range and angle alone (nobody about).
static func spot_quality(at: Vector2) -> float:
	var q := clampf(1.05 - 0.085 * at.distance_to(Geo.goal_center()), 0.0, 0.9)
	var ang := rad_to_deg(atan2(absf(at.y - Geo.GOAL_Y), maxf(Geo.GOAL_X - at.x, 0.2)))
	return q * (1.0 - clampf((ang - 45.0) / 40.0, 0.0, 0.7))

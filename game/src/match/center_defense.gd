class_name CenterDefense
## INSIDE_WATER_DEFENSIVE_RECOVERY: the man with the ball has inside water on his defender (he's
## between him and the goal, his man behind or beside him, with a real chance: Play.close_chance)
## and the defender has to do something about it. Any attacker, any defender: it's where they
## are, not the positions they play (the centre at 2 m is just where it happens most).
##
## Once he's seen it (Difficulty "recognize": a beaten man doesn't know at once), every
## DECIDE_EVERY s he weighs what each answer leaves the attack (expected goals, his read of
## them off by Difficulty "cdef_noise", now and then a plain mistake) and goes with the best:
##   RECOVER    swim round him back to the goal side (his own speed, round him, never through)
##   PRESSURE   on his shoulder: the contact slows the shot (Play.contact_on, Strength on Strength)
##   CHALLENGE  go for the ball, from the side or in front only (from behind he can't reach it
##              legally): it's his STEAL_BASE times the Foul Pressure Modifier (Defense vs Strength),
##              or a foul (an ordinary one: a free throw), or nothing
##   DESPERATE  on his back (only from behind): as he goes up to shoot, pull him (the shot's stopped, illegally). A
##              foul that stops a probable goal (PROBABLE, in the goalie box) is a 5 m penalty;
##              otherwise an ordinary foul (nothing on a shot is ever an exclusion). A strong
##              shooter gets it away anyway
##              (PULL_THROUGH). Worth it only against a goal he can't stop any other way, and his
##              read of what a penalty costs is Difficulty "pen_sense"
##   CONTAIN    stay with him, goal side of his shoulder, and take no risk
## Nothing here is automatic: no steal, no penalty, no recovery is certain, and inside water alone
## never draws a whistle. Attributes are the only ratings it reads; difficulty only the choosing.

enum Act { HOLD = 0, RECOVER, PRESSURE, CHALLENGE, DESPERATE, CONTAIN }
const ACT_NAMES := ["HOLD", "RECOVER", "PRESSURE", "CHALLENGE", "DESPERATE", "CONTAIN"]

const DANGER_MIN := 0.25       # a chance at least this good (Play.close_chance) is worth it
const DETECT_R := 2.6          # his man this close
const DECIDE_EVERY := 0.3
const CONVERT := 0.75          # close_chance -> his read of the chance the shot goes in
## The answers' sums (expected goals for the attack)
const RECOVER_ARC := 0.75      # m round him: the circle he swims on going round
const RECOVER_SWIM := 1.2      # flat out going round (his boost)
const RECOVER_STOP := 0.8      # back goal side in time, he stops this much of it
const SHOT_SOON := Vector2(1.0, 0.35)   # s before the shot: ball down .. ball up
const PRESS_STOP := 0.22
const CONTAIN_STOP := 0.05
const PEN_XG := 0.62           # a 5 m penalty's worth to the attack
const FREE_XG := 0.1           # ...a free throw where he was
## The outcomes (all attributes: Defense, Strength)
const STEAL_BASE := 0.12
const CHALLENGE_REACH := 0.85
const CHALLENGE_COOL := 1.0
const FAIL_FOUL := 0.3         # a challenge that misses is whistled this often (less the better he defends)
const PULL_THROUGH := 0.25     # pulled from behind, the shooter gets it away anyway this often (Strength on Strength)
const PROBABLE := 0.45         # Play.close_chance this good, in the goalie box: a probable goal

## The defender who'd answer for the man with the ball: his marker if he's close enough, or the
## nearest defender; null if nobody is in INSIDE_WATER range of him.
static func responsible(p: Play) -> Swimmer:
	var a := p.holder
	if a == null or a.side != Swimmer.Side.US or p.kind == Play.Kind.PENALTY or p.over or p.breakout:
		return null
	var d := p._marker(a)
	if d == null or d.out or d.pos.distance_to(a.pos) > DETECT_R:
		return null
	return d

## Is `a` (with the ball) inside on `d`: between him and the goal, `d` behind or beside him, close
## enough, with a real chance?
static func inside_water(p: Play, a: Swimmer, d: Swimmer) -> bool:
	if a == null or d == null or d.out or a != p.holder or p.ball.state != Ball.State.HELD:
		return false
	if d.pos.distance_to(a.pos) > DETECT_R:
		return false
	var goal := Geo.goal_center()
	if a.pos.distance_to(goal) >= d.pos.distance_to(goal):
		return false
	if PlayDefense.side_of(d, a) == PlayDefense.Zone.FRONT:
		return false
	return p.close_chance(a) >= DANGER_MIN

## One frame for `d`, the defender answering for the man with the ball (PlayAI._defend). Returns
## what he's doing: -1 nothing to answer (he defends as normal), HOLD (beaten, and he hasn't
## seen it yet), or his answer.
static func think(p: Play, d: Swimmer, dt: float) -> int:
	var a := p.holder
	d.cdef_cool = maxf(0.0, d.cdef_cool - dt)
	if not inside_water(p, a, d):
		d.cdef = -1
		d.cdef_t = 0.0
		d.cdef_next = 0.0
		return -1
	d.cdef_t += dt
	if d.cdef_t < Difficulty.value("recognize", p.level):
		d.cdef = Act.HOLD
		return Act.HOLD
	d.cdef_next -= dt
	if d.cdef <= Act.HOLD or d.cdef_next <= 0.0:
		d.cdef = choose(p, d, a, p.ai_rng)
		d.cdef_next = DECIDE_EVERY
	return d.cdef

## Expected goals for the attack after each answer, as he'd work them out (no dice): {Act: eg}.
## Only the answers open to him (a challenge needs him beside or in front of the ball).
static func values(p: Play, d: Swimmer, a: Swimmer, pen_sense: float = 1.0) -> Dictionary:
	var conv := CONVERT * p.close_chance(a)
	var zone := PlayDefense.side_of(d, a)
	var str_edge := Attributes.strength(d.player) - Attributes.strength(a.player)
	var out := {}
	# RECOVER: round him on RECOVER_ARC, at his own speed, against the time to the shot
	var goal_dir := (Geo.goal_center() - a.pos).normalized()
	var cur := (d.pos - a.pos).normalized() if d.pos.distance_to(a.pos) > 0.05 else -goal_dir
	var arc := absf(cur.angle_to(goal_dir)) * RECOVER_ARC
	var t_rec := arc / (d.top_speed * RECOVER_SWIM) * clampf(1.0 - str_edge * Attributes.SWITCH_PER_POINT, 0.7, 1.3)
	var t_shot := SHOT_SOON.y if p.raised else SHOT_SOON.x
	var p_rec := clampf(1.0 - t_rec / (t_shot + 0.3), 0.0, 1.0)
	out[Act.RECOVER] = conv * (1.0 - RECOVER_STOP * p_rec)
	out[Act.PRESSURE] = conv * (1.0 - PRESS_STOP * clampf(1.0 + str_edge * Attributes.FOUL_PER_POINT, 0.5, 1.5))
	out[Act.CONTAIN] = conv * (1.0 - CONTAIN_STOP)
	if zone != PlayDefense.Zone.BEHIND:
		var ps := steal_chance(p, d, a)
		var pf := fail_foul(p, d, a)
		out[Act.CHALLENGE] = (1.0 - ps) * (pf * FREE_XG + (1.0 - pf) * conv)
	if zone == PlayDefense.Zone.BEHIND:
		var pt := through_chance(d, a)
		var cost := PEN_XG if probable(p, a) or p.penalty_foul(a, d) else FREE_XG
		out[Act.DESPERATE] = pt * conv + (1.0 - pt) * cost * pen_sense
	return out

## His answer: the lowest expected goals as he reads them (Difficulty: cdef_noise, pen_sense,
## mistake).
static func choose(p: Play, d: Swimmer, a: Swimmer, rng: RandomNumberGenerator) -> int:
	var iq := p.level
	var v := values(p, d, a, Difficulty.value("pen_sense", iq))
	var keys := v.keys()
	if rng.randf() < Difficulty.value("mistake", iq):
		return int(keys[rng.randi() % keys.size()])
	var noise := Difficulty.value("cdef_noise", iq)
	var best := Act.CONTAIN
	var best_v := INF
	for k in keys:
		var x := float(v[k]) + rng.randfn(0.0, noise)
		if x < best_v:
			best_v = x
			best = int(k)
	return best

## Where he swims for answer `act` (and how hard: d.boost). Only where he aims: his speed is his own.
static func spot(p: Play, d: Swimmer, act: int) -> Vector2:
	var a := p.holder
	var goal_dir := (Geo.goal_center() - a.pos).normalized()
	var side := signf((d.pos - a.pos).dot(goal_dir.orthogonal()))
	if side == 0.0:
		side = 1.0
	var perp := goal_dir.orthogonal() * side
	d.boost = 1.0
	match act:
		Act.HOLD:
			return d.pos   # beaten, and he hasn't seen it yet
		Act.RECOVER:
			d.boost = RECOVER_SWIM
			return PlayAI._round_to(a, d, goal_dir, RECOVER_ARC, PlayAI.CENTER_SPIN_LEAD)
		Act.PRESSURE:
			d.boost = 1.1
			return a.pos + perp * 0.5 + goal_dir * 0.1
		Act.CHALLENGE:
			d.boost = 1.15
			return p.ball.pos + perp * 0.3
		Act.DESPERATE:
			d.boost = 1.1
			return a.pos - goal_dir * 0.45
	return a.pos + perp * 0.6 + goal_dir * 0.35   # CONTAIN

# ------------------------------------------------------------------ what happens
## A legal challenge for the ball: STEAL_BASE, his effective Defense against the man's Strength
## (the Foul Pressure Modifier, Attributes.foul_mult).
static func steal_chance(p: Play, d: Swimmer, a: Swimmer) -> float:
	return STEAL_BASE * Attributes.foul_mult(Attributes.eff_defense(d.player, p.comm()), a.player)

## ...and one that misses, whistled: less often the better he defends.
static func fail_foul(p: Play, d: Swimmer, a: Swimmer) -> float:
	return clampf(FAIL_FOUL / Attributes.foul_mult(Attributes.eff_defense(d.player, p.comm()), a.player), 0.0, 1.0)

## Pulled from behind, he gets it away anyway: his Strength over the puller's.
static func through_chance(d: Swimmer, a: Swimmer) -> float:
	return PULL_THROUGH * clampf(1.0 + (Attributes.strength(a.player) - Attributes.strength(d.player)) * Attributes.FOUL_PER_POINT, 0.5, 1.5)

## A probable goal: a chance this good, in the goalie box.
static func probable(p: Play, a: Swimmer) -> bool:
	return Play.in_goalie_box(a.pos) and p.close_chance(a) >= PROBABLE

## Every frame (Play.step): a defender on a CHALLENGE within reach of the ball, beside or in
## front of the man, goes for it once (then CHALLENGE_COOL before the next).
static func challenges(p: Play) -> void:
	var a := p.holder
	if a == null or p.ball.state != Ball.State.HELD or p.freeze > 0.0 or p.over or p.restart:
		return   # (a free throw being taken is protected: Play.restart)
	for d in p.defenders:
		if d.out or d.cdef != Act.CHALLENGE or d.cdef_cool > 0.0:
			continue
		if d.pos.distance_to(a.pos) > CHALLENGE_REACH or PlayDefense.side_of(d, a) == PlayDefense.Zone.BEHIND:
			continue
		d.cdef_cool = CHALLENGE_COOL
		var r := p.rng.randf()
		var ps := steal_chance(p, d, a)
		if r < ps:
			p.events.append({"k": "challenge", "won": true})
			p._turnover(d, "STOLEN!", "steal")
			return
		if r < ps + (1.0 - ps) * fail_foul(p, d, a):
			p.events.append({"k": "challenge", "won": false})
			p._ordinary_foul(a, d)
			return

## The shooter `s` going up (Play._shoot): a defender on DESPERATE, on his back within Play.FOUL_REACH,
## pulls him. Returns true if the whistle went (the shot's off): a penalty for a probable goal,
## otherwise an ordinary foul. False: nobody pulled, or he got it away anyway.
static func foul_on_shot(p: Play, s: Swimmer) -> bool:
	if p.kind == Play.Kind.PENALTY or p.restart:
		return false
	for d in p.defenders:
		if d.out or d.cdef != Act.DESPERATE or d.pos.distance_to(s.pos) > Play.FOUL_REACH:
			continue
		if PlayDefense.side_of(d, s) != PlayDefense.Zone.BEHIND:
			continue   # (a pull back is from behind him)
		d.cdef = Act.HOLD
		if p.rng.randf() < through_chance(d, s):
			p.events.append({"k": "pulled", "through": true})
			return false
		p.events.append({"k": "pulled", "through": false})
		if probable(p, s):
			p._penalty(s, d)
		else:
			p._ordinary_foul(s, d)   # (from behind on a clear chance, a penalty all the same: Play.penalty_foul)
		return true
	return false

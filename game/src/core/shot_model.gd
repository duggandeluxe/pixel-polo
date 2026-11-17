class_name ShotModel
## Decides a shot the moment it leaves the hand; the match screen then animates that
## outcome. Deterministic for a given RNG, so it can be tuned with Monte Carlo tests.
##
## The ball flies in a straight line at a fixed speed, so its whole path is known at the
## release: the defenders it passes get their chance in the order it reaches them, then the
## keeper gets his. The first one to get a hand to it decides it. Wherever it stops (a block,
## the keeper's hands, the back of the net, wide) is on that same line: on_line().
##
## The keeper never knows where it's going before it goes. Before the release he reads the
## shooter and may set off early (KeeperAI.anticipation: likelier and earlier the longer it's been
## held); after it he sees its line (KeeperAI.recognize_time) and goes for it (react_side), or, if
## he'd already gone the wrong way, corrects (a lean) or panics (KeeperDive.turn: a limited claw
## back, never across the goal from a full commitment). Three separate questions: which way
## (the decision), can his dive get there (his body: KeeperDive, his attributes), and does it stay
## out once it's in his hands (BLOCKING). A save is a ball inside his reach as it passes him
## (_contact: the ball's path through his depth, not one point, so no pace slips through him).
##
## A shot you aim yourself (ctx.exact) goes exactly where you aimed: no spread, nothing pulls it
## towards the goal. Your aim is the accuracy; ratings still set its pace and the keeper's read.
## The AI's shots keep their spread.
##
## The pool is 2D, so the goal face is too: `reach` folds in the height of the shot, rolled at
## the release (`height`, 0 at the water .. 1 under the bar: shot_height). A low one, down where
## his hands have furthest to go, is a little harder to stop; a high one a little easier.
##
## What decides a shot, roughly in order: where he aims and which way the keeper went, the
## range (less time for him to get there) and the angle, a catch and shoot (the keeper still
## moving), cross-cage (the keeper diving across), and the pressure on the shooter.

const POST_BAND := 0.08       # this far outside the post counts as hitting it
## Field blocks. Any defender in the ball's path can get a hand to it: how far he reaches
## depends on how long he has to see it coming (reaction from `defense`), his arm (`defense`
## and `strength`) and how far he can throw himself at it in the time left (`speed`).
## The shooter's own guard (`on_ball`) is the exception: until he's pressed him long enough
## (`ready`, see Play.GUARD_TIME) he gets no hand to it at all, whatever his ratings.
const BLOCK_MIN_ALONG := 0.35 # nobody blocks it straight out of his hand
const BLOCK_GOAL_GAP := 1.0   # the last metre in front of the line is the keeper's
const BODY_R := 0.22          # head and shoulders: the ball hits these with no reaction at all
const SET_R := 1.4            # his guard, ready and this close: his hand is already up
const MAX_LUNGE := 0.45       # the most a defender adds by throwing himself at it
const ATTEMPT_SLACK := 0.4    # he goes for one he can't quite reach (and misses)
const OFF_BALL_HANDS := 0.85  # a defender off the ball gets less of a hand to what he reaches...
const BODY_ONLY := 0.55       # ...and a ball he never reacted to only sticks if it hits him square
const MAX_TRIES := 2          # a crowd is a couple of chances, not a wall: the first two it reaches
## The home team's keeper dives this much faster, in both his own goal and on screen (KeeperDuel
## uses it too). Only his push off and rise: not his reaction, his read or his reach.
const HOME_DIVE := 1.3
const HEIGHT_REACH := Vector2(0.8, 1.2)   # (the old straight line, bottom .. top; height_reach replaced it)
## How high the ball is changes his reach (height_reach): down at the water his hands have furthest
## to go (HEIGHT_LOW), around his shoulders they're there (HEIGHT_BEST at HEIGHT_PEAK), and up under
## the bar it's his legs: how high he gets out of the water (HEIGHT_TOP, worst .. best Leg Strength).
const HEIGHT_LOW := 0.85
const HEIGHT_BEST := 1.12
const HEIGHT_PEAK := 0.6
const HEIGHT_TOP := Vector2(0.7, 1.1)
## His depth: the ball is his anywhere along its path within this of his line (_contact).
const KEEPER_DEPTH := 0.05
const CONTACT_STEPS := 6
## Tuning (see the README's balancing notes). Shooting is accurate: the aim, the keeper's
## position, range and angle decide most shots, not the wrist.
const ACCURACY := 0.9         # every shot's spread is scaled by this
## Catch and shoot: let it go within CATCH_SHOOT_WINDOW s of catching a pass and the keeper is
## still moving with the pass: a tidier release, a later reaction, a shorter dive. The bonus
## fades to nothing over the next CATCH_SHOOT_FADE s (gone 1 s after the catch). The gold glow
## on the catcher (PoolArt.draw_catch_glow) is this same number, so what you see is the bonus.
const CATCH_SHOOT_WINDOW := 0.5
const CATCH_SHOOT_FADE := 0.5
const CATCH_SHOOT_AIM := 0.85      # spread at the full bonus
const CATCH_SHOOT_REACT := 0.04    # keeper's reaction, later by this
const CATCH_SHOOT_REACH := 0.07    # keeper's reach, shorter by this fraction
## Cross-cage: from off to one side, aimed at the far post. The keeper shades to the near post,
## so he has the whole goal to cross, diving across his body. Best from a decent angle (it fades
## out for a shot from straight on and from a very sharp angle) and with him on the near post.
const CROSS_REACT := 0.05
const CROSS_REACH := 0.15
const CROSS_ANGLE := Vector3(10.0, 35.0, 62.0)   # degrees off the goal's axis: from, full, fading by +20
## Contact on the shooter (ctx.contact, 0..1: Play.contact_on, a defender on him and the two
## men's Strength): he gets less behind it, so it's slower and the keeper has longer. Pressure,
## not a different aim: your shot still goes where you put it.
const CONTACT_SLOW := 0.15

## A defender for resolve(): where he is and the ratings that make a blocker (defence and
## strength as his form has them today: PoloPlayer.live). `i` is handed back in the result
## (`blocker`, `attempts`) so the caller can animate the right man.
## `on_ball`: he's guarding the shooter; `ready`: and has pressed him long enough to block.
static func blocker(pos: Vector2, p: PoloPlayer, i: int = -1, on_ball: bool = false, ready: bool = false) -> Dictionary:
	return {"pos": pos, "defense": p.live("defense"), "strength": p.live("strength"), "speed": p.speed, "i": i,
		"on_ball": on_ball, "ready": ready}

## The shooter's guard, ready to block: only he can have his hand up before the shot.
static func _set_guard(b) -> bool:
	return b is Dictionary and bool(b.get("on_ball", false)) and bool(b.get("ready", false))

## The shooter's guard who hasn't pressed him long enough: no block, no attempt.
static func _unready_guard(b) -> bool:
	return b is Dictionary and bool(b.get("on_ball", false)) and not bool(b.get("ready", false))

## How far blocker `b` reaches across the line of a shot from `from`, for a ball that gets to
## him `along` metres down its path at `speed` m/s: {reach, react, arrive, set}. `late`: how much
## later than usual he sees it go (the shooter's release: Attributes.release_read).
static func block_reach(b, from: Vector2, along: float, speed: float, late: float = 0.0) -> Dictionary:
	var pos: Vector2 = b if b is Vector2 else b.pos
	var dfn := 0.5
	var stren := 0.5
	var spd := 0.5
	if b is Dictionary:
		dfn = clampf(float(b.get("defense", 50)) / 100.0, 0.0, 1.0)
		stren = clampf(float(b.get("strength", 50)) / 100.0, 0.0, 1.0)
		spd = clampf(float(b.get("speed", 50)) / 100.0, 0.0, 1.0)
	var react := maxf(0.05, lerpf(0.30, 0.12, dfn) + late)
	var arrive := along / speed
	var is_set := _set_guard(b) and pos.distance_to(from) < SET_R
	var reach := BODY_R
	if is_set or arrive >= react:
		reach += lerpf(0.36, 0.52, 0.6 * dfn + 0.4 * stren)
	reach += clampf((arrive - react) * lerpf(1.3, 2.3, spd), 0.0, MAX_LUNGE)
	return {"reach": reach, "react": react, "arrive": arrive, "set": is_set, "dfn": dfn}

## The shot's pace, m/s, fixed at the release: the pull (`power`), the shooter's own pace rating
## (`pace`: Attributes.shot_pace, his SHOOTING; Tempo), his trait (`mods`) and any contact on him (0..1).
## The shooter's share of a shot's spread (his wrist error), from his shooting rating `skill`
## (0-100) read up to `top` (100; a DEV Recruit's Attributes.rating_top): 1.35 at 0 .. 0.75 at 100,
## on at the same slope past it (0.63 at 120). Always above zero: never a shot that can't miss.
static func skill_spread(skill: float, top: float = 100.0) -> float:
	return lerpf(1.35, 0.75, clampf(skill / 100.0, 0.0, top / 100.0))

static func shot_speed(power: float, pace: float, mods: Dictionary = {}, contact: float = 0.0, top: float = 100.0) -> float:
	var speed := lerpf(9.0, 17.0, clampf(power, 0.2, 1.0)) * Tempo.shooter_shot(pace, top) * float(mods.get("speed", 1.0))
	speed = Tempo.soft_shot(speed)
	return speed * (1.0 - CONTACT_SLOW * clampf(contact, 0.0, 1.0))

## A raised arm (DefenseFormation.arm_zone: {i, hand, r, ready}) against a ball from `from` along
## `dir` (to where it crosses the line) at `speed`: {along, at, arrive} where it meets the hand, or
## {} if it doesn't: past the hand, or there before the arm's fully up (`ready` s), or out of a
## blocker's part of the path (BLOCK_MIN_ALONG .. the keeper's last BLOCK_GOAL_GAP). No dice: a
## ball through a fully raised arm is blocked, every time. The aim guide's red X is this too.
static func arm_contact(from: Vector2, dir: Vector2, speed: float, arm: Dictionary) -> Dictionary:
	var span := dir.length()
	if arm.is_empty() or span < 0.01 or speed <= 0.0:
		return {}
	var hand: Vector2 = arm.hand
	var r := float(arm.r)
	var u := dir / span
	var mid := (hand - from).dot(u)
	var perp := absf((hand - from).cross(u))
	if perp > r:
		return {}
	var along := maxf(0.0, mid - sqrt(r * r - perp * perp))   # where it first touches the hand
	if along < BLOCK_MIN_ALONG or along > span - BLOCK_GOAL_GAP:
		return {}
	var arrive := along / speed
	if arrive < float(arm.get("ready", 0.0)):
		return {}   # past him before the arm's up
	return {"along": along, "at": from + u * along, "arrive": arrive}

## from: shooter position; aim_y: where on the goal line he aims; power 0..1 (drag
## length); pressure_d: metres to the nearest defender; blockers: field defenders, either
## blocker() dictionaries or bare positions (average ratings).
## `mods`: the shooter's trait (Traits.shot_mods): speed, spread and full_spread multipliers.
## `ctx`: how the shot came about. catch_t: seconds since he caught a pass (absent: he didn't);
## home_keeper: the keeper is the home team's (he dives HOME_DIVE times faster); exact: a shot you
## aimed yourself (no spread); contact (CONTACT_SLOW). The keeper (KeeperAI): iq, his decision
## level (Difficulty, 0..1: never his body); memory (KeeperAI.read); close (Play.close_chance);
## dive_side, a dive forced on him (tests); hold, how long the shooter's had it in range
## (Play.hold_t: his anticipation); read_side and lean_y, the read Play made and where he set
## before he leaned on it; commit / lead / commit_go / height (tests only: his anticipation and the
## shot's height set); busy, the dive he's still in from the last shot
## ({side, t, base_y}: no new one until it's over); wall, a WALL's reach; window, his LEG
## STRENGTH's hang time (Attributes.dive_window). The result's `guess` is the way he went (-1
## LEFT, up the screen; 0 UP; +1 RIGHT), `read` the weights he picked it from, `dive` his dive's
## body and `keeper_go` when he set off (s after the release), so the screen draws that very dive.
## Attributes (all neutral when absent): pass_mod, the passer's catch-and-shoot edge (applied in
## proportion to the catch-and-shoot bonus: the keeper's reach and the spread); release, how much
## later the shooter's release lets everyone react (s); the keeper's lunge (his dive's share of the
## normal time: reaction and swim), leg (his reach's share) and block (his hold on a ball he gets to).
static func resolve(from: Vector2, aim_y: float, power: float, skill: float, pressure_d: float,
		blockers: Array, keeper_y: float, keeper_skill: float,
		rng: RandomNumberGenerator, penalty: bool = false, mods: Dictionary = {}, ctx: Dictionary = {}) -> Dictionary:
	# (the shooter's rating read up to ctx.skill_top: 100, or a DEV Recruit's Attributes.rating_top)
	var top := float(ctx.get("skill_top", 100.0))
	var k := clampf(keeper_skill / 100.0, 0.0, 1.0)
	power = clampf(power, 0.2, 1.0)
	# the keeper picks his way first, from what he can see: before a single die that depends on the aim
	var pick := keeper_pick(from, keeper_y, pressure_d, penalty, ctx, rng)
	var cs := 0.0 if penalty else catch_shoot(float(ctx.get("catch_t", INF)), float(ctx.get("cs_k", 1.0)))
	var exact := bool(ctx.get("exact", false))
	var cross := 0.0 if penalty else cross_cage(from, aim_y, keeper_y)
	var aim := Vector2(Geo.GOAL_X, aim_y)
	var dist := maxf(from.distance_to(aim), 0.5)
	# its pace, fixed here at the release: the pull and the shooter's own SHOOTING (ctx.pace:
	# Attributes.shot_pace; never his team's overall or form). Wherever it ends up (in,
	# saved, blocked, wide) it flies there at this speed: flight = distance / speed.
	var speed := shot_speed(power, float(ctx.get("pace", skill)), mods, float(ctx.get("contact", 0.0)), top)
	# the CPU's shot at your goal: its difficulty's pace on top of everything above (Difficulty.cpu_shot_speed)
	speed *= float(ctx.get("speed_k", 1.0))
	var sigma := (0.05 + 0.04 * dist) * skill_spread(skill, top) * float(mods.get("spread", 1.0)) * ACCURACY
	sigma *= lerpf(1.0, CATCH_SHOOT_AIM, cs)
	# the pass that set it up: a good passer's ball arrives ready to shoot (PASSING)
	var pass_edge := float(ctx.get("pass_mod", 0.0)) * cs
	sigma *= 1.0 - pass_edge
	# from a sharp angle the goal mouth looks narrow: the same wrist error lands wider
	var to_aim := (aim - from).normalized()
	sigma /= maxf(absf(to_aim.x), 0.35)
	if penalty:
		sigma *= 0.8
	if pressure_d < 1.3:
		sigma *= lerpf(2.3, 1.2, clampf(pressure_d / 1.3, 0.0, 1.0))
	if power > 0.85:
		sigma *= 1.0 + (power - 0.85) * 3.0 * float(mods.get("full_spread", 1.0))
	else:
		# a controlled pull is a tidy release; only a full pull costs accuracy
		sigma *= lerpf(0.75, 1.0, power / 0.85)
	var cross_y := aim_y if exact else aim_y + rng.randfn(0.0, sigma)
	var target := Vector2(Geo.GOAL_X, cross_y)
	var dir := target - from
	var res := {"outcome": "goal", "cross_y": cross_y, "speed": speed, "reaction": 99.0,
		"keeper_end_y": keeper_y, "keeper_speed": 0.0, "end": target, "flight": dir.length() / speed,
		"exact": exact,
		"attempts": [], "blocker": -1, "deflect": Vector2.ZERO,
		"catch_shoot": cs, "cross": cross, "power_shot": false, "pass_edge": pass_edge}
	var late := float(ctx.get("release", 0.0))

	# 1) the field defenders, in the order the ball gets to them (a raised arm in its way first, if
	# that's where it gets to first: ctx.arms)
	if _blocks(res, from, dir, speed, blockers, rng, late, ctx.get("arms", [])):
		return res

	# 2) the keeper (KeeperAI): his body is KeeperDive.body (LEG STRENGTH his reach and push, LUNGE
	# SPEED his push off, rise and how soon he sees it, HOME_DIVE); his height against this ball is
	# his legs' too (height_reach). Then the two stages: what he did before he saw it, what he does
	# once he has.
	var k_lunge := float(ctx.get("lunge_k", k))
	var k_leg := float(ctx.get("leg_k", k))
	var lunge := float(ctx.get("lunge", 1.0))
	var body := KeeperDive.body(k_leg, float(ctx.get("leg", 1.0)), lunge,
		float(ctx.get("window", Attributes.WINDOW_AT_5)), bool(ctx.get("wall", false)), bool(ctx.get("home_keeper", false)))
	if not ctx.has("dive_side"):
		body["rise"] = KeeperAI.RISE   # (a drill's forced dive keeps the dive its lesson was made with)
	body["quick"] = float(body.quick) * float(ctx.get("gk_dive", 1.0))   # (the CPU keeper's difficulty: HARD dives quicker)
	var height := shot_height(rng)
	if ctx.has("height"):
		height = float(ctx.height)   # (tests: the same die, a set height)
	res["height"] = height
	# his reach against this ball: its height, and what the play took off him (the catch and shoot, the
	# dive across his body, the pass that set it up: PASSING)
	var reach_k := height_reach(height, k_leg, float(ctx.get("strain", 0.0))) * (1.0 - CATCH_SHOOT_REACH * cs) * (1.0 - CROSS_REACH * cross) * (1.0 - pass_edge)
	var hidden := late + CATCH_SHOOT_REACT * cs + CROSS_REACT * cross   # what hid the release from him
	# (the CPU keeper's difficulty: his own delays, quicker or slower; never what the release hid)
	var gk_k := float(ctx.get("gk_k", 1.0))
	var react := lerpf(KeeperAI.GO_REACT.x, KeeperAI.GO_REACT.y, k_lunge) * lunge * gk_k + hidden   # off the arm
	var recog := KeeperAI.recognize_time(k_lunge, lunge) * gk_k + hidden                            # off the ball
	var hands := on_line(from, cross_y, Geo.KEEPER_X)
	var to_hands := from.distance_to(hands) / speed
	var err := rng.randfn(0.0, KeeperAI.TIMING_ERR)
	recog *= clampf(1.0 + rng.randfn(0.0, KeeperAI.RECOGNIZE_SD), 0.5, 1.6)   # (some he picks up quicker than others: never which way)
	var est_read := from.distance_to(Vector2(Geo.KEEPER_X, keeper_y)) / KeeperAI.READ_SPEED * (1.0 + err)   # the pace he expects
	var est := to_hands * (1.0 + err)                                                                    # the ball he's seen
	var lead := clampf(float(ctx.get("seen", KeeperAI.LEAD)), KeeperAI.SEEN_MIN, KeeperAI.LEAD)
	var dive: KeeperDive = null
	var go := 0.0
	var free_at := 0.0           # when he can push off again (s after the release)
	var kind := "react"          # what he did: react | anticipated | correction | panic | stranded | forced | busy
	var commit := KeeperDive.Commit.NONE
	var busy: Dictionary = ctx.get("busy", {})
	if not busy.is_empty():
		# still in his last dive (a rebound): that's the dive this one has to beat if it gets to him
		# before he's recovered; a new one only once it's over
		var old := KeeperDive.from_body(body, int(busy.side), float(busy.base_y), reach_k)
		free_at = old.down_at() + KeeperDive.RECOVERY - float(busy.t)
		if to_hands < free_at:
			dive = old
			dive.anticipated = true
			go = -float(busy.t)
			kind = "busy"
	var forced := ctx.has("dive_side")
	if dive == null and forced:
		# a dive forced on him (a drill, the tests): that way, timed for the pace he expects, no reading the ball
		dive = KeeperDive.from_body(body, int(pick.side), keeper_y, reach_k)
		go = maxf(maxf(react - lead, free_at), est_read - dive.extend_time() - dive.window * KeeperAI.INTO)
		kind = "forced"
	# Stage A: he went before he'd seen it (anticipation), timed for the pace he expects. Only if he'd
	# really set off by the time he sees the ball: otherwise it was a read and a lean, nothing more.
	if dive == null and bool(pick.ant.commit):
		var a := KeeperDive.from_body(body, int(pick.side), keeper_y, reach_k)
		var a_go := maxf(maxf(-float(pick.ant.lead), free_at), est_read - a.extend_time() - a.window * KeeperAI.INTO)
		if ctx.has("commit_go"):
			a_go = float(ctx.commit_go)   # (tests: exactly when he set off)
		if a_go < recog:
			dive = a
			dive.anticipated = true
			go = a_go
			kind = "anticipated"
	# Stage B: he sees it. Not gone yet: he goes for it. Gone already: right, he carries on; wrong,
	# he corrects (a lean) or panics (a real commitment).
	var redive: KeeperDive = null
	var redive_go := INF
	if dive == null:
		var lean_y := float(ctx.get("lean_y", keeper_y))   # the way he'd shaded, read before the shot
		var fix := KeeperAI.LEAN_FIX * clampf(absf(keeper_y - lean_y) / KeeperAI.LEAN_MAX, 0.0, 1.0) \
			if signf(hands.y - lean_y) != signf(keeper_y - lean_y) else 0.0
		# as soon as he's seen it, or later if there's time: timed for the ball he saw to get to him INTO his window
		var g0 := maxf(recog + fix, free_at)
		go = maxf(g0, est - KeeperDive.from_body(body, KeeperDive.CENTRE, keeper_y).extend_time() - float(body.window) * KeeperAI.INTO)
		dive = KeeperAI.reaction_dive(body, keeper_y, hands.y, go, est, reach_k)
	elif kind in ["anticipated", "busy"]:
		var at_rec := recog - go               # his clock when he sees it
		var keep := dive.duplicate_at(est - go).covers(hands.y) >= 0.0 \
			or (dive.side != KeeperDive.CENTRE and KeeperAI.zone_of(hands.y, dive.base_y) == dive.side)
		commit = dive.commitment_at(at_rec)
		var ph := dive.duplicate_at(at_rec).phase()
		if not keep and ph in [KeeperDive.Phase.REACT, KeeperDive.Phase.RISE, KeeperDive.Phase.ACTIVE]:
			if commit <= KeeperDive.Commit.MINIMAL:
				# barely started: a quick correction, a new dive from where he's got to
				var at_y := dive.duplicate_at(at_rec).body_y()
				var g2 := maxf(recog + KeeperAI.MINOR_FIX, est - dive.extend_time() - dive.window * KeeperAI.INTO)
				redive = KeeperAI.reaction_dive(body, at_y, hands.y, g2, est, reach_k)
				redive_go = g2
				kind = "correction"
			else:
				dive.turn(at_rec, hands.y)
				kind = "panic"
		elif not keep:
			kind = "stranded"   # the wrong way, and already falling back in: nothing left to turn
	res["guess"] = (redive if redive != null else dive).side
	res["read_side"] = int(pick.side)   # the way his read said, whether he went on it or not
	res["anticipated"] = int(pick.side) if kind in ["anticipated", "correction", "panic", "stranded"] else KeeperAI.NO_READ
	res["read"] = pick.read
	res["gk"] = {"kind": kind, "commit": commit, "hold": float(ctx.get("hold", 0.0)), "recognize": recog}
	res["dive"] = dive.to_dict()
	if redive != null:
		res["redive"] = redive.to_dict()
		res["redive_go"] = redive_go
	res.reaction = recog         # when he saw where it was going (LUNGE SPEED's, and what hid the shot)...
	res.keeper_go = go           # ...and when he set off (Play draws this dive from here)
	res.keeper_speed = 0.0
	var last := redive if redive != null else dive
	res["right_way"] = last.covers_at_full(cross_y)   # would the dive he ended up in have had it at full stretch
	var end_d := _dive_at(dive, go, redive, redive_go, to_hands)
	res.keeper_end_y = end_d.body_y() if end_d.t >= 0.0 else keeper_y

	# 3) on target?
	var off := absf(cross_y - Geo.GOAL_Y) - Geo.GOAL_HALF
	if off > POST_BAND:
		res.outcome = "miss"
		res.end = past_line(from, cross_y, 1.3)
		res.flight = from.distance_to(res.end) / speed
		return res
	if off > -0.04:
		res.outcome = "post"
		res.end = target
		res.flight = from.distance_to(res.end) / speed
		return res

	# 4) the save: is the ball in his hands as it goes past him (_contact)? Not gone yet (or back
	# down in the water): only a ball at his body (KeeperDuel.BODY_R). Diving: inside the reach of
	# that dive, that side; the far side of a dive is only his trailing body; a panic only what it
	# claws back (never past its wall).
	var c := _contact(from, cross_y, speed, dive, go, redive, redive_go, keeper_y)
	var at := float(c.at)
	if at >= 0.0:
		hands = c.point
		to_hands = float(c.t)
	res["dive_phase"] = int(c.phase)
	# BLOCKING: a ball he gets to is kept out Attributes.hold_chance of the time (a fingertip one
	# less often); one that beats his hands goes on in. Out of his reach, nothing helps.
	var held := at >= 0.0 and rng.randf() < Attributes.hold_chance(at, float(ctx.get("block", 0.0)))
	res["touched"] = at >= 0.0 and not held
	if held:
		res.outcome = "parry" if rng.randf() < 0.28 else "save"
		# it's in his hands in front of the line, at the shot's own speed like every other ending
		res.end = hands
		res.flight = to_hands
		return res
	res.end = past_line(from, cross_y, 0.6)
	res.flight = from.distance_to(res.end) / speed
	return res

## The way the keeper goes for a shot from `from` (KeeperAI): {side, read, ant}. Only what he can
## see before the release goes into it: the read, and whether he sets off on it before the ball's
## away (KeeperAI.anticipation, from ctx.hold); ctx.read_side is the read Play already made (his
## lean), ctx.dive_side forces one (tests).
static func keeper_pick(from: Vector2, keeper_y: float, pressure_d: float, penalty: bool, ctx: Dictionary,
		rng: RandomNumberGenerator) -> Dictionary:
	var iq := float(ctx.get("iq", Difficulty.BASELINE))
	var info := {"from": from, "keeper_y": keeper_y, "pressure": pressure_d, "penalty": penalty,
		"close": float(ctx.get("close", close_range(from))), "memory": ctx.get("memory", Vector3.ZERO)}
	var w := KeeperAI.read(info, iq)
	var side := KeeperAI.choose(w, iq, rng)
	var ant := KeeperAI.anticipation(float(ctx.get("hold", 0.0)), rng.randf(), from.distance_to(Geo.goal_center()))
	if penalty:
		ant = {"commit": true, "lead": KeeperAI.COMMIT_LEAD.y, "k": 1.0}   # (from 5 m nobody reads it in time: every keeper guesses)
	if ctx.has("commit"):
		ant.commit = bool(ctx.commit)   # (tests: he goes early, or doesn't)
		ant.lead = float(ctx.get("lead", KeeperAI.COMMIT_LEAD.y))
	if int(ctx.get("read_side", KeeperAI.NO_READ)) != KeeperAI.NO_READ:
		side = int(ctx.read_side)   # (the read Play showed you, his lean: the same dice were rolled)
	if ctx.has("dive_side"):
		side = int(ctx.dive_side)
	return {"side": side, "read": w, "ant": ant}

## How close in a shot from `from` is, 0 (6 m and out) .. 1 (inside 2.5 m), on range alone: the
## keeper's read when nobody's told him more (Play.close_chance does, with the defenders).
static func close_range(from: Vector2) -> float:
	return clampf((5.5 - from.distance_to(Geo.goal_center())) / 3.0, 0.0, 1.0)

## How high a shot crosses the line, 0 at the water .. 1 under the bar: wherever the wrist puts it.
static func shot_height(rng: RandomNumberGenerator) -> float:
	return rng.randf()

## The keeper's reach for a shot crossing at `height` (0 the water .. 1 under the bar), as a share
## of his reach: low ones are a stretch down, shoulder height is easiest, and the top corner is as
## good as his legs (`leg_k`, his LEG STRENGTH skill) get him up out of the water.
static func height_reach(height: float, leg_k: float = 0.5, strain_loss: float = 0.0) -> float:
	if height <= HEIGHT_PEAK:
		return lerpf(HEIGHT_LOW, HEIGHT_BEST, height / HEIGHT_PEAK)
	return lerpf(HEIGHT_BEST, lerpf(HEIGHT_TOP.x, HEIGHT_TOP.y, clampf(leg_k, 0.0, 1.0)), (height - HEIGHT_PEAK) / (1.0 - HEIGHT_PEAK)) \
		* legs_mult(height, strain_loss)

## Tired legs in a drop (KeeperLegs.loss, `strain_loss`): his reach for a ball at `height` as a
## share of his fresh reach. Nothing up to shoulder height (HEIGHT_PEAK), the whole loss at the
## top of the goal, in a straight line between. Your keeper's dive (KeeperDuel.height_k) and the
## computer's use this same line.
static func legs_mult(height: float, strain_loss: float) -> float:
	return 1.0 - clampf(strain_loss, 0.0, 1.0) * clampf((height - HEIGHT_PEAK) / (1.0 - HEIGHT_PEAK), 0.0, 1.0)

## The dive he's in `secs` after the release: the first one (from `go`) until a correction takes
## over (from `redive_go`), its clock set to then.
static func _dive_at(dive: KeeperDive, go: float, redive: KeeperDive, redive_go: float, secs: float) -> KeeperDive:
	if redive != null and secs >= redive_go:
		return redive.duplicate_at(secs - redive_go)
	return dive.duplicate_at(secs - go)

## Does the ball get into his hands? It's checked all along its path through his depth (Geo.KEEPER_X
## +- KEEPER_DEPTH, CONTACT_STEPS points, wherever the ball is and wherever his dive has him at each
## of those moments), so however fast it's going it can't skip past him between two looks. The first
## touch wins: {at (-1 none, else 0 body .. 1 fingertips), point, t (s after the release), phase}.
## Not diving (yet, or any more): only a ball into his body (KeeperDuel.BODY_R).
static func _contact(from: Vector2, cross_y: float, speed: float, dive: KeeperDive, go: float,
		redive: KeeperDive, redive_go: float, keeper_y: float) -> Dictionary:
	var x0 := maxf(Geo.KEEPER_X - KEEPER_DEPTH, from.x + 0.1)
	var x1 := minf(Geo.KEEPER_X + KEEPER_DEPTH, Geo.GOAL_X - 0.01)
	var mid := on_line(from, cross_y, Geo.KEEPER_X)
	var mid_t := from.distance_to(mid) / speed
	var out := {"at": -1.0, "point": mid, "t": mid_t, "phase": _dive_at(dive, go, redive, redive_go, mid_t).phase()}
	if x1 <= x0:
		x0 = Geo.KEEPER_X
		x1 = Geo.KEEPER_X
	for i in CONTACT_STEPS + 1:
		var q := on_line(from, cross_y, lerpf(x0, x1, i / float(CONTACT_STEPS)))
		var tq := from.distance_to(q) / speed
		var d := _dive_at(dive, go, redive, redive_go, tq)
		var ph := d.phase() if d.t >= 0.0 else KeeperDive.Phase.READY
		var at := -1.0
		if ph in [KeeperDive.Phase.REACT, KeeperDive.Phase.RECOVER, KeeperDive.Phase.READY]:
			var by := d.body_y() if d.t >= 0.0 else keeper_y
			if absf(q.y - by) <= KeeperDuel.BODY_R:
				at = 0.0
		else:
			at = d.covers(q.y)
		if at >= 0.0:
			return {"at": at, "point": q, "t": tq, "phase": ph}
	return out

## The point at `x` (short of the goal line) on the line from `from` through the goal line at
## `cross_y`: where a shot along that line is when it gets that far down the pool. From right on
## the goal line (no room for a line) it's straight across at cross_y.
static func on_line(from: Vector2, cross_y: float, x: float) -> Vector2:
	var run := Geo.GOAL_X - from.x
	if run < 0.3:
		return Vector2(x, cross_y)
	x = maxf(x, from.x + 0.1)   # (never behind him)
	return Vector2(x, from.y + (cross_y - from.y) * (x - from.x) / run)

## `metres` further along the same line once it's over the goal line (into the net, or wide).
static func past_line(from: Vector2, cross_y: float, metres: float) -> Vector2:
	var cross := Vector2(Geo.GOAL_X, cross_y)
	var dir := cross - from
	if dir.x < 0.05:
		dir = Vector2(1.0, 0.0)
	return cross + dir.normalized() * metres

## The catch-and-shoot bonus, 0..1, for a shot `catch_t` seconds after the catch (INF: no catch).
## `k` scales the whole window, full bonus and fade alike (Difficulty.catch_shoot_k: Play.cs_k).
static func catch_shoot(catch_t: float, k: float = 1.0) -> float:
	if catch_t <= CATCH_SHOOT_WINDOW * k:
		return 1.0
	return clampf(1.0 - (catch_t - CATCH_SHOOT_WINDOW * k) / (CATCH_SHOOT_FADE * k), 0.0, 1.0)

## How much of a cross-cage shot this is, 0..1: from off to one side (a decent angle, not
## straight on nor from the corner), aimed across to the far post, more so the further across
## and the more the keeper is cheating to the near post.
static func cross_cage(from: Vector2, aim_y: float, keeper_y: float) -> float:
	var side := from.y - Geo.GOAL_Y
	var far := (Geo.GOAL_Y - aim_y) * signf(side)   # > 0: the far half of the goal
	if absf(side) < 0.3 or far <= 0.0:
		return 0.0
	var ang := rad_to_deg(atan2(absf(side), maxf(Geo.GOAL_X - from.x, 0.3)))
	var angle_k := clampf((ang - CROSS_ANGLE.x) / (CROSS_ANGLE.y - CROSS_ANGLE.x), 0.0, 1.0) \
		* (1.0 - clampf((ang - CROSS_ANGLE.z) / 20.0, 0.0, 1.0))
	var deep := clampf(far / (Geo.GOAL_HALF * 0.8), 0.0, 1.0)
	var shade := clampf((keeper_y - Geo.GOAL_Y) * signf(side) / 0.8, 0.0, 1.0)   # on the near post
	return angle_k * deep * (0.4 + 0.6 * shade)

## Stage 1 of resolve(): every field defender the ball passes close enough to goes for it,
## nearest the shooter first. Fills res.attempts ({i, t0, t1, at, side, hit}: when his arm
## goes up, when the ball gets to him, where, and which side of him it passes) and, if one
## gets a hand to it, makes it a block that deflects off him. Returns true for a block.
static func _blocks(res: Dictionary, from: Vector2, dir: Vector2, speed: float, blockers: Array,
		rng: RandomNumberGenerator, late: float = 0.0, arms: Array = []) -> bool:
	var cands := _candidates(from, dir, speed, blockers, late, arms)
	var tried := 0
	for c in cands:
		if c.has("arm"):
			# through his raised arm: blocked, no dice
			var hand: Vector2 = c.arm.hand
			res.outcome = "block"
			res.blocker = int(c.arm.get("i", -1))
			res.end = c.at
			res.flight = float(c.along) / speed
			res.deflect = _deflect(dir, hand, c.at, speed, rng)
			res["arm"] = true
			return true
		if tried >= MAX_TRIES:
			continue
		var r: Dictionary = c.r
		var pos: Vector2 = c.b if c.b is Vector2 else c.b.pos
		var i := -1 if c.b is Vector2 else int(c.b.get("i", -1))
		var reach := float(r.reach)
		var perp := float(c.perp)
		var hit := false
		if perp <= reach:
			tried += 1
			hit = rng.randf() < block_chance(r, perp, speed)
		var arrive := float(r.arrive)
		var t0 := 0.0 if bool(r.set) else minf(float(r.react), arrive)
		var side := signf((pos - (c.at as Vector2)).cross(dir))   # which side of him it goes by
		res.attempts.append({"i": i, "t0": t0, "t1": arrive, "at": c.at, "side": side, "hit": hit,
			"lean": clampf(perp / maxf(reach, 0.01), 0.0, 1.0)})
		if hit:
			res.outcome = "block"
			res.blocker = i
			res.end = c.at
			res.flight = float(c.along) / speed
			res.deflect = _deflect(dir, pos, c.at, speed, rng)
			return true
	return false

## A field defender's chance to stop a ball that comes `perp` from him (within his reach, `r`:
## block_reach) at `speed`. The one formula: the shot's own roll (_blocks) and the red X (sure_block).
static func block_chance(r: Dictionary, perp: float, speed: float) -> float:
	var q := 1.0 - perp / maxf(float(r.reach), 0.01)   # 1 straight at him .. 0 at his fingertips
	# faster shots are harder to get a firm hand on
	var pace := lerpf(1.1, 0.8, clampf((speed - 9.0) / 9.0, 0.0, 1.0))
	var chance := (0.25 + 0.7 * q) * lerpf(0.8, 1.1, float(r.dfn)) * pace
	if not bool(r.set):
		chance *= OFF_BALL_HANDS   # reacting and stretching: a fingertip, not a wall
	if not bool(r.set) and float(r.arrive) < float(r.react):
		chance *= BODY_ONLY        # never saw it: only if it hits him square
	return chance

## THE RED X (the aim guide): the first point on a shot from `from` along `dir` at `speed` where a
## field defender is CERTAIN to stop it under _blocks' own rules, or {}: {at, along, i}. Certain
## means a fully raised arm in its way (arm_contact: no dice), or a man it reaches among the first
## MAX_TRIES whose block_chance is over 1 (the roll, randf() <= 1, can't miss). Anything less, a
## chance however good, is no X. The same candidates, in the same order, as the shot itself: what
## the X says is what that shot, released now, does. (The keeper is never in `blockers`.)
static func sure_block(from: Vector2, dir: Vector2, speed: float, blockers: Array, late: float = 0.0, arms: Array = []) -> Dictionary:
	var tried := 0
	for c in _candidates(from, dir, speed, blockers, late, arms):
		if c.has("arm"):
			return {"at": c.at, "along": c.along, "i": int(c.arm.get("i", -1)), "arm": true}
		if tried >= MAX_TRIES:
			break
		var r: Dictionary = c.r
		var perp := float(c.perp)
		if perp > float(r.reach):
			continue   # (a lunge he can't reach: no try, and no block)
		tried += 1
		if block_chance(r, perp, speed) > 1.0:
			return {"at": c.at, "along": c.along, "i": -1 if c.b is Vector2 else int(c.b.get("i", -1)), "arm": false}
	return {}

## Everybody who could get to a shot from `from` along `dir`, in the order the ball reaches them:
## the raised arms it goes through, and the field defenders near enough its path to try.
static func _candidates(from: Vector2, dir: Vector2, speed: float, blockers: Array, late: float, arms: Array) -> Array:
	var span := dir.length()
	var cands: Array = []
	for arm: Dictionary in arms:
		var ac := arm_contact(from, dir, speed, arm)
		if not ac.is_empty():
			cands.append({"arm": arm, "along": ac.along, "at": ac.at})
	for b in blockers:
		if _unready_guard(b):
			continue   # caught and shot before he'd got set on him
		var pos: Vector2 = b if b is Vector2 else b.pos
		var t := (pos - from).dot(dir) / (span * span)
		var along := t * span
		# not beside or behind the shooter, and not on top of the keeper
		if along < BLOCK_MIN_ALONG or along > span - BLOCK_GOAL_GAP:
			continue
		var at := from + dir * t
		var perp := at.distance_to(pos)
		var r := block_reach(b, from, along, speed, late)
		if perp > float(r.reach) + ATTEMPT_SLACK:
			continue
		if not bool(r.set) and float(r.arrive) < float(r.react) and perp > BODY_R:
			continue   # it's past him before he sees it
		cands.append({"b": b, "along": along, "at": at, "perp": perp, "r": r})
	cands.sort_custom(func(x, y): return float(x.along) < float(y.along))
	return cands

## The ball comes off his hand: back the way it came and away from his body, quicker off a
## harder shot. Play turns it into a loose ball with this drift.
static func _deflect(dir: Vector2, pos: Vector2, at: Vector2, speed: float, rng: RandomNumberGenerator) -> Vector2:
	var back := -dir.normalized()
	var away := at - pos
	if away.length() < 0.05:
		away = dir.orthogonal() * (1.0 if rng.randf() < 0.5 else -1.0)
	away = away.normalized()
	var out := (back * rng.randf_range(0.5, 1.2) + away * rng.randf_range(0.4, 1.3)).normalized()
	return out * clampf(speed * 0.28, 2.6, 4.8) * rng.randf_range(0.8, 1.1)

## Is a defender at `b` (as for resolve) a raised arm in the way of a shot from `from` at
## `to`? No dice: for the bots, who don't shoot into the man in their face, but will chance
## one that a defender further off has to react to.
static func lane_reach(from: Vector2, to: Vector2, speed: float, b) -> bool:
	var dir := to - from
	var span := dir.length()
	if span < 0.01:
		return false
	var pos: Vector2 = b if b is Vector2 else b.pos
	var t := (pos - from).dot(dir) / (span * span)
	var along := t * span
	if along < BLOCK_MIN_ALONG or along > span - BLOCK_GOAL_GAP:
		return false
	var r := block_reach(b, from, along, speed)
	return bool(r.set) and (from + dir * t).distance_to(pos) < float(r.reach) * 0.55

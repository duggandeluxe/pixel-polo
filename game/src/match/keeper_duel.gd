class_name KeeperDuel
extends RefCounted
## Their shot at your goal, and you in goal: the shooter winds up, the ball flies (in slow
## motion), and you tap the LEFT, CENTRE or RIGHT of the goal. Your keeper dives that way
## (KeeperDive: a beat to react, the rise, his window at full stretch, then he falls back into the
## water); if the ball crosses the line inside the reach of the body and arm you can see, it's
## saved. So the timing counts as much as the side: dive too early and he's back in the water
## when it arrives, too late and it's past him while he's still rising. Taps while a dive is
## running do nothing; once he's recovered he can dive again. Dive the wrong way and it's in. He
## never dives by himself, but a shot straight at him (inside BODY_R) hits him while he isn't
## diving: he blocks it.
## How high it crosses the line counts a little (`height`, ShotModel.shot_height): a low one, down
## at the water, is harder to get a hand to than one up under the bar (HEIGHT_REACH).
## Commit early (during the wind-up) and a good shooter puts it the other way.
## Attributes: the shooter's SHOOTING quickens (slows) his wind-up; the keeper's LUNGE SPEED his
## reaction and rise (KeeperDive.quick), LEG STRENGTH his reach and how long he stays up
## (KeeperDive.window), BLOCKING how often a ball inside that reach stays out (Attributes.hold_chance).
##
## Pure logic in pool metres: the screen draws it and feeds taps, tests use the bot keeper.
## `goal_x` is the goal line being defended: 0 in single player (your goal, left end), or
## Geo.GOAL_X when you defend your friend's attack in multiplayer.

enum State { WINDUP, FLIGHT, DONE }

const WALL_REACH := 0.06       # a WALL keeper reaches this much further
const LUNGE := Vector2(0.6, 0.85)   # how far his body goes on a dive (worst, best keeping)
const ARM := Vector2(0.4, 0.62)     # how far past his body his leading hand gets (worst, best)
## Their wind-up before the shot (times the shooter's release, Attributes.release_mult), and how
## often a shot of theirs goes wide on its own: the same at every difficulty.
const WINDUP := 0.85
const SELF_MISS := 0.04
const BODY_R := 0.3            # no dive: a shot crossing this close to him hits him (head, shoulders, hands up)
## His reach for a shot at the bottom of the goal .. the top (`height` 0 .. 1): low shots are a
## little harder to get to, high ones a little easier. The ball's height at the line (drawn): LINE_Z.
const HEIGHT_REACH := Vector2(0.92, 1.08)
const LINE_Z := Vector2(0.3, 0.9)
## The bot keeper (tests, autoplay) times his dive for the ball to arrive this far into his
## window, give or take BOT_TIMING (on-screen s, worst .. best).
const BOT_AIM := 0.35
const BOT_TIMING := Vector2(0.12, 0.03)

var state: int = State.WINDUP
var goal_x := 0.0
var from := Vector2.ZERO
var aim_y := Geo.GOAL_Y
var cross_y := Geo.GOAL_Y
var on_target := true
var outcome := ""              # "goal" | "save" | "parry" | "wide" | "post" once DONE
var penalty := false
var windup := 0.8
var flight := 0.4              # seconds the ball is in the air (game time)
var slowmo := 0.55             # the screen plays the flight at this speed
var t := 0.0                   # time in the current state
var keeper_start := Geo.GOAL_Y # where he is when the shot comes (the dive starts from here)
var keeper_y := Geo.GOAL_Y     # where his body is now
var target_y := Geo.GOAL_Y     # where his dive is headed (the tip of his reach at full stretch)
var tapped := false
var tapped_early := false      # dived during the wind-up
var anim: KeeperDive = null    # the dive, once you've tapped
var lunge := 0.75
var home := false              # your keeper is the home team's: he dives ShotModel.HOME_DIVE times faster
var reach := 0.5               # how far past his body his leading hand gets
var shooter_skill := 0.6
var by: PoloPlayer = null      # the shooter (the art: his Hot fire on the shot, HotFire)
var shooter_pace := 0.6         # his SHOOTING alone (Attributes.shot_pace / 100): the shot's speed
var given := false            # multiplayer: the shot was already aimed by a person
var quick := 1.0               # his dive's speed: 1 / Attributes.lunge_mult
var window := Attributes.WINDOW_AT_5   # Attributes.dive_window
var block := 0.0               # Attributes.block_mod
var height := 0.5              # where it crosses the line, 0 at the water .. 1 under the bar
var strain_loss := 0.0         # his legs, tired by a drop (KeeperLegs.loss at the release): less reach up high
var through := false           # the ball was in his hands and still went in (BLOCKING)
var dive_phase := -1           # the phase his dive was in as the ball got there (-1: no dive)
var rng: RandomNumberGenerator
var _bot_err := NAN            # the bot keeper's timing error for this shot

## A shot by `shooter` from `p_from`, aimed by the game (his own shooting sets its pace).
func setup(shooter: PoloPlayer, keeper: PoloPlayer, p_from: Vector2, p_goal_x: float,
		p_rng: RandomNumberGenerator, level: float, p_penalty: bool = false) -> KeeperDuel:
	rng = p_rng
	goal_x = p_goal_x
	from = p_from
	penalty = p_penalty
	by = shooter
	shooter_skill = clampf(shooter.live("shoot") / 100.0, 0.0, 1.0)
	shooter_pace = clampf(Attributes.shot_pace(shooter) / 100.0, 0.0, 1.0)   # (Hot Stars in it: play_value)
	_keeper(keeper, level)
	windup = WINDUP * (1.15 if penalty else 1.0) * Attributes.release_mult(shooter)
	_aim()
	return self

## A shot already aimed (cross_y) with its flight time: their live attack (Play), or your
## friend's in multiplayer. `keeper_y0`: where your keeper is when it leaves the hand; `p_height`
## how high it crosses the line (ShotModel's `height`).
func setup_given(keeper: PoloPlayer, p_from: Vector2, p_cross_y: float, p_flight: float,
		p_goal_x: float, keeper_y0: float, level: float, p_height: float = 0.5, p_on_target: bool = true,
		p_strain: float = 0.0) -> KeeperDuel:
	strain_loss = maxf(0.0, p_strain)
	rng = RandomNumberGenerator.new()
	rng.seed = hash([p_from, p_cross_y, p_flight])   # (the same shot, the same dice: BLOCKING's roll)
	given = true
	goal_x = p_goal_x
	from = p_from
	_keeper(keeper, level)
	keeper_start = keeper_y0
	keeper_y = keeper_y0
	target_y = keeper_y0
	cross_y = p_cross_y
	aim_y = p_cross_y
	on_target = p_on_target   # (off target: he can dive, the post or the miss stands: _resolve)
	flight = maxf(0.12, p_flight)
	height = clampf(p_height, 0.0, 1.0)
	windup = 0.0
	state = State.FLIGHT
	return self

## He's still in (or getting up from) the last dive when this shot comes, or he dived during the
## wind-up: that's the dive that has to stop it. No second dive until he's recovered.
func adopt(d: KeeperDive) -> void:
	anim = d
	anim.reach_k = height_k()
	tapped = true
	keeper_y = d.body_y()

func _keeper(keeper: PoloPlayer, level: float) -> void:
	# how far he goes is LEG STRENGTH's (Attributes.keeper_skill: his form counts, as it always did),
	# his speed LUNGE SPEED's: KeeperDive.body, the same body the AI's keepers dive with. Never the
	# difficulty's.
	var b := KeeperDive.body_of(keeper)
	lunge = float(b.lunge)
	reach = float(b.arm)
	quick = float(b.quick)
	window = float(b.window)
	block = Attributes.block_mod(keeper)
	slowmo = Difficulty.duel_slowmo(level)
	# he starts in the middle of his goal (setup_given: wherever he was tracking the ball)
	keeper_start = Geo.GOAL_Y
	keeper_y = keeper_start
	target_y = keeper_start

## Where the shooter puts it: mostly the corners, sometimes down the middle, with an error
## that shrinks with his shooting rating.
func _aim() -> void:
	var side := 1.0 if rng.randf() < 0.5 else -1.0
	if rng.randf() < 0.15:
		aim_y = Geo.GOAL_Y + rng.randf_range(-0.4, 0.4)
	else:
		aim_y = Geo.GOAL_Y + side * rng.randf_range(0.75, 1.35)
	_shoot()

func _shoot() -> void:
	var sigma := lerpf(0.5, 0.22, shooter_skill) * (0.8 if penalty else 1.0)
	cross_y = aim_y + rng.randfn(0.0, sigma)
	if rng.randf() < SELF_MISS:
		cross_y = Geo.GOAL_Y + signf(cross_y - Geo.GOAL_Y + 0.001) * (Geo.GOAL_HALF + rng.randf_range(0.2, 0.7))
	var off := absf(cross_y - Geo.GOAL_Y) - Geo.GOAL_HALF
	on_target = off <= -0.04
	height = ShotModel.shot_height(rng)
	# the pace is the shooter's own, the same wherever it's going: in, saved or wide
	var speed := lerpf(10.0, 15.0, shooter_pace) * (1.1 if penalty else 1.0)
	flight = from.distance_to(Vector2(goal_x, cross_y)) / speed

## You tap the goal at pool height `y` (KeeperDive.zone_for: the thirds of the mouth).
func tap(y: float) -> void:
	dive(KeeperDive.zone_for(y))

## Can he dive now? Not once it's decided, and not while a dive is running (rising, up, falling
## or bobbing back up): repeated taps never restart or stretch a dive.
func can_dive() -> bool:
	return state != State.DONE and (anim == null or anim.done())

## Your keeper dives LEFT (-1), CENTRE (0) or RIGHT (+1): the way he went is the way he went.
func dive(side: int) -> void:
	if not can_dive():
		return
	tapped = true
	tapped_early = state == State.WINDUP
	anim = _new_dive(clampi(side, -1, 1))
	target_y = keeper_y + float(anim.side) * (lunge + reach)

## Advance by `dt` game seconds (the screen already slowed the flight down by `slowmo`). The
## dive runs on screen time, so it's as explosive however slow the shot is shown.
func step(dt: float) -> void:
	if state == State.DONE:
		return
	t += dt
	if anim != null:
		anim.advance(dt / (slowmo if state == State.FLIGHT else 1.0))
		keeper_y = anim.body_y()
	if state == State.WINDUP:
		if t >= windup:
			_release()
		return
	if t >= flight:
		_resolve()

## After the shot is decided: his dive plays on (the hold and the recovery), in screen seconds.
func settle(real_dt: float) -> void:
	if anim != null:
		anim.advance(real_dt)
		keeper_y = anim.body_y()

func _release() -> void:
	state = State.FLIGHT
	t = 0.0
	# a keeper who committed early (and is still committed) gets punished by a good shooter
	if tapped_early and not anim.done() and not given and rng.randf() < lerpf(0.3, 0.75, shooter_skill):
		var side := -float(anim.side) if anim.side != 0 else (1.0 if rng.randf() < 0.5 else -1.0)
		aim_y = Geo.GOAL_Y + side * rng.randf_range(0.7, 1.3)
		_shoot()

## The ball is on the line: is it inside the body and hand you can see? Still gathering himself,
## or back in the water after a dive: only a ball straight at him (the body block).
func _resolve() -> void:
	state = State.DONE
	dive_phase = anim.phase() if anim != null else -1
	if not on_target:
		var off := absf(cross_y - Geo.GOAL_Y) - Geo.GOAL_HALF
		outcome = "post" if off <= 0.08 else "wide"
		return
	if anim == null or dive_phase in [KeeperDive.Phase.REACT, KeeperDive.Phase.RECOVER, KeeperDive.Phase.READY]:
		_body_block()
		return
	var at := anim.covers(cross_y)
	if at < 0.0:
		outcome = "goal"
		return
	if not _held(at):
		return
	outcome = "parry" if at > 0.8 else "save"
	anim.hit(cross_y)

## A ball inside his reach `at` of the way out to his fingertips: BLOCKING decides whether it
## stays out (Attributes.hold_chance). If not, it's through his hands: a goal.
func _held(at: float) -> bool:
	if rng.randf() < Attributes.hold_chance(at, block):
		return true
	outcome = "goal"
	through = true
	anim.hit(cross_y)
	return false

## His dive, with his LUNGE SPEED (and the home pool's) and his legs, against this shot's height.
func _new_dive(side: int) -> KeeperDive:
	var d := KeeperDive.new(side, keeper_y, lunge, reach, dive_quick())
	d.window = window
	d.reach_k = height_k()
	return d

## His reaction and rise speed: LUNGE SPEED, and the home pool's.
func dive_quick() -> float:
	return (ShotModel.HOME_DIVE if home else 1.0) * quick

## How long before the ball gets to him (on-screen s) a dive has him up for it, `into` of the way
## through his window (0: just up .. 1: about to fall).
func ideal_up(into: float) -> float:
	return (KeeperDive.REACT + KeeperDive.EXTEND) / dive_quick() + window * into

## His reach against this shot: HEIGHT_REACH between the bottom and the top of the goal, less what
## a long drop has taken out of his legs up high (ShotModel.legs_mult: the computer's keeper's line).
func height_k() -> float:
	return lerpf(HEIGHT_REACH.x, HEIGHT_REACH.y, height) * ShotModel.legs_mult(height, strain_loss)

## Not diving, and it's straight at him: he gets his body and hands to it (the block, up out of
## the water). Wider than BODY_R and it's in.
func _body_block() -> void:
	if absf(cross_y - keeper_y) > BODY_R:
		outcome = "goal"
		return
	anim = _new_dive(KeeperDive.CENTRE)
	anim.t = anim.extend_time()   # already up: the ball's on him
	if not _held(0.0):
		return
	outcome = "save"
	anim.hit(cross_y)

func done() -> bool:
	return state == State.DONE

func saved() -> bool:
	return outcome == "save" or outcome == "parry"

## Why a dive the right way didn't stop it: "early" (he'd already fallen), "late" (still
## reacting or rising), or "" (saved, no dive, the wrong way, or through his hands).
func timing() -> String:
	if outcome != "goal" or through or anim == null or dive_phase < 0 or not anim.covers_at_full(cross_y):
		return ""
	if dive_phase in [KeeperDive.Phase.FALL, KeeperDive.Phase.RECOVER, KeeperDive.Phase.READY]:
		return "early"
	if dive_phase in [KeeperDive.Phase.REACT, KeeperDive.Phase.RISE]:
		return "late"
	return ""

## 0..1 along the flight, for drawing.
func progress() -> float:
	if state == State.WINDUP:
		return 0.0
	if state == State.DONE:
		return 1.0
	return clampf(t / flight, 0.0, 1.0)

func ball_pos() -> Vector2:
	return from.lerp(Vector2(goal_x, cross_y), progress())

func ball_z() -> float:
	return lerpf(0.9, lerpf(LINE_Z.x, LINE_Z.y, height), progress()) if state != State.WINDUP else 1.2

## Keeper art (the old lunge): -1 diving up the screen, +1 down.
func dive_art() -> float:
	return float(anim.side) * anim.ext() if anim != null else 0.0

## The bot keeper (tests, autoplay): once he's seen it (a reaction time into the flight) he
## times his dive for the ball to arrive BOT_AIM into his window, give or take his timing error;
## a side read with an error too. skill 0 never taps, 1 is near perfect.
func bot(dt_left: float, skill: float, brng: RandomNumberGenerator) -> void:
	if skill <= 0.0 or tapped or state != State.FLIGHT:
		return
	if is_nan(_bot_err):
		_bot_err = brng.randfn(0.0, lerpf(BOT_TIMING.x, BOT_TIMING.y, skill))
	var react := lerpf(0.32, 0.08, skill)
	var go := flight - (ideal_up(BOT_AIM) + _bot_err) * slowmo   # (game time: the dive runs on screen time)
	if t >= maxf(react, go) - dt_left:
		tap(cross_y + brng.randfn(0.0, lerpf(0.9, 0.12, skill)))

## A whole duel at once (sims, tests): returns the outcome.
func auto(skill: float, brng: RandomNumberGenerator) -> String:
	var guard := 0
	while not done() and guard < 1000:
		guard += 1
		bot(0.0, skill, brng)
		step(0.01)
	return outcome

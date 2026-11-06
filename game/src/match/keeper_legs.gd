class_name KeeperLegs
## GOALKEEPER LEG FATIGUE IN A DROP. Behind a drop the keeper has the shooting lanes the drop
## leaves to cover, and staying up high and ready for them is work for his legs; behind PRESS it
## isn't. So while his team defends in a drop (any of the four, the same way) his legs tire, and
## the higher a shot is the more that costs him: his reach up at the top corner shrinks, down at
## the water it doesn't change at all (ShotModel.legs_mult). It's his real reach, the one his dive
## is made with (KeeperDive.reach_k) for your keeper and the computer's alike, so the dive you see
## is the dive that stops it, or doesn't.
##
## It's one possession's work, on the Play (one Play = one defensive possession: fouls and
## restarts carry on in it), never a stamina system: a new possession is fresh legs.
##   Play.gk_strain   seconds of drop his legs have in them (an average pair: one a second)
##   loss()           what that takes off his top-corner reach: nothing for the first ONSET s,
##                    growing smoothly to his CAP by FULL s
## Only live time counts (Play.step, after a whistle's freeze; not while a restart has the shot
## clock stopped). Back in PRESS he gets his legs back gradually (RECOVER), so flicking in and out
## of a drop never wipes it.
##
## LEG STRENGTH (play_value "leg") is how well he copes: strong legs tire slower (RATE) and lose
## less at worst (CAP). On top of what Leg Strength already does for his reach and his window
## (KeeperDive.body, Attributes.dive_window): those are untouched.

const ONSET := 1.5            # drop seconds (strain) before anything shows...
const FULL := 9.0             # ...and the most he'll lose, by here
const RATE := Vector2(1.3, 0.7)    # strain a second in a drop: Leg Strength 0 .. 10
const CAP := Vector2(0.24, 0.12)   # the most it takes off his reach at the top of the goal: Leg Strength 0 .. 10
const RECOVER := 0.6          # back in PRESS: strain off a second (slower than it went on)

## His Leg Strength, 0-10 (anyone else in goal: an average pair, 5).
static func legs(keeper: PoloPlayer) -> float:
	if keeper == null or not keeper.is_keeper():
		return 5.0
	return Attributes.play_value(keeper, "leg")

static func rate(keeper: PoloPlayer) -> float:
	return lerpf(RATE.x, RATE.y, Attributes.unit(legs(keeper)))

static func cap(keeper: PoloPlayer) -> float:
	return lerpf(CAP.x, CAP.y, Attributes.unit(legs(keeper)))

## His team is defending in a drop right now: the formation's running and it's one of the four.
static func in_drop(p: Play) -> bool:
	return DefenseFormation.drops(p.formation) and DefenseFormation.active(p)

## One live frame (Play.step): his legs tire in a drop and come back in PRESS. A restart (the shot
## clock stopped for a foul) changes neither.
static func step(p: Play, dt: float) -> void:
	if p.restart or p.keeper == null:
		return
	if in_drop(p):
		p.gk_strain += dt * rate(p.keeper.player)
		p.drop_t += dt
	else:
		p.gk_strain = maxf(0.0, p.gk_strain - dt * RECOVER)

## What `strain` takes off `keeper`'s reach at the top of the goal, 0 .. his CAP.
static func loss_at(strain: float, keeper: PoloPlayer) -> float:
	return cap(keeper) * smoothstep(ONSET, FULL, strain)

## ...for the keeper in this possession, now.
static func loss(p: Play) -> float:
	return loss_at(p.gk_strain, p.keeper.player) if p.keeper != null else 0.0

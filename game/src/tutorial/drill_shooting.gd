class_name ShootingDrill
extends Drill
## Part 3: shoot past a real keeper. One shooter about 5.3 m out, just right of the goal (the
## bottom of the screen), their keeper in, nobody else: pull the shooting stick back and let go, exactly as in a
## match (MatchScreen's slingshot, ShotModel). First a goal across into the far corner, then one
## inside the near post. A save, a miss or the keeper's ball gives it straight back.
##
## The keeper is a tutorial keeper, a little easier than a match's: he reacts LATE later than his
## rating, and he always commits the same way (Play.keeper_dive), as a match keeper commits to his
## guess. For the cross-cage goal he shades to the near post (PlayAI._keeper) and dives for it,
## which leaves the far corner. For the near-side goal he cheats across (Play.keeper_spot) and dives
## for the far corner, which leaves the near post.

const GOALS := 1
## 5.3 m from the middle of the goal, just outside its right post.
const SPOT := Vector2(25.0, 11.8)
const CORNER := 0.3                 # m off the middle of the goal: a corner, not the middle
const LATE := 0.06                  # s: the tutorial keeper's reaction, later than his rating's
const CHEAT := 0.2                  # m: the near-side part, he sets this far towards the far post

var cross := 0
var near := 0
var lead_in := Vector2.ZERO         # the first rep: where the shooter swims in from (ZERO: he's on his spot)

func _init() -> void:
	id = "shooting"
	passing = false
	shooting = true

func cross_done() -> bool:
	return cross >= GOALS

## The current shooting stick (ShotStick): pull back to shoot, up or down to aim the slingshot's
## way round (up aims low in the goal, down aims high), let go to fire.
func instruction() -> String:
	if not cross_done():
		return "PULL BACK TO SHOOT! PULL DOWN TO AIM HIGH, ACROSS. RELEASE TO FIRE!"
	return "PULL BACK AND UP TO AIM LOW, INSIDE THE NEAR POST. RELEASE TO FIRE!"

func progress() -> String:
	return "CROSS-CAGE: %d / %d     NEAR-SIDE: %d / %d" % [mini(cross, GOALS), GOALS, mini(near, GOALS), GOALS]

## From the break: the man who had the ball, if he's coming in on this side of the goal, swims it
## on in to the shooting spot (from anywhere else he's simply on it).
const LEAD_IN_R := 6.0
func follow_on(prev: DrillFlow) -> void:
	var p := prev.play
	if p == null or p.holder == null:
		return
	var from := p.holder.pos
	if from.x < SPOT.x and from.y > Geo.GOAL_Y + Geo.GOAL_HALF and from.distance_to(SPOT) < LEAD_IN_R:
		lead_in = from

func start(flow: DrillFlow) -> void:
	var p := flow.attack()
	var s := strip(p, ["2"], true)
	place(s, SPOT)
	if lead_in != Vector2.ZERO:
		s.pos = lead_in   # (he swims it to his spot: PlayAI._carry)
		s.facing = 1.0
		lead_in = Vector2.ZERO
	p.keeper_late = LATE
	p.keeper_spot = Geo.GOAL_Y - CHEAT if cross_done() else NAN
	# (the shooter is on the RIGHT, +y side: his near post is the keeper's RIGHT)
	p.keeper_dive = KeeperDive.LEFT if cross_done() else KeeperDive.RIGHT
	if not is_nan(p.keeper_spot):
		p.keeper.pos.y = p.keeper_spot
	p._hold_ball()

## Which side of the goal a shot that crossed at `cross_y` went in, from the shooter's side:
## "cross" (the far half), "near" (the near half) or "middle".
static func corner_of(cross_y: float, from_y: float = SPOT.y) -> String:
	var far := (Geo.GOAL_Y - cross_y) * signf(from_y - Geo.GOAL_Y)
	if far >= CORNER:
		return "cross"
	if far <= -CORNER:
		return "near"
	return "middle"

func on_event(flow: DrillFlow, e: Dictionary) -> void:
	if String(e.k) != "end":
		return
	var b := flow.play.ball
	match String(e.outcome):
		"goal":
			var side := corner_of(float(b.shot.cross_y), b.from.y)
			if not cross_done():
				if side == "cross":
					cross += 1
			elif side == "near":
				near += 1
				complete = near >= GOALS

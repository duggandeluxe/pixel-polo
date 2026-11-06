class_name Geo
## Pool geometry in metres. x runs along the pool, y across it. The user's team always
## attacks the goal at x = GOAL_X (the right-hand end on screen).

const LENGTH := 30.0
const WIDTH := 20.0
const GOAL_X := 30.0
const GOAL_Y := 10.0
const GOAL_HALF := 1.5        # half of the 3 m goal mouth
const NET_DEPTH := 0.5        # the net hangs this far behind the goal line
const KEEPER_X := 29.5
const TWO_M := 28.0
const FIVE_M := 25.0
const SIX_M := 24.0
const HALF := 15.0
## Where an excluded defender waits: the re-entry corner by his own goal line.
const REENTRY := Vector2(29.6, 19.4)

static func goal_center() -> Vector2:
	return Vector2(GOAL_X, GOAL_Y)

## Inside the water (a tap on the deck or the stands is not).
static func in_pool(p: Vector2) -> bool:
	return p.x >= 0.0 and p.x <= LENGTH and p.y >= 0.0 and p.y <= WIDTH

static func clamp_in_pool(p: Vector2) -> Vector2:
	return Vector2(clampf(p.x, 0.4, LENGTH - 0.3), clampf(p.y, 0.5, WIDTH - 0.5))

## Metres from the goal line, the way a commentator says it ("from 6 m").
static func range_to_goal(p: Vector2) -> float:
	return p.distance_to(goal_center())

## The AI only shoots from here: on or inside the 6 m line (the water polo "6 metres": distance
## out from the goal line, SIX_M). From further out it works the ball in instead (OffenseAI, PlayBot).
const AI_SHOT_RANGE := GOAL_X - SIX_M

static func in_shot_range(p: Vector2) -> bool:
	return GOAL_X - p.x <= AI_SHOT_RANGE + 0.001

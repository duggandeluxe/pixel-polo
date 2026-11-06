class_name Tempo
## How hard a man shoots, how fast his passes travel and how quickly their ball carrier makes up
## his mind. One place for every number, so the shots, the passes, their attack's brain
## (MatchFlow) and the Developer Mode lab all agree.
##
## Only the man with the ball counts: his shooting decides a shot's pace and his passing a
## pass's, and how long he looks. His TEAM's overall never does (2.0: team overall is
## information only; every team plays at what used to be the average team's pace, so an average
## man plays exactly as before). Form counts wherever the man's own ratings count
## (PoloPlayer.live), and nowhere else.
##
## Only pace and timing: where a shot goes (ShotModel's spread) never reads any of this.

## The shooter: the main thing. A typical shooter (SHOT_PIVOT) shoots exactly as he always has
## (SHOT_AT_PIVOT); every point either side moves it by SHOT_SLOPE / 100.
const SHOT_PIVOT := 65.0
const SHOT_AT_PIVOT := 1.036
const SHOT_SLOPE := 0.4
## The fastest any shot leaves the hand (m/s), before the centre's power shot: a rocket, never a
## blur no keeper can see.
const SHOT_MAX := 20.0
## Passes: the passer's rating either side of PASS_MID moves its pace by up to PASS_SKILL.
const PASS_MID := 65.0
const PASS_SKILL := 0.06
## Their attack's decisions (MatchFlow): how long the man on the ball takes to look, to react to
## the press and to get it away, as a share of the normal time: a good passer up to this much
## quicker, a poor one slower. The same choices either way (OffenseAI): only the speed.
const THINK_PASSING := 0.08

## Piecewise-linear through `pts` (x ascending), flat beyond the ends.
static func curve(pts: Array, x: float) -> float:
	if x <= pts[0].x:
		return pts[0].y
	for i in range(1, pts.size()):
		var b: Vector2 = pts[i]
		if x <= b.x:
			var a: Vector2 = pts[i - 1]
			return lerpf(a.y, b.y, (x - a.x) / (b.x - a.x))
	return pts[pts.size() - 1].y

## The shooter's share of a shot's pace, for his shooting `skill` (0-100, form and all).
static func shooter_shot(skill: float) -> float:
	return SHOT_AT_PIVOT + (clampf(skill, 0.0, 100.0) - SHOT_PIVOT) / 100.0 * SHOT_SLOPE

## A pass's pace as a share of Play.PASS_SPEED, from the passer's `passing`.
static func pass_mult(passing: float) -> float:
	return 1.0 + clampf((passing - PASS_MID) / (100.0 - PASS_MID), -1.0, 1.0) * PASS_SKILL

## How long their ball carrier takes over each decision, as a share of the normal time, from his
## `passing`.
static func think_mult(passing: float) -> float:
	return 1.0 - clampf((passing - PASS_MID) / (100.0 - PASS_MID), -1.0, 1.0) * THINK_PASSING

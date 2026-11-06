class_name DrillFlow
extends MatchFlow
## A tutorial drill on the match engine: MatchFlow's possessions (Play, PlayAI, ShotModel, your
## keeper's tracking and dives) with a Drill deciding who's in the water for each rep. No game
## clock, no shot clock, no sprint, no score that goes anywhere: when a rep ends the drill sets
## up the next, until it's complete.

var drill: Drill
var finished := false     # the drill's done: no more reps (the screen shows its card)

func _init(p_drill: Drill, p_us: PoloTeam, p_them: PoloTeam, seed_value: int) -> void:
	super(p_us, p_them, seed_value, MatchState.QUARTER_MIN, p_drill.level)
	drill = p_drill

## The next rep, set up by the drill.
func start_rep() -> void:
	drill.reset_in = -1.0
	drill.start(self)

## Your attack, as a match starts one (the drill strips it down).
func attack(kind: int = Play.Kind.HALF_COURT) -> Play:
	_start_attack(kind)
	return play

## Their attack with you in goal, as a match starts one.
func defend(kind: int = Play.Kind.HALF_COURT) -> Play:
	_start_defense(kind)
	return play

## The rep's over and its banner has been shown.
func attack_done() -> void:
	_rep_over()

func defense_done() -> void:
	_rep_over()

func _rep_over() -> void:
	if drill.complete:
		finished = true
	else:
		start_rep()

## No game clock in a drill (and so no buzzer).
func _run_clock(_live: float) -> void:
	play.clutch = false

## Their man on the ball: the drill's shooter, when it has one; otherwise MatchFlow's.
func _tick_opp(dt: float) -> void:
	if not drill.their_throw(self, dt):
		super._tick_opp(dt)

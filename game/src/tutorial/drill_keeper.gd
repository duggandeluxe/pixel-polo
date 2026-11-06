class_name KeeperDrill
extends Drill
## Part 4: you're in goal. One of theirs with the ball about 6 m out, nobody else: their live
## attack as a match plays it (MatchFlow's defence), your keeper tracking the ball by himself,
## and when the shot comes you tap: the top of the goal (his left), the middle (the block) or the
## bottom (his right), KeeperDive's lunge and all. Three saves you made yourself, one each way:
## a way counts only when you dove (or blocked) that way and it was saved, and once it's done the
## shooter never goes there again in this run of the drill (by_side: the RESTART or a new run
## clears it); he picks from the ways still to do. A goal or a miss: a new shot the same way.

const SAVES := 3
const SPOTS := [Vector2(23.6, 10.0), Vector2(24.0, 7.4), Vector2(24.0, 12.6), Vector2(24.6, 8.6), Vector2(24.6, 11.4)]
const HOLD := Vector2(0.9, 1.6)     # seconds he has it before he winds up
const SIDE_AIM := Vector2(0.75, 1.25)   # m off the middle of the goal for a shot at a side...
const MIDDLE_AIM := 0.3              # ...and at most this for one at the middle
const NAMES := {KeeperDive.LEFT: "LEFT", KeeperDive.CENTRE: "MIDDLE", KeeperDive.RIGHT: "RIGHT"}

var saves := 0
var by_side := {KeeperDive.LEFT: 0, KeeperDive.CENTRE: 0, KeeperDive.RIGHT: 0}
var zone := KeeperDive.LEFT   # where this rep's shot is going
var _wait := 0.0              # seconds before he winds up
var _dive := {}               # the dive you made for the shot in the air: {tapped, side}
var shots := 0                # shots he's taken (the first: how your keeper moves)
var rng := RandomNumberGenerator.new()

func _init() -> void:
	id = "keeper"
	passing = false
	rng.seed = 41

func phase() -> int:
	return MatchFlow.Phase.DEFENSE

func instruction() -> String:
	if shots == 0 and saves == 0:
		return "YOUR GOALIE TRACKS THE BALL: WATCH THE SHOOTER, TAP WHEN HE SHOOTS"
	if zone == KeeperDive.CENTRE:
		return "BLOCK STRAIGHT AHEAD WHEN NEEDED: TAP THE MIDDLE"
	return "DIVE LEFT OR RIGHT TO BLOCK"

func progress() -> String:
	var parts := PackedStringArray(["SAVES: %d / %d" % [mini(saves, SAVES), SAVES]])
	for s in [KeeperDive.LEFT, KeeperDive.CENTRE, KeeperDive.RIGHT]:
		parts.append("%s %s" % [NAMES[s], "OK" if by_side[s] > 0 else "-"])
	return "   ".join(parts)

## Is a save each way still to come?
func needs(side: int) -> bool:
	return by_side[side] == 0

func start(flow: DrillFlow) -> void:
	var p := flow.defend()
	var shooter := strip(p, PlaySetup.TAGS, true, "3")
	for a in p.attackers.duplicate():
		if a != shooter:
			p.attackers.erase(a)
	place(shooter, SPOTS[rng.randi() % SPOTS.size()])
	p._hold_ball()
	zone = next_zone()
	_wait = rng.randf_range(HOLD.x, HOLD.y)
	_dive = {}

## The way this rep's shot goes: one still to be saved (never one you've done), at random
## among them; the last one left until you save it.
func next_zone() -> int:
	var left: Array = [KeeperDive.LEFT, KeeperDive.CENTRE, KeeperDive.RIGHT].filter(func(s): return needs(s))
	if left.is_empty():
		return zone   # (all done: the drill's complete, nothing more is shot)
	return left[rng.randi() % left.size()]

## Where this rep's shot is aimed: a side of the goal or its middle, never quite the same spot.
func aim_y() -> float:
	if zone == KeeperDive.CENTRE:
		return Geo.GOAL_Y + rng.randf_range(-MIDDLE_AIM, MIDDLE_AIM)
	return Geo.GOAL_Y + float(zone) * rng.randf_range(SIDE_AIM.x, SIDE_AIM.y)

## He looks, then winds up and shoots, the way MatchFlow's own attack does it (opp_plan: the
## ball up, "HE'S SHOOTING!", the throw when the wind-up's done). A rebound in his hands: again.
func their_throw(flow: DrillFlow, dt: float) -> bool:
	var p := flow.play
	if p.over or not p.can_throw() or not flow.opp_plan.is_empty() or flow.opp_holder != p.holder:
		return false
	_wait -= dt
	if _wait > 0.0:
		return true
	_wait = rng.randf_range(HOLD.x, HOLD.y)
	_dive = {}
	shots += 1
	p.raise_ball(true)
	flow.opp_plan = {"target": Vector2(Geo.GOAL_X, aim_y()), "power": rng.randf_range(0.55, 0.8), "shot": true,
		"t": MatchFlow.OPP_SHOT_WINDUP * KeeperDuel.WINDUP}
	flow.events.append({"k": "windup"})
	return true

func dived(side: int) -> void:
	_dive = {"tapped": true, "side": side}

func on_event(_flow: DrillFlow, e: Dictionary) -> void:
	match String(e.k):
		"save":
			# (one that hit you, or the wrong dive, counts for nothing)
			if not _dive.is_empty() and _dive.tapped and int(_dive.side) == zone:
				saves += 1
				by_side[zone] += 1   # this way's done: he won't shoot here again (next_zone)
				if not needs(KeeperDive.LEFT) and not needs(KeeperDive.CENTRE) and not needs(KeeperDive.RIGHT):
					complete = true
			_dive = {}

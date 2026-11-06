class_name FrontcourtDrill
extends Drill
## Part 1: move the ball round the set attack. Your six in the umbrella, nobody marking them,
## no keeper: tap a teammate and the ball goes to him, as in a match. Five passes caught, between
## at least three different men.

const PASSES := 5
const PLAYERS := 3

var passes := 0
var touched := {}          # PoloPlayer -> true: everybody who's thrown or caught a counted pass
var _passer: Swimmer = null   # the pass in the air: who threw it
var _recovered := false       # the next catch is a loose ball gathered, not a pass

func _init() -> void:
	id = "frontcourt"

func instruction() -> String:
	if passes >= PASSES and touched.size() < PLAYERS:
		return "NOW PASS TO SOMEONE WHO HASN'T HAD IT"
	return "TAP A TEAMMATE TO PASS" if passes == 0 else "NICE! KEEP THE BALL MOVING"

func progress() -> String:
	return "PASSES: %d / %d     PLAYERS: %d / %d" % [mini(passes, PASSES), PASSES, mini(touched.size(), PLAYERS), PLAYERS]

func start(flow: DrillFlow) -> void:
	strip(flow.attack(), PlaySetup.TAGS, false, "3")
	_passer = null
	_recovered = false

func thrown(flow: DrillFlow) -> void:
	_passer = flow.play.ball.passer

func on_event(flow: DrillFlow, e: Dictionary) -> void:
	match String(e.k):
		"recover":
			_recovered = true
		"catch":
			if _recovered or _passer == null:
				_recovered = false
				_passer = null
				return
			passes += 1
			touched[_passer.player] = true
			touched[flow.play.holder.player] = true
			_passer = null
			if passes >= PASSES and touched.size() >= PLAYERS:
				complete = true

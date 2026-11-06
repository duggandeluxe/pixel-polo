extends "res://src/ui/screens/play_lab.gd"
## Developer Mode's SPECIAL GOAL EFFECTS (Settings > Developer Mode): BAR-IN! and BAR-DOWN! on
## demand, in the water, without waiting for one to come up. Each test is a real possession: the
## man with the ball (on the point, straight on, the lane in front of him cleared) puts one in
## (Play.dev_goal) crossing the line tight to the frame (BarHit.demo), and from the release on it's
## all the game's own: BarHit.pick (with only its die forced), the flight bending onto the frame, the
## CLANG! / BANG!, the hit-stop, the ricochet, the net, GOAL!. Then the lab settles again.
##   LEFT POST      in off the inside of the left post: BAR-IN!, across into the right side netting
##   RIGHT POST     the same off the right post
##   CROSSBAR       down off the underside of the bar: BAR-DOWN!
##   UPPER-LEFT / UPPER-RIGHT   into the corner, tight to post and bar at once: CORNER says which
##                  surface it meets (POST: from straight on, BAR-IN!; BAR: from out wide, BAR-DOWN!)
##   REPLAY         the last test again
##   PROBABILITY    this session's override for real matches (BarHit.override: NORMAL / ALWAYS /
##                  NEVER), only while Developer Mode is on, never saved
## Nothing is counted: no goal, no statistic, no standing, no save (play_lab).

const TESTS := [["LEFT POST", "left"], ["RIGHT POST", "right"], ["CROSSBAR", "bar"],
	["UPPER-LEFT", "ul"], ["UPPER-RIGHT", "ur"]]
const LABELS := {"left": "LEFT POST", "right": "RIGHT POST", "bar": "CROSSBAR", "ul": "UPPER-LEFT", "ur": "UPPER-RIGHT"}
const LANE_CLEAR := 1.0        # m: nobody left this close to the shot's line

var last := ""
var corner_bar := false
var corner_btn: Button
var prob_btn: Button

func _ready() -> void:
	lab_ready("SPECIAL GOAL EFFECTS")
	var row := UI.hbox(3)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	body.add_child(row)
	for tst in TESTS:
		var key: String = tst[1]
		row.add_child(UI.button(tst[0], func(): run(key), "normal", 84, 18))
	var row2 := UI.hbox(3)
	row2.alignment = BoxContainer.ALIGNMENT_CENTER
	body.add_child(row2)
	row2.add_child(UI.button("REPLAY LAST", func():
		if last == "":
			Game.toast("Pick a test first", UI.DIM)
			return
		run(last), "ghost", 84, 18))
	corner_btn = UI.button("", func():
		corner_bar = not corner_bar
		_labels(), "ghost", 110, 18)
	row2.add_child(corner_btn)
	prob_btn = UI.button("", func():
		BarHit.override = (BarHit.override + 1) % BarHit.OVERRIDE_NAMES.size()
		_labels(), "ghost", 150, 18)
	row2.add_child(prob_btn)
	_labels()
	settled.call_deferred()

func _labels() -> void:
	corner_btn.text = "CORNER: %s" % ("BAR" if corner_bar else "POST")
	prob_btn.text = "MATCH PROBABILITY: %s" % BarHit.OVERRIDE_NAMES[BarHit.override]

## Waiting: a fresh possession, still, the man with the ball on the point.
func settled() -> void:
	new_play()
	_place(BarHit.DEMO_FROM, Vector2(Geo.GOAL_X, Geo.GOAL_Y))
	paused = true
	status = "PICK A TEST" if last == "" else "DONE  (REPLAY LAST to see it again)"

## Test `test` ("left", "right", "bar", "ul", "ur"). False: it couldn't be set up.
func run(test: String) -> bool:
	var d := BarHit.demo(test, corner_bar)
	if d.is_empty():
		return false
	new_play()
	var end := Vector2(Geo.GOAL_X, float(d.cross_y))
	_place(d.from, end)
	last = test
	paused = false
	if not play.dev_goal(float(d.cross_y), float(d.height)):
		status = "COULDN'T SET IT UP"
		return false
	var kind := int(play.ball.bar.get("kind", BarHit.Kind.NONE))
	status = "%s: %s  (%s)" % [LABELS[test], String(play.ball.bar.get("text", "PLAIN GOAL")),
		["", "LEFT POST", "RIGHT POST", "CROSSBAR"][kind]]
	return true

## The man with the ball (the point, "3") at `from`, ball in hand, anybody near the line to `end`
## moved out of it (the shot's never blocked, but it shouldn't look like it went through a man).
func _place(from: Vector2, end: Vector2) -> void:
	var s: Swimmer = DefenseFormation.by_tag(play.attackers, "3")
	if s == null:
		s = play.attackers[0]
	s.pos = from
	s.vel = Vector2.ZERO
	s.target = from
	s.facing = 1.0
	play.give_ball(s)
	var dir := (end - from).normalized()
	for b in play.bodies():
		if b == s or b.keeper:
			continue
		var u := (b.pos - from).dot(dir)
		var off := (b.pos - from) - dir * u
		if u > -0.5 and off.length() < LANE_CLEAR:
			var side := signf(off.dot(dir.orthogonal()))
			b.pos += dir.orthogonal() * (side if side != 0.0 else 1.0) * (LANE_CLEAR + 0.4 - off.length())
			b.vel = Vector2.ZERO
			b.target = b.pos

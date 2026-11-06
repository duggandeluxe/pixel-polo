class_name Drill
extends RefCounted
## One part of the tutorial, played on the match engine (DrillFlow, DrillScreen): it decides who's
## in the water for each rep and counts what you get right. Everything
## else (passing, swimming, shooting, the keepers) is the real game's. One subclass per part:
## FrontcourtDrill, CounterDrill, ShootingDrill, KeeperDrill. The screen plays them one after
## another as a single tutorial.

## The parts, in order.
const ORDER := ["frontcourt", "counter", "shooting", "keeper"]
const TITLES := {"frontcourt": "PASSING", "counter": "COUNTERATTACK",
	"shooting": "SHOOTING", "keeper": "GOALIE BLOCKING"}
## The callout as a part's done and the next one picks up: [what you did, what's next].
const SEGUES := {"frontcourt": ["NICE PASSING!", "NOW LET'S RUN A COUNTER!"],
	"counter": ["GREAT LEAD PASSES!", "NOW FINISH THE BREAK: SHOOT!"],
	"shooting": ["NICE SHOOTING!", "NOW GET BACK IN GOAL!"]}
## The pop-up before each part: one sentence, in the lines it's drawn in (its title is TITLES').
const BRIEFS := {"frontcourt": ["Tap a teammate", "to pass him the ball."],
	"counter": ["Tap the water just ahead", "of a swimmer to lead him."],
	"shooting": ["Pull the stick back, aim,", "then let go to shoot."],
	"keeper": ["When he shoots, tap the top,", "middle or bottom of your goal."]}

var id := ""
var level := 0.25          # the difficulty the drill is played at (Difficulty: between EASY and MEDIUM)
var passing := true        # a tap passes
var shooting := false      # the shooting stick shoots
var complete := false
var reset_in := -1.0       # seconds to a fresh rep the drill has asked for (-1: none)

static func make(drill_id: String) -> Drill:
	match drill_id:
		"counter":
			return CounterDrill.new()
		"shooting":
			return ShootingDrill.new()
		"keeper":
			return KeeperDrill.new()
	return FrontcourtDrill.new()

## Where the tutorial picks up, given the parts already done (Game.settings.tutorials_done): the
## first one not done yet, or the start once they all are.
static func resume_part(done: Array) -> int:
	for i in ORDER.size():
		if not ORDER[i] in done:
			return i
	return 0

## The part after this one ("" after the last).
func next_id() -> String:
	var i := ORDER.find(id)
	return ORDER[i + 1] if i >= 0 and i + 1 < ORDER.size() else ""

func title() -> String:
	return String(TITLES.get(id, ""))

## This part follows on from `prev` (the last part's flow, as it was when that part ended): a
## part can pick up from where it left the play.
func follow_on(_prev: DrillFlow) -> void:
	pass

# ------------------------------------------------------------------ what a lesson fills in
## The line at the top of the screen.
func instruction() -> String:
	return ""

## The counts under it ("PASSES: 3 / 5").
func progress() -> String:
	return ""

## Which side of the ball you're on: MatchFlow.Phase.ATTACK or DEFENSE.
func phase() -> int:
	return MatchFlow.Phase.ATTACK

## Set up a rep: flow.attack() or flow.defend(), then strip() it to the drill.
func start(_flow: DrillFlow) -> void:
	pass

## The play's events (Play.events), after the screen has seen them.
func on_event(_flow: DrillFlow, _e: Dictionary) -> void:
	pass

## A pass you just threw (the ball's left the hand, the receiver as he was at the release).
func thrown(_flow: DrillFlow) -> void:
	pass

## You tapped to dive (your keeper drills): KeeperDive.LEFT, CENTRE or RIGHT.
func dived(_side: int) -> void:
	pass

## Their man on the ball (your keeper drills): true if the drill threw or is waiting to, false
## to leave it to MatchFlow (a wind-up counting down, a new man on the ball).
func their_throw(_flow: DrillFlow, _dt: float) -> bool:
	return false

## Every frame of play. Lessons call super() for the asked-for reset.
func tick(flow: DrillFlow, dt: float) -> void:
	if reset_in >= 0.0:
		reset_in -= dt
		if reset_in < 0.0:
			flow.start_rep()

# ------------------------------------------------------------------ helpers
## A fresh rep in `secs` (the progress is kept).
func reset_after(secs: float) -> void:
	if reset_in < 0.0:
		reset_in = secs

## Strips a possession down to the drill: only the attackers tagged in `keep`, none of the
## defenders, the keeper in his goal or out of the water. The ball goes to `holder_tag` (or the
## first man left).
static func strip(p: Play, keep: Array, keeper_in: bool, holder_tag: String = "") -> Swimmer:
	for a in p.attackers.duplicate():
		if not a.tag in keep:
			p.attackers.erase(a)
	p.defenders.clear()
	p.keeper_in = keeper_in
	p.shot_clock = INF     # no shot clock in a drill
	var h: Swimmer = p.attackers[0]
	for a in p.attackers:
		if a.tag == holder_tag:
			h = a
	p.give_ball(h)
	return h

## Puts `s` at `at`, settled there: it's his spot, and he's not swimming anywhere.
static func place(s: Swimmer, at: Vector2) -> void:
	s.pos = at
	s.home = at
	s.target = at
	s.vel = Vector2.ZERO
	s.facing = 1.0

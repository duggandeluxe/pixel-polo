class_name Swimmer
extends RefCounted
## A body in the water during a possession. Positions are metres (see Geo); the AI sets
## `target` and `boost`, step() swims there with a little inertia.

enum Side { US, THEM }

const SNAP_TIME := 0.18     # the throwing arm's follow-through after a release

var side: int = Side.US
var player: PoloPlayer
var keeper := false
var tag := ""               # formation spot: "C", "1".."5", or "GK"
var pos := Vector2.ZERO
var vel := Vector2.ZERO
var target := Vector2.ZERO
var home := Vector2.ZERO    # formation spot
var top_speed := 2.0        # m/s
var boost := 1.0
var accel := 6.0
var mark: Swimmer = null    # defender: the attacker he guards
var facing := 1.0
var anim := 0.0
var arm := 0.0              # 0 = arms down, 1 = ball raised
var dive := 0.0             # keeper lunge for the art: -1 up the screen, +1 down; a field
                            # player's block, his arm up and reaching the same way
var drive_t := 0.0          # attacker: seconds left on a drive to the goal
var drive_goal := Vector2.ZERO
var called := 0.0           # attacker: seconds left of a called drive's burst
var back_off := 0.0         # defender: seconds of giving room after a foul
var guard_on: Swimmer = null   # defender: the man with the ball he's pressing right now...
var guard_t := 0.0             # ...and for how many unbroken seconds (see Play._guard_clock)
var out := false            # excluded: swimming to the re-entry corner
var cside := 0              # the centre's guard: the side of him he's holding (-1, +1; 0 not yet)
var cside_t := 0.0          # ...how long the ball's been on the other side
var cswitch := 0.0          # ...seconds left of going round behind him to the new side
var react := 0.0            # the breakout (Play._start_breakout): seconds before he turns and goes
var snap := 0.0             # seconds left on the throwing arm's follow-through
var pose: KeeperDive = null # a keeper's dive or block, for the art (KeeperDive; the body is at pos)
var grip := 0.0             # the 2 m battle (PlayAI._center_battle), for the art: 0 free .. 1 locked up
var hook := false           # ...the centre with inside water, his arm hooked back round his man
var cdef := -1              # defender: his answer to the man with the ball having inside water on him
                            # (CenterDefense.Act; -1 none: INSIDE_WATER_DEFENSIVE_RECOVERY isn't on)
var cdef_t := 0.0           # ...how long he's been beaten (he needs Difficulty "recognize" to see it)
var cdef_next := 0.0        # ...seconds until he weighs it up again
var cdef_cool := 0.0        # ...seconds until he can go for the ball again
var ai_err := Vector2.ZERO  # defender: how far off his spot he's reading it right now (Difficulty "pos_err")
var pace := 1.0             # share of his top speed he swims at: a defender's Defense (DefenseFormation.move_mult)
var dtag := ""              # defender: the tag of the man he was paired with (his assignment: D1..D5, D6 = "C")
var duty := 0               # defender: his one job this frame in the formation (DefenseFormation.Duty)
var fspot := Vector2.INF    # ...and the spot it gives him (INF: he marks `mark` the normal way)
var press := 0              # a piston's pressure on the man with the ball (DefenseFormation.Press)
var press_t := 0.0          # ...seconds into it (the approach: his reaction, then his arm going up)
var press_on: Swimmer = null   # ...and the man he's going out to
var block_arm := 0.0        # his one blocking arm, for the art and the block: 0 down .. 1 fully up
var block_side := 1.0       # ...which side of him it's on (+1 / -1 across the line to the shooter)
var zlane := -1             # defender, man-down: his lane in the zone (ManDownZone.Lane; -1 none)
var zreach := 0.0           # ...art only: his arm up in the lane, out on the ball's man (0 .. ManDownZone.ARM_UP)
var zreach_on: Swimmer = null   # ...the man it's up against
var zside := 1.0            # ...and which side of him (as block_side)
# a goal's celebration, for the art only (GoalShow sets them; the play never reads them)
var cheer := 0.0            # 1: a fist up out of the water
var cheer_style := ""       # ...or this pose (Celebrations: art only, nothing else reads it)
var hop := 0.0              # px he's bounced up out of the water
var slump := 0.0            # the beaten keeper: 1, arms down

func _init(p: PoloPlayer, s: int, is_keeper: bool = false) -> void:
	player = p
	side = s
	keeper = is_keeper
	top_speed = lerpf(1.7, 2.5, p.speed / 100.0) + (Sprint.JET_BONUS if Traits.has(p, "jet") else 0.0)
	if keeper:
		tag = "GK"

func step(dt: float) -> void:
	var to := target - pos
	var dist := to.length()
	var desired := Vector2.ZERO
	if dist > 0.03:
		desired = to / dist * minf(top_speed * boost * pace, dist * 3.0)
	vel = vel.move_toward(desired, accel * boost * dt)
	pos += vel * dt
	var spd := vel.length()
	anim += dt * (2.0 + spd * 3.0)
	if absf(vel.x) > 0.25:
		facing = signf(vel.x)
	if arm < 0.99:
		arm = move_toward(arm, 0.0, dt * 2.5)
	dive = move_toward(dive, 0.0, dt * (0.6 if keeper else 3.0))
	snap = maxf(0.0, snap - dt)

func speed() -> float:
	return vel.length()

func is_swimming() -> bool:
	return vel.length() > 0.6

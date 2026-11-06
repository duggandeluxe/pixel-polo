extends "res://src/ui/screens/play_lab.gd"
## Developer Mode's DEFENSIVE TESTING (Settings > Developer Mode): the piston pressure, the one-arm
## block and the penalty from behind, in a real possession you play (aim and shoot, tap to pass,
## as in a match). The line along the top follows the piston who's out: his pressure state
## (DefenseFormation.Press), his speed against his full speed, his arm.
##   4-5 PISTON       their 4-5 DROP, the ball to your 5: their D5 comes out of the middle to him
##   3-4 PISTON       their 3-4 DROP, the ball to your 4
##   ONE-ARM BLOCK    the 4-5 run on until his arm's fully up and his hand's in your lane, then held still
##   BLOCK INDICATOR  ...and your aim set straight through his hand: the yellow line stops on it,
##                    the red X. SHOOT throws that very shot (it's blocked, every time)
##   COUNTER PENALTY  a breakaway in the goalie box, the beaten man on his back fouls him: PENALTY!
## RESUME / PAUSE holds the water still (you can still aim), RESET starts the last test again.
## Nothing is counted (play_lab).

const TESTS := [["4-5 PISTON", "45"], ["3-4 PISTON", "34"], ["ONE-ARM BLOCK", "arm"],
	["BLOCK INDICATOR", "aim"], ["COUNTER PENALTY", "pen"]]
const SETTLE := 1.5            # s the defence gets to set up its formation before the ball goes out
const AIM_POWER := 0.7         # BLOCK INDICATOR's pull
const LANE_D := DefenseFormation.FOUL_AT + 0.05   # m: ...still this far off you (not yet on you)
const STEP := 1.0 / 60.0

var last := ""
var pause_btn: Button
var presser: Swimmer = null    # the piston it's about
var verdict := ""              # the counter penalty: what the whistle made of it

func _ready() -> void:
	aims = true
	lab_ready("DEFENSIVE TESTING")
	var row := UI.hbox(3)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	body.add_child(row)
	for tst in TESTS:
		var key: String = tst[1]
		row.add_child(UI.button(tst[0], func(): run(key), "normal", 86, 18))
	var row2 := UI.hbox(3)
	row2.alignment = BoxContainer.ALIGNMENT_CENTER
	body.add_child(row2)
	row2.add_child(UI.button("SHOOT", func(): shoot_aimed(), "ghost", 70, 18))
	pause_btn = UI.button("PAUSE", func():
		paused = not paused
		pause_btn.text = "RESUME" if paused else "PAUSE", "ghost", 70, 18)
	row2.add_child(pause_btn)
	row2.add_child(UI.button("RESET", func():
		if last != "":
			run(last), "ghost", 70, 18))
	settled.call_deferred()

func settled() -> void:
	if last == "":
		new_play()
		paused = true
		status = "PICK A TEST"
	else:
		paused = true
		status = "DONE  (RESET to run it again)"
	if pause_btn != null:
		pause_btn.text = "RESUME"

func _hold(on: bool) -> void:
	paused = on
	pause_btn.text = "RESUME" if on else "PAUSE"

## Test `key`. False: it couldn't be set up (the possession went another way while it settled).
func run(key: String) -> bool:
	last = key
	verdict = ""
	presser = null
	match key:
		"45", "34", "arm", "aim":
			var f := DefenseFormation.F.THREE_FOUR if key == "34" else DefenseFormation.F.FOUR_FIVE
			if not piston(f, "4" if key == "34" else "5"):
				status = "COULDN'T SET IT UP"
				return false
			if key in ["arm", "aim"]:
				var man: Swimmer = play.holder
				if not run_until(func() -> bool: return presser.press == DefenseFormation.Press.BLOCK \
						and not is_nan(play.blocked_aim(AIM_POWER)) and presser.pos.distance_to(man.pos) > LANE_D, 14.0) \
						or play.free_throw:
					status = "HE NEVER GOT HIS ARM UP"
					return false
				_hold(true)
				if key == "aim":
					aim_through_arm()
			else:
				_hold(false)
		"pen":
			counter_penalty()
	return true

## Their `f`, settled, then the ball to your man in their formation's spot `n`: his piston on his
## way out (DefenseFormation.slot: theirs is the computer's, numbered from its own end).
func piston(f: int, n: String) -> bool:
	new_play()
	play.instant_drop(f)
	var tag := DefenseFormation.slot(play, n)
	var a2: Swimmer = DefenseFormation.by_tag(play.attackers, DefenseFormation.slot(play, "2"))   # (not a piston's man in either)
	play.give_ball(a2)
	if not run_until(func() -> bool: return false, SETTLE) and play.over:
		return false
	var a: Swimmer = DefenseFormation.by_tag(play.attackers, tag)
	if play.over or a == null:
		return false
	play.give_ball(a)
	play.free_throw = false   # (a whistle while it set up: this is a new ball, not a free throw)
	play.shot_clock = Play.SHOT_CLOCK
	presser = DefenseFormation.by_tag(play.defenders, tag, true)
	return true

## Runs the play on (not drawn) until `cond` or `secs`; true if `cond` came first.
func run_until(cond: Callable, secs: float) -> bool:
	var left := secs
	while left > 0.0 and not play.over:
		if cond.call():
			return true
		play.step(STEP)
		play.events.clear()
		left -= STEP
	return not play.over and cond.call()

## Your aim, set through his raised hand (as if you'd pulled it there, at AIM_POWER): the guide's red X.
func aim_through_arm() -> void:
	var h := play.holder
	var cy := play.blocked_aim(AIM_POWER) if h != null else NAN
	if is_nan(cy):
		status = "NO AIM AT THE GOAL GOES THROUGH HIS HAND"
		return
	# a pull ending past the line: power is how far past it you pull (AimGuide.power)
	var to := Vector2(Geo.GOAL_X, cy) - h.pos
	var reach := to.length() * (Play.SHOT_ZONE_X - h.pos.x) / to.x
	var len := reach + (AIM_POWER - AimGuide.SHOT_BASE) / (1.0 - AimGuide.SHOT_BASE) * AimGuide.SHOT_EXTRA
	aim.begin(-99, Vector2(view.width * 0.5, view.height * 0.5), true)
	aim.stick_at(h, h.pos + to.normalized() * maxf(len, to.length() + 0.3))

## SHOOT: throws the aimed shot (BLOCK INDICATOR's), exactly as letting go would.
func shoot_aimed() -> void:
	if play == null or not aim.active or not play.can_throw():
		Game.toast("Aim first (BLOCK INDICATOR sets one)", UI.DIM)
		return
	var blocked := not play.arm_block(float(play.aim_info(aim.target(play.holder)).cross_y), aim.power(play.holder)).is_empty()
	play.shoot_at(aim.target(play.holder), aim.power(play.holder))
	aim.cancel()
	_hold(false)
	verdict = "RED X: BLOCKED EVERY TIME" if blocked else "NO RED X"

## A breakaway: your man in the goalie box, straight on, nobody in front of him but the keeper,
## his beaten man right on his back, who fouls him (the whistle's own classification decides it).
func counter_penalty() -> void:
	new_play(Play.Kind.COUNTER, 11)
	var a: Swimmer = play.holder if play.holder != null else play.attackers[0]
	var at := Vector2(26.2, Geo.GOAL_Y + 0.3)
	a.pos = at
	a.vel = Vector2.ZERO
	a.target = at
	play.give_ball(a)
	var d: Swimmer = play._marker(a)
	if d == null:
		d = play.defenders[0]
	d.pos = at - Vector2(0.85, 0.0)
	d.vel = Vector2.ZERO
	d.target = d.pos
	for e in play.defenders:
		if e != d and e.pos.x > at.x - 2.0:
			e.pos.x = at.x - 3.0   # (everybody else trailing the break)
	view.snap_to(view.attack_frame(play))
	var pen := play.penalty_foul(a, d)
	play._ordinary_foul(a, d)
	verdict = "FROM BEHIND, CLEAR CHANCE: %s" % ("PENALTY" if pen else "ORDINARY FOUL")
	_hold(false)

func lab_tick(_dt: float) -> void:
	if presser != null and play != null:
		var full := presser.top_speed * presser.pace
		status = "D%s %s  %.2f m/s (%d%% of full)  ARM %d%%" % [presser.dtag,
			DefenseFormation.PRESS_NAMES[presser.press], presser.speed(), roundi(100.0 * presser.speed() / maxf(full, 0.01)),
			roundi(100.0 * presser.block_arm)]
		if verdict != "":
			status += "   " + verdict
	elif verdict != "":
		status = verdict

## The piston it's about: a ring on him.
func lab_draw(ci: Control) -> void:
	if presser != null and not presser.out:
		PoolArt.draw_ring(ci, view, presser, UI.WARN if presser.press == DefenseFormation.Press.BLOCK else UI.DIM)

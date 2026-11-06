class_name DefenseFormation
## The settled defence's five formations, the same for both teams: PRESS, M-DROP, 5 DROP, 4-5 DROP
## and 3-4 DROP. A formation is only where the defenders swim and what they do when they get there:
## no formation changes a rating, a shot or a pass by itself. Everything here is physical: a
## defender has a spot (or a man), swims to it at his own speed (Swimmer.step, his Defense moving
## it: move_mult), and only once he's actually there can he push (press), foul (contact_defender),
## tip a pass (tip_chance, Play._fly_pass) or take the ball off the centre (interference).
##
## The possession owns the formation (Play.formation): one Play is one defensive possession,
## through fouls, loose balls, rebounds and shot-clock resets, and only a change of possession
## makes a new Play. Each possession starts on PRESS, unlocked; one explicit pick
## (Play.select_formation) locks it for the rest of it. The computer's defence has PRESS and the
## one drop it game-planned (DropCall): it calls the drop when your centre has position on its 2MD,
## and goes back to PRESS when that's over, never locked.
##
## Assignments (by the tag of the man each defender was paired with, Swimmer.dtag):
##   A1..A5 = attackers "1".."5" (the perimeter: "1" right wing .. "3" point .. "5" left wing),
##   A6 = "C" (the centre); D1..D5 guard A1..A5, D6 the centre. Play always attacks x = 30, so
##   the formations read the same at either end of the pool (the screen mirrors their attack).
## A formation's numbers are the defence's own, read with its goal where the screen shows it
## (slot): your defence (`defending`, the pool mirrored, your goal on the left) as the tags go, its
## 4-5 DROP the two men at the top of the pool; the computer's (its goal on the right) turned round,
## so its 4-5 DROP is the two at the bottom, D2 and D1. Nobody's tag changes, only which men a
## formation's numbers are.
##
## It runs only in the settled 6 on 6 (active): counters, the breakout and man-down keep their own
## systems, and the formation takes over again once the attack has set up.
##
## Each defender has one duty a frame (Swimmer.duty), and only one:
##   MARK     man to man on his man (PlayAI._defend's marking, goal side, in the lane)
##   CLOSE    closing out on (then pressing) the man with the ball who isn't normally his
##   SPLIT    halfway between two attackers, goal side, shading to the danger (M-DROP's D2, D4)
##   DROP     in front of the centre, in the entry lane (M-DROP's D3, 5 DROP's D5, a piston)
##   CRASH    the dropper going onto the centre who has the ball (interference)
##   BEHIND   the centre's guard behind him (every drop formation's D6, once its dropper is there)
##   HELP     5 DROP: off his own man onto A5 with the ball
##   RECOVER  swimming back to his assignment (a helper, a piston going back in)
##   PRESSURE a piston going out to his man with the ball, slowly, one arm going up (Press)
##
## Piston pressure (4-5, 3-4 only): the piston whose man has the ball comes out of the middle to
## him at a controlled swim (press_share of his full speed), and after his reaction (arm_delay)
## gets one arm up (ARM_RAISE). Fully up, it's a block: a shot through that hand is stopped, no
## dice (arm_zone, ShotModel's arms). He keeps coming, and when he gets to FOUL_AT in front of the
## man it's a foul, once (piston_contact: Play's one foul classification). Then he swims all the
## way back to his spot in the middle (piston_home, within RETURN_TOL) before he can go again. A
## pass away before then: he lets it go and the formation carries on as it always does.
##   HOLD -> APPROACH -> RAISE -> BLOCK -> FOUL -> RETURN -> HOLD
##   (a pass, the ball gone: APPROACH / RAISE / BLOCK -> HOLD)

enum F { PRESS, M_DROP, FIVE_DROP, FOUR_FIVE, THREE_FOUR }
const NAMES := ["PRESS", "M-DROP", "5 DROP", "4-5 DROP", "3-4 DROP"]
const COUNT := 5
enum Duty { NONE, MARK, CLOSE, SPLIT, DROP, CRASH, BEHIND, HELP, RECOVER, PRESSURE }
const DUTY_NAMES := ["NONE", "MARK", "CLOSE", "SPLIT", "DROP", "CRASH", "BEHIND", "HELP", "RECOVER", "PRESSURE"]
enum Press { HOLD, APPROACH, RAISE, BLOCK, FOUL, RETURN }
const PRESS_NAMES := ["HOLD", "APPROACH", "RAISE", "BLOCK", "FOUL", "RETURN"]

# ------------------------------------------------------------------ tuning (all of it)
## Movement: a defender swims at MOVE_BASE + MOVE_PER_POINT x Defense of his top speed
## (Swimmer.pace: 2 -> 0.91, 5 -> 1.00, 8 -> 1.09, 10 -> 1.15). Only defending; attackers stay 1.
const MOVE_BASE := 0.85
const MOVE_PER_POINT := 0.03
## Physical pressing: the man with the ball's own defender within CONTACT_R of him, not behind
## him, is in contact. Push Advantage = his Defense - the attacker's Strength: each point over 0
## moves the attacker PUSH_PER_POINT m/s straight away from the goal (+6: 0.36 m/s), to at most
## PUSH_MAX from where the contact began and never further than PUSH_FAR from the goal. From
## ADVANCE_FROM (-4) down, the attacker gains water instead (ADVANCE_PER_POINT a point past -3,
## at most ADVANCE_MAX). -3..0: he holds his ground.
const CONTACT_R := 0.95
const CONTACT_KEEP := 0.15     # ...and contact holds until he's this much further off (no flicker)
const PUSH_PER_POINT := 0.06
const PUSH_MAX := 1.5
const PUSH_FAR := 10.5
const ADVANCE_FROM := -4.0
const ADVANCE_PER_POINT := 0.03
const ADVANCE_MAX := 0.5
const ADVANCE_NEAR := 3.0      # ...never in closer than this to the goal
## Ordinary fouls (Play._pressure): only from contact (contact_defender), and only once it's been
## held FOUL_SETTLE s; from then on FOUL_RATE a second (times the Defense vs Strength modifier).
## Contact lost, the clock runs back down FOUL_DECAY times as fast. A catch starts it at 0.
const FOUL_SETTLE := 1.1
const FOUL_RATE := 0.8
const FOUL_DECAY := 2.0
## WING PRESSURE (PRESS and M-DROP, wing_pressure): a wing with the ball is played tight by his own
## man (PlayAI: WING_GAP goal side of him, WING_SWIM_GAP while he swims it, a smaller positioning
## mistake), so a closely guarded wing is in contact; held contact is whistled sooner (WING_SETTLE)
## and more often (WING_FOUL_MULT). Still only from real contact (contact_defender), still his
## Defense against the wing's Strength, still classified like every foul (Play._ordinary_foul): a
## wing with room plays on. M-DROP's dropper and splitters keep their jobs: it's the wing's own man.
const WING_GAP := 0.7
const WING_SWIM_GAP := 1.0
const WING_ERR := 0.3
const WING_SETTLE := 1.1
const WING_FOUL_MULT := 0.7
## M-DROP's splitters: SPLIT_SAG goal side of the line between their two men (so a pass between
## them goes past his reach), shaded up to SPLIT_SHADE towards the more dangerous one and
## SPLIT_BALL towards the one nearer the ball; with his partner closing out on A3 he covers his
## other man's lane, SPLIT_COVER of the way from him.
const SPLIT_SAG := 0.5
const SPLIT_SHADE := 0.2
const SPLIT_BALL := 0.1
const SPLIT_COVER := 0.3
## A splitter out on the ball still has his other man to think of: he contests from SPLIT_CONTEST
## goal side of the shooter, leaning SPLIT_LEAN back towards the other one (a hand up, not on him).
## The longer the man holds it, the tighter he gets: down to pressing distance (PRESS_GAP) over
## SPLIT_TIGHTEN s, after SPLIT_WAIT s.
const SPLIT_CONTEST := 1.4
const SPLIT_LEAN := 0.35
const SPLIT_WAIT := 0.5
const SPLIT_TIGHTEN := 1.5
const PRESS_GAP := 0.85
## Droppers: DROP_FRONT in front of the centre on the line to the ball; established within
## DROP_SET_R of that spot. A dropper within INTERVENE_R of the centre stops the fed centre's
## exclusion; the centre holding a live ball, the dropper goes for him (CRASH) after his
## reaction (CRASH_REACT, less CRASH_REACT_PER_POINT a Defense point over 5), and once he's within
## INTERFERE_R of him with the ball still in his hands, it's a steal.
const DROP_FRONT := 1.3
const DROP_SET_R := 0.8
const INTERVENE_R := 2.4
const INTERFERE_R := 0.75
const CRASH_REACT := 0.3
const CRASH_REACT_PER_POINT := 0.02
const CRASH_BOOST := 1.25
const CENTER_BEHIND := 0.75    # every drop formation's D6, this far behind the centre
## 5 DROP: his man gone, A5 slides straight in along his line to the cage, to ATTACK_R from it (and
## no further than SLIDE_MAX_X: the 2 m line): with the ball, if nobody's within ATTACK_STOP_R of
## him, or waiting for it. It's along the attack's own direction, so it reads the same at
## both ends. From there he can take his look, or call a drive, or D4 can jump him: only D4 (the man
## on the attacker next to him), only if it's worth it (A5's spot good enough, HELP_MIN_Q, and he
## can get there in HELP_MAX_T), only some of the time (JUMP_CHANCE each HELP_EVERY s look while A5
## has it, his Defense moving it), and it leaves A4 open. Back within RECOVERED_R of his own man,
## he's recovered.
const ATTACK_R := 5.0
const SLIDE_MAX_X := 27.9
const SLIDE_DRIVE := 2.4       # a called drive from there goes this much further in
const JUMP_CHANCE := 0.25
const JUMP_PER_POINT := 0.03
const ATTACK_STOP_R := 1.1
const HELP_MAX_T := 2.6
const HELP_MIN_Q := 0.2
const HELP_EVERY := 0.3
const RECOVERED_R := 1.2
## Pistons (4-5, 3-4): who's in (dropped) changes only on a catch, and never sooner than
## PISTON_COMMIT after the last change (no flip-flopping on quick passes). The one who's out
## sags PISTON_SAG of the way from his man towards the centre while his man doesn't have the ball.
const PISTON_COMMIT := 0.35
const PISTON_SAG := 0.55
## Piston pressure: going out he swims PRESS_SHARE of his full speed (+PRESS_SHARE_PER_POINT a
## Defense point over 5, within PRESS_SHARE_RANGE: never a sprint), at a spot PRESS_AIM in front of
## the man. His arm starts up ARM_DELAY after he sets off (less ARM_DELAY_PER_POINT a Defense point
## over 5, within ARM_DELAY_RANGE) and takes ARM_RAISE to get there; ARM_DROP to come down. At
## FOUL_AT from the man: the foul. Back within RETURN_TOL of his spot: he can go again.
const PRESS_SHARE := 0.32
const PRESS_SHARE_PER_POINT := 0.016
const PRESS_SHARE_RANGE := Vector2(0.25, 0.4)
const PRESS_AIM := 0.55
const PRESS_BRAKE := 3.0       # going out, he checks any faster swim this many times his normal accel
const ARM_DELAY := 0.3
const ARM_DELAY_PER_POINT := 0.02
const ARM_DELAY_RANGE := Vector2(0.2, 0.4)
const ARM_RAISE := 0.2
const ARM_DROP := 0.15
const FOUL_AT := 0.9
const RETURN_TOL := 0.3
## The raised arm: his hand ARM_OUT to one side of him (across the line to the shooter, the side
## the shooter's line to the goal goes by him), a ball within ARM_R of it is his.
const ARM_OUT := 0.3
const ARM_R := 0.28
## Passing deflections (Play._fly_pass): a field defender whose reach (TIP_REACH) the ball's
## actual path crosses gets one go per pass: TIP_BASE + TIP_PER_DEF x Defense - TIP_PER_PASS x
## (Passing - 5), clamped to TIP_RANGE, less towards the edge of his reach (Play.INTERCEPT_EDGE).
## (A ball into the centre through a dropper is Play._drop_entry_plan's.) A tip that comes off is
## TIP_OUTCOMES: a minor deflection, a major one, or a clean interception.
const TIP_REACH := 0.55
const TIP_BASE := 0.02
const TIP_PER_DEF := 0.015
const TIP_PER_PASS := 0.01
const TIP_RANGE := Vector2(0.01, 0.3)
enum Tip { MINOR, MAJOR, CLEAN }
const TIP_OUTCOMES := [0.75, 0.20, 0.05]
const MINOR_TURN := Vector2(20.0, 50.0)    # degrees off its line...
const MINOR_SPEED := Vector2(1.6, 2.6)     # ...m/s on the water (Play._loose slows it 3 m/s/s: 0.4-1.1 m)
const MAJOR_TURN := Vector2(50.0, 140.0)
const MAJOR_SPEED := Vector2(3.8, 5.4)     # (2.4-4.9 m: a race for it)
const TIP_SKIP := 0.12                     # nobody gathers it this soon (you see it come off his hand)
## Centre entries (Play._entry_stolen, _roll_center_foul): fronted by his guard, it's his hands on
## it every time, but FRONT_LOOSE of them knocked loose rather than caught; "straight" (his guard
## beside him, a poor ball) is caught, and POOR_FOUL of the time his man fouls him as he turns
## (an ordinary foul: no shot from it).
const FRONT_LOOSE := 0.25
const POOR_FOUL := 0.55

# ------------------------------------------------------------------ movement
## A defender's Defense, 0-10 (a pro's relative to his level, Attributes.play_value).
static func defense(p: PoloPlayer) -> float:
	if p == null or p.is_keeper():
		return 5.0
	return Attributes.play_value(p, "dfn")

## His Defense with his keeper's organising (`comm`), up to 10 as it always was, then his Hot
## Stars on top (Attributes.hot_bonus: past 10 if they take him there).
static func hot_capped(d: PoloPlayer, comm: float) -> float:
	if d == null or d.is_keeper():
		return clampf(5.0 + comm, 0.0, Attributes.MAX)
	return clampf(defense(d) - Attributes.hot_bonus(d) + comm, 0.0, Attributes.MAX) + Attributes.hot_bonus(d)

static func passing(p: PoloPlayer) -> float:
	if p == null or p.is_keeper():
		return 5.0
	return Attributes.play_value(p, "pas")

static func shooting(p: PoloPlayer) -> float:
	if p == null or p.is_keeper():
		return 5.0
	return Attributes.play_value(p, "sho")

## Defensive movement multiplier (Swimmer.pace), applied once, to his top speed only.
static func move_mult(p: PoloPlayer) -> float:
	return MOVE_BASE + MOVE_PER_POINT * defense(p)

# ------------------------------------------------------------------ state
## Is the formation running: the settled 6 on 6, with the ball live.
static func active(p: Play) -> bool:
	return not p.over and not p.breakout and not p.carry and p.counter_t <= 0.0 and p.man_up <= 0.0 \
		and p.kind != Play.Kind.PENALTY and not p.shootout and p.defenders.size() == 6 and p.attackers.size() == 6

## The wing pressure applies: `a`, a wing ("1" or "5"), against PRESS or M-DROP, the set defence on.
static var wing_boost := true   # (off: the old perimeter defence, for measuring the difference: tests, the lab)
static func wing_pressure(p: Play, a: Swimmer) -> bool:
	return wing_boost and a != null and a.tag in ["1", "5"] and p.formation in [F.PRESS, F.M_DROP] and active(p)

## A formation that puts a man in front of the centre (and his guard behind him).
static func drops(f: int) -> bool:
	return f != F.PRESS

## The centre's guard plays behind him (a drop formation, running, its dropper there): the 2 m
## battle holds still.
static func center_behind(p: Play) -> bool:
	if not drops(p.formation) or not active(p):
		return false
	var g := by_tag(p.defenders, "C", true)
	return g != null and g.duty == Duty.BEHIND

static func valid(f: int) -> bool:
	return f >= 0 and f < COUNT

# ------------------------------------------------------------------ your gameplan (Coaching)
## The four drops a coach can game-plan, in Coaching's order. PRESS isn't one of them: it's
## always on the bar. Your bar in a match is PRESS and one of these (MatchFlow.user_formations);
## the computer's is PRESS and the one it game-planned the same way (DropCall).
const DROPS := [F.M_DROP, F.FOUR_FIVE, F.FIVE_DROP, F.THREE_FOUR]
const DEFAULT_DROP := F.M_DROP     # a new career's, and an older save's
## What each drop is for, in words (Coaching and the halftime adjustment). Words only: the
## formations themselves are the code above, unchanged by any of this.
const DROP_TEXT := {
	F.M_DROP: "D3 collapses onto the center while the remaining perimeter defenders split to protect shooting lanes.",
	F.FOUR_FIVE: "A defender drops from the 4-5 side to provide additional center protection while the remaining defenders maintain perimeter coverage.",
	F.FIVE_DROP: "The defender in the 5 position drops toward the center to provide additional defensive support.",
	F.THREE_FOUR: "A defender drops from the 3-4 side to provide additional center protection while the remaining defenders adjust their positioning.",
}

static func is_drop(f: int) -> bool:
	return f in DROPS

static func by_tag(list: Array[Swimmer], tag: String, d_side := false) -> Swimmer:
	for s in list:
		if (s.dtag if d_side else s.tag) == tag:
			return s
	return null

## The ball's man with it, if one of the attack has it.
static func _ball_man(p: Play) -> Swimmer:
	if p.ball.state == Ball.State.HELD and p.holder != null and p.attackers.has(p.holder):
		return p.holder
	return null

## The ball, as the defence reads it: where a pass is going, else where it is.
static func ball_focus(p: Play) -> Vector2:
	return p.ball.to if p.ball.state == Ball.State.PASS else p.ball.pos

## Formation spot `n` ("1".."5", "C") of this defence: the tag of the attacker it's on, D`n` the
## man guarding him. Your defence: `n`. The computer's: across the pool (TURNED), the same spot
## seen from its own end (see the top).
const TURNED := {"1": "5", "2": "4", "3": "3", "4": "2", "5": "1", "C": "C"}
static func slot(p: Play, n: String) -> String:
	return n if p.defending else String(TURNED[n])

## The two pistons of this defence's formation, [first, second] by tag (pistons, slot).
static func piston_tags(p: Play) -> Array:
	return pistons(p.formation).map(func(n: String) -> String: return slot(p, n))

## The two pistons of a piston formation, [first, second] by spot, the second dropped by default.
static func pistons(f: int) -> Array:
	match f:
		F.FOUR_FIVE:
			return ["4", "5"]
		F.THREE_FOUR:
			return ["3", "4"]
	return []

## One frame (PlayAI._defend, before anybody moves): who does what. Sets every defender's duty,
## mark (who he's guarding right now: null for a dropper or a splitter) and fspot (his spot, or
## INF: mark his man with the normal marking).
static func update(p: Play, dt: float) -> void:
	if not active(p):
		if p.f_active:
			p.f_active = false
			p.f_holder = null
			p.f_closer = null
			p.f_helper = null
			p.f_recover = null
			p.f_dropper = null
		for d in p.defenders:
			d.duty = Duty.NONE
			d.fspot = Vector2.INF
			_press_reset(d, dt)
		return
	if not p.f_active:
		p.f_active = true
		p.f_holder = null
		p.f_commit = 0.0
		var pair := piston_tags(p)
		p.f_in = by_tag(p.defenders, pair[1], true) if not pair.is_empty() else null
		p.f_want_in = p.f_in
	p.f_commit = maxf(0.0, p.f_commit - dt)
	var h := _ball_man(p)
	if h != p.f_holder:
		_new_holder(p, p.f_holder, h)
		p.f_holder = h
	p.f_crash_t = p.f_crash_t + dt if h != null and h.tag == "C" else 0.0
	p.f_hold_t = p.f_hold_t + dt if h != null else 0.0
	var a := {}
	var d := {}
	for s in p.attackers:
		a[s.tag] = s
	for s in p.defenders:
		d[s.dtag] = s
		s.fspot = Vector2.INF
	for t in d:
		# PRESS is the man-to-man pairing as it stands (whatever's had to reshuffle it); a drop
		# formation hands out its own jobs from each man's assignment
		_assign(d[t], Duty.MARK, d[t].mark if p.formation == F.PRESS else a.get(t))
	p.f_dropper = null
	match p.formation:
		F.M_DROP:
			_m_drop(p, a, d, h)
		F.FIVE_DROP:
			_five_drop(p, a, d, h, dt)
		F.FOUR_FIVE, F.THREE_FOUR:
			_piston(p, a, d, h)
	if drops(p.formation):
		var c: Swimmer = a["C"]
		# the centre's own man goes behind him once there's a dropper there to front him; until
		# then (the swim-in, a piston on his way back) he fronts him as in PRESS, on his own
		var dr := p.f_dropper
		if dr != null and not dr.out and dr.pos.distance_to(c.pos) <= INTERVENE_R:
			_assign(d["C"], Duty.BEHIND, c, c.pos + PlayAI.behind_dir(c, ball_focus(p)) * CENTER_BEHIND)
		if dr != null:
			_dropper(p, dr, c, h)
	# a piston whose man has the ball goes out to him, slowly, and comes all the way back (Press)
	var pp := piston_tags(p)
	for s in p.defenders:
		if pp.has(s.dtag):
			_press_step(p, s, a.get(s.dtag), h, dt)
		else:
			_press_reset(s, dt)
	# the man with the ball: the defender on him is pressing him (CLOSE) if he isn't normally his
	for s in p.defenders:
		if h != null and s.mark == h and s.duty == Duty.MARK and s.dtag != h.tag:
			s.duty = Duty.CLOSE

static func _assign(d: Swimmer, duty: int, mark: Swimmer, spot := Vector2.INF) -> void:
	if d == null:
		return
	d.duty = duty
	d.mark = mark
	d.fspot = spot

## The ball's found a new man (or left the last one: `h` null). Decisions are only made here, on
## the catch, never every frame: who closes out, who helps, which piston goes.
static func _new_holder(p: Play, was: Swimmer, h: Swimmer) -> void:
	match p.formation:
		F.M_DROP:
			p.f_closer = null
			if h != null and h.tag == "3":
				p.f_closer = _quicker(p, [by_tag(p.defenders, "2", true), by_tag(p.defenders, "4", true)], h)
		F.FIVE_DROP:
			if was != null and was.tag == slot(p, "5") and p.f_helper != null:
				p.f_recover = p.f_helper   # the ball's gone: back to his own man, the long way
				p.f_helper = null
			p.f_help_t = 0.0
		F.FOUR_FIVE, F.THREE_FOUR:
			var pair := piston_tags(p)
			if h != null and h.tag in pair:
				var other: String = pair[1] if h.tag == pair[0] else pair[0]
				p.f_want_in = by_tag(p.defenders, other, true)

## Of `ds`, the one who'd get to `m` first (his own speed, from where he actually is).
static func _quicker(p: Play, ds: Array, m: Swimmer) -> Swimmer:
	var best: Swimmer = null
	var bt := INF
	for d: Swimmer in ds:
		if d == null or d.out:
			continue
		var t := closeout_time(d, m)
		if t < bt:
			bt = t
			best = d
	return best

## Seconds for `d` to get into contact with `m` swimming flat out from where he is.
static func closeout_time(d: Swimmer, m: Swimmer) -> float:
	var spot := m.pos + (Geo.goal_center() - m.pos).normalized() * 0.9
	return maxf(0.0, d.pos.distance_to(spot) - 0.2) / maxf(0.1, d.top_speed * 1.2 * move_mult(d.player))

# ------------------------------------------------------------------ the formations
static func _m_drop(p: Play, a: Dictionary, d: Dictionary, h: Swimmer) -> void:
	var dr: Swimmer = d["3"]
	p.f_dropper = dr
	_assign(dr, Duty.DROP, null)
	var closer := p.f_closer if h != null and h.tag == "3" else null
	for pair in [["2", "2", "3"], ["4", "4", "3"]]:
		var s: Swimmer = d[pair[0]]
		var own: Swimmer = a[pair[1]]
		var mid: Swimmer = a[pair[2]]
		if h == own:
			_assign(s, Duty.MARK, own, contest_spot(p, own, mid))   # his own man has it: out to him
		elif closer == s:
			_assign(s, Duty.CLOSE, mid, contest_spot(p, mid, own))  # A3 has it and he's the one who can get there
		elif closer != null:
			_assign(s, Duty.SPLIT, null, split_spot(p, own, mid, own))   # his partner's gone: he covers the lane
		else:
			_assign(s, Duty.SPLIT, null, split_spot(p, own, mid))

static func _five_drop(p: Play, a: Dictionary, d: Dictionary, h: Swimmer, dt: float) -> void:
	var five := slot(p, "5")
	var dr: Swimmer = d[five]
	p.f_dropper = dr
	_assign(dr, Duty.DROP, null)
	var a5: Swimmer = a[five]
	if h == a5 and p.f_helper == null:
		p.f_help_t -= dt
		if p.f_help_t <= 0.0:
			p.f_help_t = HELP_EVERY
			p.f_helper = pick_helper(p, a5)
			if p.f_helper != null:
				p.events.append({"k": "help", "by": p.f_helper.player})
	if p.f_helper != null and (h != a5 or p.f_helper.out):
		p.f_recover = p.f_helper
		p.f_helper = null
	if p.f_helper != null:
		_assign(p.f_helper, Duty.HELP, a5)
		if p.f_recover == p.f_helper:
			p.f_recover = null
	if p.f_recover != null:
		var r := p.f_recover
		var own: Swimmer = a.get(r.dtag)
		if own == null or r.pos.distance_to(own.pos + (Geo.goal_center() - own.pos).normalized() * 1.1) < RECOVERED_R:
			p.f_recover = null
		else:
			_assign(r, Duty.RECOVER, own)

## 5 DROP: does D4 jump A5 (`a5`, with the ball) this look? Null: not this time, and A5 keeps his look.
static func pick_helper(p: Play, a5: Swimmer) -> Swimmer:
	if OffenseAI.spot_quality(a5.pos) < HELP_MIN_Q and p.close_chance(a5) <= 0.0:
		return null
	var four := by_tag(p.defenders, slot(p, "4"), true)
	if four == null or four.out or closeout_time(four, a5) >= HELP_MAX_T:
		return null
	var chance := clampf(JUMP_CHANCE + JUMP_PER_POINT * (defense(four.player) - 5.0), 0.05, 0.6)
	return four if p.ai_rng.randf() < chance else null

static func _piston(p: Play, a: Dictionary, d: Dictionary, h: Swimmer) -> void:
	if p.f_want_in != p.f_in and p.f_commit <= 0.0:
		p.f_in = p.f_want_in
		p.f_commit = PISTON_COMMIT
		p.events.append({"k": "piston", "in": p.f_in.dtag if p.f_in != null else ""})
	var dr := p.f_in
	if dr == null or dr.out:
		return
	p.f_dropper = dr
	_assign(dr, Duty.DROP, null)
	var c: Swimmer = a["C"]
	for t in piston_tags(p):
		var s: Swimmer = d[t]
		var m: Swimmer = a[t]
		if s != dr and h != m:
			# out, but his man hasn't got it: off him, inside, ready to go either way
			var man := m.pos + (Geo.goal_center() - m.pos).normalized() * 1.1
			_assign(s, Duty.MARK, m, man.lerp(drop_spot(p, c), PISTON_SAG))

# ------------------------------------------------------------------ piston pressure
## How fast he goes out: a share of his full speed (Swimmer.boost, on top of his pace).
static func press_share(p: PoloPlayer) -> float:
	return clampf(PRESS_SHARE + PRESS_SHARE_PER_POINT * (defense(p) - 5.0), PRESS_SHARE_RANGE.x, PRESS_SHARE_RANGE.y)

## Seconds from setting off before his arm starts up.
## `k`: the CPU's difficulty (Play.arm_k: Difficulty.cpu_arm_delay), on top of his Defense.
static func arm_delay(p: PoloPlayer, k: float = 1.0) -> float:
	return clampf(ARM_DELAY - ARM_DELAY_PER_POINT * (defense(p) - 5.0), ARM_DELAY_RANGE.x, ARM_DELAY_RANGE.y) * k

## Going out to the man with the ball (or coming back from him): his movement is the pressure's
## own (PlayAI._defend leaves it alone).
static func pressing(s: Swimmer) -> bool:
	return s.press in [Press.APPROACH, Press.RAISE, Press.BLOCK, Press.RETURN] and s.duty in [Duty.PRESSURE, Duty.RECOVER]

## His spot in the middle: in front of the centre if he's the one dropped in, else his piston spot,
## inside his man (as _piston gives it him), whatever the formation's made of it since he went out.
static func piston_home(p: Play, s: Swimmer, m: Swimmer) -> Vector2:
	var c := by_tag(p.attackers, "C")
	var spot := drop_spot(p, c) if c != null else Geo.goal_center()
	if s == p.f_in or m == null:
		return spot
	var man := m.pos + (Geo.goal_center() - m.pos).normalized() * 1.1
	return man.lerp(spot, PISTON_SAG)

## The man he's pressing still has it (or it's his shot, still in the air).
static func _still_on(p: Play, m: Swimmer) -> bool:
	if m == null or p.over:
		return false
	if p.ball.state == Ball.State.SHOT:
		return p.ball.shooter == m
	return _ball_man(p) == m

## Which side of him the arm goes up: the side the shooter's line to the goal passes him.
static func arm_side(s: Swimmer, shooter: Vector2) -> float:
	var n := (shooter - s.pos).orthogonal()
	if n.length() < 0.01:
		return 1.0
	var goal := Geo.goal_center()
	var seg := goal - shooter
	var u := clampf((s.pos - shooter).dot(seg) / maxf(seg.length_squared(), 0.01), 0.0, 1.0)
	var side := signf((shooter + seg * u - s.pos).dot(n))
	if side == 0.0:
		side = signf(seg.dot(n))
	return side if side != 0.0 else 1.0

## One piston, one frame: his pressure state, his arm, and (out or on his way back) his spot.
static func _press_step(p: Play, s: Swimmer, m: Swimmer, h: Swimmer, dt: float) -> void:
	if s == null or s.out or m == null:
		_press_reset(s, dt)
		return
	var live := p.freeze <= 0.0 and not p.over
	match s.press:
		Press.HOLD:
			if h == m and s != p.f_in and live:
				s.press = Press.APPROACH
				s.press_t = 0.0
				s.press_on = m
		Press.APPROACH, Press.RAISE, Press.BLOCK:
			if not _still_on(p, s.press_on):
				s.press = Press.HOLD   # passed (or lost): he lets it go, the formation carries on
				s.press_on = null
			elif live:
				s.press_t += dt
				var delay := arm_delay(s.player, p.arm_k())
				if s.press_t >= delay + ARM_RAISE:
					s.press = Press.BLOCK
				elif s.press_t >= delay and s.press == Press.APPROACH:
					s.press = Press.RAISE
					s.block_side = arm_side(s, s.press_on.pos)
		Press.FOUL:
			s.press = Press.RETURN   # (piston_contact whistled it: straight back)
		Press.RETURN:
			if s.pos.distance_to(piston_home(p, s, m)) <= RETURN_TOL:
				s.press = Press.HOLD   # back in the middle: he can go again
				s.press_on = null
	match s.press:
		Press.RAISE:
			s.block_arm = clampf((s.press_t - arm_delay(s.player, p.arm_k())) / ARM_RAISE, 0.0, 1.0)
		Press.BLOCK:
			s.block_arm = 1.0
		_:
			s.block_arm = move_toward(s.block_arm, 0.0, dt / ARM_DROP)
	match s.press:
		Press.APPROACH, Press.RAISE, Press.BLOCK:
			var on := s.press_on
			_assign(s, Duty.PRESSURE, on, Geo.clamp_in_pool(on.pos + (Geo.goal_center() - on.pos).normalized() * PRESS_AIM))
		Press.RETURN:
			_assign(s, Duty.RECOVER, m, piston_home(p, s, m))

static func _press_reset(s: Swimmer, dt: float) -> void:
	if s == null:
		return
	s.press = Press.HOLD
	s.press_on = null
	s.press_t = 0.0
	s.block_arm = move_toward(s.block_arm, 0.0, dt / ARM_DROP)

## His raised arm as a block for a shot: {i, hand, r, ready (s until it's fully up)}, or {} (no arm
## up, or not going up). Only a piston's: RAISE (on its way, `ready` > 0) or BLOCK.
static func arm_zone(s: Swimmer, i: int = -1, k: float = 1.0) -> Dictionary:
	if s == null or s.out or s.press_on == null or not (s.press in [Press.RAISE, Press.BLOCK]):
		return {}
	var n := (s.press_on.pos - s.pos).orthogonal()
	n = n.normalized() if n.length() > 0.01 else Vector2.DOWN
	var ready := 0.0 if s.press == Press.BLOCK else maxf(0.0, arm_delay(s.player, k) + ARM_RAISE - s.press_t)
	return {"i": i, "hand": s.pos + n * ARM_OUT * s.block_side, "r": ARM_R, "ready": ready}

## The contact (Play.step, live, the ball in his man's hands): a piston out on him who's got to
## FOUL_AT is whistled, once, by the one classification every foul goes through (Play._ordinary_foul:
## from behind on a clear chance, a penalty), and goes back. True if it went.
static func piston_contact(p: Play) -> bool:
	if pistons(p.formation).is_empty() or not active(p) or p.freeze > 0.0 or p.over or p.restart:
		return false
	var h := _ball_man(p)
	if h == null:
		return false
	for s in p.defenders:
		if s.out or s.press_on != h or not (s.press in [Press.APPROACH, Press.RAISE, Press.BLOCK]):
			continue
		if s.pos.distance_to(h.pos) > FOUL_AT:
			continue
		s.press = Press.FOUL
		p.events.append({"k": "piston_foul", "by": s.player, "tag": s.dtag})
		p._ordinary_foul(h, s)
		return true
	return false

## The dropper's duty this frame: in front of the centre (DROP, or RECOVER while he's still on
## his way there), going onto the centre once he has the ball and the dropper's seen it (CRASH).
static func _dropper(p: Play, dr: Swimmer, c: Swimmer, h: Swimmer) -> void:
	var spot := drop_spot(p, c)
	if h == c and p.f_crash_t >= crash_react(dr):
		_assign(dr, Duty.CRASH, null, c.pos)
		return
	_assign(dr, Duty.DROP if dr.pos.distance_to(spot) <= DROP_SET_R else Duty.RECOVER, null, spot)

## In front of the centre `c`: DROP_FRONT out towards the ball, in the lane of the entry.
static func drop_spot(p: Play, c: Swimmer) -> Vector2:
	var b := ball_focus(p)
	var dir := (b - c.pos).normalized() if b.distance_to(c.pos) > 0.3 else Vector2.LEFT
	return Geo.clamp_in_pool(c.pos + dir * DROP_FRONT)

## How long the dropper takes to see the centre has it and go (his Defense: quicker).
static func crash_react(dr: Swimmer) -> float:
	return clampf(CRASH_REACT - (defense(dr.player) - 5.0) * CRASH_REACT_PER_POINT, 0.15, 0.45)

## Halfway between `a1` and `a2` (`cover`: he's covering `cover`'s lane, his partner on the other),
## shaded towards the bigger threat (the better look, the better shooter) and the man nearer the
## ball, SPLIT_SAG goal side of the line between them. Only what he can see: where they are now.
static func split_spot(p: Play, a1: Swimmer, a2: Swimmer, cover: Swimmer = null) -> Vector2:
	var w := 0.5
	if cover != null:
		w = SPLIT_COVER if cover == a1 else 1.0 - SPLIT_COVER
	else:
		w += clampf((danger(a2) - danger(a1)) * 2.0, -1.0, 1.0) * SPLIT_SHADE
		var b := ball_focus(p)
		w += SPLIT_BALL * (1.0 if a2.pos.distance_to(b) < a1.pos.distance_to(b) else -1.0)
	var mid := a1.pos.lerp(a2.pos, clampf(w, 0.15, 0.85))
	return Geo.clamp_in_pool(mid + (Geo.goal_center() - mid).normalized() * SPLIT_SAG)

## A splitter's spot on the man with the ball `m`, with `other` still his to cover: a hand up,
## tightening onto him the longer he holds it.
static func contest_spot(p: Play, m: Swimmer, other: Swimmer) -> Vector2:
	var k := clampf((p.f_hold_t - SPLIT_WAIT) / SPLIT_TIGHTEN, 0.0, 1.0)
	var spot := m.pos + (Geo.goal_center() - m.pos).normalized() * lerpf(SPLIT_CONTEST, PRESS_GAP, k)
	return Geo.clamp_in_pool(spot + (other.pos - spot).normalized() * SPLIT_LEAN * (1.0 - k))

## How dangerous `a` is where he is, 0..1: the look from there and his Shooting.
static func danger(a: Swimmer) -> float:
	return OffenseAI.spot_quality(a.pos) * (0.6 + 0.08 * shooting(a.player))

# ------------------------------------------------------------------ who's where (for the rest)
## The dropper in front of the centre, there or about (within INTERVENE_R): he can still get to a
## catch, so no exclusion.
static func dropper_near(p: Play, c: Swimmer) -> bool:
	var dr := p.f_dropper
	return active(p) and dr != null and not dr.out and c != null and dr.pos.distance_to(c.pos) <= INTERVENE_R

## ...and established on his spot, in the lane (the attack's read: no entry through him).
static func dropper_set(p: Play, c: Swimmer) -> bool:
	var dr := p.f_dropper
	return dropper_near(p, c) and dr.duty in [Duty.DROP, Duty.CRASH]

## The attack's read of a ball into the centre `c`: the dropper's there, or he's visibly on his way
## back and will be in front of him within ENTRY_ETA (no gap to feed through).
const ENTRY_ETA := 0.6
static func entry_covered(p: Play, c: Swimmer) -> bool:
	if dropper_near(p, c):
		return true
	var dr := p.f_dropper
	if not active(p) or dr == null or dr.out or c == null:
		return false
	var eta := maxf(0.0, dr.pos.distance_to(drop_spot(p, c)) - DROP_SET_R) / maxf(0.1, dr.top_speed * 1.2 * move_mult(dr.player))
	return eta < ENTRY_ETA

static func is_dropper(p: Play, d: Swimmer) -> bool:
	return active(p) and d != null and d == p.f_dropper and d.duty in [Duty.DROP, Duty.CRASH, Duty.RECOVER]

## Seconds the centre `c` (with the ball) has before the dropper is on him:
## max(0, (distance - INTERFERE_R) / closing speed), plus whatever's left of his reaction.
static func center_time(p: Play, c: Swimmer) -> float:
	var dr := p.f_dropper
	if not active(p) or dr == null or dr.out or c == null:
		return INF
	var react := maxf(0.0, crash_react(dr) - p.f_crash_t) if p.holder == c else crash_react(dr)
	return react + maxf(0.0, dr.pos.distance_to(c.pos) - INTERFERE_R) / maxf(0.1, dr.top_speed * CRASH_BOOST * move_mult(dr.player))

## `a`'s own defender is off him on another job in a drop formation (helping, splitting, dropped),
## or still on his way back to him (further off than OPEN_FROM): he's open, for now. (PRESS leaves
## nobody on purpose: its gaps are the old ones, read the old way.)
const OPEN_FROM := 2.0
static func left_open(p: Play, a: Swimmer) -> bool:
	if not active(p) or a.tag == "C" or not drops(p.formation):
		return false
	var own := by_tag(p.defenders, a.tag, true)
	return own != null and (own.mark != a or own.pos.distance_to(a.pos) > OPEN_FROM)

# ------------------------------------------------------------------ the physical part (Play.step)
## The man with the ball's own defender, close enough to be in contact and not behind him (the
## centre's man on his back counts: that's where he wrestles him from); null: no contact.
static func contact_defender(p: Play, a: Swimmer) -> Swimmer:
	if a == null or p.kind == Play.Kind.PENALTY:
		return null
	var best: Swimmer = null
	var bd := CONTACT_R + (CONTACT_KEEP if p.push_by != null and p.push_on == a else 0.0)
	for d in p.defenders:
		if d.out or (d.mark != a and d != p.push_by):
			continue
		if a.tag != "C" and PlayDefense.side_of(d, a) == PlayDefense.Zone.BEHIND:
			continue
		var dd := d.pos.distance_to(a.pos)
		if dd < bd:
			bd = dd
			best = d
	return best

## Push Advantage: the defender's Defense against the attacker's Strength.
static func push_advantage(d: Swimmer, a: Swimmer) -> float:
	return defense(d.player) - Attributes.strength(a.player)

## m/s the attacker is moved away from the goal at `adv` (negative: he gains water).
static func push_speed(adv: float) -> float:
	if adv > 0.0:
		return PUSH_PER_POINT * adv
	if adv <= ADVANCE_FROM:
		return -ADVANCE_PER_POINT * (-adv - 3.0)
	return 0.0

## The press, one live frame (only with the ball held: Play.step skips whistles and dead balls).
## The defender in contact with the man with the ball (a perimeter man, not on the break or
## driving) shoves him gradually straight away from the goal, both of them moving together, by
## push_speed x dt (the same over a second at any frame rate), within PUSH_MAX of where it began
## and PUSH_FAR of the goal. Contact gone, the ball gone, a whistle: it stops.
static func press(p: Play, dt: float) -> void:
	var a := _ball_man(p)
	var ok := a != null and a.tag != "C" and not p.carry and p.kind != Play.Kind.PENALTY and a.drive_t <= 0.0 \
		and p.freeze <= 0.0 and not p.over
	var d := contact_defender(p, a) if ok else null
	if d == null:
		end_push(p)
		return
	if p.push_by != d or p.push_on != a:
		p.push_by = d
		p.push_on = a
		p.push_from = a.pos
		p.push_t = 0.0
	p.push_t += dt
	var goal := Geo.goal_center()
	var away := (a.pos - goal).normalized()
	var v := push_speed(push_advantage(d, a))
	var moved := (a.pos - p.push_from).dot(away)
	var step := v * dt
	if v > 0.0:
		step = minf(step, maxf(0.0, minf(PUSH_MAX - moved, PUSH_FAR - a.pos.distance_to(goal))))
	elif v < 0.0:
		step = maxf(step, -maxf(0.0, minf(ADVANCE_MAX + moved, a.pos.distance_to(goal) - ADVANCE_NEAR)))
	if absf(step) < 1e-6:
		return
	var delta := away * step
	var na := Geo.clamp_in_pool(a.pos + delta)
	delta = na - a.pos
	a.pos = na
	d.pos = Geo.clamp_in_pool(d.pos + delta)

static func end_push(p: Play) -> void:
	p.push_by = null
	p.push_on = null
	p.push_t = 0.0

## The dropper's interference (Play.step, live): the centre still holding the live ball when
## the dropper physically gets to him is stripped of it, the dropper's steal. Nothing for a ball
## already gone (a shot, a pass), or play already stopped.
static func interference(p: Play) -> bool:
	var c := _ball_man(p)
	if c == null or c.tag != "C" or not active(p) or p.freeze > 0.0 or p.restart:
		return false
	var dr := p.f_dropper
	if dr == null or dr.out or dr.duty != Duty.CRASH or dr.pos.distance_to(c.pos) > INTERFERE_R:
		return false
	p._turnover(dr, "STOLEN!", "steal")
	return true

# ------------------------------------------------------------------ passes
## The chance `d` gets a hand to a pass thrown by `passer` that goes right through his reach.
static func tip_chance(d: PoloPlayer, passer: PoloPlayer, comm: float = 0.0, playmaker := false) -> float:
	var pas := passing(passer) + (1.5 if playmaker else 0.0)
	var def := hot_capped(d, comm)
	return clampf(TIP_BASE + TIP_PER_DEF * def - TIP_PER_PASS * (pas - 5.0), TIP_RANGE.x, TIP_RANGE.y)

static func tip_outcome(rng: RandomNumberGenerator) -> int:
	var r := rng.randf()
	if r < TIP_OUTCOMES[0]:
		return Tip.MINOR
	if r < TIP_OUTCOMES[0] + TIP_OUTCOMES[1]:
		return Tip.MAJOR
	return Tip.CLEAN

## Where a tipped pass goes (its drift on the water, Play._loose): turned off its line, slowly
## (MINOR: it's there to be had) or hard (MAJOR: a race).
static func deflect_drift(dir: Vector2, major: bool, rng: RandomNumberGenerator) -> Vector2:
	var turn: Vector2 = MAJOR_TURN if major else MINOR_TURN
	var speed: Vector2 = MAJOR_SPEED if major else MINOR_SPEED
	var ang := deg_to_rad(rng.randf_range(turn.x, turn.y)) * (1.0 if rng.randf() < 0.5 else -1.0)
	var base := dir if dir.length() > 0.01 else Vector2.LEFT
	return base.normalized().rotated(ang) * rng.randf_range(speed.x, speed.y)

# ------------------------------------------------------------------ the attack's reads
## The man a 5 DROP has left open, while it's on: he slides in. Null otherwise.
static func slide_man(p: Play) -> Swimmer:
	if p.formation != F.FIVE_DROP or not active(p):
		return null
	return by_tag(p.attackers, slot(p, "5"))

## 5 DROP: A5 with the ball and nobody on him keeps sliding in; INF when he shouldn't (anything
## else, or he's there, or he's up to shoot: your pull).
static func open_attack(p: Play, a: Swimmer) -> Vector2:
	if a != slide_man(p) or a != _ball_man(p) or p.raised:
		return Vector2.INF
	for d in p.defenders:
		if not d.out and d.pos.distance_to(a.pos) < ATTACK_STOP_R:
			return Vector2.INF
	var to := attack_point(a.home)
	if a.pos.distance_to(to) < 0.3 or a.pos.distance_to(Geo.goal_center()) <= ATTACK_R + 0.1:
		return Vector2.INF
	return to

## Where A5 goes without the ball (INF: he isn't the man, or he's on a drive).
static func slide_spot(p: Play, a: Swimmer) -> Vector2:
	if a != slide_man(p) or a.drive_t > 0.0:
		return Vector2.INF
	return attack_point(a.home)

## A called drive from the slide: straight on at the cage.
static func slide_drive(a: Swimmer) -> Vector2:
	var to := a.pos + (Geo.goal_center() - a.pos).normalized() * SLIDE_DRIVE
	to.x = minf(to.x, SLIDE_MAX_X)
	return to

## ATTACK_R from the goal, straight in from `from`: along his line to the cage, wherever he
## started, never past the 2 m line.
static func attack_point(from: Vector2) -> Vector2:
	var to := Geo.goal_center() + (from - Geo.goal_center()).normalized() * ATTACK_R
	to.x = minf(to.x, SLIDE_MAX_X)
	return to


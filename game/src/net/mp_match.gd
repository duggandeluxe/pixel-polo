class_name MpMatch
extends RefCounted
## A 1v1 water polo match between two phones. Same game as Quick Match, except the other
## team's attacks aren't cards: your friend plays them.
##
##   * Possessions alternate. The attacking phone runs its own Play (your throws never wait on
##     the network), the AI defends for the other side, and frames go out ~12 times a second
##     so the other phone watches it live.
##   * The host is the referee: it keeps the official MatchState and decides who attacks next
##     (counters, penalties, quarter breaks, the shootout), then broadcasts "st".
##   * The sprint that opens each quarter starts at the same host-clock moment on both phones;
##     each phone times its own sprinter and the host compares.
## Sides are absolute: 0 = the host's team, 1 = the guest's. `me` says which one this phone is.

signal changed                      # a new official state ("st") arrived
signal remote_frame(f: Dictionary)  # a frame of the other phone's attack
signal remote_event(e: Dictionary)  # a sound/banner moment in the other phone's attack
signal remote_sprint(x: float)      # how far the other sprinter has swum
signal remote_verdict(outcome: String, seq: int, n: int)   # their keeper's call on your shot n

enum Phase { WAIT, SPRINT, ATTACK, BREAK, FINAL }

const GO_DELAY_MS := 900.0          # a beat between a decision and the next attack
const SPRINT_LEAD_MS := 2600.0      # countdown before the sprint whistle
const BREAK_MS := 4500.0
const SPRINT_TIMEOUT_MS := 15000.0
const ATTACK_TIMEOUT_MS := 120000.0  # far longer than any possession: the attacking phone is stuck
const SHOOTOUT_ROUNDS := 5
const SWIM_IN := MatchFlow.SWIM_IN_TIME

var net: Node                       # the Net autoload (sends, clock)
var me := 0
var teams: Array = []               # [host team, guest team]
var names := ["", ""]
var designs := ["classic", "classic"]   # each team's cap design (see Caps)
var minutes := 4.0
var seed_value := 0
var st: MatchState
var phase: int = Phase.WAIT
var seq := 0
var att := 0
var kind: int = Play.Kind.HALF_COURT
var shot0 := Play.SHOT_CLOCK        # this possession's shot clock at the start (20 s after a transition)
var go_at := 0.0                    # host clock: when this phase starts
var until := 0.0                    # host clock: when a break ends
var winner := -1
var forfeit := false
var kicks := 0                      # shootout penalties taken
var rng := RandomNumberGenerator.new()
var _spr := [-1.0, -1.0]            # host: sprint arrival time per side (host clock), -1 = not yet
var _ended_seq := -1                # host: the possession whose result was already counted

func _init(p_net: Node, msg: Dictionary, my_side: int) -> void:
	net = p_net
	me = my_side
	minutes = float(msg.minutes)
	seed_value = int(msg.seed)
	names = [String(msg.names[0]), String(msg.names[1])]
	var d: Array = msg.get("designs", ["classic", "classic"])
	designs = [Net._known_cap(String(d[0])), Net._known_cap(String(d[1]))]
	teams = make_teams(msg.clubs, bool(msg.equal), seed_value)
	st = MatchState.new(minutes)
	rng.seed = seed_value

## Both phones build identical rosters from the clubs. Equal teams: everyone gets the same
## ratings slot for slot, so it's pure skill.
static func make_teams(clubs: Array, equal: bool, seed_value: int) -> Array:
	var a := League.make_team(int(clubs[0]))
	var b := League.make_team(int(clubs[1]))
	if int(clubs[0]) == int(clubs[1]):
		b.name = b.name + " II"
		b.id = b.id.substr(0, 2) + "2"
	if equal:
		var tmpl := League.make_team(3, seed_value)
		for t in [a, b]:
			for i in t.roster.size():
				var src: PoloPlayer = tmpl.roster[i]
				var p: PoloPlayer = t.roster[i]
				for k in ["shoot", "passing", "speed", "strength", "defense", "keeping"]:
					p.set(k, src.get(k))
				p.attrs = src.attrs.duplicate()
				p.attr_pot = src.attr_pot.duplicate()
				Attributes.sync(p)
				p.lefty = src.lefty
				p.trait_id = src.trait_id
	return [a, b]

func is_host() -> bool:
	return me == 0

func my_team() -> PoloTeam:
	return teams[me]

func their_team() -> PoloTeam:
	return teams[1 - me]

func my_attack() -> bool:
	return phase == Phase.ATTACK and att == me

## The attacking phone's Play for this possession (attacker = `us` in the Play).
func new_play() -> Play:
	return _shot_clock(_home_keeper(Play.new(teams[att], teams[1 - att], kind, _play_rng(), _pen_snap())))

## The other phone's attack, rebuilt here from the same rosters: same bodies in the same
## order, so a frame only has to carry positions. Same seed too, so both phones agree whether
## a counter is really a break (Play.is_break) or just the ball.
func shadow_play() -> Play:
	return _shot_clock(_home_keeper(Play.new(teams[att], teams[1 - att], kind, _play_rng(), _pen_snap())))

## After a transition the shot clock starts 10 s down, as in MatchFlow (a penalty keeps its own).
func _shot_clock(p: Play) -> Play:
	if p.kind != Play.Kind.PENALTY:
		p.start_shot_clock(shot0)
	return p

## A shootout penalty is only the shooter and the keeper (PlaySetup._penalty).
func _pen_snap() -> Dictionary:
	return {"shootout": true} if kind == Play.Kind.PENALTY and st.in_shootout else {}

## The host's team is the home team: its keeper dives faster (ShotModel.HOME_DIVE).
func _home_keeper(p: Play) -> Play:
	p.home_keeper = att == 1
	return p

## Is this possession a real counter (a man up on the break), on both phones?
func is_counter() -> bool:
	return kind == Play.Kind.COUNTER and new_play().kind == Play.Kind.COUNTER

func _play_rng() -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = seed_value * 31 + seq
	return r

## The game clock the attacker starts from (a half-court attack spends a few seconds setting up).
func start_clock() -> float:
	if kind == Play.Kind.HALF_COURT:
		return maxf(0.0, st.clock - minf(SWIM_IN, st.clock - 1.0))
	return st.clock

# ================================================================== host: the referee
func host_start() -> void:
	_sprint()

func _sprint() -> void:
	phase = Phase.SPRINT
	shot0 = Play.SHOT_CLOCK
	_spr = [-1.0, -1.0]
	go_at = net.now_ms() + SPRINT_LEAD_MS
	_publish()

## A phone's sprinter reached the ball at `t` (host clock).
func on_sprint(side: int, t: float) -> void:
	if not is_host() or phase != Phase.SPRINT or _spr[side] >= 0.0:
		return
	_spr[side] = t
	if _spr[0] >= 0.0 and _spr[1] >= 0.0:
		_sprint_decided(0 if _spr[0] <= _spr[1] else 1)

func _sprint_decided(side: int) -> void:
	_attack(side, Play.Kind.HALF_COURT)

func _attack(side: int, k: int) -> void:
	seq += 1
	att = side
	kind = k
	phase = Phase.ATTACK
	go_at = net.now_ms() + GO_DELAY_MS
	_publish()

## The attacking phone's possession is over. res: {seq, outcome, elapsed, swim_in, scorer,
## assist, shots, saves, excl}
func on_result(side: int, res: Dictionary) -> void:
	if not is_host() or phase != Phase.ATTACK or side != att or int(res.get("seq", -1)) != seq or _ended_seq == seq:
		return
	_ended_seq = seq
	var outcome := String(res.get("outcome", ""))
	var def := 1 - side
	if st.in_shootout:
		if outcome == "goal":
			st.shootout[side] += 1
		kicks += 1
		_shootout_next()
		return
	if kind != Play.Kind.PENALTY:   # a penalty shot doesn't run the game clock (as in MatchFlow)
		st.tick(float(res.get("swim_in", 0.0)))
		st.run(float(res.get("elapsed", 0.0)))
	st.shots[side] += int(res.get("shots", 0))
	st.saves[def] += int(res.get("saves", 0))
	st.exclusions[side] += int(res.get("excl", 0))
	var counter_chance := 0.0
	match outcome:
		"goal":
			st.add_goal(side, teams[side].find(int(res.get("scorer", 0))))
		"penalty":
			_attack(side, Play.Kind.PENALTY)
			return
		"steal", "turnover":
			st.steals[def] += 1
			counter_chance = 0.5
		"save":
			counter_chance = 0.25
	shot0 = Play.SHOT_CLOCK
	if outcome in MatchFlow.POSSESSION_CHANGES:
		# the ball changed hands in play: the transition's 10 s off both clocks, once, as in MatchFlow
		shot0 = maxf(0.0, Play.SHOT_CLOCK - st.transition())
	if st.quarter_over():
		_break()
	else:
		_attack(def, Play.Kind.COUNTER if rng.randf() < counter_chance else Play.Kind.HALF_COURT)

func _break() -> void:
	if st.is_last_quarter():
		_after_break()   # no break card after the 4th: the result (or the shootout) straight away
		return
	phase = Phase.BREAK
	until = net.now_ms() + BREAK_MS
	_publish()

## Host: timers (break over, a sprint nobody finished).
func host_tick() -> void:
	if not is_host():
		return
	var now: float = net.now_ms()
	match phase:
		Phase.BREAK:
			if now >= until:
				_after_break()
		Phase.ATTACK:
			# the guest's attack never reported back: call it a shot-clock violation and move on
			if att != me and now >= go_at + ATTACK_TIMEOUT_MS:
				on_result(att, {"seq": seq, "outcome": "shotclock", "elapsed": shot0 / MatchState.CLOCK_SPEED})
		Phase.SPRINT:
			if now >= go_at + SPRINT_TIMEOUT_MS:
				var side := 0 if _spr[0] >= 0.0 else (1 if _spr[1] >= 0.0 else rng.randi() % 2)
				_sprint_decided(side)

func _after_break() -> void:
	if not st.is_last_quarter():
		st.next_quarter()
		_sprint()
		return
	if st.tied():
		st.in_shootout = true
		kicks = 0
		_attack(0, Play.Kind.PENALTY)
	else:
		_final(st.winner())

## The host shoots first in every round. Five rounds each, stopping as soon as one side can't
## catch up; then sudden death, a round at a time.
func _shootout_next() -> void:
	var a: int = st.shootout[0]
	var b: int = st.shootout[1]
	var decided := false
	if kicks <= SHOOTOUT_ROUNDS * 2:
		var rem_h := maxi(0, SHOOTOUT_ROUNDS - (kicks + 1) / 2)
		var rem_g := maxi(0, SHOOTOUT_ROUNDS - kicks / 2)
		decided = a > b + rem_g or b > a + rem_h
	else:
		decided = kicks % 2 == 0 and a != b
	if decided:
		_final(0 if a > b else 1)
	else:
		_attack(kicks % 2, Play.Kind.PENALTY)

func _final(w: int) -> void:
	phase = Phase.FINAL
	winner = w
	_publish()

## Host: the other phone left mid-match. They forfeit.
func host_forfeit(side_left: int) -> void:
	if phase == Phase.FINAL:
		return
	forfeit = true
	_final(1 - side_left)

func _publish() -> void:
	var msg := snapshot_msg()
	net.send_match(msg)
	changed.emit()

# ================================================================== the official state
func snapshot_msg() -> Dictionary:
	return {"t": "st", "phase": phase, "seq": seq, "att": att, "kind": kind, "shot0": shot0, "go_at": go_at, "until": until,
		"winner": winner, "forfeit": forfeit, "kicks": kicks, "q": st.quarter, "clock": st.clock,
		"score": st.score.duplicate(), "shots": st.shots.duplicate(), "saves": st.saves.duplicate(),
		"excl": st.exclusions.duplicate(), "steals": st.steals.duplicate(), "so": st.shootout.duplicate(),
		"in_so": st.in_shootout, "scorers": st.scorers.duplicate(true)}

## Guest: take the host's state.
func apply(msg: Dictionary) -> void:
	if is_host():
		return
	phase = int(msg.phase)
	seq = int(msg.seq)
	att = int(msg.att)
	kind = int(msg.kind)
	shot0 = float(msg.get("shot0", Play.SHOT_CLOCK))
	go_at = float(msg.go_at)
	until = float(msg.until)
	winner = int(msg.winner)
	forfeit = bool(msg.get("forfeit", false))
	kicks = int(msg.get("kicks", 0))
	st.quarter = int(msg.q)
	st.clock = float(msg.clock)
	st.score = msg.score.duplicate()
	st.shots = msg.shots.duplicate()
	st.saves = msg.saves.duplicate()
	st.exclusions = msg.excl.duplicate()
	st.steals = msg.steals.duplicate()
	st.shootout = msg.so.duplicate()
	st.in_shootout = bool(msg.in_so)
	st.scorers = msg.scorers.duplicate(true)
	changed.emit()

## The match from this phone's point of view: side 0 is always you (for the HUD and cards).
func my_view() -> MatchState:
	if me == 0:
		return st
	var v := MatchState.new(minutes)
	v.quarter = st.quarter
	v.clock = st.clock
	v.in_shootout = st.in_shootout
	for k in ["score", "shots", "saves", "exclusions", "steals", "shootout", "scorers"]:
		var arr: Array = st.get(k)
		v.set(k, [arr[1], arr[0]])
	return v

## The result line both phones print in tests, so the harness can compare them.
func result_line() -> String:
	return "MPRES %d-%d so %d-%d q%d winner %d%s" % [st.score[0], st.score[1], st.shootout[0], st.shootout[1],
		st.quarter, winner, " forfeit" if forfeit else ""]

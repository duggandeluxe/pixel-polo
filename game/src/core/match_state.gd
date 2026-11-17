class_name MatchState
extends RefCounted
## Score, clock and box score for one match. Side 0 is the user's team, side 1 theirs.

const QUARTERS := 4
const QUARTER_MIN := 2.0       # the default: four 2:00 quarters
## QUARTER LENGTH (Settings): the minutes a played quarter can last, in the button's order. A
## career keeps its own (Career.quarter_min, 2 for every new one); Quick Match the device's
## (Game.settings.quarter_min). The game clock, its speed and the shot clock are as ever: a
## longer quarter is simply more of the same game. Simulated games are untouched.
const QUARTER_OPTIONS := [2, 3, 4, 5]
const CLOCK_SPEED := 1.25      # game-clock (and shot-clock) seconds off per second of live play: a 2:00 quarter is 96 s of play
const TURNOVER_TIME := 10.0    # the transition: game-clock and shot-clock seconds off for every change of possession in live play

var quarter_len := QUARTER_MIN * 60.0
var quarter := 1
var clock := QUARTER_MIN * 60.0
var score := [0, 0]
var shots := [0, 0]
var saves := [0, 0]        # saves made by side i's keeper
var exclusions := [0, 0]   # exclusions drawn by side i
var excl_drawn_by := [[], []]   # per side: the PoloPlayer who drew each of those (career stats)
var steals := [0, 0]       # real steals by side i (see is_steal): not loose balls picked up
var blocks := [0, 0]       # shots side i's field players got a hand to
var scorers := [{}, {}]    # per side: player tag -> goals
var goal_by := [[], []]    # per side: the PoloPlayer behind each goal (career stats)
var assist_by := [[], []]
var steal_by := [[], []]
var block_by := [[], []]   # per side: the PoloPlayer behind each block
var shot_by := [[], []]    # per side: the PoloPlayer behind each shot in play (not the shootout's)
var turnover_by := [[], []]     # per side: the PoloPlayer who lost the ball (stripped, or his pass picked off)
var excl_by := [[], []]         # per side: the PoloPlayer sent out (an exclusion committed)
var pen_drawn_by := [[], []]    # per side: the PoloPlayer fouled for a 5 m penalty (not the shootout's)
var keeper_steal_by := [[], []] # per side: the keeper taking it off them (a claim: not in `steals`)
var seen := {}             # every event occurrence already counted (once): see once()
## PERSONAL FOULS (the Exclusions & Roll-Out update): every exclusion and penalty foul committed,
## by player id, for this game only; ROLL_AT of them and he's ROLLED (out for the rest of it).
## `appeared`: everybody who took part (a sub who came on too), per side, for the box score.
const ROLL_AT := 3
var pf := {}
var pen_by := [[], []]          # per side: the PoloPlayer who committed a penalty foul
var appeared := [[], []]
var uid := "%d-%d" % [Time.get_ticks_usec(), randi()]   # this match, for Career.finish_my_game (settled once)
var shootout := [0, 0]
var in_shootout := false

## The next QUARTER LENGTH after `m`: 2 -> 3 -> 4 -> 5 -> 2 (anything else: 2).
static func next_quarter_min(m: int) -> int:
	var i := QUARTER_OPTIONS.find(m)
	return int(QUARTER_OPTIONS[(i + 1) % QUARTER_OPTIONS.size()]) if i >= 0 else int(QUARTER_OPTIONS[0])

## A saved QUARTER LENGTH, made safe: one of QUARTER_OPTIONS, else the default 2.
static func valid_quarter_min(v) -> int:
	var m := int(v) if (v is int or v is float) else 0
	return m if m in QUARTER_OPTIONS else int(QUARTER_MIN)

## The minutes a quarter of the next played game lasts: the career's (career = true) or Quick Match's.
static func quarter_min_for(career: bool) -> int:
	if career and Game.career != null:
		return valid_quarter_min(Game.career.quarter_min)
	return valid_quarter_min(Game.settings.get("quarter_min", QUARTER_MIN))

## A quarter of `minutes` (QUARTER LENGTH: 2-5; the tests pass others).
func _init(minutes_per_quarter: float = QUARTER_MIN) -> void:
	quarter_len = minutes_per_quarter * 60.0
	clock = quarter_len

## Takes `dt` game-clock seconds off (never below 0:00).
func tick(dt: float) -> void:
	clock = maxf(0.0, clock - dt)

## `live` seconds of live play went by: the clock runs at CLOCK_SPEED.
func run(live: float) -> void:
	tick(live * CLOCK_SPEED)

## The ball changed hands in live play: the transition takes TURNOVER_TIME off the game clock,
## once (never below 0:00). Returns what it took, so the next shot clock loses the same.
func transition() -> float:
	var took := minf(TURNOVER_TIME, clock)
	tick(took)
	return took

func quarter_over() -> bool:
	return clock <= 0.0

func is_last_quarter() -> bool:
	return quarter >= QUARTERS

func next_quarter() -> void:
	quarter += 1
	clock = quarter_len

## Did a possession that ended `outcome` with result `r` end in a real steal: a field player
## taking the ball off a man or out of the air? A keeper claiming a pass, or a loose ball
## picked up ("turnover"), isn't one.
static func is_steal(outcome: String, r: Dictionary) -> bool:
	if outcome != "steal" or r.get("by") == null:
		return false
	return not (r.by as PoloPlayer).is_keeper()

## Has occurrence `occ` (a play and its event) been counted yet? Counts it now if not: a
## repeated frame, callback or replay of the same event is then never counted twice.
## One more personal foul for `p` (MatchFlow, once per foul): his new count.
func add_pf(p: PoloPlayer) -> int:
	pf[p.id] = int(pf.get(p.id, 0)) + 1
	return int(pf[p.id])

func pf_of(p: PoloPlayer) -> int:
	return int(pf.get(p.id, 0)) if p != null else 0

func once(occ: String) -> bool:
	if seen.has(occ):
		return false
	seen[occ] = true
	return true

func add_goal(side: int, who: PoloPlayer) -> void:
	score[side] += 1
	if who:
		goal_by[side].append(who)
	var t: String = who.tag() if who else "?"
	scorers[side][t] = int(scorers[side].get(t, 0)) + 1

func tied() -> bool:
	return score[0] == score[1]

## 0 or 1, or -1 while level (a shootout breaks the tie without changing the score).
func winner() -> int:
	if score[0] != score[1]:
		return 0 if score[0] > score[1] else 1
	if in_shootout and shootout[0] != shootout[1]:
		return 0 if shootout[0] > shootout[1] else 1
	return -1

func clock_text() -> String:
	var s := int(ceilf(clock))
	return "%d:%02d" % [s / 60, s % 60]

func top_scorer(side: int) -> String:
	var best := ""
	var n := 0
	for k in scorers[side].keys():
		if int(scorers[side][k]) > n:
			n = int(scorers[side][k])
			best = k
	return "%s (%d)" % [best, n] if n > 0 else "-"

## What a career game hands back to Career.finish_my_game() for side 0 (you). `them`: the
## other team, for both sides' stat lines (the postgame grade).
func box(us: PoloTeam, them: PoloTeam = null) -> Dictionary:
	var out := {"score": [score[0], score[1]], "so": [shootout[0], shootout[1]] if in_shootout else [],
		"uid": uid, "won": winner() == 0, "goals": goal_by[0], "assists": assist_by[0], "steals": steal_by[0], "blocks": block_by[0],
		"excl_drawn": excl_drawn_by[0], "keeper": us.keeper(), "saves": saves[0], "played": appeared[0].duplicate() if not appeared[0].is_empty() else us.starters(), "pen_fouls": pen_by[0], "pf": pf.duplicate(),
		"turnovers": turnover_by[0], "excl": excl_by[0], "pen_drawn": pen_drawn_by[0], "keeper_steals": keeper_steal_by[0],
		"shots": shot_by[0]}   # (every shot in play by whoever took it, subs too: the development sheet's S and %)
	if them != null:
		out["lines"] = [player_lines(0, us), player_lines(1, them)]
		# their side's recorded events too, for their players' XP (Development)
		out["them"] = {"lists": {"g": goal_by[1], "a": assist_by[1], "st": steal_by[1] + keeper_steal_by[1],
			"bl": block_by[1], "ed": excl_drawn_by[1], "to": turnover_by[1], "ex": excl_by[1], "pd": pen_drawn_by[1]},
			"saves": saves[1], "played": appeared[1].duplicate() if not appeared[1].is_empty() else them.starters()}
	return out

## Every one of `t`'s seven's stat line for side `side` (PlayerForm.raw_points): field players
## g goals, sh shots, bl blocks, ed exclusions drawn, ga the other side's goals (all seven are
## in the water all game); the keeper sv saves, ga goals against. The shootout isn't in them.
func player_lines(side: int, t: PoloTeam) -> Dictionary:
	var out := {}
	var seven := t.starters()
	var ga := int(score[1 - side])
	for p in seven:
		if p == seven[0]:
			out[p.id] = {"gk": true, "sv": int(saves[side]), "ga": ga}
		else:
			out[p.id] = {"g": goal_by[side].count(p), "sh": shot_by[side].count(p), "bl": block_by[side].count(p),
				"ed": excl_drawn_by[side].count(p), "ga": ga}
	return out

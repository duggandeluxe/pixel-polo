class_name DropCall
## THE COMPUTER'S DEFENCE: one drop for the half, PRESS until the centre has his man beaten.
##
## Before the game the computer scouts your roster against its own (scout) and game-plans ONE of
## the four drops, the way you do in Coaching. In the match its defence has two options only:
## PRESS and that drop (MatchFlow.their_drop, handed to each possession: Play.ai_drop). At
## halftime it looks at its first half (halftime) and keeps its drop or changes it: the only time
## it can. The formations themselves are DefenseFormation's, untouched: this only decides which
## drop, and when.
##
## Every possession starts in PRESS (a new Play always does). The drop is called (step) only when
## your centre has real position on its 2MD (the centre's guard: PlaySetup.marking's first):
## he's won the 2 m battle (PlayAI._center_battle), or his man is off the entry lane (behind him,
## on the far side of him) and the ball can go in (center_threat). A centre who's being fronted is
## no reason, however near the goal. It takes the defence a moment to see it and call it
## (reaction, a second or two at most: a centre with position is fed fast): sooner the more the
## centre has on its 2MD (his Strength against the 2MD's Strength and Defense; his Shooting a
## little), and sooner again the more personal fouls the 2MD has (it wants to keep him from his
## third). Fouls aren't needed, and alone never call it. The centre losing his position before the call, it's off. Once in the
## drop it stays there (no flicking back and forth) until the centre's left his spot for a while,
## or the man-up changes everything; a new possession is PRESS again.
##
## How the four are scored (score): what each one does for the 2MD and what it gives away, from
## the formations' own assignments (DefenseFormation's duties, by formation spot: slot):
##   SUPPORT  how much help the 2MD gets in front of the centre: M-DROP's D3 drops straight in from
##            the point with both splitters sagging behind him (the most); 5 DROP's D5 drops from
##            his spot with a helper rotating; the pistons put one man in at a time (4-5, 3-4)
##   EXPOSE   who it leaves to shoot, by formation spot, as a share: M-DROP the point and the two
##            flats (D3 gone, D2/D4 splitting), 5 DROP spot 5, 4-5 spots 4 and 5 and 3-4 spots 3 and
##            4 half the time each (the piston out goes to the ball)
## A drop is worth its SUPPORT times the centre's edge on the 2MD, less what its open men can do
## (their Shooting, a little of their Passing, against the defender at that spot), plus its
## dropper's Defense. At halftime the same, with what the first half showed: where the shots and
## goals came from, the centre's position won, his exclusions drawn, entries he caught through the
## drop, the 2MD's fouls, and how the drop did against PRESS. Keeping the drop needs no reason:
## changing it needs one (KEEP).

const F := DefenseFormation.F

# ------------------------------------------------------------------ the formations, as the scouting reads them
const SUPPORT := {F.M_DROP: 1.0, F.FIVE_DROP: 0.7, F.THREE_FOUR: 0.6, F.FOUR_FIVE: 0.55}
const EXPOSE := {
	F.M_DROP: {"2": 0.45, "3": 0.6, "4": 0.45},
	F.FIVE_DROP: {"5": 0.85},
	F.FOUR_FIVE: {"4": 0.45, "5": 0.45},
	F.THREE_FOUR: {"3": 0.45, "4": 0.45},
}
## Who drops in front of the centre, by formation spot (the pistons: either).
const DROPPERS := {F.M_DROP: ["3"], F.FIVE_DROP: ["5"], F.FOUR_FIVE: ["4", "5"], F.THREE_FOUR: ["3", "4"]}
const CENTER_K := 1.0          # a point of the centre's edge on the 2MD, times a drop's SUPPORT
const OPEN_BASE := 1.0         # an open man is a cost whoever he is...
const OPEN_SHOOT := 0.7        # ...more for each point of Shooting over 5...
const OPEN_PASS := 0.3         # ...and of Passing (he finds the next open man)
const OPEN_GUARD := 0.25       # ...less for a good defender at that spot
const ZONE_PASS := 0.2         # the attack's passing, over 5, against every share left open
const DROPPER_K := 0.1         # the dropper's Defense over 5, times SUPPORT

# ------------------------------------------------------------------ halftime
const HALF_MIN_POSS := 4.0     # (rates over fewer possessions than this are read as this many)
const OBS_CENTER := 0.5        # the half's centre against the scouting's: this much of each
const OBS_C_K := 8.0           # centre damage a possession -> the centre's edge, in points...
const OBS_C_ZERO := 0.51       # ...nothing to see at this much a possession (a bot-played half's average)
const OBS_PERIM_K := 6.0       # a spot's damage a possession -> its shooter's threat
const OBS_PERIM_ZERO := 0.12   # (the same, for a perimeter spot)
const SAVE_W := 0.6            # a shot the keeper had to save counts this much of a goal
const DROP_ENTRY_USUAL := 0.3  # entries to the centre a drop possession: about a bot-played half's
const DROP_GOALS_USUAL := 0.7  # goals a drop possession: the same
const FOUL_HELP := [0.0, 0.6, 1.4]   # the 2MD's personal fouls: the centre's edge, as the defence fears it
const NO_BENCH := 0.4          # ...two, and nobody on the bench to bring in for him
const KEEP := Vector2(0.35, 1.2)     # the margin a new drop needs: a half full of chances .. a quiet one
const DANGER_QUIET := 0.8      # goals + saves a possession at which the half counts as busy

# ------------------------------------------------------------------ the call
const REACT_EVEN := 1.2        # s to call it with the matchup even and no fouls...
const REACT_PER_POINT := 0.2   # ...this much less for each point of the centre's edge
const REACT_RANGE := Vector2(0.5, 2.0)   # (never slower than this: a centre with position gets fed fast)
const FOUL_MULT := 0.75        # one foul on the 2MD: quicker...
const FOUL_ONE_MAX := 1.2
const FOUL_TWO_MULT := 0.5     # ...two: urgent
const FOUL_TWO_RANGE := Vector2(0.3, 0.7)
const REACT_JITTER := 0.1      # (give or take this share: it isn't a stopwatch)
const LOST_GRACE := 0.3        # the centre without his position this long: the pending call's off
const DROP_MIN := 3.0          # in the drop at least this long...
const OFF_SPOT := 0.5          # ...and the centre this far further off his spot than his spot's room...
const RESOLVED := 1.2          # ...for this long: the threat's over, back to PRESS

# ------------------------------------------------------------------ ratings
static func _str(p: PoloPlayer) -> float:
	return Attributes.strength(p) if p != null else 5.0

static func _sho(p: PoloPlayer) -> float:
	return DefenseFormation.shooting(p)

static func _pas(p: PoloPlayer) -> float:
	return DefenseFormation.passing(p)

static func _dfn(p: PoloPlayer) -> float:
	return DefenseFormation.defense(p)

## The centre's edge on the 2MD, in points: Strength, his Shooting a little, against the 2MD's
## Strength and Defense. 0: even; + the centre's.
static func center_edge(c: PoloPlayer, g: PoloPlayer) -> float:
	return (0.6 * _str(c) + 0.4 * _sho(c)) - (0.55 * _str(g) + 0.45 * _dfn(g))

## The matchup as the scouting reads it: the attack's six by tag (PlaySetup.TAGS, the order it
## lines up in: PoloTeam.starters) and the defenders on them (PlaySetup.marking: the 2MD first, on
## the centre). {att: {tag: PoloPlayer}, def: {tag: PoloPlayer}}.
static func matchup(def_team: PoloTeam, att_team: PoloTeam) -> Dictionary:
	var att := {}
	var field: Array = PlaySetup.seven(att_team).slice(1)
	for i in mini(PlaySetup.TAGS.size(), field.size()):
		att[PlaySetup.TAGS[i]] = field[i]
	var dfield: Array = PlaySetup.marking(PlaySetup.seven(def_team))
	var def := {}
	for i in mini(PlaySetup.TAGS.size(), dfield.size()):
		def[PlaySetup.TAGS[i]] = dfield[i]
	return {"att": att, "def": def}

## Formation spot `n` as an attacker's tag: the computer's defence sees the pool turned round
## (DefenseFormation.slot), yours as the tags go.
static func tag_of(n: String, turned: bool) -> String:
	return String(DefenseFormation.TURNED[n]) if turned else n

## How dangerous attacker `a` is left alone, before the defender at his spot (`d`) is counted.
static func open_threat(a: PoloPlayer, d: PoloPlayer) -> float:
	return OPEN_BASE + OPEN_SHOOT * (_sho(a) - 5.0) + OPEN_PASS * (_pas(a) - 5.0) - OPEN_GUARD * (_dfn(d) - 5.0)

## Every drop's suitability against this attack, {F: score} (higher: better). `edge` is the
## centre's edge on the 2MD as the defence reads it (center_edge, or the halftime's), `extra`
## per attacker tag what the half has added to his threat.
static func score(m: Dictionary, turned: bool, edge: float, extra: Dictionary = {}) -> Dictionary:
	var att: Dictionary = m.get("att", {})
	var def: Dictionary = m.get("def", {})
	var pas := 0.0
	for t in ["1", "2", "3", "4", "5"]:
		pas += _pas(att.get(t)) / 5.0
	var out := {}
	for f in DefenseFormation.DROPS:
		var v := CENTER_K * float(SUPPORT[f]) * edge
		var share := 0.0
		for n in EXPOSE[f]:
			var t := tag_of(n, turned)
			var e := float(EXPOSE[f][n])
			share += e
			v -= e * (open_threat(att.get(t), def.get(t)) + float(extra.get(t, 0.0)))
		v -= ZONE_PASS * share * (pas - 5.0)
		var dr := 0.0
		for n in DROPPERS[f]:
			dr += _dfn(def.get(tag_of(n, turned))) / float(DROPPERS[f].size())
		v += DROPPER_K * float(SUPPORT[f]) * (dr - 5.0)
		out[f] = snappedf(v, 0.001)
	return out

static func best(scores: Dictionary) -> int:
	var pick: int = DefenseFormation.DEFAULT_DROP
	var top := -INF
	for f in DefenseFormation.DROPS:
		if float(scores[f]) > top:
			top = float(scores[f])
			pick = f
	return pick

## The computer's game plan before a game: its drop for the first half, from the two rosters.
## (`turned`: it's the computer's defence, which sees the pool turned round: slot.)
static func scout(def_team: PoloTeam, att_team: PoloTeam, turned := true) -> int:
	var m := matchup(def_team, att_team)
	if m.att.size() < 6 or m.def.size() < 6:
		return DefenseFormation.DEFAULT_DROP   # (a drill's stripped-down sides: nothing to scout)
	return best(score(m, turned, center_edge(m.att.get("C"), m.def.get("C"))))

# ------------------------------------------------------------------ halftime
## A half's defensive log (MatchFlow keeps one for the computer's defence: their_log).
static func new_log() -> Dictionary:
	return {"poss": 0, "drop_poss": 0, "press_poss": 0, "goals": 0, "saves": 0, "shots": 0,
		"drop_goals": 0, "press_goals": 0, "high_tired": 0, "c_threats": 0, "c_excl": 0, "drop_entries": 0,
		"drop_calls": 0, "by": {}}

## One shot's end in the log: `tag` the shooter's, `outcome` "goal" / "save" / anything else.
static func log_shot(lg: Dictionary, shot: Dictionary, outcome: String, drop_poss: bool) -> void:
	var t := String(shot.get("tag", ""))
	if t == "":
		return
	var by: Dictionary = lg.by
	if not by.has(t):
		by[t] = {"g": 0, "sv": 0, "sh": 0, "tired": 0}
	by[t].sh += 1
	lg.shots += 1
	var tired := float(shot.get("height", 0.0)) > ShotModel.HEIGHT_PEAK and float(shot.get("strain", 0.0)) > 0.01
	if outcome == "goal":
		by[t].g += 1
		lg.goals += 1
		if drop_poss:
			lg.drop_goals += 1
		else:
			lg.press_goals += 1
		if tired:
			lg.high_tired += 1
			by[t].tired += 1
	elif outcome in ["save", "parry"]:
		by[t].sv += 1
		lg.saves += 1

## What the centre did to the defence in a half, a possession: his goals, the shots the keeper
## had to save, his exclusions drawn and his catches through the drop. (Position won isn't
## damage by itself: the drop is the answer to it.)
static func center_damage(lg: Dictionary) -> float:
	var c: Dictionary = (lg.by as Dictionary).get("C", {})
	return (float(c.get("g", 0)) + SAVE_W * float(c.get("sv", 0)) + 0.8 * float(lg.c_excl) \
		+ 0.3 * float(lg.drop_entries)) / maxf(float(lg.poss), HALF_MIN_POSS)

## ...and a perimeter spot (attacker tag `t`): goals, saves, and the high ones off tired legs.
static func spot_damage(lg: Dictionary, t: String) -> float:
	var e: Dictionary = (lg.by as Dictionary).get(t, {})
	return (float(e.get("g", 0)) + SAVE_W * float(e.get("sv", 0)) + 0.5 * float(e.get("tired", 0))) \
		/ maxf(float(lg.poss), HALF_MIN_POSS)

## The halftime decision, from the first half's log and the matchup now (the subs and the ROLLED
## in it). `cur` the drop it had; `pf` its 2MD's personal fouls; `bench` whether there's a defender
## on the bench to bring in for him. {drop, keep, scores, edge, margin, gain, reason}.
static func halftime(cur: int, m: Dictionary, lg: Dictionary, pf: int, bench: bool, turned := true) -> Dictionary:
	var poss := maxf(float(lg.poss), HALF_MIN_POSS)
	var by: Dictionary = lg.by
	# the centre: what he did to it, and what the 2MD's fouls make of him now
	var seen := clampf(OBS_C_K * (center_damage(lg) - OBS_C_ZERO), -4.0, 6.0)
	var edge := (1.0 - OBS_CENTER) * center_edge(m.att.get("C"), m.def.get("C")) + OBS_CENTER * seen
	edge += float(FOUL_HELP[clampi(pf, 0, FOUL_HELP.size() - 1)])
	if pf >= 2 and not bench:
		edge += NO_BENCH
	# the perimeter: who's hurt it from where (goals, saves he had to make, high ones off tired legs)
	var extra := {}
	for t in ["1", "2", "3", "4", "5"]:
		extra[t] = 0.6 * clampf(OBS_PERIM_K * (spot_damage(lg, t) - OBS_PERIM_ZERO), -1.0, 4.0)
	var scores := score(m, turned, edge, extra)
	# how the drop it had did: the entries it let through (more than a drop usually does), the goals
	# scored against it a drop possession (more than usual), the keeper behind it beaten up high.
	# (Not against PRESS: it only drops when the centre already has position, the harder possessions.)
	var dp := maxf(1.0, float(lg.drop_poss))
	var worn := 1.5 * maxf(0.0, float(lg.drop_entries) / dp - DROP_ENTRY_USUAL) \
		+ 2.0 * maxf(0.0, float(lg.drop_goals) / dp - DROP_GOALS_USUAL) + 0.25 * float(lg.high_tired)
	if int(lg.drop_poss) < 2:
		worn = 0.25 * float(lg.high_tired)   # (too few to say)
	scores[cur] = snappedf(float(scores[cur]) - worn, 0.001)
	# keeping it needs no reason; a change needs a real one (more of one after a quiet half)
	var danger := (float(lg.goals) + SAVE_W * float(lg.saves)) / poss
	var margin := lerpf(KEEP.x, KEEP.y, clampf(1.0 - danger / DANGER_QUIET, 0.0, 1.0))
	var top := cur
	for f in DefenseFormation.DROPS:
		if f != cur and float(scores[f]) > float(scores[top]):
			top = f
	var gain := float(scores[top]) - float(scores[cur])
	var change := top != cur and gain > margin
	var reason := "kept: it's working"
	if change:
		reason = "the centre" if float(SUPPORT[top]) > float(SUPPORT[cur]) else "the perimeter"
	elif top != cur:
		reason = "kept: %s only a little better" % DefenseFormation.NAMES[top]
	return {"drop": top if change else cur, "keep": not change, "scores": scores, "edge": snappedf(edge, 0.001),
		"margin": snappedf(margin, 0.001), "gain": snappedf(gain, 0.001), "worn": snappedf(worn, 0.001), "reason": reason}

# ------------------------------------------------------------------ the call, in a possession
## The centre's own man, the 2MD (the defender on "C").
static func guard(p: Play) -> Swimmer:
	return DefenseFormation.by_tag(p.defenders, "C", true)

static func centre(p: Play) -> Swimmer:
	return DefenseFormation.by_tag(p.attackers, "C")

## Has the centre got real position on the 2MD right now: on his spot, the ball live with the
## attack, and any of: the 2 m battle won (turned, sealed, or his man still swimming back round),
## the entry lane open (Play.center_entry "open": his man's behind him or on the far side of him
## from the ball), nobody on him at all, or the ball already in his hands there. No fouls needed.
## Fronted (his man in the lane), or his man beside him with the ball straight down from the
## point ("straight"), he hasn't.
static func center_threat(p: Play) -> bool:
	var c := centre(p)
	var g := guard(p)
	if c == null or g == null or c.out or p.carry:
		return false
	if c.pos.distance_to(c.home) > Play.CENTER_SPOT_R:
		return false
	if p.ball.state == Ball.State.HELD:
		if p.holder == null or not p.attackers.has(p.holder):
			return false
		if p.holder == c:
			return true
	elif p.ball.state != Ball.State.PASS:
		return false
	if p.cfight in [PlayAI.Fight.SPIN, PlayAI.Fight.SEALED, PlayAI.Fight.ROUND]:
		return true
	if g.out or g.pos.distance_to(c.pos) > Play.CENTER_GUARD_R:
		return true   # nobody on him
	return p.center_entry(DefenseFormation.ball_focus(p), c) == "open"

## How long (s) the defence takes to call its drop once the centre has position, with no dice:
## the matchup (center_edge, his keeper's organising in the 2MD's Defense) and the 2MD's fouls.
static func reaction(c: PoloPlayer, g: PoloPlayer, fouls: int) -> float:
	var t := clampf(REACT_EVEN - REACT_PER_POINT * center_edge(c, g), REACT_RANGE.x, REACT_RANGE.y)
	if fouls == 1:
		t = minf(t * FOUL_MULT, FOUL_ONE_MAX)
	elif fouls >= 2:
		t = clampf(t * FOUL_TWO_MULT, FOUL_TWO_RANGE.x, FOUL_TWO_RANGE.y)
	return t

static func fouls_of(p: Play, s: Swimmer) -> int:
	return int(p.pf.get(s.player.id, 0)) if s != null and s.player != null else 0

## One live frame (Play.step, before the defence moves): the computer's call. Nothing for a
## formation somebody's picked (select_formation: a lab, a test) or a defence that isn't the
## computer's.
static func step(p: Play, dt: float) -> void:
	if p.ai_drop < 0 or p.formation_locked or p.over:
		return
	if p.drop_pending >= 0:
		if p.man_up > 0.0:
			p.drop_pending = -1   # (the exclusion's changed everything)
			p.drop_fouler = null
		return   # (called: its foul first, Play._drop_step)
	if not DefenseFormation.active(p):
		if p.man_up > 0.0 and p.formation != F.PRESS:
			call_formation(p, F.PRESS, "man_up")   # the exclusion's changed everything: PRESS once it's 6 on 6 again
		_cancel(p)
		return
	var threat := center_threat(p)
	if p.formation == F.PRESS:
		if p.drop_fouled:
			return   # (one drop, one foul: this possession's been used)
		if threat:
			if p.dc_wait < 0.0:
				var g := guard(p)
				p.dc_wait = reaction(centre(p).player, g.player, fouls_of(p, g)) \
					* (1.0 + p.ai_rng.randf_range(-REACT_JITTER, REACT_JITTER))
				p.dc_t = 0.0
				p.events.append({"k": "c_position", "wait": p.dc_wait})
			p.dc_lost = 0.0
			p.dc_t += dt
			if p.dc_t >= p.dc_wait:
				call_formation(p, p.ai_drop, "centre")
		elif p.dc_wait >= 0.0:
			p.dc_lost += dt
			if p.dc_lost >= LOST_GRACE:
				_cancel(p)   # he lost it before they called it
		return
	p.dc_in += dt
	var c := centre(p)
	var off := c == null or c.out or c.pos.distance_to(c.home) > Play.CENTER_SPOT_R + OFF_SPOT
	p.dc_off = p.dc_off + dt if off else 0.0
	if p.dc_in >= DROP_MIN and p.dc_off >= RESOLVED:
		call_formation(p, F.PRESS, "resolved")

static func _cancel(p: Play) -> void:
	p.dc_t = 0.0
	p.dc_wait = -1.0
	p.dc_lost = 0.0

## The computer's defence into `f`: back to PRESS at once; a drop the way your own is called,
## the foul on the ball first (Play.begin_drop). No lock.
static func call_formation(p: Play, f: int, why: String) -> void:
	if p.formation == f:
		return
	p.dc_in = 0.0
	p.dc_off = 0.0
	_cancel(p)
	var extra := {"ai": true, "why": why}
	if f == F.PRESS or Play.instant_drops:
		p.form_up(f, extra)
	else:
		p.begin_drop(f, extra)

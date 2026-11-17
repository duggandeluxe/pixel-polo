class_name PlayerForm
## Player stars, HOT form and the postgame grade (docs: "Player Stars & 7-Player Rosters").
##
## Every player has two permanent ratings, CURRENT and POTENTIAL stars (0.0-5.0, potential never
## below current). Since 2.0 they are half his OVERALL and POTENTIAL (Attributes: the averages of
## his four attributes and their ceilings), unrounded, so they move whenever an attribute does.
## On top of CURRENT sits form: after every game each of the seven is graded GOOD (+1), NORMAL (0)
## or BAD (-1) from his stat line against what was expected of him, and his last FORM_GAMES grades
## move his HEAT one level at a time: NORMAL (0), HOT (1, one red star) or VERY HOT (2, two red
## stars). There is no cold form: a player who isn't HOT plays and shows his own stars.
## EFFECTIVE = CURRENT + form, 0.0-6.0. The team overall counts a man's HEAT UP as his red stars
## (PoloTeam.team_overall); the scoring engine adds its own form term once to OFF and DEF
## (PoloTeam.form_delta, GameSim.live_ratings), and in a game you play form is each man's Hot
## Stars' attribute bonus instead: +0.5 to all four of his attributes a Hot Star, past 10 too
## (Attributes.hot_bonus), which every attribute effect and his 0-100 ratings read (PoloPlayer.live).

## The star scale (the spec's numbers): stars x 2 -> the hidden value. 5.5 and 6.0 exist only
## as EFFECTIVE stars, for a five-star player who is HOT or VERY HOT.
const STAR_VALUE := {2: 44, 3: 50, 4: 56, 5: 62, 6: 68, 7: 74, 8: 80, 9: 86, 10: 92, 11: 96, 12: 99}
const STAR_WORDS := {2: "ENTRY-LEVEL", 3: "LOW", 4: "DEVELOPING", 5: "AVERAGE", 6: "GOOD", 7: "VERY GOOD",
	8: "EXCELLENT", 9: "EXCEPTIONAL", 10: "ELITE"}
const MIN_STARS := 0.0        # (OVERALL 0)
const MAX_STARS := 5.0        # CURRENT and POTENTIAL (OVERALL 10)
const MAX_EFFECTIVE := 6.0

## The form states, coolest first (HEAT 0, 1, 2), and what each adds to a player's stars in play.
## The bonus is EFFECTIVE stars (a game's ratings: RATING_PER_STAR a star); the bar shows the level
## as whole red stars (red_stars), one for HOT, two for VERY HOT.
const NORMAL := "normal"
const HOT := "hot"
const VERY_HOT := "very_hot"
const LEVELS := [NORMAL, HOT, VERY_HOT]
const FORM_STARS := {VERY_HOT: 1.0, HOT: 0.5, NORMAL: 0.0}
const FORM_NAMES := {VERY_HOT: "VERY HOT", HOT: "HOT", NORMAL: "NORMAL"}
const FIRE_RED := Color("ff4a2a")     # HOT and VERY HOT
const GOLD := Color("ffd23f")         # NORMAL (UI.GOLD)

## HEAT from a run of games: the last FORM_GAMES grades, scored GOOD - BAD (the RUN). A run of
## HOT_AT or more heats a NORMAL player up to HOT, VERY_HOT_AT a HOT one up to VERY HOT; a HOT
## player keeps it while the run stays at HOT_HOLD or more, a VERY HOT one only while it stays at
## VERY_HOT_HOLD. Heat moves one level a game at most, up or down, so NORMAL -> HOT -> VERY HOT and
## back the same way. One great game is never enough (HOT takes three GOOD games in five, with no
## BAD to cancel one); VERY HOT needs four of five, to have been HOT the game before, and to keep
## it up (measured over seasons since GOOD_AT went to +4.5: a player is HOT about one game in 35,
## VERY HOT about one in 500; it was one in 15 and one in 100 at +3).
const FORM_GAMES := 5
const HOT_AT := 3
const VERY_HOT_AT := 4
const HOT_HOLD := 2
const VERY_HOT_HOLD := 4

## The postgame grade: PERFORMANCE +/- = RAW - EXPECTED.
const GOOD := 1
const BAD := -1
## THE ONE HOT STAR BALANCING VALUE (the Universal Hot Star Balancing update): the performance a
## GOOD game takes, x1.30 its old +4.5 (now +5.85). Every Hot Star is built from GOOD games (HOT
## from a run of three, VERY HOT from four), so this one number makes both 30% harder to earn,
## for every player in the game the same (yours and the CPU's, played and simulated: grade_team
## is the one place anyone is graded), and is applied nowhere else. BAD games, the runs a star
## takes, how long a star holds (HOT_HOLD / VERY_HOT_HOLD) and the bonuses are as they were.
const GOOD_AT_BASE := 4.5     # (was +3 until HOT was made half as easy to reach, then this)
const HOT_STAR_ACQUISITION_MULTIPLIER := 1.30
const GOOD_AT := GOOD_AT_BASE * HOT_STAR_ACQUISITION_MULTIPLIER
## Measurement only (tests / Developer Mode's comparisons): the multiplier grade_of uses. Always
## HOT_STAR_ACQUISITION_MULTIPLIER in the game.
static var acquisition := HOT_STAR_ACQUISITION_MULTIPLIER

static func good_at() -> float:
	return GOOD_AT_BASE * acquisition
const BAD_AT := -3.0          # -3 or less is BAD
const GRADE_NAMES := {1: "GOOD", 0: "NORMAL", -1: "BAD"}

## RAW points (the spec's table). Field players: goals, exclusions drawn, field blocks, missed
## shots, and every goal the other side scores while he's in the water (all seven play it all).
## Keepers: saves and goals allowed (a save is never also a field block).
const PTS_GOAL := 3.0
const PTS_EXCL := 2.0
const PTS_BLOCK := 2.0
const PTS_MISS := -1.0
const PTS_FIELD_GA := -0.5
const PTS_SAVE := 2.0
const PTS_KEEPER_GA := -1.5

## ------------------------------------------------------------------ the expected-performance model
## NOT from the spec: the spec names the inputs (CURRENT stars, the opponent's OFF/DEF, position,
## game context) and leaves the numbers to the game. Here they are.
##
## Team expectations come from the scoring engine's own formula (GameSim.expected), before the
## game: our expected goals G and theirs A, from the two teams' ratings, with the home pool (or a
## neutral site) in them. BASE comes from CURRENT stars, so a stronger roster is expected to score
## more, and 3 goals against CULA's DEF are worth more than 3 against HURST's. The ratings are the
## ones the game is played with (GameSim.pregame_expected: BASE plus each team's form), so a HOT
## team is expected to play like one: on BASE alone its own boost would keep it HOT by itself
## (measured: form 4 points off BASE on average, changing a fifth of all results).
## Then, per environment (a scoring-engine game, or a game played out in the pool):
##   POSS     possessions a side          SAVE  share of the other side's non-scoring possessions saved
##   MISS     share of our non-scoring possessions that end in a missed shot (saved, blocked, wide)
##   BLOCK    share of their non-scoring possessions our field players block
##   EXCL     exclusions a side draws      GOALS played games score this share of the engine's goals
##   team misses M = (POSS - G) x MISS; our blocks B = (POSS - A) x BLOCK; exclusions X = EXCL
## Each field player gets his share of those: goals and misses by shooting rating squared (the
## engine picks its shooters that way: OppSim._pick_shooter), blocks by defence squared,
## exclusions by strength squared with the centre's counted CENTER_EXCL times. A game played in
## the pool isn't shared out like that (the centre takes his shots from 2 m and draws nearly
## every exclusion; drivers in the lanes make most of the blocks), so there each share is also
## multiplied by the position's number in POS ("goal", "miss", "block"), and the centre gets
## CENTER_SHARE of the exclusions.
##   field EXPECTED = 3 x G x goal + 2 x X x excl + 2 x B x block - M x miss - 0.5 x A
##   keeper EXPECTED = 2 x (POSS - A) x SAVE - 1.5 x A
## "sim" matches what GameSim.player_lines generates; "played" is measured from bot-played games
## (tests: --test form_calibrate) so a man who plays to his level averages about +/- 0.
const ENV := {
	"sim": {"poss": 24.0, "goals": 1.0, "miss": 0.768, "block": 0.145, "excl": 6.0, "save": 0.42, "center_excl": 2.5},
	"played": {"poss": 18.5, "goals": 0.59, "miss": 0.94, "block": 0.19, "excl": 9.0, "save": 0.69, "center_excl": 2.5,
		"center_share": 0.97,
		"pos": {"goal": {PoloPlayer.Pos.CENTER: 1.43, PoloPlayer.Pos.DEFENDER: 1.04, PoloPlayer.Pos.DRIVER: 0.86, PoloPlayer.Pos.UTILITY: 0.93},
			"miss": {PoloPlayer.Pos.CENTER: 0.16, PoloPlayer.Pos.DEFENDER: 1.67, PoloPlayer.Pos.DRIVER: 1.11, PoloPlayer.Pos.UTILITY: 1.07},
			"block": {PoloPlayer.Pos.CENTER: 0.28, PoloPlayer.Pos.DEFENDER: 0.07, PoloPlayer.Pos.DRIVER: 2.48, PoloPlayer.Pos.UTILITY: 0.78}}},
}

## In a game you play, form moves a man's ratings by this much per star of form (+8 VERY HOT,
## +4 HOT): shooting, passing, defence and blocks, steals, keeping. Since the Hot Star Gameplay
## update that's his attribute bonus on the 0-100 scale (Attributes.HOT_RATING_PER_POINT, the
## same +4 / +8, PoloPlayer.live), with the attribute effects reading the bonus itself. NOT from the spec: a tuning number. A full star of form is about the
## gap between a bottom program's starter and a top one's, so it shows without taking over.
const RATING_PER_STAR := 8.0

## Player overall <-> stars, for players made from ratings (walk-ons, older saves): the scale
## the 18-man and seven-man rosters were built on (CollegeGen.quality_for_ovr), where a star
## is 12 team-rating points and a team point is 0.3 of a player's overall, plus STARTER_EDGE:
## an 18-man program's starting seven were its best, about 5 above its roster's level, and a
## seven-man roster is built at that level so the pool plays as it did (a five-star is a
## starter of the best programs, 69; two and a half stars one of the weakest's, 60).
const OVERALL_PER_STAR := 3.6
const STARTER_EDGE := 5.0

# ------------------------------------------------------------------ stars
static func snap_half(v: float) -> float:
	return roundf(v * 2.0) / 2.0

static func clamp_stars(v: float, hi: float = MAX_STARS) -> float:
	return clampf(snap_half(v), MIN_STARS, hi)

## The hidden value of a star rating (1.0 -> 44 .. 5.0 -> 92, 5.5 -> 96, 6.0 -> 99), whole.
static func star_value(stars: float) -> int:
	return roundi(star_points(stars))

## The same, unrounded, for any number of stars (stars are no longer whole halves): straight
## lines between STAR_VALUE's points, and 12 a star below one star (0 stars -> 32).
static func star_points(stars: float) -> float:
	var h := clampf(stars * 2.0, 0.0, 12.0)
	if h <= 2.0:
		return 44.0 - (2.0 - h) * 6.0
	var lo := floori(h)
	if lo >= 12:
		return float(STAR_VALUE[12])
	return lerpf(float(STAR_VALUE[lo]), float(STAR_VALUE[lo + 1]), h - lo)

static func star_word(stars: float) -> String:
	return String(STAR_WORDS.get(clampi(roundi(stars * 2.0), 2, 10), ""))

## "3.5" / "5" / "3.25" for text (two decimals at most).
static func star_text(stars: float) -> String:
	var s := snappedf(stars, 0.01)
	if is_equal_approx(s, floorf(s)):
		return "%d" % int(s)
	return ("%.1f" % s) if is_equal_approx(s, roundf(s * 10.0) / 10.0) else ("%.2f" % s)

## A player just made from 0-100 ratings (CollegeGen, an old save from before stars): his four
## attributes made from them (Attributes.from_legacy) at OVERALL = his overall on the star scale
## and POTENTIAL = his ceiling on it, unrounded. Stars follow from those.
static func rate_new(p: PoloPlayer) -> void:
	var o := p.legacy_overall()
	p.attrs = {}
	p.attr_pot = {}
	if p.pro:
		Attributes.from_legacy(p, Attributes.pro_ten_of(o), Attributes.pro_ten_of(maxf(p.pot, o)))
	else:
		Attributes.from_legacy(p, Attributes.ten_of(o), Attributes.ten_of(maxf(p.pot, o)))
	p.star_base = snappedf(p.overall(), 0.0001)
	p.stars_locked = p.stars

## The off-season roster lock: his stars already show the year's development (they are his
## attributes' average); this marks where they stand for next year's report and returns how far
## they moved since the last lock.
static func develop(p: PoloPlayer) -> float:
	var before := p.stars_locked if p.stars_locked >= 0.0 else p.stars
	p.stars_locked = p.stars
	p.star_base = snappedf(p.overall(), 0.0001)
	return snappedf(p.stars - before, 0.0001)

# ------------------------------------------------------------------ form
## The form a HEAT level is (0 NORMAL, 1 HOT, 2 VERY HOT), and back.
static func state_of(heat: int) -> String:
	return LEVELS[clampi(heat, 0, LEVELS.size() - 1)]

static func level_of(state: String) -> int:
	return maxi(0, LEVELS.find(state))

## The red stars a form shows after the gold ones (Deck.star_fills caps them at the bar's end).
static func red_stars(state: String) -> int:
	return level_of(state)

static func form_color(state: String) -> Color:
	return FIRE_RED if level_of(state) > 0 else GOLD

## EFFECTIVE stars: CURRENT plus form, 0.0-6.0.
static func effective(stars: float, state: String) -> float:
	return clampf(stars + float(FORM_STARS.get(state, 0.0)), MIN_STARS, MAX_EFFECTIVE)

## Where a player stands on the way to (or from) his red stars, for the back of his card: read
## from the same things that move his HEAT (his RUN over the last FORM_GAMES grades, his level,
## HOT_AT / VERY_HOT_AT to go up, HOT_HOLD / VERY_HOT_HOLD to stay), so it is never a separate
## count. {status, stars (his red stars now), bar (0..1), bar_label, next, cooling}:
##   NORMAL, RUN 0 or less   NEUTRAL       bar RUN / HOT_AT towards the first red star
##   NORMAL, RUN above 0     HEATING UP    the same
##   HOT, RUN at HOT_AT+     HOT           bar RUN / VERY_HOT_AT towards the second
##   HOT, RUN under HOT_AT   COOLING DOWN  bar = what's left before he drops: (RUN - HOT_HOLD + 1)
##                                         over (HOT_AT - HOT_HOLD + 1); one more point down, NORMAL
##   VERY HOT                ON FIRE       the maximum; bar = what's left before he drops the same
##                                         way, COOLING DOWN once his last game wasn't GOOD and he's
##                                         at VERY_HOT_HOLD
## A run moves both ways: bad games take it back, and grades older than FORM_GAMES drop out.
static func momentum(p: PoloPlayer) -> Dictionary:
	var run := run_score(p.form) + p.heat_bonus   # (a coaching decision's HOT STAR PROGRESS: part of a GOOD grade)
	var last := int(p.form[p.form.size() - 1]) if not p.form.is_empty() else 0
	var lv := clampi(p.heat, 0, LEVELS.size() - 1)
	var keep := func(hold: int, at: int) -> float:
		return clampf(float(run - hold + 1) / float(at - hold + 1), 0.0, 1.0)
	match lv:
		0:
			# (shut out by the HOT SLOTS cap: his run is there, a spot isn't; he has to outplay one)
			return {"status": "HEATING UP" if run > 0 else "NEUTRAL", "stars": 0, "bar": clampf(float(run) / HOT_AT, 0.0, 1.0),
				"bar_label": "HOT STAR PROGRESS", "next": "OUTPLAY A HOT TEAMMATE" if shut_out(p) and run >= HOT_AT else "1ST HOT STAR",
				"cooling": false}
		1:
			if run < HOT_AT:
				return {"status": "COOLING DOWN", "stars": 1, "bar": keep.call(HOT_HOLD, HOT_AT),
					"bar_label": "MOMENTUM", "next": "KEEP THE HOT STAR", "cooling": true}
			return {"status": "HOT", "stars": 1, "bar": clampf(float(run) / VERY_HOT_AT, 0.0, 1.0),
				"bar_label": "2ND HOT STAR PROGRESS", "next": "2ND HOT STAR", "cooling": false}
	var cooling := run <= VERY_HOT_HOLD and last < GOOD
	return {"status": "COOLING DOWN" if cooling else "ON FIRE", "stars": 2, "bar": keep.call(VERY_HOT_HOLD, FORM_GAMES),
		"bar_label": "MOMENTUM", "next": "MAX HOT STARS", "cooling": cooling}

## A run of grades scored: GOOD games less BAD ones.
static func run_score(grades: Array) -> int:
	var n := 0
	for g in grades:
		n += int(g)
	return n

## The level a run of grades points to for a player now at `heat` (HOT_AT .. VERY_HOT_HOLD).
## `bonus`: HOT STAR PROGRESS from a coaching decision (part of a GOOD grade, never a whole one).
static func target_heat(grades: Array, heat: int, bonus := 0.0) -> int:
	var run := run_score(grades) + bonus
	if run >= VERY_HOT_AT or (heat >= 2 and run >= VERY_HOT_HOLD):
		return 2
	if run >= HOT_AT or (heat >= 1 and run >= HOT_HOLD):
		return 1
	return 0

## His HEAT after a game: one level towards where his run points.
static func next_heat(grades: Array, heat: int, bonus := 0.0) -> int:
	var want := target_heat(grades, heat, bonus)
	return clampi(heat + signi(want - heat), 0, LEVELS.size() - 1)

## Adds a grade to a player's history, keeping the last FORM_GAMES, and moves his heat.
static func push_grade(p: PoloPlayer, grade: int) -> void:
	p.form.append(clampi(grade, BAD, GOOD))
	while p.form.size() > FORM_GAMES:
		p.form.pop_front()
	var was := p.heat
	p.heat = next_heat(p.form, p.heat, p.heat_bonus)
	if p.heat > was:
		p.heat_bonus = 0.0   # (a coaching boost is spent once it's lifted him a level)

## A save from before two-level heat (HOT/COLD from the sum of three grades): HOT only if those
## grades already make a run (three GOOD games), never VERY HOT; cold form is simply NORMAL.
static func legacy_heat(grades: Array) -> int:
	return mini(1, target_heat(grades, 0))

## A new season: everyone starts NORMAL with no grades (permanent stars stay as they are).
static func reset(p: PoloPlayer) -> void:
	p.form = []
	p.heat = 0
	p.heat_bonus = 0.0
	p.last_game = {}

# ------------------------------------------------------------------ the grade
static func grade_of(pm: float) -> int:
	var v := snappedf(pm, 0.01)
	if v >= snappedf(good_at(), 0.01):
		return GOOD
	if v <= BAD_AT:
		return BAD
	return 0

## RAW points from a stat line: field {g, sh, ed, bl, ga}; keeper {sv, ga} (with gk: true).
static func raw_points(line: Dictionary) -> float:
	if bool(line.get("gk", false)):
		return PTS_SAVE * int(line.get("sv", 0)) + PTS_KEEPER_GA * int(line.get("ga", 0))
	var goals := int(line.get("g", 0))
	var misses := maxi(0, int(line.get("sh", goals)) - goals)
	return PTS_GOAL * goals + PTS_EXCL * int(line.get("ed", 0)) + PTS_BLOCK * int(line.get("bl", 0)) \
		+ PTS_MISS * misses + PTS_FIELD_GA * int(line.get("ga", 0))

## Each player's share of `field` by `weight` (a Callable on a PoloPlayer): {id: 0..1}.
static func _shares(field: Array, weight: Callable) -> Dictionary:
	var total := 0.0
	for p: PoloPlayer in field:
		total += maxf(0.0, float(weight.call(p)))
	var out := {}
	for p: PoloPlayer in field:
		out[p.id] = maxf(0.0, float(weight.call(p))) / total if total > 0.0 else 1.0 / maxf(1.0, field.size())
	return out

## A simulated game's scorers and shooters (GameSim) go by shooting to this power: 2 once, 1
## since the Conference Awards: a team's goals spread over its shooters, its best still the most.
const SHOT_POW := 1.0

static func shot_weight(p: PoloPlayer) -> float:
	return pow(float(p.shoot), SHOT_POW)

## Who loses the ball in a simulated game: the weaker passers likelier.
static func turnover_weight(p: PoloPlayer) -> float:
	return pow(maxf(5.0, 110.0 - float(p.passing)), 1.5)

## Who's sent out for an exclusion `drawer` drew: a centre's own defender (the centre-D) most
## often when a centre drew it, else anyone, the stronger likelier.
static func excl_commit_weight(p: PoloPlayer, drawer: PoloPlayer) -> float:
	var w := pow(float(p.strength), 2.0)
	if drawer != null and drawer.pos == PoloPlayer.Pos.CENTER and p.pos == PoloPlayer.Pos.DEFENDER:
		w *= 3.0
	return w

static func block_weight(p: PoloPlayer) -> float:
	return pow(float(p.defense), 2.0)

static func excl_weight(p: PoloPlayer, center_mult: float) -> float:
	return pow(float(p.strength), 2.0) * (center_mult if p.pos == PoloPlayer.Pos.CENTER else 1.0)

## EXPECTED RAW for each of `t`'s seven, before the game: {id: points}. `xg` is [ours, theirs]
## from the engine before the game (GameSim.pregame_expected); `env` "sim" or "played".
static func expected(t: PoloTeam, xg: Array, env: String) -> Dictionary:
	var e: Dictionary = ENV.get(env, ENV["sim"])
	var seven := t.starters()
	var out := {}
	if seven.is_empty():
		return out
	var g := float(xg[0]) * float(e.goals)
	var a := float(xg[1]) * float(e.goals)
	var poss := float(e.poss)
	var misses := maxf(0.0, poss - g) * float(e.miss)
	var blocks := maxf(0.0, poss - a) * float(e.block)
	var excl := float(e.excl)
	var field: Array = seven.slice(1)
	var pos: Dictionary = e.get("pos", {})
	var by_pos := func(kind: String, p: PoloPlayer) -> float: return float(pos.get(kind, {}).get(p.pos, 1.0))
	var goal := _shares(field, func(p): return shot_weight(p) * by_pos.call("goal", p))
	var miss := _shares(field, func(p): return shot_weight(p) * by_pos.call("miss", p))
	var blk := _shares(field, func(p): return block_weight(p) * by_pos.call("block", p))
	var exc := _excl_shares(field, e)
	var gk: PoloPlayer = seven[0]
	out[gk.id] = snappedf(PTS_SAVE * maxf(0.0, poss - a) * float(e.save) + PTS_KEEPER_GA * a, 0.01)
	for p: PoloPlayer in field:
		var v := PTS_GOAL * g * float(goal[p.id]) + PTS_EXCL * excl * float(exc[p.id]) \
			+ PTS_BLOCK * blocks * float(blk[p.id]) + PTS_MISS * misses * float(miss[p.id]) + PTS_FIELD_GA * a
		out[p.id] = snappedf(v, 0.01)
	return out

## Each field player's share of the exclusions: by strength squared, the centre's counted
## CENTER_EXCL times; or, where the environment says so, CENTER_SHARE to the centre (the first,
## if there are two) and the rest shared out among the others the same way.
static func _excl_shares(field: Array, e: Dictionary) -> Dictionary:
	var cm := float(e.center_excl)
	if not e.has("center_share"):
		return _shares(field, func(p): return excl_weight(p, cm))
	var centers := field.filter(func(p: PoloPlayer): return p.pos == PoloPlayer.Pos.CENTER)
	if centers.is_empty():
		return _shares(field, func(p): return excl_weight(p, cm))
	var c: PoloPlayer = centers[0]
	var rest := _shares(field.filter(func(p): return p != c), func(p): return excl_weight(p, cm))
	var cs := float(e.center_share)
	var out := {c.id: cs}
	for id in rest:
		out[id] = float(rest[id]) * (1.0 - cs)
	return out

## The numbers from his stat line kept with his last game (the profile's LAST GAME).
const LINE_FIELD := ["g", "bl", "ed"]
const LINE_KEEPER := ["sv", "ga"]

## Grades `t`'s seven after a game and moves their form. `lines`: {id: stat line} (raw_points);
## `exp`: expected() made before the game. Returns one row a player, keeper first:
## {p, raw, exp, pm, grade, before, after, eff_before, eff_after}.
## Then the HOT SLOTS cap (limit_hot) settles who may actually heat up, before "after" is read.
## A row also carries "bumped_by" (the player who took his HOT spot) or "capped" (his run earned a
## red star but there was no spot he could win) when that happened to him.
static func grade_team(t: PoloTeam, lines: Dictionary, exp: Dictionary) -> Array:
	trim_hot(t)
	var out: Array = []
	var bonus_before := {}
	for p: PoloPlayer in t.starters():
		var line: Dictionary = lines.get(p.id, {"gk": p.is_keeper()})
		var raw := snappedf(raw_points(line), 0.01)
		var want := float(exp.get(p.id, 0.0))
		var pm := snappedf(raw - want, 0.01)
		var grade := grade_of(pm)
		var before := p.form_state()
		var eff_before := p.eff_stars()
		bonus_before[p.id] = p.heat_bonus
		push_grade(p, grade)
		p.last_game = {"raw": raw, "exp": want, "pm": pm, "gr": grade, "was": before}
		for k in LINE_KEEPER if p.is_keeper() else LINE_FIELD:
			p.last_game[k] = int(line.get(k, 0))
		out.append({"p": p, "raw": raw, "exp": want, "pm": pm, "grade": grade, "before": before,
			"eff_before": eff_before})
	limit_hot(t, out, bonus_before)
	for row in out:
		var p: PoloPlayer = row.p
		row["after"] = p.form_state()
		row["eff_after"] = p.eff_stars()
	return out

# ------------------------------------------------------------------ HOT SLOTS
## No team has more than HOT_SLOTS players with red stars at once (HOT and VERY HOT alike count
## one each), yours and the CPU's. The run of grades and any HOT STAR PROGRESS (form, heat_bonus)
## keep building for everyone; only the red stars themselves (heat) are limited. A slot frees
## when a hot player cools off, leaves the roster or is outplayed for it.
const HOT_SLOTS := 3

static func hot_count(t: PoloTeam) -> int:
	return t.roster.filter(func(q: PoloPlayer): return q.heat > 0).size()

## The game just graded (`rows`, grade_team's, each with "before" and "pm") pushed some NORMAL
## players up to HOT. Each heat that rose stands only if there's room:
##   1. those heating up go in order of this game's PM (best first; ties by RAW), and take any
##      free slots;
##   2. once the team is full, one must beat a hot teammate who played this same game, by
##      strictly more PM: the lowest-PM 1-star HOT player if there is any 1-star player on the
##      team at all (a VERY HOT one is never at risk while one is), else the lowest-PM VERY HOT;
##   3. whoever loses his spot goes back to NORMAL (his grades and progress stay his), and can't
##      lose a second one this update; nobody who got a spot this update can lose it to a later,
##      lower-scoring one;
##   4. one who doesn't get a spot stays NORMAL, his progress as it was before the game (the
##      coaching boost push_grade spent on the rise is given back).
## A player already HOT moving up to VERY HOT, or down, takes no new slot. Returns the changes,
## [{"in": PoloPlayer, "out": PoloPlayer or null}], with nobody "in" for a player shut out.
static func limit_hot(t: PoloTeam, rows: Array, bonus_before: Dictionary = {}) -> Array:
	var played := {}
	var entrants: Array = []
	for row in rows:
		var p: PoloPlayer = row.p
		played[p.id] = row
		if p.heat > 0 and level_of(String(row.before)) == 0:
			entrants.append(row)
	if entrants.is_empty():
		return []
	var rising := {}
	for row in entrants:
		rising[(row.p as PoloPlayer).id] = true
	var held := t.roster.filter(func(q: PoloPlayer): return q.heat > 0 and not rising.has(q.id))
	if held.size() + entrants.size() <= HOT_SLOTS:
		return []
	entrants.sort_custom(func(a, b):
		return float(a.pm) > float(b.pm) if not is_equal_approx(float(a.pm), float(b.pm)) else float(a.raw) > float(b.raw))
	var free := maxi(0, HOT_SLOTS - held.size())
	var fresh := {}       # got a spot this update: safe from the rest of it
	var replaced := {}    # lost one this update: can't lose another
	var out: Array = []
	for row in entrants:
		var p: PoloPlayer = row.p
		if free > 0:
			free -= 1
			fresh[p.id] = true
			held.append(p)
			continue
		var victim := _weakest_hot(held, played, fresh, replaced)
		# (PM is snapped to 0.01, so equal games compare exactly equal: a tie never takes a spot)
		if victim != null and float(row.pm) > float((played[victim.id] as Dictionary).pm):
			victim.heat = 0
			victim.last_game["bump"] = 1.0
			replaced[victim.id] = true
			held.erase(victim)
			held.append(p)
			fresh[p.id] = true
			(played[victim.id] as Dictionary)["bumped_by"] = p
			row["bumped"] = victim
			out.append({"in": p, "out": victim})
			continue
		# shut out: back to NORMAL, nothing of his progress lost
		p.heat = 0
		p.heat_bonus = float(bonus_before.get(p.id, p.heat_bonus))
		p.last_game["cap"] = 1.0
		row["capped"] = true
		out.append({"in": null, "out": null, "capped": p})
	return out

## The hot player an incoming one has to beat: among `held` (the team's hot players now), the
## 1-star ones if there are any, else the VERY HOT; of those, only who played this game (`played`,
## by id) and isn't protected (`fresh`) or already replaced, the lowest PM of the game. Null: none.
static func _weakest_hot(held: Array, played: Dictionary, fresh: Dictionary, replaced: Dictionary) -> PoloPlayer:
	var ones := held.filter(func(q: PoloPlayer): return q.heat == 1)
	var pool := ones if not ones.is_empty() else held.filter(func(q: PoloPlayer): return q.heat >= 2)
	var best: PoloPlayer = null
	var best_pm := INF
	for q: PoloPlayer in pool:
		if not played.has(q.id) or fresh.has(q.id) or replaced.has(q.id):
			continue
		var pm := float((played[q.id] as Dictionary).pm)
		if pm < best_pm:
			best_pm = pm
			best = q
	return best

## A team over the cap (a save from before it): the HOT_SLOTS hottest keep their red stars
## (VERY HOT first, then the better last game), the rest go back to NORMAL, their grades kept.
## True if anyone changed.
static func trim_hot(t: PoloTeam) -> bool:
	var hot := t.roster.filter(func(q: PoloPlayer): return q.heat > 0)
	if hot.size() <= HOT_SLOTS:
		return false
	hot.sort_custom(func(a: PoloPlayer, b: PoloPlayer):
		if a.heat != b.heat:
			return a.heat > b.heat
		return float(a.last_game.get("pm", 0.0)) > float(b.last_game.get("pm", 0.0)))
	for i in range(HOT_SLOTS, hot.size()):
		(hot[i] as PoloPlayer).heat = 0
	return true

## His run says HOT but the team's spots were full and he didn't outplay anyone for one.
static func shut_out(p: PoloPlayer) -> bool:
	return p.heat == 0 and float(p.last_game.get("cap", 0.0)) > 0.0

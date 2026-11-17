class_name Difficulty
## How hard a match plays: EASY, MEDIUM (saved as "normal"), HARD or DYNAMIC. A new dynasty
## starts at DYNAMIC (NEW_CAREER_MODE); Quick Match's default is MEDIUM. DYNAMIC starts halfway between EASY and MEDIUM (DYN_START)
## and follows how you've played your last few games.
##
## THE CPU'S TIMING AND PACE (the Difficulty Gameplay Balancing update): on top of its decisions,
## three things the other team does are quicker with the level, EASY exactly as first tuned
## (CPU, cpu_shot_speed / cpu_keeper_react / cpu_arm_delay): its shots' speed (fixed at the
## release, after the shooter's own SHOOTING and the pull have made it: a full pull gains most), its
## keeper's reaction and recognition (from what he can already see: never the aim, never a
## release's disguise), and its defenders' arm going up (the arm still rises in full before it
## blocks). Never your players, never their ratings, never a simulated game (GameSim).
##
## Difficulty is otherwise the opposing AI's intelligence, never its body. Everything reads one number,
## 0.0 (EASY) .. 0.5 (MEDIUM) .. 1.0 (HARD), and every AI decision that changes with it asks
## value() for one of the PARAMS below (straight lines between the three reference levels, so
## DYNAMIC's in-between levels are those same lines, not another engine). What it changes: how
## well the AI reads the play, how good the option it picks is, how often it makes a plain
## mistake. What it never changes: a rating or attribute, the ball's flight, a swimmer's speed,
## the keeper's reach, a shot's accuracy, a save or a steal once the play has happened. Team
## overall and stars are never read here either.
##
## Which AI it is: the other team's. Your own AI teammates (the defenders on their attack) play
## at TEAMMATES whatever you pick. Multiplayer is always MULTIPLAYER (it's you against a friend).
##
## DYNAMIC: the level is fixed when the match starts (MatchScreen reads level_for once) and only
## moves after a completed game (after_game): at most DYN_MAX_STEP a game, from the last
## DYN_WINDOW games' margins against what the matchup (the two teams' attributes) predicted. A
## career keeps its own level and history; Quick Match keeps another (Game.settings).

const MODES := ["dynamic", "easy", "normal", "hard"]
const NAMES := {"dynamic": "DYNAMIC", "easy": "EASY", "normal": "MEDIUM", "hard": "HARD"}
const FIXED := {"easy": 0.0, "normal": 0.5, "hard": 1.0}
const DEFAULT_MODE := "normal"
const MEDIUM := 0.5
## The game as first tuned (the old MEDIUM, EASY since the re-tier): your own AI teammates,
## multiplayer and every bench / default that means "the game as it plays" stay here.
const BASELINE := 0.0
const TEAMMATES := BASELINE
const MULTIPLAYER := BASELINE
const DYN_START := 0.25           # DYNAMIC starts halfway between EASY and MEDIUM
const DYN_MAX_STEP := 0.05        # the most one completed game moves DYNAMIC
const DYN_WINDOW := 5             # ...judged on this many recent games
const DYN_RECENT := 0.85          # each older game in the window counts this much less than the one after it
const DYN_DEADBAND := 0.15        # a window score inside this moves nothing (one result alone never gets past it)
const DYN_FULL := 0.6             # ...and from here it's a full step
## The matchup, from the two teams' starters' attributes (team_strength: never team overall or stars).
const GOALS_PER_POINT := 2.5      # the margin one attribute point of edge is expected to be worth
const PERF_GOALS := 4.0           # goals over (under) that expectation that count as a dominant (awful) game
const WIN_EDGE := 0.25            # a win (loss) on top of the margin
const MATCHUP_EVEN := 0.6         # attribute points apart and still a comparable opponent...
const MATCHUP_FAR := 1.6          # ...this far apart, a mismatch: the expected result barely counts
const MISMATCH_WEIGHT := 0.2

## The AI's decision parameters at EASY, MEDIUM, HARD (x, y, z). Re-tiered 2026-11-16: EASY is the
## old MEDIUM (the game as first tuned: BASELINE), MEDIUM the old HARD, HARD a new, harder level
## past it. (The old EASY is gone.)
const PARAMS := {
	# reading the play
	"recognize": Vector3(0.35, 0.11, 0.05),   # s a defender takes to see a man has inside water on him (CenterDefense)
	"read": Vector3(1.0, 1.45, 1.8),          # how sharply defenders re-read where they should be (PlayAI._defend)
	"switch": Vector3(1.0, 0.7, 0.5),         # the centre's guard waits this share of his time before going round
	# positioning and rotations (defence)
	"pos_err": Vector3(0.0, 0.0, 0.0),        # m a defender's spot can be off (a positioning mistake)
	"lane_deny": Vector3(0.45, 0.75, 0.95),   # m off his man into the passing lane from the ball
	"help": Vector3(0.35, 0.58, 0.75),        # how far the far side sags into the hole to help on the centre
	# offence (OffenseAI)
	"eval_noise": Vector3(0.03, 0.006, 0.0),  # how far off his judgement of a look or a pass can be
	"overlook": Vector3(0.04, 0.005, 0.0),    # each teammate: the chance he doesn't see him as an option this look
	"center_use": Vector3(1.0, 1.65, 2.0),    # how much he values getting it into the man at 2 m
	"aim_smart": Vector3(0.75, 0.96, 1.0),    # the shooter goes for the side the keeper isn't on (else a predictable spot)
	"exploit_see": Vector3(0.575, 0.8, 0.92), # the chance he sees a gap the defence has left (OffenseAI)
	"hold": Vector3(1.0, 0.78, 0.62),         # how long the man on the ball looks before he throws (hesitation)
	"press_react": Vector3(0.0, 0.10, 0.18),  # s sooner he reacts to the press getting to him
	# keepers (KeeperAI)
	"gk_read": Vector3(0.55, 0.93, 0.97),     # how well his anticipation reads the shot he can see (0 naive .. 1 sharp)
	"gk_temp": Vector3(1.0, 0.62, 0.42),      # how loosely he picks among his weights (higher: more random)
	"gk_memory": Vector3(0.35, 0.8, 1.0),     # how much he leans on where this team has been putting them
	"gk_pos_err": Vector3(0.12, 0.015, 0.0),  # m off where he means to set before the shot
	# the centre defender (CenterDefense)
	"cdef_noise": Vector3(0.08, 0.01, 0.0),   # how far off his valuing of recover / press / challenge / foul can be
	"pen_sense": Vector3(0.8, 1.0, 1.0),      # how much of what a penalty really costs he weighs (1: in full; no higher)
	# all of them
	"mistake": Vector3(0.03, 0.005, 0.0),     # a decision: the chance of a plainly worse option
}

## The CPU's timing and pace at EASY, MEDIUM, HARD (multipliers; EASY 1, the game as first tuned).
const CPU := {
	"shot_low": Vector3(1.0, 1.12, 1.2),      # its shots' speed, a soft pull (power 0.2)...
	"shot_high": Vector3(1.0, 1.28, 1.4),     # ...and a full one (power 1), smoothly between
	"gk_react": Vector3(1.0, 0.65, 0.5),      # its keeper's reaction and recognition delays (and his read of a hold)
	"gk_dive": Vector3(1.0, 1.15, 1.25),      # its keeper's dive (push off and rise to full stretch): this much quicker
	"gk_wing_early": Vector3(1.0, 0.8, 0.7),  # ...and on a wing's shot ("1", "5") early in the shot clock, his delays this much again
	"arm_delay": Vector3(1.0, 0.65, 0.5),     # its pressing defenders' delay before the arm starts up
}

## Your catch-and-shoot bonus window against the CPU at EASY, MEDIUM, HARD: its full-bonus window
## and its fade both this share of ShotModel's (10% / 25% / 50% smaller). Only your attack against
## the CPU (MatchFlow sets Play.cs_k): never the CPU's shots, multiplayer or a drill.
const CATCH_SHOOT := Vector3(0.9, 0.75, 0.5)

static func catch_shoot_k(l: float) -> float:
	l = clampf(l, 0.0, 1.0)
	if l <= MEDIUM:
		return lerpf(CATCH_SHOOT.x, CATCH_SHOOT.y, l / MEDIUM)
	return lerpf(CATCH_SHOOT.y, CATCH_SHOOT.z, (l - MEDIUM) / (1.0 - MEDIUM))

## The CPU's shot-speed multiplier at level `l` for a shot pulled to `power` (0.2 .. 1).
static func cpu_shot_speed(l: float, power: float) -> float:
	var t := clampf((power - 0.2) / 0.8, 0.0, 1.0)
	return lerpf(_line(CPU.shot_low, l), _line(CPU.shot_high, l), t)

## The CPU keeper's reaction-delay multiplier at level `l`.
static func cpu_keeper_react(l: float) -> float:
	return _line(CPU.gk_react, l)

## The CPU keeper's dive-speed multiplier at level `l` (KeeperDive.quick: his push off and rise).
static func cpu_keeper_dive(l: float) -> float:
	return _line(CPU.gk_dive, l)

## The CPU keeper's extra reaction multiplier at level `l` for a wing's shot, `early` 0 (late in
## the shot clock) .. 1 (early: Play.wing_early).
static func cpu_keeper_wing(l: float, early: float) -> float:
	return lerpf(1.0, _line(CPU.gk_wing_early, l), clampf(early, 0.0, 1.0))

## The CPU defenders' arm-raise-delay multiplier at level `l`.
static func cpu_arm_delay(l: float) -> float:
	return _line(CPU.arm_delay, l)

## Measurement only (--test ai_balance N nocpu): the CPU's timing and pace as first tuned (EASY's).
static var cpu_neutral := false

static func _line(v: Vector3, l: float) -> float:
	if cpu_neutral:
		return 1.0
	l = clampf(l, 0.0, 1.0)
	if l <= MEDIUM:
		return lerpf(v.x, v.y, l / MEDIUM)
	return lerpf(v.y, v.z, (l - MEDIUM) / (1.0 - MEDIUM))

## A parameter at level `l` (0..1): straight lines EASY - MEDIUM - HARD.
static func value(key: String, l: float) -> float:
	var v: Vector3 = PARAMS[key]
	l = clampf(l, 0.0, 1.0)
	if l <= MEDIUM:
		return lerpf(v.x, v.y, l / MEDIUM)
	return lerpf(v.y, v.z, (l - MEDIUM) / (1.0 - MEDIUM))

## Every parameter at level `l` (tests, the lab).
static func params(l: float) -> Dictionary:
	var out := {}
	for k in PARAMS:
		out[k] = value(k, l)
	return out

# ------------------------------------------------------------------ the mode and the level
## The mode in play: a career's own (picked with it, kept in its save), else the device's.
static func mode(career := false) -> String:
	var m := String(Game.settings.get("difficulty", DEFAULT_MODE))
	if career and Game.career != null and Game.career.difficulty in MODES:
		m = Game.career.difficulty
	return m if m in MODES else DEFAULT_MODE

## A NEW DYNASTY starts at DYNAMIC, whatever the device's pick and whichever school: the New
## Career screen opens on it (reset_new_career) and the player can switch there or any time
## later in Settings (set_mode: that career's own, kept in its save). Older saves keep theirs.
const NEW_CAREER_MODE := "dynamic"
static var new_career_pick := NEW_CAREER_MODE

static func reset_new_career() -> void:
	new_career_pick = NEW_CAREER_MODE

## The New Career screen's pick (only the career about to be made; Quick Match keeps its own).
static func pick_new_career(m: String) -> void:
	if m in MODES:
		new_career_pick = m

## The mode a career being made now starts at.
static func new_career_mode() -> String:
	return new_career_pick if new_career_pick in MODES else NEW_CAREER_MODE

## Picking a mode (Settings): the device's, and the loaded career's.
static func set_mode(m: String) -> void:
	if not m in MODES:
		return
	Game.settings.difficulty = m
	if Game.career != null:
		Game.career.difficulty = m
	Game.save_settings()

## The level for a career game (career = true) or a Quick Match, fixed for the whole match.
static func level_for(career: bool) -> float:
	var m := mode(career)
	if FIXED.has(m):
		return FIXED[m]
	return dyn_level(career)

static func dyn_level(career: bool) -> float:
	if career and Game.career != null:
		return clampf(Game.career.dyn_ai, 0.0, 1.0)
	return clampf(float(Game.settings.get("dyn_ai", DYN_START)), 0.0, 1.0)

## "DYNAMIC (MEDIUM)" and friends, for the settings and the hub.
static func label_for(career: bool) -> String:
	var m := mode(career)
	if m != "dynamic":
		return NAMES[m]
	return "DYNAMIC (%s)" % word(level_for(career))

static func word(l: float) -> String:
	if l < 0.25:
		return "EASY"
	if l < 0.75:
		return "MEDIUM"
	return "HARD"

## An older save's dynamic level (-1 easy .. 0 normal .. +1 hard) on this scale.
static func from_legacy(old: float) -> float:
	return clampf((old + 1.0) * 0.5, 0.0, 1.0)

# ------------------------------------------------------------------ DYNAMIC
## A completed game: goals for and against, and the two teams. Records it (career or Quick
## Match) and, on DYNAMIC, moves that level by step_for. Never during a match.
static func after_game(career: bool, gf: int, ga: int, us: PoloTeam, them: PoloTeam) -> void:
	var entry := game_entry(gf, ga, us, them)
	var hist: Array = Game.career.dyn_hist if career and Game.career != null else Game.settings.get("dyn_hist", [])
	hist = record(hist, entry)
	var moving := mode(career) == "dynamic"
	var l := dyn_level(career)
	if moving:
		l = clampf(l + step_for(hist), 0.0, 1.0)
	if career and Game.career != null:
		Game.career.dyn_hist = hist
		Game.career.dyn_ai = l
	else:
		Game.settings.dyn_hist = hist
		Game.settings.dyn_ai = l
		Game.save_settings()

## One game for the history: its margin and the attribute gap between the teams (yours less theirs).
static func game_entry(gf: int, ga: int, us: PoloTeam, them: PoloTeam) -> Dictionary:
	var gap := 0.0
	if us != null and them != null:
		gap = snappedf(team_strength(us) - team_strength(them), 0.001)
	return {"m": gf - ga, "gap": gap}

## The history with `entry` added, the last DYN_WINDOW kept.
static func record(hist: Array, entry: Dictionary) -> Array:
	var out := hist.duplicate(true)
	out.append(entry)
	while out.size() > DYN_WINDOW:
		out.pop_front()
	return out

## A team's strength for the matchup: its seven starters' average attribute OVERALL (0-10),
## permanent attributes only (no form, no stars, no team overall).
static func team_strength(t: PoloTeam) -> float:
	var xs := t.starters()
	if xs.is_empty():
		return 5.0
	var s := 0.0
	for p in xs:
		s += p.rating10()
	return s / xs.size()

## How one game went against what the matchup predicted, -1 (awful) .. +1 (dominant), and how
## much it counts: a comparable opponent fully; the expected result against a mismatch hardly
## at all (beating a much weaker team, losing to a much stronger one). An upset counts in full.
static func game_score(e: Dictionary) -> Vector2:
	var m := float(e.get("m", 0))
	var gap := float(e.get("gap", 0.0))
	var perf := clampf((m - gap * GOALS_PER_POINT) / PERF_GOALS + WIN_EDGE * signf(m), -1.0, 1.0)
	var w := 1.0
	var far := clampf((absf(gap) - MATCHUP_EVEN) / (MATCHUP_FAR - MATCHUP_EVEN), 0.0, 1.0)
	if far > 0.0 and signf(m) == signf(gap):
		w = lerpf(1.0, MISMATCH_WEIGHT, far)   # the result the mismatch predicted
	return Vector2(perf, w)

## The window's score: recent games weighted more, averaged over the whole window, so one or
## two results never add up to much on their own.
static func window_score(hist: Array) -> float:
	var s := 0.0
	var norm := 0.0
	for i in DYN_WINDOW:
		norm += pow(DYN_RECENT, i)
	for i in hist.size():
		var age := hist.size() - 1 - i
		var g := game_score(hist[i])
		s += g.x * g.y * pow(DYN_RECENT, age)
	return s / norm

## How far DYNAMIC moves after the latest game in `hist`: never more than DYN_MAX_STEP.
static func step_for(hist: Array) -> float:
	var sc := window_score(hist)
	if absf(sc) < DYN_DEADBAND:
		return 0.0
	return signf(sc) * DYN_MAX_STEP * clampf((absf(sc) - DYN_DEADBAND) / (DYN_FULL - DYN_DEADBAND), 0.0, 1.0)

# ------------------------------------------------------------------ the keeper duel
## The keeper duel's slow motion while you react to their shot. Your dive runs on screen time
## and the ball on game time, so this is part of the physics of your save: the same at every
## level (the original tuning's), never a difficulty assist.
const DUEL_SLOWMO := 0.55

static func duel_slowmo(_l: float = MEDIUM) -> float:
	return DUEL_SLOWMO

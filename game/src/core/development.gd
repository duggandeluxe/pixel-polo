class_name Development
## Player development (docs: "Complete Player Development, XP, Training & Injury Overhaul").
##
##   GAME PERFORMANCE + TRAINING -> his own XP -> a HIDDEN level -> one UPGRADE TOKEN -> one
##   permanent attribute point, bought by tapping that attribute's cyan box (spend).
##
## Every player has a hidden level (never shown anywhere: it only sets how much XP his next token
## costs, xp_required), his XP towards it, and the tokens he hasn't spent. The level starts from
## his four attributes (initial_level: their average x 2) and from then on only moves with XP.
## What a token costs counts from where he started (xp_start): his first is level 0 of the curve,
## every one after it dearer (Long-Term Player Development: a four-year process, not one season).
## Tokens and XP are his alone. Credits play no part in any of it.
##
## Training (training_xp) gives XP, never attributes: BALANCED a flat amount, a specialised focus
## more to players weaker in the attribute it works (SPECIALIZED_BASE + (10 - attribute) x 2),
## times the intensity's multiplier. Every completed week of training can injure (INJURY_RISK by
## intensity). An injury is a temporary penalty on some of his attributes (INJURIES): he still
## plays, at MAX(0, attribute - penalty) wherever the game reads that attribute (eff_value), and
## his stars, ceilings, XP, tokens and the team's overall never see it. RECOVERY week heals it.
## One injury at a time; nothing stacks.
##
## AI programs live by exactly the same rules (game XP from their stat lines, training, tokens),
## spending each token as it comes (ai_spend). No numbers here depend on difficulty.

# ------------------------------------------------------------------ the balance (all of it)
## (Long-Term Player Development: was 76 x 1.11 ^ hidden level; calibrated on whole simmed
## four-year careers, --test dev_career)
const XP_BASE := 450.0
const XP_GROWTH := 1.38
## The Development Maturity rebalance: on top of that curve, the first tokens cost REQ_LOW
## (+15%) and it eases off evenly to REQ_HIGH (-15%) REQ_REF_LEVELS levels in (about the most a
## player gets through in four years), staying there after: no new cap. It falls slower than the
## curve rises (1.38 a level against at most 0.0375), so every token still costs more than the last.
const REQ_LOW := 1.15     # (two floats, not a Vector2: its 32-bit 1.15 isn't 1.15)
const REQ_HIGH := 0.85
const REQ_REF_LEVELS := 8.0
## The saved curve: 3 this one (a save without it was made on CEIL(450 x 1.38^n): from_dict keeps
## his share of the way to his next token).
const CURVE_VERSION := 3
## The curve before it, for converting a saved player's progress (from_dict).
const OLD_XP_BASE := 76.0
const OLD_XP_GROWTH := 1.11
const GAME_XP_MIN := 0
## (XP Development Update 2.0: no per-game cap. A game pays everything its stat line earns,
## times his class's multiplier; only his remaining potential limits what it turns into.)
## Game XP per recorded stat. Every one of them is recorded per player in a played game
## (MatchState); a simulated game's line has only what GameSim generates, and a stat missing
## from a line simply awards nothing: nothing is ever made up.
const GOAL_XP := 20
const ASSIST_XP := 15
const STEAL_XP := 14
const BLOCK_XP := 14
const DRAWN_EXCLUSION_XP := 10
const DRAWN_PENALTY_XP := 18
const TURNOVER_XP := -4
const EXCLUSION_COMMITTED_XP := -4
const GOALKEEPER_SAVE_XP := 10
const GOAL_CONCEDED_XP := -1
const PARTICIPATION_XP := 8
const WIN_BONUS_XP := 8
## Game XP x his class (FR, SO, JR, SR), as whole percents so the rounding is exact half-up
## (1.15 in floating point would turn 10 x 1.15 = 11.5 into 11). Game XP only: training, event
## cards and recovery never see it. (Development Maturity: older players earn more; it was
## 150 / 130 / 115 / 100, freshmen first.)
const CLASS_XP_PCT := [100, 80, 95, 110, 125]
## Stat-line keys -> XP. Field players and keepers count different things (a keeper's goals
## conceded cost him; a field player's "ga" is only the score, so it doesn't).
const FIELD_XP := {"g": GOAL_XP, "a": ASSIST_XP, "st": STEAL_XP, "bl": BLOCK_XP, "ed": DRAWN_EXCLUSION_XP,
	"pd": DRAWN_PENALTY_XP, "to": TURNOVER_XP, "ex": EXCLUSION_COMMITTED_XP}
const KEEPER_XP := {"sv": GOALKEEPER_SAVE_XP, "st": STEAL_XP, "a": ASSIST_XP, "g": GOAL_XP, "ga": GOAL_CONCEDED_XP}

const BALANCED_TRAINING_XP := 12
const SPECIALIZED_BASE_XP := 8
const SPECIALIZED_WEAKNESS_MULTIPLIER := 2
const GOALKEEPER_SHOOTING_TRAINING_XP := 5
const LIGHT_XP_MULTIPLIER := 0.75
const NORMAL_XP_MULTIPLIER := 1.00
const HARD_XP_MULTIPLIER := 1.50
const LIGHT_INJURY_RISK := 0.01
const NORMAL_INJURY_RISK := 0.03
const HARD_INJURY_RISK := 0.08
const MINOR_INJURY_CHANCE := 0.75
const MODERATE_INJURY_CHANCE := 0.25
## An event card's "+N rating" (Career.apply_effects) is now N x this much XP.
const CARD_XP_PER_POINT := 15

## Intensity 1 LIGHT, 2 NORMAL, 3 HARD (Career.training.intensity).
const XP_MULT := [0.0, LIGHT_XP_MULTIPLIER, NORMAL_XP_MULTIPLIER, HARD_XP_MULTIPLIER]
const INJURY_RISK := [0.0, LIGHT_INJURY_RISK, NORMAL_INJURY_RISK, HARD_INJURY_RISK]
## The attribute each specialised focus works: [field player's, keeper's]. "" for a keeper is the
## small flat amount (GOALKEEPER_SHOOTING_TRAINING_XP): keepers have no Shooting. Swimming and
## Defense both work a field player's Defense, on purpose.
const FOCUS_ATTR := {"shooting": ["sho", ""], "passing": ["pas", "com"], "swimming": ["dfn", "lun"],
	"strength": ["str", "leg"], "defense": ["dfn", "blk"]}

# ------------------------------------------------------------------ injuries
## type -> severity -> {attribute: penalty}. Keepers only ever get "head" (KEEPER_HEAD).
const INJURIES := {
	"shoulder": {"minor": {"sho": 1}, "moderate": {"sho": 2, "pas": 1}},
	"hip": {"minor": {"str": 1}, "moderate": {"str": 2}},
	"head": {"minor": {"dfn": 1}, "moderate": {"dfn": 2}},
}
const KEEPER_HEAD := {"minor": {"com": 1, "lun": 1, "blk": 1, "leg": 1},
	"moderate": {"com": 2, "lun": 2, "blk": 2, "leg": 2}}
## Which injury, once one happens: field players by these odds (in order), keepers always head.
const FIELD_TYPES := [["shoulder", 0.40], ["hip", 0.35], ["head", 0.25]]
const TYPE_NAMES := {"shoulder": "SHOULDER", "hip": "HIP", "head": "HEAD"}

# ------------------------------------------------------------------ hidden level & XP
## Every XP award by player id, before his potential trims it ({} to record, null off): the
## balance reports read it.
static var xp_log = null

## The hidden level a player starts at: his four attributes' average x 2, rounded down, at least 1.
static func initial_level(p: PoloPlayer) -> int:
	if p.attrs.is_empty():
		return 1
	# (the average of 4-decimal attributes is exact at 6 decimals: 5.5 never reads as 5.4999999)
	return maxi(1, floori(Attributes.snap(Attributes.overall(p), 1000000.0) * 2.0))

## XP a token costs `n` levels into his development (0: his first): the curve times where he is on
## it, CEIL(XP_BASE x XP_GROWTH ^ n x req_mod(n)), >= 1.
static func xp_required(n: int) -> int:
	var k := clampi(n, 0, 200)
	return maxi(1, ceili(snappedf(XP_BASE * pow(XP_GROWTH, float(k)) * req_mod(k), 0.000001)))

## How much dearer (or cheaper) than the curve a token is `n` levels in: REQ_LOW at his first,
## evenly down to REQ_HIGH at REQ_REF_LEVELS and on.
static func req_mod(n: int) -> float:
	return lerpf(REQ_LOW, REQ_HIGH, clampf(float(n) / REQ_REF_LEVELS, 0.0, 1.0))

## The curve as it was before the rebalance (save conversion only): CEIL(XP_BASE x XP_GROWTH ^ n).
static func lt_xp_required(n: int) -> int:
	return maxi(1, ceili(XP_BASE * pow(XP_GROWTH, float(clampi(n, 0, 200)))))

## The old curve's requirement at hidden level `level` (save conversion only).
static func old_xp_required(level: int) -> int:
	return maxi(1, roundi(OLD_XP_BASE * pow(OLD_XP_GROWTH, float(clampi(level, 0, 200)))))

## How many levels into his development he is: the curve's index for his next token.
static func level_index(p: PoloPlayer) -> int:
	ensure(p)
	return maxi(0, p.xp_level - p.xp_start)

static func xp_needed(p: PoloPlayer) -> int:
	return xp_required(level_index(p))

## Gives a player his hidden level the first time (a new player, or one from an older save), and
## where his development counts from (his level then; never above what he has). Does nothing once
## he has them: the level then only moves with XP.
static func ensure(p: PoloPlayer) -> void:
	if p.xp_level <= 0:
		p.xp_level = initial_level(p)
	if p.xp_start < 0:
		p.xp_start = mini(p.xp_level, initial_level(p))
	p.xp = maxi(0, p.xp)
	p.tokens = maxi(0, p.tokens)

## Adds `amount` XP (never less than nothing) and works through every token it pays for: each
## time his XP reaches the requirement it's taken off (the rest carries over), his hidden level
## goes up one and he gets exactly one token, as many times as it pays for. Never past his
## potential: once the tokens he holds cover every box left under his ceilings, development
## stops and the XP left over is dropped (reconcile). Returns the tokens earned.
static func award_xp(p: PoloPlayer, amount: int) -> int:
	ensure(p)
	if xp_log != null and amount > 0:
		xp_log[p.id] = int(xp_log.get(p.id, 0)) + amount
	reconcile(p)
	if amount <= 0 or p.tokens >= boxes_left(p):
		return 0
	p.xp = mini(p.xp + amount, 1 << 30)
	var earned := 0
	while p.xp >= xp_needed(p) and p.tokens < boxes_left(p):
		p.xp -= xp_needed(p)
		p.xp_level += 1
		p.tokens += 1
		earned += 1
	reconcile(p)
	return earned

## 0..1 of the way to his next token (the profile's bar).
static func progress(p: PoloPlayer) -> float:
	return clampf(float(p.xp) / float(xp_needed(p)), 0.0, 1.0)

# ------------------------------------------------------------------ potential
## How many upgrades his four attributes can still take: per attribute, the tokens spend()
## would accept before it reaches its ceiling (a part point of room still takes one).
static func boxes_left(p: PoloPlayer) -> int:
	var n := 0
	for k in p.key_ratings():
		var room := Attributes.room(p, k)
		if room >= Attributes.PRECISION:
			n += ceili(room - Attributes.PRECISION)
	return n

## Every permanent attribute at its ceiling (never his injury, his stars or his form).
static func is_maxed(p: PoloPlayer) -> bool:
	return not has_room(p)

## Keeps his development inside his potential: never more tokens than boxes left to buy, and
## once his tokens cover them all, no XP banked towards another. A fully developed player
## therefore holds no XP and no tokens. Safe to run any number of times.
static func reconcile(p: PoloPlayer) -> void:
	var left := boxes_left(p)
	p.tokens = clampi(p.tokens, 0, left)
	if p.tokens >= left:
		p.xp = 0

## Tokens he must spend before another game: his, and every one usable.
static func pending(p: PoloPlayer) -> int:
	return mini(p.tokens, boxes_left(p))

# ------------------------------------------------------------------ game XP
## One game's XP from his stat line (keys as in FIELD_XP / KEEPER_XP; anything else is ignored):
## the base (every stat, +PARTICIPATION_XP for playing, +WIN_BONUS_XP for a win), then
## MAX(0, ROUND(base x his class multiplier)). No cap.
static func game_xp(p: PoloPlayer, line: Dictionary, won: bool) -> int:
	var base := base_game_xp(p, line, won)
	if base <= 0:
		return GAME_XP_MIN
	return (base * class_pct(p) + 50) / 100

## The base before his class multiplier (may be negative).
static func base_game_xp(p: PoloPlayer, line: Dictionary, won: bool) -> int:
	var table: Dictionary = KEEPER_XP if p.is_keeper() else FIELD_XP
	var xp := PARTICIPATION_XP + (WIN_BONUS_XP if won else 0)
	for k in table:
		xp += int(table[k]) * clampi(int(line.get(k, 0)), 0, 10000)
	return xp

## His class's game XP multiplier as a whole percent (his current year: it moves with him).
static func class_pct(p: PoloPlayer) -> int:
	return int(CLASS_XP_PCT[clampi(p.year, 1, 4)])

## Every player who played in one finished game: their stat lines ({id: line}), XP awarded.
## Returns {id: {"xp": n, "tokens": n}}.
## `mults` ({id: m}): a coaching decision's one multiplier on a player's positive game XP
## (CoachEvents.award_game: never two at once); then each also has "base" (before it) and "mult".
static func award_game(t: PoloTeam, lines: Dictionary, won: bool, mults: Dictionary = {}) -> Dictionary:
	var out := {}
	for id in lines:
		var p := t.find_id(int(id))
		if p == null:
			continue
		var base := game_xp(p, lines[id], won)
		var xp := base
		var m := float(mults.get(p.id, 1.0))
		if base > 0 and not is_equal_approx(m, 1.0):
			xp = roundi(base * m)
		var tk := award_xp(p, xp)
		out[p.id] = {"xp": xp, "tokens": tk}
		if mults.has(p.id):
			out[p.id]["base"] = base
			out[p.id]["mult"] = m
	return out

## A game's stat lines for one side, from what it recorded: who played (participation), every
## goal, assist, steal, block and exclusion drawn, the keeper's saves and goals against.
## `played`: the PoloPlayers in the water; `lists`: {"g": [players], "a": [...], ...} (one entry
## an event); `keeper`/`saves`/`against` for the man in goal; `extra`: {id: {key: n}} more counts
## from a stat line (a simulated game's blocks and exclusions drawn).
static func lines_of(played: Array, lists: Dictionary, keeper: PoloPlayer, saves: int, against: int, extra: Dictionary = {}) -> Dictionary:
	var out := {}
	for p: PoloPlayer in played:
		out[p.id] = {}
	for k in lists:
		for p: PoloPlayer in lists[k]:
			if p != null and out.has(p.id):
				out[p.id][k] = int(out[p.id].get(k, 0)) + 1
	for id in extra:
		if out.has(id):
			for k in extra[id]:
				if not (out[id] as Dictionary).has(k):
					out[id][k] = int(extra[id][k])
	if keeper != null and out.has(keeper.id):
		out[keeper.id]["sv"] = saves
		out[keeper.id]["ga"] = against
	return out

# ------------------------------------------------------------------ training
## One week's base XP (before intensity) for `focus`. RECOVERY gives none.
static func training_base(p: PoloPlayer, focus: String) -> int:
	if focus == "recovery":
		return 0
	if not FOCUS_ATTR.has(focus):
		return BALANCED_TRAINING_XP
	var key: String = FOCUS_ATTR[focus][1 if p.is_keeper() else 0]
	if key == "":
		return GOALKEEPER_SHOOTING_TRAINING_XP
	# his permanent attribute (never the injured one, never his form), whole points
	var a := clampi(floori(Attributes.value(p, key) + Attributes.PRECISION), 0, int(Attributes.MAX))
	return SPECIALIZED_BASE_XP + (int(Attributes.MAX) - a) * SPECIALIZED_WEAKNESS_MULTIPLIER

## A week's XP: ROUND(base x the intensity's multiplier) (x `extra`, an event's training bonus).
static func training_xp(p: PoloPlayer, focus: String, intensity: int, extra: float = 1.0) -> int:
	var m: float = XP_MULT[clampi(intensity, 1, 3)]
	return maxi(0, roundi(float(training_base(p, focus)) * m * maxf(0.0, extra)))

## The chance a week at `intensity` injures one player (a better medical room takes some off).
static func injury_risk(intensity: int, medical: int = 1) -> float:
	return float(INJURY_RISK[clampi(intensity, 1, 3)]) * (1.0 - 0.12 * (clampi(medical, 1, 5) - 1))

## One completed week of training for a whole roster: XP for everyone, then each healthy player
## may get hurt. RECOVERY heals everyone instead (no XP, no injuries). Returns
## {xp: {id: n}, tokens: {id: n}, hurt: [ids], healed: [ids]}.
static func train_team(t: PoloTeam, focus: String, intensity: int, rng: RandomNumberGenerator, medical: int = 1,
		extra: float = 1.0) -> Dictionary:
	var out := {"xp": {}, "tokens": {}, "hurt": [], "healed": []}
	if focus == "recovery":
		for p in t.roster:
			if heal(p):
				out.healed.append(p.id)
		return out
	var risk := injury_risk(intensity, medical)
	for p in t.roster:
		var xp := training_xp(p, focus, intensity, extra)
		out.xp[p.id] = xp
		var tk := award_xp(p, xp)
		if tk > 0:
			out.tokens[p.id] = tk
	for p in t.roster:
		if not is_injured(p) and rng.randf() < risk:
			injure(p, rng)
			out.hurt.append(p.id)
	return out

# ------------------------------------------------------------------ injuries
static func is_injured(p: PoloPlayer) -> bool:
	return p.inj_type != ""

## His injury's penalty on one attribute (0 healthy, or an attribute it doesn't touch).
static func penalty(p: PoloPlayer, key: String) -> int:
	return int(penalties(p).get(key, 0))

## {attribute: penalty} for his injury ({} healthy).
static func penalties(p: PoloPlayer) -> Dictionary:
	if p.inj_type == "":
		return {}
	if p.is_keeper():
		return KEEPER_HEAD.get(p.inj_sev, {})
	return INJURIES.get(p.inj_type, {}).get(p.inj_sev, {})

## An attribute as he plays it today: MAX(0, permanent - injury penalty).
static func eff_value(p: PoloPlayer, key: String) -> float:
	return maxf(0.0, Attributes.value(p, key) - penalty(p, key))

## Hurts him (type and severity rolled now: field players by FIELD_TYPES, keepers always head;
## MINOR_INJURY_CHANCE minor). A player who's already hurt keeps the injury he has: they never
## stack. `sev` forces the severity ("" rolls it). Returns whether it happened.
static func injure(p: PoloPlayer, rng: RandomNumberGenerator, sev: String = "", type: String = "") -> bool:
	if is_injured(p):
		return false
	if type == "" or p.is_keeper():
		type = "head"
		if not p.is_keeper():
			var roll := rng.randf()
			for ft in FIELD_TYPES:
				roll -= float(ft[1])
				if roll < 0.0:
					type = String(ft[0])
					break
	if sev == "":
		sev = "minor" if rng.randf() < MINOR_INJURY_CHANCE else "moderate"
	p.inj_type = type
	p.inj_sev = sev
	Attributes.sync(p)
	return true

## Heals him. Returns whether he was hurt.
static func heal(p: PoloPlayer) -> bool:
	if not is_injured(p):
		return false
	p.inj_type = ""
	p.inj_sev = ""
	Attributes.sync(p)
	return true

## "MODERATE SHOULDER" (or "").
static func injury_text(p: PoloPlayer) -> String:
	if not is_injured(p):
		return ""
	return "%s %s" % [p.inj_sev.to_upper(), TYPE_NAMES.get(p.inj_type, p.inj_type.to_upper())]

# ------------------------------------------------------------------ tokens
## Can a token go on `key` now: he has one, it's one of his four, and it's under its ceiling.
static func can_spend(p: PoloPlayer, key: String) -> bool:
	return p.tokens > 0 and key in p.key_ratings() and Attributes.room(p, key) >= Attributes.PRECISION

## Spends one token on `key`: +1 permanent point (never past its ceiling). His stars and the
## 0-100 ratings follow (Attributes.sync); his injury stays exactly as it was, so its red boxes
## simply move up with the new point. Returns whether it happened.
static func spend(p: PoloPlayer, key: String) -> bool:
	if not can_spend(p, key):
		return false
	p.tokens -= 1
	Attributes.set_value(p, key, minf(Attributes.value(p, key) + 1.0, Attributes.ceiling(p, key)))
	reconcile(p)   # (the last box bought: fully developed, nothing banked)
	return true

## Is there anywhere a token could go?
static func has_room(p: PoloPlayer) -> bool:
	for k in p.key_ratings():
		if Attributes.room(p, k) >= Attributes.PRECISION:
			return true
	return false

## How much an AI program wants each attribute for this player: what his position leans on.
const ROLE_WEIGHT := {
	PoloPlayer.Pos.CENTER: {"str": 1.5, "sho": 1.2, "pas": 0.8, "dfn": 0.8},
	PoloPlayer.Pos.DEFENDER: {"dfn": 1.5, "str": 1.3, "pas": 0.9, "sho": 0.6},
	PoloPlayer.Pos.DRIVER: {"sho": 1.4, "pas": 1.1, "dfn": 0.9, "str": 0.7},
	PoloPlayer.Pos.WING: {"sho": 1.4, "pas": 1.2, "dfn": 0.8, "str": 0.7},
	PoloPlayer.Pos.UTILITY: {"pas": 1.2, "sho": 1.2, "dfn": 1.0, "str": 0.9},
	PoloPlayer.Pos.GK: {"blk": 1.3, "lun": 1.2, "leg": 1.1, "com": 0.9},
}

## The attribute an AI program puts a token on: what his position needs, a little more where
## he's weakest (room to grow is cheap there), only where there's room under the ceiling. ""
## when none has room.
static func ai_choice(p: PoloPlayer) -> String:
	var best := ""
	var best_score := -1.0
	var w: Dictionary = ROLE_WEIGHT.get(p.pos, {})
	for k in p.key_ratings():
		if Attributes.room(p, k) < Attributes.PRECISION:
			continue
		var s := float(w.get(k, 1.0)) * (1.0 + (Attributes.MAX - Attributes.value(p, k)) * 0.08)
		if s > best_score:
			best_score = s
			best = k
	return best

## An AI player spends every token he can (one point each); any he can't use he keeps.
static func ai_spend(p: PoloPlayer) -> int:
	var n := 0
	while p.tokens > 0:
		var k := ai_choice(p)
		if k == "" or not spend(p, k):
			break
		n += 1
	return n

# ------------------------------------------------------------------ saving
## A player saved on the old curve (no level_start): his attributes, level and tokens kept as they
## were; where his development started worked out from them (each point he has bought lifted
## initial_level half a level; tokens he still holds didn't), and his XP turned into the same share
## of his next token on the new curve.
static func _convert_curve(p: PoloPlayer) -> void:
	var earned := clampi(2 * (p.xp_level - initial_level(p)) - p.tokens, 0, p.xp_level - 1)
	earned = maxi(earned, mini(p.tokens, p.xp_level - 1))
	var share := clampf(float(p.xp) / float(old_xp_required(p.xp_level)), 0.0, 1.0)
	p.xp_start = p.xp_level - earned
	p.xp = mini(floori(share * xp_required(earned)), xp_required(earned) - 1)

## A player saved on CEIL(450 x 1.38^n), before the rebalance: his level, tokens and attributes as
## they were, his XP the same share of his next token on this curve (40% of the way is still 40%),
## never a token more or less.
static func _rebalance_curve(p: PoloPlayer) -> void:
	var n := maxi(0, p.xp_level - p.xp_start)
	var share := clampf(float(p.xp) / float(lt_xp_required(n)), 0.0, 1.0)
	p.xp = mini(floori(share * xp_required(n)), xp_required(n) - 1)

static func to_dict(p: PoloPlayer) -> Dictionary:
	ensure(p)   # (a player nobody has asked yet saves the level he'll load with)
	var d := {"hidden_level": p.xp_level, "level_start": p.xp_start, "current_xp": p.xp, "available_upgrade_tokens": p.tokens,
		"curve": CURVE_VERSION}
	if p.inj_type != "":
		d["injury"] = {"type": p.inj_type, "severity": p.inj_sev}
	return d

## Reads the saved progression (`d` the "development" entry, {} for an older save: ensure()
## then starts him from his attributes with no XP and no tokens).
static func from_dict(p: PoloPlayer, d: Dictionary) -> void:
	p.xp_level = int(d.get("hidden_level", 0))
	p.xp = maxi(0, int(d.get("current_xp", 0)))
	p.tokens = maxi(0, int(d.get("available_upgrade_tokens", 0)))
	if d.has("level_start"):
		p.xp_start = int(d.level_start)
		if int(d.get("curve", 2)) < CURVE_VERSION:
			_rebalance_curve(p)
	elif p.xp_level > 0:
		_convert_curve(p)
	var inj: Dictionary = d.get("injury", {}) if d.get("injury") is Dictionary else {}
	var type := String(inj.get("type", ""))
	var sev := String(inj.get("severity", ""))
	if INJURIES.has(type) and sev in ["minor", "moderate"]:
		p.inj_type = "head" if p.is_keeper() else type
		p.inj_sev = sev
	# an older save may hold more tokens than his ceilings leave room for (or XP banked by a
	# fully developed player): trimmed to what he can use, his attributes untouched
	reconcile(p)

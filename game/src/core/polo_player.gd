class_name PoloPlayer
extends RefCounted
## One rostered player. His four ATTRIBUTES (0-10, each with its own ceiling: Attributes) are
## what he is: OVERALL and POTENTIAL are their averages, his stars their star ratings
## (Attributes.stars_of). The 0-100
## ratings below (`shoot` ... `keeping`) are worked out from them (Attributes.sync) for the pool's
## older mechanics; nothing sets them on their own any more.

## The positions (Position Identity update): C the centre, ATK an attacker (the old driver: its
## saved number is the same, so an older save's DRV is an ATK and its DEF a 2MD), WG a wing, UT a
## utility, 2MD the two-metre defender. LFTY is an ATK who shoots left-handed (`lefty`): a
## position of its own on every screen (pos_text), the same attacker everywhere else.
enum Pos { GK, CENTER, DRIVER, WING, UTILITY, DEFENDER }
const POS_SHORT := ["GK", "C", "ATK", "WG", "UT", "2MD"]
const POS_LONG := ["Goalkeeper", "Center", "Attacker", "Wing", "Utility", "Two-Meter Defender"]
const LEFTY_SHORT := "LFTY"
const LEFTY_LONG := "Lefty"
const SKIN := ["f1c9a5", "e0ac85", "c68a5e", "a86b43", "7d4a2b", "5a3520"]
## How often a new player gets each SKIN shade (the Hometown & Appearance update): light 40,
## medium-light 30, medium 20 (its two shades, 10 each), dark 8, very dark 2. The palette itself is
## unchanged and every shade still comes up. (It was even, a sixth each: the two darkest a third.)
## Drawn on its own: nothing about the player (his hometown, name, team, position) enters into it.
const SKIN_WEIGHTS := [40.0, 30.0, 10.0, 10.0, 8.0, 2.0]
const SKIN_GROUPS := ["light", "medium-light", "medium", "medium", "dark", "very dark"]

var first := ""
var last := ""
var number := 0
var pos: int = Pos.UTILITY
var lefty := false
var age := 22
var shoot := 50
var passing := 50
var speed := 50
var strength := 50
var defense := 50
var keeping := 0
var skin := 0
# career only (quick-match players keep the defaults)
var id := 0
var year := 1               # 1-4: FR, SO, JR, SR
var pot := 60.0             # hidden: the overall this player can grow into
# development (Development): hidden level, XP towards his next upgrade token, unspent tokens, and
# his one injury (a temporary attribute penalty: he still plays), "" healthy
var xp_level := 0           # hidden: never shown anywhere (0 = not set yet: Development.ensure)
var xp_start := -1          # hidden: his level when his development began (-1 = not set yet)
var xp := 0
var tokens := 0
var inj_type := ""          # "shoulder", "hip", "head" (keepers: always "head")
var inj_sev := ""           # "minor", "moderate"
var stats := {}             # this season: gp, g, a, sv, st
var totals := {}            # whole college career, same keys
var seasons: Array = []     # his finished seasons, oldest first: {s: "2026-27", yr: 1-4, team: id, stats: {...}}
var awards: Array = []      # "2026-27 All-Conference" and friends
var trait_id := ""          # one thing he's known for (Traits), or ""
var schol := false          # on one of the program's scholarships (Career.SCHOL_MAX)
var home := ""              # hometown, "Newport Beach, CA"
var region := ""            # its region (Regions.LIST)
# stars and form (PlayerForm): CURRENT and POTENTIAL are permanent (they move at the roster
# lock); form is his last few postgame grades and the HEAT they've built, and EFFECTIVE is
# CURRENT plus his heat's form
var stars := 3.0            # CURRENT, 0.5-5.0 in halves (Attributes.stars_of his OVERALL)
var pot_stars := 3.0        # POTENTIAL, CURRENT-5.0 (the same of his ceilings' average)
var star_base := 0.0        # his overall when CURRENT was last set (development counts from it)
var form: Array = []        # the last PlayerForm.FORM_GAMES grades, oldest first: 1 GOOD, 0, -1 BAD
var heat := 0               # 0 NORMAL, 1 HOT, 2 VERY HOT (PlayerForm.push_grade moves it a level a game)
var rolled := false         # ROLLED in the game going on (three personal fouls): out until it ends. Never saved
var susp := 0               # SUSPENDED (a coaching decision, CoachEvents): your team's games he still sits out
var heat_bonus := 0.0       # HOT STAR PROGRESS a coaching decision gave him, in part of a GOOD grade (PlayerForm)
var attrs := {}             # his four attributes, 0-10 (Attributes.FIELD or Attributes.KEEPER)
var attr_pot := {}          # ...and each one's ceiling, never below it
var stars_locked := -1.0    # CURRENT stars at the last roster lock (what "stars moved" counts from)
var pro := false            # a quick-match club's player (League): rated above the college scale, so his
                            # own 0-100 ratings stay as made (Attributes.sync leaves them). Not saved.
var shape: Array = []       # being made: each attribute's lean off his overall from the ratings he was
                            # made with (Attributes.from_legacy), so rescaling him keeps it. Not saved.
var dev := ""               # hidden: the development profile he was recruited with (Recruiting.DEV_PROFILES),
                            # "" for anyone made before them. Says nothing the ceilings don't; kept for the record.
var dev_recruit := ""      # a DEV RECRUIT's identity (DevRecruits.DEFS: "blake", "logan"), "" for
                            # everyone else: his attributes may pass 10 (Attributes.cap). Saved only when set.
var walk_on := false        # a WALK-ON (WalkOns: open tryouts filled an empty place): no potential at
                            # all, every ceiling his attribute (Attributes.sync holds it). Saved only when set.
var walkon_rookie := false  # ...and still in his first season here: a rookie for the rookie awards
                            # whatever his class year (WalkOns.is_rookie). Off at the next transition.
var last_game := {}         # his last graded game: {raw, exp, pm, gr, was (form before it)}, and his
                            # line's numbers (PlayerForm.LINE_FIELD / LINE_KEEPER) since they were kept

const YEAR_SHORT := ["", "FR", "SO", "JR", "SR"]
const RATINGS := ["shoot", "passing", "speed", "strength", "defense", "keeping"]
const RATING_NAMES := {"shoot": "Shooting", "passing": "Passing", "speed": "Speed",
	"strength": "Strength", "defense": "Defense", "keeping": "Goalkeeping"}
const INT_KEYS := ["number", "pos", "age", "shoot", "passing", "speed", "strength", "defense",
	"keeping", "skin", "id", "year", "heat", "susp"]

func is_keeper() -> bool:
	return pos == Pos.GK

## A left-handed field player (a keeper's hand is never his position).
func is_lefty() -> bool:
	return lefty and pos != Pos.GK

## His natural position as every screen shows it: LFTY for a lefty, else POS_SHORT.
func pos_text() -> String:
	return LEFTY_SHORT if is_lefty() else POS_SHORT[clampi(pos, 0, POS_SHORT.size() - 1)]

func pos_long() -> String:
	return LEFTY_LONG if is_lefty() else POS_LONG[clampi(pos, 0, POS_LONG.size() - 1)]

## His OVERALL on the 0-100 scale the AI and recruiting compare (Attributes.legacy_of), unrounded.
## Before he has attributes (being made the pre-2.0 way), the old weighted overall.
func overall() -> float:
	if attrs.is_empty() or pro:
		return legacy_overall()
	return Attributes.legacy_of(Attributes.overall(self))

## OVERALL, 0-10: the average of his four attributes (the one rating calculation).
func rating10() -> float:
	return Attributes.overall(self) if not attrs.is_empty() else Attributes.ten_of(legacy_overall())

## POTENTIAL, 0-10: the average of his four ceilings.
func potential10() -> float:
	return Attributes.potential(self) if not attrs.is_empty() else Attributes.ten_of(maxf(pot, legacy_overall()))

## "6.5": OVERALL for the screen.
func ovr_text() -> String:
	return Attributes.text(rating10())

func pot_text() -> String:
	return Attributes.text(potential10())

## The pre-2.0 weighted overall: only for converting a player made from 0-100 ratings (each
## position's weights add up to 1: keepers are mostly keeping; centres strength and shooting;
## drivers, wings and utilities shooting and speed; centre-defenders defence and strength).
func legacy_overall() -> float:
	match pos:
		Pos.GK:
			return keeping * 0.8 + passing * 0.1 + speed * 0.1
		Pos.CENTER:
			return strength * 0.36 + shoot * 0.3 + passing * 0.12 + defense * 0.11 + speed * 0.11
		Pos.DEFENDER:
			return defense * 0.33 + strength * 0.32 + speed * 0.17 + passing * 0.1 + shoot * 0.08
		_:
			return shoot * 0.32 + speed * 0.25 + passing * 0.2 + defense * 0.12 + strength * 0.11

## OVERALL on the 0-100 scale, a whole number 0-99 (internal comparisons; screens show ovr_text).
func ovr() -> int:
	return clampi(roundi(overall()), 0, 99)

## CEILING: the overall he can grow into (`pot`), 0-99; never below what he already is.
func ceiling() -> int:
	return clampi(roundi(maxf(pot, overall())), 0, 99)

## His run: GOOD less BAD over his last grades (PlayerForm.run_score); his form is his heat.
func form_total() -> int:
	return PlayerForm.run_score(form)

func form_state() -> String:
	return PlayerForm.state_of(heat)

## EFFECTIVE stars: CURRENT plus form, 0.0-6.0.
func eff_stars() -> float:
	return PlayerForm.effective(stars, form_state())

## His OVERALL on the continuous star scale (OVERALL / 2, Attributes.star_value): what the team
## ratings count, so the star steps on screen never move a team's rating.
func star_value() -> float:
	if attrs.is_empty():
		return stars
	return Attributes.star_value(rating10())

## The same with his form on top (EFFECTIVE's bonus).
func eff_star_value() -> float:
	return star_value() + eff_stars() - stars

## A rating as he plays it today: the permanent rating moved by his Hot Stars' attribute bonus
## (Attributes.hot_bonus, HOT_RATING_PER_POINT a point: +4 HOT, +8 VERY HOT). Only games played
## out in the pool use this; the scoring engine takes form from the team's LIVE OVR instead, so
## it never counts twice. Never saved: get(key) is the permanent rating.
func live(key: String) -> float:
	return float(get(key)) + Attributes.hot_bonus(self) * Attributes.HOT_RATING_PER_POINT

func short_name() -> String:
	return last.to_upper()

func tag() -> String:
	return "#%d %s" % [number, short_name()]

## A new player's skin shade (SKIN_WEIGHTS, whole percents), one draw of `rng`: one randi(), as
## the old even pick took (randf() takes two in this Godot: everything generated after him would
## move).
static func random_skin(rng: RandomNumberGenerator) -> int:
	var r := float(rng.randi() % 100)
	for i in SKIN_WEIGHTS.size():
		r -= float(SKIN_WEIGHTS[i])
		if r < 0.0:
			return i
	return 0

func skin_color() -> Color:
	return Color(SKIN[clampi(skin, 0, SKIN.size() - 1)])

## Can he play: everyone, unless he's been ROLLED in the game going on (three personal fouls:
## MatchState.add_pf). An injury only lowers some of his attributes for now (Development).
func is_available() -> bool:
	return not rolled and susp <= 0

## Sitting out a suspension (CoachEvents): never starts, never comes on, never simulated.
func is_suspended() -> bool:
	return susp > 0

func is_injured() -> bool:
	return inj_type != ""

func year_text() -> String:
	return YEAR_SHORT[clampi(year, 1, 4)]

## His four attributes, in the order his page shows them (Attributes.FIELD / KEEPER).
func key_ratings() -> Array:
	return Attributes.keys_for(self)

## The 0-100 ratings that mattered for this position before 2.0 (making a player the old way).
func legacy_keys() -> Array:
	if is_keeper():
		return ["keeping", "passing", "speed"]
	return ["shoot", "passing", "speed", "strength", "defense"]

## One attribute, 0-10.
func attr(key: String) -> float:
	return Attributes.value(self, key)

## A 0-100 rating by name (an attribute's key gives the attribute, rounded).
func rating(key: String) -> int:
	if key in Attributes.FIELD or key in Attributes.KEEPER:
		return roundi(attr(key))
	return int(get(key))

func add_stat(key: String, n: int = 1) -> void:
	stats[key] = int(stats.get(key, 0)) + n
	totals[key] = int(totals.get(key, 0)) + n

func stat(key: String) -> int:
	return int(stats.get(key, 0))

## The season over: this season's numbers kept in his season log (FULL CAREER STATS), once a
## season, only if he played.
func archive_season(label: String, team_id: String) -> void:
	if int(stats.get("gp", 0)) <= 0:
		return
	if not seasons.is_empty() and String(seasons[-1].get("s", "")) == label:
		return
	seasons.append({"s": label, "yr": year, "team": team_id, "ovr": snappedf(rating10(), 0.01), "stars": stars, "stats": stats.duplicate()})

func to_dict() -> Dictionary:
	return {"first": first, "last": last, "number": number, "pos": pos, "lefty": lefty, "age": age,
		"shoot": shoot, "passing": passing, "speed": speed, "strength": strength,
		"defense": defense, "keeping": keeping, "skin": skin, "id": id, "year": year, "pot": snappedf(pot, 0.0001),
		"development": Development.to_dict(self), "stats": stats.duplicate(),
		"totals": totals.duplicate(), "seasons": seasons.duplicate(true), "awards": awards.duplicate(), "trait_id": trait_id,
		"schol": schol, "home": home, "region": region, "dev": dev,
		"stars": stars, "pot_stars": pot_stars, "star_base": snappedf(star_base, 0.0001), "form": form.duplicate(),
		"heat": heat, "susp": susp, "heat_bonus": snappedf(heat_bonus, 0.0001),
		"last_game": last_game.duplicate(), "attrs": _snapped(attrs), "attr_pot": _snapped(attr_pot),
		"stars_locked": snappedf(stars_locked, 0.0001)}.merged({"dev_recruit": dev_recruit} if dev_recruit != "" else {}) \
		.merged({"walk_on": true, "walkon_rookie": walkon_rookie} if walk_on else {})

## Saved fractions keep 4 decimals, so a save round-trips exactly.
static func _snapped(d: Dictionary) -> Dictionary:
	var out := {}
	for k in d:
		out[k] = snappedf(float(d[k]), 0.0001)
	return out

## His development (Development.from_dict). A save from before it: his hidden level from his
## attributes, no XP, no tokens, and an injury that had him out for weeks becomes a temporary
## penalty instead (two weeks or more: moderate), its kind drawn the same way every time.
static func _load_development(p: PoloPlayer, d: Dictionary) -> void:
	if d.get("development") is Dictionary:
		Development.from_dict(p, d.development)
	elif int(d.get("injury", 0)) > 0:
		var rng := RandomNumberGenerator.new()
		rng.seed = hash("injury%d" % p.id)
		Development.injure(p, rng, "moderate" if int(d.injury) >= 2 else "minor")
	Development.ensure(p)
	Attributes.sync(p)

static func from_dict(d: Dictionary) -> PoloPlayer:
	var p := PoloPlayer.new()
	for k in d.keys():
		if k in INT_KEYS:
			p.set(k, int(d[k]))
		elif k == "form":
			p.form = (d[k] as Array).map(func(x): return clampi(int(x), PlayerForm.BAD, PlayerForm.GOOD))
		elif k == "last_game":
			var lg: Dictionary = d[k]
			p.last_game = {}
			for lk in lg:
				if lk == "was":
					p.last_game[lk] = String(lg[lk])
				elif lk == "gr" or lk in PlayerForm.LINE_FIELD or lk in PlayerForm.LINE_KEEPER:
					p.last_game[lk] = int(lg[lk])
				else:
					p.last_game[lk] = float(lg[lk])
		elif k in ["stars", "pot_stars", "star_base", "stars_locked", "heat_bonus"]:
			p.set(k, float(d[k]))
		elif k in ["attrs", "attr_pot"]:
			var src: Dictionary = d[k]
			var out := {}
			for ak in src:
				out[String(ak)] = float(src[ak])
			p.set(k, out)
		elif k == "seasons":
			p.seasons = []
			for e in d[k]:
				var st := {}
				for sk in (e.get("stats", {}) as Dictionary):
					st[sk] = int(e.stats[sk])
				p.seasons.append({"s": String(e.get("s", "")), "yr": int(e.get("yr", 0)), "team": String(e.get("team", "")), "stats": st})
		elif k in ["stats", "totals"]:
			var src: Dictionary = d[k]
			var out := {}
			for sk in src.keys():
				out[sk] = int(src[sk])
			p.set(k, out)
		elif k == "admin" or k == "dev_recruit":
			p.dev_recruit = String(d[k])   # (a save from before the DEV Recruits rename calls him "admin")
		elif k == "dev":
			p.dev = DevRecruits.DEV_PROFILE if String(d[k]) == "admin" else String(d[k])   # (likewise)
		elif k == "walk_on" or k == "walkon_rookie":
			p.set(k, bool(d[k]))
		elif k in ["development", "injury", "boosts", "prog"]:
			pass   # (below; the last three only in saves from before XP development)
		else:
			p.set(k, d[k])
	if not d.has("stars"):
		# saved before stars and form: his 0-99 overall kept exactly (as OVERALL 0-10), NORMAL form
		PlayerForm.rate_new(p)
	elif not Attributes.migrate(p):
		Attributes.sync(p)
	_load_development(p, d)
	# (saved before 2.0: converted above at his saved stars, which stay exactly as they were)
	if p.stars_locked < 0.0:
		p.stars_locked = p.stars
	elif not d.has("dev"):
		# saved before the star steps: his last lock was OVERALL / 2, now the stars that rated
		p.stars_locked = Attributes.stars_of(p.stars_locked * 2.0)
	while p.form.size() > PlayerForm.FORM_GAMES:
		p.form.pop_front()
	if d.has("heat"):
		p.heat = clampi(int(d.heat), 0, PlayerForm.LEVELS.size() - 1)
	else:
		# saved before two-level heat: no cold form any more, and HOT only from a real run
		p.heat = PlayerForm.legacy_heat(p.form)
		if not p.last_game.is_empty():
			p.last_game["was"] = p.form_state()
	if p.last_game.has("was") and not PlayerForm.FORM_NAMES.has(String(p.last_game.was)):
		p.last_game["was"] = p.form_state()
	_migrate_position(p)
	return p

## The Position Identity update on an older save (DRV and DEF need nothing: ATK and 2MD are the
## same saved numbers): a lefty is a LFTY, an attacker, whatever he was listed as (an old lefty
## utility or wing); a keeper's hand isn't a position; the retired LEFTY SNIPER trait is worked
## out again from his attributes. Nobody becomes a lefty here, and nothing else changes.
static func _migrate_position(p: PoloPlayer) -> void:
	if p.lefty and p.pos == Pos.GK:
		p.lefty = false
	elif p.lefty and p.pos != Pos.DRIVER:
		p.pos = Pos.DRIVER
	if p.trait_id == "lefty_sniper":
		p.trait_id = Traits.best_for(p)

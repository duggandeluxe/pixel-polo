class_name RosterReport
## THE ROSTER SET REPORT, as data (the Roster Set Redesign): what your off-season did to your roster,
## kept as it happened for the roster_set screen to draw. It only ever WRITES DOWN what Offseason
## already does (who graduated, who joined, who you cut, who signed elsewhere, how the stars moved,
## next season's ratings): it never decides, moves or rates anyone, so the off-season plays exactly
## as before with or without it.
##   Offseason.transition   start(): your graduating class (before they leave), add("fresh")
##   Offseason.cut          add("cuts")
##   Offseason._pickups     add("elsewhere"): a player you cut signs with another program
##   Offseason.finish       close(): roster size, scholarships, walk-ons, development, ratings
## While the off-season runs it lives in Career.season["roster_report"] (so a save in the cuts
## phase keeps it); close() hands it to the ROSTER SET queue item ("report") and keeps a copy on the
## season's Career.history entry ("roster_report") for DEV Mode's VIEW ROSTER SET.
## A player is a small dictionary (entry()): enough to show him and draw his portrait, never the
## player himself, so the report stays small in the save.
##
## The DEV preview's sample reports (sample()) are made here too, from fixed lists: the same every
## time, never written to a career.

const KEY := "roster_report"
const VERSION := 1

## One player as the report keeps him: {id, first, last, skin, dr, num, pos, stars, pot, year}.
static func entry(p: PoloPlayer, extra: Dictionary = {}) -> Dictionary:
	var e := {"id": p.id, "first": p.first, "last": p.last, "skin": p.skin, "dr": p.dev_recruit, "num": p.number, "pos": p.pos,
		"stars": snappedf(p.stars, 0.01), "pot": snappedf(p.pot_stars, 0.01), "year": p.year}
	e.merge(extra, true)
	return e

## A stand-in player for an entry, only for drawing (his portrait, his position): never on a roster.
static func stub(e: Dictionary) -> PoloPlayer:
	var p := PoloPlayer.new()
	p.id = int(e.get("id", 0))
	p.first = String(e.get("first", ""))
	p.last = String(e.get("last", ""))
	p.skin = int(e.get("skin", 0))
	p.dev_recruit = String(e.get("dr", ""))
	p.number = int(e.get("num", 0))
	p.pos = int(e.get("pos", PoloPlayer.Pos.UTILITY))
	p.stars = float(e.get("stars", 0.0))
	p.pot_stars = float(e.get("pot", p.stars))
	p.year = int(e.get("year", 1))
	return p

## "WINKLER", or "J. WINKLER" when `initial`.
static func name_of(e: Dictionary, initial := false) -> String:
	var last := String(e.get("last", "")).to_upper()
	var first := String(e.get("first", ""))
	return ("%s. %s" % [first.substr(0, 1).to_upper(), last]) if initial and first != "" else last

static func pos_text(e: Dictionary) -> String:
	var i := int(e.get("pos", -1))
	return String(PoloPlayer.POS_SHORT[i]) if i >= 0 and i < PoloPlayer.POS_SHORT.size() else ""

# ------------------------------------------------------------------ recording (Offseason)
## The off-season's report, started: your team, the two seasons, your graduating class as it
## leaves. (Called before the seniors go.)
static func start(c: Career, grads: Array) -> void:
	c.season[KEY] = {"v": VERSION, "team": c.school, "from": c.season_years(), "to": "%d-%d" % [c.year + 1, c.year + 2],
		"grads": grads.map(func(p: PoloPlayer): return entry(p)), "fresh": [], "cuts": [], "elsewhere": [], "notes": []}

## Adds a player to a section ("fresh", "cuts", "elsewhere"); nothing before start() (an older
## save mid-off-season) or twice.
static func add(c: Career, section: String, p: PoloPlayer, extra: Dictionary = {}) -> void:
	var r: Dictionary = c.season.get(KEY, {})
	if r.is_empty():
		return
	var list: Array = r.get(section, [])
	if list.any(func(e): return int(e.id) == p.id):
		return
	list.append(entry(p, extra))
	r[section] = list
	if section == "cuts":   # (a freshman cut before he played: a cut, not an arrival)
		r["fresh"] = (r.get("fresh", []) as Array).filter(func(e): return int(e.id) != p.id)

## A line worth keeping (a graduate's career record).
static func note(c: Career, line: String) -> void:
	var r: Dictionary = c.season.get(KEY, {})
	if not r.is_empty():
		(r.notes as Array).append(line)

## The roster is set: the rest of the report (`f`: roster, schol, walkons, dev, ratings) and where
## it's kept. Returns the finished report ({} for an off-season that began before the report did).
static func close(c: Career, f: Dictionary) -> Dictionary:
	var r: Dictionary = c.season.get(KEY, {})
	if r.is_empty():
		return {}
	c.season.erase(KEY)
	if String(r.team) != c.school:
		# (you took a job while the old roster waited for its cuts: that roster isn't yours now)
		for k in ["grads", "fresh", "cuts", "elsewhere", "notes"]:
			r[k] = []
		r.team = c.school
	r.merge(f, true)
	# PLAYER DEVELOPMENT is your returning players: not this off-season's freshmen
	var fresh_ids: Array = (r.fresh as Array).map(func(e): return int(e.id))
	r["dev"] = (r.get("dev", []) as Array).filter(func(e): return not int(e.id) in fresh_ids)
	r["team_name"] = c.team().name
	if not c.history.is_empty():
		(c.history[c.history.size() - 1] as Dictionary)[KEY] = r.duplicate(true)
	return r

## The last finished off-season's report in this career ({} none): DEV Mode's real preview.
static func latest(c: Career) -> Dictionary:
	if c == null:
		return {}
	for i in range(c.history.size() - 1, -1, -1):
		var r: Dictionary = (c.history[i] as Dictionary).get(KEY, {})
		if not r.is_empty():
			return r.duplicate(true)
	return {}

## Next season's ratings as the report shows them: OVR, OFF and DEF stars, GK, each with the
## value the finished season started with when it was snapshotted ("*_was", absent otherwise: no
## change is ever claimed without it).
static func ratings(c: Career, me: PoloTeam) -> Dictionary:
	var out := {"ovr": PoloTeam.display_ovr(float(me.ratings()[0])), "off": PoloTeam.rating_stars(me.offense_display()),
		"def": PoloTeam.rating_stars(me.defense_display()), "gk": me.goalkeeping_display()}
	var before: Dictionary = c.season.get("ratings", {})
	if before.has(me.id):
		out["ovr_was"] = PoloTeam.display_ovr(float(before[me.id][0]))
	var shown: Dictionary = c.season.get("shown", {})
	if shown.has(me.id):
		var was: Array = shown[me.id]
		out["off_was"] = PoloTeam.rating_stars(float(was[0]))
		out["def_was"] = PoloTeam.rating_stars(float(was[1]))
		out["gk_was"] = int(was[2])
	return out

# ------------------------------------------------------------------ DEV preview samples
## DEV Mode's sample scenarios: [key, button label]. Every one draws through the same screen.
const SCENARIOS := [["normal", "NORMAL OFFSEASON"], ["champion", "CHAMPIONSHIP OFFSEASON"], ["big_grads", "LARGE GRADUATING CLASS"],
	["big_fresh", "LARGE RECRUITING CLASS"], ["cuts", "SEVERAL ROSTER CUTS"], ["no_cuts", "NO ROSTER CUTS"],
	["development", "BIG PLAYER DEVELOPMENT"], ["decline", "TEAM RATING DECLINE"], ["long_names", "LONG NAMES"],
	["no_portraits", "MISSING PORTRAITS"], ["big_history", "LARGE DYNASTY HISTORY"]]

const _FIRST := ["Jake", "Marco", "Eli", "Tomas", "Ryan", "Luca", "Owen", "Nico", "Sam", "Dylan", "Mateo", "Cole", "Ari", "Ben", "Theo", "Kai"]
const _LAST := ["WINKLER", "DOMINGUEZ", "WARD", "MARTINEZ", "ERNST", "HOLLOWAY", "PARK", "BECKETT", "SANTOS", "OKAFOR", "LINDQVIST",
	"REYES", "CHAU", "FOSTER", "IVANOV", "MORENO", "BRANDT", "KEANE", "NAKAMURA", "OSEI"]
const _LONG := ["VANDERHOOVEN-MACALLISTER", "CHRISTOPHERSON-WAINWRIGHT", "ABERNATHY-KOWALCZYK", "MONTGOMERY-FITZWILLIAM"]
const _SCHOOLS := ["ERIE LAKEHAWKS", "PACIFIC BREAKERS", "HARBOR CITY GULLS", "RIVERSIDE OTTERS"]

## A sample report for scenario `key`, made the same way every time (its own seeded dice), for
## your team (`team_id`, `team_name`: the open dynasty's, or a stand-in). Marked "preview": the screen
## shows DEV PREVIEW and nothing about it is ever saved.
static func sample(key: String, team_id: String, team_name: String) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(["roster_set_sample", key])
	var long := key == "long_names"
	var n := {"grads": 3, "fresh": 3, "cuts": 2, "elsewhere": 1, "dev": 8}
	match key:
		"big_grads":
			n.grads = 7
		"big_fresh":
			n.fresh = 8
		"cuts":
			n.cuts = 6
			n.elsewhere = 3
		"no_cuts":
			n.cuts = 0
			n.elsewhere = 0
		"development":
			n.dev = 12
		"long_names":
			n.grads = 4
			n.fresh = 4
			n.elsewhere = 2
	var next_id := [900000]
	var make := func(year: int, lo: float, hi: float) -> Dictionary:
		next_id[0] += 1
		var last := String(_LONG[rng.randi_range(0, _LONG.size() - 1)]) if long else String(_LAST[rng.randi_range(0, _LAST.size() - 1)])
		var stars := snappedf(rng.randf_range(lo, hi) * 2.0, 1.0) / 2.0
		var e := {"id": next_id[0], "first": String(_FIRST[rng.randi_range(0, _FIRST.size() - 1)]), "last": last, "skin": rng.randi_range(0, 3),
			"dr": "", "num": rng.randi_range(2, 13), "pos": rng.randi_range(0, PoloPlayer.POS_SHORT.size() - 1), "stars": stars,
			"pot": minf(5.0, stars + snappedf(rng.randf_range(0.0, 2.0) * 2.0, 1.0) / 2.0), "year": year}
		if key == "no_portraits":
			e["no_portrait"] = true
		return e
	var r := {"v": VERSION, "preview": true, "scenario": key, "team": team_id, "team_name": ("UNIVERSITY OF " + team_name + " AQUATIC CLUB") if long else team_name,
		"from": "2026-2027", "to": "2027-2028", "grads": [], "fresh": [], "cuts": [], "elsewhere": [], "notes": []}
	for i in n.grads:
		r.grads.append(make.call(4, 2.0, 4.5))
	for i in n.fresh:
		var f: Dictionary = make.call(1, 1.5, 3.5)
		r.fresh.append(f)
	for i in n.cuts:
		r.cuts.append(make.call(rng.randi_range(1, 3), 1.0, 2.5))
	for i in n.elsewhere:
		var e: Dictionary = (r.cuts[i] as Dictionary).duplicate() if i < r.cuts.size() else make.call(2, 1.5, 3.0)
		var to := String(_SCHOOLS[i % _SCHOOLS.size()])
		e["to"] = ""
		e["to_name"] = ("SOUTHEASTERN " + to + " POLYTECHNIC") if long else to
		r.elsewhere.append(e)
	var dev: Array = []
	for i in n.dev:
		var e: Dictionary = make.call(rng.randi_range(2, 4), 1.5, 4.0)
		var step: float = [0.0, 0.0, 0.5, 0.5, -0.5][rng.randi_range(0, 4)]
		match key:
			"development":
				step = [0.5, 1.0, 1.5, 0.5, -0.5, 0.0][i % 6]
			"decline":
				step = [-0.5, -1.0, 0.0, -0.5][i % 4]
		dev.append({"id": e.id, "first": e.first, "last": e.last, "pos": e.pos, "num": e.num, "was": e.stars, "now": clampf(float(e.stars) + step, 0.5, 5.0)})
	r["dev"] = dev
	var walkons := 0 if key != "big_grads" else 2
	r["walkons"] = walkons
	r["roster"] = clampi(10 - n.grads + n.fresh - n.cuts + walkons + 4, 7, 14)
	r["schol"] = mini(4, 2 + n.fresh / 2)
	r["schol_max"] = 4
	r["roster_max"] = 14
	var off := 3.5
	var def := 2.5
	r["ratings"] = {"ovr": 70, "ovr_was": 68, "off": off, "off_was": 3.0, "def": def, "def_was": 2.0, "gk": 43, "gk_was": 37}
	if key == "decline":
		r.ratings = {"ovr": 58, "ovr_was": 71, "off": 2.0, "off_was": 3.5, "def": 1.5, "def_was": 3.0, "gk": 31, "gk_was": 45}
	elif key == "champion":
		r.ratings = {"ovr": 84, "ovr_was": 82, "off": 4.5, "off_was": 4.5, "def": 4.0, "def_was": 3.5, "gk": 71, "gk_was": 68}
	if n.grads > 0:
		r.notes.append("SCHOOL RECORD! Career goals: 212, %s" % name_of(r.grads[0], true))
	r["history"] = _sample_history(key, team_id, r.team_name, rng)
	return r

## The sample's YOUR SEASONS: SeasonReview.history's shape ({history, totals}).
static func _sample_history(key: String, team_id: String, team_name: String, rng: RandomNumberGenerator) -> Dictionary:
	var count := 3
	if key == "big_history":
		count = 14
	elif key == "champion":
		count = 4
	var rows: Array = []
	var conf := 0
	var nat := 0
	for i in count:
		var y := 2026 - i
		var w := rng.randi_range(9, 22)
		var titles: Array = []
		if (key == "champion" and i == 0) or (key == "big_history" and i % 4 == 1):
			titles = ["NCSA CHAMPIONS", "CONFERENCE CHAMPIONS"]
			nat += 1
			conf += 1
			w = 24
		elif rng.randf() < 0.3:
			titles = ["CONFERENCE CHAMPIONS"]
			conf += 1
		rows.append({"year": "%d-%02d" % [y, (y + 1) % 100], "team": team_id, "team_name": team_name, "w": w, "l": 26 - w, "rank": rng.randi_range(1, 8),
			"finish": "NCSA champions" if "NCSA CHAMPIONS" in titles else ["Season over", "NCSA quarterfinals", "Conference semifinals"][rng.randi_range(0, 2)],
			"titles": titles})
	return {"history": rows, "totals": {"seasons": rows.size(), "conf": conf, "nat": nat, "titles": conf + nat}}

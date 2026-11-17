class_name Awards
## Season awards, handed out in the off-season before graduation: the NCSA's own (NationalAwards:
## Player, Defensive Player and Freshman of the Year, the Golden Arm and Iron Wall, the All-NCSA
## teams), Coach of the Year, and the All-Conference team of your conference. (The Golden Cap and
## Keeper of the Year were the National Awards update's Golden Arm and Iron Wall before it: their
## records stay in older saves, under their own names.)
## Winners go in the career's award history and on the players themselves. (No award pays
## credits: CreditRewards is the only way a career earns them.)

const TITLES := {"poy": "NCSA Player of the Year", "golden_cap": "Golden Cap (top scorer)",
	"keeper": "Keeper of the Year", "coach": "Coach of the Year", "all_conf": "All-Conference",
	"dpoy": "NCSA Defensive Player of the Year", "foy": "NCSA Freshman of the Year", "arm": "NCSA Golden Arm Award",
	"wall": "NCSA Iron Wall Award", "first": "All-NCSA First Team", "second": "All-NCSA Second Team"}

## A player's season, weighted by how his team did.
static func season_score(p: PoloPlayer, win_pct: float) -> float:
	var s := p.stat("g") * 2.0 + p.stat("a") + p.stat("st") * 0.5
	if p.is_keeper():
		s = p.stat("sv") * 0.25
	return s * (0.6 + 0.8 * win_pct)

static func _win_pct(c: Career, id: String) -> float:
	var r: Dictionary = c.table[id]
	return float(r.w) / maxf(1.0, float(r.w) + float(r.l))

## Hands out the awards. `prestige_before`: team id -> prestige at the start of the off-season
## (for Coach of the Year). Returns lines for the season review. `out`, if given, gets the
## All-Conference team as data too ("all_conf": [{pid, name, team, pos, conf}], keeper first) for
## the redesigned review (SeasonReview): the same picks, nothing chosen twice.
static func run(c: Career, prestige_before: Dictionary, out: Dictionary = {}) -> Array:
	var lines: Array = []
	var field: Array = []
	var keepers: Array = []
	for id in c.teams:
		var pct := _win_pct(c, id)
		for p in (c.teams[id] as PoloTeam).roster:
			var entry := [p, id, season_score(p, pct)]
			if p.is_keeper():
				keepers.append(entry)
			elif p.stat("gp") > 0:
				field.append(entry)
	field.sort_custom(func(a, b): return a[2] > b[2])
	keepers.sort_custom(func(a, b): return a[2] > b[2])
	lines.append_array(NationalAwards.run(c))   # (the NCSA's honours, all 30 schools)
	# Coach of the Year: the program that rose the most
	var best := ""
	var rise := -999.0
	for id in c.teams:
		var d: float = (c.teams[id] as PoloTeam).prestige - float(prestige_before.get(id, 0.0))
		if d > rise:
			rise = d
			best = id
	if best != "":
		var coach_name := "Coach %s" % c.coach.last if best == c.school else "the %s coach" % c.teams[best].name
		c.awards.append({"year": c.season_label(), "award": "coach", "name": coach_name, "team": best})
		lines.append("%s: %s (%s)" % [TITLES.coach, coach_name, c.teams[best].name])
		if best == c.school:
			c.coach.rep = mini(100, int(c.coach.rep) + 5)
			c.add_news("COACH OF THE YEAR! %s's turnaround at %s" % [c.coach.last, c.team().name])
	# All-Conference: your conference's best keeper and six best field players
	var conf := c.team().conf
	var cf: Array = field.filter(func(e): return (c.teams[e[1]] as PoloTeam).conf == conf).slice(0, 6)
	var ck: Array = keepers.filter(func(e): return (c.teams[e[1]] as PoloTeam).conf == conf).slice(0, 1)
	var names := PackedStringArray()
	var mine := 0
	var picks: Array = []
	for e in ck + cf:
		var p: PoloPlayer = e[0]
		p.awards.append("%s All-Conference" % c.season_label())
		names.append("%s (%s)" % [p.short_name(), Colleges.short_name(c.teams[e[1]])])
		picks.append({"pid": p.id, "name": "%s %s" % [p.first, p.last], "team": String(e[1]), "pos": p.pos, "conf": conf})
		if e[1] == c.school:
			mine += 1
	if not names.is_empty():
		lines.append("All-Conference: " + ", ".join(names))
	if mine > 0:
		c.add_news("%d %s players named All-Conference" % [mine, c.team().name])
	out["all_conf"] = picks
	return lines

static func _give(c: Career, key: String, p: PoloPlayer, team_id: String, extra: String = "") -> String:
	p.awards.append("%s %s" % [c.season_label(), TITLES[key]])
	c.awards.append({"year": c.season_label(), "award": key, "name": "%s %s" % [p.first, p.last], "team": team_id})
	if team_id == c.school:
		c.add_news("%s! %s %s" % [String(TITLES[key]).to_upper(), p.first, p.last])
	return "%s: %s %s (%s)%s" % [TITLES[key], p.first, p.last, c.teams[team_id].name, ("  " + extra) if extra != "" else ""]

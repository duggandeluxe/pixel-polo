class_name Honours
## Every honour a player has won, from the records themselves (by his permanent id, never his
## team): the weekly awards (ConfAwards: Career.conf_awards), the All-Tournament awards
## (TourneyAwards: Career.tourney_awards), the NCSA's annual honours (NationalAwards: Career.awards
## with a pid), and from before those were kept by id, the season awards written on him
## (PoloPlayer.awards: "2026-27 All-Conference"). Each one its own entry, so a trophy room shows
## every plaque and trophy, and the accolades list groups them.
##   {kind: weekly | tourney | national | legacy, key (grouping), cat, title, short, season, year
##    (earned: NationalAwards.earned_year), week (a weekly award's label), conf, team (the school he
##    won it for), line (the stats that won it, as recorded), order (oldest first)}

static func of(c: Career, pid: int, p: PoloPlayer = null) -> Array:
	var out: Array = []
	if c == null:
		return out
	for a in c.conf_awards:
		if int(a.pid) != pid:
			continue
		var abbr := Colleges.conf_abbr(String(a.conf))
		out.append({"kind": "weekly", "key": "w|%s|%s" % [a.conf, a.cat], "cat": String(a.cat),
			"title": "%s %s" % [abbr, ConfAwards.TITLES[a.cat]], "short": "%s %s" % [abbr, ConfAwards.SHORT[a.cat]],
			"season": String(a.season), "year": NationalAwards.earned_year(String(a.season)), "week": String(a.label),
			"conf": abbr, "team": String(a.team), "line": ConfAwards.line_text(a), "order": [String(a.season), 0, int(a.week)]})
	for a in c.tourney_awards:
		if int(a.pid) != pid:
			continue
		var pre := TourneyAwards.prefix(String(a.tid))
		out.append({"kind": "tourney", "key": "t|%s|%s" % [a.tid, a.cat], "cat": String(a.cat), "tid": String(a.tid),
			"title": "%s %s" % [pre, TourneyAwards.TITLES[a.cat]], "short": "%s %s" % [pre, TourneyAwards.SHORT[a.cat]],
			"season": String(a.season), "year": NationalAwards.earned_year(String(a.season)), "week": "",
			"conf": pre.trim_prefix("ALL-"), "team": String(a.team), "line": TourneyAwards.line_text(a), "order": [String(a.season), 1, 0]})
	for a in c.awards:
		if not a.has("pid") or int(a.pid) != pid:
			continue
		var k := String(a.award)
		out.append({"kind": "national", "key": "n|" + k, "cat": k, "title": String(Awards.TITLES.get(k, k)).to_upper(),
			"short": SHORT.get(k, k), "season": String(a.year), "year": NationalAwards.earned_year(String(a.year)), "week": "",
			"conf": String(a.get("conf", "")), "team": String(a.team), "line": NationalAwards.line_text(a),
			"slot": String(a.get("slot", "")), "order": [String(a.year), 2, 0]})
	for s in (p.awards if p != null else []):
		var text := String(s)
		var season := text.get_slice(" ", 0)
		var title := text.substr(season.length() + 1)
		out.append({"kind": "legacy", "key": "l|" + title, "cat": _legacy_cat(title), "title": title.to_upper(), "short": title.to_upper(),
			"season": season, "year": NationalAwards.earned_year(season), "week": "", "conf": "", "team": "", "line": "",
			"order": [season, 2, 0]})
	out.sort_custom(func(x, y): return _before(x.order, y.order))
	return out

const SHORT := {"poy": "NCSA POY", "dpoy": "NCSA DPOY", "foy": "NCSA FOY", "arm": "GOLDEN ARM", "wall": "IRON WALL",
	"first": "ALL-NCSA 1ST", "second": "ALL-NCSA 2ND"}

## An older save's season award by its words: the trophy it gets (Golden Cap -> the arm, Keeper of
## the Year -> the wall, All-Conference -> the silver cup), its own name kept.
static func _legacy_cat(title: String) -> String:
	if title.begins_with("NCSA Player of the Year"):
		return "poy"
	if title.begins_with("Golden Cap"):
		return "arm"
	if title.begins_with("Keeper of the Year"):
		return "wall"
	return "second"

static func _before(a: Array, b: Array) -> bool:
	for i in a.size():
		if a[i] != b[i]:
			return a[i] < b[i]
	return false

## The accolades list: one line a kind of honour, [count, full, short] with the years it was won,
## "(2027)", "(2027, 2028)", "(2027: 2, 2028: 1)" ("" for a year not known). National first, then
## the weekly awards, the All-Tournament ones after them, older season awards.
static func grouped(entries: Array) -> Array:
	var groups := {}
	var order: Array = []
	for e in entries:
		if not groups.has(e.key):
			groups[e.key] = {"title": e.title, "short": e.short, "kind": e.kind, "years": {}}
			order.append(e.key)
		var y := int(e.year)
		groups[e.key].years[y] = int(groups[e.key].years.get(y, 0)) + 1
	var rank := {"national": 0, "weekly": 1, "tourney": 2, "legacy": 3}
	var first := {}
	for i in order.size():
		first[order[i]] = i
	order.sort_custom(func(a, b): return [rank[groups[a].kind], first[a]] < [rank[groups[b].kind], first[b]])
	var out: Array = []
	for k in order:
		var g: Dictionary = groups[k]
		var n := 0
		for y in g.years:
			n += int(g.years[y])
		var ys := years_text(g.years)
		out.append([n, "%s%s" % [g.title, ys], "%s%s" % [g.short, ys]])
	return out

## " (2027)", " (2027, 2028)", " (2027: 2, 2028: 1)": the years in order, counts when any year has more than one.
static func years_text(years: Dictionary) -> String:
	var ks: Array = years.keys().filter(func(y): return int(y) > 0)
	if ks.is_empty():
		return ""
	ks.sort()
	var counts := ks.any(func(y): return int(years[y]) > 1) and ks.size() > 1
	return " (%s)" % ", ".join(ks.map(func(y): return ("%d: %d" % [y, years[y]]) if counts else str(y)))

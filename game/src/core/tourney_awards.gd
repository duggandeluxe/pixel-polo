class_name TourneyAwards
## ALL-TOURNAMENT AWARDS (the Accolades update): every conference tournament (All-PEC, All-GCC,
## All-WWPC, All-AWPC, All-NCC) and the NCSA Championship (All-NCSA) names its PLAYER, OFFENSIVE
## PLAYER and DEFENSIVE PLAYER OF THE TOURNAMENT once its final has been played, from what each
## player did in that tournament's games and no others: every round he actually played, added up
## (Career.week_line, a playoff round being a week of the schedule), never the regular season,
## another tournament or a past season.
##
## One framework for all six (one tournament's totals never mix with another's): the totals are
## kept under the tournament's key (tid "conf:<conference id>" or "nat") and the season's year,
## a round's lines added once (ConfAwards.decide_week runs once a week). The scores are the weekly
## awards' own (ConfAwards.score: "pot", "opot", "dpot"), over the totals, with the same allowance
## for games played: a man with a bye (one game fewer) isn't buried by a man with an extra game,
## and one great game doesn't beat a great tournament. PLAYER first (the best overall), then
## OFFENSIVE among the rest, then DEFENSIVE (field players and keepers both) among the rest.
## No sweeps: one school wins at most ConfAwards.MAX_PER_TEAM of a tournament's three.
##
## Each award is a record in Career.tourney_awards, for good: {year, season, tid, conf, cat, pid,
## team (the school he won it for), name, pos, cls, stars, line (his tournament totals), score}.
## The player's current school is his own business: the record never changes when he moves.

const CATS := ["pot", "opot", "dpot"]
const TITLES := {"pot": "PLAYER OF THE TOURNAMENT", "opot": "OFFENSIVE PLAYER OF THE TOURNAMENT",
	"dpot": "DEFENSIVE PLAYER OF THE TOURNAMENT"}
const SHORT := {"pot": "POT", "opot": "OPOT", "dpot": "DPOT"}

## The tournament a playoff round of `kind` is, for a team in conference `conf`.
static func tid_of(kind: String, conf: String) -> String:
	return "nat" if kind.begins_with("nat_") else "conf:" + conf

## "ALL-WWPC" / "ALL-NCSA": the honour's prefix, from the conference it was won in.
static func prefix(tid: String) -> String:
	if tid == "nat":
		return "ALL-NCSA"
	return "ALL-" + Colleges.conf_abbr(tid.trim_prefix("conf:"))

## The week being decided (ConfAwards.decide_week, once a week): a playoff round's lines go into
## its tournament's totals, every player who played in it.
static func add_week(c: Career) -> void:
	if c.week >= c.schedule.size() or not Schedule.is_playoff(c.schedule[c.week]):
		return
	var round: Dictionary = c.schedule[c.week]
	var kind := String(round.kind)
	var seen := {}
	for g in round.games:
		if g.r == null:
			continue
		for tid_team in [String(g.h), String(g.a)]:
			if seen.has(tid_team) or not c.teams.has(tid_team):
				continue
			seen[tid_team] = true
			var won: bool = Schedule.winner(g) == tid_team
			var t: PoloTeam = c.teams[tid_team]
			var key := "%d:%s" % [c.year, tid_of(kind, t.conf)]
			if not c.tourney_stats.has(key):
				c.tourney_stats[key] = {}
			var book: Dictionary = c.tourney_stats[key]
			for p: PoloPlayer in t.roster:
				var ln := c.week_line(p)
				if int(ln.get("gp", 0)) <= 0:
					continue
				var pid := str(p.id)
				if not book.has(pid):
					book[pid] = {"team": tid_team, "line": {}}
				var tot: Dictionary = book[pid].line
				for k in Career.WEEK_KEYS:
					tot[k] = int(tot.get(k, 0)) + int(ln.get(k, 0))
				if won:
					tot["tw"] = int(tot.get("tw", 0)) + 1   # (team success: PLAYER OF THE TOURNAMENT's, ConfAwards.TEAM_WIN)

## After the week: any tournament whose final was this week names its three (once).
static func decide(c: Career) -> Array:
	if c.week >= c.schedule.size():
		return []
	var kind := String(c.schedule[c.week].kind)
	var made: Array = []
	if kind == "conf_final":
		for conf in ConfAwards.CONF_ORDER:
			made.append_array(_decide(c, "conf:" + conf))
	elif kind == "nat_final":
		made.append_array(_decide(c, "nat"))
	return made

static func _decide(c: Career, tid: String) -> Array:
	var key := "%d:%s" % [c.year, tid]
	if key in c.tourney_done or not c.tourney_stats.has(key):
		return []
	c.tourney_done.append(key)
	var book: Dictionary = c.tourney_stats[key]
	var entries: Array = []
	for pid in book:
		var p := _player(c, int(pid))
		if p != null:
			entries.append({"p": p, "team": String(book[pid].team), "line": book[pid].line})
	var made: Array = []
	var given := {}
	var per_team := {}
	for cat in CATS:
		var best := ConfAwards._best(entries.filter(func(e): return not given.has((e.p as PoloPlayer).id) and int(per_team.get(String(e.team), 0)) < ConfAwards.MAX_PER_TEAM), cat)
		if best.is_empty():
			continue
		given[(best.p as PoloPlayer).id] = true
		per_team[String(best.team)] = int(per_team.get(String(best.team), 0)) + 1
		var rec := _record(c, best, cat, tid)
		c.tourney_awards.append(rec)
		made.append(rec)
	c.tourney_stats.erase(key)   # (decided: the totals live on in the records)
	return made

static func _player(c: Career, pid: int) -> PoloPlayer:
	for id in c.teams:
		var p := (c.teams[id] as PoloTeam).find_id(pid)
		if p != null:
			return p
	return null

static func _record(c: Career, e: Dictionary, cat: String, tid: String) -> Dictionary:
	var p: PoloPlayer = e.p
	var keep := {}
	for k in e.line:
		if int(e.line[k]) != 0 and k != "tw":   # (the record keeps his own stats; team wins only weighed the choice)
			keep[k] = int(e.line[k])
	c.award_players[str(p.id)] = JSON.stringify(p.to_dict())   # (his profile as he was, as the weekly awards keep it)
	if String(e.team) == c.school:
		c.add_news("%s %s: %s %s" % [prefix(tid), TITLES[cat], p.first, p.last])
	return {"year": c.year, "season": c.season_label(), "tid": tid, "conf": tid.trim_prefix("conf:") if tid != "nat" else "",
		"cat": cat, "pid": p.id, "team": String(e.team), "name": "%s %s" % [p.first, p.last], "pos": p.pos, "cls": p.year,
		"stars": p.stars, "line": keep, "score": snappedf(float(e.score), 0.01)}

## His tournament honours, grouped: [[tid, cat, count], ...] (the conferences' first, CONF_ORDER,
## then the NCSA's), each in the conference it was won in.
static func by_tourney(c: Career, pid: int) -> Array:
	var n := {}
	var tids: Array = ConfAwards.CONF_ORDER.map(func(cf): return "conf:" + cf)
	for a in c.tourney_awards:
		if int(a.pid) != pid:
			continue
		var k := "%s|%s" % [a.tid, a.cat]
		n[k] = int(n.get(k, 0)) + 1
		if not String(a.tid) in tids and String(a.tid) != "nat":
			tids.append(String(a.tid))
	tids.append("nat")
	var out: Array = []
	for tid in tids:
		for cat in CATS:
			var k := "%s|%s" % [tid, cat]
			if n.has(k):
				out.append([tid, cat, int(n[k])])
	return out

## His tournament totals in words, games first: "3 GAMES | 12 GOALS | 6 ASSISTS | 5 STEALS"
## (a keeper: saves, goals against, save %).
static func line_text(rec: Dictionary) -> String:
	var ln: Dictionary = rec.line
	if ln.is_empty():
		return ""   # (a pre-dynasty award, Legacy: no stats claimed)
	var parts := PackedStringArray()
	var gp := int(ln.get("gp", 0))
	parts.append("%d GAME%s" % [gp, "" if gp == 1 else "S"])
	var add := func(k: String, one: String, many: String) -> void:
		var n := int(ln.get(k, 0))
		if n > 0:
			parts.append("%d %s" % [n, one if n == 1 else many])
	if int(rec.pos) == PoloPlayer.Pos.GK:
		add.call("sv", "SAVE", "SAVES")
		var ga := int(ln.get("ga", 0))
		parts.append("%d AGAINST" % ga)
		var faced := int(ln.get("sv", 0)) + ga
		if faced > 0:
			parts.append("%d%% SAVED" % roundi(100.0 * int(ln.get("sv", 0)) / faced))
	elif String(rec.get("cat", "")) == "dpot":
		add.call("st", "STEAL", "STEALS")
		add.call("bl", "BLOCK", "BLOCKS")
		add.call("g", "GOAL", "GOALS")
	else:
		add.call("g", "GOAL", "GOALS")
		add.call("a", "ASSIST", "ASSISTS")
		add.call("st", "STEAL", "STEALS")
		add.call("bl", "BLOCK", "BLOCKS")
	return " | ".join(parts.slice(0, 5))

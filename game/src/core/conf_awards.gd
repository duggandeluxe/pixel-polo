class_name ConfAwards
## CONFERENCE WEEKLY AWARDS (the Conference Awards update): every week, once all its games are
## played (Career.end_week), each of the five conferences names its PLAYER, ROOKIE, OFFENSIVE
## PLAYER and DEFENSIVE PLAYER OF THE WEEK from what its players actually did that week
## (Career.week_line: every stat the games recorded, Career.WEEK_KEYS; nothing made up). Your
## players and the AI's alike, a man on a losing team too. One award a player a week: they're
## given in PICK_ORDER (the biggest first) and whoever has won one that week is passed over for
## the rest (a freshman who's PLAYER OF THE WEEK leaves ROOKIE to the next freshman). A
## conference with nobody who played names nobody. Recognition only: no credits,
## XP, stars or anything else comes with it.
##
## Each award is a record in Career.conf_awards, saved for good and never worked out again:
## {year, season, week, label, conf, cat, pid, team, name, pos, cls, stars, line, score}; the
## winner's player as he was (Career.award_players[pid], his last win's) keeps his profile when
## he's gone. Career.awards_done holds the weeks already decided ("year:week").
##
## The scores (a week's total; a second or third game counts, a little less than in full:
## PARTICIPATION):
##   POTW field: 5 goal, 4 assist, 4 steal, 4 block, 2 exclusion drawn, 3 penalty drawn,
##        -2 turnover, -2 exclusion committed
##   POTW keeper: KEEPER_SAVE a save, -KEEPER_GA a goal against, 4 steal, 4 assist (scaled to
##        the field players' range: a dominant keeper's week rates like a big field week)
##   ROTW: the POTW score, freshmen only
##   OPOTW: 6 goal, 4 assist, 2 exclusion drawn, 3 penalty drawn, -2 turnover, and with shots
##        recorded an efficiency nudge (EFFICIENCY x (goals/shots - 0.45), over 4+ shots in full)
##   DPOTW: goalkeepers only (the Accolades update): DEF_SAVE a save, -DEF_GA a goal against,
##        6 steal; nothing under MIN_FACED shots faced (two saves from two shots isn't a week's
##        defending). No keeper with a real week: nobody wins it.
## POTW is the best overall week of all (the one shared score); OPOTW goes to the best attacker
## among everybody else, so its winner never outranks POTW's on that score.
## The All-Tournament awards (TourneyAwards) use the same scores on a tournament's totals:
##   pot / opot as potw / opotw (pot also TEAM_WIN a game his team won); dpot as dpotw, but a field player's defending counts there too
##   (6 steal, 6 block, -3 exclusion committed, -4 penalty committed).
## Ties: the award's main stats, then fewer turnovers and exclusions, games played, then the
## lower player id (always the same answer).
##
## THE WEEK'S FOUR (the Weekly Awards Evaluation & Exclusivity update), conference by conference,
## from every player of every member school who played that week, in any game (played or
## simulated, inside the conference or out of it: Career.week_line, a week's every game added up):
##   1. POTW: the best overall week (no minimum). A keeper is scored on its own stricter scale
##      for it (KEEPER_POTW_*: saves above a par save rate, goals against counted hard), so an
##      ordinary keeper's week never beats a strong field player's; an extraordinary one can.
##   2. OPOTW, DPOTW, ROTW together (_allocate): one award a player a week, OPOTW only to a man
##      with offence on the sheet (goals, assists, exclusions or penalties drawn), DPOTW only a
##      keeper, ROTW only a freshman; as many of the three given as distinct winners allow, then
##      all three as near their own best as they can be together, then OPOTW first. No minimums: the best
##      keeper left is DPOTW whatever his week, the best freshman left ROTW.
## An award nobody can be given (the only keeper who played is POTW) stays empty: never a
## duplicate, never a field player for DPOTW. Old weeks stay as they were decided.
## No sweeps: a school wins at most MAX_PER_TEAM of a conference-week's four (and of a
## tournament's three, TourneyAwards); the next best man from another school takes the rest.

const CATS := ["potw", "rotw", "opotw", "dpotw"]
## The order a week's awards are given in (a player only ever gets the first he's best for).
const PICK_ORDER := ["potw", "opotw", "dpotw", "rotw"]
## The most of one conference-week's (or one tournament's) awards one school can win.
const MAX_PER_TEAM := 2
const TITLES := {"potw": "PLAYER OF THE WEEK", "rotw": "ROOKIE OF THE WEEK",
	"opotw": "OFFENSIVE PLAYER OF THE WEEK", "dpotw": "DEFENSIVE PLAYER OF THE WEEK"}
const SHORT := {"potw": "POTW", "rotw": "ROTW", "opotw": "OPOTW", "dpotw": "DPOTW"}
## The tabs' order: PEC, GCC, WWPC, NCC, AWPC (Colleges.CONFERENCES' own order).
const CONF_ORDER := ["MPSF", "BIGWEST", "WCC", "NWPC", "MAWPC"]

const KEEPER_SAVE := 2.5     # (ROTW's and the tournaments' keeper scale)
const KEEPER_GA := 2.0
## POTW's keeper scale: saves beyond KEEPER_POTW_PAR of the shots he faced, goals against at
## KEEPER_POTW_GA each, his steals and assists as a field player's. Calibrated on simulated
## seasons (--test conf_awards_measure: 2 of 230 conference-weeks, the sample's two most dominant
## keeper weeks: 15 saves / 2 against, 23 / 3 over two games; 14 / 7 scores below a typical best field week), so a keeper is POTW about one conference-week in a hundred.
const KEEPER_POTW_SAVE := 9.0
const KEEPER_POTW_PAR := 0.30   # (about a simulated keeper's usual save rate: only saving well above it counts)
const KEEPER_POTW_GA := 4.0
static var measure = null   # (a list: each conference-week's lines go in it, for the measure)
const DEF_SAVE := 1.2
const DEF_GA := 1.5
const MIN_FACED := 6
const EFFICIENCY := 6.0
const PARTICIPATION := 0.5   # a week's score over (1 - this) + this x games played
## A goal or assist in a game you played counts this many (Career's pg_g, pg_a): played games
## run to about 11 goals a side, simulated ones about 16.5 (--test sim_stats_measure), so without
## it your players' scoring could never compete. A touch under that gap: a lift, not a bonus.
const PLAYED_GOALS := 1.45
## PLAYER OF THE TOURNAMENT's team success (the Postseason Awards update): each tournament game his
## team won while he played ("tw" in TourneyAwards' totals) is worth a steal. A lean toward the
## teams that went deep, never a rule: a great tournament on a team out in the semis still wins it.
const TEAM_WIN := 4.0

# ------------------------------------------------------------------ deciding a week
## Decides the week just finished (every game of it played): each conference's four, once
## ("year:week" in Career.awards_done). Returns the records made ([] if already decided).
## Regular-season weeks only (the round's own kind, Schedule.is_playoff, never a week number): a
## conference or NCSA tournament round adds to its tournament's totals and, after its final, names
## that tournament's honours (TourneyAwards), but no weekly award. Weeks already decided in older
## saves stay as they were.
static func decide_week(c: Career) -> Array:
	var key := "%d:%d" % [c.year, c.week]
	if key in c.awards_done or c.phase != "season" or c.week >= c.schedule.size():
		return []
	c.awards_done.append(key)
	TourneyAwards.add_week(c)   # (a playoff round: its lines into its tournament's totals, this once)
	var made: Array = []
	if Schedule.is_playoff(c.schedule[c.week]):
		# (the Postseason Awards update) the weekly awards are the regular season's: a playoff round
		# names nobody of the week, only its tournament's own honours once its final is played
		TourneyAwards.decide(c)
		return made
	var label := week_label(c, c.week)
	for conf in CONF_ORDER:
		var lines := _lines(c, conf)
		if lines.is_empty():
			continue
		var week := pick_week(lines)
		if measure != null:
			measure.append({"lines": lines, "pick": week.keys(), "gk_potw": week.has("potw") and (week.potw.p as PoloPlayer).is_keeper(),
				"ids": week.values().map(func(x): return (x.p as PoloPlayer).id),
				"fresh": lines.filter(func(x): return WalkOns.is_rookie(x.p as PoloPlayer)).size(),
				"gks": lines.filter(func(x): return (x.p as PoloPlayer).is_keeper()).size()})
		for cat in PICK_ORDER:
			var e: Dictionary = week.get(cat, {})
			if e.is_empty():
				continue
			var rec := _record(c, e, cat, conf, label)
			c.conf_awards.append(rec)
			made.append(rec)
	TourneyAwards.decide(c)   # (a final this week: its tournament's three)
	return made

## A conference-week's four from its `lines` ({p, team, line}): {cat: entry with "score"}, a
## category nobody can be given missing. One player one award (by id).
static func pick_week(lines: Array) -> Dictionary:
	var out := {}
	var potw := _best(lines, "potw")
	if potw.is_empty():
		return out
	out["potw"] = potw
	var rest := lines.filter(func(e): return (e.p as PoloPlayer).id != (potw.p as PoloPlayer).id)
	out.merge(_allocate(rest, {String(potw.team): 1}))
	return out

## OPOTW, DPOTW and ROTW from `lines`, distinct winners, no school past MAX_PER_TEAM (counting
## `taken`, {team: awards already won this week}): of every way to give them from each category's
## best few (ALLOC_TOP, at most ALLOC_PER_TEAM of one school: enough, since the others can only
## take two men or fill two schools), the one that gives the most awards, then the three as near
## their own best as they can be, then OPOTW its best man, then DPOTW, then ROTW.
const ALLOC_TOP := 8
const ALLOC_PER_TEAM := 3
const REST := ["opotw", "dpotw", "rotw"]
static func _allocate(lines: Array, taken := {}) -> Dictionary:
	var ranked := {}
	for cat in REST:
		var short: Array = []
		var per := {}
		var rank := 0
		for x in _ranked(lines, cat):
			var tm := String(x.team)
			if int(per.get(tm, 0)) < ALLOC_PER_TEAM:
				per[tm] = int(per.get(tm, 0)) + 1
				x["rank"] = rank
				short.append(x)
				if short.size() >= ALLOC_TOP:
					break
			rank += 1
		ranked[cat] = short
	var best: Array = []
	var best_key: Array = []
	for i in (ranked.opotw as Array).size() + 1:
		for j in (ranked.dpotw as Array).size() + 1:
			for k in (ranked.rotw as Array).size() + 1:
				var pick := [i, j, k]
				var ids := {}
				var teams: Dictionary = taken.duplicate()
				var ok := true
				var n := 0
				var places := [0, 0, 0]
				for c in 3:
					var list: Array = ranked[REST[c]]
					if pick[c] < list.size():
						var e: Dictionary = list[pick[c]]
						var pid: int = (e.p as PoloPlayer).id
						var tm := String(e.team)
						teams[tm] = int(teams.get(tm, 0)) + 1
						ok = ok and not ids.has(pid) and int(teams[tm]) <= MAX_PER_TEAM
						ids[pid] = true
						places[c] = int(e.rank)
						n += 1
					else:
						places[c] = 1000   # (not given: behind any man who could have it)
				if not ok:
					continue
				# more awards first, then the three as near their best as they can all be (the lowest
				# total of their places), then OPOTW's place, DPOTW's, ROTW's (lower is better)
				var key := [n, -(places[0] + places[1] + places[2]), -places[0], -places[1], -places[2]]
				if best.is_empty() or _ahead(key, best_key):
					best = pick
					best_key = key
	var out := {}
	for c in 3:
		var list: Array = ranked[REST[c]]
		if not best.is_empty() and best[c] < list.size():
			var e: Dictionary = list[best[c]]
			e.erase("rank")
			out[REST[c]] = e
	return out

## "WEEK 3", or the round's name in the playoffs ("CONF SEMIS").
static func week_label(c: Career, w: int) -> String:
	if w < c.schedule.size() and Schedule.is_playoff(c.schedule[w]):
		return String(Schedule.SHORT_NAMES.get(String(c.schedule[w].kind), "PLAYOFFS"))
	return "WEEK %d" % (w + 1)

## Every player of the conference who played this week: [{p, team, line}].
static func _lines(c: Career, conf: String) -> Array:
	var out: Array = []
	for id in c.teams:
		var t: PoloTeam = c.teams[id]
		if t.conf != conf:
			continue
		for p: PoloPlayer in t.roster:
			var ln := c.week_line(p)
			if int(ln.get("gp", 0)) > 0:
				out.append({"p": p, "team": id, "line": ln})
	return out

## The week's winner of `cat` among `lines`, or {} if nobody can have it.
static func _best(lines: Array, cat: String) -> Dictionary:
	var r := _ranked(lines, cat)
	return r[0] if not r.is_empty() else {}

## Everyone who can have `cat`, best first (entries with "score"). The weekly four have no minimum
## (only eligibility: DPOTW a keeper, ROTW a freshman, OPOTW some offence); the tournament's three
## (TourneyAwards: pot, opot, dpot) keep theirs: a score above 0.
static func _ranked(lines: Array, cat: String) -> Array:
	var scored: Array = []
	for e in lines:
		var p: PoloPlayer = e.p
		if not eligible(p, e.line, cat):
			continue
		var s := score(p, e.line, cat)
		if not cat in CATS and s <= 0.0:
			continue
		var x: Dictionary = e.duplicate()
		x["score"] = s
		x["key"] = [snappedf(s, 0.0001), main_stats(p, e.line, cat), -(int(e.line.get("to", 0)) + int(e.line.get("ex", 0))), int(e.line.get("gp", 0)), -p.id]
		scored.append(x)
	scored.sort_custom(func(a, b): return _ahead(a.key, b.key))
	for x in scored:
		x.erase("key")
	return scored

## Can `p` have weekly award `cat` at all this week (no minimums: who he is, and for OPOTW that
## there's offence on his sheet)?
static func eligible(p: PoloPlayer, ln: Dictionary, cat: String) -> bool:
	match cat:
		"rotw":
			return WalkOns.is_rookie(p)   # (a freshman, or a walk-on in his first season here)
		"dpotw":
			return p.is_keeper()
		"opotw":
			return int(ln.get("g", 0)) + int(ln.get("a", 0)) + int(ln.get("ed", 0)) + int(ln.get("pd", 0)) > 0
	return true

static func _ahead(a: Array, b: Array) -> bool:
	for i in a.size():
		if a[i] != b[i]:
			return a[i] > b[i]
	return false

## A player's score for `cat` from his week's line (see the class notes).
static func score(p: PoloPlayer, ln: Dictionary, cat: String) -> float:
	var v := func(k: String) -> float:
		var n := float(ln.get(k, 0))
		if k == "g" or k == "a":
			n += (PLAYED_GOALS - 1.0) * float(ln.get("pg_" + k, 0))   # (played games' goals and assists, lifted)
		return n
	var raw := 0.0
	match cat:
		"potw":
			if p.is_keeper():
				# (the overall award's stricter keeper scale: saves beyond par, goals against hard)
				var faced: float = v.call("sv") + v.call("ga")
				raw = KEEPER_POTW_SAVE * (v.call("sv") - KEEPER_POTW_PAR * faced) - KEEPER_POTW_GA * v.call("ga") \
					+ 4.0 * v.call("st") + 4.0 * v.call("a")
			else:
				raw = 5.0 * v.call("g") + 4.0 * v.call("a") + 4.0 * v.call("st") + 4.0 * v.call("bl") + 2.0 * v.call("ed") \
					+ 3.0 * v.call("pd") - 2.0 * v.call("to") - 2.0 * v.call("ex")
		"rotw", "pot":
			if p.is_keeper():
				raw = KEEPER_SAVE * v.call("sv") - KEEPER_GA * v.call("ga") + 4.0 * v.call("st") + 4.0 * v.call("a")
			else:
				raw = 5.0 * v.call("g") + 4.0 * v.call("a") + 4.0 * v.call("st") + 4.0 * v.call("bl") + 2.0 * v.call("ed") \
					+ 3.0 * v.call("pd") - 2.0 * v.call("to") - 2.0 * v.call("ex")
		"opotw", "opot":
			if p.is_keeper() and cat == "opot":
				return 0.0
			raw = 6.0 * v.call("g") + 4.0 * v.call("a") + 2.0 * v.call("ed") + 3.0 * v.call("pd") - 2.0 * v.call("to")
			var sh := float(ln.get("sh", 0))
			if sh > 0.0:
				raw += EFFICIENCY * (float(ln.get("g", 0)) / sh - 0.45) * minf(1.0, sh / 4.0)   # (the real goals: efficiency is a share)
		"dpotw", "dpot":
			if p.is_keeper():
				if cat == "dpot" and v.call("sv") + v.call("ga") < MIN_FACED:
					return 0.0   # (the tournament's: a real tournament's defending)
				raw = DEF_SAVE * v.call("sv") - DEF_GA * v.call("ga") + 6.0 * v.call("st")
			elif cat == "dpotw":
				return 0.0   # (the weekly award is a goalkeeper's)
			else:
				raw = 6.0 * v.call("st") + 6.0 * v.call("bl") - 3.0 * v.call("ex") - 4.0 * v.call("pf5")
	if cat == "pot":
		raw += TEAM_WIN * v.call("tw")   # (the tournament's games his team won with him in the water)
	var gp := maxf(1.0, v.call("gp"))
	return raw / ((1.0 - PARTICIPATION) + PARTICIPATION * gp)

## The award's own stats, added up (the first tiebreak).
static func main_stats(p: PoloPlayer, ln: Dictionary, cat: String) -> int:
	var v := func(k: String) -> int: return int(ln.get(k, 0))
	match cat:
		"opotw":
			return v.call("g") + v.call("a")
		"dpotw":
			return v.call("sv") + v.call("st") if p.is_keeper() else v.call("st") + v.call("bl")
	return v.call("sv") if p.is_keeper() else v.call("g") + v.call("a") + v.call("st") + v.call("bl")

static func _record(c: Career, e: Dictionary, cat: String, conf: String, label: String) -> Dictionary:
	var p: PoloPlayer = e.p
	var keep := {}
	for k in e.line:
		if int(e.line[k]) != 0:
			keep[k] = int(e.line[k])
	c.award_players[str(p.id)] = JSON.stringify(p.to_dict())   # (his profile as he was, for when he's gone: kept as text, so it saves exactly)
	return {"year": c.year, "season": c.season_label(), "week": c.week, "label": label, "conf": conf, "cat": cat,
		"pid": p.id, "team": String(e.team), "name": "%s %s" % [p.first, p.last], "pos": p.pos, "cls": p.year,
		"stars": p.stars, "line": keep, "score": snappedf(float(e.score), 0.01)}

# ------------------------------------------------------------------ reading them back
## The four for a conference in a week ({cat: record}; a category nobody won is missing).
static func of(c: Career, year: int, week: int, conf: String) -> Dictionary:
	var out := {}
	for a in c.conf_awards:
		if int(a.year) == year and int(a.week) == week and String(a.conf) == conf and not bool(a.get("hist", false)):
			out[String(a.cat)] = a
	return out

## The awards this dynasty has actually given (Legacy's made-up seasons before it, "hist", left out).
static func earned(c: Career) -> Array:
	return c.conf_awards.filter(func(a): return not bool(a.get("hist", false)))

## The weeks decided, oldest first: [[year, week, label, season], ...]. earned_only: this
## dynasty's own weeks (the Conference Awards screen), not Legacy's past seasons.
static func weeks(c: Career, earned_only := false) -> Array:
	var seen := {}
	var out: Array = []
	for a in (earned(c) if earned_only else c.conf_awards):
		var k := "%d:%d" % [int(a.year), int(a.week)]
		if not seen.has(k):
			seen[k] = true
			out.append([int(a.year), int(a.week), String(a.label), String(a.season)])
	return out

## A player's weekly awards by where he won them: [[conf, cat, count], ...], CONF_ORDER's order
## then any older conference's, CATS' order within each. A conference's awards stay its own
## wherever he plays now (the record's conf is the one he won it in).
static func by_conf(c: Career, pid: int) -> Array:
	var n := {}
	var confs: Array = CONF_ORDER.duplicate()
	for a in c.conf_awards:
		if int(a.pid) != pid:
			continue
		var k := "%s|%s" % [a.conf, a.cat]
		n[k] = int(n.get(k, 0)) + 1
		if not String(a.conf) in confs:
			confs.append(String(a.conf))
	var out: Array = []
	for conf in confs:
		for cat in CATS:
			var k := "%s|%s" % [conf, cat]
			if n.has(k):
				out.append([conf, cat, int(n[k])])
	return out

## A player's weekly awards, all of them: {cat: count}.
static func counts(c: Career, pid: int) -> Dictionary:
	var out := {}
	for a in c.conf_awards:
		if int(a.pid) == pid:
			out[String(a.cat)] = int(out.get(String(a.cat), 0)) + 1
	return out

## "PLAYER OF THE WEEK x2  DEFENSIVE PLAYER OF THE WEEK x1" (short names), "" with none.
static func counts_text(c: Career, pid: int) -> String:
	var n := counts(c, pid)
	var parts := PackedStringArray()
	for cat in CATS:
		if n.has(cat):
			parts.append("%s x%d" % [SHORT[cat], int(n[cat])])
	return "  ".join(parts)

## The week's line as words: "5 GOALS | 3 ASSISTS | 2 EXCL DRAWN" (a keeper: saves, save %).
static func line_text(rec: Dictionary) -> String:
	var ln: Dictionary = rec.line
	if ln.is_empty():
		return ""   # (a pre-dynasty award, Legacy: no stats claimed)
	var parts := PackedStringArray()
	var keeper := int(rec.pos) == PoloPlayer.Pos.GK
	var add := func(k: String, one: String, many: String) -> void:
		var n := int(ln.get(k, 0))
		if n > 0:
			parts.append("%d %s" % [n, one if n == 1 else many])
	if keeper:
		add.call("sv", "SAVE", "SAVES")
		var faced := int(ln.get("sv", 0)) + int(ln.get("ga", 0))
		if faced > 0:
			parts.append("%d%% SAVED" % roundi(100.0 * int(ln.get("sv", 0)) / faced))
		add.call("st", "STEAL", "STEALS")
	elif String(rec.get("cat", "")) == "dpotw":
		add.call("st", "STEAL", "STEALS")   # (the defensive award: its own stats first)
		add.call("bl", "BLOCK", "BLOCKS")
		add.call("g", "GOAL", "GOALS")
		add.call("a", "ASSIST", "ASSISTS")
	else:
		add.call("g", "GOAL", "GOALS")
		add.call("a", "ASSIST", "ASSISTS")
		add.call("st", "STEAL", "STEALS")
		add.call("bl", "BLOCK", "BLOCKS")
		add.call("ed", "EXCL DRAWN", "EXCL DRAWN")
		add.call("pd", "PEN DRAWN", "PENS DRAWN")
	if int(ln.get("gp", 0)) > 1:
		parts.append("%d GAMES" % int(ln.gp))
	return " | ".join(parts.slice(0, 4))

## The winner as a player: still in the league (his team's roster), else as he was when he won.
static func player_of(c: Career, rec: Dictionary) -> PoloPlayer:
	for id in c.teams:
		var p := (c.teams[id] as PoloTeam).find_id(int(rec.pid))
		if p != null:
			return p
	var text := String(c.award_players.get(str(rec.pid), ""))
	var d = JSON.parse_string(text) if text != "" else null
	return PoloPlayer.from_dict(d) if d is Dictionary else null

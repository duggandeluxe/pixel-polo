class_name LeagueNews
## LEAGUE NEWS (the Dynasty Hub): a retro sports news feed written from what really happened, a
## week at a time (Career.end_week, once its games are all played): every story is a game, a
## ranking, a table or an award the dynasty recorded. Nothing is made up. Each story has an id
## ("year:week:kind:team"), so the same story is never written twice, and the feed is saved
## (Career.league_news, newest first, NEWS_MAX kept).
##
## A story: {id, year, week, label, head, text, team}: `head` the headline, `text` one line of
## summary, `team` the school its logo is (or "").
##
## What makes a story:
##   UPSET         a team beat one ranked UPSET_GAP or more places above it in the Top 20 (the
##                 poll out before the week); the biggest UPSETS_MAX of the week
##   NO. 1 FALLS   the No. 1 team lost (unless it's already the week's upset)
##   PERFECT       a team still unbeaten in the regular season at PERFECT_AT wins
##   RACE          two teams level, or a game apart, at the top of a conference (weeks RACE_WEEKS)
##   NEW NO. 1     the poll's No. 1 changed
##   AWARDS        each conference's PLAYER OF THE WEEK (ConfAwards)
##   CHAMPIONS     a conference final or the NCSA final won
##   YOUR PROGRAM  your win streaks of 5 and 10 (CreditRewards' claims), an unbeaten regular season

const NEWS_MAX := 150
const UPSET_GAP := 6
const UPSETS_MAX := 2
const PERFECT_AT := [5, 8, 12, 16]
const RACE_WEEKS := [5, 8]

## The week just played (before the week moves on and its poll is out: `ranks` is the one out
## before it). Returns the stories written.
static func week(c: Career, ranks: Dictionary) -> Array:
	var out: Array = []
	var rd := c.cur()
	if rd.is_empty() or c.phase != "season":
		return out
	var label := ConfAwards.week_label(c, c.week)
	var add := func(kind: String, team: String, head: String, text: String) -> void:
		var id := "%d:%d:%s:%s" % [c.year, c.week, kind, team]
		if c.league_news.any(func(n): return String(n.id) == id):
			return
		var story := {"id": id, "year": c.year, "week": c.week, "label": "%s %s" % [c.season_label(), label], "head": head, "text": text, "team": team}
		c.league_news.push_front(story)
		out.append(story)
	# upsets and the No. 1 falling, from the games' results and the poll before them
	var upsets: Array = []
	var fell := ""
	for g in rd.games:
		if g.r == null:
			continue
		var w := Schedule.winner(g)
		var l: String = g.a if w == g.h else g.h
		var rw := int(ranks.get(w, 99))
		var rl := int(ranks.get(l, 99))
		if rl <= Poll.TOP and rw - rl >= UPSET_GAP:
			upsets.append([rw - rl, w, l, g])
		if rl == 1:
			fell = l
	upsets.sort_custom(func(a, b): return int(a[0]) > int(b[0]))
	var upset_losers: Array = []
	for u in upsets.slice(0, UPSETS_MAX):
		var g: Dictionary = u[3]
		upset_losers.append(String(u[2]))
		add.call("upset", String(u[1]), "%s SHOCK NO. %d %s!" % [_short(c, u[1]), int(ranks.get(u[2], 0)), _short(c, u[2])],
			"%s beat %s %s." % [_name(c, u[1]), _name(c, u[2]), Schedule.score_text(g, g.h == u[1])])
	if fell != "" and not fell in upset_losers:
		add.call("fall", fell, "NO. 1 %s FALLS!" % _short(c, fell), "The top-ranked %s lost this week, to %s." % [_name(c, fell), _beat_by(c, rd, fell)])
	# unbeaten, at the milestones
	if not Schedule.is_playoff(rd):
		for id in c.teams:
			var row: Dictionary = c.table.get(id, {})
			if int(row.get("l", 1)) == 0 and int(row.get("w", 0)) in PERFECT_AT:
				add.call("perfect%d" % int(row.w), id, "%s STILL PERFECT AT %d-0!" % [_short(c, id), int(row.w)], "%s haven't lost a game this season." % _name(c, id))
		# the conference races
		if c.week in RACE_WEEKS:
			for conf in ConfAwards.CONF_ORDER:
				var order := Schedule.conf_table(c.teams, c.table, conf)
				if order.size() < 2:
					continue
				var a: Dictionary = c.table[order[0]]
				var b: Dictionary = c.table[order[1]]
				if absi(int(a.cw) - int(b.cw)) <= 1 and int(a.cw) + int(a.cl) > 0:
					add.call("race", String(order[0]), "%s RACE HEATS UP!" % Colleges.conf_abbr(conf),
						"%s (%d-%d) and %s (%d-%d) lead the %s." % [_name(c, order[0]), int(a.cw), int(a.cl), _name(c, order[1]), int(b.cw), int(b.cl), Colleges.conference(conf).get("name", conf)])
	# the champions
	for g in rd.games:
		if g.r == null:
			continue
		var w := Schedule.winner(g)
		if String(rd.kind) == "conf_final":
			add.call("conf_champ", w, "%s WIN THE %s!" % [_short(c, w), Colleges.conf_abbr((c.teams[w] as PoloTeam).conf)],
				"%s are conference champions, %s over %s." % [_name(c, w), Schedule.score_text(g, g.h == w), _name(c, g.a if w == g.h else g.h)])
		elif String(rd.kind) == "nat_final":
			add.call("nat_champ", w, "%s ARE NATIONAL CHAMPIONS!" % _short(c, w),
				"%s won the NCSA final %s over %s." % [_name(c, w), Schedule.score_text(g, g.h == w), _name(c, g.a if w == g.h else g.h)])
	# the week's conference awards
	for a in c.conf_awards:
		if int(a.year) != c.year or int(a.week) != c.week or String(a.cat) != "potw":
			continue
		var cls: String = ["", "FRESHMAN", "SOPHOMORE", "JUNIOR", "SENIOR"][clampi(int(a.cls), 1, 4)]
		add.call("potw_" + String(a.conf), String(a.team), "%s %s WINS %s POTW!" % [_short(c, a.team), cls, Colleges.conf_abbr(String(a.conf))],
			"%s: %s." % [String(a.name), ConfAwards.line_text(a).to_lower()])
	# your program
	for k in [["streak5", 5], ["streak10", 10]]:
		if ("%d:%s" % [c.year, k[0]]) in c.cr_claims:
			add.call(String(k[0]), c.school, "%s WIN %d STRAIGHT!" % [_short(c, c.school), int(k[1])], "%s are on a %d-game winning streak." % [_name(c, c.school), int(k[1])])
	if ("%d:undefeated" % c.year) in c.cr_claims:
		add.call("unbeaten", c.school, "%s FINISH THE REGULAR SEASON UNBEATEN!" % _short(c, c.school), "A perfect regular season for %s." % _name(c, c.school))
	if c.league_news.size() > NEWS_MAX:
		c.league_news.resize(NEWS_MAX)
	return out

## After the week's poll is out: a new No. 1 makes the news. `before` the No. 1 going in.
static func new_top(c: Career, before: String) -> void:
	var poll := Poll.latest(c)
	var ranks: Array = poll.get("ranks", [])
	if ranks.is_empty() or String(ranks[0]) == before or before == "":
		return
	var top := String(ranks[0])
	var id := "%d:%d:top:%s" % [c.year, c.week, top]
	if c.league_news.any(func(n): return String(n.id) == id):
		return
	c.league_news.push_front({"id": id, "year": c.year, "week": c.week, "label": "%s %s" % [c.season_label(), ConfAwards.week_label(c, c.week)],
		"head": "%s CLIMB TO NO. 1!" % _short(c, top), "text": "%s top the new %s poll." % [_name(c, top), String(poll.get("label", "Top 20")).to_lower()], "team": top})

static func _short(c: Career, id: String) -> String:
	return Colleges.short_name(c.teams[id]).to_upper() if c.teams.has(id) else id

static func _name(c: Career, id: String) -> String:
	return (c.teams[id] as PoloTeam).name if c.teams.has(id) else id

## Who beat `id` this week ("" if nobody).
static func _beat_by(c: Career, rd: Dictionary, id: String) -> String:
	for g in rd.games:
		if g.r != null and (g.h == id or g.a == id) and Schedule.winner(g) != id:
			return _name(c, Schedule.winner(g))
	return "an opponent"

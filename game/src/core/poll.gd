class_name Poll
## The National Top 20: a weekly coaches-style poll of all 30 teams, ranked by this season's
## results, never by the team ratings (it never changes them either). Each team's score, 0-100:
##   45 x win % + 25 x strength of schedule + 20 x quality wins + 10 x recent form
## each input on a 0-1 scale. Ties: head to head, then quality wins, then strength of schedule.
## The preseason poll is last season's final poll (a new career's: the team ratings, best first);
## it fades out over the first three weeks, and from week 4 on the poll is results only.
## Published after every regular-season week, after the conference tournament rounds (the poll
## after the conference finals is the SELECTION poll the NCSA Championship's at-large bids come
## from) and after the NCSA final (the FINAL poll, next season's preseason). Each poll keeps
## everyone's place, so the screen shows the previous rank and the movement.
## Every poll then keeps the Big Four in the Top 4 (see protect_big_four).
## A poll: {wk: week index it follows (-1 preseason), kind, label, ranks: [ids, best first],
## pts: [scores, the same order], rec: [[w, l, cw, cl], the same order]}.

const TOP := 20
const RV := 2                   # receiving votes: shown under the Top 20
const W_WIN := 45.0
const W_SOS := 25.0
const W_QW := 20.0
const W_FORM := 10.0
const PRIOR_WEEKS := 3          # the preseason poll counts for less each week, nothing from week 4
## Strength of schedule is the RPI's: two thirds the opponents' win %, a third their opponents'.
## It lives in a narrow band, so SOS_LO..SOS_HI is stretched over 0-1.
const SOS_LO := 0.3
const SOS_HI := 0.7
## A win over a team ranked this high in the poll before it is worth this much; QW_FULL of them
## max the quality-wins input.
const QW_VALUE := [[5, 1.0], [10, 0.8], [15, 0.6], [20, 0.4], [22, 0.2]]
const QW_FULL := 3.0
## Recent form: the last FORM_GAMES results, the latest counting most.
const FORM_GAMES := 5
## The preseason order as a poll score: #1 PRIOR_TOP down to #30 PRIOR_BOTTOM.
const PRIOR_TOP := 90.0
const PRIOR_BOTTOM := 10.0

## The preseason poll: last season's final poll, or the team ratings for a new career.
static func preseason(c: Career) -> void:
	var prior: Array = []
	for fp in c.final_polls:
		if int(fp.year) == c.year - 1:
			prior = (fp.ranks as Array).filter(func(id): return c.teams.has(id))
	if prior.size() != c.teams.size():
		prior = protect_big_four(hierarchy(c.teams), [], -1)   # a new career: no Big Four team beaten yet
	c.season["poll_prior"] = prior
	var polls: Array = []
	c.season["polls"] = polls
	var pts: Array = []
	for i in prior.size():
		pts.append(Career._whole(snappedf(prior_points(i + 1, prior.size()), 0.1)))
	var rec: Array = prior.map(func(_id): return [0, 0, 0, 0])
	polls.append({"wk": -1, "kind": "pre", "label": "PRESEASON", "ranks": prior.duplicate(), "pts": pts, "rec": rec})

## The initial team hierarchy: OVR, then OFF, then the id (a fixed order).
static func hierarchy(teams: Dictionary) -> Array:
	var ids: Array = teams.keys()
	ids.sort_custom(func(a, b):
		var ta: PoloTeam = teams[a]
		var tb: PoloTeam = teams[b]
		if ta.rating() != tb.rating():
			return ta.rating() > tb.rating()
		if ta.off_rating() != tb.off_rating():
			return ta.off_rating() > tb.off_rating()
		return String(a) < String(b))
	return ids

static func prior_points(rank: int, n: int) -> float:
	return PRIOR_TOP - (PRIOR_TOP - PRIOR_BOTTOM) * float(rank - 1) / maxf(1.0, n - 1)

## How much the preseason poll still counts once `weeks` regular-season weeks are played.
static func prior_weight(weeks: int) -> float:
	return maxf(0.0, 1.0 - float(weeks) / PRIOR_WEEKS)

## The week at schedule index `w` is over: its poll, if one comes out after it.
static func publish(c: Career, w: int) -> void:
	if w < 0 or w >= c.schedule.size():
		return
	if not c.season.has("polls"):
		rebuild(c, w - 1)
	var kind := String(c.schedule[w].kind)
	var label := ""
	match kind:
		"conf_qf":
			label = "CONF. QUARTERFINALS"
		"conf_semi":
			label = "CONF. SEMIFINALS"
		"conf_final":
			label = "SELECTION"
		"nat_final":
			label = "FINAL"
		_:
			if Schedule.is_playoff(c.schedule[w]):
				return   # no poll during the NCSA Championship until it's over
			label = "WEEK %d" % (w + 1)
	var polls: Array = c.season.polls
	polls = polls.filter(func(p): return int(p.wk) < w)   # a week is published once
	var poll := make(c.teams, c.schedule, w, c.season.get("poll_prior", hierarchy(c.teams)), latest_of(polls))
	poll.merge({"wk": w, "kind": {"conf_final": "select", "nat_final": "final"}.get(kind, "week"), "label": label}, true)
	polls.append(poll)
	c.season["polls"] = polls
	if kind == "nat_final":
		c.final_polls = c.final_polls.filter(func(fp): return int(fp.year) != c.year)
		c.final_polls.append({"year": c.year, "ranks": (poll.ranks as Array).duplicate()})
		if c.final_polls.size() > 3:
			c.final_polls = c.final_polls.slice(c.final_polls.size() - 3)

## A season with no polls yet (an older save): the preseason one from the ratings, then every
## week's up to schedule index `upto` (default: the weeks already played).
static func rebuild(c: Career, upto: int = -2) -> void:
	if upto == -2:
		upto = c.week - 1
	preseason(c)
	for w in range(0, mini(upto + 1, c.schedule.size())):
		publish(c, w)

## The poll after schedule index `upto`, from the results so far, with `prev` (the poll before
## it) deciding which wins are quality wins: {ranks, pts, rec}.
static func make(teams: Dictionary, rounds: Array, upto: int, prior: Array, prev: Dictionary) -> Dictionary:
	var weeks := 0
	for i in mini(upto + 1, rounds.size()):
		if not Schedule.is_playoff(rounds[i]):
			weeks += 1
	var ref := rank_map(prev) if not prev.is_empty() else _order_map(prior)
	var sc := scores(teams, rounds, upto, ref)
	var pw := prior_weight(weeks)
	var prior_rank := _order_map(prior)
	var total := {}
	for id in teams:
		var pr := prior_points(int(prior_rank.get(id, teams.size())), teams.size())
		total[id] = lerpf(float(sc[id].score), pr, pw)
	var ids := protect_big_four(order(teams, total, sc), rounds, upto)
	return {"ranks": ids, "pts": ids.map(func(id): return Career._whole(snappedf(total[id], 0.1))),
		"rec": ids.map(func(id): return sc[id].rec)}

## THE BIG FOUR: the four dominant programs keep their Top 4 places. A Big Four team that has
## lost only to the other three this season is PROTECTED: it is in the Top 4 whatever its score.
## One beaten by a school outside the Big Four loses that protection, and its place opens: it goes
## to the best-ranked (by the normal order) of the unprotected Big Four teams and the outside
## schools that have beaten a Big Four team. No other school reaches the Top 4: a record, schedule,
## score or title never earns a place on its own. Inside the Top 4, and from #5 down, the normal
## order stands. Worked out from the season's results every poll, so nothing extra is saved; the
## preseason poll is last season's final one as it stood (its giant killers keep their places until
## the first poll of the new season).
const BIG_FOUR := ["CULA", "CUSC", "STAM", "ALC"]
const BIG_TOP := 4

static func protect_big_four(ids: Array, rounds: Array, upto: int) -> Array:
	var big: Array = BIG_FOUR.filter(func(id): return id in ids)
	if big.is_empty():
		return ids
	var res := results(rounds, upto)
	var giant_killers := {}   # outside schools that have beaten a Big Four team
	var protected: Array = []
	for b in big:
		var beaten := false
		for e in res.get(b, []):
			if not e.won and not e.o in BIG_FOUR:
				beaten = true
				giant_killers[e.o] = true
		if not beaten:
			protected.append(b)
	var open := mini(BIG_TOP, ids.size()) - protected.size()
	var top: Array = protected.duplicate()
	for id in ids:   # best first
		if open <= 0:
			break
		if id in protected:
			continue
		if id in big or giant_killers.has(id):
			top.append(id)
			open -= 1
	var out: Array = ids.filter(func(id): return id in top)   # the Top 4 in the normal order
	out.append_array(ids.filter(func(id): return not id in top))
	return out

## Best first: the score, then head to head, quality wins and strength of schedule (`sc`'s).
static func order(teams: Dictionary, total: Dictionary, sc: Dictionary) -> Array:
	var ids: Array = teams.keys()
	ids.sort()
	ids.sort_custom(func(a, b):
		var ta := snappedf(float(total[a]), 0.01)
		var tb := snappedf(float(total[b]), 0.01)
		if ta != tb:
			return ta > tb
		var h2h := int(sc[a].beat.get(b, 0)) - int(sc[b].beat.get(a, 0))
		if h2h != 0:
			return h2h > 0
		if sc[a].qw != sc[b].qw:
			return sc[a].qw > sc[b].qw
		if sc[a].sos != sc[b].sos:
			return sc[a].sos > sc[b].sos
		return String(a) < String(b))
	return ids

## Every team's results this season up to schedule index `upto`, in the order played:
## id -> [{o: opponent, won, c: a conference game}].
static func results(rounds: Array, upto: int) -> Dictionary:
	var out := {}
	for i in mini(upto + 1, rounds.size()):
		var r: Dictionary = rounds[i]
		var games: Array = (r.games as Array).duplicate()
		games.sort_custom(func(x, y): return int(x.get("d", 0)) < int(y.get("d", 0)))
		for g in games:
			if g.r == null:
				continue
			var w := Schedule.winner(g)
			var conf: bool = not Schedule.is_playoff(r) and Schedule.is_conf_game(r, g)
			for side in [String(g.h), String(g.a)]:
				if not out.has(side):
					out[side] = []
				out[side].append({"o": String(g.a) if side == String(g.h) else String(g.h), "won": w == side, "c": conf})
	return out

## The four inputs (0-1) and the score for every team: id -> {win, sos, qw, form, score, rec,
## beat: {opponent: wins over him}}. `ref` is the poll before (id -> rank) for the quality wins.
static func scores(teams: Dictionary, rounds: Array, upto: int, ref: Dictionary) -> Dictionary:
	var res := results(rounds, upto)
	var wl := {}
	for id in teams:
		var games: Array = res.get(id, [])
		var w := games.filter(func(e): return e.won).size()
		wl[id] = [w, games.size() - w]
	var out := {}
	var owp := {}
	for id in teams:
		owp[id] = _owp(id, res, wl)
	for id in teams:
		var games: Array = res.get(id, [])
		var n := games.size()
		var w: int = wl[id][0]
		var win := float(w) / n if n > 0 else 0.5
		# strength of schedule: the RPI's 2/3 opponents' win % + 1/3 their opponents'
		var oowp := 0.0
		for e in games:
			oowp += float(owp.get(e.o, 0.5))
		var sos_raw := (2.0 * float(owp[id]) + (oowp / n if n > 0 else 0.5)) / 3.0
		var sos := clampf((sos_raw - SOS_LO) / (SOS_HI - SOS_LO), 0.0, 1.0)
		var qw_pts := 0.0
		var beat := {}
		for e in games:
			if e.won:
				qw_pts += quality(int(ref.get(e.o, 99)))
				beat[e.o] = int(beat.get(e.o, 0)) + 1
		var qw := minf(1.0, qw_pts / QW_FULL)
		var form := 0.5
		if n > 0:
			var recent: Array = games.slice(maxi(0, n - FORM_GAMES))
			var num := 0.0
			var den := 0.0
			for k in recent.size():
				var wt := float(k + 1)
				num += wt if recent[k].won else 0.0
				den += wt
			form = num / den
		var cw := games.filter(func(e): return e.c and e.won).size()
		var cl := games.filter(func(e): return e.c and not e.won).size()
		out[id] = {"win": win, "sos": sos, "qw": qw, "form": form, "beat": beat,
			"score": W_WIN * win + W_SOS * sos + W_QW * qw + W_FORM * form, "rec": [w, n - w, cw, cl]}
	return out

## What a win over the team ranked `rank` (in the poll before) is worth.
static func quality(rank: int) -> float:
	for qv in QW_VALUE:
		if rank <= int(qv[0]):
			return float(qv[1])
	return 0.0

## A team's opponents' win %, leaving out their games against it (one entry per game).
static func _owp(id: String, res: Dictionary, wl: Dictionary) -> float:
	var games: Array = res.get(id, [])
	if games.is_empty():
		return 0.5
	var total := 0.0
	for e in games:
		var o: String = e.o
		var w: int = wl[o][0]
		var l: int = wl[o][1]
		for f in res.get(o, []):
			if f.o == id:
				if f.won:
					w -= 1
				else:
					l -= 1
		total += float(w) / (w + l) if w + l > 0 else 0.5
	return total / games.size()

# ------------------------------------------------------------------ reading the polls
static func latest_of(polls: Array) -> Dictionary:
	return polls[polls.size() - 1] if not polls.is_empty() else {}

## The poll out now ({} before the first).
static func latest(c: Career) -> Dictionary:
	return latest_of(c.season.get("polls", []))

## The poll before `poll` this season: the one movement is measured from ({} for the first).
static func previous(c: Career, poll: Dictionary) -> Dictionary:
	var polls: Array = c.season.get("polls", [])
	var i := polls.find(poll)
	return polls[i - 1] if i > 0 else {}

## id -> rank (1 = best) in `poll`.
static func rank_map(poll: Dictionary) -> Dictionary:
	return _order_map(poll.get("ranks", []))

static func _order_map(ids: Array) -> Dictionary:
	var out := {}
	for i in ids.size():
		out[ids[i]] = i + 1
	return out

## Where `id` is in `poll`: 1-30 (0 if it isn't in it).
static func rank_in(poll: Dictionary, id: String) -> int:
	return (poll.get("ranks", []) as Array).find(id) + 1

## The poll's Top 20 and its receiving-votes teams, as rows:
## {rank, id, rec, pts, prev (0: unranked or none), move ("NEW", "-", or +n/-n as an int), rv}.
static func rows(c: Career, poll: Dictionary) -> Array:
	var prev := previous(c, poll)
	var prev_ranks := rank_map(prev)
	var out: Array = []
	var ranks: Array = poll.get("ranks", [])
	for i in mini(TOP + RV, ranks.size()):
		var id: String = ranks[i]
		var before := int(prev_ranks.get(id, 0))
		var shown := before if before > 0 and before <= TOP else 0
		var move: Variant = shown - (i + 1)
		if prev.is_empty() or (shown == 0 and i >= TOP):
			move = "-"
		elif shown == 0:
			move = "NEW"
		out.append({"rank": i + 1, "id": id, "rec": poll.rec[i], "pts": poll.pts[i], "prev": shown, "move": move, "rv": i >= TOP})
	return out

class_name Offseason
## Between seasons (the Credit Economy & Recruiting Overhaul: no portals, no spring, no lock week):
##   begin:      straight after the NCSA final. The season's review, prestige, awards, records, job
##               offers. The season is "done": its tables and polls stay up until you start the
##               next one (the hub's NEXT SEASON: Career.end_week runs the transition).
##   transition: seniors graduate everywhere and everyone else grows a year; your signed recruits
##               (Career.incoming) join as freshmen. Your roster over its cap (Career.roster_cap, or more keepers than
##               Career.keeper_cap): the season waits in phase "cuts" for you to cut players by
##               hand (the roster_cuts screen: cut, roster_legal). Nobody of yours is ever cut
##               automatically, and a cut never refunds a credit.
##   finish:     your roster is legal: the players cut this off-season may be signed by AI
##               programs with places for them (_pickups); each AI program's empty places then get
##               freshmen made for its prestige (Recruiting.ai_class), and walk-ons fill any short
##               of seven (_ai_rosters); walk-ons fill yours to seven if it's short, every player's
##               stars take in the year's development (PlayerForm.develop), and the next season
##               starts (its +15 credits and a new recruiting market: Career.start_season).

## A season moves a program's prestige by at most this much: a reputation is built over years.
const PRESTIGE_STEP := 8.0

## The season is over: the review, then the roster transition.
static func begin(c: Career) -> void:
	var lines: Array = []
	var me := c.team()
	_final_result(c)
	var champion: String = c.season.get("champion", "")
	TeamHonours.record_season(c)   # (the season's champions, kept for every program's trophy case)
	if champion != "":
		lines.append("NCSA champions: %s" % c.teams[champion].name)
	lines.append("%s: %s, %s in the %s" % [me.name, c.record_text(), c.season.finish, c.conf_name()])
	var prestige_before := {}
	for id in c.teams:
		prestige_before[id] = (c.teams[id] as PoloTeam).prestige
	_prestige(c)
	# awards and the season's records, before the seniors leave
	lines.append_array(Awards.run(c, prestige_before))
	for ln in Records.check_season(c):
		if ln.begins_with("NCSA") or ln.contains(c.school) or ln.begins_with("SCHOOL"):
			lines.append(ln)
	c.coach.rep = clampi(int(c.coach.rep) + int(c.table[c.school].w) / 2 + (6 if c.school in c.season.conf_champs else 0) + (10 if champion == c.school else 0), 0, 100)
	c.history.append({"year": c.season_label(), "team": c.school, "w": int(c.table[c.school].w), "l": int(c.table[c.school].l),
		"cw": int(c.table[c.school].cw), "cl": int(c.table[c.school].cl), "rank": c.conf_rank(), "finish": c.season.finish,
		"poll": Poll.rank_in(Poll.latest(c), c.school)})
	var top := _top_scorer(me)
	if top != null:
		lines.append("Top scorer: %s, %d goals" % [top.short_name(), top.stat("g")])
	var paid: Array = (c.season.get("credit_log", []) as Array)
	var earned := 0
	for e in paid:
		earned += int(e[1])
	lines.append("Credits earned this season: %s" % CreditCoin.tag(earned))
	var recap := {"type": "recap", "title": "%s SEASON REVIEW" % c.season_label(), "lines": lines, "next": c.next_season_label()}
	c.queue.append(recap)
	# the coach's future: schools that want you after a good season (nobody fires you)
	var offers := _offers(c, false)
	if not offers.is_empty():
		c.queue.append({"type": "offers", "offers": offers})
	c.phase = "done"

## Graduation, a year older, the freshmen in. Your roster legal: finish (the next season). Over
## its cap: phase "cuts", and the season waits for your cuts.
static func transition(c: Career) -> void:
	var lines: Array = []
	var me := c.team()
	var grads: Array = me.roster.filter(func(p: PoloPlayer): return p.year >= 4)
	if not grads.is_empty():
		lines.append("Graduated: " + ", ".join(grads.map(func(p): return p.short_name())))
	for id in c.teams:
		var t: PoloTeam = c.teams[id]
		var stay: Array[PoloPlayer] = []
		for p in t.roster:
			if p.year >= 4:
				for ln in Records.check_career(c, p, id):
					if id == c.school or ln.begins_with("NCSA"):
						lines.append(ln)
				continue
			_age(c, p, id == c.school)
			stay.append(p)
		t.roster = stay
	# your signed recruits, as freshmen (once: the list is emptied as they join)
	var signed: Array = []
	for r in c.incoming:
		var p: PoloPlayer = r.p
		if me.find_id(p.id) != null:
			continue   # (never twice)
		p.year = 1
		p.schol = me.roster.filter(func(q: PoloPlayer): return q.schol).size() < Career.SCHOL_MAX
		join(c, me, p)
		signed.append("%s (%s, %s*)" % [p.short_name(), p.pos_text(), PlayerForm.star_text(p.stars)])
	c.incoming = []
	if not signed.is_empty():
		lines.append("Freshmen joined: " + ", ".join(signed))
	# (the AI programs fill their places once your cuts are made: finish, _ai_rosters, so the
	# players you cut can be signed by them first)
	c.season["lock_lines"] = lines
	if roster_legal(c):
		finish(c)
		return
	c.phase = "cuts"
	me.sync_lineup()
	c.add_news("ROSTER CUTS REQUIRED: %d / %d" % [me.roster.size(), c.roster_max()])

# ------------------------------------------------------------------ roster cuts
## Players you must still cut to be at your cap (0: none).
static func cuts_needed(c: Career) -> int:
	return maxi(0, c.team().roster.size() - c.roster_max())

## Keepers over Career.keeper_cap (0: none).
static func keepers_over(c: Career) -> int:
	return maxi(0, _keepers(c.team()) - c.keeper_cap(c.school))

static func roster_legal(c: Career) -> bool:
	return cuts_needed(c) == 0 and keepers_over(c) == 0

## Why `p` can't be cut now ("" if he can): only while cuts are due, never your last keeper or
## below six field players (a legal lineup), and only a keeper when it's keepers that are over.
static func cut_block(c: Career, p: PoloPlayer) -> String:
	var t := c.team()
	if c.phase != "cuts" or roster_legal(c):
		return "Your roster is set."
	if not p in t.roster:
		return "He's not on your roster."
	if p.is_keeper() and _keepers(t) <= 1:
		return "He's your only goalkeeper."
	if not p.is_keeper() and t.roster.size() - _keepers(t) <= Career.FIELD_MAX:
		return "You need %d field players." % Career.FIELD_MAX
	if cuts_needed(c) == 0 and not p.is_keeper():
		return "Cut a goalkeeper: you may carry %d." % c.keeper_cap(c.school)
	return ""

## CUT PLAYER (after the screen's confirmation): he leaves the program for good. Nothing is
## refunded. Returns "" or why not.
static func cut(c: Career, p: PoloPlayer) -> String:
	var block := cut_block(c, p)
	if block != "":
		return block
	var t := c.team()
	t.roster.erase(p)
	t.sync_lineup()
	c.cut_pool.append({"p": p, "from": c.school})   # (another program may sign him: _pickups)
	c.add_news("Released: %s" % p.short_name())
	(c.season.get("lock_lines", []) as Array).append("Cut: %s" % p.short_name())
	return ""

## CONTINUE TO NEXT SEASON: only with a legal roster. Returns "" or why not.
static func finish_cuts(c: Career) -> String:
	if c.phase != "cuts":
		return ""
	if not roster_legal(c):
		return "Your roster is still over its limit."
	finish(c)
	return ""

## The roster is set: walk-ons to seven, the year's development, the report, the next season.
static func finish(c: Career) -> void:
	var me := c.team()
	var lines: Array = c.season.get("lock_lines", [])
	lines.append_array(_ai_rosters(c))
	var had: Array = me.roster.duplicate()
	var walkons := _fill(c, me, Career.ROSTER_MAX)
	me.sync_lineup()
	CollegeGen.hold_bench(me, me.roster.filter(func(q: PoloPlayer): return not q in had))   # (walk-ons only: never your signings)
	if walkons > 0:
		lines.append("%d walk-on%s joined to fill the roster" % [walkons, "" if walkons == 1 else "s"])
	me.sync_lineup()
	lines.append("Roster set: %d players, %d on scholarship" % [me.roster.size(), me.roster.filter(func(p: PoloPlayer): return p.schol).size()])
	# the year's development shows in the stars, and next season's ratings come from them
	var moved: Array = []
	for id in c.teams:
		for p: PoloPlayer in (c.teams[id] as PoloTeam).roster:
			var d := PlayerForm.develop(p)
			if id == c.school and absf(d) >= 0.01:
				moved.append("%s %s*" % [p.short_name(), PlayerForm.star_text(p.stars)])
	if not moved.is_empty():
		lines.append("Stars moved: " + ", ".join(moved))
	# next season's ratings are simply the new roster's (PoloTeam.ratings): nothing to set. The
	# report compares them with the snapshot this season started with.
	var before: Array = c.season.get("ratings", {}).get(me.id, me.ratings())
	var after := me.ratings()
	var shown := func(i: int, r: Array) -> int: return PoloTeam.display_ovr(float(r[i]))
	# OFF, DEF and GK as every screen shows them (PoloTeam.offense_display...); a season saved
	# before they were snapshotted has no "before" for them, so no change is claimed
	var now := [me.offense_display(), me.defense_display(), me.goalkeeping_display()]
	var was: Array = c.season.get("shown", {}).get(me.id, now)
	# (OFF and DEF in stars, as every screen shows them: PoloTeam.rating_stars)
	lines.append("%s ratings: OVR %d (%+d), OFF %s, DEF %s, GK %d (%+d)" % [c.next_season_label(), shown.call(0, after), shown.call(0, after) - shown.call(0, before),
		CreditCoin.STARS % PoloTeam.rating_stars(now[0]), CreditCoin.STARS % PoloTeam.rating_stars(now[1]), now[2], now[2] - int(was[2])])
	c.queue.append({"type": "recap", "title": "%s ROSTER SET" % c.season_label(), "lines": lines, "next": c.next_season_label()})
	if c.needs_realign():
		c.realign()
	c.activate_pending()   # (a division added for next season: only ever here, between seasons)
	c.phase = "season"
	c.year += 1
	c.start_season()

# ------------------------------------------------------------------ the AI programs, and the cut players
## The AI programs' rosters for next season, once your cuts are made: their own shape first (what
## goes from it joins the pool), then the cut players they want (_pickups), then freshmen for the
## places still empty (Recruiting.ai_class), a full shape, seven at least. Lines for your report.
static func _ai_rosters(c: Career) -> Array:
	for id in c.teams:
		if id == c.school:
			continue
		var t: PoloTeam = c.teams[id]
		for p in _fix_shape(c, t) + _trim(c, t):
			c.cut_pool.append({"p": p, "from": id})
	var lines := _pickups(c)
	for id in c.teams:
		if id == c.school:
			continue
		var t: PoloTeam = c.teams[id]
		var returning: Array = t.roster.duplicate()
		for p in Recruiting.ai_class(c, t, maxi(0, c.roster_cap(id) - t.roster.size())):
			p.schol = t.roster.filter(func(q: PoloPlayer): return q.schol).size() < Career.SCHOL_MAX
			join(c, t, p)
		_fix_shape(c, t)
		_trim(c, t)
		_fill(c, t, Career.ROSTER_MAX)
		# a freshman or walk-on who lands on the bench is never rated above a starter (never a
		# transfer: he arrives as he is)
		CollegeGen.hold_bench(t, t.roster.filter(func(q: PoloPlayer): return not q in returning))
		t.sync_lineup()
	c.cut_pool = []
	return lines

## CUT PLAYERS FIND NEW PROGRAMS (the Accolades & Transfer update). Every player cut this
## off-season (yours: cut; an AI program's own trims) is in Career.cut_pool, already a year older,
## his career not over (graduating seniors left before any cut). The best prospects are looked at
## first; each AI program with a legal place for him (its roster cap, its keeper cap) weighs him
## (pickup_value: what it needs at his position, how he compares with what it has, the years he
## has left and the room he has to grow), and wants him with a chance that grows with that value
## (PICKUP_BASE + PICKUP_PER x value, at most PICKUP_MAX; nothing at 0 or below). Of the programs
## that want him, the one he's worth most to signs him: the same player (id, attributes, ceilings,
## XP, class year, career totals, awards), on exactly one roster. Nobody is guaranteed a place.
## The dice are his own (the year and his id), so nothing else in the career's draws moves.
const PICKUP_BASE := 0.1
const PICKUP_PER := 0.3
const PICKUP_MAX := 0.85

static func _pickups(c: Career) -> Array:
	var lines: Array = []
	var pool: Array = c.cut_pool.filter(func(e): return e.p != null and int((e.p as PoloPlayer).year) <= 4 and _team_of(c, e.p) == "")
	pool.sort_custom(func(a, b): return prospect(a.p) > prospect(b.p))
	var ids: Array = c.teams.keys()
	ids.sort()
	for e in pool:
		var p: PoloPlayer = e.p
		var rng := RandomNumberGenerator.new()
		rng.seed = hash([c.year, p.id, "pickup"])
		var best: PoloTeam = null
		var best_v := -INF
		for id in ids:
			if id == c.school or id == String(e.from):
				continue
			var t: PoloTeam = c.teams[id]
			if not has_place(c, t, p):
				continue
			var v := pickup_value(c, t, p)
			var roll := rng.randf()
			if v > 0.0 and roll < clampf(PICKUP_BASE + PICKUP_PER * v, 0.0, PICKUP_MAX) and v > best_v:
				best = t
				best_v = v
		if best == null:
			continue
		p.schol = best.roster.filter(func(q: PoloPlayer): return q.schol).size() < Career.SCHOL_MAX
		var keep_stats := p.totals.duplicate(true)
		join(c, best, p)
		p.totals = keep_stats   # (join starts his season's stats: his career's are his)
		e["to"] = best.id
		var from_name := Colleges.team_name(String(e.from)) if not c.teams.has(String(e.from)) else String(c.teams[String(e.from)].name)
		if String(e.from) == c.school:
			lines.append("Signed elsewhere: %s (%s, %s*) joins %s" % [p.short_name(), p.pos_text(), PlayerForm.star_text(p.stars), best.name])
			c.add_news("%s, cut by %s, signs with %s" % [p.short_name(), from_name, best.name])
	return lines

## Who has him now ("" nobody: he's only in the pool).
static func _team_of(c: Career, p: PoloPlayer) -> String:
	for id in c.teams:
		if (c.teams[id] as PoloTeam).roster.has(p) or (c.teams[id] as PoloTeam).find_id(p.id) != null:
			return String(id)
	return ""

## How good a prospect he is, for the order they're looked at in: his stars, his room, his years left.
static func prospect(p: PoloPlayer) -> float:
	return p.stars + 0.5 * maxf(0.0, p.pot_stars - p.stars) + 0.2 * (4 - p.year)

## Room for him at `t`: under its roster cap, and a keeper only under its keeper cap.
static func has_place(c: Career, t: PoloTeam, p: PoloPlayer) -> bool:
	if t.roster.size() >= c.roster_cap(t.id):
		return false
	return not p.is_keeper() or _keepers(t) < c.keeper_cap(t.id)

## What `p` is worth to `t` (0 or less: not interested): the need at his position (nobody there:
## a lot; one: some), how he compares with the weakest he'd play with there (or the team's
## average without anyone), the years he has left and his room to grow, less for a player far
## below the program's level.
static func pickup_value(c: Career, t: PoloTeam, p: PoloPlayer) -> float:
	var same: Array = t.roster.filter(func(q: PoloPlayer): return q.is_keeper() == p.is_keeper() and (p.is_keeper() or q.pos == p.pos))
	var need := 1.0 if same.is_empty() else (0.4 if same.size() == 1 else 0.0)
	var level := 0.0
	var seven := t.starters()
	for q in seven:
		level += (q as PoloPlayer).stars / maxf(1.0, seven.size())
	var bar: float = level if same.is_empty() else same.map(func(q): return (q as PoloPlayer).stars).min()
	var better := p.stars - bar
	var years := 0.2 * (4 - p.year)
	var room := 0.25 * maxf(0.0, p.pot_stars - p.stars)
	var below := 0.3 * maxf(0.0, level - p.stars - 1.0)
	return better + need + years + room - below

static func _keepers(t: PoloTeam) -> int:
	return t.roster.filter(func(p: PoloPlayer): return p.is_keeper()).size()

## A year older: a trait maybe, the next class year, healthy again. (No growth here: his
## attributes only ever move with the upgrade tokens his XP earns.)
static func _age(c: Career, p: PoloPlayer, mine: bool) -> void:
	if p.trait_id == "":
		p.trait_id = Traits.best_for(p)
		if p.trait_id != "" and mine:
			c.add_news("%s grows into a %s" % [p.tag(), Traits.title(p.trait_id)])
	p.year += 1
	p.age += 1
	Development.heal(p)

static func join(c: Career, t: PoloTeam, p: PoloPlayer) -> void:
	Development.ensure(p)   # a newcomer's hidden level, from the attributes he arrives with
	p.number = t.free_number(p.is_keeper())
	p.stats = {}
	t.roster.append(p)

## No more keepers than Career.keeper_cap and no more field players than the rest of the places
## (never expected: places are held by position): the extra goes, the weakest non-scholarship
## player first. Returns them.
static func _fix_shape(c: Career, t: PoloTeam) -> Array:
	var cut: Array = []
	var by := func(a: PoloPlayer, b: PoloPlayer):
		if a.schol != b.schol:
			return not a.schol
		return a.overall() < b.overall()
	var gks := t.roster.filter(func(p: PoloPlayer): return p.is_keeper())
	gks.sort_custom(func(a: PoloPlayer, b: PoloPlayer): return a.keeping > b.keeping)
	for p in gks.slice(c.keeper_cap(t.id)):
		t.roster.erase(p)
		cut.append(p)
	var field := t.roster.filter(func(p: PoloPlayer): return not p.is_keeper())
	field.sort_custom(by)
	while field.size() > c.roster_cap(t.id) - maxi(1, gks.size() - cut.size()):
		var p: PoloPlayer = field.pop_front()
		t.roster.erase(p)
		cut.append(p)
	return cut

## A roster over its places (Career.roster_cap; never expected: commitments are held to the
## places) lets its weakest non-scholarship players go. Returns them.
static func _trim(c: Career, t: PoloTeam) -> Array:
	var cut: Array = []
	while t.roster.size() > c.roster_cap(t.id):
		var by: Array = t.roster.duplicate()
		by.sort_custom(func(a: PoloPlayer, b: PoloPlayer):
			if a.schol != b.schol:
				return not a.schol
			return a.overall() < b.overall())
		var p: PoloPlayer = by[0]
		t.roster.erase(p)
		cut.append(p)
	return cut

static func _final_result(c: Career) -> void:
	var last: Dictionary = c.schedule[c.schedule.size() - 1]
	if last.games.is_empty():
		return
	var g: Dictionary = last.games[0]
	c.season.champion = Schedule.winner(g)
	if c.season.champion == c.school:
		c.season.finish = "NCSA champions"
	elif Schedule.loser(g) == c.school:
		c.season.finish = "NCSA runners-up"
	elif c.season.finish == "":
		c.season.finish = "Season over"

## Results move prestige; a conference only takes you so far.
static func _prestige(c: Career) -> void:
	var d3_champ := Schedule.winner(Schedule.d3_game(c.schedule, "d3_final")) if not Schedule.d3_game(c.schedule, "d3_final").is_empty() else ""
	for id in c.teams:
		var t: PoloTeam = c.teams[id]
		var r: Dictionary = c.table[id]
		var pct := float(r.w) / maxf(1.0, float(r.w + r.l))
		var delta := (pct - 0.5) * 10.0
		if id in c.season.conf_champs:
			delta += 5.0
		if id in c.season.nat_seeds:
			delta += 3.0
		if id == c.season.champion:
			delta += 6.0
		if id in c.season.get("d3_seeds", []):
			delta += 3.0
		if id == d3_champ:
			delta += 6.0
		var ceiling := 56.0 + 48.0 * Colleges.tier_frac(t.conf)
		if t.prestige > ceiling and delta > 0.0:
			delta *= 0.3
		if not t.is_player:
			var base := float(Colleges.school(id).get("prestige", t.prestige))
			delta += (base - t.prestige) * 0.25 + c.rng.randf_range(-2.0, 2.0)
		t.prestige = clampf(t.prestige + clampf(delta, -PRESTIGE_STEP, PRESTIGE_STEP), 15.0, 99.0)

static func _top_scorer(t: PoloTeam) -> PoloPlayer:
	var best: PoloPlayer = null
	for p in t.roster:
		if p.stat("g") > 0 and (best == null or p.stat("g") > best.stat("g")):
			best = p
	return best

## Tops a roster up to `size` with walk-on freshmen, at the positions the roster is short of.
## The same for every school. Never removes anyone. Returns how many joined.
static func _fill(c: Career, t: PoloTeam, size: int) -> int:
	var added := 0
	var used := {}
	for p in t.roster:
		used[p.last] = true
	# up to `size`, and always a keeper and six field players (a bench's backup keeper doesn't
	# play in the field)
	var short := func() -> bool:
		var gk := t.roster.filter(func(q: PoloPlayer): return q.is_keeper()).size()
		return gk == 0 or t.roster.size() - gk < Career.FIELD_MAX
	while t.roster.size() < size or short.call():
		var pos := CollegeGen.needed_pos(t, c.rng)
		var p := CollegeGen.make_walkon(c.rng, pos, used)
		p.id = c.new_id()
		p.number = t.free_number(p.is_keeper())
		Development.ensure(p)
		t.roster.append(p)
		added += 1
	return added

## Schools that want you: a good season brings bigger schools.
static func _offers(c: Career, _unused := false) -> Array:
	var fired := false
	var me := c.team()
	var good: bool = c.school in c.season.conf_champs or c.school in c.season.nat_seeds or c.school in c.season.get("d3_seeds", [])
	var pct := float(c.table[c.school].w) / maxf(1.0, float(c.table[c.school].w + c.table[c.school].l))
	var ids: Array = c.teams.keys().filter(func(id):
		var t: PoloTeam = c.teams[id]
		if id == c.school:
			return false
		if fired:
			return t.prestige < me.prestige - 2.0
		return t.prestige > me.prestige + 5.0 and t.prestige < me.prestige + 32.0)
	ids.shuffle()
	var n := 0
	if fired:
		n = 2 if int(c.coach.rep) >= 15 else 1
	elif good:
		n = 2
	elif pct >= 0.65:
		n = 1
	return ids.slice(0, mini(n, ids.size()))

## Take a job: a new school, its roster, its facilities and its pool. Your staff, your credits,
## your recruiting market and the recruits you've signed come along (they signed with you, and
## join your new program). Taken while your old roster waited for its cuts: it's an AI program's
## now and sets itself, and your new one is already legal, so the next season starts.
static func take_job(c: Career, id: String) -> void:
	var old := c.school
	c.teams[old].is_player = false
	c.teams[id].is_player = true
	c.school = id
	c.add_news("Coach %s takes over at %s" % [c.coach.last, c.teams[id].name])
	c.add_news("%s hire a new coach after %s leaves" % [c.teams[old].name, c.coach.last])
	if c.phase == "cuts":
		var t: PoloTeam = c.teams[old]
		_fix_shape(c, t)
		_trim(c, t)
		t.sync_lineup()
		if roster_legal(c):
			finish(c)

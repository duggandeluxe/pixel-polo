extends RefCounted
## The Credit Economy & Recruiting Overhaul: CreditRewards (the only credits a career earns), the
## eight-man RECRUITING MARKET (Recruiting), signing, refreshing, incoming recruits, the projected
## roster and the roster cuts after a season (Offseason), saves and older saves, and the screens.
##   godot --headless --path game -- --test credit_economy
##   godot --path game -- --test credit_economy_png <dir>      (screenshots: needs a window)

var r   # the test runner
const RecruitingScreen := preload("res://src/ui/screens/recruiting.gd")

func run(runner) -> void:
	r = runner
	print("credit economy & recruiting market")
	Store.reset_for_tests()
	_old_sources_gone()
	_game_rewards()
	_achievements()
	_season_start()
	_real_season()
	_market()
	_prices()
	_signing()
	_refresh()
	_transition_and_cuts()
	_saves()
	_old_save()
	await _screens()
	Game.career = null

func _career(seed_value: int = 81, school: String = "CULA") -> Career:
	var c := Career.new_game(school, "A", "B", seed_value)
	c.queue.clear()
	return c

## Every label CreditRewards pays under: nothing else may show up in a season's credit log.
func _allowed() -> Array:
	var out := ["WIN", "UPSET VICTORY", "BEAT A TOP 5 TEAM", "BEAT THE NO. 1 TEAM", "WIN BY %d+" % CreditRewards.MARGIN_BY, "SHUTOUT", "NEW SEASON"]
	for a in CreditRewards.ACHIEVEMENTS:
		out.append(String(a[2]))
	return out

# ------------------------------------------------------------------ 1: no other source
func _old_sources_gone() -> void:
	var callers: Array = []
	_scan("res://src", callers)
	# (and, since the Coaching Events: Decisions & Consequences update, the events' own credit rewards)
	r.check(callers == ["res://src/core/coach_events.gd", "res://src/core/credit_rewards.gd"], "1: only CreditRewards (and coaching events' rewards) pay credits (add_credits callers: %s)" % [callers])
	var c := _career()
	for k in ["recruits", "portal", "rp", "visits_left", "pipelines", "ai_rec", "class_history", "rp_paid", "visit_plans"]:
		r.check(not k in c, "14-15: the old recruiting's %s is gone" % k)
	r.check(not "PRO_CREDIT_BONUS" in Store and not Store.PRO_PERKS.any(func(x): return String(x).contains("credits")), "1: PRO no longer multiplies earned credits")
	for cd in CardsData.CARDS:
		for ch in cd.choices:
			r.check(not _pays(ch.effects), "1: event card %s never pays credits" % cd.id)
	# an effect asking to pay credits pays nothing now; one asking for recruiting points neither
	var before := c.credits
	c.apply_effects([{"t": "credits", "v": 50}, {"t": "rp", "v": 10}])
	r.check(c.credits == before, "1: a credits effect can only cost")

func _pays(effects: Array) -> bool:
	for e in effects:
		if String(e.t) == "credits" and float(e.v) > 0.0:
			return true
		if String(e.t) == "chance" and (_pays(e.win) or _pays(e.lose)):
			return true
	return false

func _scan(dir: String, out: Array) -> void:
	for f in DirAccess.get_files_at(dir):
		if not f.ends_with(".gd"):
			continue
		var path := dir.path_join(f)
		var text := FileAccess.get_file_as_string(path)
		for line in text.split("\n"):
			if line.contains("add_credits(") and not line.strip_edges().begins_with("func ") and not line.strip_edges().begins_with("#"):
				if not path in out:
					out.append(path)
	for d in DirAccess.get_directories_at(dir):
		_scan(dir.path_join(d), out)

# ------------------------------------------------------------------ 2-8: a game's credits
## Your next regular-season game with a result: you `mine` - `theirs` (a shootout when level).
func _result(c: Career, mine: int, theirs: int, so: Array = []) -> Dictionary:
	var g := c.my_game()
	var home: bool = g.h == c.school
	var won := mine > theirs or (mine == theirs and int(so[0]) > int(so[1]))
	g.r = {"s": [mine, theirs] if home else [theirs, mine], "so": ([so[0], so[1]] if home else [so[1], so[0]]) if not so.is_empty() else [],
		"w": (0 if home else 1) if won else (1 if home else 0)}
	return g

func _ranks(c: Career, me: int, opp: int) -> Dictionary:
	var g := c.my_game()
	return {c.school: me, (g.a if g.h == c.school else g.h): opp}

func _sum(lines: Array) -> int:
	return CreditRewards.total(lines)

func _game_rewards() -> void:
	var c := _career(82)
	var rd := c.cur()
	var g := _result(c, 8, 6)
	r.check(_sum(CreditRewards.game_lines(c, g, rd, _ranks(c, 5, 12))) == 3, "3: a regular-season win: exactly 3")
	g = _result(c, 6, 8)
	r.check(CreditRewards.game_lines(c, g, rd, _ranks(c, 12, 5)).is_empty(), "4: a loss: nothing")
	g = _result(c, 8, 6)
	r.check(_sum(CreditRewards.game_lines(c, g, rd, _ranks(c, 12, 9))) == 6, "5: a higher-ranked opponent: +3 more")
	r.check(_sum(CreditRewards.game_lines(c, g, rd, _ranks(c, 12, 4))) == 8, "8: a Top 5 team: +5, not +3 as well")
	r.check(_sum(CreditRewards.game_lines(c, g, rd, _ranks(c, 12, 1))) == 11, "8: the No. 1 team: +8 alone")
	r.check(_sum(CreditRewards.game_lines(c, g, rd, _ranks(c, 3, 4))) == 8, "8: a Top 5 team ranked below you: still the Top 5 bonus")
	g = _result(c, 11, 6)
	r.check(_sum(CreditRewards.game_lines(c, g, rd, _ranks(c, 5, 12))) == 5, "6: won by 5: +2")
	g = _result(c, 10, 6)
	r.check(_sum(CreditRewards.game_lines(c, g, rd, _ranks(c, 5, 12))) == 3, "6: won by 4: no margin bonus")
	g = _result(c, 4, 0)
	r.check(_sum(CreditRewards.game_lines(c, g, rd, _ranks(c, 5, 12))) == 6, "7: a shutout: +3")
	g = _result(c, 12, 6)
	var ex := CreditRewards.game_lines(c, g, rd, _ranks(c, 9, 7))
	r.check(_sum(ex) == 8 and ex.map(func(x): return x[0]) == ["WIN", "UPSET VICTORY", "WIN BY 5+"], "the spec's example: 12-6 over a higher-ranked team, +8 (%s)" % [ex])
	g = _result(c, 0, 0, [3, 0])
	r.check(_sum(CreditRewards.game_lines(c, g, rd, _ranks(c, 5, 12))) == 6, "7: 0-0, won the shootout without conceding one: a shutout")
	# paid once
	var before := c.credits
	var lines := CreditRewards.pay_game(c, g, rd, _ranks(c, 5, 12))
	var again := CreditRewards.pay_game(c, g, rd, _ranks(c, 5, 12))
	r.check(c.credits == before + _sum(lines) and again.is_empty(), "12: a game pays once")
	# a playoff game pays per-game nothing (the achievements pay the playoffs)
	var po := {"kind": "nat_sf", "games": []}
	r.check(CreditRewards.game_lines(c, g, po, _ranks(c, 5, 1)).is_empty(), "the per-game rewards are the regular season's")

# ------------------------------------------------------------------ 9-10: achievements
func _achievements() -> void:
	var c := _career(83)
	var before := c.credits
	# ten wins in a row
	var n := 0
	for rd in c.schedule:
		for g in c.my_games(rd):
			if n < 10 and not Schedule.is_playoff(rd):
				var home: bool = g.h == c.school
				g.r = {"s": [7, 5] if home else [5, 7], "so": [], "w": 0 if home else 1}
				n += 1
	r.check(CreditRewards.best_streak(c) == 10, "a ten-game run (%d)" % CreditRewards.best_streak(c))
	var paid := CreditRewards.season_lines(c)
	r.check(_sum(paid) == 13 and c.credits == before + 13, "10: 5 and 10 straight: +5 and +8 (%s)" % [paid])
	r.check(CreditRewards.season_lines(c).is_empty(), "10: streaks pay once a season")
	# the titles
	c.season.conf_champs = [c.school]
	c.season.nat_seeds = [c.school]
	for rd in c.schedule:
		if String(rd.kind) in ["conf_final", "nat_sf", "nat_final"]:
			var g := {"h": c.school, "a": "USC" if c.school != "USC" else "CAL", "r": null, "d": 1}
			if String(rd.kind) in ["conf_final", "nat_final"]:
				g.r = {"s": [9, 8], "so": [], "w": 0}
			rd.games = [g]
	before = c.credits
	paid = CreditRewards.season_lines(c)
	var labels := paid.map(func(x): return x[0])
	r.check(_sum(paid) == 8 + 15 + 8 + 8 + 8 + 23 and c.credits == before + 70, "9: conference final 8, title 15, NCSA bid 8, semis 8, final 8, champions 23 (%s)" % [paid])
	r.check(labels.has("NATIONAL CHAMPIONS") and labels.has("CONFERENCE CHAMPIONS"), "9: each named")
	r.check(CreditRewards.season_lines(c).is_empty(), "12: achievements pay once a season")
	var back := Career.from_dict(JSON.parse_string(JSON.stringify(c.to_dict())))
	r.check(CreditRewards.season_lines(back).is_empty() and back.credits == c.credits, "29: a reload pays nothing again")
	# unbeaten: only once the regular season's played, without a loss
	var u := _career(84)
	u.table[u.school].w = 16
	u.table[u.school].l = 0
	r.check(CreditRewards.season_lines(u).filter(func(x): return x[0] == "UNDEFEATED REGULAR SEASON").is_empty(), "10: not unbeaten until the regular season's done")
	u.week = Schedule.REGULAR_WEEKS
	r.check(CreditRewards.season_lines(u).any(func(x): return x[0] == "UNDEFEATED REGULAR SEASON" and int(x[1]) == 15), "10: an unbeaten regular season: +15")
	var l := _career(85)
	l.table[l.school].w = 15
	l.table[l.school].l = 1
	l.week = Schedule.REGULAR_WEEKS
	r.check(not CreditRewards.season_lines(l).any(func(x): return x[0] == "UNDEFEATED REGULAR SEASON"), "10: one loss: no bonus")

# ------------------------------------------------------------------ 11: the new season
func _season_start() -> void:
	var c := _career(86)
	r.check(c.credits == CreditRewards.SEASON_START and c.season.credit_log == [["NEW SEASON", 15]], "11: a new career starts with the season's 15 and nothing else (%d)" % c.credits)
	var back := Career.from_dict(JSON.parse_string(JSON.stringify(c.to_dict())))
	r.check(back.credits == 15, "11: reopening pays nothing more")
	r.check(CreditRewards.season_start(c) == 0 and c.credits == 15, "11: never twice in a season")
	c.credits = 5000
	c.year += 1
	c.start_season()
	r.check(c.credits == 5015, "11, 13: the next season +15, on top of what you had (no cap)")

# ------------------------------------------------------------------ 2, 12, 30: a real season
func _real_season() -> void:
	var c := _career(87)
	Game.career = c
	var labels := {}
	var paid_game := 0
	var guard := 0
	while c.phase == "season" and guard < 40:
		guard += 1
		c.queue.clear()
		while c.has_game():
			var ranks := CreditRewards.ranks_now(c)
			var g := c.my_game()
			var rd := c.cur()
			var out := c.sim_my_game()
			var want := CreditRewards.game_lines(c, g, rd, ranks)
			r.check(_sum(out.credits.filter(func(x): return x in want)) == _sum(want), "2: game credits are exactly the table's (%s)" % [out.credits])
			paid_game += _sum(want)
			# the summary reopened, the save reloaded: nothing more
			var gi: int = (rd.games as Array).find(g)
			var again := Career.from_dict(JSON.parse_string(JSON.stringify(c.to_dict())))
			var g2: Dictionary = again.schedule[c.week].games[gi]
			r.check(CreditRewards.season_lines(again).is_empty() and CreditRewards.pay_game(again, g2, again.schedule[c.week], ranks).is_empty() and again.credits == c.credits,
				"29: nothing pays twice across a reload")
		for q in c.upgrades_due():
			Development.ai_spend(q)
		c.end_week()
	r.check(c.phase == "done", "the season ends: done, next season to come")
	var log: Array = c.season.get("credit_log", [])
	var bad := log.filter(func(e): return not String(e[0]) in _allowed())
	r.check(bad.is_empty(), "1-2: the season's credits came from the new rewards only (%s)" % [bad])
	var total := 0
	for e in log:
		total += int(e[1])
	r.check(c.credits == total, "13: the balance is exactly what was paid (%d)" % total)
	var ids := c.cr_claims.duplicate()
	var uniq := {}
	for id in ids:
		uniq[id] = true
	r.check(uniq.size() == ids.size(), "12: every claim is unique")
	Game.career = null

# ------------------------------------------------------------------ 16, 20: the market
func _market() -> void:
	var c := _career(88)
	r.check(c.market.size() == 8 and c.market.all(func(x): return not bool(x.legacy) and not x.has("sc")), "16: eight prospects, no scouting")
	var ids: Array = c.market.map(func(x): return (x.p as PoloPlayer).id)
	r.check(not c.market.any(func(x): return (x.p as PoloPlayer).stars >= 5.0), "9: nobody starts at five stars")
	# the stars and potential over many markets
	var by := {}
	var pot5 := 0
	var low_high := 0
	var high_low := 0
	var total := 0
	for i in 150:
		Recruiting.new_market(c)
		for x in c.market:
			var p: PoloPlayer = x.p
			by[p.stars] = int(by.get(p.stars, 0)) + 1
			total += 1
			if p.pot_stars >= 5.0:
				pot5 += 1
			if p.stars <= 2.5 and p.pot_stars >= 4.0:
				low_high += 1
			if p.stars >= 3.5 and p.pot_stars <= p.stars + 0.5:
				high_low += 1
	var mid := 0
	for k in by:
		if float(k) >= 2.0 and float(k) <= 3.5:
			mid += int(by[k])
	print("  market stars over %d: %s  pot 5*: %d" % [total, by, pot5])
	r.check(mid > total * 0.7, "9: most are 2-3.5 stars (%d of %d)" % [mid, total])
	r.check(int(by.get(4.0, 0)) < total * 0.15 and int(by.get(4.5, 0)) < total * 0.05 and int(by.get(4.5, 0)) > 0, "9: fours uncommon, 4.5 rare")
	r.check(not by.has(5.0) and pot5 > 0 and pot5 < total * 0.1, "9: five-star potential possible but rare (%d)" % pot5)
	r.check(low_high > 0 and high_low > 0, "9: low-rated sleepers and finished high-rated prospects both exist (%d, %d)" % [low_high, high_low])
	# opening the screen makes nobody new
	var c2 := _career(89)
	var keep: Array = c2.market.map(func(x): return (x.p as PoloPlayer).id)
	Game.career = c2
	Game.goto("recruiting")
	r.check(c2.market.map(func(x): return (x.p as PoloPlayer).id) == keep, "9: opening Recruiting doesn't regenerate the market")
	Game.career = null

# ------------------------------------------------------------------ 17-19: prices
func _prices() -> void:
	var c := _career(90)
	var by := {}
	var lo := 999
	var hi := 0
	var formula := true
	for i in 300:
		var x := Recruiting.new_recruit(c)
		var p: PoloPlayer = x.p
		lo = mini(lo, int(x.price))
		hi = maxi(hi, int(x.price))
		formula = formula and int(x.price) == Recruiting.price_of(p)
		if not by.has(p.stars):
			by[p.stars] = []
		by[p.stars].append(int(x.price))
	r.check(lo >= 8 and hi <= 99, "17: every price 8-99 (%d-%d)" % [lo, hi])
	r.check(formula, "18: the saved price is the formula's")
	var keys := by.keys()
	keys.sort()
	for k in keys:
		var a: Array = by[k]
		a.sort()
		print("  %.1f*: %d-%d (median %d, n %d)" % [k, a[0], a[a.size() - 1], a[a.size() / 2], a.size()])
	# what moves it: attributes, room to grow, position (stars too, through the base)
	var p := Recruiting.make(c.rng, 3.0, 3.5, "normal", {}, PoloPlayer.Pos.DRIVER)
	var base := Recruiting.price_of(p)
	var k0: String = p.key_ratings()[0]
	var more_room := Recruiting.make(c.rng, 3.0, 3.5, "normal", {}, PoloPlayer.Pos.DRIVER)
	more_room.attrs = p.attrs.duplicate()
	more_room.attr_pot = p.attr_pot.duplicate()
	more_room.attr_pot[k0] = minf(10.0, float(p.attr_pot[k0]) + 3.0)
	Attributes.sync(more_room)
	r.check(Recruiting.price_of(more_room) > base, "18: more room to grow costs more (%d > %d)" % [Recruiting.price_of(more_room), base])
	r.check(Recruiting.POS_PRICE[PoloPlayer.Pos.GK] == 3 and Recruiting.POS_PRICE[PoloPlayer.Pos.CENTER] == 2 and Recruiting.POS_PRICE[PoloPlayer.Pos.DEFENDER] == 2 and Recruiting.POS_PRICE[PoloPlayer.Pos.UTILITY] == 1 and Recruiting.POS_PRICE[PoloPlayer.Pos.WING] == 0, "18: position adds GK 3, C 2, DEF 2, UT 1, wings and drivers 0")
	var u := Recruiting.make(c.rng, 3.0, 3.5, "normal", {}, PoloPlayer.Pos.UTILITY)
	var w := PoloPlayer.from_dict(u.to_dict())
	w.pos = PoloPlayer.Pos.WING
	r.check(Recruiting.price_of(u) == Recruiting.price_of(w) + 1, "18: a utility man costs 1 more than the same wing")
	# attributes: two more points now (the ceiling with them, so the room is the same) cost more
	var up := PoloPlayer.from_dict(p.to_dict())
	for kk in up.key_ratings().slice(0, 2):
		up.attrs[kk] = minf(9.0, float(up.attrs[kk]) + 1.0)
		up.attr_pot[kk] = maxf(float(up.attr_pot[kk]), float(up.attrs[kk]) + float(p.attr_pot[kk]) - float(p.attrs[kk]))
	Attributes.sync(up)
	r.check(up.stars != p.stars or Recruiting.price_of(up) > base, "18: better attributes cost more (%d > %d)" % [Recruiting.price_of(up), base])
	# no 25% cut anywhere
	r.check(Recruiting.REFRESH_COSTS == [0, 3, 5, 8, 10] and Recruiting.PRICE_MIN == 8 and Recruiting.PRICE_MAX == 99, "19: refresh costs and the price range as specified")

# ------------------------------------------------------------------ 21-22: signing
func _signing() -> void:
	var c := _career(92)
	c.credits = 1000
	var proj := Recruiting.projected(c)
	var x: Dictionary = c.market[0]
	var cost := int(x.price)
	r.check(Recruiting.sign(c, x) == "" and c.credits == 1000 - cost, "21: signing takes exactly his price (%d)" % cost)
	r.check(not x in c.market and x in c.incoming and c.market.size() == 7, "12: off the market, into Incoming Recruits")
	r.check(Recruiting.projected(c) == proj + 1 and c.team().find_id((x.p as PoloPlayer).id) == null, "12, 24: the projection moves; he's not on the roster yet")
	r.check(Recruiting.sign(c, x) != "", "12: he can't be signed twice")
	for i in 3:
		Recruiting.sign(c, c.market[0])
	r.check(Recruiting.signed_count(c) == 4 and Recruiting.sign(c, c.market[0]) != "" and c.incoming.size() == 4, "22: four a season, no more")
	var poor := _career(93)
	poor.credits = 0
	var y: Dictionary = poor.market[0]
	r.check(Recruiting.sign(poor, y) != "" and poor.credits == 0 and y in poor.market, "12: short of credits: nothing happens")
	r.check(Recruiting.sign_block(poor, y, false) == "", "...and it's only the credits")

# ------------------------------------------------------------------ 23: refreshing
func _refresh() -> void:
	var c := _career(94)
	c.credits = 100
	Recruiting.sign(c, c.market[0])
	var signed: Array = c.incoming.duplicate()
	var paid: Array = []
	for i in 6:
		var before := c.wallet()
		var old_ids: Array = c.market.map(func(x): return (x.p as PoloPlayer).id)
		r.check(Recruiting.refresh(c) == "", "(refresh %d)" % (i + 1))
		paid.append(before - c.wallet())
		r.check(c.market.size() == 8 and not c.market.any(func(x): return (x.p as PoloPlayer).id in old_ids), "23: eight new prospects")
	r.check(paid == [0, 3, 5, 8, 10, 10], "13: free, 3, 5, 8, then 10 each (%s)" % [paid])
	r.check(c.incoming == signed and Recruiting.signed_count(c) == 1, "23: signed recruits and the count stay")
	c.credits = 2
	r.check(Recruiting.refresh_block(c) != "" and Recruiting.refresh(c) != "" and c.credits == 2, "13: a refresh you can't pay for is off")
	var back := Career.from_dict(JSON.parse_string(JSON.stringify(c.to_dict())))
	r.check(back.refreshes == c.refreshes and back.market.map(func(x): return x.price) == c.market.map(func(x): return x.price), "19: the refresh count and market save")
	c.year += 1
	c.start_season()
	r.check(c.refreshes == 0 and Recruiting.refresh_cost(c) == 0, "13: the free refresh is back each season")

# ------------------------------------------------------------------ 24-28: the transition and cuts
func _to_done(c: Career) -> void:
	var guard := 0
	while c.phase == "season" and guard < 40:
		guard += 1
		c.queue.clear()
		while c.has_game():
			c.sim_my_game()
		for q in c.upgrades_due():
			Development.ai_spend(q)
		c.end_week()

func _transition_and_cuts() -> void:
	# within the cap: straight on
	var a := _career(95)
	_to_done(a)
	a.queue.clear()
	var grads := Recruiting.graduating(a).size()
	var size := a.team().roster.size()
	r.check(a.phase == "done" and grads > 0, "the season's done; seniors to graduate (%d)" % grads)
	a.end_week()
	r.check(a.phase == "season" and a.week == 0 and a.team().roster.size() >= size - grads, "no cuts needed: on to the next season")
	# over the cap
	var c := _career(96)
	c.credits = 2000
	for i in 4:
		Recruiting.sign(c, c.market[0])
	var signed_ids: Array = c.incoming.map(func(x): return (x.p as PoloPlayer).id)
	_to_done(c)
	c.queue.clear()
	var expect := Recruiting.projected(c)
	var over := Recruiting.over_by(c)
	var pre := c.credits
	c.end_week()
	if over == 0:
		print("  (seed 96 had room: %d)" % expect)
		return
	r.check(c.phase == "cuts" and c.team().roster.size() == expect and Offseason.cuts_needed(c) == over, "25-26: over the cap: %d / %d, %d to cut" % [expect, c.roster_max(), over])
	r.check(signed_ids.all(func(id): return c.team().find_id(id) != null and c.team().find_id(id).year == 1) and c.incoming.is_empty(), "24: the signings join after the season, as freshmen")
	var week0 := c.week
	c.end_week()
	r.check(c.phase == "cuts" and c.week == week0 and c.year == Career.START_YEAR, "28: nothing moves on with an over-cap roster")
	r.check(Offseason.finish_cuts(c) != "" and c.phase == "cuts", "28: CONTINUE refused until it's legal")
	var gks: Array = c.team().roster.filter(func(p: PoloPlayer): return p.is_keeper())
	if gks.size() == 1:
		r.check(Offseason.cut_block(c, gks[0]) != "", "26: your only keeper can't be cut")
	var back := Career.from_dict(JSON.parse_string(JSON.stringify(c.to_dict())))
	r.check(back.phase == "cuts" and back.team().roster.size() == c.team().roster.size() and back.incoming.is_empty(), "29: the pending cuts save; nobody joins twice")
	while not Offseason.roster_legal(c):
		var can: Array = c.team().roster.filter(func(p: PoloPlayer): return Offseason.cut_block(c, p) == "")
		r.check(not can.is_empty(), "26: someone can be cut")
		if can.is_empty():
			break
		Offseason.cut(c, can[0])
	r.check(c.credits == pre and c.team().roster.size() == c.roster_max(), "27: cuts refund nothing (%d)" % c.credits)
	var any_left: Array = c.team().roster.filter(func(p: PoloPlayer): return Offseason.cut_block(c, p) == "")
	r.check(any_left.is_empty(), "26: no more cuts once it's legal")
	r.check(Offseason.finish_cuts(c) == "" and c.phase == "season" and c.year == Career.START_YEAR + 1, "26: CONTINUE TO NEXT SEASON")
	r.check(c.credits == pre + 15 and c.market.size() == 8, "the new season: +15 and a new market")

# ------------------------------------------------------------------ 29: saves
func _saves() -> void:
	var c := _career(97)
	c.credits = 300
	Recruiting.sign(c, c.market[0])
	Recruiting.refresh(c)
	var text := JSON.stringify(c.to_dict())
	var back := Career.from_dict(JSON.parse_string(text))
	r.check(JSON.stringify(back.to_dict()) == text, "29: everything saves and loads exactly (market, prices, scouting, incoming, refreshes, claims)")
	r.check(not back.converted, "29: a new save isn't converted again")

# ------------------------------------------------------------------ an older save
func _old_save() -> void:
	var c := _career(98)
	for _i in 3:
		c.sim_my_game()
		c.end_week()
	var d: Dictionary = JSON.parse_string(JSON.stringify(c.to_dict()))
	for k in ["market", "incoming", "refreshes", "cr_claims"]:
		d.erase(k)
	d.credits = 437
	d.rp = 220
	var x := Recruiting.new_recruit(c)
	var y := Recruiting.new_recruit(c)
	d.recruits = [{"p": (x.p as PoloPlayer).to_dict(), "kind": "HS", "committed": c.school, "sc": {c.school: 2}},   # (an old save's scouting: dropped)
		{"p": (y.p as PoloPlayer).to_dict(), "kind": "HS", "committed": "USC" if c.school != "USC" else "CAL"}]
	d.portal = []
	var old := Career.from_dict(JSON.parse_string(JSON.stringify(d)))
	r.check(old.converted and old.credits == 437, "an older dynasty keeps its credits exactly; no points become credits")
	r.check(old.incoming.size() == 1 and bool(old.incoming[0].legacy) and not old.incoming[0].has("sc") and Recruiting.signed_count(old) == 0, "your old commitment comes across as an incoming recruit (outside the four)")
	r.check(old.market.size() == 8 and old.refreshes == 0, "...and the market opens")
	r.check(CreditRewards.season_start(old) == 0, "...this season's +15 counted as paid")
	var again := Career.from_dict(JSON.parse_string(JSON.stringify(old.to_dict())))
	r.check(not again.converted and again.incoming.size() == 1, "converted once")
	# caught in the old off-season
	d.phase = "spring"
	d.week = (d.schedule as Array).size()
	var off := Career.from_dict(JSON.parse_string(JSON.stringify(d)))
	r.check(off.phase == "done" and off.incoming.size() == 1, "an old off-season save: the season's done, NEXT SEASON next")

# ------------------------------------------------------------------ the screens
func _frames(n: int) -> void:
	for _i in n:
		await r.get_tree().process_frame

func _texts(root: Node) -> String:
	var out := PackedStringArray()
	for n in root.find_children("*", "", true, false):
		if n is Label or n is Button:
			out.append(n.text)
	return "\n".join(out)

func _overlay_button(t: String) -> Button:
	for b in Game.overlay.find_children("*", "Button", true, false):
		if (b as Button).text == t:
			return b
	return null

func _clear_overlay() -> void:
	for ch in Game.overlay.get_children():
		if ch != Game._fade:   # (the dialogs; never the screen fade)
			ch.queue_free()

func _screens() -> void:
	var c := _career(99)
	c.credits = 500
	Game.career = c
	Game.goto("recruiting", {"tab": "MARKET"})
	await _frames(3)
	var scr: Node = Game.current_screen
	var cards: Array = scr.find_children("Card_*", "", true, false)
	var RosterScreen = load("res://src/ui/screens/roster.gd")
	r.check(Game.current_name == "recruiting" and cards.size() == 8, "cards 1: eight recruit player cards (%d)" % cards.size())
	r.check(cards.all(func(b: Control): return b.size.x >= RosterScreen.CARD.x and b.size.y >= RosterScreen.CARD.y and b is BaseButton and b.mouse_filter == Control.MOUSE_FILTER_STOP),
		"cards 2-4: each a whole roster-size card, the full surface one button")
	r.check(cards.map(func(b): return int(b.get_meta("pid"))) == c.market.map(func(x): return (x.p as PoloPlayer).id), "cards 1: the market's eight, in order")
	var shown := _texts(scr)
	r.check(shown.contains("RECRUITS SIGNED: 0 / 4") and shown.contains("PROJECTED ROSTER") and shown.contains("REFRESH RECRUITS"), "18: signings, projection, refresh")
	r.check(not shown.contains("RECRUITING POINTS") and not shown.contains("INTEREST") and not shown.contains(" RP") and not shown.contains(" CR"), "15: no points, no interest, no CR labels")
	# a card opens his profile, never signs him
	var x: Dictionary = c.market[2]
	var px: PoloPlayer = x.p
	var wallet := c.wallet()
	(cards[2] as BaseButton).pressed.emit()
	await _frames(3)
	var prof: Node = Game.current_screen
	r.check(Game.current_name == "player" and prof.recruit and prof.p == px, "cards 5-6: his card opens his profile, the player page")
	r.check(c.wallet() == wallet and x in c.market and c.incoming.is_empty(), "cards 11: opening him signs nobody")
	r.check(prof.find_child("Stars_Potential", true, false) != null and is_equal_approx(float(prof.find_child("Stars_Potential", true, false).get_meta("stars")), px.pot_stars)
		and prof.find_child("Boxes_" + px.key_ratings()[0], true, false) != null and prof.find_child("Scout", true, false) == null,
		"his potential, attributes and ceilings show at once: no scouting")
	r.check(prof.find_child("XpLine", true, false) == null and prof.find_child("Up_" + px.key_ratings()[0], true, false) == null and prof.find_child("FlipHint", true, false) == null,
		"cards 7: no XP, upgrades or flip on a recruit")
	var price: Node = prof.find_child("Price", true, false)
	r.check(price != null and price.find_child("Amount", true, false).text == str(int(x.price)) and price.find_child("Coin", true, false) != null
		and price.find_child("Amount", true, false).get_index() < price.find_child("Coin", true, false).get_index(), "coin 9: his price, number then the coin")
	# sign from the profile (its confirmation), back to the market
	(prof.find_child("Sign", true, false) as BaseButton).pressed.emit()
	await _frames(1)
	var yes := _overlay_button("SIGN RECRUIT")
	if yes == null:
		yes = _overlay_button("SIGN ANYWAY")
	r.check(yes != null and x in c.market, "cards 10: SIGN RECRUIT asks first")
	if yes != null:
		yes.pressed.emit()
	await _frames(2)
	_clear_overlay()
	r.check(x in c.incoming and c.wallet() == wallet - int(x.price), "cards 10, 21: signed from his profile, his exact price")
	r.check(Game.current_screen.find_child("SignedNote", true, false) != null, "cards 4: SIGNED - JOINS NEXT SEASON on his profile")
	Game.current_screen.on_back()
	await _frames(3)
	r.check(Game.current_name == "recruiting" and Game.current_screen.find_children("Card_*", "", true, false).size() == 7, "cards 13: back on the market, seven left")
	# signing over the cap: the warning (from the shared confirmation)
	while Recruiting.over_by(c, 1) == 0 and Recruiting.signed_count(c) < 3:
		Recruiting.sign(c, c.market[0])
	if Recruiting.over_by(c, 1) > 0:
		var y: Dictionary = c.market[0]
		var w0 := c.wallet()
		RecruitingScreen.ask_sign(c, y, func(_e): pass)
		await _frames(1)
		var dlg := _texts(Game.overlay)
		r.check(dlg.contains("ROSTER LIMIT WARNING") and dlg.contains("SIGN ANYWAY") and dlg.contains("CANCEL"), "15: the roster limit warning")
		_overlay_button("CANCEL").pressed.emit()
		await _frames(1)
		r.check(c.wallet() == w0 and y in c.market, "15: cancelled: nothing paid")
		_clear_overlay()
	Game.goto("recruiting", {"tab": "MARKET"})
	await _frames(3)
	var proj: Node = Game.current_screen.find_child("Projection", true, false)
	r.check(proj != null and int(proj.get_meta("over")) == Recruiting.over_by(c), "25: the projection's warning is live")
	# the Golden Credits coin
	r.check(ResourceLoader.exists(CreditCoin.SOURCE) and ResourceLoader.exists("%scredit_coin_16.png" % CreditCoin.DIR), "coin 1: the official coin art is in the project (tools/make_credit_coin.py)")
	r.check(CreditCoin.texture(16).get_height() >= 16, "coin 6: the coin at 16 px at least beside an amount (%d)" % CreditCoin.texture(16).get_height())
	var old_ids: Array = c.market.map(func(m): return (m.p as PoloPlayer).id)
	Recruiting.refresh(c)
	Game.goto("recruiting", {"tab": "MARKET"})
	await _frames(3)
	var after: Array = Game.current_screen.find_children("Card_*", "", true, false)
	r.check(after.size() == 8 and not after.any(func(b): return int(b.get_meta("pid")) in old_ids), "cards 12: a refresh shows eight new cards")
	var rb: Button = Game.current_screen.find_child("Refresh", true, false)
	r.check(rb != null and rb.icon == CreditCoin.texture(16) and rb.text.ends_with("%d" % Recruiting.refresh_cost(c)), "coin 4: the refresh cost, number then coin")
	Game.current_screen._ask_refresh()
	await _frames(1)
	var rich: Array = Game.overlay.find_children("CreditText", "RichTextLabel", true, false)
	r.check(not rich.is_empty() and String(rich[0].get_meta("text")).contains(CreditCoin.tag(Recruiting.refresh_cost(c))), "coin 12: the confirmation shows the amount and the coin")
	_clear_overlay()
	r.check(CreditCoin.tag(35) == "35{coin}" and CreditCoin.tag(8, true) == "+8{coin}" and CreditCoin.norm("+8{COIN}") == "+8{coin}", "coin 3: number first")
	Game.goto("recruiting", {"tab": "INCOMING"})
	await _frames(3)
	r.check(Game.current_screen.find_children("Card_*", "", true, false).size() == c.incoming.size(), "cards 13: INCOMING shows the signed as cards")
	# the cuts screen
	_to_done(c)
	c.queue.clear()
	c.end_week()
	if c.phase == "cuts":
		Game.goto("roster_cuts")
		await _frames(3)
		var cont: Button = Game.current_screen.find_child("Continue", true, false)
		r.check(Game.current_name == "roster_cuts" and cont != null and cont.disabled, "17: ROSTER CUTS REQUIRED, CONTINUE off")
		var txt := _texts(Game.current_screen)
		r.check(txt.contains("PLAYERS TO CUT: %d" % Offseason.cuts_needed(c)) and txt.contains("CUT PLAYER"), "17: how many, and CUT PLAYER")
	Game.goto("title")
	await _frames(1)

# ------------------------------------------------------------------ screenshots
static func shots(runner, out: String) -> void:
	DirAccess.make_dir_recursive_absolute(out)
	var tree: SceneTree = runner.get_tree()
	Store.reset_for_tests()
	Store.mark_starter_offered()   # (no starter-pack pop-up over the shots)
	var c := Career.new_game("CULA", "Sam", "Rivera", 31)
	c.queue.clear()
	c.hot_tip = true
	c.credits = 160
	Game.career = c
	var save := func(name: String) -> void:
		await tree.create_timer(0.5).timeout
		await RenderingServer.frame_post_draw
		runner.get_viewport().get_texture().get_image().save_png(out.path_join(name + ".png"))
		print("  shot ", name)
	Game.goto("recruiting", {"tab": "MARKET", "sel": (c.market[0].p as PoloPlayer).id})
	await save.call("ce_market")
	Recruiting.sign(c, c.market[1])
	Recruiting.sign(c, c.market[1])
	Game.goto("player", {"id": (c.market[0].p as PoloPlayer).id, "recruit": true})
	await save.call("ce_profile")
	RecruitingScreen.ask_sign(c, c.market[0], func(_e): pass)
	await save.call("ce_sign_dialog")
	for ch in Game.overlay.get_children():
		if ch != Game._fade:   # (the dialogs; never the screen fade)
			ch.queue_free()
	Game.goto("recruiting", {"tab": "INCOMING"})
	await save.call("ce_incoming")
	Game.goto("coaching")
	await save.call("ce_coaching")
	# a game's credits
	c.queue.clear()
	c.last_summary = c.sim_my_game()
	Game.goto("game_summary")
	await tree.create_timer(0.3).timeout
	var gs = Game.current_screen
	gs.stage = gs.Stage.NEXT
	gs.t = 3.0
	await save.call("ce_summary")
	# cuts
	c.credits = 2000
	Recruiting.sign(c, c.market[0])
	Recruiting.sign(c, c.market[0])
	var guard := 0
	while c.phase == "season" and guard < 40:
		guard += 1
		c.queue.clear()
		while c.has_game():
			c.sim_my_game()
		for q in c.upgrades_due():
			Development.ai_spend(q)
		c.end_week()
	c.queue.clear()
	Game.goto("hub")
	await save.call("ce_hub_done")
	c.end_week()
	c.queue.clear()
	if c.phase == "cuts":
		Game.goto("roster_cuts")
		await save.call("ce_cuts")
	Game.career = null

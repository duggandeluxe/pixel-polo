extends RefCounted
## XP Development Update 2.0: bigger game XP, no per-game cap, class multipliers (game XP only),
## every level-up processed inside the player's remaining potential, every XP stat recorded per
## player (both sides, once), the mandatory upgrades after the postgame and training, no game
## while one is unspent, MAX POTENTIAL, saves and older saves. The numbered checks follow the
## spec's REQUIRED TESTING list.
##   godot --headless --path game -- --test xp_update

const DT := 1.0 / 30.0
const Summary := preload("res://src/ui/screens/game_summary.gd")

var r   # the test runner

func run(runner) -> void:
	r = runner
	print("xp development update 2.0")
	Store.reset_for_tests()
	_unlimited()
	_multiple()
	_max_safeguard()
	_tracking()
	_classes()
	await _postgame_order()
	await _next_game_blocked()
	await _training_upgrades()
	_fully_developed()
	await _save_reload()
	_duplicates()
	_keeper()
	_injured_final()
	_migration()
	Game.career = null
	Game.goto("title")
	await r.get_tree().process_frame

# ------------------------------------------------------------------ helpers
func _p(vals: Dictionary, keeper := false, pots := {}) -> PoloPlayer:
	var p := AttrBench.player(vals, keeper, pots, PoloPlayer.Pos.UTILITY)
	p.id = 1 + randi() % 100000
	Development.ensure(p)
	return p

func _field(v: float, pot: float = 10.0) -> PoloPlayer:
	return _p({"pas": v, "sho": v, "str": v, "dfn": v}, false, {"pas": pot, "sho": pot, "str": pot, "dfn": pot})

func _rng(seed_value: int = 7) -> RandomNumberGenerator:
	var g := RandomNumberGenerator.new()
	g.seed = seed_value
	return g

## XP enough for `n` level-ups from where he is now (none of it left over).
func _xp_for(p: PoloPlayer, n: int) -> int:
	var total := 0
	for i in n:
		total += Development.xp_required(Development.level_index(p) + i)
	return total - p.xp

## Room under every ceiling for at least `n` more upgrades (his values kept).
func _roomy(p: PoloPlayer, n: int = 8) -> void:
	for k in p.key_ratings():
		Attributes.set_ceiling(p, k, minf(10.0, Attributes.value(p, k) + ceilf(float(n) / 4.0) + 1.0))

func _cur() -> String:
	return Game.current_name

func _frames(n: int = 2) -> void:
	for i in n:
		await r.get_tree().process_frame

# ------------------------------------------------------------------ 1: unlimited XP
func _unlimited() -> void:
	var fr := _field(5.0)
	fr.year = 1
	var line := {"g": 8, "a": 3}
	r.check(Development.base_game_xp(fr, line, true) == 221, "T1: 8 goals, 3 assists, played, won: base 221 (%d)" % Development.base_game_xp(fr, line, true))
	r.check(Development.game_xp(fr, line, true) == 177, "T1: a freshman gets ROUND(221 x 0.8) = 177, no cap (%d)" % Development.game_xp(fr, line, true))
	fr.xp_level = 80   # (a far-off requirement: the XP stays XP)
	Development.award_xp(fr, Development.game_xp(fr, line, true))
	r.check(fr.xp == 177, "T1: all 177 credited (%d)" % fr.xp)
	r.check(not FileAccess.get_file_as_string("res://src/core/development.gd").contains("GAME_XP_CAP"), "T1: no cap constant left")
	var sr := _field(5.0)
	sr.year = 4
	r.check(Development.game_xp(sr, {"g": 30, "a": 20, "st": 10}, true) == ((8 + 8 + 600 + 300 + 140) * 125 + 50) / 100, "T1: even a 30-goal game pays all of it (x1.25, a senior)")
	r.check(Development.game_xp(sr, {"to": 50, "ex": 50}, false) == 0, "T1: never negative")

# ------------------------------------------------------------------ 2: multiple level-ups
func _multiple() -> void:
	var p := _field(4.0)
	var lv := p.xp_level
	var need := _xp_for(p, 4)
	var got := Development.award_xp(p, need + 17)
	r.check(got == 4 and p.tokens == 4 and p.xp_level == lv + 4 and p.xp == 17, "T2: four thresholds in one award: 4 tokens, 4 levels, 17 carried over (%d, %d, %d)" % [got, p.xp_level - lv, p.xp])
	# the spec's walk-through: each threshold taken off in turn (his first 450, then 621...)
	var q := _field(2.0)
	var l2 := q.xp_level
	var award := 1600
	var left := award
	var lvl := Development.level_index(q)
	var want := 0
	while left >= Development.xp_required(lvl):
		left -= Development.xp_required(lvl)
		lvl += 1
		want += 1
	Development.award_xp(q, award)
	r.check(q.tokens == want and q.xp == left and q.xp_level == l2 + want, "T2: 1600 XP: %d tokens, %d left (got %d, %d)" % [want, left, q.tokens, q.xp])
	r.check(want >= 2, "T2: more than one upgrade from one game")

# ------------------------------------------------------------------ 3: the potential safeguard
func _max_safeguard() -> void:
	# three boxes left: Passing, Shooting and Strength one each, Defense at its ceiling
	var p := _p({"pas": 7, "sho": 7, "str": 7, "dfn": 7}, false, {"pas": 8, "sho": 8, "str": 8, "dfn": 7})
	r.check(Development.boxes_left(p) == 3, "T3: three boxes left (%d)" % Development.boxes_left(p))
	var lv := p.xp_level
	var got := Development.award_xp(p, _xp_for(p, 5) + 30)
	r.check(got == 3 and p.tokens == 3 and p.xp == 0 and p.xp_level == lv + 3, "T3: XP for five, three usable tokens; the excess XP dropped (%d tokens, %d XP)" % [p.tokens, p.xp])
	r.check(Development.award_xp(p, 5000) == 0 and p.tokens == 3 and p.xp == 0, "T3: nothing banked past potential")
	for k in ["pas", "sho", "str"]:
		Development.spend(p, k)
	r.check(Development.is_maxed(p) and p.tokens == 0 and p.xp == 0, "T3: all three spent: maximum potential")
	r.check(p.key_ratings().all(func(k): return p.attr(k) <= Attributes.ceiling(p, k) + 1e-6), "T3: nothing past its ceiling")
	r.check(not Development.spend(p, "dfn") and not Development.spend(p, "pas"), "T3: no further upgrade")
	# tokens he already holds count against the boxes
	var q := _p({"pas": 7, "sho": 7, "str": 7, "dfn": 7}, false, {"pas": 8, "sho": 8, "str": 8, "dfn": 7})
	q.tokens = 2
	r.check(Development.award_xp(q, _xp_for(q, 5)) == 1 and q.tokens == 3, "T3: two unspent tokens: only one more (%d)" % q.tokens)
	# a part box still takes one upgrade (spend caps it at the ceiling)
	var f := _p({"pas": 6, "sho": 6, "str": 6, "dfn": 6}, false, {"pas": 6.5, "sho": 6, "str": 6, "dfn": 6})
	r.check(Development.boxes_left(f) == 1, "T3: half a point of room is one box")

# ------------------------------------------------------------------ 4: statistical tracking
func _tracking() -> void:
	var tot := {}
	var bad: Array = []
	for i in 6:
		var a := League.make_team(i % 8, 0)
		var b := League.make_team((i + 3) % 8, 0)
		var f := MatchFlow.new(a, b, 7100 + i, MatchState.QUARTER_MIN)
		_play_match(f)
		var s := f.state
		for side in 2:
			var mine: PoloTeam = a if side == 0 else b
			var other: PoloTeam = b if side == 0 else a
			var lists := {"goal": s.goal_by[side], "assist": s.assist_by[side], "steal": s.steal_by[side], "block": s.block_by[side],
				"drawn": s.excl_drawn_by[side], "pen": s.pen_drawn_by[side], "to": s.turnover_by[side], "ex": s.excl_by[side],
				"kst": s.keeper_steal_by[side]}
			for k in lists:
				tot[k] = int(tot.get(k, 0)) + (lists[k] as Array).size()
				for q in lists[k]:
					if not mine.roster.has(q):
						bad.append("%s side %d" % [k, side])
			if s.steal_by[side].size() != s.steals[side] or s.block_by[side].size() != s.blocks[side]:
				bad.append("steal/block count side %d" % side)
			if s.excl_by[1 - side].size() != s.exclusions[side]:
				bad.append("every exclusion drawn by side %d has its committer (%d vs %d)" % [side, s.excl_by[1 - side].size(), s.exclusions[side]])
			if s.steal_by[side].any(func(q): return (q as PoloPlayer).is_keeper()) or s.block_by[side].any(func(q): return (q as PoloPlayer).is_keeper()):
				bad.append("a keeper's steal or save counted as a field steal / block")
			if not s.keeper_steal_by[side].all(func(q): return (q as PoloPlayer).is_keeper()):
				bad.append("keeper steals are keepers'")
			if s.turnover_by[side].any(func(q): return other.roster.has(q)):
				bad.append("a turnover charged to the side that won the ball")
		var box := s.box(a, b)
		if (box.turnovers as Array).size() != s.turnover_by[0].size() or ((box.them as Dictionary).lists.to as Array).size() != s.turnover_by[1].size():
			bad.append("the box carries both sides' turnovers")
	print("    6 bot games: %s" % [tot])
	r.check(bad.is_empty(), "T4: every event credited to a player of the right side (%s)" % [bad.slice(0, 4)])
	for k in ["goal", "assist", "steal", "block", "drawn", "to", "ex"]:
		r.check(int(tot.get(k, 0)) > 0, "T4: %s recorded in real games (%d)" % [k, int(tot.get(k, 0))])
	# drawn 5 m penalties: rarer, so straight through the flow
	var c := League.make_team(1, 0)
	var d := League.make_team(2, 0)
	var g := MatchFlow.new(c, d, 4242, MatchState.QUARTER_MIN)
	g._start_attack(Play.Kind.HALF_COURT)
	var fouled: PoloPlayer = c.starters()[3]
	g.play._finish("penalty", "PENALTY!", {"fouled": fouled})
	g.attack_done()
	r.check(g.state.pen_drawn_by[0] == [fouled] and g.state.excl_drawn_by[0].is_empty(), "T4: a penalty foul: 5 m penalty drawn, not an exclusion too")
	g._start_defense(Play.Kind.HALF_COURT)
	var their: PoloPlayer = d.starters()[4]
	g.play._finish("penalty", "PENALTY!", {"fouled": their})
	g.defense_done()
	r.check(g.state.pen_drawn_by[1] == [their], "T4: ...for the CPU side too")
	# into the career: stats on both sides and the XP lines
	var car := Career.new_game("GWU", "A", "B", 64)
	Game.career = car
	var us := car.team()
	var opp := car.opponent()
	var st := MatchState.new()
	var seven := us.starters()
	var o7 := opp.starters()
	st.score = [3, 2]
	st.goal_by = [[seven[1], seven[1], seven[2]], [o7[1], o7[2]]]
	st.assist_by = [[seven[2]], [o7[3]]]
	st.steal_by = [[seven[3]], [o7[4]]]
	st.steals = [1, 1]
	st.keeper_steal_by = [[seven[0]], [o7[0]]]
	st.block_by = [[seven[4]], [o7[5]]]
	st.excl_drawn_by = [[seven[5]], [o7[6]]]
	st.exclusions = [1, 1]
	st.excl_by = [[seven[6]], [o7[2]]]
	st.turnover_by = [[seven[1]], [o7[1]]]
	st.pen_drawn_by = [[seven[3]], []]
	st.saves = [9, 6]
	var before := {}
	for q in us.roster + opp.roster:
		_roomy(q)
		q.tokens = 0
		q.xp = 0
		q.xp_level = 80
		before[q.id] = q.stats.duplicate()
	var out := car.finish_my_game(st.box(us, opp))
	var d1 := func(q: PoloPlayer, k: String) -> int: return q.stat(k) - int((before[q.id] as Dictionary).get(k, 0))
	r.check(d1.call(seven[1], "g") == 2 and d1.call(seven[1], "to") == 1 and d1.call(seven[3], "st") == 1 and d1.call(seven[3], "pd") == 1
		and d1.call(seven[5], "ed") == 1 and d1.call(seven[6], "ex") == 1 and d1.call(seven[4], "bl") == 1 and d1.call(seven[0], "st") == 1
		and d1.call(seven[0], "sv") == 9 and d1.call(seven[0], "ga") == 2, "T4: your players' career stats: every new stat recorded")
	r.check(seven.all(func(q): return d1.call(q, "gp") == 1) and us.roster.filter(func(q): return not seven.has(q)).all(func(q): return d1.call(q, "gp") == 0),
		"T4: appearances only for the players in the water")
	var pct := func(q: PoloPlayer, base: int) -> int: return (base * Development.class_pct(q) + 50) / 100
	r.check(seven[1].xp == pct.call(seven[1], 8 + 8 + 40 - 4), "T4: goals and a turnover in his XP (%d)" % seven[1].xp)
	r.check(seven[3].xp == pct.call(seven[3], 8 + 8 + 14 + 18), "T4: a steal and a drawn 5 m penalty (%d)" % seven[3].xp)
	r.check(seven[6].xp == pct.call(seven[6], 8 + 8 - 4), "T4: an exclusion committed costs 4 (%d)" % seven[6].xp)
	r.check(seven[0].xp == pct.call(seven[0], 8 + 8 + 90 - 2 + 14), "T4: the keeper: saves, conceded, his steal (%d)" % seven[0].xp)
	r.check(o7[1].xp == pct.call(o7[1], 8 + 20 - 4) and o7[2].xp == pct.call(o7[2], 8 + 20 - 4) and o7[0].xp == pct.call(o7[0], 8 + 60 - 3 + 14),
		"T4: the CPU side's XP from its own recorded stats, no win bonus (%d, %d, %d)" % [o7[1].xp, o7[2].xp, o7[0].xp])
	r.check(us.roster.filter(func(q): return not seven.has(q)).all(func(q): return q.xp == 0), "T4: the bench gets nothing")
	r.check(out.has("xp"), "T4: the summary has the awards")

## A whole bot-played game (the stats harness's driver).
func _play_match(f: MatchFlow) -> void:
	var steps := 0
	while f.phase != MatchFlow.Phase.FINAL and steps < 200000:
		steps += 1
		match f.phase:
			MatchFlow.Phase.SPRINT:
				f.sprint_done(f.rng.randf() < 0.5)
			MatchFlow.Phase.ATTACK:
				_possession(f, true)
				f.attack_done()
			MatchFlow.Phase.DEFENSE:
				_possession(f, false)
				f.defense_done()
			MatchFlow.Phase.SHOOTOUT_THEM:
				f.their_ball_done()
			MatchFlow.Phase.THEIR_SHOT:
				f.auto_duel(0.5)
				f.duel_done()
			MatchFlow.Phase.BREAK:
				f.break_done()

func _possession(f: MatchFlow, ours: bool) -> void:
	var p := f.play
	var think := 0.0
	var t := 0.0
	if not ours:
		if "auto_defend" in f:
			f.set("auto_defend", true)
		f.auto_keeper = 0.5
	while not p.over and t < 90.0:
		if ours:
			think -= DT
			if think <= 0.0:
				think = PlayBot.THINK_EVERY
				var d := PlayBot.think(p, f.rng)
				if not d.is_empty():
					p.throw(d.target, d.power)
			f.tick_attack(DT)
		else:
			f.tick_defense(DT)
		t += DT
		f.events.clear()

# ------------------------------------------------------------------ 5: class multipliers
func _classes() -> void:
	var line := {"g": 2, "a": 1}
	var got := []
	for y in [1, 2, 3, 4]:
		var p := _field(5.0)
		p.year = y
		got.append(Development.game_xp(p, line, true))
	r.check(got == [57, 67, 78, 89], "T5: base 71: FR 57, SO 67, JR 78, SR 89 (%s)" % [got])
	var k := _p({"com": 5, "lun": 5, "blk": 5, "leg": 5}, true)
	k.year = 2
	r.check(Development.game_xp(k, {"sv": 10}, false) == 103, "T5: keepers too: (8 + 100) x 0.95 = 103")
	# exact half-up where floating point would slip (10 x 1.15 = 11.5 -> 12)
	var j := _field(5.0)
	j.year = 3
	r.check(Development.game_xp(j, {"ga": 2}, false) == 9 and Development.game_xp(j, {"to": 0}, true) == 18, "T5: rounded half-up exactly (8 x 1.15 = 9.2 -> 9; 16 x 1.15 = 18.4 -> 18)")
	# training never sees the class
	var tr := []
	for y in [1, 4]:
		var p := _field(5.0)
		p.year = y
		tr.append([Development.training_xp(p, "balanced", 2), Development.training_xp(p, "shooting", 3), Development.training_xp(p, "recovery", 2)])
	r.check(tr[0] == tr[1] and tr[0] == [12, 27, 0], "T5: training XP the same for a freshman and a senior (%s)" % [tr])
	# moving up a class changes only future game XP
	var m := _field(5.0)
	m.year = 1
	var keep := [m.attrs.duplicate(), m.attr_pot.duplicate(), m.xp_level, m.stars]
	m.year = 2
	r.check([m.attrs, m.attr_pot, m.xp_level, m.stars] == keep and Development.class_pct(m) == 95, "T5: a new class year: only the multiplier moves (SO 95)")

# ------------------------------------------------------------------ 6: the postgame, then upgrades
func _postgame_order() -> void:
	var c := Career.new_game("GWU", "A", "B", 606)
	Game.career = c
	c.queue.clear()   # (the welcome and the season goals)
	var seven := c.team().starters()
	var ups: Array = [seven[1], seven[2], seven[3]]
	for q in ups:
		_roomy(q)
		q.xp = Development.xp_needed(q) - 1   # appearance alone pays the next one
	c.last_summary = c.sim_my_game()
	r.check(ups.all(func(q): return q.tokens >= 1), "T6: three players earned upgrades in the game")
	var seen: Array = []
	Game.goto("game_summary")
	await _frames()
	seen.append(_cur())
	var scr = Game.current_screen
	var stages: Array = [scr.stage]
	for i in 6:
		if scr.stage == Summary.Stage.NEXT:
			break
		scr.t = 99.0
		scr.tap(Vector2.ZERO)
		if scr.stage == Summary.Stage.HOT:
			scr.reveal.skip()
			scr._reveal_done()
		stages.append(scr.stage)
		await _frames(1)
	r.check(stages[0] == Summary.Stage.FINAL and stages.has(Summary.Stage.LEAGUE) and stages.back() == Summary.Stage.NEXT, "T6: final score, then every summary stage (%s)" % [stages])
	r.check(_cur() == "game_summary", "T6: no upgrade screen interrupts the summary")
	scr._continue()
	await _frames()
	seen.append(_cur())
	r.check(_cur() == "postgame_review", "T6: the POSTGAME REVIEW next")
	Game.current_screen._continue()
	await _frames(3)
	if _cur() == "coach_event":   # (sometimes a coaching event: its XP can add upgrades too)
		seen.append("coach_event")
		Game.current_screen.pick = 0
		Game.current_screen._confirm()
		Game.current_screen._leave()
	await _frames(4)
	# the hub shows anything queued (cards, press) first; clear those as the coach would
	var guard := 0
	while _cur() == "hub" and not c.queue.is_empty() and guard < 10:
		guard += 1
		Game.current_screen._drop_item()
		Game.goto("hub", {}, false)
		await _frames(4)
	seen.append(_cur())
	r.check(_cur() == "player" and bool(Game.current_screen.mandatory), "T6: then the mandatory upgrades (%s)" % [seen])
	var visited := {}
	guard = 0
	while _cur() == "player" and guard < 40:
		guard += 1
		var pg = Game.current_screen
		visited[pg.p.id] = true
		r.check(Development.pending(pg.p) > 0 or guard > 1, "T6: each page is a player with upgrades")
		# back is refused while one is left
		if Development.pending(pg.p) > 0:
			pg.on_back()
			await _frames(1)
			r.check(_cur() == "player" and Game.current_screen == pg, "T15/16: back refused while he has an upgrade")
		var key := ""
		for k in pg.p.key_ratings():
			if Development.can_spend(pg.p, k):
				key = k
				break
		if key == "":
			break
		var who: PoloPlayer = pg.p
		var left := Development.pending(who)
		var v0: float = who.attr(key)
		await pg._buy(key)
		await _frames(1)
		r.check(is_equal_approx(who.attr(key), minf(v0 + 1.0, Attributes.ceiling(who, key))) and Development.pending(who) == left - 1, "T15: one token, one point")
	r.check(ups.all(func(q): return visited.has(q.id)), "T16: every player who earned one was visited in turn")
	r.check(c.upgrades_due().is_empty() and _cur() == "hub", "T6: all spent: back to the hub (%s)" % _cur())
	r.check(seen.slice(0, 2) == ["game_summary", "postgame_review"], "T6: the order: summary, review, (event,) then upgrades (%s)" % [seen])
	Game.goto("matchup")
	await _frames()
	r.check(_cur() == "matchup" or not c.has_game(), "T6: the next game is open again")

# ------------------------------------------------------------------ 7: no game with an upgrade unspent
func _next_game_blocked() -> void:
	var c := Career.new_game("STAM", "A", "B", 707)
	Game.career = c
	c.queue.clear()
	for q in c.team().roster:
		q.tokens = 0   # (only his upgrades in the way)
	var p: PoloPlayer = c.team().starters()[2]
	_roomy(p)
	p.tokens = 2
	Game.goto("hub")
	await _frames(4)
	r.check(_cur() == "player", "T7: the hub sends you to the upgrade")
	Game.goto("matchup")
	await _frames()
	r.check(_cur() == "player" and Game.current_screen.p == p, "T7: PLAY's matchup: blocked, his upgrade opens")
	Game.goto("match", {"us": c.team(), "them": c.opponent(), "seed": 1, "career": true, "home": true, "pool": c.venue().id})
	await _frames()
	r.check(_cur() == "player", "T7: the match itself (any path): blocked")
	var week := c.week
	Game.goto("hub", {}, false)
	Game.current_screen._sim_week()   # (straight away, before the hub opens them itself)
	await _frames()
	r.check(c.week == week and _cur() == "player", "T7: NEXT WEEK / SIM WEEK: blocked")
	# (on attributes with room: one already at 10 can't take a box)
	var open: Array = p.key_ratings().filter(func(k): return Attributes.room(p, k) >= 1.0)
	Development.spend(p, open[0])
	r.check(Game.upgrade_target() != {}, "T7: one of two spent: still blocked")
	Development.spend(p, open[1] if open.size() > 1 else open[0])
	r.check(Game.upgrade_target() == {}, "T7: all spent: free")
	Game.goto("matchup")
	await _frames()
	r.check(_cur() == "matchup", "T7: ...and the game can start")

# ------------------------------------------------------------------ 8: training upgrades
func _training_upgrades() -> void:
	var c := Career.new_game("GWU", "A", "B", 808)
	Game.career = c
	c.training = {"focus": "balanced", "intensity": 2}
	var p: PoloPlayer = c.team().roster[4]
	_roomy(p)
	p.xp_level = 1   # (his first two levels, the cheapest: one week pays both)
	p.xp_start = 1
	p.xp = 0
	var need := Development.xp_required(0) + Development.xp_required(1)
	p.xp = need - 10
	var rep := c.train_week()
	r.check(int(rep.tokens.get(p.id, 0)) >= 2 and p.tokens >= 2, "T8: a training week paying two upgrades: both recorded (%d)" % p.tokens)
	r.check(int(rep.xp.get(p.id, 0)) == Development.training_xp(p, "balanced", 2), "T8: training XP exactly as before (no class multiplier)")
	r.check(c.train_week().is_empty(), "T8: the same week never trains twice")
	r.check(c.news.any(func(n): return String(n.get("t", n) if n is Dictionary else n).contains("NEW ATTRIBUTE UPGRADE AVAILABLE!")), "T8: the training news says so")
	c.queue.clear()
	c.queue.append({"type": "info", "title": "TEST", "text": "a queued message"})
	Game.goto("hub")
	await _frames(4)
	r.check(_cur() == "hub", "T8: what's queued shows first")
	Game.current_screen._next_item()
	await _frames(2)
	r.check(_cur() == "player" and bool(Game.current_screen.mandatory), "T8: then the mandatory upgrades")
	Game.goto("matchup")
	await _frames()
	r.check(_cur() == "player", "T8: the next game waits for them")
	while Development.pending(p) > 0:
		var k := ""
		for kk in p.key_ratings():
			if Development.can_spend(p, kk):
				k = kk
		Development.spend(p, k)
	for q in c.upgrades_due():
		while Development.pending(q) > 0:
			Development.spend(q, Development.ai_choice(q))
	Game.goto("matchup")
	await _frames()
	r.check(_cur() == "matchup" or not c.has_game(), "T8: spent: the game opens")

# ------------------------------------------------------------------ 9: fully developed
func _fully_developed() -> void:
	var p := _field(7.0, 7.0)
	var lv := p.xp_level
	r.check(Development.is_maxed(p) and Development.boxes_left(p) == 0, "T9: every attribute at its ceiling")
	r.check(Development.award_xp(p, 10000) == 0 and p.xp == 0 and p.tokens == 0 and p.xp_level == lv, "T9: no XP, no level, no token")
	Development.injure(p, _rng(), "moderate", "hip")
	r.check(Development.eff_value(p, "str") == 5.0 and Attributes.value(p, "str") == 7.0 and Development.is_maxed(p), "T9: injured: plays at 5, still fully developed at 7")
	Development.heal(p)
	r.check(Development.eff_value(p, "str") == 7.0, "T9: recovers as normal")
	# in a career game: stats recorded, no development
	var c := Career.new_game("SCCU", "A", "B", 909)
	Game.career = c
	var seven := c.team().starters()
	var m: PoloPlayer = seven[2]
	for k in m.key_ratings():
		Attributes.set_ceiling(m, k, Attributes.value(m, k))
	m.xp = 33
	m.tokens = 1
	Development.reconcile(m)
	var g0 := m.stat("g")
	var ml := m.xp_level
	var st := MatchState.new()
	st.score = [2, 0]
	st.goal_by = [[m, m], []]
	c.finish_my_game(st.box(c.team(), c.opponent()))
	r.check(m.stat("g") == g0 + 2 and m.xp == 0 and m.tokens == 0 and m.xp_level == ml, "T9: his goals count, his development doesn't move")
	r.check(not c.upgrades_due().has(m), "T9: never in the upgrade queue")

# ------------------------------------------------------------------ 10: save and reload
func _save_reload() -> void:
	var c := Career.new_game("GWU", "A", "B", 1010)
	Game.career = c
	var p: PoloPlayer = c.team().starters()[3]
	_roomy(p)
	p.xp_level = 60
	c.last_summary = c.sim_my_game()
	var g: Dictionary = c.last_summary.game
	p.tokens = 2
	p.xp = 123
	var back := Career.from_dict(JSON.parse_string(JSON.stringify(c.to_dict())))
	var q: PoloPlayer = back.team().find_id(p.id)
	r.check(q.tokens == 2 and q.xp == 123 and q.xp_level == 60 and q.attrs == p.attrs, "T10: tokens, XP, level and attributes survive")
	var gb: Dictionary = {}
	for gm in back.cur().games:
		if gm.h == g.h and gm.a == g.a and int(gm.get("d", 0)) == int(g.get("d", 0)):
			gb = gm
	r.check(bool(gb.get("xp", false)) and back._award_game_xp(gb, {}, {}).is_empty() and q.xp == 123, "T10: the settled game stays settled")
	Game.career = back
	back.queue.clear()
	Game.goto("hub")
	await _frames(4)
	var guard := 0
	while _cur() == "hub" and not back.queue.is_empty() and guard < 10:
		guard += 1
		Game.current_screen._drop_item()
		Game.goto("hub", {}, false)
		await _frames(4)
	r.check(_cur() == "player" and bool(Game.current_screen.mandatory) and back.upgrades_due().has(q), "T10: the upgrades open again after loading (%s)" % _cur())
	Game.goto("matchup")
	await _frames()
	r.check(_cur() == "player", "T10: and the next game stays closed")

# ------------------------------------------------------------------ 11: duplicate events
func _duplicates() -> void:
	var a := League.make_team(3, 0)
	var b := League.make_team(4, 0)
	var f := MatchFlow.new(a, b, 1111, MatchState.QUARTER_MIN)
	f._start_attack(Play.Kind.HALF_COURT)
	var blocker: PoloPlayer = b.starters()[3]
	var e := {"k": "block", "by": blocker}
	f.play.events.append(e)
	f.play.events.append(e)   # the same block reported twice (a repeated callback)
	f._collect(0)
	f.play.events.append(e)   # ...and once more a frame later
	f._collect(0)
	r.check(f.state.blocks[1] == 1 and f.state.block_by[1] == [blocker], "T11: one block, counted once (%d)" % f.state.blocks[1])
	var ex := {"k": "exclusion", "drawn_by": a.starters()[2], "by": b.starters()[2], "text": "x"}
	f.play.events.append(ex)
	f.play.events.append(ex)
	f._collect(0)
	r.check(f.state.exclusions[0] == 1 and f.state.excl_by[1].size() == 1 and f.state.excl_drawn_by[0].size() == 1, "T11: one exclusion: one drawn, one committed")
	f.play.events.append({"k": "block", "by": blocker})
	f._collect(0)
	r.check(f.state.blocks[1] == 2, "T11: a second, separate block still counts")
	# a possession's result counted once
	var sc: PoloPlayer = a.starters()[4]
	f.play._finish("goal", "GOAL!", {"scorer": sc})
	var pn := f.play_no
	f.attack_done()
	r.check(f.state.goal_by[0] == [sc] and f.state.score[0] == 1, "T11: the goal counted")
	r.check(not f.state.once("%d:end" % pn), "T11: its result is marked counted")
	# a game settled twice: stats and XP once
	var c := Career.new_game("GWU", "A", "B", 1112)
	Game.career = c
	var seven := c.team().starters()
	var st := MatchState.new()
	st.score = [1, 0]
	st.goal_by = [[seven[2]], []]
	var g0 := seven[2].stat("g")
	var box := st.box(c.team(), c.opponent())
	c.last_summary = c.finish_my_game(box)
	var xp := seven[2].xp
	var tk := seven[2].tokens
	c.finish_my_game(box)
	r.check(seven[2].stat("g") == g0 + 1 and seven[2].xp == xp and seven[2].tokens == tk, "T11: finishing the same game again counts nothing")

# ------------------------------------------------------------------ 12: a keeper's huge game
func _keeper() -> void:
	var k := _p({"com": 2, "lun": 2, "blk": 2, "leg": 2}, true, {"com": 9, "lun": 9, "blk": 9, "leg": 9})
	k.year = 4
	var line := {"sv": 40, "ga": 3, "st": 2}
	var base := 8 + 8 + 400 - 3 + 28
	r.check(Development.base_game_xp(k, line, true) == base, "T12: 40 saves: every one in the base (%d)" % Development.base_game_xp(k, line, true))
	var xp := Development.game_xp(k, line, true)
	r.check(xp == (base * 125 + 50) / 100 and xp > 500, "T12: a senior keeper: x1.25, no cap (%d)" % xp)
	var lv := k.xp_level
	var left := xp
	var lvl := Development.level_index(k)
	var want := 0
	while left >= Development.xp_required(lvl) and want < Development.boxes_left(k):
		left -= Development.xp_required(lvl)
		lvl += 1
		want += 1
	Development.award_xp(k, xp)
	r.check(k.tokens == want and want >= 1 and k.xp == left and k.xp_level == lv + want, "T12: every level-up processed (%d tokens)" % k.tokens)
	var c := Career.new_game("STAM", "A", "B", 1212)
	var lines := Development.lines_of(c.team().starters(), {}, c.team().keeper(), 40, 3)
	r.check(int(lines[c.team().keeper().id].sv) == 40, "T12: all 40 saves on his line")

# ------------------------------------------------------------------ 13: final upgrade while injured
func _injured_final() -> void:
	var p := _p({"pas": 9, "sho": 6, "str": 9, "dfn": 9}, false, {"pas": 9, "sho": 7, "str": 9, "dfn": 9})
	Development.injure(p, _rng(), "moderate", "shoulder")
	Development.award_xp(p, _xp_for(p, 3))
	r.check(p.tokens == 1 and p.xp == 0, "T13: one box left: one token (%d)" % p.tokens)
	var before := Deck.box_states(p.attr("sho"), Attributes.ceiling(p, "sho"), Development.penalty(p, "sho"), p.tokens)
	r.check(Development.spend(p, "sho"), "T13: the last box bought while injured")
	var after := Deck.box_states(p.attr("sho"), Attributes.ceiling(p, "sho"), Development.penalty(p, "sho"), p.tokens)
	r.check(Attributes.value(p, "sho") == 7.0 and Development.penalty(p, "sho") == 2 and Development.eff_value(p, "sho") == 5.0, "T13: permanent 7, the penalty still -2, plays at 5")
	r.check(before.slice(0, 7) == ["green", "green", "green", "green", "red", "red", "buy"] and after.slice(0, 7) == ["green", "green", "green", "green", "green", "red", "red"],
		"T13: the red boxes move up with the new point (%s -> %s)" % [before.slice(0, 7), after.slice(0, 7)])
	r.check(Development.is_maxed(p) and p.tokens == 0 and p.xp == 0 and Development.award_xp(p, 999) == 0, "T13: maximum potential from the permanent attributes; development stops")

# ------------------------------------------------------------------ 14: an older save
func _migration() -> void:
	var c := Career.new_game("GWU", "A", "B", 1414)
	var t := c.team()
	var a: PoloPlayer = t.starters()[1]
	var b: PoloPlayer = t.starters()[2]
	var n: PoloPlayer = t.starters()[3]
	for k in b.key_ratings():
		Attributes.set_ceiling(b, k, Attributes.value(b, k))
	_roomy(n)
	var d := c.to_dict()
	var week := c.week
	var rec := c.record_text()
	# what the old build could have saved: more tokens than room, XP on a maxed player
	var edit := func(pid: int, dev: Dictionary) -> void:
		for td in (d.teams as Dictionary).values():
			for pd in td.roster:
				if int(pd.id) == pid:
					(pd.development as Dictionary).merge(dev, true)
	edit.call(a.id, {"available_upgrade_tokens": Development.boxes_left(a) + 4, "current_xp": 50})
	edit.call(b.id, {"available_upgrade_tokens": 2, "current_xp": 77})
	edit.call(n.id, {"available_upgrade_tokens": 1, "current_xp": 40})
	var back := Career.from_dict(JSON.parse_string(JSON.stringify(d)))
	var a2: PoloPlayer = back.team().find_id(a.id)
	var b2: PoloPlayer = back.team().find_id(b.id)
	var n2: PoloPlayer = back.team().find_id(n.id)
	r.check(a2.tokens == Development.boxes_left(a2) and a2.xp == 0 and a2.attrs == a.attrs and a2.attr_pot == a.attr_pot, "T14: excess tokens trimmed to his room, attributes untouched")
	r.check(b2.tokens == 0 and b2.xp == 0 and b2.attrs == b.attrs and b2.xp_level == b.xp_level, "T14: a fully developed player normalised, gameplay attributes kept")
	r.check(n2.tokens == 1 and n2.xp == 40, "T14: legitimate tokens and XP kept")
	r.check(back.week == week and back.record_text() == rec and back.teams.size() == c.teams.size(), "T14: the season carries on where it was")
	var stats_ok := back.team().roster.all(func(q): return q.stats == (t.find_id(q.id) as PoloPlayer).stats)
	r.check(stats_ok, "T14: season stats intact")

# ------------------------------------------------------------------ screenshots
## The mandatory upgrade page, a fully developed player's page and his roster card.
##   godot --path game -- --test xp_update_png <outdir>
static func shots(runner, out: String) -> void:
	DirAccess.make_dir_recursive_absolute(out)
	var tree: SceneTree = runner.get_tree()
	Store.reset_for_tests()
	var c := Career.new_game("WAGN", "Sam", "Rivera", 31)
	c.hot_tip = true
	c.queue.clear()
	Game.career = c
	var seven := c.team().starters()
	var up: PoloPlayer = seven[2]
	for k in up.key_ratings():
		Attributes.set_ceiling(up, k, minf(10.0, Attributes.value(up, k) + 2.0))
	up.tokens = 3
	var done: PoloPlayer = seven[3]
	for k in done.key_ratings():
		Attributes.set_ceiling(done, k, Attributes.value(done, k))
	Development.reconcile(done)
	for shot in [["player", {"id": up.id, "mandatory": true}, "x_mandatory"], ["player", {"id": done.id}, "x_max_profile"], ["roster", {}, "x_max_roster"]]:
		Game.goto(String(shot[0]), shot[1])
		await tree.create_timer(0.6).timeout
		for n in tree.root.find_children("*", "", true, false):
			if n.name.begins_with("Dialog") or n.name.begins_with("Tip"):
				n.queue_free()
		await tree.process_frame
		await RenderingServer.frame_post_draw
		runner.get_viewport().get_texture().get_image().save_png(out.path_join(String(shot[2]) + ".png"))
		print("  shot ", shot[2])

extends RefCounted
## Weekly awards over whole simulated seasons: how often a keeper is POTW, how the best field and
## keeper POTW scores compare, and every conference-week's four (distinct, all given?), as they
## were decided at the time (ConfAwards.measure).
##   godot --headless --path game -- --test conf_awards_measure [seasons] [seed]
## Also writes user://award_weeks.csv (week, best field POTW score, then each keeper's sv, ga, gp, st).

static func report(runner, seasons: int, seed_value: int) -> void:
	Store.reset_for_tests()
	ConfAwards.measure = []
	var c := Career.new_game("BUCK", "A", "B", seed_value)
	for s in seasons:
		var label := c.season_label()
		var guard := 0
		while c.season_label() == label and guard < 80:
			guard += 1
			c.queue.clear()
			for q in c.upgrades_due():
				Development.ai_spend(q)
			while c.has_game():
				c.sim_my_game()
				for q in c.upgrades_due():
					Development.ai_spend(q)
			c.end_week()
			runner._make_cuts(c)
	var weeks: Array = ConfAwards.measure
	ConfAwards.measure = null
	var gk_wins := 0
	var field_best: Array = []
	var gk_best: Array = []
	var full := 0
	var dup := 0
	var missing := {}
	var impossible := 0
	var dump := FileAccess.open("user://award_weeks.csv", FileAccess.WRITE)
	for wi in weeks.size():
		var wk: Dictionary = weeks[wi]
		var f := -INF
		var g := -INF
		for e in wk.lines:
			var sc := ConfAwards.score(e.p, e.line, "potw")
			if (e.p as PoloPlayer).is_keeper():
				g = maxf(g, sc)
			else:
				f = maxf(f, sc)
		for e in wk.lines:
			if (e.p as PoloPlayer).is_keeper():
				dump.store_line("%d,%f,%d,%d,%d,%d" % [wi, f, int(e.line.get("sv", 0)), int(e.line.get("ga", 0)), int(e.line.get("gp", 0)), int(e.line.get("st", 0))])
		field_best.append(f)
		gk_best.append(g)
		gk_wins += 1 if bool(wk.gk_potw) else 0
		var ids: Array = wk.ids
		var uniq := {}
		for x in ids:
			uniq[x] = true
		dup += ids.size() - uniq.size()
		var pick: Array = wk.pick
		full += 1 if pick.size() == 4 else 0
		for cat in ConfAwards.CATS:
			if not cat in pick:
				missing[cat] = int(missing.get(cat, 0)) + 1
		if pick.size() < 4 and (int(wk.fresh) == 0 or int(wk.gks) < 2):
			impossible += 1
	dump.close()
	field_best.sort()
	gk_best.sort()
	var n := weeks.size()
	var pct := func(arr: Array, q: float) -> float: return float(arr[clampi(int(q * arr.size()), 0, arr.size() - 1)])
	print("WEEKLY AWARDS over %d seasons: %d conference-weeks" % [seasons, n])
	print("  keeper POTW: %d (%.1f%%)" % [gk_wins, 100.0 * gk_wins / maxf(1.0, n)])
	print("  best field POTW score: median %.1f, p10 %.1f, p90 %.1f" % [pct.call(field_best, 0.5), pct.call(field_best, 0.1), pct.call(field_best, 0.9)])
	print("  best keeper POTW score: median %.1f, p90 %.1f, p99 %.1f, max %.1f" % [pct.call(gk_best, 0.5), pct.call(gk_best, 0.9), pct.call(gk_best, 0.99), gk_best[-1]])
	print("  all four given: %d of %d; duplicate winners: %d; missing %s (short weeks with no freshman or one keeper: %d)" % [full, n, dup, str(missing), impossible])
	print("  dump: %s" % ProjectSettings.globalize_path("user://award_weeks.csv"))

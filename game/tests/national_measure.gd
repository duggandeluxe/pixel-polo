extends RefCounted
## NCSA annual honours over whole simulated seasons: who wins (keeper or field), and how the best
## keeper and field candidates compare (POY: season_value; DPOY: def_values without the keeper pref).
##   godot --headless --path game -- --test national_measure [seasons] [seed]
static func report(runner, seasons: int, seed_value: int) -> void:
	Store.reset_for_tests()
	var c := Career.new_game("BUCK", "A", "B", seed_value)
	for s in seasons:
		var label := c.season_label()
		var guard := 0
		while c.phase == "season" and guard < 80:
			guard += 1
			c.queue.clear()
			for q in c.upgrades_due():
				Development.ai_spend(q)
			while c.has_game():
				c.sim_my_game()
				for q in c.upgrades_due():
					Development.ai_spend(q)
			c.end_week()
		# the season's done: its honours, and the candidates as they stood
		var everyone: Array = []
		for id in c.teams:
			for p: PoloPlayer in (c.teams[id] as PoloTeam).roster:
				if p.stat("gp") > 0:
					everyone.append({"p": p, "team": id})
		var games := NationalAwards._median_games(everyone)
		var defs := NationalAwards.def_values(everyone)
		var ov := NationalAwards.overall_values(everyone, games, 0.0)
		var best := {"poy_gk": -INF, "poy_f": -INF, "def_gk": -INF, "def_f": -INF}
		for e in everyone:
			var p: PoloPlayer = e.p
			var k := "gk" if p.is_keeper() else "f"
			best["poy_" + k] = maxf(best["poy_" + k], float(ov[p.id]))
			best["def_" + k] = maxf(best["def_" + k], float(defs[p.id]) - (NationalAwards.GK_PREF if p.is_keeper() else 0.0))
		var won := {}
		for a in c.awards:
			if String(a.year) == label and a.has("pid"):
				won[String(a.award)] = won.get(String(a.award), []) + ["%s %s %s" % [PoloPlayer.POS_SHORT[int(a.pos)], a.name, NationalAwards.line_text(a)]]
		print("SEASON %s: POY (no handicap) gk %.2f / field %.2f; DEF (no pref) gk %.2f / field %.2f" % [label, best.poy_gk, best.poy_f, best.def_gk, best.def_f])
		for k in NationalAwards.KEYS:
			print("   %s: %s" % [k, str(won.get(k, []))])
		while c.phase != "season" or c.season_label() == label:
			c.queue.clear()
			c.end_week()
			runner._make_cuts(c)
			if c.phase == "season" and c.season_label() != label:
				break

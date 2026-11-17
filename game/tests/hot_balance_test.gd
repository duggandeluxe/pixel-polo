extends RefCounted
## The Universal Hot Star Balancing & CPU Momentum update: one multiplier (PlayerForm.
## HOT_STAR_ACQUISITION_MULTIPLIER, 1.30) on the performance a GOOD game takes, for everyone; CPU
## players graded, heated and boosted exactly like yours; nothing else moved.
##   godot --headless --path game -- --test hot_balance          (the checks + a short measurement)
##   godot --headless --path game -- --test hot_balance_measure N (N seasons a multiplier, 1.00 vs 1.30)

var r

func run(runner) -> void:
	r = runner
	print("hot balance")
	Store.reset_for_tests()
	_rules()
	_everyone()
	await _lab()
	var m := measure(1, [1.0, PlayerForm.HOT_STAR_ACQUISITION_MULTIPLIER])
	var a: Dictionary = m[0]
	var b: Dictionary = m[1]
	r.check(float(b.hot_rate) < float(a.hot_rate) and float(b.first) < float(a.first) and float(b.second) <= float(a.second),
		"1/4/5: at 1.30 fewer Hot Stars are earned (first %.2f -> %.2f, second %.2f -> %.2f a team-season)" % [a.first, b.first, a.second, b.second])
	r.check(int(b.cpu_first) > 0, "8/16/17/21: CPU players heat up in simulated games (%d first stars in a season)" % int(b.cpu_first))
	Game.career = null

func _rules() -> void:
	r.check(is_equal_approx(PlayerForm.GOOD_AT, 4.5 * 1.30) and is_equal_approx(PlayerForm.good_at(), 5.85), "1/6: GOOD takes +5.85 (4.5 x 1.30, once: not 4.5 x 1.69)")
	r.check(PlayerForm.grade_of(5.84) == 0 and PlayerForm.grade_of(5.85) == PlayerForm.GOOD and PlayerForm.grade_of(4.6) == 0, "4: +4.6 used to be GOOD, now it's NORMAL; +5.85 is")
	r.check(PlayerForm.grade_of(-3.0) == PlayerForm.BAD and PlayerForm.grade_of(-2.99) == 0, "7/41: BAD (-3) is where it was")
	r.check(PlayerForm.HOT_AT == 3 and PlayerForm.VERY_HOT_AT == 4 and PlayerForm.HOT_HOLD == 2 and PlayerForm.VERY_HOT_HOLD == 4 and PlayerForm.FORM_GAMES == 5,
		"5/43: the runs and how long a star holds are unchanged (harder to earn, not quicker to lose)")
	var p := AttrBench.player({"sho": 10.0}, false)
	p.heat = 2
	r.check(is_equal_approx(Attributes.hot_bonus(p), 1.0) and is_equal_approx(Attributes.effective(p, "sho"), 11.0), "the bonuses unchanged: two stars +1.0, past 10")
	var src := ""
	for f in ["res://src/core/player_form.gd", "res://src/core/career.gd", "res://src/core/game_sim.gd", "res://src/core/difficulty.gd"]:
		if FileAccess.file_exists(f):
			src += FileAccess.get_file_as_string(f)
	r.check(src.count("HOT_STAR_ACQUISITION_MULTIPLIER") >= 2 and not src.contains("CPU_HOT") and not src.contains("USER_HOT"), "17: one shared value, no user / CPU copies")
	r.check(not FileAccess.get_file_as_string("res://src/core/player_form.gd").contains("Difficulty"), "11/45: no difficulty setting touches how anyone heats up")

## CPU players: graded in every game (theirs and yours, played or simulated), the same bonus.
func _everyone() -> void:
	var c := Career.new_game("GWU", "H", "B", 7001)
	Game.career = c
	c.queue.clear()
	while c.has_game():
		c.sim_my_game()
	var graded := c.form_rows.keys()
	r.check(graded.size() >= 2 and graded.has(c.school) and graded.any(func(id): return id != c.school), "1/9/20: your game grades both sevens")
	c.end_week()
	var cpu_graded := 0
	for id in c.teams:
		if id != c.school and (c.teams[id] as PoloTeam).starters().any(func(q: PoloPlayer): return not q.form.is_empty()):
			cpu_graded += 1
	r.check(cpu_graded >= 20, "10/21: the other schools' players are graded from their own simulated games (%d schools)" % cpu_graded)
	var cpu: PoloPlayer = c.teams.values().filter(func(t): return t.id != c.school)[0].starters()[1]
	var keeper: PoloPlayer = c.teams.values().filter(func(t): return t.id != c.school)[0].starters()[0]
	var before := cpu.attrs.duplicate()
	cpu.heat = 2
	keeper.heat = 1
	r.check(is_equal_approx(Attributes.hot_bonus(cpu), 1.0) and is_equal_approx(Attributes.effective(cpu, "sho"), Development.eff_value(cpu, "sho") + 1.0)
		and is_equal_approx(Attributes.effective(keeper, "blk"), Development.eff_value(keeper, "blk") + 0.5), "10/11/13: a CPU field player +1.0, a CPU keeper +0.5 (the same Attributes.play_value)")
	r.check(cpu.attrs == before, "14: nothing permanent")
	cpu.heat = 0
	keeper.heat = 0
	# a CPU keeper earns stars from his own saves, the same rule
	var k := keeper
	k.form = []   # (a clean run: his own week's grades, and any CPU coaching, left out)
	k.heat_bonus = 0.0
	var t: PoloTeam = c.teams.values().filter(func(tt): return tt.id != c.school)[0]
	for i in 3:
		var line := {k.id: {"gk": true, "sv": 20, "ga": 0}}
		PlayerForm.grade_team(t, line, {})
	r.check(k.heat == 1, "9: a CPU keeper heats up on three big games like anyone")
	_cpu_coach(c)

## CPU coaches: your coaching events' HOT STAR help, for their players, on the same conditions.
func _cpu_coach(c: Career) -> void:
	var t: PoloTeam = c.teams.values().filter(func(q): return q.id != c.school)[1]
	var young: PoloPlayer = t.starters().slice(1).filter(func(q: PoloPlayer): return true)[0]
	var cold: PoloPlayer = t.starters()[2]
	young.year = 2
	young.heat_bonus = 0.0
	var star := {young.id: {"g": 4, "sh": 5}}
	var got := {}
	for w in 60:
		young.heat_bonus = 0.0
		c.week = w
		var res := CoachEvents.cpu_coach(c, t, star)
		if not res.is_empty():
			got[String(res.id)] = is_equal_approx(young.heat_bonus, CoachEvents.HOT.star_praise)
	r.check(got.get("star_in_making", false) and got.size() == 1, "CPU: A STAR IN THE MAKING's +HOT STAR PROGRESS for a young CPU scorer")
	var n := 0
	for w in 60:
		cold.form = [-1, -1, 0]
		c.week = w
		if String(CoachEvents.cpu_coach(c, t, {cold.id: {"g": 0, "sh": 6}}).get("id", "")) == "rough_night":
			n += 1
			r.check(cold.form == [0, 0, 0], "CPU: A ROUGH NIGHT forgives his last two BAD grades")
	r.check(n > 0 and n < 30, "CPU: drawn at about your rate when it fits (%d of 60, ~%d expected)" % [n, roundi(60 * CoachEvents.CPU_DRAW.rough_night)])
	young.heat_bonus = 0.0
	var mine: PoloPlayer = c.team().starters()[1]
	mine.heat_bonus = 0.0
	for w in 60:
		c.week = w
		CoachEvents.cpu_coach(c, c.team(), {mine.id: {"g": 4, "sh": 5}})
	r.check(mine.heat_bonus == 0.0, "CPU: your team's help is still only your coaching events")

## HOT STAR TESTING: CPU schools, progress, the multiplier, the thresholds; nothing real touched.
func _lab() -> void:
	var c := Career.new_game("GWU", "L", "B", 7101)
	c.queue.clear()
	Game.career = c
	Game.settings.dev_mode = true
	Game.goto("hot_star_lab")
	for i in 4:
		await r.get_tree().process_frame
	var lab = Game.current_screen
	r.check(lab.schools.size() == 30 and lab.schools[0] == c.team() and not lab.cpu(), "31: every school to pick, yours first")
	lab.select_school(5)
	await r.get_tree().process_frame
	var cpu_team: PoloTeam = lab.schools[5]
	var real: PoloPlayer = cpu_team.find_id(int(lab.ids[0]))
	var real_attrs := real.attrs.duplicate()
	var real_form := real.form.duplicate()
	r.check(lab.cpu() and lab.source == cpu_team and lab.ids.size() == cpu_team.roster.size(), "31/32: a CPU school and its whole roster")
	var rows := str(lab.rows())
	r.check(rows.contains("(CPU)") and rows.contains("HOT PROGRESS") and rows.contains("1.30x ORIGINAL (GOOD +5.85)"), "34/35: CPU, his Hot progress, and the real 1.30x on the panel")
	lab.select(1)
	var p: PoloPlayer = lab.player()
	var ok := true
	for k in Attributes.keys_for(p):
		ok = ok and rows.length() > 0
	lab.set_stars(2)
	r.check(is_equal_approx(Attributes.effective(p, Attributes.keys_for(p)[0]) - Development.eff_value(p, Attributes.keys_for(p)[0]), 1.0), "33: a CPU player's effective attributes at two stars")
	var first: Dictionary = lab.test_star(1)
	r.check(first.ok and int(first.games) == PlayerForm.HOT_AT, "36: 1ST-STAR THRESHOLD: three GOOD games, a game under +5.85 doesn't count")
	var second: Dictionary = lab.test_star(2)
	r.check(second.ok and int(second.games) == 1, "36: 2ND-STAR THRESHOLD: a fourth GOOD game in the run")
	lab.reset_state()
	lab.add_good_game()
	r.check(lab.player().form.size() >= 1 and int(lab.player().form[lab.player().form.size() - 1]) == PlayerForm.GOOD, "+1 GOOD GAME goes through push_grade")
	lab.preview_stars(2)
	for i in 2:
		await r.get_tree().process_frame
	r.check(HotFire.level_of(lab.play.ball.shooter) == 2 or lab.player().is_keeper(), "23-25: a CPU player's shot at two stars (the same flaming shot / ring)")
	r.check(real.attrs == real_attrs and real.form == real_form, "37: the real CPU player untouched")
	Game.settings.dev_mode = false
	Game.goto("title")
	await r.get_tree().process_frame
	Game.career = null

## Seasons at each multiplier, the same seeds: per team-season, first stars (NORMAL -> HOT) and
## second (HOT -> VERY HOT) earned, and the share of starter-games played HOT or better.
func measure(seasons: int, mults: Array, seeds: Array = [811, 812]) -> Array:
	var out: Array = []
	for m in mults:
		PlayerForm.acquisition = float(m)
		var first := 0
		var second := 0
		var cpu_first := 0
		var games := 0
		var hot_games := 0
		var team_seasons := 0
		for sd in seeds:
			var c := Career.new_game("GWU", "M", "M", int(sd))
			Game.career = c
			for s in seasons:
				var label := c.season_label()
				var guard := 0
				while c.season_label() == label and guard < 40:
					guard += 1
					c.queue.clear()
					var heat := {}
					for id in c.teams:
						for p: PoloPlayer in (c.teams[id] as PoloTeam).roster:
							heat[p.id * 1000 + id.hash() % 1000] = p.heat
					while c.has_game():
						c.sim_my_game()
					c.end_week()
					for id in c.teams:
						for p: PoloPlayer in (c.teams[id] as PoloTeam).starters():
							var was := int(heat.get(p.id * 1000 + id.hash() % 1000, 0))
							if p.heat > was:
								if was == 0:
									first += 1
									if id != c.school:
										cpu_first += 1
								else:
									second += 1
							if not p.form.is_empty():
								games += 1
								hot_games += 1 if p.heat > 0 else 0
					if c.phase == "cuts":
						c.phase = "done"
				team_seasons += c.teams.size()
		out.append({"mult": m, "first": float(first) / team_seasons, "second": float(second) / team_seasons, "cpu_first": cpu_first,
			"hot_rate": float(hot_games) / maxf(1.0, games)})
		print("    x%.2f: per team-season %.2f first stars, %.2f second; HOT or better %.1f%% of starter-weeks" % [m, out[-1].first, out[-1].second, out[-1].hot_rate * 100.0])
	PlayerForm.acquisition = PlayerForm.HOT_STAR_ACQUISITION_MULTIPLIER
	return out

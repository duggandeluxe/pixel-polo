extends RefCounted
## THE ROSTER GENERATION & RATINGS UPDATE: all 30 rosters made before PICK YOUR SCHOOL (the
## dynasty setup) and never made again, OFFENSE / DEFENSE / GOALKEEPING from the starters'
## attributes, the overall's star formula untouched, the Road to Glory tiers fixed. The numbered
## checks follow the spec's REQUIRED TESTING list.
##   godot --headless --path game -- --test ratings

const DIR := "user://test_ratings/"

var r   # the test runner

func run(runner) -> void:
	load("res://src/ui/screens/new_career.gd").start_filter = Colleges.D1   # (the Road to Glory's thirty; --test divisions has the rest)
	r = runner
	print("roster generation & ratings")
	Store.reset_for_tests()
	Game.progress = Progression.fresh()
	Game.setup = null
	_full_rosters()
	_formulas()
	await _picker_and_start()
	await _back_navigation()
	_setup_file()
	_tiers()
	_lineup_change()
	_upgrade()
	_existing_save()
	Game.setup = null
	Game.career = null
	Game.progress = null
	Game.goto("title")
	await r.get_tree().process_frame

# ------------------------------------------------------------------ helpers
## Every team's players and ratings, to compare two moments: {id: [ratings, [[pid, name, pos,
## year, attrs, pots]...], starter ids]}.
func _snap(teams: Dictionary) -> Dictionary:
	var out := {}
	for id in teams:
		var t: PoloTeam = teams[id]
		var players: Array = t.roster.map(func(p: PoloPlayer): return [p.id, p.first + " " + p.last, p.pos, p.year, p.attrs.duplicate(), p.attr_pot.duplicate(), p.stars])
		out[id] = [[t.overall_display(), t.offense_display(), t.defense_display(), t.goalkeeping_display()], players, t.starters().map(func(p): return p.id)]
	return out

## The six field starters' average of `key`.
func _avg(t: PoloTeam, key: String) -> float:
	var field := t.starters().filter(func(p: PoloPlayer): return not p.is_keeper())
	var s := 0.0
	for p: PoloPlayer in field:
		s += Attributes.value(p, key)
	return s / field.size()

func _expect(t: PoloTeam) -> Array:
	var off := (_avg(t, "sho") * 0.40 + _avg(t, "pas") * 0.35 + _avg(t, "str") * 0.25) / 10.0 * 99.0
	var dfn := (_avg(t, "dfn") * 0.65 + _avg(t, "str") * 0.35) / 10.0 * 99.0
	var gk := t.starters()[0]
	var kp := (Attributes.value(gk, "blk") * 0.35 + Attributes.value(gk, "lun") * 0.30 + Attributes.value(gk, "leg") * 0.20 + Attributes.value(gk, "com") * 0.15) / 10.0 * 99.0
	return [clampi(roundi(snappedf(off, 0.000001)), 0, 99), clampi(roundi(snappedf(dfn, 0.000001)), 0, 99), clampi(roundi(snappedf(kp, 0.000001)), 0, 99)]

## The overall by the established star formula, worked out here from the starters' stars.
func _star_ovr(t: PoloTeam) -> int:
	var total := 0.0
	for p: PoloPlayer in t.starters():
		total += p.stars
	return PoloTeam.display_ovr(PoloTeam.OVR_ZERO + PoloTeam.OVR_PER_STAR * total / PoloTeam.STARTERS)

# ------------------------------------------------------------------ T30, T41
func _full_rosters() -> void:
	var c := Game.dynasty_setup()
	r.check(c.teams.size() == 54 and c.school == "", "T30: a setup has all 54 teams (a dynasty keeps the divisions it plays) and no school picked yet")
	var bad: Array = []
	var ids := {}
	var dup := false
	for id in c.teams:
		var t: PoloTeam = c.teams[id]
		var seven := t.starters()
		var ok := t.roster.size() == Career.ROSTER_MAX + Career.BENCH_MAX and seven.size() == PoloTeam.STARTERS and seven[0].is_keeper() \
			and seven.slice(1).all(func(p): return not p.is_keeper()) and t.roster.all(func(p): return not p.attrs.is_empty())
		for v in [t.offense_display(), t.defense_display(), t.goalkeeping_display(), t.overall_display()]:
			ok = ok and v > 0 and v <= 99
		if not ok:
			bad.append(id)
		for p in t.roster:
			dup = dup or ids.has(p.id)
			ids[p.id] = true
	r.check(bad.is_empty(), "T30/T41: every team has a full roster, seven starters with a keeper, and all four ratings %s" % str(bad))
	r.check(not dup and ids.size() == 54 * (Career.ROSTER_MAX + Career.BENCH_MAX), "T41: no player twice (%d players: every program's seven and its bench)" % ids.size())
	var rated := true
	for id in c.teams:
		rated = rated and _expect(c.teams[id]) == [c.teams[id].offense_display(), c.teams[id].defense_display(), c.teams[id].goalkeeping_display()]
		rated = rated and c.teams[id].overall_display() == _star_ovr(c.teams[id])
	r.check(rated, "T30: every team's OFF, DEF and GK are its starters' weighted attributes, its OVR the star formula")
	# stronger programs still make stronger players, on the whole
	var top := 0.0
	var bottom := 0.0
	var order := Progression.by_rating()
	for i in 5:
		top += (c.teams[order[i].short] as PoloTeam).team_overall(false)
		bottom += (c.teams[order[order.size() - 1 - i].short] as PoloTeam).team_overall(false)
	for s in order:
		var tm: PoloTeam = c.teams[s.short]
		print("    %-6s base %d  OVR %d  OFF %d  DEF %d  GK %d" % [s.short, int(s.ovr), tm.overall_display(), tm.offense_display(), tm.defense_display(), tm.goalkeeping_display()])
	r.check(top > bottom + 5 * 10.0, "T17: the five strongest programs' rosters are well above the five weakest (%.1f vs %.1f)" % [top / 5, bottom / 5])

# ------------------------------------------------------------------ T31-T34
func _formulas() -> void:
	var c := Career.new_setup(77)
	var t: PoloTeam = c.teams["CULA"]
	var field := t.starters().filter(func(p: PoloPlayer): return not p.is_keeper())
	r.check(field.size() == 6, "T31: six field starters")
	for p: PoloPlayer in field:
		p.attrs["sho"] = 8.5
		p.attrs["pas"] = 8.0
		p.attrs["str"] = 8.2
	r.check(t.offense_display() == 82, "T31: shooting 8.5, passing 8.0, strength 8.2 -> OFFENSE 82 (%d)" % t.offense_display())
	for p: PoloPlayer in field:
		p.attrs["dfn"] = 8.8
		p.attrs["str"] = 8.1
	r.check(t.defense_display() == 85, "T32: defense 8.8, strength 8.1 -> DEFENSE 85 (%d)" % t.defense_display())
	# uneven players: it's the average of the six
	var vals := [9.0, 8.0, 8.5, 9.0, 8.0, 8.5]
	for i in 6:
		field[i].attrs["sho"] = vals[i]
	r.check(absf(t.offense_score() - (8.5 * 0.40 + 8.0 * 0.35 + 8.1 * 0.25)) < 0.0001, "T31: the field starters' average, player by player")
	var gk: PoloPlayer = t.starters()[0]
	gk.attrs["blk"] = 9.0
	gk.attrs["lun"] = 8.0
	gk.attrs["leg"] = 8.0
	gk.attrs["com"] = 7.0
	r.check(t.goalkeeping_display() == 81, "T33: blocking 9, lunge 8, legs 8, communication 7 -> GOALKEEPING 81 (%d)" % t.goalkeeping_display())
	r.check(PoloTeam.rating_99(10.0) == 99 and PoloTeam.rating_99(11.0) == 99 and PoloTeam.rating_99(0.0) == 0 and PoloTeam.rating_99(-1.0) == 0, "T31: clamped to 0..99")
	# the overall: the star formula, untouched by any of this
	for p: PoloPlayer in t.starters():
		Attributes.sync(p)
	r.check(t.overall_display() == _star_ovr(t), "T34: OVR is still the starters' star formula (%d)" % t.overall_display())
	var avg3 := roundi((t.offense_display() + t.defense_display() + t.goalkeeping_display()) / 3.0)
	r.check(t.team_overall(false) == PoloTeam.ovr_for_stars(t.starters().reduce(func(a, p): return a + p.stars, 0.0) / 7.0), "T34: not an average of OFF/DEF/GK (that'd be %d)" % avg3)
	# HEAT UP moves the overall only
	var before := [t.offense_display(), t.defense_display(), t.goalkeeping_display()]
	var hot: PoloPlayer = field[0]
	var ovr0 := t.overall_display()
	hot.heat = 2
	r.check([t.offense_display(), t.defense_display(), t.goalkeeping_display()] == before, "T22: HEAT UP never moves OFF, DEF or GK")
	r.check(t.overall_display() > ovr0 or ovr0 == 99, "T22: ...while the overall keeps its HEAT UP stars (%d -> %d)" % [ovr0, t.overall_display()])
	hot.heat = 0

# ------------------------------------------------------------------ T35
func _picker_and_start() -> void:
	Game.setup = null
	Game.career = null
	Game.progress = Progression.fresh()
	Game.goto("new_career")
	for _i in 3:
		await r.get_tree().process_frame
	var scr = Game.current_screen
	r.check(scr.preview == Game.setup and scr.preview != null, "T30: the picker shows the dynasty setup's own teams")
	var id: String = Game.progress.picker_groups()[0].ids[0]
	scr._pick(id)
	await r.get_tree().process_frame
	var t: PoloTeam = scr.preview.teams[id]
	var card: Control = scr.cards[id]
	var shown := [float(card.find_child("StarsOFF", true, false).get_meta("stars")), float(card.find_child("StarsDEF", true, false).get_meta("stars"))]
	var want := [scr.card_stars(t.offense_display()), scr.card_stars(t.defense_display())]
	r.check(shown == want, "T23: the card shows the generated roster's OFF and DEF %s" % str(want))
	var snap := _snap(scr.preview.teams)
	var setup: Career = Game.setup
	scr.step = 1
	scr._render()
	scr._start()
	await r.get_tree().process_frame
	var c: Career = Game.career
	r.check(c != null and c == setup and c.school == id, "T35/T24: the career is the setup itself, not made again")
	var after := _snap(c.teams)
	# (the other programs are the same players; their attributes can already have moved: the
	# season starts with any of this week's games before yours played, and their XP spent)
	var who := func(rows: Array) -> Array: return rows.map(func(x): return [x[0], x[1], x[2], x[3], x[5]])
	var same := true
	for tid in snap:
		if tid == id or not after.has(tid):
			continue   # (yours; and a division this Division I dynasty left out)
		same = same and who.call(after[tid][1]) == who.call(snap[tid][1])
	r.check(same, "T35: every other team is the same players the picker showed (nobody made again)")
	var mine: Array = after[id]
	var before_mine: Array = snap[id]
	r.check(mine[0] == before_mine[0] and _sorted(mine[2]) == _sorted(before_mine[2]), "T35/T25: your team's OVR, OFF, DEF, GK and seven starters are what the picker showed %s" % str(mine[0]))
	r.check(mine[1] == before_mine[1] and c.team().roster.size() == c.roster_cap(id), "T35: your whole roster, bench too, exactly the one the picker showed (%d)" % c.team().roster.size())
	var ids := {}
	var dup := false
	for tid in c.teams:
		for p in c.teams[tid].roster:
			dup = dup or ids.has(p.id)
			ids[p.id] = true
	r.check(not dup, "T29: no player twice once the career starts")
	r.check(Game.setup == null, "T4: the setup is used up: the next new dynasty gets new rosters")
	Game.goto("title")
	await r.get_tree().process_frame
	Game.career = null

# ------------------------------------------------------------------ T36
func _back_navigation() -> void:
	Game.setup = null
	Game.goto("new_career")
	for _i in 3:
		await r.get_tree().process_frame
	var first: Dictionary = _snap(Game.current_screen.preview.teams)
	var coach := [Game.current_screen.first, Game.current_screen.last]
	Game.current_screen._pick("HURST")
	Game.current_screen._pick("CULA")
	Game.current_screen.on_back()   # (back to the careers screen)
	for _i in 3:
		await r.get_tree().process_frame
	Game.goto("new_career")
	for _i in 3:
		await r.get_tree().process_frame
	r.check(_snap(Game.current_screen.preview.teams) == first, "T36: back out and in again: same players, attributes, ratings and starters")
	r.check([Game.current_screen.first, Game.current_screen.last] == coach, "T36: ...and the same suggested coach")
	# the game closed and opened again: the setup comes back from its seed, identical
	var seed_value := Game.setup_seed
	Game.setup = null
	Game.setup_seed = 0
	var again := Career.new_setup(seed_value, [1, 2, 3])
	r.check(_snap(again.teams) == first, "T36: the same seed makes exactly the same rosters")
	Game.goto("title")
	await r.get_tree().process_frame

## The setup's seed is saved, so closing the game can't reroll it either.
func _setup_file() -> void:
	var saved_dir := Game.save_dir
	DirAccess.make_dir_recursive_absolute(DIR)
	Game.save_dir = DIR
	Game.test_mode = false
	Game.setup = null
	if FileAccess.file_exists(DIR + Game.SETUP_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(DIR + Game.SETUP_PATH))
	var a := _snap(Game.dynasty_setup().teams)
	var seed_a := Game.setup_seed
	Game.setup = null   # (the game closed)
	var b := _snap(Game.dynasty_setup().teams)
	r.check(FileAccess.file_exists(DIR + Game.SETUP_PATH) and Game.setup_seed == seed_a and a == b, "T27: reopened, the saved setup brings back the same players")
	Game.clear_setup()
	r.check(not FileAccess.file_exists(DIR + Game.SETUP_PATH), "T4: a used-up setup's file is gone")
	Game.test_mode = true
	Game.save_dir = saved_dir
	Game.setup = null

# ------------------------------------------------------------------ T37
func _tiers() -> void:
	var want := Progression.fresh()
	var ok := true
	var orders := {}
	for seed_value in [1, 2, 3, 4, 5]:
		var c := Career.new_setup(seed_value)
		var p := Progression.fresh()
		ok = ok and p.tiers == want.tiers and _sorted(p.unlocked) == _sorted(want.unlocked)
		var g := p.picker_groups(c.teams)
		var g0 := want.picker_groups()
		for i in g.size():
			ok = ok and _sorted(g[i].ids) == _sorted(g0[i].ids)
		orders[str(g[0].ids)] = true
	r.check(ok, "T37: five setups, the same five open schools and the same tiers every time")
	r.check(_sorted(want.unlocked) == _sorted(Progression.by_rating().slice(25).map(func(s): return String(s.short))), "T16: the open five are the five lowest base program ratings")

func _sorted(a: Array) -> Array:
	var b := a.duplicate()
	b.sort()
	return b

# ------------------------------------------------------------------ T38
func _lineup_change() -> void:
	var c := Career.new_game("CULA", "A", "B", 12)
	var t := c.team()
	r.check(t.lineup.size() == PoloTeam.LINEUP_SPOTS.size(), "T38: your team has a lineup with a bench")
	var gk0 := t.goalkeeping_display()
	# a field sub into a field starter's place
	var sub_i := -1
	for i in range(PoloTeam.STARTERS, t.lineup.size()):
		var q := t.find_id(int(t.lineup[i]))
		if q != null and not q.is_keeper():
			sub_i = i
	var sub := t.find_id(int(t.lineup[sub_i]))
	var out := t.find_id(int(t.lineup[2]))
	t.lineup[2] = sub.id
	t.lineup[sub_i] = out.id
	r.check(t.starters().has(sub) and not t.starters().has(out), "T38: the sub starts")
	r.check(_expect(t) == [t.offense_display(), t.defense_display(), t.goalkeeping_display()] and t.overall_display() == _star_ovr(t), "T38: OFF, DEF and OVR follow the new seven")
	r.check(t.goalkeeping_display() == gk0, "T38: GK unchanged by a field change")
	# the backup keeper in goal
	var bk_i := -1
	for i in range(PoloTeam.STARTERS, t.lineup.size()):
		var q := t.find_id(int(t.lineup[i]))
		if q != null and q.is_keeper():
			bk_i = i
	var bk := t.find_id(int(t.lineup[bk_i]))
	var gk := t.find_id(int(t.lineup[0]))
	t.lineup[0] = bk.id
	t.lineup[bk_i] = gk.id
	r.check(t.starters()[0] == bk and t.goalkeeping_display() == _expect(t)[2], "T38: a new starting keeper: GK is his (%d, was %d)" % [t.goalkeeping_display(), gk0])

# ------------------------------------------------------------------ T39
func _upgrade() -> void:
	var c := Career.new_game("HURST", "A", "B", 8)
	var t := c.team()
	var p: PoloPlayer = null
	for q: PoloPlayer in t.starters():
		if not q.is_keeper() and Attributes.room(q, "sho") >= 1.0:
			p = q
			break
	r.check(p != null, "T39: a starter with room to shoot better")
	if p == null:
		return
	var off0 := t.offense_score()
	var def0 := t.defense_display()
	var sho0 := Attributes.value(p, "sho")
	p.tokens += 1
	r.check(Development.spend(p, "sho"), "T39: a token spent on SHOOTING")
	r.check(Attributes.value(p, "sho") == sho0 + 1.0, "T39: his shooting goes up a point")
	r.check(absf(t.offense_score() - off0 - 0.40 / 6.0) < 0.0001 and t.offense_display() == _expect(t)[0], "T39: OFFENSE goes up by his share (%.3f -> %.3f)" % [off0, t.offense_score()])
	r.check(t.defense_display() == def0, "T39: DEFENSE doesn't move")
	r.check(t.overall_display() == _star_ovr(t), "T39: OVR is the star formula with his new stars")

# ------------------------------------------------------------------ T40
func _existing_save() -> void:
	var saved_dir := Game.save_dir
	var saved_slot := Game.slot
	DirAccess.make_dir_recursive_absolute(DIR)
	Game.save_dir = DIR
	Game.test_mode = false
	Game.career = Career.new_game("WAGN", "Old", "Save", 21)
	Game.career.queue.clear()
	for _i in 2:
		if Game.career.has_game():
			Game.career.sim_my_game()
		Game.career.end_week()
	Game.slot = 1
	Game.save_career()
	var before := _snap(Game.career.teams)
	# a save from before the update: no OFF/DEF/GK snapshot in its season
	var d = JSON.parse_string(FileAccess.get_file_as_string(Game.slot_path(1)))
	d.season.erase("shown")
	var f := FileAccess.open(Game.slot_path(1), FileAccess.WRITE)
	f.store_string(JSON.stringify(d))
	f.close()
	Game.career = null
	r.check(Game.load_career(1), "T40: the save loads")
	var after := _snap(Game.career.teams)
	var players_same := true
	for id in before:
		players_same = players_same and after[id][1] == before[id][1] and after[id][2] == before[id][2]
	r.check(players_same, "T40: the same players, attributes and starters; nothing made again")
	var rated := true
	for id in Game.career.teams:
		var t: PoloTeam = Game.career.teams[id]
		rated = rated and _expect(t) == [t.offense_display(), t.defense_display(), t.goalkeeping_display()]
	r.check(rated, "T40: OFF, DEF and GK read from the loaded players")
	Game.test_mode = true
	Game.save_dir = saved_dir
	Game.slot = saved_slot
	Game.career = null
	for fn in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(DIR + fn))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(DIR))

extends RefCounted
## The Division II & III expansion: --test divisions. DivisionChecks' groups, then the master table
## typed out again here, independently of the data, and the shapes and balance a season shows.

## id: name, conference, OVR, OFF, DEF, GK, home pool (the spec's table).
const TABLE := {
	"D2_01": ["La Mirada Falcons", "WWPA", 65, 3.0, 3.0, 3.0], "D2_02": ["Irvine Goldhawks", "WWPA", 72, 3.5, 3.5, 3.5],
	"D2_03": ["Fresno Firebirds", "WWPA", 60, 2.5, 2.5, 2.5], "D2_04": ["Erie Golden Sentinels", "WWPA", 66, 3.0, 3.0, 3.0],
	"D2_05": ["Lebanon Clawcats", "WWPA", 67, 3.0, 3.0, 3.0], "D2_06": ["Salem Sabertooths", "WWPA", 68, 3.5, 3.0, 3.0],
	"D2_07": ["Merced Lynx", "WWPA", 58, 2.5, 2.5, 2.0], "D3_01": ["Pasadena Woodchucks", "SCIAC", 46, 2.0, 2.0, 1.5],
	"D3_02": ["Thousand Oaks Royals", "SCIAC", 66, 3.0, 3.0, 3.0], "D3_03": ["Orange Pumas", "SCIAC", 64, 3.0, 2.5, 3.0],
	"D3_04": ["Claremont Bucks", "SCIAC", 77, 3.5, 4.0, 4.0], "D3_05": ["Los Angeles Wildcats", "SCIAC", 65, 3.0, 3.0, 3.0],
	"D3_06": ["Claremont Sagebirds", "SCIAC", 74, 3.5, 3.5, 3.5], "D3_07": ["La Verne Jaguars", "SCIAC", 61, 2.5, 2.5, 2.5],
	"D3_08": ["Redlands Mastiffs", "SCIAC", 67, 3.0, 3.5, 3.0], "D3_09": ["Whittier Bards", "SCIAC", 70, 3.0, 3.5, 3.5],
	"D3_10": ["Rock Island Norsemen", "MPSFE", 69, 3.5, 3.0, 3.0], "D3_11": ["Sherman Wallabies", "MPSFE", 62, 2.5, 3.0, 2.5],
	"D3_12": ["New London Dromedaries", "MPSFE", 54, 2.0, 2.5, 2.5], "D3_13": ["Baltimore Bluewings", "MPSFE", 71, 3.5, 3.5, 3.0],
	"D3_14": ["Erie Cougars", "MPSFE", 59, 2.5, 2.5, 2.5], "D3_15": ["Washington Statesmen", "MPSFE", 49, 2.0, 2.0, 2.0],
	"D3_16": ["Norton Lionhearts", "MPSFE", 44, 1.5, 2.0, 1.5], "D3_17": ["Cambridge Mechanics", "NEWPC", 65, 3.0, 3.0, 3.0],
}

func run(r) -> void:
	# (all of this is the lower divisions' content: checked with them switched on, as they'll be)
	Colleges.lower_divisions = true
	_content(r)
	Colleges.lower_divisions = Colleges.ENABLE_LOWER_DIVISIONS
	_hibernation(r)

func _content(r) -> void:
	for g in DivisionChecks.GROUPS:
		print("-- %s" % g)
		for e in DivisionChecks.run(g):
			r.check(bool(e.ok), "%s: %s" % [g, e.text])
	print("-- the master table")
	for id in TABLE:
		var row: Array = TABLE[id]
		var s := Colleges.school(id)
		r.check(String(s.get("name", "")) == row[0] and String(s.get("conf", "")) == row[1] and int(s.get("ovr", 0)) == row[2]
			and is_equal_approx(float(s.get("t_off", 0)), row[3]) and is_equal_approx(float(s.get("t_def", 0)), row[4]) and is_equal_approx(float(s.get("t_gk", 0)), row[5]), "table: %s" % row[0])
	print("-- several seasons, every configuration")
	for cfg in DivisionChecks.CONFIGS:
		for sd in 2:
			var c := DivisionChecks.sandbox("D3_17" if cfg[1].has(3) else "CULA", cfg[1], 70 + sd)
			DivisionChecks.sim_season(c)
			var bad := DivisionChecks.season_problems(c)
			r.check(bad.is_empty(), "%s seed %d: a whole season %s" % [cfg[0], sd, "" if bad.is_empty() else String(bad[0])])
	_measure(r)
	_store(r)

## What a league with everyone in it looks like after a few seasons: the numbers to judge it by.
func _measure(r) -> void:
	var top20 := {1: 0, 2: 0, 3: 0}
	var d2_wins := 0
	var d2_titles := 0
	var seasons := 0
	var weak_upsets := [0, 0]
	var bucks := [0, 0]
	for sd in 4:
		var c := DivisionChecks.sandbox("CULA", [1, 2, 3], 80 + sd)
		DivisionChecks.sim_season(c)
		seasons += 1
		for id in (Poll.latest(c).ranks as Array).slice(0, 20):
			top20[Colleges.division_of(id)] += 1
		var nat := String(c.season.get("champion", ""))
		if Colleges.division_of(nat) == 2:
			d2_titles += 1
		for rd in c.schedule:
			for g in rd.games:
				if g.r == null:
					continue
				var w := Schedule.winner(g)
				var l := Schedule.loser(g)
				if rd.kind.begins_with("nat") and Colleges.division_of(w) == 2 and not g.has("k"):
					d2_wins += 1
				for pair in [["D3_16", 85.0]]:
					var o: String = g.h if g.a == pair[0] else (g.a if g.h == pair[0] else "")
					if o != "" and (c.teams[o] as PoloTeam).base_ovr() >= 85:
						weak_upsets[0] += 1
						weak_upsets[1] += 1 if w == pair[0] else 0
				if (g.h == "D3_04" or g.a == "D3_04") and Colleges.division_of(g.a if g.h == "D3_04" else g.h) == 1:
					bucks[0] += 1
					bucks[1] += 1 if w == "D3_04" else 0
		print("  NCSA %s | D2 %s | D3 %s" % [c.teams[nat].name, c.teams[c.season.d2_champ].name, c.teams[Schedule.winner(Schedule.d3_game(c.schedule, "d3_final"))].name])
	print("  Top 20 over %d seasons by division: %s; D2 NCSA wins %d, titles %d; Norton v 85+: %s; Bucks v Division I: %s" % [seasons, str(top20), d2_wins, d2_titles, str(weak_upsets), str(bucks)])
	r.check(int(top20[1]) > int(top20[2]) + int(top20[3]), "Division I holds most of the Top 20")

func _store(r) -> void:
	Store.reset_for_tests()
	r.check(not Store.division_access("div2") and not Store.division_access("div3"), "no pack owned to begin with")
	r.check(not Game.progression().is_unlocked("D2_01") and not Game.progression().is_unlocked("D3_04"), "unowned schools are locked, whatever else is open")
	Store.all_teams = true
	r.check(not Game.progression().is_unlocked("D2_01"), "ALL 30 TEAMS doesn't open a pack")
	Store.all_teams = false
	Store._grant("division2_pack", "purchase", "t-1")
	r.check(Store.division_access("div2") and not Store.division_access("div3") and Store.vault == 0, "the Division II pack alone: Division II, no coins")
	r.check(Game.progression().is_unlocked("D2_01") and not Game.progression().is_unlocked("D3_04"), "...and only its schools open")
	Store.reset_for_tests()
	Store._grant("pro_unlock", "purchase", "t-2")
	r.check(Store.division_access("div2") and Store.division_access("div3") and Store.vault == 500, "Pixel Polo +: both packs and its 500 coins")
	Store._grant("pro_unlock", "restored", "t-3")
	r.check(Store.vault == 500, "...the coins once")
	Store.reset_for_tests()
	r.check(Store.DIVISIONS.div2.product in Store.PRODUCTS and Store.DIVISIONS.div3.product in Store.PRODUCTS, "the packs are real one-time products")
	var ok := Game.start_career("D2_02", "A", "B", 91, [1, 2])
	r.check(not ok, "an unowned school can't start a career")
	Store._grant("division2_pack", "purchase", "t-4")
	ok = Game.start_career("D2_02", "A", "B", 92, [1, 2, 3])
	r.check(ok and Game.career.divisions == [1, 2] and Game.career.teams.size() == 37, "a career only gets the packs you own")
	Store.reset_for_tests()

## THE HIBERNATION (Colleges.ENABLE_LOWER_DIVISIONS off): Division I alone, nothing deleted.
func _hibernation(r) -> void:
	print("-- hibernated")
	Colleges.lower_divisions = false
	r.check(not Colleges.ENABLE_LOWER_DIVISIONS, "the switch is off: a Division I game")
	Store.reset_for_tests()
	Store._grant("pro_unlock", "purchase", "h-1")
	Store._grant("division2_pack", "purchase", "h-2")
	r.check(not Store.division_owned(2) and not Store.division_owned(3) and Store.listed_divisions().is_empty() and not Store.division_for_sale("div2"),
		"packs bought or with Pixel Polo +: not owned, sold or listed while hibernated")
	r.check("div2" in Store.packs and Store.pro, "...the purchases themselves are kept")
	r.check(not Store.pro_perks().any(func(x): return String(x).contains("Division")) and Store.PRO_PERKS.size() == 4, "Pixel Polo +'s card leaves the packs out (the list itself is kept)")
	r.check(not Game.progression().is_unlocked("D2_01") and not Game.progression().is_unlocked("D3_04"), "no lower-division school opens")
	var open: Array = Colleges.SCHOOLS.filter(func(s): return Game.progression().is_unlocked(String(s.short)))
	var ok := not open.is_empty() and Game.start_career(String(open[0].short), "A", "B", 93, [1, 2, 3])
	r.check(ok and Game.career.divisions == [1] and Game.career.teams.size() == 30, "a new career is Division I's thirty, whatever's asked")
	r.check(not Game.start_career("D2_02", "A", "B", 94, [1, 2]), "a lower-division school can't start one")
	r.check(Game.career.division_invites(func(d): return true).is_empty(), "no NEW DIVISION AVAILABLE! invitation")
	Game.career.div_pending = [2]
	var joined := Game.career.activate_pending()
	r.check(joined.is_empty() and Game.career.div_pending == [2] and Game.career.teams.size() == 30, "a division already queued waits, kept, and nothing joins")
	r.check(Colleges.schools_of(2).size() == 7 and Colleges.schools_of(3).size() == 17 and Colleges.EXPANSION_CONFERENCES.size() > 0, "the schools and conferences are all still in the game's data")
	# the saves: a Division II career stays on disk and keeps its slot, but isn't listed or loaded
	var keep_dir := Game.save_dir
	var dir := "user://hibernation_test/"
	DirAccess.make_dir_recursive_absolute(dir)
	Game.save_dir = dir
	for n in range(1, Game.SLOTS + 1):
		if FileAccess.file_exists(Game.slot_path(n)):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(Game.slot_path(n)))
	var d1 := DivisionChecks.sandbox("CULA", [1], 95)
	var d2 := DivisionChecks.sandbox("D2_02", [1, 2], 96)
	var mixed := DivisionChecks.sandbox("CULA", [1, 3], 97)
	var texts := {}
	for pair in [[1, d1], [2, d2], [3, mixed]]:
		var t := JSON.stringify((pair[1] as Career).to_dict())
		var f := FileAccess.open(Game.slot_path(pair[0]), FileAccess.WRITE)
		f.store_string(t)
		f.close()
		texts[pair[0]] = t
	r.check(not Game.slot_hidden(1) and Game.slot_hidden(2) and Game.slot_hidden(3),
		"saves: the Division I career shows; the Division II one and the Division I school playing Division III don't")
	r.check(Game.slot_exists(2) and Game.slot_exists(3) and Game.first_free_slot() == 4, "...their slots stay taken: a new career never goes into them")
	r.check(Game.last_slot() == 1 and not Game.load_career(2) and not Game.load_career(3), "...CONTINUE and loading pass them by")
	r.check(FileAccess.get_file_as_string(Game.slot_path(2)) == texts[2] and FileAccess.get_file_as_string(Game.slot_path(3)) == texts[3], "...their files untouched")
	Colleges.lower_divisions = true
	r.check(not Game.slot_hidden(2) and Game.load_career(2) and Game.career.school == "D2_02" and Game.career.divisions == [1, 2],
		"switched back on: the Division II career is there again, as it was")
	Colleges.lower_divisions = Colleges.ENABLE_LOWER_DIVISIONS
	for n in range(1, Game.SLOTS + 1):
		if FileAccess.file_exists(Game.slot_path(n)):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(Game.slot_path(n)))
	Game.save_dir = keep_dir
	Game.career = null
	Store.reset_for_tests()

extends RefCounted
## Development tool: how close the expansion's first rosters come to their targets.
func run(_r) -> void:
	var seeds := [11, 22, 33, 44, 55, 66]
	var sum := {}
	for sd in seeds:
		var c := Career.new_setup(sd, [1, 2, 3])
		for s in Colleges.EXPANSION_SCHOOLS:
			var t: PoloTeam = c.teams[s.short]
			var a: Array = sum.get(s.short, [0.0, 0.0, 0.0, 0.0])
			a[0] += t.base_ovr()
			a[1] += PoloTeam.rating_stars(t.offense_display())
			a[2] += PoloTeam.rating_stars(t.defense_display())
			a[3] += PoloTeam.rating_stars(t.goalkeeping_display())
			sum[s.short] = a
	var n := float(seeds.size())
	for s in Colleges.EXPANSION_SCHOOLS:
		var a: Array = sum[s.short]
		print("%-26s OVR %d/%.1f  OFF %.1f/%.2f  DEF %.1f/%.2f  GK %.1f/%.2f" % [s.name, s.ovr, a[0] / n, s.t_off, a[1] / n, s.t_def, a[2] / n, s.t_gk, a[3] / n])

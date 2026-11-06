extends RefCounted
## The Long-Term Player Development report: whole-league seasons simmed back to back, every
## player's XP (Development.xp_log), upgrades (hidden levels gained) and how much of the room he
## arrived with he has used, by class year; then the freshmen followed through four years by
## career type (star / average starter, bench, starting / other keeper) and by position.
##   godot --headless --path game -- --test dev_career [seasons] [seed]

static func report(runner, seasons: int = 5, seed: int = 4040) -> Dictionary:
	print("long-term development: %d seasons, seed %d" % [seasons, seed])
	changed_ceilings = 0
	var c := Career.new_game("STAM", "A", "B", seed)
	Game.career = c
	c.training = {"focus": "balanced", "intensity": 2}
	var info := {}      # id -> {entry, box0, pos, keeper, seasons: [{year, xp, up, left, role}]}
	var season := 0
	var cohort := {}    # id -> the season he arrived as a freshman
	_mark(c, info, cohort, season)
	Development.xp_log = {}
	var st0 := 0.0
	var n0 := 0
	var o0 := 0.0
	for id in c.teams:
		o0 += (c.teams[id] as PoloTeam).live_ovr()
		for p in (c.teams[id] as PoloTeam).roster:
			st0 += p.stars
			n0 += 1
	print("  new career: league average CURRENT stars %.2f, team OVR %.1f" % [st0 / maxf(1, n0), o0 / maxf(1, c.teams.size())])
	while season < seasons:
		if c.in_offseason():
			c.end_week()
			c.queue.clear()
			continue
		while c.has_game():
			c.sim_my_game()
			_spend_mine(c)
		c.end_week()
		c.queue.clear()
		_spend_mine(c)
		if c.in_offseason():
			_record(c, info, season)
			Development.xp_log = {}
			season += 1
			if season < seasons:
				while c.in_offseason():
					c.end_week()
					c.queue.clear()
				_mark(c, info, cohort, season)
	Development.xp_log = null
	var out := _print(info, cohort, seasons)
	out["ceilings_changed"] = changed_ceilings
	print("    player-seasons whose ceilings moved: %d" % changed_ceilings)
	Game.career = null
	return out

static func _spend_mine(c: Career) -> void:
	for p in c.team().roster:
		Development.ai_spend(p)

## Everyone on a roster at a season's start: his class year, and (new to us) what he arrived with.
static func _mark(c: Career, info: Dictionary, cohort: Dictionary, season: int) -> void:
	for id in c.teams:
		var t: PoloTeam = c.teams[id]
		for p in t.roster:
			Development.ensure(p)
			if not info.has(p.id):
				info[p.id] = {"box0": Development.boxes_left(p), "pos": Deck.pos_tag(p), "keeper": p.is_keeper(),
					"star0": p.stars, "pot": p.pot_stars, "seasons": [], "year0": p.year, "lv0": p.xp_level,
					"ceil": p.attr_pot.duplicate()}
				if p.year == 1:
					cohort[p.id] = season
			info[p.id]["_lv"] = p.xp_level
			info[p.id]["_year"] = p.year

## Everyone at a season's end: his XP, upgrades, room left and role (keeper / starter / bench).
static var changed_ceilings := 0

static func _record(c: Career, info: Dictionary, season: int) -> void:
	var stars := 0.0
	var n := 0
	var ovr := 0.0
	for id in c.teams:
		ovr += (c.teams[id] as PoloTeam).live_ovr()
		for p in (c.teams[id] as PoloTeam).roster:
			stars += p.stars
			n += 1
	print("  season %d ends: league average CURRENT stars %.2f, team OVR %.1f" % [season + 1, stars / maxf(1, n), ovr / maxf(1, c.teams.size())])
	for id in c.teams:
		var t: PoloTeam = c.teams[id]
		var seven := t.starters()
		for p in t.roster:
			if not info.has(p.id):
				continue
			var i: Dictionary = info[p.id]
			var role := ("gk_start" if seven.has(p) else "gk_bench") if p.is_keeper() else ("start" if seven.has(p) else "bench")
			if p.attr_pot != i.ceil:
				changed_ceilings += 1
			i.seasons.append({"season": season, "year": int(i._year), "xp": int(Development.xp_log.get(p.id, 0)),
				"up": p.xp_level - int(i._lv), "left": Development.boxes_left(p) + p.tokens, "role": role,
				"stars": p.stars, "maxed": Development.is_maxed(p)})

static func _print(info: Dictionary, cohort: Dictionary, seasons: int) -> Dictionary:
	var names := ["", "FR", "SO", "JR", "SR"]
	# 1: every player-season, by class year and role
	print("\n  EVERY PLAYER-SEASON (by class year, role at season's end)")
	print("    %-4s %-9s %5s %7s %6s %7s %7s" % ["yr", "role", "n", "XP", "ups", "room0", "maxed"])
	var by := {}
	for id in info:
		var i: Dictionary = info[id]
		for s in i.seasons:
			var k := "%d %s" % [s.year, s.role]
			if not by.has(k):
				by[k] = {"n": 0, "xp": 0.0, "up": 0.0, "room": 0.0, "max": 0}
			by[k].n += 1
			by[k].xp += s.xp
			by[k].up += s.up
			by[k].room += i.box0
			by[k].max += 1 if s.maxed else 0
	var ks := by.keys()
	ks.sort()
	for k in ks:
		var b: Dictionary = by[k]
		var parts: PackedStringArray = k.split(" ")
		print("    %-4s %-9s %5d %7.0f %6.2f %7.2f %6d%%" % [names[int(parts[0])], parts[1], b.n, b.xp / b.n, b.up / b.n, b.room / b.n, roundi(100.0 * b.max / b.n)])
	# 2: freshmen followed through their four years, by career type
	var kinds := {}
	var careers: Array = []
	for id in cohort:
		var i: Dictionary = info[id]
		if i.seasons.size() < 4 or int(i.seasons[0].year) != 1:
			continue
		careers.append(id)
	var field_xp: Array = []
	var gk_xp: Array = []
	for id in careers:
		var i: Dictionary = info[id]
		var tot := 0
		for s in i.seasons.slice(0, 4):
			tot += int(s.xp)
		i["_tot"] = tot
		(gk_xp if i.keeper else field_xp).append(tot)
	field_xp.sort()
	gk_xp.sort()
	var f_top: int = field_xp[int(field_xp.size() * 0.75)] if not field_xp.is_empty() else 0
	var g_mid: int = gk_xp[int(gk_xp.size() * 0.5)] if not gk_xp.is_empty() else 0
	for id in careers:
		var i: Dictionary = info[id]
		var starts := 0
		for s in i.seasons.slice(0, 4):
			starts += 1 if String(s.role) in ["start", "gk_start"] else 0
		var kind := ""
		if i.keeper:
			kind = "4 GK strong starter" if starts >= 2 and int(i._tot) >= g_mid else "5 GK average/backup"
		elif starts >= 2:
			kind = "1 strong starter" if int(i._tot) >= f_top else "2 average starter"
		else:
			kind = "3 bench"
		if not kinds.has(kind):
			kinds[kind] = []
		kinds[kind].append(id)
	print("\n  FRESHMEN THROUGH FOUR YEARS (%d careers; room0 = upgrades left when he arrived)" % careers.size())
	print("    %-22s %4s %6s | %-31s | %-31s | %-31s | %-31s" % ["career", "n", "room0", "FR  XP ups used max", "SO  XP ups used max", "JR  XP ups used max", "SR  XP ups used max"])
	var out := {}
	var kk := kinds.keys()
	kk.sort()
	for kind in kk:
		var ids: Array = kinds[kind]
		var line := "    %-22s %4d %6.2f" % [kind, ids.size(), _avg(ids.map(func(x): return float(info[x].box0)))]
		var row := []
		for y in 4:
			var xp := _avg(ids.map(func(x): return float(info[x].seasons[y].xp)))
			var up := _avg(ids.map(func(x): return float(info[x].seasons[y].up)))
			var used := _avg(ids.map(func(x): return _used(info[x], y)))
			var mx := _avg(ids.map(func(x): return 1.0 if info[x].seasons[y].maxed else 0.0))
			line += " | %5.0f %4.2f %5.0f%% %5.0f%%   " % [xp, up, used * 100.0, mx * 100.0]
			row.append({"xp": xp, "up": up, "used": used, "maxed": mx})
		out[kind] = row
		print(line)
	# 2b: the same freshmen by the room they arrived with (DEV_PROFILES: near ceiling 0-1,
	# limited 1-3, moderate 4-8, high 8-14, exceptional 14-20)
	print("\n  FRESHMEN THROUGH FOUR YEARS, BY ROOM ON ARRIVAL (starters / bench by FR-year role)")
	print("    %-22s %4s %6s | %-31s | %-31s | %-31s | %-31s" % ["room", "n", "room0", "FR  XP ups used max", "SO  XP ups used max", "JR  XP ups used max", "SR  XP ups used max"])
	var tiers := {}
	for id in careers:
		var i: Dictionary = info[id]
		var b := int(i.box0)
		var t := "a 0-1" if b <= 1 else ("b 2-3" if b <= 3 else ("c 4-8" if b <= 8 else "d 9+"))
		var all_k := t + " all"
		for k in [all_k, t + (" GK" if i.keeper else (" starter" if String(i.seasons[0].role) == "start" else " bench"))]:
			if not tiers.has(k):
				tiers[k] = []
			tiers[k].append(id)
	var tk := tiers.keys()
	tk.sort()
	for t in tk:
		var ids: Array = tiers[t]
		var line := "    %-22s %4d %6.2f" % [t, ids.size(), _avg(ids.map(func(x): return float(info[x].box0)))]
		var row := []
		for y in 4:
			var xp := _avg(ids.map(func(x): return float(info[x].seasons[y].xp)))
			var up := _avg(ids.map(func(x): return float(info[x].seasons[y].up)))
			var used := _avg(ids.map(func(x): return _used(info[x], y)))
			var mx := _avg(ids.map(func(x): return 1.0 if info[x].seasons[y].maxed else 0.0))
			line += " | %5.0f %4.2f %5.0f%% %5.0f%%   " % [xp, up, used * 100.0, mx * 100.0]
			row.append({"xp": xp, "up": up, "used": used, "maxed": mx, "n": ids.size()})
		out["room " + t] = row
		print(line)
	# 3: the freshman year by position (all freshmen, every season)
	print("\n  FRESHMAN YEAR BY POSITION (every freshman, every season)")
	print("    %-10s %5s %7s %6s %6s %7s" % ["pos", "n", "XP", "ups", "room0", "maxed"])
	var pos := {}
	var all_fr := {"n": 0, "max": 0, "room0": 0, "n4": 0, "max4": 0}
	for id in info:
		var i: Dictionary = info[id]
		for s in i.seasons:
			if int(s.year) != 1 or int(i.year0) != 1:
				continue
			var k := String(i.pos)
			if not pos.has(k):
				pos[k] = {"n": 0, "xp": 0.0, "up": 0.0, "room": 0.0, "max": 0}
			pos[k].n += 1
			pos[k].xp += s.xp
			pos[k].up += s.up
			pos[k].room += i.box0
			pos[k].max += 1 if s.maxed else 0
			all_fr.n += 1
			all_fr.max += 1 if s.maxed else 0
			all_fr.room0 += 1 if int(i.box0) == 0 else 0
			if int(i.box0) >= 4:
				all_fr.n4 += 1
				all_fr.max4 += 1 if s.maxed else 0
	var pk := pos.keys()
	pk.sort()
	for k in pk:
		var b: Dictionary = pos[k]
		print("    %-10s %5d %7.0f %6.2f %6.2f %6d%%" % [k, b.n, b.xp / b.n, b.up / b.n, b.room / b.n, roundi(100.0 * b.max / b.n)])
		out["pos " + k] = {"n": b.n, "up": b.up / b.n, "maxed": float(b.max) / b.n}
	print("    all freshmen: %d, maxed after the year %d%% (arrived with no room: %d%%)" % [all_fr.n, roundi(100.0 * all_fr.max / maxf(1, all_fr.n)), roundi(100.0 * all_fr.room0 / maxf(1, all_fr.n))])
	print("    freshmen arriving with 4+ upgrades of room: %d, maxed after the year %d%%" % [all_fr.n4, roundi(100.0 * all_fr.max4 / maxf(1, all_fr.n4))])
	out["fr_maxed"] = float(all_fr.max) / maxf(1, all_fr.n)
	out["fr4_maxed"] = float(all_fr.max4) / maxf(1, all_fr.n4)
	out["fr_room0"] = float(all_fr.room0) / maxf(1, all_fr.n)
	# room on arrival
	var hist := {}
	for id in info:
		var i: Dictionary = info[id]
		if int(i.year0) == 1 and not i.seasons.is_empty():
			var b := mini(int(i.box0), 12)
			hist[b] = int(hist.get(b, 0)) + 1
	var hk := hist.keys()
	hk.sort()
	print("    freshmen's room on arrival (upgrades): " + ", ".join(hk.map(func(b): return "%d:%d" % [b, hist[b]])))
	return out

## How much of the room he arrived with he has used by the end of year `y` (no room: 1).
static func _used(i: Dictionary, y: int) -> float:
	var b0 := int(i.box0)
	if b0 <= 0:
		return 1.0
	return clampf(float(b0 - int(i.seasons[y].left)) / b0, 0.0, 1.0)

static func _avg(a: Array) -> float:
	var s := 0.0
	for v in a:
		s += float(v)
	return s / maxf(1, a.size())

extends RefCounted
## THE EXCLUSIONS & ROLL-OUT UPDATE: personal fouls (exclusions and penalty fouls committed) per
## player per game (no longer on the in-game holder tag), FOUL TROUBLE at two, ROLLED at three with an
## automatic replacement from the bench (every program has one now), no rolled player back, and a
## fresh count each game. The numbered checks follow the spec's REQUIRED TESTING list.
##   godot --headless --path game -- --test rollout

var r   # the test runner

func run(runner) -> void:
	r = runner
	print("exclusions & roll-out")
	Store.reset_for_tests()
	Game.progress = Progression.fresh()
	_benches()
	_counts()
	_real_fouls()
	_reentry()
	_replacements()
	_keeper()
	_multiple()
	_display()
	_next_game()
	_old_save()

func _career(seed_value: int = 51) -> Career:
	var c := Career.new_game("SJCU", "A", "B", seed_value)
	c.queue.clear()
	return c

func _flow(c: Career) -> MatchFlow:
	var opp: PoloTeam = c.teams["CULA"]
	return MatchFlow.new(c.team(), opp, 99, 2.0)

func _events(f: MatchFlow, k: String) -> Array:
	return f.events.filter(func(e): return String(e.k) == k)

# ------------------------------------------------------------------ the benches
func _benches() -> void:
	var c := _career()
	var ok := true
	for id in c.teams:
		var t: PoloTeam = c.teams[id]
		ok = ok and t.roster.size() == Career.ROSTER_MAX + Career.BENCH_MAX and t.roster.filter(func(p): return p.is_keeper()).size() == 2 and t.starters().size() == 7
	r.check(ok, "every program carries ten: seven and a bench with a backup keeper")
	var ids := {}
	var dup := false
	for id in c.teams:
		for p in c.teams[id].roster:
			dup = dup or ids.has(p.id)
			ids[p.id] = true
	r.check(not dup, "no player twice")

# ------------------------------------------------------------------ T41-44, T54
func _counts() -> void:
	var c := _career()
	var f := _flow(c)
	var d: PoloPlayer = f.them.starters()[3]
	var a: PoloPlayer = f.us.starters()[2]
	f._count({"k": "exclusion", "by": d, "drawn_by": a}, 0)
	r.check(f.state.pf_of(d) == 1 and f.state.pf_of(a) == 0, "T41/T54: the man who commits it gets the personal foul, not the one who draws it")
	r.check(f.state.excl_drawn_by[0].has(a) and f.state.excl_by[1].has(d), "T54: drawn and committed recorded as before (the XP's lists)")
	f._count({"k": "exclusion", "by": d, "drawn_by": a}, 0)
	r.check(f.state.pf_of(d) == 2 and not d.rolled and f.them.starters().has(d) and _events(f, "foul_trouble").size() == 1, "T42: two: FOUL TROUBLE, still eligible, not substituted")
	var before := f.them.starters()
	f._count({"k": "exclusion", "by": d, "drawn_by": a}, 0)
	var rolled := _events(f, "rolled")
	r.check(f.state.pf_of(d) == 3 and d.rolled and not d.is_available(), "T43: three: ROLLED")
	r.check(rolled.size() == 1 and rolled[0].p == d and rolled[0].sub != null and not before.has(rolled[0].sub) and f.them.starters().has(rolled[0].sub) and not f.them.starters().has(d),
		"T43: replaced by a real bench player (%s)" % (rolled[0].sub.short_name() if not rolled.is_empty() and rolled[0].sub != null else "none"))
	f._count({"k": "exclusion", "by": d, "drawn_by": a}, 0)
	r.check(f.state.pf_of(d) == 3 and _events(f, "rolled").size() == 1, "T4/T18: a rolled man's count stays 3, rolled once")
	# ordinary fouls never count
	f._start_attack(Play.Kind.HALF_COURT)
	var pl := f.play
	var att := pl.attackers[2]
	var def := pl.defenders[2]
	def.pos = att.pos + (Geo.goal_center() - att.pos).normalized() * 0.6
	var n0 := f.state.pf_of(def.player)
	for i in 3:
		pl._end_restart()
		pl._ordinary_foul(att, def)
		f._collect(0)
	r.check(f.state.pf_of(def.player) == n0, "T44: ordinary fouls never add a personal foul")

## The real paths: an exclusion and a penalty foul in a Play, collected by the flow.
func _real_fouls() -> void:
	var c := _career(52)
	var f := _flow(c)
	f._start_attack(Play.Kind.HALF_COURT)
	var pl := f.play
	var d := pl.defenders[0]
	pl._exclusion(d, pl.attackers[0])
	f._collect(0)
	f._collect(0)   # (the same events seen again count nothing)
	r.check(f.state.pf_of(d.player) == 1, "T41: an exclusion in the game: one personal foul, counted once")
	f._start_attack(Play.Kind.HALF_COURT)
	var pl2 := f.play
	var by := pl2.defenders[1]
	pl2._penalty(pl2.attackers[1], by)
	f._collect(0)
	f.attack_done()
	r.check(f.state.pf_of(by.player) == 1 and f.state.pen_by[1].has(by.player), "T45: a penalty foul: one personal foul for the man who committed it")
	r.check(f.play.kind == Play.Kind.PENALTY, "T45: and the penalty goes on as before")

# ------------------------------------------------------------------ T17
func _reentry() -> void:
	var c := _career(53)
	var f := _flow(c)
	f._start_attack(Play.Kind.HALF_COURT)
	var pl := f.play
	var d := pl.defenders[2]
	f.state.pf[d.player.id] = 2
	pl._exclusion(d, pl.attackers[2])
	f._collect(0)
	var who := d.player
	r.check(who.rolled and d.out, "T17: rolled on an exclusion: he's out, the man-up runs")
	var sub: PoloPlayer = _events(f, "rolled")[0].sub
	pl.man_up = 0.05
	pl.man_up_live = true   # (its first pass made: the clock runs)
	var guard := 0
	while pl.excluded != null and guard < 120 and not pl.over:   # (the whistle's freeze first, then the man-up)
		guard += 1
		pl.step(1.0 / 30.0)
	r.check(not d.out and d.player == sub, "T17: at the end of the man-up his replacement comes in (%s)" % sub.short_name())
	var on := {}
	var dup := false
	for s in pl.defenders + pl.attackers + [pl.keeper]:
		dup = dup or on.has(s.player)
		on[s.player] = true
	r.check(not on.has(who) and not dup, "T29: the rolled man is nowhere in the water, nobody twice")

# ------------------------------------------------------------------ T47
func _replacements() -> void:
	var c := _career(54)
	var t := c.team()
	var f := MatchFlow.new(t, c.teams["CULA"], 7, 2.0)
	var seven := t.starters()
	var victim: PoloPlayer = seven[3]
	var bench: Array = t.roster.filter(func(p): return not seven.has(p))
	f.state.pf[victim.id] = 2
	f._personal_foul(victim, 0)
	var sub: PoloPlayer = _events(f, "rolled")[0].sub
	var places: Array = seven.duplicate()
	places[3] = null
	PoloTeam.fill_places(places, bench.filter(func(q: PoloPlayer): return q.is_available()), true)
	var want: PoloPlayer = places[3]
	r.check(sub != null and bench.has(sub) and sub == want and not sub.is_keeper(), "T47: your bench man who fits his place best (%s for %s)" % [sub.short_name() if sub != null else "-", victim.short_name()])
	var attrs: Dictionary = sub.attrs.duplicate()
	r.check(sub.attrs == attrs and sub != victim and sub.stars != -1.0, "T16: with his own attributes (nothing copied)")
	r.check(f.state.pf_of(sub) == 0, "T19: he starts at 0 EX")
	r.check(t.starters().size() == 7 and t.starters().has(sub), "T29: he's in the seven")

# ------------------------------------------------------------------ T49
func _keeper() -> void:
	var c := _career(55)
	var opp: PoloTeam = c.teams["CULA"]
	var f := MatchFlow.new(c.team(), opp, 8, 2.0)
	var gk: PoloPlayer = opp.starters()[0]
	f.state.pf[gk.id] = 2
	f._personal_foul(gk, 1)
	var now: PoloPlayer = opp.starters()[0]
	r.check(gk.rolled and now != gk and now.is_keeper(), "T49: a rolled keeper: the backup keeper's in goal (%s)" % now.short_name())
	f._start_defense(Play.Kind.HALF_COURT)
	f._start_attack(Play.Kind.HALF_COURT)
	r.check(f.play.keeper.player == now, "T49: the play's keeper is the backup")

# ------------------------------------------------------------------ T51
func _multiple() -> void:
	var c := _career(56)
	var opp: PoloTeam = c.teams["CULA"]
	var f := MatchFlow.new(c.team(), opp, 9, 2.0)
	var field: Array = opp.starters().slice(1)
	for i in 2:
		f.state.pf[field[i].id] = 2
		f._personal_foul(field[i], 1)
	var st := opp.starters()
	var ids := {}
	var dup := false
	for p in st:
		dup = dup or ids.has(p.id)
		ids[p.id] = true
	r.check(field[0].rolled and field[1].rolled and not st.has(field[0]) and not st.has(field[1]) and st.size() == 7 and not dup, "T51: two rolled: two bench men in, nobody twice")
	r.check(f.state.pf_of(field[0]) == 3 and f.state.pf_of(field[2]) == 0, "T51: each his own count")
	# so many rolled the team can't make seven: it plays short, nobody comes back, nothing breaks
	for i in range(2, 5):
		f.state.pf[field[i].id] = 2
		f._personal_foul(field[i], 1)
	f._start_attack(Play.Kind.HALF_COURT)
	var gone := f.play.defenders.filter(func(s): return s.player.rolled)
	r.check(gone.all(func(s): return s.out) and f.play.defenders.size() == 6, "T30: short of players: the rolled stand-ins stay out of the water (%d)" % gone.size())
	for i in 60:
		f.play.step(1.0 / 30.0)
	r.check(gone.all(func(s): return s.out), "T18: and they never come back in")

# ------------------------------------------------------------------ T46
func _display() -> void:
	var c := _career(57)
	# (the HUD cleanup: the in-game holder tag no longer shows the count; it's still kept, MatchState.pf)
	var p: PoloPlayer = c.team().starters()[2]
	var plain := Hud.tag_parts(p)
	r.check(not plain.has("ex") and not String(plain.text).contains("EX"), "T46: the holder tag shows no EX count")
	r.check(is_equal_approx(float(plain.pos_x), float(plain.stars_x) + Deck.star_bar_w_for(p.stars, p.stars, int(plain.red)) + 6.0),
		"T46: the position follows the stars, no gap where the count was")
	var src := FileAccess.get_file_as_string("res://src/match/match_screen.gd")
	r.check(not src.contains("dp.keeper.player)") and src.contains("_tag_holder(dp)"), "the defending tag is the ball holder's, not your keeper's")

# ------------------------------------------------------------------ T52, T53
func _next_game() -> void:
	var c := _career(58)
	var opp: PoloTeam = c.teams["CULA"]
	var f := MatchFlow.new(c.team(), opp, 10, 2.0)
	var p: PoloPlayer = opp.starters()[2]
	f.state.pf[p.id] = 2
	f.state.tick(200.0)   # (into the second half)
	f._personal_foul(p, 1)
	r.check(p.rolled, "T52: fouls carry through the game: the third, later, rolls him")
	var f2 := MatchFlow.new(c.team(), opp, 11, 2.0)
	r.check(not p.rolled and f2.state.pf_of(p) == 0 and opp.starters().has(p), "T53: the next game: eligible again, 0 EX")
	p.rolled = true
	c.finish_my_game(MatchState.new().box(c.team()))
	r.check(not p.rolled, "T40: a finished career game clears every roll-out")

# ------------------------------------------------------------------ old saves
func _old_save() -> void:
	var c := _career(59)
	var d: Dictionary = JSON.parse_string(JSON.stringify(c.to_dict()))
	d.v = 8
	for id in d.teams:
		if id == c.school:
			continue
		var roster: Array = d.teams[id].roster
		d.teams[id].roster = roster.slice(0, 7)
	var back := Career.from_dict(d)
	var ok := true
	for id in back.teams:
		ok = ok and (back.teams[id] as PoloTeam).roster.size() == 10
	r.check(ok, "an older save: every program gets its bench on load")
	var kept := true
	for id in d.teams:
		if id == c.school:
			continue
		for pd in d.teams[id].roster:
			kept = kept and (back.teams[id] as PoloTeam).find_id(int(pd.id)) != null
	r.check(kept, "...and nobody already there is touched")

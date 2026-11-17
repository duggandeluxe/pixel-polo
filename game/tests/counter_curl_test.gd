extends RefCounted
## The counterattack's chain-reaction rotation (CounterCurl): only on a counter the game has already
## started, men coming in moving on the men holding their spots, one at a time, till it's the 6 on 6,
## in both attacks and both directions, without ever changing whether a counter happens (the activation regression: ACTIVATION_DIGEST, recorded before CounterCurl).
##   godot --headless --path game -- --test counter_curl

const DT := 1.0 / 60.0
## PlaySetup's decisions (kind, carry, the break's numbers, who has it, the steal line) over the
## fixed scenarios of activation_digest(), recorded from the code BEFORE this update. Any change to
## when a counter starts changes it.
const ACTIVATION_DIGEST := 1253889429

var r   # the test runner (check, check_between)

func run(runner) -> void:
	r = runner
	print("counter curl")
	_activation()
	_activation_switch()
	_no_counter_identical()
	_real_counters()
	_rotations()
	_interrupts()
	await _lab()
	var args := OS.get_cmdline_user_args()
	var i := args.find("counter_curl")
	_matches(int(args[i + 1]) if i >= 0 and args.size() > i + 1 else 6)

static func _teams() -> Array:
	return [League.make_team(2, 1), League.make_team(3, 1)]

## Every scenario the activation is checked on: made-up turnovers (seeded), and handovers built by
## hand (steals on the top line and the bottom line, open-water turnovers, keeper saves), each made
## into a counter possession exactly as MatchFlow._possession makes one.
static func activation_rows() -> Array:
	var rows: Array = []
	var t := _teams()
	for sd in 300:
		var rng := RandomNumberGenerator.new()
		rng.seed = 9100 + sd
		var p := Play.new(t[0], t[1], Play.Kind.COUNTER, rng)
		rows.append(_row(p))
	for sd in 300:
		var g := RandomNumberGenerator.new()
		g.seed = 9900 + sd
		var rng := RandomNumberGenerator.new()
		rng.seed = 12000 + sd
		var proto := Play.new(t[0], t[1], Play.Kind.HALF_COURT, RandomNumberGenerator.new())
		var pos := {}
		for s in proto.attackers + proto.defenders:
			pos[s.player] = Vector2(g.randf_range(2.0, 27.0), g.randf_range(1.0, 19.0))
		var why: String = ["steal", "turnover", "save", "steal"][sd % 4]
		var holder: Variant = null if why == "save" else proto.attackers[g.randi() % 6].player
		var at := Vector2(g.randf_range(1.0, 12.0), g.randf_range(2.0, 18.0))
		var snap := {"pos": pos, "vel": {}, "holder": holder, "lost_by": proto.defenders[g.randi() % 6].player,
			"why": why, "at": at}
		rows.append(_row(Play.new(t[0], t[1], Play.Kind.COUNTER, rng, snap)))
	return rows

static func _row(p: Play) -> String:
	return "%d|%s|%d,%d|%s|%s|%d" % [p.kind, p.carry, p.break_n.x, p.break_n.y,
		p.holder.tag if p.holder != null else "-", p.steal_line, p.rng.state % 1000003]

static func activation_digest() -> int:
	return hash(activation_rows())

# ------------------------------------------------------------------ activation (locked)
func _activation() -> void:
	var rows := activation_rows()
	var counters := rows.filter(func(s: String): return s.begins_with("%d|true" % Play.Kind.COUNTER)).size()
	var d := hash(rows)
	print("  activation: %d scenarios, %d counters, digest %d" % [rows.size(), counters, d])
	r.check(d == ACTIVATION_DIGEST, "counter curl: counter activation is identical to before the update (digest %d)" % d)

## The same activation with the curl switched off: it never had a say in it.
func _activation_switch() -> void:
	CounterCurl.enabled = false
	var off := activation_digest()
	CounterCurl.enabled = true
	r.check(off == ACTIVATION_DIGEST, "counter curl: activation is the same with the curl switched off")

# ------------------------------------------------------------------ no counter, no change
## A possession that isn't a counter (the half court, and a turnover with level numbers, which the
## game plays as a normal possession) is swum exactly as before: every body, every frame.
func _no_counter_identical() -> void:
	var same := true
	var tried := 0
	var t := _teams()
	for sd in 24:
		var kind := Play.Kind.HALF_COURT if sd % 2 == 0 else Play.Kind.COUNTER
		var tracks: Array = []
		var started := false
		for on in [false, true]:
			CounterCurl.enabled = on
			var rng := RandomNumberGenerator.new()
			rng.seed = 31000 + sd
			var p := Play.new(t[0], t[1], kind, rng)
			if p.kind == Play.Kind.COUNTER:
				break   # (a real counter: that's the rest of this test's)
			p.defending = sd % 4 >= 2
			var tr := PackedVector2Array()
			var bot := RandomNumberGenerator.new()
			bot.seed = 5
			var think := 0.0
			for i in 360:
				if p.over:
					break
				think -= DT
				if think <= 0.0:
					think = PlayBot.THINK_EVERY
					var d := PlayBot.think(p, bot)
					if not d.is_empty():
						p.throw(d.target, d.power)
				p.step(DT)
				started = started or p.curl_mode != CounterCurl.Mode.OFF
				for s in p.bodies():
					tr.append(s.pos)
			tracks.append(tr)
		CounterCurl.enabled = true
		if tracks.size() == 2:
			tried += 1
			same = same and tracks[0] == tracks[1] and not started
	r.check(tried >= 12 and same, "counter curl: no counter, nothing changes: %d possessions swum identically with it on and off" % tried)

# ------------------------------------------------------------------ the rotation
const MIRROR := {"C": "C", "1": "5", "2": "4", "3": "3", "4": "2", "5": "1"}

## A break staged so the arrivals chain: the ball with "2" out in front; "3" and "4" just behind
## him on the top side (they'll get down first and take the 2 m spot and the top wing for the men
## still coming), the centre next, "1" on his own side, "5" well back. Nobody of theirs back. `flip`:
## the same thing on the other side of the pool (the ball with "4", "3" and "2" ahead on the bottom...).
func _stage(defending: bool, flip: bool) -> Play:
	var t := _teams()
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var p := Play.new(t[0], t[1], Play.Kind.HALF_COURT, rng)
	p.defending = defending
	var spots := {"2": Vector2(21.0, 14.0), "3": Vector2(20.0, 8.0), "4": Vector2(18.0, 5.0),
		"C": Vector2(14.0, 10.0), "1": Vector2(15.0, 16.5), "5": Vector2(6.0, 4.0)}
	var holder: Swimmer = null
	for a in p.attackers:
		var key: String = MIRROR[a.tag] if flip else a.tag
		a.pos = spots[key]
		if flip:
			a.pos.y = 2.0 * Geo.GOAL_Y - a.pos.y
		a.vel = Vector2(a.top_speed * PlaySetup.BREAK_SWIM, 0.0)
		if key == "2":
			holder = a
	for d in p.defenders:
		d.pos = d.mark.pos + Vector2(-3.0, 0.5)
		d.vel = Vector2(1.5, 0.0)
	p.keeper.pos = Vector2(Geo.KEEPER_X, Geo.GOAL_Y)
	for s in p.bodies():
		s.target = s.pos
	p.give_ball(holder)
	p.kind = Play.Kind.COUNTER
	p.carry = true
	p.counter_t = 5.0
	p.break_n = p.break_numbers()
	PlayAI.counter_marks(p)
	PlayAI.assign_lanes(p)
	return p

func _variants() -> Array:
	return [[false, false], [true, false], [false, true], [true, true]]   # [defending, flip]

func _name(v: Array) -> String:
	return ("theirs" if v[0] else "yours") + (", the other side" if v[1] else "")

## Watches a counter for `secs`: how everybody swims, and each rotation as it goes.
func _watch(p: Play, secs: float) -> Dictionary:
	var w := {"fwd": {}, "jump": 0.0, "turn": 0.0, "closest": INF, "deep": -INF, "speed": 0.0, "states": {},
		"rot": [], "early_start": true}
	var last := {}
	var lastv := {}
	for a in p.attackers:
		last[a] = a.pos
		lastv[a] = a.vel
		w.states[a] = {}
	var seen := 0
	var tt := 0.0
	while tt < secs and not p.over:
		var held := {}
		if p.rot != null:
			for a: Swimmer in (p.rot as CounterCurl.Rotation).agents.keys():
				held[a] = ((p.rot as CounterCurl.Rotation).agents[a] as CounterCurl.Agent).at
		var before := {}
		for a in p.attackers:
			before[a] = a.pos
		p.step(DT)
		tt += DT
		var R: CounterCurl.Rotation = p.rot
		if R != null:
			# a rotation starts with the man still on his spot (he was holding it: no premature
			# leaving), the incoming man not yet on top of him
			while seen < R.log.size():
				var e: Dictionary = R.log[seen]
				seen += 1
				if e.k in ["rotate", "peel"]:
					var who: Swimmer = e.who
					if e.k == "rotate" and String(held.get(who, "")) != String(e.from):
						w.early_start = false
					w.rot.append({"e": e, "start": before[who], "to": R.spots[e.to], "side": (R.agents[who] as CounterCurl.Agent).side if R.agents.has(who) else 0.0, "ext": -INF})
		for a in p.attackers:
			var st := CounterCurl.state_of(p, a)
			w.states[a][st] = true
			if tt < 0.6 and a != p.holder:
				w.fwd[a] = minf(float(w.fwd.get(a, INF)), a.vel.x)
			w.jump = maxf(w.jump, a.pos.distance_to(last[a]))
			var on := R != null and R.agents.has(a)
			if on:
				if a.speed() > 1.2 and (lastv[a] as Vector2).length() > 1.2:
					w.turn = maxf(w.turn, absf(a.vel.angle_to(lastv[a])))
				w.speed = maxf(w.speed, a.speed() / (a.top_speed * Play.COUNTER_SURGE * 1.01))
				w.deep = maxf(w.deep, a.pos.x)
			last[a] = a.pos
			lastv[a] = a.vel
		for rr: Dictionary in w.rot:
			var who: Swimmer = rr.e.who
			if R != null and R.agents.has(who) and (R.agents[who] as CounterCurl.Agent).goal == rr.e.to:
				# how far he bows out (towards his side) off the straight line from where he started to his next spot
				var n := CounterCurl.bow(rr.start, rr.to, float(rr.side))
				rr.ext = maxf(rr.ext, (who.pos - (rr.start as Vector2)).dot(n))
		if tt > 1.0:
			for i in p.attackers.size():
				for j in range(i + 1, p.attackers.size()):
					w.closest = minf(w.closest, p.attackers[i].pos.distance_to(p.attackers[j].pos))
	return w

func _rotations() -> void:
	for v in _variants():
		var p := _stage(v[0], v[1])
		var w := _watch(p, 22.0)
		var nm := _name(v)
		var R: CounterCurl.Rotation = p.rot
		var fwd := true
		for a in p.attackers:
			if w.fwd.has(a):
				fwd = fwd and float(w.fwd[a]) > 0.0
		r.check(fwd, "rotation: everybody sets off up the pool (%s)" % nm)
		var rots: Array = R.log.filter(func(e: Dictionary): return e.k in ["rotate", "peel"])   # (the handoffs: moved on off a spot, or off his way to one)
		r.check(rots.size() >= 2, "rotation: incoming men move the men holding their spots on (%d rotations, %s)" % [rots.size(), nm])
		var triggered := true
		var before_overlap := INF
		for e: Dictionary in rots:
			triggered = triggered and e.by != null and float(e.d) <= CounterCurl.ARRIVE_R + 0.05
			before_overlap = minf(before_overlap, float(e.gap))
		r.check(triggered, "rotation: every one set off by a teammate coming in, within %.0f m of the spot (%s)" % [CounterCurl.ARRIVE_R, nm])
		r.check(before_overlap >= 1.0, "rotation: ...and he's off before they meet (closest %.1f m apart as it starts, %s)" % [before_overlap, nm])
		r.check(w.early_start, "rotation: nobody leaves a spot he's holding until he's moved on (%s)" % nm)
		r.check(R.log.filter(func(e: Dictionary): return e.k == "release").is_empty(), "rotation: nobody gives up a spot with its owner still coming (%s)" % nm)
		# the chain: a man moved on by a man who'd just been moved on himself
		var chain := 0
		for e: Dictionary in rots:
			var by: Swimmer = e.by
			for f: Dictionary in rots:
				if f.who == by and float(f.t) < float(e.t):
					var held_since := R.log.filter(func(g: Dictionary): return g.k == "hold" and g.who == by and float(g.t) > float(f.t) and float(g.t) < float(e.t))
					if held_since.is_empty():
						chain += 1
		r.check(chain >= 1, "rotation: a chain reaction, a man on his way out moving the next man on (%d, %s)" % [chain, nm])
		var times := {}
		for e: Dictionary in rots:
			times[snappedf(float(e.t), 0.25)] = true
		r.check(times.size() == rots.size(), "rotation: one at a time, as each man comes in (%s)" % nm)
		# the way they go: the top side up and out, the bottom down and out, round the turn
		var dir_ok := true
		var least := INF
		for rr: Dictionary in w.rot:
			if float(rr.side) != 0.0:
				dir_ok = dir_ok and float(rr.ext) >= 0.3
				least = minf(least, float(rr.ext))
		r.check(dir_ok, "rotation: the top side swings up and out, the bottom down and out, round the turn (least %.2f m, %s)" % [least, nm])
		var pairs := {}
		var twice := false
		var per := {}
		for e: Dictionary in rots:
			pairs[[e.who, e.by, e.from]] = true
			per[e.who] = int(per.get(e.who, 0)) + 1
		for e: Dictionary in rots:
			twice = twice or pairs.has([e.by, e.who, e.from])
		var most := 0
		for k in per.keys():
			most = maxi(most, int(per[k]))
		r.check(not twice and most <= 3, "rotation: nobody swaps the same spot back and forth (most moves for a man %d, %s)" % [most, nm])
		# the end: everybody on his own spot (the man on the ball with it, back on his), the centre on 2 m
		var set_ok := true
		for a in p.attackers:
			if a == p.holder:
				set_ok = set_ok and a.pos.distance_to(a.home) < 1.0
			else:
				set_ok = set_ok and R.done.get(a, "") == "SET"
		r.check(set_ok and R.agents.is_empty() and p.curl_mode == CounterCurl.Mode.FINISHED,
			"rotation: it ends in the 6 on 6, every man swum into his own spot, nobody stuck (%s)" % nm)
		var c: Swimmer = PlaySetup._by_tag(p, "C")
		r.check(R.done.get(c, "") == "SET" and not (w.states[c] as Dictionary).has("ROTATING"), "rotation: the centre takes 2 m, never rotates (%s)" % nm)
		r.check(rots.any(func(e: Dictionary): return e.by == c and e.from == "C"), "rotation: ...moving on the man holding it for him (%s)" % nm)
		r.check(w.jump < 0.2, "rotation: nobody jumps (%.2f m in a frame, %s)" % [w.jump, nm])
		r.check(w.turn < 0.35, "rotation: no sudden turns (%.2f rad in a frame at speed, %s)" % [w.turn, nm])
		r.check(w.speed <= 1.0, "rotation: nobody faster than the existing speeds (%.2f of the fastest, %s)" % [w.speed, nm])
		r.check(w.closest >= 0.45, "rotation: nobody on top of a teammate (%.2f m, %s)" % [w.closest, nm])
		r.check(w.deep <= Geo.TWO_M + 0.3, "rotation: nobody off the ball inside 2 m (%.2f, %s)" % [w.deep, nm])

## The rotation never gets in the way of the ball: a pass to a man in it, he takes it (out of it);
## when he's moved it on, he's back in it for his own spot. An exclusion (the 4-2) or the ball
## changing hands ends it.
func _interrupts() -> void:
	for v in _variants():
		var p := _stage(v[0], v[1])
		var mate: Swimmer = null
		var tt := 0.0
		while tt < 8.0 and mate == null and not p.over:
			p.step(DT)
			tt += DT
			var R: CounterCurl.Rotation = p.rot
			for a: Swimmer in R.agents.keys():
				if a.tag != "C" and p.holder != null and (R.agents[a] as CounterCurl.Agent).goal != "" \
						and a.pos.distance_to(p.holder.pos) < 9.0:
					mate = a
					break
		r.check(mate != null, "rotation: somebody on his way in to pass to (%s)" % _name(v))
		if mate == null:
			continue
		var passer := p.holder
		p.pass_to(mate)
		var t2 := 0.0
		while t2 < 3.0 and p.holder != mate and not p.over:
			p.step(DT)
			t2 += DT
		var R2: CounterCurl.Rotation = p.rot
		r.check(p.holder == mate and not R2.agents.has(mate), "rotation: a pass to a man in it: he takes it, out of the rotation (%s)" % _name(v))
		p.pass_to(passer)
		var t3 := 0.0
		var back := false
		while t3 < 18.0 and not p.over:
			p.step(DT)
			t3 += DT
			back = back or (R2.agents.has(mate) and CounterCurl.reason_of(p, mate).begins_with("BACK IN"))
		r.check(back and (R2.done.get(mate, "") == "SET" or p.holder == mate), "rotation: ...rid of it, he's back in for his own spot and gets there (%s)" % _name(v))
	var q := _stage(false, false)
	for _i in 30:
		q.step(DT)
	r.check(not (q.rot as CounterCurl.Rotation).agents.is_empty(), "rotation: men in it on the break")
	q.man_up = 5.0
	q.step(DT)
	r.check((q.rot as CounterCurl.Rotation).agents.is_empty() and q.curl_mode == CounterCurl.Mode.FINISHED, "rotation: an exclusion (the 4-2) ends it")
	var e := _stage(false, false)
	for _i in 30:
		e.step(DT)
	e._turnover(e.holder, "TURNOVER", "turnover")
	e.step(DT)
	r.check((e.rot as CounterCurl.Rotation).agents.is_empty(), "rotation: the ball changing hands ends it")

## The game's own counters (PlaySetup's, from made-up turnovers): every one is swum with the
## rotation and ends in the 6 on 6; nothing else ever is.
func _real_counters() -> void:
	var t := _teams()
	var counters := 0
	var rotated := 0
	var formed := 0
	var stuck := 0
	var others_off := true
	for sd in 80:
		var rng := RandomNumberGenerator.new()
		rng.seed = 9100 + sd
		var p := Play.new(t[0], t[1], Play.Kind.COUNTER, rng)
		var was := p.kind == Play.Kind.COUNTER and p.carry
		p.step(DT)
		if not was:
			others_off = others_off and p.curl_mode == CounterCurl.Mode.OFF
			continue
		counters += 1
		if p.curl_mode != CounterCurl.Mode.OFF:
			rotated += 1
		var tt := 0.0
		while tt < 25.0 and not p.over and p.curl_mode != CounterCurl.Mode.FINISHED:
			p.step(1.0 / 30.0)
			tt += 1.0 / 30.0
		if p.curl_mode == CounterCurl.Mode.FINISHED and not p.over:
			formed += 1
		elif not p.over:
			stuck += 1
	print("  made-up counters: %d, %d swum with the rotation, %d into the 6 on 6, %d not done in 25 s" % [counters, rotated, formed, stuck])
	r.check(counters > 0 and rotated == counters, "rotation: every counter the game starts is swum with it (%d of %d)" % [rotated, counters])
	r.check(others_off, "rotation: a turnover that isn't a counter never is")
	r.check(stuck == 0, "rotation: none of them stuck (%d)" % stuck)

## Whole bot matches, with it and without it: counters started by the game's own rule (per game it
## only moves as far as where the men happen to be when the ball changes hands), every one swum
## with the rotation.
func _matches(n: int) -> void:
	var res := {}
	for on in [false, true]:
		CounterCurl.enabled = on
		var tot := {"counters": 0, "live": 0, "curled": 0, "goals": 0}
		for i in n:
			var teams := [League.make_team(i % 8, 0), League.make_team((i + 3) % 8, 0)]
			_match(MatchFlow.new(teams[0], teams[1], 5000 + i, MatchState.QUARTER_MIN), tot)
		res[on] = tot
	CounterCurl.enabled = true
	var off: Dictionary = res[false]
	var on_: Dictionary = res[true]
	print("  %d bot matches: counters per game %.2f before, %.2f with the curl (goals %.1f, %.1f); %d of %d counters still on for a frame of swimming were swum with the rotation" % [n,
		float(off.counters) / n, float(on_.counters) / n, float(off.goals) / n, float(on_.goals) / n, on_.curled, on_.live])
	r.check(on_.live > 0 and on_.curled == on_.live, "rotation: every counter in a real match is swum with it (%d of %d)" % [on_.curled, on_.live])
	r.check(off.curled == 0, "counter curl: switched off, no counter is")
	if n >= 8:   # (a handful of matches is too few to compare)
		r.check(absf(float(on_.counters) - float(off.counters)) / maxf(1.0, float(off.counters)) < 0.25,
			"counter curl: counters per game in line with before (%d, %d)" % [off.counters, on_.counters])

func _match(f: MatchFlow, tot: Dictionary) -> void:
	var steps := 0
	var bot := RandomNumberGenerator.new()
	bot.seed = 1
	while f.phase != MatchFlow.Phase.FINAL and steps < 200000:
		steps += 1
		match f.phase:
			MatchFlow.Phase.SPRINT:
				f.sprint_done(f.rng.randf() < 0.5)
			MatchFlow.Phase.ATTACK, MatchFlow.Phase.DEFENSE:
				var ours := f.phase == MatchFlow.Phase.ATTACK
				var p := f.play
				var curled := false
				var live := false   # (a counter shot from the first touch is over before anybody swims a stroke)
				var think := 0.0
				var t := 0.0
				if not ours:
					if "auto_defend" in f:
						f.set("auto_defend", true)
					f.auto_keeper = 0.5
				while not p.over and t < 90.0:
					if ours:
						think -= 1.0 / 30.0
						if think <= 0.0:
							think = PlayBot.THINK_EVERY
							var d := PlayBot.think(p, bot)
							if not d.is_empty():
								p.throw(d.target, d.power)
						f.tick_attack(1.0 / 30.0)
					else:
						f.tick_defense(1.0 / 30.0)
					live = live or (p.carry and p.kind == Play.Kind.COUNTER)   # (still on after a frame of swimming: it was on while they swam)
					curled = curled or p.curl_mode != CounterCurl.Mode.OFF
					f.events.clear()
					t += 1.0 / 30.0
				if p.kind == Play.Kind.COUNTER:
					tot.counters += 1
					if live:
						tot.live += 1
					if curled:
						tot.curled += 1
				if ours:
					f.attack_done()
				else:
					f.defense_done()
			MatchFlow.Phase.SHOOTOUT_THEM:
				f.their_ball_done()
			MatchFlow.Phase.THEIR_SHOT:
				f.auto_duel(0.5)
				f.duel_done()
			MatchFlow.Phase.BREAK:
				f.break_done()
	tot.goals += f.state.score[0] + f.state.score[1]

# ------------------------------------------------------------------ Developer Mode
## The COUNTERATTACK CURL TEST: opens from Developer Mode, START runs the real thing (the same
## routes a match lays out), RESET puts the ball back with the keeper, REVERSE runs it the other
## way, REPEAT goes again by itself.
func _lab() -> void:
	var dev_was: bool = Game.settings.get("dev_mode", false)
	Game.settings.dev_mode = true
	Game.goto("counter_lab")
	await r.get_tree().process_frame
	await r.get_tree().process_frame
	var lab = Game.current_screen
	r.check(lab != null and lab.has_method("start_counter"), "COUNTERATTACK CURL TEST opens (Settings > Developer Mode)")
	if lab == null or not lab.has_method("start_counter"):
		Game.settings.dev_mode = dev_was
		return
	r.check(lab.phase == "ready" and lab.play.holder == null and lab.paused, "RESET: the ball with the keeper, nobody moving")
	for rev in [false, true]:
		if rev:
			lab.reverse()
		lab.start_counter()
		var p: Play = lab.play
		r.check(p.kind == Play.Kind.COUNTER and p.carry and p.holder != null, "START COUNTERATTACK: the outlet, the counter on (%s)" % ("reversed" if rev else "normal"))
		var seen := {}
		for i in 60 * 20:
			lab._process(DT)
			for a in p.attackers:
				seen[CounterCurl.state_of(p, a)] = true
			if lab.phase == "set":
				break
		r.check(lab.phase == "set", "...it runs to the set attack (%s)" % ("reversed" if rev else "normal"))
		r.check(seen.has("ROTATING") and (seen.has("HOLDING POSITION") or seen.has("INCOMING TEAMMATE")) and seen.has("FORMATION READY") and lab.events.size() >= 1,
			"...men holding spots moved on by men coming in, into the formation (%d rotations, %s)" % [lab.events.size(), "reversed" if rev else "normal"])
		var R: CounterCurl.Rotation = p.rot
		r.check(R.done.get(PlaySetup._by_tag(p, "C"), "") == "SET", "...the centre on 2 m (%s)" % ("reversed" if rev else "normal"))
		r.check(lab.view.mirror == rev, "REVERSE DIRECTION draws it attacking the other way (%s)" % rev)
	lab.toggle_repeat()
	var first: Play = lab.play
	for i in 60 * 30:
		lab._process(DT)
		if lab.play != first:
			break
	r.check(lab.play != first and lab.phase == "running", "REPEAT TEST: it goes again by itself")
	lab.toggle_repeat()
	lab.reset_test()
	r.check(lab.phase == "ready" and lab.play.holder == null and lab.events.is_empty(), "RESET TEST: back to the start")
	Game.settings.dev_mode = dev_was
	Game.goto("title")
	await r.get_tree().process_frame

## godot --path game -- --test counter_curl_png <outdir>: the lab at its moments (needs a window).
static func shots(runner, dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	var save := func(name: String) -> void:
		await RenderingServer.frame_post_draw
		runner.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [dir, name])
	Game.settings.dev_mode = true
	Game.goto("counter_lab")
	await runner.get_tree().process_frame
	await runner.get_tree().process_frame
	var lab = Game.current_screen
	await save.call("curl_ready")
	for rev in [false, true]:
		if rev:
			lab.reverse()
			await runner.get_tree().process_frame
		lab.start_counter()
		var tag := "rev_" if rev else ""
		var marks := {90: "sprint", 200: "hold", 300: "rotate", 420: "rotate2", 560: "chain", 800: "set"}
		for i in 801:
			lab._process(DT)
			if marks.has(i):
				lab.paused = true
				lab.stage_cv.queue_redraw()
				await runner.get_tree().process_frame
				await save.call("curl_%s%s" % [tag, marks[i]])
				lab.paused = false
	Game.settings.dev_mode = false

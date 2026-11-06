extends RefCounted
## Save-rate numbers for the AI keeper (ShotModel.resolve only, so it runs on older copies too):
##   godot --headless --path game -- --test keeper_measure [n]

const PERIMETER := [Vector2(24.0, 10.0), Vector2(24.2, 8.0), Vector2(24.2, 12.0), Vector2(24.6, 6.8), Vector2(24.6, 13.2)]
const CLOSE := [Vector2(27.6, 10.0), Vector2(27.4, 9.2), Vector2(27.4, 10.8), Vector2(27.8, 9.6), Vector2(27.8, 10.4)]

static func _aim(keeper_y: float, rng: RandomNumberGenerator) -> float:
	var open_side := -1.0 if keeper_y > Geo.GOAL_Y else 1.0
	if absf(keeper_y - Geo.GOAL_Y) < 0.05:
		open_side = -1.0 if rng.randf() < 0.5 else 1.0
	var u := rng.randf()
	if u < 0.6:
		return Geo.GOAL_Y + open_side * rng.randf_range(0.8, 1.35)
	if u < 0.85:
		return Geo.GOAL_Y - open_side * rng.randf_range(0.8, 1.3)
	return Geo.GOAL_Y + rng.randf_range(-0.35, 0.35)

static func measure(n: int, v: float = 5.0) -> Dictionary:
	var k := AttrBench.player({"com": v, "lun": v, "blk": v, "leg": v}, true)
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var arng := RandomNumberGenerator.new()
	arng.seed = 78
	var tally := {}
	var add := func(key: String, saved: bool) -> void:
		var e: Vector2 = tally.get(key, Vector2.ZERO)
		tally[key] = e + Vector2(1.0 if saved else 0.0, 1.0)
	for i in n:
		var close := i % 2 == 1
		var spots: Array = CLOSE if close else PERIMETER
		var from: Vector2 = spots[(i / 2) % spots.size()]
		var ky := PlayAI.keeper_set_y(from, 0.6)
		var aim := _aim(ky, arng) if OS.get_environment("AIMS") != "uniform" else Geo.GOAL_Y + arng.randf_range(-1.35, 1.35)
		var power := arng.randf_range(0.5, 1.0)
		var hold := arng.randf_range(0.0, 2.0)
		var ctx := AttrBench.shot_ctx(AttrBench.player({}), null, k, INF)
		ctx["exact"] = true
		ctx["iq"] = 0.5
		ctx["hold"] = hold
		var res := ShotModel.resolve(from, aim, power, 62.0, 4.0, [], ky, 62.0, rng, false, {}, ctx)
		var out := String(res.outcome)
		if out in ["miss", "post"]:
			continue
		var saved := out in ["save", "parry"]
		var cy := float(res.cross_y)
		add.call("all", saved)
		add.call("close" if close else "perimeter", saved)
		add.call("central" if absf(cy - ky) < 0.5 else ("corner" if absf(cy - Geo.GOAL_Y) > 1.0 else "between"), saved)
		add.call("fast" if float(res.speed) > 14.0 else ("slow" if float(res.speed) < 11.5 else "mid"), saved)
		add.call("high" if float(res.get("height", 0.5)) > 0.75 else "low/mid", saved)
		add.call("hold<0.3" if hold < 0.3 else ("hold>1.2" if hold > 1.2 else "hold mid"), saved)
		var gk: Dictionary = res.get("gk", {})
		if not gk.is_empty():
			add.call("kind:" + String(gk.kind), saved)
			add.call(("C " if close else "P ") + "kind:" + String(gk.kind) + (" central" if absf(cy - ky) < 0.5 else ""), saved)
			if String(gk.kind) == "panic":
				add.call("panic commit %d" % int(gk.commit), saved)
	var outd := {}
	for key in tally:
		var e: Vector2 = tally[key]
		outd[key] = "%.3f (n %d)" % [e.x / maxf(e.y, 1.0), int(e.y)]
	return outd

## The targets the old tests encoded: {near, far (wing, keeper on the near post), corner5, at_him5,
## hard corner goals poor / avg / elite, perimeter vs close goals}
static func targets() -> Dictionary:
	var rate := func(from: Vector2, aim: float, ky: float, power: float, skill: float, seed_v: int) -> float:
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_v
		var g := 0
		for i in 2000:
			if ShotModel.resolve(from, aim, power, 65.0, 5.0, [], ky, skill, rng).outcome == "goal":
				g += 1
		return g / 2000.0
	return {"wing near": rate.call(Vector2(25.5, 13.5), 11.2, 10.7, 0.8, 62.0, 21), "wing far": rate.call(Vector2(25.5, 13.5), 8.8, 10.7, 0.8, 62.0, 21),
		"5m corner": rate.call(Vector2(25, 10), 11.2, 10.0, 0.8, 62.0, 11), "5m at him": rate.call(Vector2(25, 10), 10.1, 10.0, 0.8, 62.0, 11),
		"pen": 0.0, "hard poor": rate.call(Vector2(24.5, 10.5), 8.7, 10.2, 1.0, 30.0, 5), "hard avg": rate.call(Vector2(24.5, 10.5), 8.7, 10.2, 1.0, 62.0, 5),
		"hard elite": rate.call(Vector2(24.5, 10.5), 8.7, 10.2, 1.0, 92.0, 5), "7m corner": rate.call(Vector2(23, 10), 11.2, 10.0, 0.8, 62.0, 11)}

static func report(runner, n: int) -> void:
	if OS.get_environment("TARGETS") != "":
		var t := targets()
		print("targets: ", t)
		var m := measure(n, 5.0)
		print("keeper 5: all %s perim %s close %s" % [m["all"], m["perimeter"], m["close"]])
		print("keeper 2: all %s   keeper 8: all %s" % [measure(n, 2.0)["all"], measure(n, 8.0)["all"]])
		return
	for v in [2.0, 5.0, 8.0]:
		var m := measure(n, v)
		print("keeper %.0f save rates:" % v)
		var keys := m.keys()
		keys.sort()
		for key in keys:
			print("  %-18s %s" % [key, m[key]])

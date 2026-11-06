extends RefCounted
## Numbers for the Dynasty Refinement update's gameplay work (not checks):
##   godot --headless --path game -- --test refine_measure [n]
## Wing-to-wing passes on a 6 on 5, and entries into the centre against each drop.

const DT := 1.0 / 60.0
const F := DefenseFormation.F
var r

func run(runner, n: int = 200) -> void:
	r = runner
	for defending in [false, true]:
		for pair in [["1", "5"], ["5", "1"], ["2", "3"], ["3", "2"], ["2", "5"], ["3", "1"]]:
			for wait in [0.0, 0.5, 1.0, 2.0, 4.0]:
				print("SWING %s>%s %.1fs after whistle, %s: %s" % [pair[0], pair[1], wait, "their" if defending else "your", swing(n, pair[0], pair[1], wait, defending)])
	for defending in [false, true]:
		for pair in [["1", "5"], ["5", "1"]]:
			var o := wing(n, pair[0], pair[1], defending)
			print("WING %s>%s %s: %s" % [pair[0], pair[1], "their attack" if defending else "your attack", o])
	for defending in [false, true]:
		for f in [F.M_DROP, F.FIVE_DROP, F.FOUR_FIVE, F.THREE_FOUR]:
			for wait in [0.4, 3.0]:
				for tag in ["1", "2", "3", "4", "5"]:
					var o := entry(n / 2, f, tag, wait, defending)
					print("ENTRY %s from %s after %.1fs %s: %s" % [DefenseFormation.NAMES[f], tag, wait, "their" if defending else "your", o])

## The pass `wait` s after the exclusion's freeze: nobody settled yet.
func swing(n: int, from: String, to: String, wait: float, defending: bool) -> Dictionary:
	var out := {}
	for sd in n:
		var p: Play = r._center_play(66000 + sd, defending)
		p.set_level(1.0)
		for s in p.attackers + p.defenders:
			s.player.trait_id = ""
		p.give_ball(PlaySetup._by_tag(p, from))
		p._exclusion(p.defenders[sd % 5 + 1], null)
		p.drive_timer = 99.0
		for i in int((1.2 + wait) * 60):
			p.shot_clock = 20.0
			p.step(DT)
			if p.over or p.holder == null:
				break
		if p.over or p.holder == null:
			_add(out, "before")
			continue
		p.restart = false
		p.pass_first = false
		p.free_throw = false
		var tgt := PlaySetup._by_tag(p, to)
		if not p.pass_to(tgt):
			_add(out, "no pass")
			continue
		var res := "?"
		for i in 180:
			p.shot_clock = 20.0
			p.step(DT)
			if p.over:
				res = "%s:%s" % [str(p.result.outcome), "keeper" if (p.result.get("by") != null and (p.result.by as PoloPlayer).is_keeper()) else "field"]
				break
			if p.holder == tgt:
				res = "caught"
				break
			if p.ball.state == Ball.State.LOOSE:
				res = "tipped"
				break
		_add(out, res)
	return out

## Man-up, settled, then the pass; the outcome by who ended it.
func wing(n: int, from: String, to: String, defending: bool) -> Dictionary:
	var out := {}
	for sd in n:
		var p: Play = r._center_play(77000 + sd, defending)
		for s in p.attackers + p.defenders:
			s.player.trait_id = ""
		p.give_ball(PlaySetup._by_tag(p, from))
		p._exclusion(p.defenders[sd % 5 + 1], null)
		p.freeze = 0.0
		p.drive_timer = 99.0
		for i in 150:   # 2.5 s of settling
			p.shot_clock = 20.0
			p.step(DT)
			if p.over or p.holder == null:
				break
		if p.over or p.holder == null:
			_add(out, "before")
			continue
		var tgt := PlaySetup._by_tag(p, to)
		p.restart = false
		p.pass_first = false
		p.free_throw = false
		if not p.pass_to(tgt):
			_add(out, "no pass")
			continue
		var res := "?"
		for i in 180:
			p.shot_clock = 20.0
			p.step(DT)
			if p.over:
				res = "%s:%s" % [str(p.result.outcome), "keeper" if (p.result.get("by") != null and (p.result.by as PoloPlayer).is_keeper()) else "field"]
				break
			if p.holder == tgt:
				res = "caught"
				break
			if p.ball.state == Ball.State.LOOSE:
				res = "tipped"
				break
		_add(out, res)
	return out

func entry(n: int, f: int, tag: String, wait: float, defending: bool) -> Dictionary:
	var out := {}
	for sd in n:
		var p: Play = r._center_play(88000 + sd, defending)
		for s in p.attackers + p.defenders:
			s.player.trait_id = ""
		var holder := PlaySetup._by_tag(p, tag)
		p.give_ball(holder if wait > 1.0 else PlaySetup._by_tag(p, "3" if tag != "3" else "2"))
		if p.has_method("instant_drop"):
			p.call("instant_drop", f)
		else:
			p.select_formation(f)
		for i in int(2.5 * 60):
			p.step(DT)
		if wait < 1.0:   # swing it, then the entry `wait` s after the catch
			p.pass_to(holder)
			for i in 120:
				p.step(DT)
				if p.holder == holder or p.over:
					break
		for i in int(wait * 60):
			p.step(DT)
		if p.over or p.holder != holder:
			_add(out, "before")
			continue
		p.restart = false
		p.pass_first = false
		p.free_throw = false
		p.first_pass = sd % 2 == 0
		var c := PlaySetup._by_tag(p, "C")
		if not p.pass_to(c):
			_add(out, "no pass")
			continue
		p.events.clear()
		var res := "?"
		for i in 180:
			p.step(DT)
			if p.over:
				res = str(p.result.outcome)
				break
			if p.ball.state == Ball.State.LOOSE:
				res = "tipped"
				break
			if p.holder == c:
				res = "caught"
				for k in 30:
					p.step(DT)
					if p.over:
						break
				for e in p.events:
					if e.k == "foul":
						res = "caught+foul"
					elif e.k == "exclusion":
						res = "caught+excl"
				break
		_add(out, res)
	return out

func _add(d: Dictionary, k: String) -> void:
	d[k] = int(d.get(k, 0)) + 1

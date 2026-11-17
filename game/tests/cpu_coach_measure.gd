extends RefCounted
## Measurement only: how often your coaching draw (CoachEvents.roll) lands on each heat-giving
## event when its condition fits your game.
##   godot --headless --path game -- --test cpu_coach_measure [seasons]

const IDS := ["star_in_making", "keeper_confidence", "rough_night"]

func run(runner, seasons: int) -> void:
	var fits := {}
	var chosen := {}
	var games := 0
	for id in IDS:
		fits[id] = 0
		chosen[id] = 0
	for sd in [501, 502, 503, 504]:
		var c := Career.new_game(["GWU", "CULA", "WAGN", "MSMU"][sd % 4], "M", "M", sd)
		Game.career = c
		for s in seasons:
			var label := c.season_label()
			var guard := 0
			while c.season_label() == label and guard < 40:
				guard += 1
				c.queue.clear()
				while c.has_game():
					var out := c.sim_my_game()
					var rv: Dictionary = out.get("review", {})
					if rv.is_empty():
						continue
					games += 1
					var fit := {}
					for id in IDS:
						fit[id] = not CoachEvents.when(id, c, rv).is_empty()
					var ev := CoachEvents.roll(c, rv)
					for id in IDS:
						if fit[id]:
							fits[id] += 1
							if String(ev.get("id", "")) == id:
								chosen[id] += 1
				c.end_week()
				if c.phase == "cuts":
					c.phase = "done"
	print("games %d" % games)
	for id in IDS:
		print("  %-18s fits %4d (%.1f%% of games)  drawn when it fits %.3f" % [id, fits[id], 100.0 * fits[id] / maxf(1, games), float(chosen[id]) / maxf(1, fits[id])])
	Game.career = null
	for on in [false, true]:
		CoachEvents.cpu_coaching = on
		var m: Dictionary = load("res://tests/hot_balance_test.gd").new().measure(seasons, [PlayerForm.HOT_STAR_ACQUISITION_MULTIPLIER], [811, 812, 813, 814])[0]
		print("  CPU coaching %s: CPU first stars %d" % ["ON " if on else "OFF", int(m.cpu_first)])
	CoachEvents.cpu_coaching = true

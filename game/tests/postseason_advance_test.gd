extends RefCounted
## The automatic postseason advance: out of a tournament with nothing left to play, the rest is
## simmed at once (Career.advance_postseason): FELL JUST SHORT! into the NCSA after a conference
## tournament loss with a bid, or OH NO! then the season's own review once the season's done;
## a title keeps CHAMPIONS!. Never a game of yours simmed by it, never a popup twice.
##   godot --headless --path game -- --test postseason_advance
##   godot --path game --resolution 960x540 -- --test postseason_advance_png <dir>

var r

func _frames(n: int) -> void:
	for _i in n:
		await r.get_tree().process_frame

static func _schools(strong: bool) -> Array:
	var s: Array = Colleges.SCHOOLS.duplicate()
	s.sort_custom(func(a, b): return float(a.ovr) > float(b.ovr) if strong else float(a.ovr) < float(b.ovr))
	return s.slice(0, 4).map(func(x): return String(x.short))

static func _my_played(c: Career) -> int:
	var n := 0
	for rd in c.schedule:
		n += c.my_games(rd).filter(func(g): return g.r != null).size()
	return n

## Plays a season as the hub would: your games by the sim, SIM WEEK on a week without one, the
## advance whenever it's due, until `stop` says so (or the season ends). Checks on the way that
## the advance never plays a game of yours, and that a conference week never waits on SIM WEEK
## once you're out of it.
func _play(c: Career, stop: Callable) -> void:
	var guard := 400
	while c.phase == "season" and guard > 0 and not stop.call(c):
		guard -= 1
		if c.advance_due():
			var mine := _my_played(c)
			c.advance_postseason()
			r.check(_my_played(c) == mine, "the advance never plays a game of yours")
			r.check(c.phase != "season" or c.has_game() or not c.advance_due(), "the advance stops at a game of yours, or runs out the season")
		elif c.has_game():
			c.sim_my_game()
			c.close_postgame()
		else:
			c.sim_week_without_me()
			c.end_week()

static func _lost_conf(c: Career) -> bool:
	for rd in c.schedule:
		for g in c.my_games(rd):
			if g.r != null and String(rd.kind).begins_with("conf_") and Schedule.loser(g) == c.school:
				return true
	return false

static func _played_nat(c: Career) -> bool:
	for rd in c.schedule:
		if String(rd.kind).begins_with("nat_") and c.my_games(rd).any(func(g): return g.r != null):
			return true
	return false

## A career out of its conference tournament and into the NCSA (before any NCSA game).
func _find_short() -> Career:
	for school in _schools(true):
		for seed_value in range(40, 52):
			var c := Career.new_game(school, "A", "B", seed_value)
			c.sandbox = true
			_play(c, func(x: Career): return x.fell_short_pending() or _played_nat(x) or (x.week < x.schedule.size() and String(x.cur().kind).begins_with("nat_")))
			c.advance_postseason()   # (the hub's own call: it notes FELL JUST SHORT!)
			if c.fell_short_pending():
				return c
	return null

func run(runner) -> void:
	r = runner
	print("automatic postseason advance")
	Store.reset_for_tests()
	await _not_selected()
	await _fell_short()
	await _ncsa_loss()
	await _dev_preview()
	Game.career = null
	Game.goto("title")
	await _frames(2)

## Lost in the conference tournament, no bid: the conference tournament and the whole NCSA at once,
## then OH NO! and the season's own review.
func _not_selected() -> void:
	var c: Career = null
	for school in _schools(false):
		var x := Career.new_game(school, "A", "B", 21)
		x.sandbox = true
		_play(x, func(y: Career): return y.week < y.schedule.size() and String(y.cur().kind).begins_with("conf_") and y.advance_due())
		if x.phase == "season" and _lost_conf(x):
			c = x
			break
	if c == null:
		r.check(false, "not selected: no weak school lost in its conference tournament")
		return
	var wk := c.week
	r.check(c.advance_due(), "A: out of the conference tournament: the advance is due (week %d)" % wk)
	var hist := c.history.size()
	Game.career = c
	for q in c.upgrades_due():
		Development.ai_spend(q)
	Game.goto("hub")
	await _frames(4)
	r.check(c.phase == "done", "A: the hub sims to the off-season at once (%s)" % c.phase)
	r.check(String(c.season.get("champion", "")) != "", "A: the NCSA champion is decided")
	r.check(c.schedule.all(func(rd): return rd.games.all(func(g): return g.r != null)), "A: every postseason game has a result")
	r.check(c.history.size() == hist + 1, "A: the season in the history once")
	r.check(not c.fell_short_pending(), "A: no FELL JUST SHORT!")
	r.check(Game.current_name == "season_over", "A: OH NO! (%s)" % Game.current_name)
	r.check(String(c.elim.get("round", "")) == "NOT SELECTED FOR THE NCSA CHAMPIONSHIP", "A: it reads NOT SELECTED (%s)" % String(c.elim.get("round", "")))
	r.check(String(c.elim.get("kind", "")).begins_with("conf_"), "A: the conference loss is the last game shown")
	c.queue.push_front({"type": "info", "title": "X", "text": "a note queued ahead of the review"})
	var btn: Button = Game.current_screen.find_child("ViewSeasonReview", true, false)
	btn.pressed.emit()
	await _frames(4)
	r.check(Game.current_name == "recap" and not Game.current_screen.live, "A: then the season's own review (%s)" % Game.current_name)
	Game.current_screen._done()
	await _frames(4)
	r.check(c.queue.all(func(q): return String(q.type) != "recap"), "A: the review is taken off the queue")
	r.check(Game.current_name != "season_over" and not c.elim_pending(), "A: OH NO! never twice")
	r.check(c.in_offseason(), "A: the off-season (recruiting, NEXT SEASON)")

## Lost in the conference tournament with a bid: FELL JUST SHORT! (never OH NO!), then the first
## NCSA game; seen once; saves.
func _fell_short() -> void:
	var c := _find_short()
	if c == null:
		print("  (no conference loss with an NCSA bid found: the FELL JUST SHORT! checks are skipped)")
		return
	r.check(not c.elim_pending() and not c.is_eliminated(), "B: never the OH NO! screen")
	r.check(String(c.cur().kind).begins_with("nat_"), "B: the conference tournament is all played (%s)" % String(c.cur().kind))
	r.check(c.week == 0 or c.schedule.slice(0, c.week).all(func(rd): return rd.games.all(func(g): return g.r != null)), "B: every week before has its results")
	var back := Career.from_dict(JSON.parse_string(JSON.stringify(c.to_dict())))
	r.check(back.fell_short_pending(), "B: it survives a save")
	Game.career = c
	for q in c.upgrades_due():
		Development.ai_spend(q)
	c.queue.clear()
	Game.goto("hub")
	await _frames(4)
	r.check(Game.current_name == "fell_short", "B: the hub opens FELL JUST SHORT! (%s)" % Game.current_name)
	var btn: Button = Game.current_screen.find_child("ContinueToNCSA", true, false)
	r.check(btn != null and btn.text.begins_with("CONTINUE TO NCSA TOURNAMENT"), "B: CONTINUE TO NCSA TOURNAMENT")
	btn.pressed.emit()
	await _frames(4)
	r.check(not c.fell_short_pending(), "B: seen once")
	r.check(c.has_game() and String(c.cur().kind).begins_with("nat_"), "B: your first NCSA game is up (%s)" % String(c.cur().kind))
	var due := not c.upgrades_due().is_empty()
	r.check(Game.current_name == "matchup" or (due and Game.current_name == "player"), "B: its matchup opens (or the upgrades earned on the way, first, as ever) (%s)" % Game.current_name)
	for q in c.upgrades_due():
		Development.ai_spend(q)
	c.queue.clear()
	Game.goto("hub")
	await _frames(4)
	r.check(Game.current_name == "hub", "B: the hub after it, no popup again (%s)" % Game.current_name)

## Knocked out of the NCSA: the rest of it at once, OH NO!, the review.
func _ncsa_loss() -> void:
	var c: Career = null
	for school in _schools(true):
		for seed_value in [61, 62, 63, 64]:
			var x := Career.new_game(school, "A", "B", seed_value)
			x.sandbox = true
			_play(x, func(y: Career): return (y.elim_pending() or y.champ_pending()) and not y.advance_due())
			if x.elim_pending() and String(x.elim.get("kind", "")).begins_with("nat_"):
				c = x
				break
		if c != null:
			break
	if c == null:
		print("  (no NCSA loss found: the NCSA checks are skipped)")
		return
	r.check(c.phase == "done", "C: knocked out of the NCSA: the season's simmed to the off-season (%s)" % c.phase)
	r.check(not c.is_eliminated(), "C: no SEASON OVER hub to sim from")
	r.check(String(c.season.get("champion", "")) != "" and String(c.season.champion) != c.school, "C: someone else is champion")
	Game.career = c
	for q in c.upgrades_due():
		Development.ai_spend(q)
	Game.goto("hub")
	await _frames(4)
	r.check(Game.current_name == "season_over", "C: OH NO! (%s)" % Game.current_name)
	Game.current_screen.find_child("ViewSeasonReview", true, false).pressed.emit()
	await _frames(4)
	r.check(Game.current_name == "recap" and not Game.current_screen.live, "C: the season's own review (%s)" % Game.current_name)

## Developer Tools' PREVIEW FELL JUST SHORT: opens the screen (a sample) and comes back.
func _dev_preview() -> void:
	Game.career = null
	var was: bool = Game.settings.get("dev_mode", false)
	Game.settings.dev_mode = true
	DevGate.try_unlock("8008")
	Game.goto("dev_settings")
	await _frames(3)
	var b: Button = Game.current_screen.find_child("PreviewFellShort", true, false)
	r.check(b != null, "D: Developer Tools has PREVIEW FELL JUST SHORT")
	if b != null:
		b.pressed.emit()
		await _frames(4)
		r.check(Game.current_name == "fell_short" and Game.current_screen.preview, "D: it opens the screen as a preview (%s)" % Game.current_name)
		Game.current_screen.find_child("ContinueToNCSA", true, false).pressed.emit()
		await _frames(4)
		r.check(Game.current_name == "dev_settings", "D: its button comes back to Developer Tools (%s)" % Game.current_name)
	DevGate.lock()
	Game.settings.dev_mode = was

## PNGs: FELL JUST SHORT!'s frames (a sample) and the not-selected OH NO!.
static func shots(runner, dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	Game.settings["dev_mode"] = true
	var lab = load("res://src/ui/screens/elim_lab.gd")
	var c := Career.new_game(_schools(true)[0], "A", "B", 5)
	c.sandbox = true
	Game.career = c
	for kind in ["conf_semi", "conf_final"]:
		Game.goto("fell_short", {"preview": true, "model": lab.short_sample(c, kind)})
		for _i in 3:
			await runner.get_tree().process_frame
		var scr = Game.current_screen
		for tt in [0.4, 1.0, 1.9, 2.7, 4.0]:
			scr.t = tt
			scr.art.queue_redraw()
			scr.go_btn.modulate.a = clampf((tt - scr.BTN_T) / 0.3, 0.0, 1.0)
			await runner.get_tree().process_frame
			await runner.get_tree().process_frame
			runner.get_viewport().get_texture().get_image().save_png("%s/fell_short_%s_%.1f.png" % [dir, kind, tt])
	Game.goto("season_over", {"preview": true, "model": lab.sample(c, "missed")})
	for _i in 3:
		await runner.get_tree().process_frame
	Game.current_screen.t = 4.0
	await runner.get_tree().process_frame
	await runner.get_tree().process_frame
	runner.get_viewport().get_texture().get_image().save_png(dir + "/oh_no_missed.png")
	Game.career = null
	print("shots in ", dir)

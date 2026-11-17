extends RefCounted
## POSTGAME PLAYER DEVELOPMENT (player_development.gd): the career's before/after snapshot of
## your roster round the game's one XP award (Career.dev_snapshot), the screen between the game
## summary and the coaching event / hub for SIM TO END (the matchup's) and a simulated game, every
## roster player a row, the bar's path across several thresholds, SKIP, and that nothing about
## any player changes because the screen opened, played, skipped or moved on.
##   godot --headless --path game -- --test player_dev
##   godot --path game --resolution 1440x810 -- --test player_dev_png <dir>   (frames, PNGs)

const SCREEN := "res://src/ui/screens/player_development.gd"

var r
var tree: SceneTree

func run(runner) -> void:
	r = runner
	tree = r.get_tree()
	print("player development")
	var kept_career = Game.career
	_path_math()
	await _sim_to_end_flow()
	await _simmed_game()
	Game.career = kept_career
	Game.history.clear()
	Game.goto("title", {}, false)
	await tree.process_frame

func run_png(runner, dir: String) -> void:
	r = runner
	tree = r.get_tree()
	DirAccess.make_dir_recursive_absolute(dir)
	var c := _career(77)
	Game.career = c
	_near_levels(c, 30)
	Game.goto("matchup")
	await _frames(4)
	Game.current_screen._sim_to_end()
	await _frames(6)
	Game.current_screen._continue()
	await _frames(6)
	for at in [0.3, 0.8, 1.6, 2.0, 2.2, 2.4, 2.6, 3.2, 9.0]:
		Game.goto("player_development", {"t": at, "freeze": true}, false)
		await _frames(6)
		await _shot(dir, "dev_t%02d" % int(at * 10.0))
	# scrolled to the bottom (the keepers)
	var scr = Game.current_screen
	scr._scroll_by(10000.0)
	await _frames(3)
	await _shot(dir, "dev_scrolled")
	# the real thing, playing, then skipped
	Game.goto("player_development", {"t": 0.0}, false)
	await tree.create_timer(1.9).timeout
	await _shot(dir, "dev_live_1_9")
	Game.current_screen.skip()
	await _frames(3)
	await _shot(dir, "dev_skipped")

# ------------------------------------------------------------------ helpers
func _career(seed_value: int) -> Career:
	var c := Career.new_setup(seed_value).begin("CULA", "Sam", "Rivera")
	c.queue.clear()
	c.hot_tip = false
	return c

func _frames(n: int = 3) -> void:
	for _i in n:
		await tree.process_frame

func _shot(dir: String, name: String) -> void:
	await RenderingServer.frame_post_draw
	r.get_viewport().get_texture().get_image().save_png(dir.path_join(name + ".png"))
	print("  shot ", name)

## Puts some of the roster a few XP short of their next token (and one of them two tokens' worth
## short of it), so a game's XP is sure to show level-ups. Only XP banked: no attribute moves.
func _near_levels(c: Career, short := 6) -> void:
	var i := 0
	for p in c.team().roster:
		Development.ensure(p)
		if i % 2 == 0 and p.tokens < Development.boxes_left(p):
			p.xp = maxi(0, Development.xp_needed(p) - short - i * 7)
		i += 1

## Everything about the roster's development, to compare.
static func _dev_state(c: Career) -> String:
	var out := []
	for p in c.team().roster:
		out.append([p.id, p.xp, p.xp_level, p.xp_start, p.tokens, Attributes.overall(p)])
	return JSON.stringify(out)

# ------------------------------------------------------------------ the bar's path
func _path_math() -> void:
	var scr = load(SCREEN).new()
	# half full, two tokens, a quarter into the next: 0.5 + 1 + 0.25 of a bar, thresholds at 0.5, 1.5
	var row := {"f0": 0.5, "f1": 0.25, "levels": 2, "capped": false, "hold": false}
	scr._path(row)
	r.check(is_equal_approx(float(row.dist), 1.75), "D1: two levels from half full to a quarter: 1.75 bars (%.3f)" % float(row.dist))
	r.check((row.cross as Array).size() == 2 and is_equal_approx(float(row.cross[0]), 0.5) and is_equal_approx(float(row.cross[1]), 1.5), "D2: thresholds at 0.5 and 1.5 bars")
	r.check(float(row.cross_t[0]) > scr.XP_IN and float(row.cross_t[1]) < scr.FILL_END and float(row.cross_t[0]) < float(row.cross_t[1]), "D3: both level-ups inside the fill, one after the other (%.2f, %.2f)" % [row.cross_t[0], row.cross_t[1]])
	scr.t = scr.XP_IN
	var st0: Dictionary = scr._bar_state(row)
	r.check(is_equal_approx(float(st0.fill), 0.5) and int(st0.crossed) == 0, "D4: the bar starts where it stood before the game")
	scr.t = (float(row.cross_t[0]) + float(row.cross_t[1])) * 0.5
	var st1: Dictionary = scr._bar_state(row)
	r.check(int(st1.crossed) == 1 and float(st1.fill) < 1.0 and float(st1.old) == 0.0, "D5: past the first threshold it starts over, all of it new")
	scr.t = scr.END
	var st2: Dictionary = scr._bar_state(row)
	r.check(int(st2.crossed) == 2 and is_equal_approx(float(st2.fill), 0.25), "D6: it ends at his real share of the next token (%.3f)" % float(st2.fill))
	var hold := {"f0": 0.8, "f1": 1.0, "levels": 1, "capped": false, "hold": true}
	scr._path(hold)
	scr.t = scr.END
	r.check(is_equal_approx(float(scr._bar_state(hold).fill), 1.0), "D7: XP that took him to his potential: the bar stays full")
	var none := {"f0": 0.2, "f1": 0.35, "levels": 0, "capped": false, "hold": false}
	scr._path(none)
	scr.t = scr.END
	r.check(is_equal_approx(float(scr._bar_state(none).fill), 0.35) and (none.cross as Array).is_empty(), "D8: no level: from 0.20 to 0.35, no level-up")
	scr.free()

# ------------------------------------------------------------------ SIM TO END, end to end
func _sim_to_end_flow() -> void:
	var c := _career(41)
	Game.career = c
	_near_levels(c)
	var pre := Career.dev_snapshot(c.team())
	Game.goto("matchup")
	await _frames(4)
	Game.current_screen._sim_to_end()
	await _frames(6)
	var s: Dictionary = c.last_summary
	var dev: Dictionary = s.get("dev", {})
	r.check(Game.current_name == "game_summary" and not dev.is_empty(), "S1: SIM TO END's summary carries the development snapshot")
	if dev.is_empty():
		return
	var before: Dictionary = dev.before
	var after: Dictionary = dev.after
	r.check(before.size() == c.team().roster.size() and after.size() == c.team().roster.size(), "S2: every roster player is in both snapshots (%d)" % c.team().roster.size())
	var same := true
	for id in pre:
		same = same and int(pre[id].xp) == int(before[id].xp) and int(pre[id].idx) == int(before[id].idx) and int(pre[id].tokens) == int(before[id].tokens)
	r.check(same, "S3: 'before' is the roster as it stood before the game")
	var now := Career.dev_snapshot(c.team())
	r.check(JSON.stringify(now) == JSON.stringify(after), "S4: 'after' is the roster as it stands now")
	# the tokens each earned are exactly the levels the screen will show
	var ok := true
	var any_level := false
	for id in dev.xp:
		var lv := int(after[id].idx) - int(before[id].idx)
		ok = ok and lv == int(dev.xp[id].tokens)
		any_level = any_level or lv > 0
	r.check(ok, "S5: levels gained = tokens the game paid, for everyone")
	r.check(any_level, "S6: (players a few XP short) somebody levels up")
	var shot_ok := true
	var any_shot := false
	for id in dev.lines:
		var ln: Dictionary = dev.lines[id]
		shot_ok = shot_ok and ln.has("sh") and int(ln.get("g", 0)) <= int(ln.get("sh", 0))
		any_shot = any_shot or int(ln.get("sh", 0)) > 0
	r.check(any_shot and shot_ok, "S6b: every player who played has his shots on the sheet's lines, subs too (goals never more than shots)")
	var state := _dev_state(c)
	Game.current_screen._continue()
	await _frames(6)
	r.check(Game.current_name == "player_development", "S7: the summary's CONTINUE opens PLAYER DEVELOPMENT")
	var scr = Game.current_screen
	r.check(scr.rows.size() == c.team().roster.size(), "S8: a row for every player on the roster, subs and keepers too (%d)" % scr.rows.size())
	r.check(scr.keeper_at >= 0 and (scr.rows[scr.keeper_at].p as PoloPlayer).is_keeper(), "S9: the keepers in their own section")
	var zero_kept := false
	for row in scr.rows:
		zero_kept = zero_kept or not bool(row.played)
	r.check(zero_kept or scr.rows.size() <= 7, "S10: players who didn't play are still listed")
	var total := 0
	for id in dev.xp:
		total += int(dev.xp[id].xp)
	r.check(int(scr.totals.xp) == total, "S11: TOTAL TEAM XP is the XP the game paid (%d)" % total)
	r.check(scr.t >= scr.END, "S12: in tests (as with Reduce Motion) the finished sheet")
	# played through from the start, then skipped
	Game.goto("player_development", {"t": 0.0}, false)
	await _frames(4)
	scr = Game.current_screen
	await tree.create_timer(0.4).timeout
	r.check(scr.t > 0.0 and scr.t < scr.END and scr.skip_btn.visible, "S13: it plays, SKIP ANIMATION showing")
	scr.skip()
	r.check(scr.t >= scr.END and not scr.skip_btn.visible, "S14: SKIP ANIMATION: straight to the end")
	r.check(_dev_state(c) == state, "S15: opening, playing and skipping change nobody's XP, tokens or attributes")
	scr._continue()
	await _frames(6)
	r.check(Game.current_name in ["coach_event", "hub", "player"], "S16: CONTINUE ends the postgame: a coaching event, or on (%s)" % Game.current_name)
	r.check(_dev_state(c) == state, "S17: ...still nothing awarded twice")
	# a reopened summary settles nothing again and shows the same
	var again := c.finish_my_game({"uid": c.settled_box})
	r.check(again == c.last_summary, "S18: the same box settles once")
	c.close_postgame()
	r.check(c.last_dev.is_empty(), "S19: the postgame over: the snapshot dropped")

# ------------------------------------------------------------------ a simulated game
func _simmed_game() -> void:
	var c := _career(9)
	Game.career = c
	var out := c.sim_my_game()
	c.last_summary = out
	r.check(not (out.get("dev", {}) as Dictionary).is_empty(), "M1: a simulated game's summary carries the snapshot")
	Game.goto("player_development", {}, false)
	await _frames(4)
	var scr = Game.current_screen
	r.check(Game.current_name == "player_development" and scr.rows.size() == c.team().roster.size(), "M2: its sheet lists the whole roster")
	UI.drawn_log = []
	scr._redraw()
	await _frames(3)
	var log: Array = UI.drawn_log
	UI.drawn_log = null
	r.check("%" in log and "SV%" in log and "GOALKEEPERS" in log and not "TOTAL TEAM XP" in log and not "COACH'S NOTES" in log, "M3: the field and keeper headings are drawn, no notes under the sheet")
	# no summary data: nothing to show, on to the review
	c.last_summary.erase("dev")
	Game.goto("player_development", {}, false)
	await _frames(6)
	r.check(Game.current_name in ["coach_event", "hub", "player"], "M4: a game with no snapshot ends the postgame as before (%s)" % Game.current_name)
	c.close_postgame()

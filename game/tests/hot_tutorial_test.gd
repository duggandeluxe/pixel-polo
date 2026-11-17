extends RefCounted
## THE FIRST HOT STAR TUTORIAL (HotTutorial): queued by the first of yours to heat up, once a
## dynasty save (saved flag), shown only at home and never over a dialog or the career tour; the
## whole walk (announcement, the real ROSTER button, his card, the bonuses, the HOT limit, GOT IT!);
## SKIP; an older save; the real bonus numbers; nothing of Heating Up changed.
##   godot --headless --path game -- --test hot_tutorial
##   godot --path game --resolution 1440x810 -- --test hot_tutorial_png <dir>   (every step, PNGs)

var r
var tree: SceneTree

func run(runner) -> void:
	r = runner
	tree = r.get_tree()
	print("hot tutorial")
	var kept: Dictionary = Game.settings.duplicate(true)
	var kept_career = Game.career
	Game.settings.career_tour = CareerTour.SEEN
	HotTutorial.force_in_tests = true
	_queue_rules()
	_save_rules()
	await _start_rules()
	await _walkthrough(null)
	await _skip()
	await _waits_for_dialog()
	await _ends_quietly()
	await _preview()
	HotTutorial.force_in_tests = false
	_end()
	Game.settings = kept
	Game.career = kept_career
	Game.history.clear()
	Game.goto("title", {}, false)
	await tree.process_frame

func run_png(runner, dir: String) -> void:
	r = runner
	tree = r.get_tree()
	var kept: Dictionary = Game.settings.duplicate(true)
	Game.settings.career_tour = CareerTour.SEEN
	HotTutorial.force_in_tests = true
	DirAccess.make_dir_recursive_absolute(dir)
	await _walkthrough(dir)
	# a keeper and a VERY HOT player too (their own attributes and words)
	await _walkthrough(dir, true)
	HotTutorial.force_in_tests = false
	_end()
	Game.settings = kept

# ------------------------------------------------------------------ helpers
func _career(seed_value: int) -> Career:
	var c := Career.new_setup(seed_value).begin("CULA", "Sam", "Rivera")
	c.queue.clear()
	c.hot_tip = false
	return c

func _frames(n: int = 3) -> void:
	for _i in n:
		await tree.process_frame

func _tut() -> HotTutorial:
	return HotTutorial.current()

func _end() -> void:
	var t := _tut()
	if t != null:
		t.get_parent().remove_child(t)
		t.free()

func _press(n: Node) -> void:
	if n is BaseButton:
		(n as BaseButton).pressed.emit()

func _btn(nm: String) -> Node:
	var t := _tut()
	return null if t == null else t.find_child(nm, true, false)

## A field starter of yours, made HOT (heat 1, a run of three GOOD games), as a game would.
func _heat(c: Career, keeper := false, very := false) -> PoloPlayer:
	var seven := c.team().starters()
	var p: PoloPlayer = seven[0] if keeper else seven[3]
	p.form = [1, 1, 1, 1] if very else [1, 1, 1]
	p.heat = 2 if very else 1
	return p

func _home(c: Career) -> void:
	_end()
	Game.career = c
	Game.history.clear()
	Game.goto("hub", {}, false)
	await _frames(4)

func _rows(c: Career) -> Array:
	var out: Array = []
	for p: PoloPlayer in c.team().starters():
		out.append({"p": p, "before": PlayerForm.NORMAL, "pm": 0.0, "raw": 0.0})
	return out

# ------------------------------------------------------------------ the queue
func _queue_rules() -> void:
	var c := _career(61)
	var rows := _rows(c)
	HotTutorial.note_graded(c, rows)
	r.check(c.hot_tutorial_pid == -1, "Q1: nobody heated up: nothing queued")
	# two heat up in the same game: the better game is the first
	var a: PoloPlayer = rows[2].p
	var b: PoloPlayer = rows[4].p
	a.heat = 1
	b.heat = 1
	rows[2].pm = 6.0
	rows[4].pm = 9.0
	HotTutorial.note_graded(c, rows)
	r.check(c.hot_tutorial_pid == b.id, "Q2: several heat up after one game: the best game of them is the one")
	# a later game: still the first while he's HOT
	var d: PoloPlayer = rows[5].p
	d.heat = 1
	rows[5].pm = 20.0
	rows[4].before = PlayerForm.HOT
	HotTutorial.note_graded(c, rows)
	r.check(c.hot_tutorial_pid == b.id, "Q3: later ones never take the first one's place")
	# an already-HOT player moving up doesn't count as new
	var c2 := _career(62)
	var rows2 := _rows(c2)
	(rows2[3].p as PoloPlayer).heat = 2
	rows2[3].before = PlayerForm.HOT
	HotTutorial.note_graded(c2, rows2)
	r.check(c2.hot_tutorial_pid == -1, "Q4: HOT to VERY HOT isn't a first heat-up")
	c2.hot_tutorial_seen = true
	rows2[3].before = PlayerForm.NORMAL
	HotTutorial.note_graded(c2, rows2)
	r.check(c2.hot_tutorial_pid == -1, "Q5: seen: nothing is queued again")
	# reading only: the rows' heat is what grading left
	r.check(a.heat == 1 and b.heat == 1 and d.heat == 1, "Q6: queueing changes nobody's heat")

func _save_rules() -> void:
	var c := _career(63)
	c.hot_tutorial_seen = true
	c.hot_tutorial_pid = 7
	var back := Career.from_dict(JSON.parse_string(JSON.stringify(c.to_dict())))
	r.check(back.hot_tutorial_seen and back.hot_tutorial_pid == 7, "S1: the flag is saved with the dynasty")
	var d: Dictionary = c.to_dict()
	d.erase("hot_tutorial_seen")
	d.erase("hot_tutorial_pid")
	var old := Career.from_dict(JSON.parse_string(JSON.stringify(d)))
	r.check(not old.hot_tutorial_seen and old.hot_tutorial_pid == -1, "S2: an older save hasn't seen it")
	r.check(not Game.settings.has("hot_tutorial_seen"), "S3: it's per dynasty, never a global setting")

func _start_rules() -> void:
	var c := _career(64)
	await _home(c)
	r.check(_tut() == null, "T1: nobody HOT: no tutorial")
	# an older save: someone HOT, nothing queued
	var p := _heat(c)
	await _home(c)
	var t := _tut()
	r.check(t != null and t.pid == p.id, "T2: an older save with a HOT player gets it, about him")
	_end()
	c.hot_tutorial_seen = true
	await _home(c)
	r.check(_tut() == null, "T3: seen: never again in that dynasty")
	# another dynasty is its own
	var c2 := _career(65)
	_heat(c2)
	await _home(c2)
	r.check(_tut() != null, "T4: another dynasty save gets its own")
	_end()
	# the career tour first
	var c3 := _career(66)
	_heat(c3)
	var tour := CareerTour.new()
	tour.name = CareerTour.NODE_NAME
	tour.uid = c3.uid
	Game.career = c3
	Game.overlay.add_child(tour)
	r.check(HotTutorial.maybe_start() == null, "T5: never over the first-career tour")
	Game.overlay.remove_child(tour)
	tour.free()

# ------------------------------------------------------------------ the whole walk
func _walkthrough(dir, keeper := false) -> void:
	var c := _career(71 if not keeper else 72)
	var p := _heat(c, keeper, keeper)
	c.hot_tutorial_pid = p.id
	var before := JSON.stringify(c.team().to_dict())
	var pre := "k_" if keeper else ""
	await _home(c)
	var t := _tut()
	r.check(t != null, "W1: home with a HOT player: it starts")
	if t == null:
		return
	await _frames(HotTutorial.SETTLE_FRAMES + 2)
	# the announcement
	r.check(t.step_id() == "intro" and t.center_layer != null and t.center_layer.visible, "W2: the announcement is up")
	var title := _btn("TutTitle") as Label
	var text := _btn("TutText") as Label
	r.check(title != null and title.text == "YOUR PLAYER IS HEATING UP!", "W3: YOUR PLAYER IS HEATING UP!")
	var full := ("%s %s" % [p.first, p.last]).strip_edges().to_upper()
	r.check(text != null and text.text.begins_with(full + " has earned"), "W4: with his name (%s)" % (text.text if text else "-"))
	r.check(_btn("HotStar") != null and _btn("TutContinue") != null and _btn("TutSkip") != null, "W5: the big star, CONTINUE and SKIP")
	await _shot(dir, pre + "1_intro")
	_press(_btn("TutContinue"))
	await _frames(HotTutorial.SETTLE_FRAMES + 2)
	# the ROSTER button
	r.check(t.step_id() == "nav" and Game.current_name == "hub", "W6: CONTINUE: still home, ROSTER next")
	var nav := Game.current_screen.find_child("Nav_roster", true, false) as Control
	r.check(nav != null and t.has_hole and t.hole.encloses(nav.get_global_rect()), "W7: the ROSTER button is highlighted")
	r.check(not t.lid.visible, "W8: ...and takes the tap")
	r.check(t.box != null and not t.box.get_global_rect().intersects(t.hole), "W9: the box is clear of it")
	r.check(t.box.find_child("TutNext", true, false) == null, "W10: no NEXT: the player has to tap ROSTER")
	await _shot(dir, pre + "2_nav")
	await _frames(10)
	r.check(Game.current_name == "hub", "W11: it never opens the Roster by itself")
	_press(nav)
	await _frames(HotTutorial.SETTLE_FRAMES + 6)
	r.check(Game.current_name == "roster" and t.step_id() == "player", "W12: the real ROSTER tap: on to his card")
	r.check(not c.hot_tip or Game.overlay.get_children().filter(func(n): return n != t and n is Control and (n as Control).mouse_filter == Control.MOUSE_FILTER_STOP).is_empty(),
		"W13: the roster's old HOT tip doesn't pop over it")
	var cd := t.card()
	r.check(cd != null and t.has_hole and t.hole.encloses(cd.get_global_rect()), "W14: his card is highlighted")
	r.check(t.lid.visible, "W15: ...look-only (no page, no drag mid-tutorial)")
	r.check(t.badge_rect().size.x > 0.0 and t.red_star_rect().size.x > 0.0, "W16: his burning red stars are outlined")
	r.check(t.box != null and t.box.find_child("TutNext", true, false) != null, "W17: NEXT")
	await _shot(dir, pre + "3_player")
	_press(t.box.find_child("TutNext", true, false))
	await _frames(4)
	# the bonuses: the game's own numbers, his own attributes
	r.check(t.step_id() == "bonuses", "W18: HEATING UP BONUSES")
	var b1 := t.find_child("TutBonus1", true, false) as Label
	var b2 := t.find_child("TutBonus2", true, false) as Label
	r.check(b1 != null and b1.text.begins_with("+%.1f to all four" % Attributes.HOT_PER_STAR), "W19: HOT: +%.1f to all four attributes" % Attributes.HOT_PER_STAR)
	r.check(b2 != null and b2.text.begins_with("+%.1f to all four" % (Attributes.HOT_PER_STAR * 2)), "W20: VERY HOT: +%.1f" % (Attributes.HOT_PER_STAR * 2))
	r.check(is_equal_approx(HotTutorial.bonus_stars(1), PlayerForm.FORM_STARS[PlayerForm.HOT]) and is_equal_approx(HotTutorial.bonus_stars(2), PlayerForm.FORM_STARS[PlayerForm.VERY_HOT]), "W21: the effective stars are PlayerForm's")
	var grid := t.find_child("TutAttrs", true, false) as GridContainer
	var cells: Array = grid.get_children().map(func(l): return (l as Label).text) if grid != null else []
	var keys := Attributes.keys_for(p)
	var ok := cells.size() == 4 * (keys.size() + 1)
	for i in keys.size():
		if not ok:
			break
		var k: String = keys[i]
		var base := Attributes.base_play_value(p, k)
		var row := cells.slice(4 * (i + 1), 4 * (i + 2))
		ok = row[0] == String(Attributes.NAMES[k]).to_upper() and row[1] == "%.1f" % base \
			and row[2] == "%.1f" % (base + Attributes.HOT_PER_STAR) and row[3] == "%.1f" % (base + 2.0 * Attributes.HOT_PER_STAR)
	r.check(ok, "W22: his own %s attributes at HOT and VERY HOT (%s)" % ["keeper" if keeper else "field", cells])
	# what the table shows is what he plays at
	var lvl := p.heat
	r.check(is_equal_approx(Attributes.play_value(p, keys[0]), Attributes.base_play_value(p, keys[0]) + Attributes.HOT_PER_STAR * lvl), "W23: the game plays him at those numbers")
	await _shot(dir, pre + "4_bonuses")
	_press(t.box.find_child("TutBack", true, false))
	await _frames(3)
	r.check(t.step_id() == "player", "W24: BACK")
	_press(t.box.find_child("TutNext", true, false))
	await _frames(3)
	_press(t.box.find_child("TutNext", true, false))
	await _frames(4)
	r.check(t.step_id() == "limit", "W25: the HOT limit")
	var cnt := t.find_child("TutHotCount", true, false) as Label
	r.check(cnt != null and cnt.text == "YOUR TEAM NOW: %d / %d HOT" % [PlayerForm.hot_count(c.team()), PlayerForm.HOT_SLOTS], "W26: your team's HOT count, of %d" % PlayerForm.HOT_SLOTS)
	await _shot(dir, pre + "5_limit")
	_press(t.box.find_child("TutNext", true, false))
	await _frames(4)
	r.check(t.step_id() == "final" and _btn("TutGotIt") != null, "W27: KEEP THE FIRE GOING! with GOT IT!")
	await _shot(dir, pre + "6_final")
	r.check(not c.hot_tutorial_seen, "W28: not marked seen until it's done")
	_press(_btn("TutGotIt"))
	await _frames(3)
	r.check(_tut() == null and Game.current_name == "roster", "W29: GOT IT!: closed, the Roster as it was")
	r.check(c.hot_tutorial_seen, "W30: seen for good in this dynasty")
	r.check(JSON.stringify(c.team().to_dict()) == before, "W31: nobody's heat, form, stars or lineup changed")
	Game.goto("hub", {}, false)
	await _frames(4)
	r.check(_tut() == null, "W32: never again")

func _shot(dir, nm: String) -> void:
	if dir == null:
		return
	await _frames(8)
	tree.root.get_viewport().get_texture().get_image().save_png("%s/hot_%s.png" % [dir, nm])

# ------------------------------------------------------------------ SKIP, dialogs, leaving
func _skip() -> void:
	var c := _career(81)
	_heat(c)
	await _home(c)
	await _frames(HotTutorial.SETTLE_FRAMES + 2)
	_press(_btn("TutSkip"))
	await _frames(3)
	r.check(_tut() == null and c.hot_tutorial_seen, "K1: SKIP: it ends, seen for that dynasty")
	await _home(c)
	r.check(_tut() == null, "K2: skipped: never again")
	# skip from the Roster part too
	var c2 := _career(82)
	_heat(c2)
	await _home(c2)
	await _frames(HotTutorial.SETTLE_FRAMES + 2)
	_press(_btn("TutContinue"))
	await _frames(HotTutorial.SETTLE_FRAMES + 2)
	_press(Game.current_screen.find_child("Nav_roster", true, false))
	await _frames(HotTutorial.SETTLE_FRAMES + 6)
	var t := _tut()
	_press(t.box.find_child("TutSkip", true, false) if t != null and t.box != null else null)
	await _frames(3)
	r.check(_tut() == null and c2.hot_tutorial_seen, "K3: SKIP on the Roster too")

func _waits_for_dialog() -> void:
	var c := _career(91)
	_heat(c)
	await _home(c)
	var layer := Game.dialog("POSTGAME", "A result.", [["OK", Callable(), "primary"]])
	await _frames(HotTutorial.SETTLE_FRAMES + 4)
	var t := _tut()
	r.check(t != null and (t.center_layer == null or not t.center_layer.visible), "D1: hidden while a dialog is up")
	for ch in Game.overlay.get_children():
		if ch != t and ch is Control and (ch as Control).mouse_filter == Control.MOUSE_FILTER_STOP:
			ch.queue_free()
	if is_instance_valid(layer):
		layer.queue_free()
	await _frames(HotTutorial.SETTLE_FRAMES + 4)
	r.check(t != null and t.center_layer != null and t.center_layer.visible and t.step_id() == "intro", "D2: the dialogs closed: the announcement shows")
	# the home screen's queue (a weekly award still to click through): it waits for all of it
	c.queue.append({"type": "info", "title": "AWARD", "text": "Still to see."})
	await _frames(HotTutorial.SETTLE_FRAMES + 4)
	r.check(t.center_layer == null or not t.center_layer.visible, "D3: hidden while the hub's queue still has items")
	var aw := WeeklyAwardShow.new()
	aw.mouse_filter = Control.MOUSE_FILTER_STOP
	c.queue.clear()
	Game.current_screen.add_child(aw)
	await _frames(HotTutorial.SETTLE_FRAMES + 4)
	r.check(t.center_layer == null or not t.center_layer.visible, "D4: hidden while an award celebration is on the screen")
	aw.free()
	await _frames(HotTutorial.SETTLE_FRAMES + 4)
	r.check(t.center_layer != null and t.center_layer.visible, "D5: everything clicked through: it shows")

func _ends_quietly() -> void:
	var c := _career(95)
	_heat(c)
	await _home(c)
	r.check(_tut() != null, "E1: up")
	Game.goto("title", {}, false)
	await _frames(3)
	r.check(_tut() == null and not c.hot_tutorial_seen, "E2: left for the title screen: it stops, not marked seen")
	await _home(c)
	r.check(_tut() != null, "E3: ...and comes back at home")
	_end()

# ------------------------------------------------------------------ the developer preview
func _preview() -> void:
	_end()
	var c := _career(97)
	c.hot_tutorial_seen = true   # (seen already: a preview plays anyway)
	Game.career = c
	Game.history.clear()
	Game.goto("settings", {}, false)
	await _frames(3)
	var before := JSON.stringify(c.to_dict())
	var t := HotTutorial.preview()
	await _frames(HotTutorial.SETTLE_FRAMES + 8)
	r.check(t != null and t.preview_mode and Game.current_name == "hub" and t.step_id() == "intro", "P1: PREVIEW opens the home screen with the announcement")
	if t == null:
		return
	var p := t.player()
	r.check(p != null and p.heat == 0 and t.heat_of(p) == 1, "P2: nobody HOT: shown HOT for the preview only")
	_press(_btn("TutContinue"))
	await _frames(HotTutorial.SETTLE_FRAMES + 2)
	_press(Game.current_screen.find_child("Nav_roster", true, false))
	await _frames(HotTutorial.SETTLE_FRAMES + 6)
	var forms = Game.current_screen.get("dev_forms")
	r.check(Game.current_name == "roster" and forms is Dictionary and String(forms.get(p.id, "")) == PlayerForm.HOT, "P3: his card shows HOT (display only)")
	r.check(t.badge_rect().size.x > 0.0 and t.red_star_rect().size.x > 0.0, "P4: his burning red stars highlighted")
	for _i in 3:
		_press(t.box.find_child("TutNext", true, false))
		await _frames(4)
	r.check(t.step_id() == "final", "P5: the whole walk")
	_press(_btn("TutGotIt"))
	await _frames(3)
	r.check(_tut() == null and p.heat == 0 and not c.hot_tip, "P6: done: nobody's heat or tips touched")
	r.check(JSON.stringify(c.to_dict()) == before, "P7: the dynasty is exactly as it was (nothing marked or saved)")
	var dev_src: GDScript = load("res://src/ui/screens/dev_settings.gd")
	r.check(dev_src != null and dev_src.can_instantiate() and dev_src.source_code.contains("PreviewHotTutorial"), "P8: Developer Tools has PREVIEW HOT STAR TUTORIAL")

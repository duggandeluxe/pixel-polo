extends RefCounted
## The Dynasty Hub's door on the home screen (hub.gd): the whole team card is one button, a blue
## DYNASTY HUB tab hanging from its bottom-right edge, a lighter face on hover, a pixel press,
## and the first-time hint (CLICK HERE TO VIEW YOUR DYNASTY HUB!) until the hub is first opened.
##   godot --headless --path game -- --test hub_entry
##   godot --path game -- --test hub_entry_png <dir>      (16:9, 4:3 and ultrawide windows)

var r

func _frames(n: int) -> void:
	for _i in n:
		await r.get_tree().process_frame

static func _career() -> Career:
	var c := Career.new_game("WAGN", "Sam", "Rivera", 31)
	for _i in 2:
		while c.has_game():
			c.sim_my_game()
		for q in c.upgrades_due():
			Development.ai_spend(q)
		c.end_week()
	c.queue.clear()
	for q in c.upgrades_due():
		Development.ai_spend(q)
	return c

func _node(n: String) -> Node:
	return Game.current_screen.find_child(n, true, false) if Game.current_screen != null else null

func _rect(n: Node) -> Rect2:
	return (n as Control).get_global_rect() if n != null else Rect2()

func run(runner) -> void:
	r = runner
	print("hub entry")
	Store.reset_for_tests()
	# ---- the save flag: a new career hasn't seen the hub; an older save (no flag) has
	var c := _career()
	r.check(not c.hub_seen, "4: a new dynasty hasn't opened the Dynasty Hub yet")
	var d: Dictionary = JSON.parse_string(JSON.stringify(c.to_dict()))
	r.check(d.has("hub_seen") and not Career.from_dict(d).hub_seen, "4: the flag is saved")
	d.erase("hub_seen")
	r.check(Career.from_dict(d).hub_seen, "4: a save from before the hint never shows it")
	# ---- the home screen (a first-ever dynasty: no other has claimed the hint)
	var hint_owner0 = Game.settings.get("hub_hint_uid", "")
	Game.settings.hub_hint_uid = ""
	Game.career = c
	Game.goto("hub")
	await _frames(4)
	var entry = _node("HubEntry")
	var card = _node("TeamCard")
	var tab = _node("HubTab")
	var hint = _node("HubHint")
	r.check(entry is Button and card != null and tab is Button, "1, 3: the team card is a button, with a DYNASTY HUB tab")
	r.check(entry != null and entry.mouse_default_cursor_shape == Control.CURSOR_POINTING_HAND and tab.mouse_default_cursor_shape == Control.CURSOR_POINTING_HAND, "3: a pointer over either")
	r.check(entry != null and _rect(entry).encloses(_rect(card)) and _rect(card).encloses(_rect(entry)), "1: the whole card is the button, border and all")
	var tr := _rect(tab)
	var cr := _rect(card)
	r.check(is_equal_approx(tr.end.x, cr.end.x), "1: the tab's right edge is the card's (%s / %s)" % [tr.end.x, cr.end.x])
	r.check(is_equal_approx(tr.position.y, cr.end.y - 1.0), "1-2: its top row is the card's bottom edge: attached, one line")
	r.check(tr.size.x >= 250.0 / 3.0 and tr.size.x <= 270.0 / 3.0 and tr.size.y >= 30.0 / 3.0 and tr.size.y <= 36.0 / 3.0, "1: about 250-270 x 30-35 at 1440 x 810 (%s)" % str(tr.size))
	_no_overlap(tab, card, null)
	_no_overlap(tab, Game.current_screen, _node("HubDoor"))
	r.check(Game.current_screen.find_children("*", "Button", true, false).filter(func(b): return String(b.text).contains("DYNASTY")).is_empty(), "1: no other DYNASTY HUB button on the screen")
	r.check(hint != null and hint.visible, "4: the first-time hint shows for a new dynasty")
	r.check(hint != null and hint.mouse_filter == Control.MOUSE_FILTER_IGNORE, "4: the hint never blocks a tap")
	r.check(hint != null and not _rect(hint).intersects(tr) and not _rect(hint).intersects(cr), "4: the hint covers neither the card nor the tab")
	_no_overlap(hint, Game.current_screen, _node("HubDoor"))
	# ---- the hover face: lighter, then back; the press sinks it
	var scr = Game.current_screen
	var normal: StyleBox = card.get_theme_stylebox("panel")
	scr._hub_face("hover")
	var lit: StyleBox = card.get_theme_stylebox("panel")
	r.check(lit != normal and lit.texture.get_image().get_pixel(3, 3).v > normal.texture.get_image().get_pixel(3, 3).v, "3: hover lights the card's plate")
	r.check(lit.texture.get_image().get_pixel(2, 0) == UI.BORDER, "2: its edge stays white, the tab's edge")
	var size0: Vector2 = card.size
	scr._hub_face("down")
	await _frames(2)
	r.check(card.size == size0 and (card.get_theme_stylebox("panel") as StyleBoxTexture).content_margin_top > 3, "3: the press sinks the card without moving the layout")
	scr._hub_face("normal")
	await _frames(2)
	# ---- the tap: the Dynasty Hub, and the hint is gone for good
	Game.save_career()   # (test mode: guarded)
	tab.pressed.emit()
	await _frames(2)
	r.check(c.hub_seen, "4: opening the hub dismisses the hint for this save")
	await r.get_tree().create_timer(0.6).timeout
	r.check(Game.current_name == "more", "1-2: the tab opens the Dynasty Hub (%s)" % Game.current_name)
	Game.goto("hub")
	await _frames(4)
	r.check(_node("HubHint") == null, "4: never shown again")
	r.check(Career.from_dict(JSON.parse_string(JSON.stringify(c.to_dict()))).hub_seen, "4: and that's saved")
	r.check(String(Game.settings.hub_hint_uid) == c.uid, "4: the first dynasty claimed the hint, game-wide")
	# ---- a later dynasty never gets it, opened or not
	var c2 := _career()
	r.check(c2.uid != c.uid and not c2.hub_seen, "4: a second dynasty hasn't opened its hub")
	Game.career = c2
	Game.goto("hub")
	await _frames(4)
	r.check(_node("HubHint") == null, "4: only the first-ever dynasty shows the hint")
	Game.settings.hub_hint_uid = hint_owner0
	Game.career = null

## `w` covers none of the text (or the team logo, the season path) under `root`, but `skip`'s.
func _no_overlap(w: Control, root: Node, skip: Node) -> void:
	if w == null or root == null:
		return
	var cr := _rect(w)
	var hit := []
	for n in root.find_children("*", "", true, false):
		if skip != null and (n == skip or skip.is_ancestor_of(n)):
			continue
		if not (n is Label or String(n.name) in ["TeamLogo", "SeasonPath", "SeasonProgress"]) or not (n as Control).is_visible_in_tree():
			continue
		var nr: Rect2 = _rect(n)
		if n is Label:
			# the text itself, not the label's stretched box
			var l := n as Label
			var lw := l.get_theme_font("font").get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, l.get_theme_font_size("font_size")).x
			var x0 := nr.position.x
			if l.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER:
				x0 += (nr.size.x - lw) * 0.5
			elif l.horizontal_alignment == HORIZONTAL_ALIGNMENT_RIGHT:
				x0 += nr.size.x - lw
			nr = Rect2(x0, nr.position.y, lw, nr.size.y)
		if nr.has_area() and nr.intersects(cr):
			hit.append("%s '%s'" % [n.name, n.text if n is Label else ""])
	r.check(hit.is_empty(), "1, 4: %s covers nothing %s" % [w.name, str(hit)])

## Shots: the home screen at 16:9, 4:3 and 21:9; normal, hovered, pressed; hint on and off.
static func shots(runner: Node, out: String) -> void:
	DirAccess.make_dir_recursive_absolute(out)
	var tree := runner.get_tree()
	Store.reset_for_tests()
	var c := _career()
	Game.career = c
	for sz in [Vector2i(1440, 810), Vector2i(1440, 1080), Vector2i(1890, 810)]:
		DisplayServer.window_set_size(sz)
		c.hub_seen = false
		Game.goto("hub")
		await tree.create_timer(0.8).timeout
		var tag := "%dx%d" % [sz.x, sz.y]
		await _shot(runner, out, "hub_%s_hint" % tag)
		var e: Button = Game.current_screen.find_child("HubEntry", true, false)
		if e != null and Game.current_screen.has_method("_hub_face"):
			Game.current_screen._hub_face("hover")
			await tree.process_frame
			await _shot(runner, out, "hub_%s_hover" % tag)
			Game.current_screen._hub_face("down")
			await tree.process_frame
			await _shot(runner, out, "hub_%s_down" % tag)
		c.hub_seen = true
		Game.goto("hub")
		await tree.create_timer(0.6).timeout
		await _shot(runner, out, "hub_%s" % tag)
	DisplayServer.window_set_size(Vector2i(1440, 810))
	Game.career = null

static func _shot(runner: Node, out: String, name: String) -> void:
	await RenderingServer.frame_post_draw
	runner.get_viewport().get_texture().get_image().save_png(out.path_join(name + ".png"))
	print("  shot ", name)

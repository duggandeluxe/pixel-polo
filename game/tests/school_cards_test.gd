extends RefCounted
## THE SCHOOL SELECTION CARD REDESIGN: PICK YOUR SCHOOL is a full-width grid of school cards
## (logo, name, conference, OFF and DEF stars, a lock when it's locked); a tap picks, NEXT goes on.
## No list, no school panel. The numbered checks follow the spec's REQUIRED TESTING list.
##   godot --headless --path game -- --test school_cards

var r   # the test runner

func run(runner) -> void:
	load("res://src/ui/screens/new_career.gd").start_filter = Colleges.D1   # (the Road to Glory's thirty; --test divisions has the rest)
	r = runner
	print("school cards")
	Store.reset_for_tests()
	Game.career = null
	Game.setup = null
	Game.progress = Progression.fresh()
	var scr = await _picker()
	_grid(scr)
	_info(scr)
	await _select(scr)
	_locked(scr)
	_stars(scr)
	await _scroll(scr)
	_logos(scr)
	await _next(scr)
	await _owned()
	Store.reset_for_tests()
	Game.progress = null
	Game.setup = null
	Game.goto("title")
	await r.get_tree().process_frame

func _picker() -> Node:
	Game.goto("new_career")
	for _i in 4:
		await r.get_tree().process_frame
	return Game.current_screen

func _texts(n: Node) -> Array:
	return n.find_children("*", "Label", true, false).map(func(l): return (l as Label).text)

# ------------------------------------------------------------------ T1, T10
func _grid(scr) -> void:
	var grids: Array = scr.list.get_children().filter(func(n): return n is GridContainer)
	r.check(scr.get("card_box") == null and scr.find_child("SchoolLocked", true, false) == null, "T1: no school panel")
	r.check(scr.list.get_children().all(func(n): return n is GridContainer or String(n.name).begins_with("Header") or n.get_child_count() == 0), "T1: no list rows: only the tier headers and their grids")
	r.check(grids.all(func(g): return g.columns == scr.columns()) and scr.columns() >= 4, "T1: %d cards to a row at %d px" % [scr.columns(), int(scr.get_viewport_rect().size.x)])
	var sc: Rect2 = scr.list_scroll.get_global_rect()
	r.check(sc.size.x >= scr.get_viewport_rect().size.x - 24, "T1: the grid runs the page's width (%d)" % int(sc.size.x))
	var right := 0.0
	for id in scr.cards:
		right = maxf(right, scr.cards[id].get_global_rect().end.x)
	r.check(right >= sc.end.x - 12 and right <= sc.end.x + 0.5, "T1/T10: the cards fill the width, never past it (%.0f of %.0f)" % [right, sc.end.x])
	r.check(scr.list_scroll.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED and scr.list_scroll is TouchScroll, "T10: it scrolls by touch, never sideways")
	r.check(scr.cards.values().all(func(cd): return cd is Button and cd.focus_mode == Control.FOCUS_NONE and cd.mouse_filter == Control.MOUSE_FILTER_STOP), "T10: every card takes a tap")
	var under: Array = scr.cards.values().filter(func(cd): return cd.find_children("*", "Control", true, false).any(func(k): return k.mouse_filter != Control.MOUSE_FILTER_IGNORE))
	r.check(under.is_empty(), "T10: nothing on a card swallows the tap")

# ------------------------------------------------------------------ T2
func _info(scr) -> void:
	var wrong: Array = []
	for id in scr.cards:
		var s := Colleges.school(id)
		var t: PoloTeam = scr.preview.teams[id]
		var tx := _texts(scr.cards[id])
		var want := ["OVR", str(t.overall_display()), "SELECTED", Colleges.place(id).to_upper(), String(s.mascot).to_upper(), Colleges.conf_abbr(s.conf), "OFF", "DEF"]
		var ok: bool = tx == want and scr.cards[id].find_child("Logo", true, false) != null
		ok = ok and float(scr.cards[id].find_child("StarsOFF", true, false).get_meta("stars")) == scr.card_stars(t.offense_display())
		ok = ok and float(scr.cards[id].find_child("StarsDEF", true, false).get_meta("stars")) == scr.card_stars(t.defense_display())
		if not ok:
			wrong.append([id, tx])
	r.check(wrong.is_empty(), "T2: every card: logo, its team OVR, place and mascot, conference, OFF and DEF stars (and the SELECTED tab, shown on the pick), nothing else %s" % str(wrong.slice(0, 2)))

# ------------------------------------------------------------------ T3
func _select(scr) -> void:
	var open: Array = scr.card_order().filter(func(id): return Game.progress.is_unlocked(id))
	scr.cards[open[1]].pressed.emit()
	await r.get_tree().process_frame
	scr.cards[open[2]].pressed.emit()
	await r.get_tree().process_frame
	var lit: Array = scr.cards.keys().filter(func(id): return scr.card_on(id))
	r.check(scr.pick == open[2] and lit == [open[2]], "T3: the tapped card is the one yellow card (%s)" % str(lit))
	var tabs: Array = scr.cards.keys().filter(func(id): return scr.cards[id].find_child("Selected", true, false).visible)
	r.check(tabs == [open[2]], "T3: only your pick says SELECTED (%s)" % str(tabs))
	r.check(Colleges.SCHOOLS.any(func(s): return s.short == scr.pick) and scr.cards[scr.pick] == scr.cards[open[2]], "T3: the pick is the card's own school id (%s)" % scr.pick)

# ------------------------------------------------------------------ T5
func _locked(scr) -> void:
	var was: String = scr.pick
	scr.cards.CULA.pressed.emit()
	r.check(scr.pick == was and not scr.card_on("CULA") and not scr.cards.CULA.find_child("Selected", true, false).visible, "T5: a locked card can't be picked (never SELECTED)")
	r.check(scr.cards.CULA.find_child("Lock", true, false) != null and scr.cards.CULA.modulate != Color.WHITE, "T5: it shows its lock, faded")
	r.check(not Game.start_career("CULA", "A", "B", 1) and Game.career == null, "T5: and no dynasty can start there")
	r.check(Game.progress.unlocked.size() == 5, "T5: the unlocks as they were")

# ------------------------------------------------------------------ T7
func _stars(scr) -> void:
	var table := {40: 2.0, 50: 2.5, 60: 3.0, 70: 3.5, 80: 4.0, 90: 4.5, 99: 5.0, 64: 3.0, 66: 3.5, 0: 0.0}
	var ok := true
	for v in table:
		ok = ok and scr.card_stars(float(v)) == table[v]
	r.check(ok, "T7: stars = rating / 20, to the nearest half")
	var before := {}
	for id in scr.preview.teams:
		var t: PoloTeam = scr.preview.teams[id]
		before[id] = [t.offense_display(), t.defense_display(), t.overall_display()]
	scr._render()
	var same := true
	for id in scr.preview.teams:
		var t: PoloTeam = scr.preview.teams[id]
		same = same and before[id] == [t.offense_display(), t.defense_display(), t.overall_display()]
	r.check(same, "T7: the ratings themselves untouched")
	var halves: Array = scr.preview.teams.keys().filter(func(id): return fmod(scr.card_stars(scr.preview.teams[id].offense_display()), 1.0) != 0.0 or fmod(scr.card_stars(scr.preview.teams[id].defense_display()), 1.0) != 0.0)
	r.check(not halves.is_empty(), "T7: half stars come up (%d schools)" % halves.size())

# ------------------------------------------------------------------ T8
func _scroll(scr) -> void:
	for _i in 2:
		await r.get_tree().process_frame
	var bar: VScrollBar = scr.list_scroll.get_v_scroll_bar()
	r.check(bar.max_value - bar.page > 0, "T8: the grid scrolls")
	scr.list_scroll.scroll_vertical = int(bar.max_value)
	await r.get_tree().process_frame
	var last: String = scr.card_order()[-1]
	r.check(scr.list_scroll.get_global_rect().grow(0.5).encloses(scr.cards[last].get_global_rect()), "T8: down at the bottom: the last school (%s) in full" % last)
	var rects: Array = scr.cards.values().map(func(cd): return cd.get_global_rect())
	var apart := true
	for a in rects.size():
		for b in range(a + 1, rects.size()):
			apart = apart and not (rects[a] as Rect2).grow(-0.5).intersects(rects[b])
	r.check(apart and scr.card_order().size() == 30, "T8: all 30, none overlapping")
	scr.list_scroll.scroll_vertical = 0

# ------------------------------------------------------------------ T9
func _logos(scr) -> void:
	var ok := true
	for id in scr.cards:
		var lg: Control = scr.cards[id].find_child("Logo", true, false)
		var own: Vector2 = Vector2(lg.texture.get_size()) if lg is TextureRect else Vector2(40, 40)
		ok = ok and lg.size == own and own.x <= scr.LOGO_FIT.x and own.y <= scr.LOGO_FIT.y and lg.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST
		var ovr: Control = scr.cards[id].find_child("Ovr", true, false)
		ok = ok and not lg.get_global_rect().intersects(ovr.get_global_rect())
	r.check(ok, "T9: every logo at its own file's size (1:1, nearest-neighbour), clear of the OVR badge")
	var sj: Control = scr.cards.SJCU.find_child("Logo", true, false)
	r.check(sj.size == Vector2(60, 32), "T9: San Jose's wide logo gets its 60 px file (%s)" % str(sj.size))
	var arts: Array = ["SJCU", "CCSB", "MSMU", "CULA"].filter(func(id): return TeamLogo.art(Colleges.school(id), Vector2i(40, 40)) != null)
	r.check(arts.size() == 4, "T9: the cards draw the logo artwork's own 40 px file %s" % str(arts))

# ------------------------------------------------------------------ T4
func _next(scr) -> void:
	var setup: Career = Game.setup
	var id: String = scr.pick
	var snap := JSON.stringify(setup.teams[id].roster.map(func(p): return [p.id, p.attrs]))
	scr.next_button.pressed.emit()
	await r.get_tree().process_frame
	r.check(scr.step == 1, "T4: NEXT goes on to YOUR COACH")
	scr._start()
	await r.get_tree().process_frame
	var c: Career = Game.career
	r.check(c != null and c == setup and c.school == id, "T4: the dynasty starts at the picked school (%s), from the setup the cards showed" % id)
	r.check(c != null and JSON.stringify(c.teams[id].roster.map(func(p): return [p.id, p.attrs])) == snap, "T4: its roster not made again")
	Game.career = null
	Game.goto("title")
	await r.get_tree().process_frame

# ------------------------------------------------------------------ T6
func _owned() -> void:
	Store.all_teams = true
	var scr = await _picker()
	r.check(scr.cards.values().all(func(cd): return cd.find_child("Lock", true, false) == null and cd.modulate == Color.WHITE), "T6: owned: no locks, nothing faded")
	r.check(scr.find_child("UnlockAllTeams", true, false) == null and scr.find_child("OfferRow", true, false) == null, "T6: no purchase button")
	scr.cards.CULA.pressed.emit()
	r.check(scr.pick == "CULA" and scr.card_on("CULA") and not scr.next_button.disabled, "T6: any card can be picked")
	var order: Array = scr.card_order()
	var desc := true
	for i in range(1, order.size()):
		desc = desc and (scr.preview.teams[order[i]] as PoloTeam).team_overall(false) <= (scr.preview.teams[order[i - 1]] as PoloTeam).team_overall(false) + 0.000001
	r.check(order.size() == 30 and desc, "T6: all 30, highest overall first")
	Store.all_teams = false

## Shots: every card, all 30 open (the store's test entitlement), a page at a time.
##   godot --path game -- --test school_cards_png <dir>   (needs a window)
static func shots(runner, out: String) -> void:
	DirAccess.make_dir_recursive_absolute(out)
	var tree: SceneTree = runner.get_tree()
	Store.reset_for_tests()
	Store.all_teams = true
	Game.progress = Progression.fresh()
	Game.career = null
	Game.goto("new_career")
	await tree.create_timer(0.5).timeout
	var scr = Game.current_screen
	var bar: VScrollBar = scr.list_scroll.get_v_scroll_bar()
	var page := 0
	var at := 0
	while true:
		scr.list_scroll.scroll_vertical = at
		await tree.create_timer(0.2).timeout
		runner.get_viewport().get_texture().get_image().save_png(out.path_join("sc%02d.png" % page))
		print("  shot sc%02d" % page)
		if at >= int(bar.max_value - bar.page):
			break
		at = mini(at + int(bar.page) - 20, int(bar.max_value - bar.page))
		page += 1
	Store.reset_for_tests()
	Game.progress = null
	Game.goto("title")

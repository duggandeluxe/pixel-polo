extends RefCounted
## THE RECRUITING MARKET VISUAL OVERHAUL (recruiting.gd): the spec's REQUIRED TESTING (1-26).
##   godot --headless --path game -- --test recruit_cards
##   godot --path game -- --test recruit_cards_png <dir>

var r

func run(runner) -> void:
	r = runner
	print("recruiting market overhaul")
	Store.reset_for_tests()
	Game.progress = Progression.fresh()
	var c := _career(971)
	var prices: Array = c.market.map(func(x): return int(x.price))
	var refresh := Recruiting.refresh_cost(c)
	var proj := Recruiting.projected(c)
	Game.goto("recruiting", {"tab": "MARKET"})
	await _frames()
	var scr = Game.current_screen
	var cards: Array = scr.find_children("Card_*", "", true, false)
	var grid: GridContainer = scr.find_child("Cards", true, false)
	r.check(cards.size() == 8 and grid.columns == 4, "1/2: eight cards, four columns, two rows")
	var vr: Rect2 = scr.get_viewport_rect()
	r.check(cards.all(func(b): return vr.encloses((b as Control).get_global_rect())), "1/19/23: every card wholly on screen, no scrolling")
	var s0: Vector2 = cards[0].size
	r.check(cards.all(func(b): return (b as Control).size == s0) and s0.x >= 104.0 and s0.y >= 88.0, "10: one size for all (%s)" % str(s0))
	var xs: Array = cards.slice(0, 4).map(func(b): return (b as Control).global_position.x)
	var gaps: Array = [xs[1] - xs[0], xs[2] - xs[1], xs[3] - xs[2]]
	r.check(gaps.all(func(g): return is_equal_approx(g, gaps[0])) and is_equal_approx(cards[4].global_position.x, xs[0]), "11: even spacing, rows aligned")
	r.check(cards.all(func(b): return not b.has_meta("fills")) and not FileAccess.get_file_as_string("res://src/ui/screens/recruiting.gd").contains("TEAM NEED:"), "3: no TEAM NEED on any card")
	r.check(scr.find_child("RosterNeeds", true, false) == null and RosterNeeds.GROUPS.all(func(g): return scr.find_child("Need_" + g, true, false) == null),
		"4: no TEAM NEEDS panel on the recruiting screen (removed)")
	r.check((scr.find_child("ProjectedCount", true, false) as Label).text == "PROJECTED ROSTER: %d / %d" % [proj, c.roster_max()], "18: the projected roster as before")
	r.check(cards.map(func(b): return int(b.get_meta("price"))) == prices and Recruiting.refresh_cost(c) == refresh, "16/17: prices and the refresh cost unchanged")
	# the card itself, painted on an image (pixel checks need a window: run without --headless)
	var p: PoloPlayer = c.market[0].p
	if DisplayServer.get_name() == "headless":
		print("  (headless: the card's pixel checks are skipped; run without --headless for them)")
	else:
		# the card itself, painted on an image: the portrait 2x, the stars, the price inside
		var img := await _paint(scr, p, c, false, false)
		r.check(img != null, "5: the card paints")
		var pc := Portrait.colors_ours(p, c.team())
		var src: Image = Portrait.image(p, pc[0], pc[1])
		var same := 0
		var tot := 0
		var at := Vector2i(int(floorf(scr.card_size(scr).x * 0.5 - 1.0 - Portrait.SIZE.x)), int(scr.PORTRAIT_Y) + 1)
		for y in range(0, 40, 3):
			for x in range(0, Portrait.SIZE.x * 2, 3):
				var a := src.get_pixel(x / 2, y / 2)
				if a.a < 0.5:
					continue
				tot += 1
				if img.get_pixel(at.x + x, at.y + y).is_equal_approx(a):
					same += 1
		r.check(tot > 0 and same >= tot * 0.95, "5/24: his own portrait at exactly twice its pixels, sharp (%d of %d sampled)" % [same, tot])
		r.check(Portrait.SIZE.x * 2 > Portrait.CARD_ZOOM.x, "5: bigger than the roster card's (%d vs %d wide)" % [Portrait.SIZE.x * 2, Portrait.CARD_ZOOM.x])
		# 7/8: current stars, half stars
		p.stars = 2.5
		var im2 := await _paint(scr, p, c, false, false)
		var gold := 0
		for y in range(int(scr.STARS_Y), int(scr.STARS_Y) + 9):
			for x in int(scr.card_size(scr).x):
				if im2.get_pixel(x, y).is_equal_approx(PlayerForm.GOLD):
					gold += 1
		r.check(gold > 20, "7/8: his stars drawn (half stars by the game's own bar)")
		# his potential: hollow stars after the gold, up to his ceiling and no further
		var was_pot := p.pot_stars
		var bar_span := func(im: Image) -> int:   # the star row's width, first lit column to last
			var lo := 9999
			var hi := -1
			for y in range(int(scr.STARS_Y), int(scr.STARS_Y) + 9):
				for x in int(scr.card_size(scr).x):
					var px := im.get_pixel(x, y)
					if px.is_equal_approx(PlayerForm.GOLD) or px.is_equal_approx(Deck.STAR_OPEN):
						lo = mini(lo, x)
						hi = maxi(hi, x)
			return hi - lo + 1 if hi >= 0 else 0
		p.pot_stars = 3.0
		var at_pot: int = bar_span.call(await _paint(scr, p, c, false, false))
		p.pot_stars = 4.0
		var im3 := await _paint(scr, p, c, false, false)
		var open := 0
		for y in range(int(scr.STARS_Y), int(scr.STARS_Y) + 9):
			for x in int(scr.card_size(scr).x):
				if im3.get_pixel(x, y).is_equal_approx(Deck.STAR_OPEN):
					open += 1
		r.check(open > 10, "potential: hollow stars after the gold (2.5 of 4)")
		r.check(bar_span.call(im3) == at_pot + int(Deck.STAR_STEP), "potential: the bar ends at his ceiling (4 places, not 5: %d vs %d)" % [bar_span.call(im3), at_pot])
		# a half-star ceiling: the last star is cut in half (nothing drawn past its middle)
		p.pot_stars = 3.5
		var im4 := await _paint(scr, p, c, false, false)
		var past := 0
		for y in range(int(scr.STARS_Y), int(scr.STARS_Y) + 9):
			for x in int(scr.card_size(scr).x):
				if im4.get_pixel(x, y).is_equal_approx(Deck.STAR_PAST):
					past += 1
		var cut_w: int = bar_span.call(im4)
		r.check(past == 0 and cut_w == at_pot + int(Deck.STAR_STEP) - (int(Deck.STAR_SHAPE.w) - int(Deck.STAR_SHAPE.half)),
			"potential: a 3.5 ceiling ends on half a star (span %d vs %d, %d past-ceiling pixels)" % [cut_w, at_pot, past])
		p.pot_stars = was_pot
		# 9: the price in the footer
		var foot_y := int(scr.CARD_H - 2 - scr.FOOT_H * 0.5)
		var lit := 0
		for x in int(scr.card_size(scr).x):
			if im2.get_pixel(x, foot_y).is_equal_approx(UI.GOLD):
				lit += 1
		r.check(lit > 3, "9: the price inside the card's footer")
	# 22: a long name never overflows
	p.last = "Vanderbergh-Szabolcsi"
	var fitted := Deck.fit(p.short_name().to_upper(), scr.card_size(scr).x - 12.0, 8, "caps")
	r.check(Deck.text_w(fitted, 8, "caps") <= scr.card_size(scr).x - 12.0, "22: a long surname is fitted inside the card")
	# 12-15: the tabs
	Recruiting.toggle_pin(c, c.market[1])
	(scr.find_child("Tab_MARKET", true, false) as Button).pressed.emit()
	await _frames()
	scr = Game.current_screen
	var pins: Array = scr.find_children("Card_*", "", true, false).filter(func(x): return bool(x.get_meta("pinned")))
	r.check(pins.size() == 1 and scr.find_child("Tab_PINNED", true, false) == null, "12/13/14: no PINNED tab; the pinned prospect keeps his pin on the MARKET")
	c.credits = 999
	var err := Recruiting.sign(c, c.market[2])
	(scr.find_child("Tab_INCOMING", true, false) as Button).pressed.emit()
	await _frames()
	scr = Game.current_screen
	var inc: Array = scr.find_children("Card_*", "", true, false)
	r.check(err == "" and inc.size() == 1 and (scr.find_child("Tab_INCOMING", true, false) as Button).text == "INCOMING  1", "15/21: INCOMING: the signed recruit (signing as ever)")
	(scr.find_child("Tab_MARKET", true, false) as Button).pressed.emit()
	await _frames()
	scr = Game.current_screen
	var first: Button = scr.find_children("Card_*", "", true, false)[0]
	first.pressed.emit()
	await _frames()
	r.check(Game.current_name == "player" and Game.current_screen.recruit, "20: a card opens his profile, as ever")
	r.check(Game.current_screen.find_child("Stars_Potential", true, false) != null, "19: his potential is on the profile too")
	var d := Career.from_dict(JSON.parse_string(JSON.stringify(c.to_dict())))
	r.check(d.market.size() == c.market.size() and d.incoming.size() == 1, "25: the save as ever")
	Game.career = null
	Game.goto("title")
	await r.get_tree().process_frame

func _frames(n: int = 3) -> void:
	for _i in n:
		await r.get_tree().process_frame

static func _career(seed_value: int) -> Career:
	var c := Career.new_game("SJCU", "A", "B", seed_value)
	c.queue.clear()
	Game.career = c
	if c.market.is_empty():
		Recruiting.refresh(c)
	return c

## One card painted into an image (a SubViewport of its own).
func _paint(scr, p: PoloPlayer, c: Career, pinned: bool, incoming: bool) -> Image:
	var sz: Vector2 = scr.card_size(scr)
	var vp := SubViewport.new()
	vp.size = Vector2i(sz)
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	var cv := UI.canvas(int(sz.x), int(sz.y), func(ci): scr.paint_recruit(ci, sz, p, c.team(), "normal", false, pinned, incoming, false, 47))
	cv.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	vp.add_child(cv)
	r.get_tree().root.add_child(vp)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	vp.queue_free()
	return img

static func shots(runner, out: String) -> void:
	DirAccess.make_dir_recursive_absolute(out)
	var tree: SceneTree = runner.get_tree()
	Store.reset_for_tests()
	var c := _career(971)
	Recruiting.toggle_pin(c, c.market[1])
	for t in ["MARKET"]:
		Game.goto("recruiting", {"tab": t, "sel": (c.market[5].p as PoloPlayer).id})
		await tree.create_timer(0.5).timeout
		await RenderingServer.frame_post_draw
		runner.get_viewport().get_texture().get_image().save_png(out.path_join("r_%s.png" % t.to_lower()))
	print("  shots")
	Game.career = null

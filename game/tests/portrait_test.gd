extends RefCounted
## The Player Portrait Sprite Upgrade: Portrait's front-facing headshots on the roster and
## recruiting cards and the player page.
##   godot --headless --path game -- --test portraits
##   godot --path game -- --test portraits_png <dir>      (a contact sheet and the screens: needs a window)

var r

func run(runner) -> void:
	r = runner
	print("portraits")
	Store.reset_for_tests()
	var c := Career.new_game("CULA", "A", "B", 12)
	var cap := Color("f2f2e9")
	var trim := Color("1d4ab8")
	var players: Array = []
	for id in c.teams:
		players.append_array((c.teams[id] as PoloTeam).roster)
	players.append_array(c.market.map(func(x): return x.p))
	# the same player, the same face: every time, after a save, on every screen
	var p: PoloPlayer = players[0]
	var a := Portrait.image(p, cap, trim)
	var again := Portrait.image(p, cap, trim)
	var back := PoloPlayer.from_dict(JSON.parse_string(JSON.stringify(p.to_dict())))
	r.check(a.get_data() == again.get_data() and a.get_data() == Portrait.image(back, cap, trim).get_data(), "9, 12: the same player looks the same, after a save too")
	r.check(Portrait.traits(p) == Portrait.traits(back), "12: his traits come from who he is, nothing saved")
	r.check(a.get_size() == Portrait.SIZE, "7: the headshot is the portrait panel's size (%s)" % str(a.get_size()))
	# a water polo cap on everyone: cap colour across the top and in both ear guards
	var capped := 0
	var faces := {}
	var trait_sets := {}
	for q: PoloPlayer in players:
		var img := Portrait.image(q, cap, trim)
		var top := _count(img, cap, 0, 7)
		var guards := _count_at(img, cap, 0, 9, 8, 13) > 0 and _count_at(img, cap, 17, 26, 8, 13) > 0
		if top >= 20 and guards:
			capped += 1
		faces[img.get_data()] = true
		var t := Portrait.traits(q)
		trait_sets["%s|%s|%s|%s|%s|%s|%s" % [t.face_w, t.jaw, t.eye, t.brow, t.nose, t.mouth, t.face]] = true
	r.check(capped == players.size(), "2-3: every player wears the cap and its ear guards (%d of %d)" % [capped, players.size()])
	r.check(faces.size() >= players.size() * 0.95, "5: faces differ (%d different of %d)" % [faces.size(), players.size()])
	r.check(trait_sets.size() >= players.size() * 0.8, "5: and not just colours: face shape, eyes, brows, nose, mouth, hair (%d sets)" % trait_sets.size())
	# a face: two eyes, symmetric about the centre; a mouth
	var t0 := Portrait.traits(p)
	var eyes_ok := true
	for q: PoloPlayer in players.slice(0, 60):
		var img := Portrait.image(q, cap, trim)
		var row10: Array = []
		for x in Portrait.SIZE.x:
			if _same(img.get_pixel(x, 10), Portrait.PUPIL) or _same(img.get_pixel(x, 11), Portrait.PUPIL):
				row10.append(x)
		var l := row10.filter(func(x): return x < Portrait.CX)
		var rr := row10.filter(func(x): return x >= Portrait.CX)
		eyes_ok = eyes_ok and not l.is_empty() and not rr.is_empty()
	r.check(eyes_ok, "1, 4: front on: an eye each side of the centre")
	var blink := Portrait.image(p, cap, trim, true)
	r.check(blink.get_data() != a.get_data() and _count(blink, Portrait.PUPIL, 9, 12) == 0, "his page's blink closes both eyes")
	# the cards' zoom: the same art, its columns mirrored exactly (both eyes alike), no new colours
	var z := Portrait.CARD_ZOOM
	var sym := true
	for x in z.x:
		var sx := int(floorf((x + 0.5) * Portrait.SIZE.x / float(z.x)))
		var mx := int(floorf((z.x - 1 - x + 0.5) * Portrait.SIZE.x / float(z.x)))
		sym = sym and sx + mx == Portrait.SIZE.x - 1
	r.check(sym, "zoom: the columns mirror about the face's centre")
	var zi := (Portrait.texture_zoomed(p, cap, trim, z) as ImageTexture).get_image()
	var colours := {}
	for y in Portrait.SIZE.y:
		for x in Portrait.SIZE.x:
			colours[a.get_pixel(x, y).to_html()] = true
	var only := true
	for y in z.y:
		for x in z.x:
			only = only and colours.has(zi.get_pixel(x, y).to_html())
	r.check(zi.get_size() == z and only, "zoom: %s, every pixel one of the art's own (no blur)" % str(z))
	# keepers in red, your caps for the rest
	var gk: PoloPlayer = c.team().keeper()
	r.check(Portrait.colors_ours(gk, c.team())[0] == PoolArt.CAP_KEEPER, "keepers wear the red cap")
	# nothing about him changes
	var before := JSON.stringify(p.to_dict())
	Portrait.texture(p, cap, trim)
	r.check(JSON.stringify(p.to_dict()) == before, "11: drawing him changes nothing")
	r.check(t0.has("hair") and t0.has("face"), "his hair and facial hair are the pool sprite's (PlayerArt.looks)")

## The same colour once stored at 8 bits a channel.
func _same(a: Color, b: Color) -> bool:
	return a.a > 0.5 and a.to_html(false) == b.to_html(false)

func _count(img: Image, col: Color, y0: int, y1: int) -> int:
	return _count_at(img, col, 0, img.get_width(), y0, y1)

func _count_at(img: Image, col: Color, x0: int, x1: int, y0: int, y1: int) -> int:
	var n := 0
	for y in range(y0, y1):
		for x in range(x0, x1):
			if _same(img.get_pixel(x, y), col):
				n += 1
	return n

## A contact sheet (forty at 1x, then the same at 4x) and the roster, recruiting and player pages.
static func shots(runner, out: String) -> void:
	DirAccess.make_dir_recursive_absolute(out)
	var tree: SceneTree = runner.get_tree()
	Store.reset_for_tests()
	Store.mark_starter_offered()
	var c := Career.new_game("CULA", "Sam", "Rivera", 31)
	c.queue.clear()
	c.hot_tip = true
	Game.career = c
	var players: Array = []
	for id in ["CULA", "USC", "STAM", "HVRD", "PRIN"]:
		if c.teams.has(id):
			players.append_array((c.teams[id] as PoloTeam).roster)
	players.append_array(c.market.map(func(x): return x.p))
	var img := Image.create(480, 270, false, Image.FORMAT_RGBA8)
	img.fill(Color("0b1d5c"))
	var cap := Color("f2f2e9")
	var trim := c.team().c1
	for i in mini(40, players.size()):
		var q: PoloPlayer = players[i]
		var pi := Portrait.image(q, PoolArt.CAP_KEEPER if q.is_keeper() else cap, trim)
		img.blit_rect(pi, Rect2i(Vector2i.ZERO, Portrait.SIZE), Vector2i(4 + (i % 16) * 29, 4 + (i / 16) * 32))
	for i in mini(12, players.size()):
		var q: PoloPlayer = players[i]
		var pi := Portrait.image(q, PoolArt.CAP_KEEPER if q.is_keeper() else cap, trim)
		pi.resize(Portrait.SIZE.x * 3, Portrait.SIZE.y * 3, Image.INTERPOLATE_NEAREST)
		img.blit_rect(pi, Rect2i(Vector2i.ZERO, pi.get_size()), Vector2i(4 + (i % 6) * 80, 100 + (i / 6) * 88))
	img.save_png(out.path_join("portrait_sheet.png"))
	print("  shot portrait_sheet")
	for shot in [["roster", {}], ["recruiting", {"tab": "MARKET"}], ["player", {"id": c.team().starters()[1].id}]]:
		Game.goto(String(shot[0]), shot[1])
		await tree.create_timer(0.6).timeout
		await RenderingServer.frame_post_draw
		runner.get_viewport().get_texture().get_image().save_png(out.path_join("portrait_%s.png" % shot[0]))
		print("  shot portrait_", shot[0])
	Game.career = null

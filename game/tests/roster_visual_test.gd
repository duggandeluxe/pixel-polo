extends RefCounted
const HotBadge := preload("res://src/ui/hot_badge.gd")
## Fixed roster geometry and UI state derived from saved player data.

const ROSTER := preload("res://src/ui/screens/roster.gd")
## (the cards 64 tall since the Portrait Zoom update; rows 75 apart since the Position Identity
## update: each place's name over its card)
const POSITIONS := {
	"lw": Vector2(0, 11), "cf": Vector2(108, 11), "rw": Vector2(216, 11),
	"lf": Vector2(0, 86), "pt": Vector2(108, 86), "rf": Vector2(216, 86),
	"gk": Vector2(108, 161), "s1": Vector2(332, 11),
	"s2": Vector2(332, 86), "s3": Vector2(332, 161),
}

func run(runner: Node) -> void:
	print("roster visual")
	Store.reset_for_tests()
	var tree := runner.get_tree()
	var career := Career.new_game("LIUB", "Roster", "Visual", 42)
	Game.career = career
	var team := career.team()
	var player: PoloPlayer = team.roster[0]
	var need := Development.xp_needed(player)
	for quarter in [0, 1, 2, 3]:
		player.xp = roundi(need * quarter / 4.0)
		runner.check(is_equal_approx(ROSTER.xp_fill(player), Development.progress(player)),
			"roster XP uses the progression threshold at %d%%" % (quarter * 25))
	player.xp = need
	runner.check(is_equal_approx(ROSTER.xp_fill(player), 1.0), "a full XP threshold fills the bar")
	player.xp = 0
	player.tokens = 1
	runner.check(is_equal_approx(ROSTER.xp_fill(player), 1.0), "one unused token fills the roster XP bar")
	player.tokens = 2
	runner.check(is_equal_approx(ROSTER.xp_fill(player), 1.0), "multiple unused tokens keep the bar full")
	player.tokens = 0
	player.xp = roundi(need * 0.25)
	runner.check(is_equal_approx(ROSTER.xp_fill(player), Development.progress(player)), "spending the last token restores remaining XP progress")
	runner.check(ROSTER.CARD == Vector2(102, 64) and ROSTER.board_size() == Vector2(434, 225),
		"card and board at their dimensions (64 tall since the Portrait Zoom update)")
	for key in POSITIONS:
		runner.check(ROSTER.spot_pos(key) == POSITIONS[key], "%s keeps its original position" % key)
	career.hot_tip = true
	Game.goto("roster")
	await tree.process_frame
	var screen = Game.current_screen
	var placed := true
	for key in POSITIONS:
		var index := PoloTeam.LINEUP_SPOTS.find(key)
		var card: Control = screen.slots[index]
		placed = placed and card.position == POSITIONS[key] and card.size == ROSTER.CARD
	runner.check(placed, "all live roster cards keep their positions and dimensions")
	for state in [[false, false], [true, false], [false, true], [true, true]]:
		var upgrade: bool = state[0]
		var injury: bool = state[1]
		player.tokens = 1 if upgrade else 0
		if injury and not player.is_injured():
			Development.injure(player, RandomNumberGenerator.new(), "minor")
		elif not injury and player.is_injured():
			Development.heal(player)
		Game.goto("hub")
		await tree.process_frame
		var button: Control = Game.current_screen.find_child("Nav_roster", true, false)
		var badges: Control = button.find_child("RosterStatusBadges", true, false) if button != null else null
		var correct := (badges == null) if not upgrade and not injury else (badges != null and bool(badges.get_meta("upgrade", false)) == upgrade and bool(badges.get_meta("injury", false)) == injury and badges.mouse_filter == Control.MOUSE_FILTER_IGNORE)
		runner.check(correct, "roster navigation reflects upgrade=%s injury=%s" % [upgrade, injury])
	player.tokens = 0
	if player.is_injured():
		Development.heal(player)
	_star_shape(runner)
	await _card_info(runner, career)
	await _mandatory(runner, career)
	if DisplayServer.get_name() == "headless":
		print("  (the pixel checks need a window: --test roster_visual without --headless)")
	else:
		await _pixels(runner, career)
	Game.career = null
	Game.goto("title")
	await tree.process_frame

## The Roster Restoration stars: one five-pointed star, symmetric, a thin outline round it, the
## same shape on every screen, half stars lit to their centre.
func _star_shape(runner: Node) -> void:
	var inner := _cells(Deck.STAR_INNER)
	var tips := 0
	for c: Vector2i in inner:
		var n := 0
		for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			n += 1 if inner.has(c + d) else 0
		tips += 1 if n == 1 else 0
	runner.check(tips == 5, "the star has five points (%d)" % tips)
	var mirror := func(rows: Array) -> bool:
		return rows.all(func(row: String):
			for x in row.length():
				if row[x] != row[row.length() - 1 - x]:
					return false
			return true)
	runner.check(mirror.call(Deck.STAR) and mirror.call(Deck.STAR_INNER), "...symmetric left to right")
	var grown := inner.duplicate()
	for c: Vector2i in inner:
		for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			grown[c + d] = true
	var outline := _cells(Deck.STAR)
	runner.check(grown.size() == outline.size() and grown.keys().all(func(c): return outline.has(c)),
		"...with a 1 px outline all round, nothing more")
	runner.check(Deck.STAR.size() == 9 and inner.size() >= 20 and Deck.STAR_STEP > float(Deck.STAR_SHAPE.w),
		"bigger than the old 5x5 and 7x7 stars, a gap between places (%d lit pixels)" % inner.size())
	var f := Deck.star_fills(3.5, 5.0)
	runner.check(f.map(func(x): return [float(x.gold), float(x.pot)]) == [[1.0, 1.0], [1.0, 1.0], [1.0, 1.0], [0.5, 1.0], [0.0, 1.0]],
		"3.5 stars: three gold, a half, then a hollow POTENTIAL star (no rounding)")
	runner.check(Deck._cols(0.5) == 5 and Deck._cols(1.0) == 9 and Deck._cols(0.0) == 0, "a half star lights the left half up to its centre")
	# one star everywhere: no screen keeps a star pattern of its own
	var stray: Array = []
	for path in _scripts("res://src"):
		if path.ends_with("/deck.gd"):
			continue
		var src := FileAccess.get_file_as_string(path)
		for old in ["STAR_7", "Deck.STAR_L", "Deck.STAR_S)", "Deck.STAR_S,", "STAR_INNER", "const STAR :="]:
			if src.contains(old):
				stray.append("%s %s" % [path.get_file(), old])
	var deck_src := FileAccess.get_file_as_string("res://src/ui/deck.gd")
	var stars_fn := deck_src.substr(deck_src.find("static func stars("), 400)
	runner.check(stray.is_empty() and stars_fn.contains("star_place(") and not deck_src.contains("STAR_7"),
		"every screen draws the one shared star (%s)" % ", ".join(stray))

## The card's words: name, class year, position, cap number, HOT / VERY HOT; never an upgrade mark.
## The headshot (Portrait) zoomed in about 38%, its cap in the panel and only the last of its
## shoulders under the divider; the card 16% taller than its 55 px.
func _card_info(runner: Node, career: Career) -> void:
	var z := Portrait.CARD_ZOOM
	runner.check(z.x * Portrait.SIZE.y == z.y * Portrait.SIZE.x + 4 or absf(float(z.x) / Portrait.SIZE.x - float(z.y) / Portrait.SIZE.y) < 0.02, "the zoom keeps the portrait's shape (%s)" % str(z))
	runner.check(float(z.y) / Portrait.SIZE.y >= 1.3 and float(z.y) / Portrait.SIZE.y <= 1.4 and z.y - (int(ROSTER.SPLIT) - 1) <= 3,
		"the headshot about 35% bigger, nearly all of it in the portrait panel (%s in %d)" % [str(z), int(ROSTER.SPLIT) - 1])
	runner.check(ROSTER.CARD.y >= 55 * 1.15 and ROSTER.CARD.y <= 55 * 1.2 and ROSTER.CARD.x == 102, "cards 15-20% taller, the same width (%s)" % str(ROSTER.CARD))
	var team := career.team()
	var hot: PoloPlayer = team.starters()[2]
	hot.heat = 2
	hot.tokens = 1
	Game.goto("roster")
	await runner.get_tree().process_frame
	var scr = Game.current_screen
	UI.drawn_log = []
	scr.cards[hot.id].get_child(0).queue_redraw()
	await _frames(runner, 3)
	var log: Array = UI.drawn_log
	UI.drawn_log = null
	runner.check(log.has(hot.short_name()) and log.has(hot.year_text()) and log.has(Deck.pos_tag(hot)) and log.has("#%d" % hot.number),
		"a card: name, class year, position, cap number")
	runner.check(not log.has("VERY") and not log.has("HOT"), "VERY HOT: no words on the card, his red stars burn instead")
	var src := FileAccess.get_file_as_string("res://src/ui/screens/roster.gd")
	var body := src.substr(src.find("static func paint_card("), src.find("static func xp_fill(") - src.find("static func paint_card("))
	runner.check(not body.contains("tokens") and not body.contains("status_badge") and not log.any(func(s): return String(s).contains("UPGRADE")),
		"no upgrade badge or mark on a card, tokens or not")
	runner.check(not body.contains("stripe") and not body.contains("lerp(") and not body.contains("Color(team.c2"), "no stripes, tints or colour column behind the portrait")
	hot.heat = 0
	hot.tokens = 0

## Unspent upgrades still close the next game: the roster card losing its badge changes nothing.
func _mandatory(runner: Node, career: Career) -> void:
	var up: PoloPlayer = null
	for q: PoloPlayer in career.team().roster:
		if Development.has_room(q):
			up = q
			break
	if up == null:
		runner.check(false, "a player with room to upgrade")
		return
	up.tokens = 1
	runner.check(career.upgrades_due().has(up), "an unspent token is due")
	Game.goto("matchup")
	await runner.get_tree().process_frame
	runner.check(Game.current_name == "player" and bool(Game.current_screen.mandatory), "...and the next game opens his mandatory upgrades first")
	runner.check(up.tokens == 1, "...his token kept")
	up.tokens = 0
	Game.goto("hub")
	await runner.get_tree().process_frame

## What a real frame shows (needs a window): solid panels, one white border, head room over the
## smaller portrait, a 2 px XP bar, the star's own pixels, no upgrade mark, a small injury cross,
## and the same table at phone and tablet shapes.
func _pixels(runner: Node, career: Career) -> void:
	var team := career.team()
	for q: PoloPlayer in team.roster:
		q.heat = 0
		q.tokens = 0
		if q.is_injured():
			Development.heal(q)
	Game.goto("roster")
	await _frames(runner, 3)
	_close_overlays()
	await _frames(runner, 2)
	var scr = Game.current_screen
	var img := await _shot(runner)
	var bad := {}
	var headroom := 99
	for i in PoloTeam.LINEUP_SPOTS.size():
		var q: PoloPlayer = scr.at(i)
		if q == null:
			continue
		var r: Rect2 = scr.cards[q.id].get_global_rect()
		var bench := i >= PoloTeam.STARTERS
		var gk := q.is_keeper() and not bench
		var top: Color = ROSTER.SUB_TOP if bench else ROSTER.GK_TOP if gk else ROSTER.TOP_BG
		var info: Color = ROSTER.SUB_INFO if bench else ROSTER.GK_INFO if gk else ROSTER.INFO_BG
		for x in 102:
			if not _near(_px(img, r, x, 0), UI.TEXT) or not _near(_px(img, r, x, int(ROSTER.CARD.y) - 1), UI.TEXT):
				bad["border"] = true
		for y in int(ROSTER.CARD.y):
			if not _near(_px(img, r, 0, y), UI.TEXT) or not _near(_px(img, r, 101, y), UI.TEXT):
				bad["border"] = true
		for y in range(1, 2):   # (the row over his cap: the zoomed headshot starts under it)
			for x in range(1, 101):
				if not _near(_px(img, r, x, y), top):
					bad["portrait"] = true
		for y in range(int(ROSTER.SPLIT) + 9, int(ROSTER.SPLIT) + 19):
			for x in range(56, 77):
				if not _near(_px(img, r, x, y), info):
					bad["info"] = true
		if not q.is_keeper():
			for y in range(12, int(ROSTER.SPLIT)):
				for x in range(1, 101):
					if (x < 21 or x > 81) and not _near(_px(img, r, x, y), top):
						bad["margins"] = true
			for y in range(1, int(ROSTER.SPLIT)):
				for x in range(28, 75):
					if not _near(_px(img, r, x, y), top):
						headroom = mini(headroom, y)
						break
		if not Development.is_maxed(q):
			var xy := int(ROSTER.XP_Y)
			var mid := 50
			if not (_near(_px(img, r, mid, xy - 1), info) and _near(_px(img, r, mid, xy + 2), info)
					and _px(img, r, mid, xy) != info and _px(img, r, mid, xy + 1) != info):
				bad["xp"] = true
		if q.stars >= 1.0 and not _star_at(img, r, 0, 1.0, info):
			bad["star"] = true
	runner.check(not bad.has("border"), "every card: one clean white border")
	runner.check(not bad.has("portrait") and not bad.has("info"), "solid portrait and info panels: no textures or stray pixels")
	runner.check(not bad.has("margins"), "the smaller portraits leave clear space on both sides")
	# (zoomed in since the Portrait Zoom update: the cap whole, a pixel's margin over it)
	runner.check(headroom >= 2 and headroom < 99, "space over every head, the cap whole (first row %d)" % headroom)
	runner.check(not bad.has("xp"), "a 2 px XP bar, clear above and below")
	runner.check(not bad.has("star"), "a full star's pixels: gold five-pointed star, dark outline")
	# a 3.5-star: three gold, one half, nothing for POTENTIAL (Roster Star Display Cleanup)
	var probe: PoloPlayer = null
	for k in ["cf", "pt", "lw", "rw", "lf", "rf"]:
		var q: PoloPlayer = scr.at(PoloTeam.LINEUP_SPOTS.find(k))
		if q != null and not Development.is_maxed(q):
			probe = q
			break
	var was := [probe.stars, probe.pot_stars]
	probe.stars = 3.5
	probe.pot_stars = 5.0
	var card: Control = scr.cards[probe.id]
	var cr: Rect2 = card.get_global_rect()
	card.queue_redraw()
	img = await _shot(runner)
	runner.check(_star_at(img, cr, 2, 1.0, ROSTER.INFO_BG) and _star_at(img, cr, 3, 0.5, ROSTER.INFO_BG, true) and _star_at(img, cr, 4, 0.0, ROSTER.INFO_BG, true),
		"3.5 stars on the card: a half-gold fourth star, then only the panel (no hollow POTENTIAL)")
	# HOT: a red star the same shape, his permanent stars unchanged
	probe.heat = 1
	card.queue_redraw()
	img = await _shot(runner)
	var red := true
	var at := Vector2i(int(cr.position.x + ROSTER.STAR_X + Deck.star_x(4)), int(cr.position.y + ROSTER.STAR_Y))
	for c: Vector2i in _cells(Deck.STAR_INNER):
		if HotBadge.CORE.has(c):
			continue   # (the fire's hot core glows in its middle)
		red = red and _near(img.get_pixelv(at + c), PlayerForm.FIRE_RED)
	runner.check(red and is_equal_approx(probe.stars, 3.5), "HOT: a red star of the same shape after the half gold one, CURRENT still 3.5")
	probe.heat = 0
	probe.stars = was[0]
	probe.pot_stars = was[1]
	card.queue_redraw()
	# an unspent token changes nothing above the XP bar
	var before := (await _shot(runner)).get_region(Rect2i(Vector2i(cr.position), Vector2i(102, int(ROSTER.XP_Y))))
	probe.tokens = 2
	card.queue_redraw()
	var after := (await _shot(runner)).get_region(Rect2i(Vector2i(cr.position), Vector2i(102, int(ROSTER.XP_Y))))
	runner.check(before.get_data() == after.get_data(), "two unspent tokens: the card looks exactly the same (no badge)")
	probe.tokens = 0
	# hurt: the medical cross under his cap number (still in tests: its normal red), a red border,
	# the panels a touch darker red; healed, all of it gone
	Development.injure(probe, RandomNumberGenerator.new(), "minor")
	card.queue_redraw()
	img = await _shot(runner)
	var cx := int(ROSTER.CARD.x - ROSTER.CROSS_X - 5.0)
	var cy := int(ROSTER.CROSS_Y)
	var cross_ok := true
	for y in ROSTER.CROSS.size():
		var row: String = ROSTER.CROSS[y]
		for x in row.length():
			if row[x] == "r" and not _near(_px(img, cr, cx + x, cy + y), ROSTER.INJURY):
				cross_ok = false
			elif row[x] == "w" and not _near(_px(img, cr, cx + x, cy + y), UI.TEXT):
				cross_ok = false
	var reds := 0
	for y in int(ROSTER.CARD.y):
		for x in 102:
			reds += 1 if _near(_px(img, cr, x, y), ROSTER.INJURY) else 0
	runner.check(cross_ok and reds >= 25, "injured: the big medical cross, red with a white outline (%d red px)" % reds)
	runner.check(_near(_px(img, cr, 0, 20), ROSTER.INJURY_EDGE) and _near(_px(img, cr, 101, 50), ROSTER.INJURY_EDGE),
		"injured: a thin red border")
	runner.check(_near(_px(img, cr, 50, 1), ROSTER.hurt_tint(ROSTER.TOP_BG)) and not _near(_px(img, cr, 50, 1), ROSTER.TOP_BG),
		"injured: the panels lean dark red")
	Development.heal(probe)
	card.queue_redraw()
	img = await _shot(runner)
	runner.check(_near(_px(img, cr, 0, 20), UI.TEXT) and _near(_px(img, cr, 50, 1), ROSTER.TOP_BG)
			and not _near(_px(img, cr, cx + 4, cy + 4), ROSTER.INJURY),
		"healed: no cross, tint or red border")
	# phone and tablet shapes: the same table, every card on screen, nothing scrolls
	var win := DisplayServer.window_get_size()
	for sz in [Vector2i(1170, 540), Vector2i(1334, 750), Vector2i(1024, 768)]:
		DisplayServer.window_set_size(sz)
		await _frames(runner, 4)
		var vis := runner.get_viewport().get_visible_rect()
		var ok := true
		for i in PoloTeam.LINEUP_SPOTS.size():
			var slot: Control = scr.slots[i]
			var sr := slot.get_global_rect()
			ok = ok and vis.encloses(sr) and slot.size == ROSTER.CARD and slot.position == ROSTER.spot_pos(PoloTeam.LINEUP_SPOTS[i])
		runner.check(ok, "%dx%d: all ten places on screen, same sizes and places" % [sz.x, sz.y])
		await _shot(runner)
	DisplayServer.window_set_size(win)
	await _frames(runner, 2)

## Is star place `i` on card `r` drawn as the shared star: lit (`fill` 1 gold, 0.5 its left half)
## with a dark outline, the rest hollow (`bare`: the rest the panel too), and the card's panel round it?
func _star_at(img: Image, r: Rect2, i: int, fill: float, panel: Color, bare: bool = false) -> bool:
	var at := Vector2(ROSTER.STAR_X + Deck.star_x(i), ROSTER.STAR_Y)
	var inner := _cells(Deck.STAR_INNER)
	var shape := _cells(Deck.STAR)
	var lit := Deck._cols(fill)
	for y in 9:
		for x in 9:
			var c := _px(img, r, int(at.x) + x, int(at.y) + y)
			var k := Vector2i(x, y)
			var want := panel
			if bare and x >= lit:
				pass
			elif inner.has(k):
				want = PlayerForm.GOLD if x < lit else Deck.STAR_HOLLOW
			elif shape.has(k):
				want = Deck.STAR_EDGE if x < lit else Deck.STAR_OPEN
			if not _near(c, want):
				return false
	return true

## Dialogs and toasts off the screen (the screen fade stays).
static func _close_overlays() -> void:
	var ov = Game.get("overlay")
	if ov is Node:
		for ch in (ov as Node).get_children():
			if ch != Game.get("_fade"):
				ch.free()

static func _cells(rows: Array) -> Dictionary:
	var out := {}
	for y in rows.size():
		var row: String = rows[y]
		for x in row.length():
			if row[x] == "#":
				out[Vector2i(x, y)] = true
	return out

static func _scripts(dir: String) -> Array:
	var out: Array = []
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".gd"):
			out.append(dir.path_join(f))
	for d in DirAccess.get_directories_at(dir):
		out.append_array(_scripts(dir.path_join(d)))
	return out

static func _px(img: Image, r: Rect2, x: int, y: int) -> Color:
	return img.get_pixel(int(r.position.x) + x, int(r.position.y) + y)

static func _near(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) < 0.02 and absf(a.g - b.g) < 0.02 and absf(a.b - b.b) < 0.02

func _frames(runner: Node, n: int) -> void:
	for i in n:
		await runner.get_tree().process_frame

func _shot(runner: Node) -> Image:
	await RenderingServer.frame_post_draw
	return runner.get_viewport().get_texture().get_image()

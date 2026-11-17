extends BaseScreen
## THE TROPHY ROOM (the National Awards & Trophy Room update): one player's whole career of honours,
## from the records themselves (Honours: by his id, whatever school he's at now, each honour named
## for where he won it). Opened from his page's TROPHY CASE; back returns to that page as it was
## (yours, an award winner's, or a scouted opponent's: nothing here shows potential or edits a thing).
##   WEEKLY AWARDS   a dark wood board, a brass plaque for every weekly award he's won ("2027 WEEK 3"
##                   / "NCC OFFENSIVE POTW"), oldest first, four across, scrolling when there are many;
##                   empty mounts when he has none (never a plaque he didn't earn)
##   MAJOR AWARDS    a glass cabinet, spotlights over a shelf: a trophy for each honour (TrophyArt:
##                   one silhouette an award), its gold nameplate and every year he won it (x2 when
##                   it's more than one), more shelves as they fill; NO MAJOR AWARDS YET when empty
## Tap a plaque or a trophy: everything its record kept (the award, the year and week, the school
## and conference he won it for, the stats that won it).
## DETAIL MODE (Game.set_detail): this screen is drawn at the window's pixels, its art at a third of
## a game pixel (two screen pixels at the usual 3x): the wood grain, the brass, the glass, the trophies.

const BOARD_H := 76
const PLAQUE := Vector2(110, 21)
const PLAQUE_GAP := Vector2(5, 4)
const TROPHY_W := 84
const SHELF_H := 62
const PER_SHELF := 5
const ART := 2.0 / 3.0          # game pixels an art pixel (2 screen pixels at 3x)
const WOOD := Color("5a3018")
const WOOD_D := Color("3a1c0c")
const WOOD_L := Color("7a4424")
const FRAME := Color("2a1408")
const BRASS := Color("d9b24a")
const BRASS_D := Color("8e6a1c")
const BRASS_L := Color("fbe9a6")
const INK := Color("2b1a06")
const GLASS := Color("0b1d5c")
const GLASS_D := Color("071237")

var pid := 0
var back_params := {}
var player: PoloPlayer = null
var honours: Array = []
var preview: Career = null     # Developer Mode's preview: a throwaway career (never Game.career, never saved)
var back_to := ""              # ...and the screen Back goes to
var team_id := ""              # TEAM MODE (the team trophy case): a program's championships, not a player's honours
static var _grain: ImageTexture = null

func setup(params: Dictionary) -> void:
	pid = int(params.get("id", 0))
	back_params = params.get("back", {"id": pid})
	preview = params.get("preview") as Career
	back_to = String(params.get("back_to", ""))
	team_id = String(params.get("team", ""))
	detail = true

func _ready() -> void:
	c = preview if preview != null else Game.career
	if team_id != "":
		_team_ready()
		return
	player = ConfAwards.player_of(c, {"pid": pid}) if c != null else null
	if player == null:
		Game.goto("hub")
		return
	build("TROPHY ROOM" if preview == null else "TROPHY ROOM (PREVIEW)", true, preview == null)
	if preview != null:
		c = preview   # (build reads Game.career: the preview keeps its own)
	honours = Honours.of(c, pid, player)
	var name_line := UI.label("%s %s  -  %s" % [player.first.to_upper(), player.last.to_upper(), _school(player)], 8, UI.ACCENT, "caps")
	name_line.name = "WhoseRoom"
	name_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(name_line)
	body.add_child(_board(honours.filter(func(e): return e.kind == "weekly")))
	body.add_child(_cabinet(_majors(honours)))

## TEAM MODE (the Dynasty Hub's TROPHY CASE): the program's championships (TeamHonours), the
## same room: a brass plaque on the board for every title (its year, which one), and in the glass
## cabinet a trophy for each kind (the conference's silver cup, the NCSA's gold), how many, the
## years. Tap either for its record.
func _team_ready() -> void:
	if c == null or not c.teams.has(team_id):
		Game.goto("hub")
		return
	build("TEAM TROPHY CASE", true, true)
	honours = TeamHonours.of(c, team_id)
	var t: PoloTeam = c.teams[team_id]
	var n := honours.size()
	var name_line := UI.label("%s  -  %s" % [Colleges.display_name(t.name).to_upper(), ("%d CHAMPIONSHIP%s" % [n, "" if n == 1 else "S"]) if n > 0 else "NO TITLES YET"], 8, UI.ACCENT, "caps")
	name_line.name = "WhoseRoom"
	name_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(name_line)
	body.add_child(_board(honours, "CHAMPIONSHIPS", "NO CHAMPIONSHIPS YET"))
	body.add_child(_cabinet(_majors(honours), "TROPHY CASE", "NO TROPHIES YET"))

func on_back() -> void:
	Sfx.play("back")
	# a return, not a new visit: the history's entry for where we came from is used up, so the
	# screens that go back by history (Settings) never cycle back in here
	var target := back_to if back_to != "" else "player"
	if not Game.history.is_empty() and String(Game.history.back()) == target:
		Game.history.pop_back()
	Game.goto(target, {} if back_to != "" else back_params, false)

func _school(p: PoloPlayer) -> String:
	for id in c.teams:
		if (c.teams[id] as PoloTeam).find_id(p.id) != null:
			return Colleges.display_name((c.teams[id] as PoloTeam).name).to_upper()
	return "ALUMNUS"

# ------------------------------------------------------------------ the weekly board
func _board(weekly: Array, title := "WEEKLY AWARDS", empty := "NO WEEKLY AWARDS YET") -> Control:
	var board := UI.canvas(0, BOARD_H, _paint_board)
	board.name = "WeeklyBoard"
	board.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	board.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var inner := UI.vbox(3)
	var m := UI.margin(inner, 9, 5, 9, 7)
	m.set_anchors_preset(Control.PRESET_FULL_RECT)
	board.add_child(m)
	inner.add_child(_title_plate(title))
	var grid := GridContainer.new()
	grid.name = "Plaques"
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", int(PLAQUE_GAP.x))
	grid.add_theme_constant_override("v_separation", int(PLAQUE_GAP.y))
	if weekly.is_empty():
		for i in 8:
			grid.add_child(UI.canvas(int(PLAQUE.x), int(PLAQUE.y), _paint_mount))
	for e in weekly:
		var pl := UI.canvas(int(PLAQUE.x), int(PLAQUE.y), func(ci): _paint_plaque(ci, e))
		pl.name = "Plaque"
		pl.set_meta("entry", e)
		pl.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_clickable(pl, func(): _show(e))
		grid.add_child(pl)
	var center := CenterContainer.new()
	center.add_child(grid)
	var sc := UI.scroll(center)
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inner.add_child(sc)
	if weekly.is_empty():
		board.add_child(_overlay("NoWeekly", empty, BRASS_L, 16))
	return board

func _paint_board(ci: Control) -> void:
	var r := Rect2(Vector2.ZERO, ci.size)
	ci.draw_rect(r, FRAME)
	ci.draw_texture_rect(_wood(), r.grow(-3), false)
	# the frame: a dark rim, a lit inner edge, the wood's bevel
	ci.draw_rect(r, Color.BLACK, false, 1.0)
	ci.draw_rect(r.grow(-3), WOOD_L, false, ART)
	# brass screws in the corners
	for p in [Vector2(5, 5), Vector2(r.size.x - 5, 5), Vector2(5, r.size.y - 5), Vector2(r.size.x - 5, r.size.y - 5)]:
		_screw(ci, p)

## A plaque: brass with a bevel, a dark engraved line (year and week) over the award, screws at its ends.
func _paint_plaque(ci: Control, e: Dictionary) -> void:
	var r := Rect2(Vector2.ZERO, PLAQUE)
	ci.draw_rect(r, BRASS_D)
	ci.draw_rect(r.grow(-ART), BRASS)
	ci.draw_rect(Rect2(ART, ART, PLAQUE.x - 2 * ART, ART), BRASS_L)
	ci.draw_rect(Rect2(ART, PLAQUE.y - 2 * ART, PLAQUE.x - 2 * ART, ART), BRASS_D)
	_screw(ci, Vector2(3, PLAQUE.y * 0.5), 1.0)
	_screw(ci, Vector2(PLAQUE.x - 3, PLAQUE.y * 0.5), 1.0)
	var top := "%d %s" % [int(e.year), String(e.week)] if int(e.year) > 0 else String(e.week)
	Deck.text(ci, 0, 6, Deck.fit(top, PLAQUE.x - 12), 8, INK, "caps", HORIZONTAL_ALIGNMENT_CENTER, PLAQUE.x)
	Deck.text(ci, 0, 14.5, Deck.fit(String(e.short), PLAQUE.x - 12, 8, "body"), 8, INK, "body", HORIZONTAL_ALIGNMENT_CENTER, PLAQUE.x)

## An empty mount: where a plaque would hang, its screw holes.
func _paint_mount(ci: Control) -> void:
	var r := Rect2(Vector2.ZERO, PLAQUE)
	ci.draw_rect(r, Color(0, 0, 0, 0.18))
	ci.draw_rect(r, Color(WOOD_L, 0.6), false, ART)
	ci.draw_circle(Vector2(3, PLAQUE.y * 0.5), 0.8, Color(0, 0, 0, 0.5))
	ci.draw_circle(Vector2(PLAQUE.x - 3, PLAQUE.y * 0.5), 0.8, Color(0, 0, 0, 0.5))

func _screw(ci: CanvasItem, p: Vector2, r := 1.5) -> void:
	ci.draw_circle(p, r, Color("9aa0aa"))
	ci.draw_circle(p + Vector2(-ART * 0.5, -ART * 0.5), r * 0.5, Color.WHITE)
	ci.draw_rect(Rect2(p.x - r * 0.7, p.y - ART * 0.5, r * 1.4, ART), Color("50545c"))

## The wood: grain at a third of a game pixel, made once.
func _wood() -> ImageTexture:
	if _grain == null:
		var img := Image.create(480 * 3, BOARD_H * 3, false, Image.FORMAT_RGBA8)
		var rng := RandomNumberGenerator.new()
		rng.seed = 7
		for y in img.get_height():
			var band := sin(y * 0.21) * 0.5 + sin(y * 0.047 + 1.3) * 0.5
			for x in img.get_width():
				var wave := sin((x * 0.011) + y * 0.09 + sin(x * 0.003) * 3.0)
				var t := clampf(0.5 + 0.28 * band + 0.18 * wave, 0.0, 1.0)
				var col := WOOD_D.lerp(WOOD_L, t)
				if rng.randf() < 0.012:
					col = col.darkened(0.25)
				img.set_pixel(x, y, col)
		_grain = ImageTexture.create_from_image(img)
	return _grain

# ------------------------------------------------------------------ the cabinet
## The honours that get trophies, one a kind of honour: {key, cat, title, entries (each year's)}.
func _majors(all: Array) -> Array:
	var out: Array = []
	var by := {}
	for e in all:
		if e.kind == "weekly":
			continue
		if not by.has(e.key):
			by[e.key] = {"key": e.key, "cat": TrophyArt.cat_of(e), "title": String(e.title), "ncsa": not (e.kind == "tourney" and String(e.get("tid", "")) != "nat"), "entries": []}
			out.append(by[e.key])
		(by[e.key].entries as Array).append(e)
	var rank := {"ncsa_champ": -2, "conf_champ": -1, "poy": 0, "dpoy": 1, "foy": 2, "arm": 3, "wall": 4, "first": 5, "second": 6, "pot": 7, "opot": 8, "dpot": 9}
	out.sort_custom(func(a, b): return int(rank.get(a.cat, 10)) < int(rank.get(b.cat, 10)))
	return out

func _cabinet(majors: Array, title := "MAJOR AWARDS", empty := "NO MAJOR AWARDS YET") -> Control:
	var cab := UI.canvas(0, 0, _paint_cabinet)
	cab.name = "Cabinet"
	cab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cab.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cab.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var inner := UI.vbox(0)
	var m := UI.margin(inner, 7, 14, 7, 2)
	m.set_anchors_preset(Control.PRESET_FULL_RECT)
	cab.add_child(m)
	# the cabinet's name on a brass plate over the top of its frame
	var top := CenterContainer.new()
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_top = 1
	top.add_child(_title_plate(title))
	cab.add_child(top)
	var shelves := UI.vbox(0)
	shelves.name = "Shelves"
	var row: HBoxContainer = null
	for t in majors:
		if row == null or row.get_child_count() >= PER_SHELF:
			row = UI.hbox(4)
			row.alignment = BoxContainer.ALIGNMENT_CENTER
			shelves.add_child(row)
		var tr := UI.canvas(TROPHY_W, SHELF_H, func(ci): _paint_trophy(ci, t))
		tr.name = "Trophy_" + String(t.cat)
		tr.set_meta("trophy", t)
		tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_clickable(tr, func(): _show_trophy(t))
		row.add_child(tr)
	# room under the last shelf, so its years scroll fully into view (never cut at the glass)
	if shelves.get_child_count() > 2:
		shelves.add_child(UI.spacer(0, 8))
	var sc := UI.scroll(shelves)
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inner.add_child(sc)
	if majors.is_empty():
		cab.add_child(_overlay("NoMajors", empty, UI.DIM, 10))
	return cab

func _paint_cabinet(ci: Control) -> void:
	var r := Rect2(Vector2.ZERO, ci.size)
	ci.draw_rect(r, FRAME)
	ci.draw_texture_rect(_wood(), Rect2(r.position + Vector2(1, 1), r.size - Vector2(2, 2)), false)
	var glass := r.grow(-5)
	ci.draw_rect(glass, GLASS_D)
	ci.draw_rect(Rect2(glass.position, Vector2(glass.size.x, glass.size.y * 0.55)), GLASS)
	# spotlights along the top, their light falling on the shelf
	var n := maxi(3, int(glass.size.x / 70.0))
	for i in n:
		var x := glass.position.x + glass.size.x * (i + 0.5) / n
		ci.draw_rect(Rect2(x - 3, glass.position.y, 6, 2), Color("c9cfd9"))
		ci.draw_rect(Rect2(x - 2, glass.position.y + 2, 4, ART), Color("fff7c2"))
		var cone := PackedVector2Array([Vector2(x - 2, glass.position.y + 2), Vector2(x + 2, glass.position.y + 2),
			Vector2(x + 18, glass.end.y - 6), Vector2(x - 18, glass.end.y - 6)])
		ci.draw_colored_polygon(cone, Color(1, 0.95, 0.7, 0.07))
	# the glass's reflections: two thin diagonal streaks
	for k in [0.2, 0.72]:
		var gx: float = glass.position.x + glass.size.x * k
		ci.draw_line(Vector2(gx, glass.end.y - 4), Vector2(gx + 26, glass.position.y + 4), Color(1, 1, 1, 0.07), ART * 3)
	ci.draw_rect(glass, Color("c9cfd9"), false, ART)
	ci.draw_rect(r, Color.BLACK, false, 1.0)

## A trophy on its shelf: the wood shelf under it, the trophy (TrophyArt at ART), its gold
## nameplate (the award, wrapped to two lines) and the years (x2 when it's more than one).
func _paint_trophy(ci: Control, t: Dictionary) -> void:
	var w := float(TROPHY_W)
	var tex: ImageTexture = TrophyArt.texture(String(t.cat), bool(t.ncsa))
	var tw := TrophyArt.W * ART
	var th := TrophyArt.H * ART
	var shelf_y := th + 1.0
	ci.draw_rect(Rect2(0, shelf_y, w, 3), WOOD)
	ci.draw_rect(Rect2(0, shelf_y, w, ART), WOOD_L)
	ci.draw_texture_rect(tex, Rect2(_snap((w - tw) * 0.5), 1.0, tw, th), false)
	var n := (t.entries as Array).size()
	if n > 1:
		var badge := "x%d" % n
		var bw := Deck.text_w(badge) + 4
		ci.draw_rect(Rect2(w - bw - 2, 10, bw, 9), UI.GOLD)   # (beside the cup, clear of the cabinet's title plate)
		Deck.text(ci, w - bw - 2, 14.5, badge, 8, UI.INK, "caps", HORIZONTAL_ALIGNMENT_CENTER, bw)
	# the nameplate
	var plate := Rect2(1, shelf_y + 4, w - 2, 17)
	ci.draw_rect(plate, BRASS_D)
	ci.draw_rect(plate.grow(-ART), BRASS)
	var lines := _wrap(_plate_title(String(t.title), plate.size.x - 4), plate.size.x - 4)
	for i in mini(2, lines.size()):
		Deck.text(ci, plate.position.x, plate.position.y + 4.5 + i * 8, lines[i], 8, INK, "body", HORIZONTAL_ALIGNMENT_CENTER, plate.size.x)
	var years: Array = []
	for e in t.entries:
		if int(e.year) > 0 and not int(e.year) in years:
			years.append(int(e.year))
	years.sort()
	Deck.text(ci, 0, plate.end.y + 4, years_text(years, w), 8, UI.GOLD, "caps", HORIZONTAL_ALIGNMENT_CENTER, w)

## The years under a trophy, all of them, in the room there is: "2027, 2028", else a run as
## "2027-30", else the short years "'27 '29 '31", else the first and last ("2027 - 2031").
static func years_text(years: Array, w: float) -> String:
	var full := ", ".join(years.map(func(y): return str(y)))
	if years.size() <= 1 or Deck.text_w(full) <= w:
		return full
	var run := true
	for k in range(1, years.size()):
		run = run and int(years[k]) == int(years[k - 1]) + 1
	if run:
		return "%d-%02d" % [int(years[0]), int(years.back()) % 100]
	var short := " ".join(years.map(func(y): return "'%02d" % (int(y) % 100)))
	if Deck.text_w(short) <= w:
		return short
	return "%d - %d" % [int(years[0]), int(years.back())]

## A nameplate's words: the award without "NCSA" where its trophy already says it.
## Still too long for two lines: OFFENSIVE / DEFENSIVE shortened.
func _plate_title(title: String, w: float = 1e9) -> String:
	var t := title.trim_prefix("NCSA ").replace(" OF THE TOURNAMENT", " OF TOURNEY")
	if t == "CHAMPIONS":
		t = title   # (a team's NCSA title keeps its name: the NCSA's is the point)
	if _wrap(t, w, false).size() > 2:
		t = t.replace("OFFENSIVE ", "OFF. ").replace("DEFENSIVE ", "DEF. ")
	return t

static func _snap(v: float) -> float:
	return roundf(v / ART) * ART

static func _wrap(text: String, w: float, cut := true) -> Array:
	text = Loc.t(text)   # (the player's LANGUAGE: translated whole, then wrapped)
	var out: Array = []
	var line := ""
	for word: String in Loc.units(text):
		var next := word if line == "" else line + Loc.gap() + word
		if Deck.text_w(next, 8, "body") <= w or line == "":
			line = next
		else:
			out.append(line)
			line = word
	if line != "":
		out.append(line)
	if cut and out.size() > 2:
		out[1] = Deck.fit(Loc.gap().join(out.slice(1)), w, 8, "body")
	return out

# ------------------------------------------------------------------ shared
## An empty case's words, centred over it (a little below the middle, clear of its title plate).
func _overlay(n: String, t: String, col: Color, down: int) -> Control:
	var cc := CenterContainer.new()
	cc.name = n
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	cc.offset_top = down
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := UI.label(t, 8, col, "caps")
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cc.add_child(l)
	return cc

func _title_plate(t: String) -> Control:
	var tw := Deck.text_w(t, 16, "big") + 24
	var plate := UI.canvas(int(tw), 14, func(ci: Control):
		var r := Rect2(Vector2.ZERO, ci.size)
		ci.draw_rect(r, BRASS_D)
		ci.draw_rect(r.grow(-ART), BRASS)
		ci.draw_rect(Rect2(ART, ART, r.size.x - 2 * ART, ART), BRASS_L)
		Deck.text(ci, 0, 7, t, 16, INK, "big", HORIZONTAL_ALIGNMENT_CENTER, r.size.x))
	plate.name = "Plate_" + t.replace(" ", "_")
	plate.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	return plate

func _clickable(cv: Control, cb: Callable) -> void:
	cv.mouse_filter = Control.MOUSE_FILTER_STOP
	cv.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	cv.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT and not ev.pressed:
			Sfx.play("click")
			cb.call())

## A plaque's record: the award, when, where, for whom, the week that won it.
func _show(e: Dictionary) -> void:
	Game.dialog(String(e.title), _details(e), [["CLOSE", Callable(), "primary"]], "reward")

func _show_trophy(t: Dictionary) -> void:
	var parts := PackedStringArray()
	for e in t.entries:
		parts.append(_details(e))
	Game.dialog(String(t.title), "\n\n".join(parts), [["CLOSE", Callable(), "primary"]], "reward")

func _details(e: Dictionary) -> String:
	var bits := PackedStringArray()
	var when := ("%d" % int(e.year)) if int(e.year) > 0 else "YEAR NOT RECORDED"
	if String(e.week) != "":
		when += "  -  " + String(e.week)
	bits.append(when)
	if String(e.team) != "":
		bits.append("%s%s" % [Colleges.team_name(String(e.team)) if not c.teams.has(String(e.team)) else (c.teams[String(e.team)] as PoloTeam).name,
			("  (%s)" % e.conf) if String(e.conf) != "" and e.kind != "national" else ""])
	if String(e.get("slot", "")) != "":
		bits.append("POSITION: %s" % e.slot)
	if String(e.line) != "":
		bits.append(String(e.line))
	return "\n".join(bits)

extends BaseScreen
## POSTGAME PLAYER DEVELOPMENT: after the game summary, the last postgame screen (the coaching
## event, if one comes, follows it). Your whole roster as a stat sheet (a row a player, a column a
## stat the game recorded), and every player's yellow XP bar filling from where it stood before
## the game to where it stands now.
##
## THE BULLETIN BOARD (the coach's corkboard, as the old POSTGAME REVIEW had it): a wood-framed
## board of cork; the stat sheet a printed report pinned up on it, top to bottom, the result across
## its top. Each
## XP bar is printed on the sheet in the roster cards' XP yellow (the part from before the game
## hatched), a level-up gets a red LEVEL UP! stamp in his DEVELOPMENT column and a highlighter pass over his
## row. Drawn in DETAIL MODE (Game.set_detail): the units are FINE (two-thirds of a game pixel,
## two screen pixels at the usual 3x), so the grain, the pins, the strokes, the bars, the sparkles
## and the small print are all on the high-res pixel grid, the type at the game's own sizes.
##
## Nothing here awards anything. The game's XP was paid once, when the game was settled
## (Career._award_game_xp), and the career kept a snapshot of the roster either side of it
## (Career.dev_snapshot: XP, level index, the XP each token costs, tokens, attributes). This screen
## only animates the difference; SKIP ANIMATION (or Reduce Motion) just shows the end of it.
##
## The timing (seconds since the screen opened):
##   0.0 - 0.5  the sheet's rows come in with every stat
##   0.5 - 1.0  each player's XP for the game appears beside his bar
##   1.0 - 3.0  every bar fills at once, from before to after. Each time one passes a token's
##              threshold: the bar flashes, LEVEL UP! is stamped in his DEVELOPMENT column, pixel sparkles
##              rise round the row, and the bar starts over at the next level's share
##   after      the upgrades each earned (green), MAXED XP for a player at every ceiling,

## CONTINUE ends the postgame: maybe a coaching event (CoachEvents.roll, from the game's review
## data, Postgame), else the week goes on (Career.close_postgame) and back to the hub.

const FINE := 2.0 / 3.0         # game pixels a unit (detail mode)
const T := 12                   # the usual 8-pixel type, in units
const T_SMALL := 8              # small print: two screen pixels a type pixel
const BIG := 24                 # the big type at its usual 16

const CORK := Color("b07a46")
const CORK_D := Color("94622f")
const CORK_L := Color("c48d55")
const WOOD_D := Color("3d2410")
const WOOD_L := Color("8a5a2e")
const PAPER := Color("fdfbf3")          # the printed sheet
const PAPER_EDGE := Color("e6dcc2")
const PAPER_SHADOW := Color(0.18, 0.1, 0.03, 0.45)
const INK := Color("1d2433")            # printed black
const DIM := Color("6a6152")            # printed grey
const FADED := Color("a39a88")          # zeros, did not play
const BLUE := Color("2a4a8a")
const RED := Color("b3261e")
const GREEN := Color("1f8a3a")
const AMBER := Color("9a6400")          # the XP numbers (yellow can't be read on paper)
const RULE := Color(0.42, 0.38, 0.32, 0.28)
const ROW_SHADE := Color(0.45, 0.38, 0.2, 0.05)
const HILITE := Color(1.0, 0.86, 0.2, 0.45)   # the highlighter
const PIN_RED := Color("d8312b")
const PIN_BLUE := Color("2f6fe0")
const PIN_GOLD := Color("e8b923")
const PIN_GREEN := Color("3aa655")
const XP_GOLD := UI.GOLD                # the roster cards' XP yellow (Deck.xp_bar): the bars' fill
const XP_OLD := Color("fbe7a0")         # what the bar held before the game (hatched)
const XP_HATCH := Color("e3b52e")
const XP_EDGE := Color("d89c00")
const XP_HI := Color("fff6c4")
const FRAME := 12.0             # the wooden frame, units
const T_ROW := 12               # a row's numbers (the usual 8-pixel type)
const T_NAME := 16              # a player's name, a size up
const T_SCORE := 32             # the final score, a size up from BIG

const ROW_H := 18.0
const HEAD_H := 18.0
const MATCH_H := 53.0

const SHEET_IN := 0.5           # the rows are in by here
const XP_IN := 1.0              # the XP numbers by here, and the bars start
const FILL_END := 3.0           # ...and are full by here
const FLASH := 0.28             # a level-up's flash
const SPARK := 0.75             # its sparkles
const END := FILL_END + SPARK   # nothing left moving

## The stat columns, field players: [line key, heading]. Every one a stat the match records (S
## his shots, goals among them; % his goals of them).
const FIELD_COLS := [["g", "G"], ["sh", "S"], ["shp", "%"], ["a", "A"], ["st", "STL"], ["bl", "BLK"], ["ed", "EXD"], ["ex", "EX"]]
## ...and a keeper's, in the same places (SV% worked out from his saves and goals against).
const KEEPER_COLS := [["sv", "SV"], ["ga", "GA"], ["pct", "SV%"], ["st", "STL"], ["a", "A"], ["g", "G"], ["", ""], ["", ""]]

var s: Dictionary
var dev: Dictionary
var done := false
var t := 0.0
var animate := true
var rows: Array = []            # field players first, then the keepers (see _row)
var keeper_at := -1             # the index of the first keeper row (the GOALKEEPERS rule above it)
var sheet: Control
var list_cv: Control           # the rows, on their own canvas clipped to the list
var skip_btn: Button
var scroll := 0.0               # units
var _drag_from := -1.0
var totals := {}

func setup(params: Dictionary) -> void:
	detail = true
	# (a test can open it part-way through: {"t": seconds, "freeze": true})
	if params.has("t"):
		t = float(params.t)
		animate = not bool(params.get("freeze", false))
		set_meta("forced", true)

func _ready() -> void:
	c = Game.career
	if c == null or c.last_summary.is_empty():
		Game.goto("hub")
		return
	s = c.last_summary
	if (s.get("dev", {}) as Dictionary).is_empty():
		_continue.call_deferred()   # (nothing to show: the postgame just ends as it would)
		return
	dev = s.dev
	if not has_meta("forced") and (Game.test_mode or not Juice.enabled()):
		t = END   # (Reduce Motion: the finished sheet, nothing moving)
		animate = false
	_make_rows()
	build("POSTGAME PLAYER DEVELOPMENT", false, true)
	sheet = UI.canvas(0, 0, _draw_sheet)
	sheet.name = "Sheet"
	sheet.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sheet.mouse_filter = Control.MOUSE_FILTER_STOP
	sheet.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sheet.gui_input.connect(_on_input)
	body.add_child(sheet)
	list_cv = UI.canvas(0, 0, _draw_list)
	list_cv.name = "Rows"
	list_cv.clip_contents = true
	list_cv.mouse_filter = Control.MOUSE_FILTER_STOP
	list_cv.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	list_cv.gui_input.connect(_on_input)
	sheet.add_child(list_cv)
	sheet.resized.connect(_place_list)
	var row := UI.hbox(4)
	row.alignment = BoxContainer.ALIGNMENT_END
	body.add_child(row)
	skip_btn = UI.button("SKIP ANIMATION", skip, "normal", 110, 24)
	skip_btn.name = "Skip"
	skip_btn.visible = t < END
	row.add_child(skip_btn)
	var cont := UI.button("CONTINUE  >", _continue, "primary", 150, 24)
	cont.name = "Continue"
	row.add_child(cont)
	Sfx.music("menu")

func _process(dt: float) -> void:
	if not animate or t >= END:
		return
	var was := t
	t = minf(t + dt, END)
	for r in rows:
		for tc in r.cross_t:
			if was < float(tc) and t >= float(tc):
				Sfx.play("click")
	if t >= END and skip_btn != null:
		skip_btn.visible = false
	_redraw()

## SKIP ANIMATION: straight to the finished sheet (the values were final all along).
func skip() -> void:
	t = END
	if skip_btn != null:
		skip_btn.visible = false
	_redraw()

func on_back() -> void:
	_continue()

## The end of the postgame (nothing is awarded here): now, and only now, maybe a coaching event
## (CoachEvents.roll, from the game's review data); what the last decisions came to and the new
## event come on the event's screen. Else the postgame is over (the week may end) and the hub.
func _continue() -> void:
	if done:
		return
	done = true
	var rv: Dictionary = s.get("review", {})
	var ev := CoachEvents.roll(c, rv) if not rv.is_empty() and c.pending_event.is_empty() else c.pending_event
	if not ev.is_empty() or not CoachEvents.unshown(c).is_empty():
		c.pending_event = ev
		Game.save_career()
		Game.goto("coach_event")
		return
	c.close_postgame()
	Game.save_career()
	Game.goto("hub")

# ------------------------------------------------------------------ the rows
## A row for every player on the roster now (starters, subs, keepers), from the snapshots either
## side of the game's XP and his stat line:
##   {p, keeper, played, line, xp, f0, f1, levels, hold (ends full: his tokens cover his potential),
##    maxed, capped (was already full before), ups [[key, from, to]], dist, cross [bar positions],
##    cross_t [seconds]}
func _make_rows() -> void:
	var before: Dictionary = dev.get("before", {})
	var after: Dictionary = dev.get("after", {})
	var lines: Dictionary = dev.get("lines", {})
	var xp: Dictionary = dev.get("xp", {})
	var field: Array = []
	var keepers: Array = []
	for p in c.team().roster:
		var b: Dictionary = before.get(p.id, {})
		var a: Dictionary = after.get(p.id, {})
		if b.is_empty() or a.is_empty():
			continue   # (joined after the game: nothing of his to show)
		var r := {"p": p, "keeper": p.is_keeper(), "played": lines.has(p.id), "line": lines.get(p.id, {}),
			"xp": int((xp.get(p.id, {}) as Dictionary).get("xp", 0)), "levels": maxi(0, int(a.idx) - int(b.idx)),
			"maxed": bool(a.maxed), "capped": false, "hold": false, "ups": [],
			"to_next": maxi(0, int(a.need) - int(a.xp))}
		r.f0 = _share(b)
		r.f1 = _share(a)
		# already as developed as he can get before the game (every box covered by a token he
		# holds, or every ceiling reached): a full, still bar
		if int(b.left) <= 0 or int(b.tokens) >= int(b.left):
			r.capped = true
			r.f0 = 1.0
			r.f1 = 1.0
		elif int(a.left) <= 0 or int(a.tokens) >= int(a.left):
			r.hold = true   # this game's XP took him to his potential: fills, and stays full
			r.f1 = 1.0
		for k in (a.attrs as Dictionary):
			var v0 := float((b.attrs as Dictionary).get(k, a.attrs[k]))
			var v1 := float(a.attrs[k])
			if v1 > v0 + Attributes.PRECISION:
				r.ups.append([k, v0, v1])
		_path(r)
		(keepers if r.keeper else field).append(r)
	var order := func(x, y) -> bool:
		if bool(x.played) != bool(y.played):
			return bool(x.played)
		if int(x.xp) != int(y.xp):
			return int(x.xp) > int(y.xp)
		return (x.p as PoloPlayer).number < (y.p as PoloPlayer).number
	field.sort_custom(order)
	keepers.sort_custom(order)
	rows = field + keepers
	keeper_at = field.size() if not keepers.is_empty() else -1
	var team_xp := 0
	var leveled := 0
	var upgrades := 0
	for r in rows:
		team_xp += int(r.xp)
		leveled += 1 if int(r.levels) > 0 else 0
		upgrades += int(r.levels) + (r.ups as Array).size()
	totals = {"xp": team_xp, "leveled": leveled, "upgrades": upgrades}

## 0..1 of the way to his next token, from a snapshot.
static func _share(d: Dictionary) -> float:
	return clampf(float(d.xp) / maxf(1.0, float(d.need)), 0.0, 1.0)

## How far his bar travels (in bars: 1 a whole level) and where it passes each threshold.
func _path(r: Dictionary) -> void:
	var f0: float = r.f0
	var f1: float = r.f1
	var n: int = r.levels
	r.cross = []
	r.cross_t = []
	if r.capped:
		r.dist = 0.0
		return
	if n == 0:
		r.dist = maxf(0.0, f1 - f0)
	else:
		# up to full, n - 1 whole bars, then his share of the next (none if it holds full)
		r.dist = (1.0 - f0) + float(n - 1) + (0.0 if r.hold else f1)
		for j in n:
			var at := (1.0 - f0) + float(j)
			r.cross.append(at)
			r.cross_t.append(_time_at(at / maxf(r.dist, 0.0001)))

## The bars' easing over the fill (a smooth start and a soft landing).
static func _ease(u: float) -> float:
	var x := clampf(u, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)

## When the eased fill reaches share `q` of its way (bisection: the ease only ever rises).
static func _time_at(q: float) -> float:
	var lo := 0.0
	var hi := 1.0
	for i in 24:
		var mid := (lo + hi) * 0.5
		if _ease(mid) < q:
			lo = mid
		else:
			hi = mid
	return XP_IN + hi * (FILL_END - XP_IN)

## How far along its path a row's bar is now (0..dist).
func _pos(r: Dictionary) -> float:
	return float(r.dist) * _ease((t - XP_IN) / (FILL_END - XP_IN))

## The bar now: {fill (0..1), old (the part he had before, this level only), crossed (levels so far)}.
func _bar_state(r: Dictionary) -> Dictionary:
	var f0: float = r.f0
	if r.capped:
		return {"fill": 1.0, "old": 1.0, "crossed": 0}
	var pos := _pos(r)
	var crossed := 0
	for at in r.cross:
		if pos >= float(at) - 0.00001:
			crossed += 1
	if crossed == 0:
		return {"fill": minf(1.0, f0 + pos), "old": f0, "crossed": 0}
	if crossed >= int(r.levels) and r.hold:
		return {"fill": 1.0, "old": 0.0, "crossed": crossed}
	var into := pos - float(r.cross[crossed - 1])
	return {"fill": clampf(into, 0.0, 1.0), "old": 0.0, "crossed": crossed}

## Seconds since his latest level-up (-1: none yet).
func _since_level(r: Dictionary) -> float:
	var best := -1.0
	for tc in r.cross_t:
		if t >= float(tc):
			best = t - float(tc)
	return best

# ------------------------------------------------------------------ input (the sheet scrolls)
func _on_input(ev: InputEvent) -> void:
	var k := _k()
	if ev is InputEventMouseButton and ev.pressed:
		if ev.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_scroll_by(ROW_H * 2.0)
		elif ev.button_index == MOUSE_BUTTON_WHEEL_UP:
			_scroll_by(-ROW_H * 2.0)
		elif ev.button_index == MOUSE_BUTTON_LEFT:
			_drag_from = ev.position.y / k
	elif ev is InputEventMouseButton and not ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		_drag_from = -1.0
	elif ev is InputEventMouseMotion and _drag_from >= 0.0 and (ev.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		var y: float = ev.position.y / k
		_scroll_by(_drag_from - y)
		_drag_from = y
	elif ev is InputEventScreenDrag:
		_scroll_by(-ev.relative.y / k)

func _scroll_by(d: float) -> void:
	var was := scroll
	scroll = clampf(scroll + d, 0.0, _max_scroll())
	if scroll != was:
		_redraw()

## The rows' whole height (the GOALKEEPERS rule included).
func _content_h() -> float:
	return rows.size() * ROW_H + (HEAD_H if keeper_at >= 0 else 0.0)

## The printed sheet pinned on the cork, units.
func _sheet_rect() -> Rect2:
	var size := sheet.size / _k() if sheet != null else Vector2(708, 315)
	var cork := Rect2(Vector2(FRAME, FRAME) + Vector2(2, 2), size - Vector2(3, 3) - Vector2(FRAME, FRAME) * 2.0 - Vector2(4, 4))
	return Rect2(cork.position + Vector2(6, 7), Vector2(cork.size.x - 12.0, cork.size.y - 7.0 - 7.0))

## Where the rows scroll: the sheet under its result and headings.
func _list_rect() -> Rect2:
	var sh := _sheet_rect()
	var top := sh.position.y + 6.0 + MATCH_H + HEAD_H
	return Rect2(Vector2(sh.position.x, top), Vector2(sh.size.x, sh.end.y - 4.0 - top))

func _max_scroll() -> float:
	return maxf(0.0, _content_h() - _list_rect().size.y)

## Units to game pixels: FINE in detail mode, 1 if it's off (still drawn, just larger).
func _k() -> float:
	return FINE if get_window() != null and get_window().content_scale_mode == Window.CONTENT_SCALE_MODE_CANVAS_ITEMS else 1.0

## The rows' own canvas sits exactly over the list and clips to it (what scrolls stays on the sheet).
func _place_list() -> void:
	if list_cv == null or sheet == null:
		return
	var k := _k()
	var lr := _list_rect()
	list_cv.position = (lr.position * k).floor()
	list_cv.size = (lr.size * k).floor()

func _redraw() -> void:
	if sheet != null:
		sheet.queue_redraw()
	if list_cv != null:
		list_cv.queue_redraw()

# ------------------------------------------------------------------ the layout
## Every column's left edge and width in units across the sheet `sh`:
## {num, name, pos, stats (8 [x, w]), xp, bar, status}. Spare width goes to the name and the bar.
func _cols(sh: Rect2) -> Dictionary:
	var spare := maxf(0.0, sh.size.x - 668.0)
	var x := sh.position.x + 6.0
	var out := {}
	out.num = [x, 22.0]
	x += 24.0
	var name_w := 132.0 + floorf(spare * 0.35)
	out.name = [x, name_w]
	x += name_w
	out.pos = [x, 30.0]
	x += 32.0
	var stats: Array = []
	for i in 8:
		var sw := 38.0 if i == 2 else 24.0   # (the % column: "100%")
		stats.append([x, sw])
		x += sw + 1.0
	out.stats = stats
	x += 6.0
	out.xp = [x, 34.0]
	x += 38.0
	var bar_w := 96.0 + floorf(spare * 0.45)
	out.bar = [x, bar_w]
	x += bar_w + 10.0
	out.status = [x, maxf(80.0, sh.end.x - x - 8.0)]
	return out

# ------------------------------------------------------------------ the board's textures
static var _cork: ImageTexture = null
static var _grain: ImageTexture = null

## Cork, a texture pixel a unit: flecks of darker and lighter cork, a few old pin holes.
static func _cork_tex() -> ImageTexture:
	if _cork == null:
		var img := Image.create(96, 96, false, Image.FORMAT_RGBA8)
		var rng := RandomNumberGenerator.new()
		rng.seed = 31
		img.fill(CORK)
		for i in 1400:
			var x := rng.randi() % 96
			var y := rng.randi() % 96
			var roll := rng.randf()
			img.set_pixel(x, y, CORK_D if roll < 0.45 else (CORK_L if roll < 0.85 else Color("7d5026")))
		for i in 14:
			img.set_pixel(rng.randi() % 96, rng.randi() % 96, Color("4a2c12"))
		_cork = ImageTexture.create_from_image(img)
	return _cork

## The frame's wood grain.
static func _grain_tex() -> ImageTexture:
	if _grain == null:
		var img := Image.create(128, 32, false, Image.FORMAT_RGBA8)
		for y in 32:
			var band := 0.5 + 0.5 * sin(y * 0.9) * 0.6
			for x in 128:
				var wave := sin(x * 0.07 + y * 0.6 + sin(x * 0.02) * 2.0)
				var v := clampf(0.35 + 0.25 * band + 0.2 * wave, 0.0, 1.0)
				img.set_pixel(x, y, Color("4e2f14").lerp(Color("7a4a22"), v))
		_grain = ImageTexture.create_from_image(img)
	return _grain

## A pushpin: its shadow, the head (a darker rim, a highlight).
static func _pin(ci: CanvasItem, p: Vector2, col: Color) -> void:
	p = p.floor()
	ci.draw_rect(Rect2(p + Vector2(-2, 1), Vector2(8, 6)), Color(0, 0, 0, 0.3))
	ci.draw_rect(Rect2(p + Vector2(-3, -5), Vector2(8, 8)), col.darkened(0.45))
	ci.draw_rect(Rect2(p + Vector2(-4, -4), Vector2(10, 6)), col.darkened(0.45))
	ci.draw_rect(Rect2(p + Vector2(-3, -4), Vector2(8, 6)), col)
	ci.draw_rect(Rect2(p + Vector2(-2, -5), Vector2(6, 1)), col)
	ci.draw_rect(Rect2(p + Vector2(-2, -3), Vector2(3, 2)), col.lightened(0.45))
	ci.draw_rect(Rect2(p + Vector2(-2, -3), Vector2(1, 1)), Color.WHITE)

## A pinned sheet of paper: its hard shadow on the cork, the paper, a lit top line, an edge.
static func _paper(ci: CanvasItem, r: Rect2, col: Color) -> void:
	ci.draw_rect(Rect2(r.position + Vector2(3, 3), r.size), PAPER_SHADOW)
	ci.draw_rect(r, col)
	ci.draw_rect(Rect2(r.position, Vector2(r.size.x, 1)), Color(1, 1, 1, 0.6))
	ci.draw_rect(r, col.darkened(0.22), false, 1.0)

# ------------------------------------------------------------------ drawing: the board
func _draw_sheet(ci: Control) -> void:
	var k := _k()
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2(k, k))
	var size := ci.size / k
	var r := Rect2(Vector2(2, 2), size - Vector2(5, 5))
	_frame(ci, r)
	var cork := r.grow(-FRAME)
	ci.draw_texture_rect(_cork_tex(), cork, true)
	ci.draw_rect(Rect2(cork.position, Vector2(cork.size.x, 3)), Color(0, 0, 0, 0.25))   # (the frame's shadow on the cork)
	ci.draw_rect(Rect2(cork.position, Vector2(3, cork.size.y)), Color(0, 0, 0, 0.2))
	var sh := _sheet_rect()
	var cols := _cols(sh)
	_paper(ci, sh, PAPER)
	ci.draw_rect(Rect2(sh.position + Vector2(1, 1), Vector2(sh.size.x - 2, 3)), RED)   # (the report's red strip, win or lose)
	_draw_matchup(ci, Rect2(Vector2(sh.position.x, sh.position.y + 6.0), Vector2(sh.size.x, MATCH_H)))
	_draw_heads(ci, Rect2(Vector2(sh.position.x, sh.position.y + 6.0 + MATCH_H), Vector2(sh.size.x, HEAD_H)), cols, FIELD_COLS, INK, "PLAYER")
	if _max_scroll() > 0.0:
		_draw_scrollbar(ci, _list_rect())
	_pin(ci, Vector2(sh.position.x + 10.0, sh.position.y + 4.0), PIN_GOLD)
	_pin(ci, Vector2(sh.end.x - 12.0, sh.position.y + 4.0), PIN_GOLD)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

## The wooden frame: its shadow, the grain, a lit top-left bevel, a dark bottom-right, a nail in each corner.
func _frame(ci: CanvasItem, r: Rect2) -> void:
	ci.draw_rect(Rect2(r.position + Vector2(3, 3), r.size), Color(0, 0, 0, 0.35))
	ci.draw_texture_rect(_grain_tex(), r, true)
	ci.draw_rect(r, WOOD_D, false, 1.0)
	ci.draw_rect(Rect2(r.position + Vector2(1, 1), Vector2(r.size.x - 2, 1)), WOOD_L)
	ci.draw_rect(Rect2(r.position + Vector2(1, 1), Vector2(1, r.size.y - 2)), WOOD_L)
	ci.draw_rect(Rect2(r.position + Vector2(1, r.size.y - 2), Vector2(r.size.x - 2, 1)), WOOD_D)
	ci.draw_rect(Rect2(r.position + Vector2(r.size.x - 2, 1), Vector2(1, r.size.y - 2)), WOOD_D)
	ci.draw_rect(r.grow(-FRAME).grow(1.0), WOOD_D, false, 1.0)
	for p in [r.position + Vector2(6, 6), Vector2(r.end.x - 7, r.position.y + 6), Vector2(r.position.x + 6, r.end.y - 7), r.end - Vector2(7, 7)]:
		ci.draw_rect(Rect2(p - Vector2(1, 1), Vector2(3, 3)), Color("2a1a0c"))
		ci.draw_rect(Rect2(p - Vector2(1, 1), Vector2(1, 1)), Color("c9a77a"))

## The top of the sheet: both schools with their logos and the final score between them, the
## round and the result under it.
func _draw_matchup(ci: CanvasItem, r: Rect2) -> void:
	var g: Dictionary = s.game
	var home: bool = s.home
	var opp: PoloTeam = c.teams.get(String(s.opp))
	var us := c.team()
	var won: bool = s.won
	var sc: Array = g.r.s if g.r != null else [0, 0]
	var so: Array = g.r.so if g.r != null else []
	var mine := int(sc[0] if home else sc[1])
	var theirs := int(sc[1] if home else sc[0])
	# your team always on the left, home or away
	var left_t: PoloTeam = us
	var right_t: PoloTeam = opp
	var ls := mine
	var rs := theirs
	# after a shootout each side's shootout goals in brackets: 10(3) - 10(2)
	var score := Schedule.final_text([ls, rs], [] if so.is_empty() else ([so[0], so[1]] if home else [so[1], so[0]]), " - ")
	var sw := UI.text_width(score, T_SCORE, "big")
	var cx := floorf(r.get_center().x)
	var mid_y := r.position.y + 20.0
	UI.text(ci, Vector2(floorf(cx - sw / 2.0), mid_y + 11.0), score, T_SCORE, INK, "big")
	var room := cx - sw / 2.0 - 18.0 - 42.0 - r.position.x - 20.0
	for side in 2:
		var tm: PoloTeam = left_t if side == 0 else right_t
		if tm == null:
			continue
		var name := Colleges.display_name(tm.name).to_upper()
		name = Deck.fit(name, room - 6.0, T_NAME)
		var col := INK if (tm == us) == won else DIM
		var nw := UI.text_width(name, T_NAME, "caps")
		# (name, logo, score, logo, name: each logo on the inside, next to the score)
		var lb := _logo_size(tm)
		var ly := floorf(mid_y - 1.0 - lb.y / 2.0)
		if side == 0:
			var lx := floorf(cx - sw / 2.0 - 10.0 - lb.x)
			_logo(ci, Vector2(lx, ly), tm)
			UI.text(ci, Vector2(floorf(lx - 8.0 - nw), mid_y + 5.0), name, T_NAME, col, "caps")
		else:
			var lx := floorf(cx + sw / 2.0 + 10.0)
			_logo(ci, Vector2(lx, ly), tm)
			UI.text(ci, Vector2(lx + lb.x + 8.0, mid_y + 5.0), name, T_NAME, col, "caps")
	# just what kind of game it was, centred in the gap between the logos' bottom and the headings
	var info := String(s.get("round", "")).to_upper().replace("NONCONFERENCE", "NON-CONFERENCE")
	var logo_bottom := floorf(mid_y - 1.0 - 20.0) + 40.0
	var cap := UI.font_caps.get_ascent(T)
	var base := floorf((logo_bottom + r.end.y) / 2.0 + cap / 2.0)
	UI.text(ci, Vector2(r.position.x, base), info, T, GREEN, "caps", HORIZONTAL_ALIGNMENT_CENTER, r.size.x)

## A school's logo in the header: its fine artwork (42 x 30, the medium logo drawn in fine pixels)
## 1:1 on this screen's units, half as big again as the usual list logo and still exactly on the
## grid; a team with no artwork keeps the usual one.
static func _logo_tex(tm: PoloTeam) -> Texture2D:
	return TeamLogo.art(tm, TeamLogo.ART_BOXES["40"])

static func _logo_size(tm: PoloTeam) -> Vector2:
	var tex := _logo_tex(tm)
	return Vector2(tex.get_width(), tex.get_height()) if tex != null else Vector2(TeamLogo.box(TeamLogo.MEDIUM, 1))

static func _logo(ci: CanvasItem, at: Vector2, tm: PoloTeam) -> void:
	var tex := _logo_tex(tm)
	if tex == null:
		TeamLogo.paint(ci, at, tm, TeamLogo.MEDIUM, 1, false)
		return
	ci.draw_texture_rect(tex, Rect2(at.floor(), Vector2(tex.get_width(), tex.get_height())), false)

## A heading row, printed (`ink`), a heavy rule under it; `cols_def` the eight stat headings.
func _draw_heads(ci: CanvasItem, r: Rect2, cols: Dictionary, cols_def: Array, ink: Color, first: String) -> void:
	var y := r.position.y + r.size.y * 0.5 - 1.0
	Deck.text(ci, cols.num[0], y, "#", T_SMALL, ink, "caps", 2, cols.num[1])
	Deck.text(ci, cols.name[0] + 2.0, y, first, T_SMALL, ink)
	Deck.text(ci, cols.pos[0], y, "POS", T_SMALL, ink, "caps", 1, cols.pos[1])
	for i in 8:
		var sc: Array = cols.stats[i]
		Deck.text(ci, sc[0], y, String(cols_def[i][1]), T_SMALL, ink, "caps", 1, sc[1])
	# (the keepers' heading leaves XP, PROGRESS and DEVELOPMENT to the one at the top)
	if cols_def != KEEPER_COLS:
		Deck.text(ci, cols.xp[0], y, "XP", T_SMALL, AMBER, "caps", 2, cols.xp[1])
		Deck.text(ci, cols.bar[0], y, "PROGRESS", T_SMALL, ink)
		Deck.text(ci, cols.status[0], y, "DEVELOPMENT", T_SMALL, ink)
	ci.draw_rect(Rect2(Vector2(r.position.x + 6.0, r.end.y - 3.0), Vector2(r.size.x - 12.0, 2)), ink)

# ------------------------------------------------------------------ drawing: the rows (clipped)
func _draw_list(ci: Control) -> void:
	var k := _k()
	ci.draw_set_transform(-ci.position, 0.0, Vector2(k, k))
	var lr := _list_rect()
	var cols := _cols(_sheet_rect())
	var y := lr.position.y - scroll
	for i in rows.size():
		if i == keeper_at:
			if y + HEAD_H > lr.position.y - HEAD_H and y < lr.end.y:
				_draw_heads(ci, Rect2(Vector2(lr.position.x, y), Vector2(lr.size.x, HEAD_H)), cols, KEEPER_COLS, RED, "GOALKEEPERS")
			y += HEAD_H
		if y + ROW_H > lr.position.y - ROW_H * 2.0 and y < lr.end.y + ROW_H:
			_draw_row(ci, rows[i], i, Rect2(Vector2(lr.position.x, y), Vector2(lr.size.x, ROW_H)), cols)
		y += ROW_H
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

## One player's row: (it comes in over 0.2 s, a row after another, by SHEET_IN).
func _draw_row(ci: CanvasItem, r: Dictionary, i: int, rr: Rect2, cols: Dictionary) -> void:
	var stagger := minf(0.025, (SHEET_IN - 0.2) / maxf(1.0, float(rows.size())))
	var a := clampf((t - i * stagger) / 0.2, 0.0, 1.0)
	if a <= 0.0:
		return
	rr.position.x += roundf((1.0 - a) * 10.0)
	var p: PoloPlayer = r.p
	var keeper: bool = r.keeper
	var inner := Rect2(rr.position + Vector2(4, 0), rr.size - Vector2(8, 0))
	if i % 2 == 1:
		ci.draw_rect(inner, Color(ROW_SHADE, ROW_SHADE.a * a))
	# a level-up: a highlighter pass over the whole row, settling to a lighter one
	var since := _since_level(r)
	if since >= 0.0 and since < 0.6:
		ci.draw_rect(inner.grow_individual(0, -1, 0, -1), Color(HILITE, 0.75 * (1.0 - since / 0.6) + 0.3))
	elif int(r.levels) > 0 and since >= 0.6:
		ci.draw_rect(inner.grow_individual(0, -1, 0, -1), Color(HILITE, 0.3))
	ci.draw_rect(Rect2(Vector2(inner.position.x, rr.end.y - 1.0), Vector2(inner.size.x, 1)), Color(RULE, RULE.a * a))
	var y := rr.position.y + rr.size.y * 0.5
	var faded := Color(FADED, a)
	var ink := Color(INK, a)
	var played: bool = r.played
	Deck.text(ci, cols.num[0], y, str(p.number), T_ROW, Color(BLUE, a), "caps", 2, cols.num[1])
	Deck.text(ci, cols.name[0] + 2.0, y, Deck.fit(p.short_name(), cols.name[1] - 4.0, T_NAME), T_NAME, ink if played else faded)
	Deck.text(ci, cols.pos[0], y, p.pos_text(), T_ROW, Color(RED, a) if keeper else Color(DIM, a), "caps", 1, cols.pos[1])
	# the stats
	var defs: Array = KEEPER_COLS if keeper else FIELD_COLS
	var line: Dictionary = r.line
	for j in 8:
		var key := String(defs[j][0])
		if key == "":
			continue
		var sc: Array = cols.stats[j]
		var txt := "-"
		var col := faded
		if played:
			if key == "pct":
				var sv := int(line.get("sv", 0))
				var shots := sv + int(line.get("ga", 0))
				txt = ("%d%%" % roundi(100.0 * sv / shots)) if shots > 0 else "-"
				col = ink
			elif key == "sh" or key == "shp":
				# S his shots, % his goals of them ("-" with no shot); every goal is a shot, so never
				# fewer shots than goals
				var shots := maxi(int(line.get("sh", 0)), int(line.get("g", 0)))
				if key == "sh":
					txt = str(shots)
					col = ink if shots > 0 else Color(FADED, 0.8 * a)
					Deck.text(ci, sc[0], y, txt, T_ROW, col, "caps", 1, sc[1])
					continue
				txt = ("%d%%" % roundi(100.0 * int(line.get("g", 0)) / shots)) if shots > 0 else "-"
				col = ink if shots > 0 else Color(FADED, 0.8 * a)
			else:
				var v := int(line.get(key, 0))
				txt = str(v)
				col = ink if v != 0 else Color(FADED, 0.8 * a)
				if v != 0 and key in ["ex", "ga"]:
					col = Color(RED, a)
		Deck.text(ci, sc[0], y, txt, T_ROW, col, "caps", 1, sc[1])
	# the game's XP, then the bar
	var xa := clampf((t - SHEET_IN) / (XP_IN - SHEET_IN), 0.0, 1.0) * a
	if xa > 0.0:
		var xp := int(r.xp)
		var xt := ("+%d" % xp) if xp >= 0 else str(xp)
		Deck.text(ci, cols.xp[0], y + roundf((1.0 - xa) * 3.0), xt, T_ROW, Color(AMBER if xp > 0 else FADED, xa), "caps", 2, cols.xp[1])
	_draw_bar(ci, Rect2(Vector2(cols.bar[0], y - 4.0), Vector2(cols.bar[1], 8.0)), r, a)
	_draw_status(ci, r, Vector2(cols.status[0], y), cols.status[1], a)
	if since >= 0.0 and since < SPARK and not bool(Game.settings.get("reduce_motion", false)):
		_sparkles(ci, r, rr, cols, since)

## His XP bar, filled in scribbles: a paper track in an ink outline, scribbled across in dark
## grey pencil. What he had before the game (this level) is a paler, older scribble; what this game
## added is scribbled a shade darker, gone over several times so it fills the bar, each pass
## reaching right to where the bar is now. Every level starts a fresh scribble (an empty bar). A
## flash as it passes a threshold.
const LEAD := Color("4a4f57")        # the dark grey scribble (this game's XP)
const LEAD_DARK := Color("33373e")
const LEAD_LIGHT := Color("60656e")
const LEAD_OLD := Color("9a9ea5")    # ...and the lighter one (what he had before)

func _draw_bar(ci: CanvasItem, r: Rect2, row: Dictionary, a: float) -> void:
	r = Rect2(r.position.floor(), r.size.floor())
	ci.draw_rect(r, Color("f3ecd8", a))
	var st := _bar_state(row)
	var full_still: bool = row.maxed and row.capped
	var fill := r.size.x if full_still else r.size.x * float(st.fill)
	var old := r.size.x if full_still else minf(fill, r.size.x * float(st.old))
	var sd := (row.p as PoloPlayer).id * 31 + int(st.crossed) * 7
	if old > 0.0:
		ci.draw_rect(Rect2(r.position, Vector2(old, r.size.y)), Color(LEAD_OLD, 0.45 * a))
		_scribble(ci, r, 0.0, old, sd, LEAD_OLD, a, 1.0)
		_scribble(ci, r, 0.0, old, sd + 1, LEAD_OLD.lightened(0.15), a, 1.25)
	if fill > old:
		ci.draw_rect(Rect2(r.position + Vector2(floorf(old), 0), Vector2(ceilf(fill - floorf(old)), r.size.y)), Color(LEAD_LIGHT, 0.6 * a))
		# gone over and over: a darker grey pass for the texture, then the dark grey ones on top
		_scribble(ci, r, old, fill, sd + 3, LEAD_DARK, a * 0.85, 1.25)
		_scribble(ci, r, old, fill, sd + 4, LEAD, a, 0.75)
		_scribble(ci, r, old, fill, sd + 5, LEAD, a, 1.0)
		_scribble(ci, r, old, fill, sd + 6, LEAD_LIGHT, a * 0.8, 2.0)
	# ticks every quarter, under the bar
	for q in [0.25, 0.5, 0.75]:
		ci.draw_rect(Rect2(r.position + Vector2(roundf(r.size.x * q), r.size.y + 1.0), Vector2(1, 2)), Color(INK, 0.3 * a))
	ci.draw_rect(r.grow(1.0), Color(INK, 0.85 * a), false, 1.0)
	var since := _since_level(row)
	if since >= 0.0 and since < FLASH:
		var f := 1.0 - since / FLASH
		ci.draw_rect(r, Color(XP_HI, 0.9 * f))
		ci.draw_rect(r.grow(3.0), Color(XP_GOLD, 0.8 * f), false, 2.0)

## One scribble across the bar `r`, from x0 to x1 units in: a quick zig-zag top to bottom
## and back, each stroke a little uneven (where it turns, how far over it goes, how hard it's
## pressed), the same every frame for the same `sd`. Cut off at x1 mid-stroke, so the line ends
## where the pencil is. `step`: how far along each stroke goes (smaller is denser). Returns the
## point it ends at (the pencil's tip), (-1, -1) if nothing was drawn.
static func _scribble(ci: CanvasItem, r: Rect2, x0: float, x1: float, sd: int, col: Color, a: float, step: float) -> Vector2:
	if x1 <= x0 + 0.01:
		return Vector2(-1, -1)
	var h := r.size.y
	# the strokes are laid down from the bar's start, so a part drawn later lines up with the rest
	var x := 0.0
	var i := 0
	var down := true
	var prev := Vector2(0.0, 0.0 if hash([sd, -1]) % 2 == 0 else h - 1.0)
	var tip := Vector2(-1, -1)
	while x < x1 and i < 400:
		var hh := hash([sd, i])
		var adv := maxf(0.5, step + float(hh % 3) * 0.25 - 0.25)
		var nx := x + adv
		var ny := (h - 1.0 - (1.0 if (hh >> 3) % 5 == 0 else 0.0)) if down else (1.0 if (hh >> 5) % 5 == 0 else 0.0)
		var to := Vector2(nx, ny)
		if nx > x0:
			var from := prev
			if x < x0:
				from = prev.lerp(to, (x0 - x) / maxf(0.001, nx - x))
			var end := to
			if nx > x1:
				end = prev.lerp(to, (x1 - x) / maxf(0.001, nx - x))
			var press := 0.6 + 0.4 * float((hh >> 7) % 5) / 4.0
			ci.draw_line((r.position + from).round(), (r.position + end).round(), Color(col, col.a * a * press), 1.0)
			tip = r.position + end
		prev = to
		x = nx
		down = not down
		i += 1
	return tip

## The DEVELOPMENT column: while it fills, only a still bar's word; then what the game came to.
func _draw_status(ci: CanvasItem, r: Dictionary, at: Vector2, w: float, a: float) -> void:
	var n := int(r.levels)
	var ups: Array = r.ups
	# LEVEL UP!: stamped here the moment his bar passes a threshold (x2, x3 for more), and it stays
	var crossed := int(_bar_state(r).crossed)
	if crossed > 0:
		var x := _stamp(ci, r, at, crossed, a)
		if not ups.is_empty() and t >= FILL_END:
			at = Vector2(x + 6.0, at.y)
		else:
			return
	if t < FILL_END:
		if r.capped:
			_status_text(ci, at, w, "MAXED XP" if r.maxed else "UPGRADES WAITING", Color(FADED, a))
		return
	var fa := clampf((t - FILL_END) / 0.25, 0.0, 1.0) * a
	if not ups.is_empty():
		# an attribute that really went up (SHOOTING 6 > 7), the first, then how many more
		var u: Array = ups[0]
		var label := String(Attributes.NAMES.get(u[0], String(u[0]))).to_upper()
		var from := str(floori(float(u[1]) + Attributes.PRECISION))
		var to := str(floori(float(u[2]) + Attributes.PRECISION))
		var x := at.x
		var col := Color(GREEN, fa)
		var tail := ("  +%d" % (ups.size() - 1)) if ups.size() > 1 else ""
		Deck.text(ci, x, at.y, "%s %s" % [label, from], T_SMALL, col)
		x += Deck.text_w("%s %s" % [label, from], T_SMALL) + 3.0
		_arrow(ci, Vector2(x, at.y), col)
		x += 7.0
		Deck.text(ci, x, at.y, to + tail, T_SMALL, col)
		return
	if n > 0:
		return   # (the stamp says it)
	if r.maxed:
		_status_text(ci, at, w, "MAXED XP", Color(BLUE, fa))
	elif r.capped:
		_status_text(ci, at, w, "UPGRADES WAITING", Color(BLUE, fa))
	elif not r.played:
		_status_text(ci, at, w, "DNP", Color(FADED, fa))
	else:
		_status_text(ci, at, w, "%d XP TO NEXT" % int(r.to_next), Color(DIM, fa))

## The red LEVEL UP! stamp, its left middle at `at`: it comes down a touch big and dark as his bar
## passes the threshold, then settles. Returns its right edge.
func _stamp(ci: CanvasItem, r: Dictionary, at: Vector2, crossed: int, a: float) -> float:
	var chip := "LEVEL UP!" if crossed == 1 else "LEVEL UP! x%d" % crossed
	var chip_w := Deck.text_w(chip, T_SMALL) + 8.0
	var since := _since_level(r)
	var land := clampf(since / 0.14, 0.0, 1.0) if since >= 0.0 else 1.0
	var cr := Rect2(floorf(at.x), floorf(at.y - 5.0), chip_w, 11.0)
	var big := cr.grow(roundf((1.0 - land) * 2.0))
	var ink_a := a * lerpf(1.0, 0.85, land)
	ci.draw_rect(big, Color(RED, ink_a), false, 1.0)
	ci.draw_rect(big.grow(-2.0), Color(RED, ink_a * 0.45), false, 1.0)
	Deck.text(ci, cr.position.x + 4.0, cr.get_center().y, chip, T_SMALL, Color(RED, ink_a))
	return cr.end.x

func _status_text(ci: CanvasItem, at: Vector2, w: float, txt: String, col: Color) -> void:
	Deck.text(ci, at.x, at.y, Deck.fit(txt, w, T_SMALL), T_SMALL, col)

## A little right arrow, 5 x 5 units, its left middle at `p`.
static func _arrow(ci: CanvasItem, p: Vector2, col: Color) -> void:
	var o := p.floor()
	ci.draw_rect(Rect2(o + Vector2(0, 0), Vector2(4, 1)), col)
	ci.draw_rect(Rect2(o + Vector2(2, -2), Vector2(1, 1)), col)
	ci.draw_rect(Rect2(o + Vector2(3, -1), Vector2(1, 1)), col)
	ci.draw_rect(Rect2(o + Vector2(3, 1), Vector2(1, 1)), col)
	ci.draw_rect(Rect2(o + Vector2(2, 2), Vector2(1, 1)), col)
	ci.draw_rect(Rect2(o + Vector2(4, 0), Vector2(1, 1)), col)

## A five-point star, `r` units across, centred at `p`.
static func _star(ci: CanvasItem, p: Vector2, r: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 10:
		var ang := -PI / 2.0 + i * PI / 5.0
		var rad := r if i % 2 == 0 else r * 0.45
		pts.append((p + Vector2(cos(ang), sin(ang)) * rad).round())
	ci.draw_colored_polygon(pts, col)

## Gold, orange, red and blue pixel sparkles and little stars rising round his bar and his name,
## worked out from the time since his level-up alone (seeded by who he is and which level),
## gone by SPARK.
func _sparkles(ci: CanvasItem, r: Dictionary, rr: Rect2, cols: Dictionary, since: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([(r.p as PoloPlayer).id, int(_bar_state(r).crossed)])
	var fade := 1.0 - since / SPARK
	var x0: float = cols.name[0]
	var x1: float = cols.bar[0] + cols.bar[1] + 8.0
	var palette := [Color("f0b000"), Color("ff8a00"), PIN_RED, PIN_BLUE]
	for i in 28:
		var bx := rng.randf_range(x0, x1)
		if i % 3 == 0:
			bx = rng.randf_range(cols.bar[0] - 4.0, cols.bar[0] + cols.bar[1] + 4.0)
		var by := rr.get_center().y + rng.randf_range(-4.0, 4.0)
		var vy := rng.randf_range(14.0, 34.0)
		var sway := rng.randf_range(0.0, TAU)
		var delay := rng.randf_range(0.0, 0.15)
		var st := since - delay
		if st < 0.0:
			continue
		var pnt := Vector2(bx + sin(st * 9.0 + sway) * 1.5, by - st * vy).round()
		var col: Color = palette[i % palette.size()]
		if i % 7 == 0:
			_star(ci, pnt, 3.0, Color(col, fade))
		elif i % 5 == 0:
			var rad := 1 if st < 0.2 or st > 0.45 else 2
			ci.draw_rect(Rect2(pnt.x - rad, pnt.y, rad * 2 + 1, 1), Color(col, fade))
			ci.draw_rect(Rect2(pnt.x, pnt.y - rad, 1, rad * 2 + 1), Color(col, fade))
		else:
			ci.draw_rect(Rect2(pnt, Vector2(2, 2) if i % 2 == 0 else Vector2(1, 1)), Color(col, fade))

func _draw_scrollbar(ci: CanvasItem, list: Rect2) -> void:
	var track := Rect2(Vector2(list.end.x - 6.0, list.position.y + 2.0), Vector2(3, list.size.y - 4.0))
	ci.draw_rect(track, Color(INK, 0.08))
	var h := maxf(12.0, track.size.y * list.size.y / _content_h())
	var y := track.position.y + (track.size.y - h) * (scroll / maxf(1.0, _max_scroll()))
	ci.draw_rect(Rect2(Vector2(track.position.x, floorf(y)), Vector2(3, floorf(h))), Color(INK, 0.45))

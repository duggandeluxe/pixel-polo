class_name WalkOnShow
extends Control
## WELCOMING ALL WALK-ONS! (the Automatic Walk-On Recruitment update): the new season's
## announcement whenever open tryouts filled empty places on your roster (WalkOns, Offseason.finish:
## the queue's "walkons" item {n, ids, season}), over the hub, once. In the season transitions'
## look (WeeklyAwardShow's navy and gold, BarHit's lettering):
##   top      OPEN TRYOUTS and the season on a ribbon; WELCOMING ALL WALK-ONS! popping in
##   middle   why they're here (the program held open tryouts), then "N WALK-ON PLAYERS HAVE JOINED
##            YOUR ROSTER!" in gold
##   row      every new walk-on: his portrait in your cap (Portrait: the same face as everywhere),
##            position, class year and stars, rising in one after another
##   bottom   the pool: two of them swimming (PlayerArt, the match's sprite), the water moving,
##            and VIEW NEW WALK-ONS (usable at once; a tap anywhere else finishes the animation)
## Nothing here makes, changes or saves a player: it only shows the ones it's given.

signal finished

const GOLD := Color("ffd83d")
const NAVY := Color("071b3f")
const GREEN := Color("7fe35f")
const WATER := Color("1a5fb4")
const WATER_D := Color("0f3f86")
const FOAM := Color("9ad8ff")
const TITLE := "WELCOMING ALL WALK-ONS!"
const BLURB := "Your team entered the new season with a smaller recruiting class than expected, leaving several roster spots unfilled. To complete your roster, your program held open tryouts and welcomed a group of walk-on athletes ready to represent your school!"
const BUTTON := "VIEW NEW WALK-ONS"
const T_HEAD := 0.08
const T_TEXT := 0.35
const T_COUNT := 0.6
const T_TILES := 0.75
const TILE_STEP := 0.07
const TILE := Vector2(42, 78)
const FACE := Vector2i(38, 43)
const GAP := 3.0

var c: Career
var q := {}
var players: Array = []    # the walk-ons on show (still on your roster), in the order they joined
var team: PoloTeam         # whose caps they wear (yours; a lab's sample team in a preview)
var preview := false       # Developer Tools' WALK-ON TESTING: sample players, nothing read or saved
var t := 0.0
var t_done := 1.2
var motion := true
var blurb: Label
var count_l: Label
var view: Button
var _closed := false
var _stars: StarFx         # the roster card's star bar (bare), drawn for every tile

## The announcement for queue item `item` over `parent`; `done` once VIEW NEW WALK-ONS is pressed.
static func play(parent: Node, car: Career, item: Dictionary, done: Callable = Callable(), with_motion: Variant = null) -> WalkOnShow:
	var w := WalkOnShow.new()
	w.name = "WalkOnShow"
	w.c = car
	w.q = item
	w.motion = Juice.enabled() if with_motion == null else bool(with_motion)
	w.set_anchors_preset(Control.PRESET_FULL_RECT)
	w.mouse_filter = Control.MOUSE_FILTER_STOP
	w.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	w.theme = UI.theme
	w._read()
	if done.is_valid():
		w.finished.connect(done)
	parent.add_child(w)
	w._build()
	return w

## Developer Tools' preview: `list` (sample walk-ons, never on any roster) in `t`'s caps; `done`
## when VIEW NEW WALK-ONS is pressed. Nothing is read from or written to a career.
static func play_preview(parent: Node, list: Array, t: PoloTeam, season: String, done: Callable = Callable()) -> WalkOnShow:
	var w := WalkOnShow.new()
	w.name = "WalkOnShow"
	w.preview = true
	w.team = t
	w.players = list.duplicate()
	w.q = {"n": list.size(), "season": season}
	w.t_done = T_TILES + list.size() * TILE_STEP + 0.3
	w.motion = Juice.enabled()
	w.set_anchors_preset(Control.PRESET_FULL_RECT)
	w.mouse_filter = Control.MOUSE_FILTER_STOP
	w.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	w.theme = UI.theme
	if done.is_valid():
		w.finished.connect(done)
	parent.add_child(w)
	w._build()
	return w

## How many joined (the item's count; the players still here, if it says nothing).
static func count_text(n: int) -> String:
	return ("%d WALK-ON PLAYER HAS JOINED YOUR ROSTER!" if n == 1 else "%d WALK-ON PLAYERS HAVE JOINED YOUR ROSTER!") % n

func _read() -> void:
	if c == null:
		return
	team = c.team()
	for pid in q.get("ids", []):
		var p := c.team().find_id(int(pid))
		if p != null:
			players.append(p)
	t_done = T_TILES + players.size() * TILE_STEP + 0.3

func count() -> int:
	return int(q.get("n", players.size()))

func _build() -> void:
	blurb = UI.label(BLURB, 8, UI.TEXT, "body")
	blurb.name = "Blurb"
	blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	blurb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	blurb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(blurb)
	count_l = UI.label(count_text(count()), 8, GOLD, "caps")
	count_l.name = "Count"
	count_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(count_l)
	view = Deck.button(BUTTON, _view, "primary", 150, 22)
	view.name = "ViewWalkOns"
	add_child(view)
	resized.connect(_place)
	_place()
	t = 0.0 if motion else t_done
	_apply()
	Sfx.play("card")

func _vs() -> Vector2:
	return size if size.x > 0 else get_viewport_rect().size

## The panel: the window less a margin, at most 452 x 254, centred.
func panel() -> Rect2:
	var vs := _vs()
	var sz := Vector2(minf(452.0, vs.x - 16.0), minf(254.0, vs.y - 12.0))
	return Rect2(((vs - sz) * 0.5).floor(), sz)

func _place() -> void:
	var pr := panel()
	var w := minf(400.0, pr.size.x - 32.0)
	blurb.position = Vector2(floorf(pr.get_center().x - w * 0.5), pr.position.y + 50)
	blurb.size = Vector2(w, 40)
	count_l.position = Vector2(pr.position.x, pr.position.y + 96)
	count_l.size = Vector2(pr.size.x, 12)
	view.position = Vector2(floorf(pr.get_center().x - view.size.x * 0.5), pr.end.y - view.size.y - 9)

## Where the row of walk-ons stands (it shrinks to fit a big class).
func _tile_w() -> float:
	var n := maxi(1, players.size())
	return minf(TILE.x, floorf((panel().size.x - 24.0 - (n - 1) * GAP) / n))

func _tile_rect(i: int) -> Rect2:
	var pr := panel()
	var tw := _tile_w()
	var n := players.size()
	var total := n * tw + maxf(0, n - 1) * GAP
	return Rect2(Vector2(floorf(pr.get_center().x - total * 0.5) + i * (tw + GAP), pr.position.y + 114), Vector2(tw, TILE.y))

func _process(dt: float) -> void:
	if _closed:
		return
	t += dt
	_apply()
	queue_redraw()

func _apply() -> void:
	blurb.modulate.a = clampf((t - T_TEXT) / 0.25, 0.0, 1.0)
	count_l.modulate.a = clampf((t - T_COUNT) / 0.2, 0.0, 1.0)
	var glow := (0.5 + 0.5 * sin(t * 5.0)) if motion and t >= t_done else 0.0
	count_l.add_theme_color_override("font_color", GOLD.lerp(Color.WHITE, glow * 0.35))

func _gui_input(ev: InputEvent) -> void:
	if (ev is InputEventMouseButton and ev.pressed) or (ev is InputEventScreenTouch and ev.pressed):
		accept_event()
		t = maxf(t, t_done)   # (a tap: straight to the finished picture)

## VIEW NEW WALK-ONS: closes (once, however many taps) and hands over to the roster.
func _view() -> void:
	if _closed or is_queued_for_deletion():
		return
	_closed = true
	set_process(false)
	queue_free()
	finished.emit()

# ------------------------------------------------------------------ the picture
func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, _vs()), Color(0.01, 0.03, 0.1, 0.82))
	var pr := panel()
	var cx := pr.get_center().x
	draw_rect(Rect2(pr.position + Vector2(3, 3), pr.size), Color(0, 0, 0, 0.45))
	draw_rect(pr, NAVY)
	_pool(pr)
	# the frame: thick gold, a green line inside it (the walk-ons' colour), gold corner studs
	draw_rect(pr, GOLD, false, 3.0)
	draw_rect(pr.grow(-4), Color(GREEN, 0.7), false, 1.0)
	for corner in [pr.position, Vector2(pr.end.x, pr.position.y), Vector2(pr.position.x, pr.end.y), pr.end]:
		var at := (corner as Vector2) - Vector2(4, 4)
		draw_rect(Rect2(at, Vector2(8, 8)), GOLD)
		draw_rect(Rect2(at + Vector2(2, 2), Vector2(4, 4)), NAVY)
	# the ribbon: OPEN TRYOUTS and the season, as an athletics department would put it
	var season := String(q.get("season", c.season_label() if c != null else ""))
	var kick := ("OPEN TRYOUTS  -  %s SEASON" % season) if season != "" else "OPEN TRYOUTS"
	var kw := Deck.text_w(kick, 8, "caps") + 16.0
	var rib := Rect2(Vector2(floorf(cx - kw * 0.5), pr.position.y + 8), Vector2(kw, 11))
	draw_rect(rib, GOLD)
	draw_rect(Rect2(rib.position + Vector2(0, rib.size.y), Vector2(rib.size.x, 1)), BarHit.ORANGE)
	UI.text(self, Vector2(rib.position.x, rib.position.y + 9), kick, 8, NAVY, "caps", HORIZONTAL_ALIGNMENT_CENTER, rib.size.x)
	# the headline, popping in
	if t >= T_HEAD:
		var s := t - T_HEAD
		var sc := BarHit.pop(s) if motion and s < BarHit.OUT_AT else 1.0
		var fs := BarHit.word_fs(TITLE, sc, pr.size.x - 40.0)
		BarHit.lettering(self, Vector2(cx + (BarHit.shake_x(s) if motion else 0.0), pr.position.y + 34), TITLE, fs, 1.0, GOLD, GREEN.darkened(0.25), GREEN.darkened(0.6))
	# a rule under the count
	if t >= T_COUNT:
		var a := clampf((t - T_COUNT) / 0.2, 0.0, 1.0)
		draw_rect(Rect2(cx - 90, pr.position.y + 109, 180, 1), Color(GOLD, 0.5 * a))
	# the row: each walk-on rising in
	for i in players.size():
		var k := clampf((t - T_TILES - i * TILE_STEP) / 0.18, 0.0, 1.0)
		if k <= 0.0:
			continue
		var r := _tile_rect(i)
		r.position.y += roundf((1.0 - _ease(k)) * 10.0)
		_tile(r, players[i], k)

## One walk-on: his portrait in your cap (a keeper's red), his position, class year and stars.
func _tile(r: Rect2, p: PoloPlayer, a: float) -> void:
	var face := Vector2i(mini(FACE.x, int(r.size.x) - 4), FACE.y)
	var box := Rect2(Vector2(floorf(r.get_center().x - face.x * 0.5), r.position.y + 2), Vector2(face))
	draw_rect(r, Color(Deck.NAVY_HEAD, a))
	draw_rect(r, Color(GREEN if not p.is_keeper() else BarHit.RED, a), false, 1.0)
	draw_rect(box, Color("081650", a))
	var col: Array = Portrait.colors_ours(p, team)
	draw_texture_rect(Portrait.texture_zoomed(p, col[0], col[1], face), box, false, Color(1, 1, 1, a))
	UI.text(self, Vector2(r.position.x, box.end.y + 9), "%s %s" % [p.pos_text(), p.year_text()], 8, Color(UI.TEXT, a), "caps", HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
	# his stars exactly as his roster card draws them (Roster.paint_card's `current` bar: StarFx,
	# bare, only the lit part of each star, nothing hollow past it). They land with the tile (the
	# stars draw opaque)
	if a >= 0.6:
		if _stars == null:
			_stars = StarFx.new()
			_stars.bare = true
			_stars.fire = false
			add_child(_stars)
		var sw := Deck.star_bar_w_for(p.stars, p.stars)
		_stars.draw(self, floorf(r.get_center().x - sw * 0.5), box.end.y + 13, p.stars, p.stars, PlayerForm.NORMAL, Color("596170"), Deck.STAR_SHAPE)

## The pool along the panel's foot: the water, its moving ripples and two walk-ons swimming,
## either side of the button.
func _pool(pr: Rect2) -> void:
	var top := pr.end.y - 30.0
	draw_rect(Rect2(pr.position.x, top, pr.size.x, pr.end.y - top), WATER_D)
	draw_rect(Rect2(pr.position.x, top, pr.size.x, 3), WATER)
	_swimmers(pr, top)
	# the water in front of them: they're in the pool, only heads and shoulders above it
	draw_rect(Rect2(pr.position.x, top + 4, pr.size.x, pr.end.y - top - 4), Color(WATER_D, 0.82))
	var drift := (t * 14.0) if motion else 0.0
	var x := pr.position.x + fmod(drift, 12.0) - 12.0
	while x < pr.end.x:
		if x >= pr.position.x and x + 4 <= pr.end.x:
			draw_rect(Rect2(floorf(x), top, 4, 1), Color(FOAM, 0.8))
			draw_rect(Rect2(floorf(x) + 6, top + 9, 3, 1), Color(FOAM, 0.35))
		x += 12.0
	# lane rope: red and white floats along the far edge
	var fx := pr.position.x + 6
	var k := 0
	while fx + 3 <= pr.end.x - 6:
		draw_rect(Rect2(fx, top + 18, 3, 2), Color("e8382c") if k % 4 < 2 else Color("f2f2e9"))
		fx += 4
		k += 1

func _swimmers(pr: Rect2, top: float) -> void:
	if team == null or players.is_empty():
		return
	var swim: Array = players.filter(func(p: PoloPlayer): return not p.is_keeper())
	if swim.is_empty():
		swim = players
	var spots := [pr.position.x + pr.size.x * 0.17, pr.end.x - pr.size.x * 0.17]
	for i in mini(2, swim.size()):
		var bob := roundf(sin(t * 3.0 + i * 2.0)) if motion else 0.0
		var arm := (0.5 + 0.5 * sin(t * 4.0 + i)) if motion else 0.3
		PlayerArt.draw_ours(self, Vector2(roundf(spots[i]), top + 9.0 + bob), swim[i], team, 2.0, arm, t)

static func _ease(x: float) -> float:
	return 1.0 - pow(1.0 - x, 3.0)

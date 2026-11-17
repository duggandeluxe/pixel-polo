class_name WeeklyAwardShow
extends Control
## THE WEEKLY AWARD CELEBRATION (the Weekly Award Celebration update): a player of yours named one
## of his conference's weekly awards (ConfAwards: POTW, OPOTW, DPOTW, ROTW), celebrated over the
## hub, one award at a time, in HEATING UP!'s spirit (BarHit's lettering and pop):
##   top      the award, big and gold ("PLAYER OF THE WEEK!"), the conference it was won in and
##            the week, from the award's own record
##   left     his portrait (Portrait: the same face as everywhere), in a gold frame, sliding in
##   centre   his name, number and position, school, year
##   right    the weekly award's brass plaque (the Trophy Room's own: the same brass, screws and
##            engraving), larger, a shine passing over it, gold sparkles
##   bottom   AWARD-WINNING PERFORMANCE: three or four of the week's stats, from the very line the
##            award was decided on (the record's `line`): only what was recorded, never made up
##   CONTINUE (usable at once: a tap anywhere else finishes the animation)
## Each award's accent: POTW gold, OPOTW orange, DPOTW cyan, ROTW green. Nothing here grants,
## records or changes an award: it only shows the record it's given.
##
## PLAYER OF THE TOURNAMENT (the Postseason Awards update): a TourneyAwards record (it has a
## `tid`) is shown the same way, grander: CONFERENCE TOURNAMENT / NATIONAL CHAMPIONSHIP on a
## ribbon above the award, a sunburst behind it, a double gold frame with gold corner studs (the
## national one heavier still: a gold ribbon, a checker trim, a gold-leaf plaque, more sparkles),
## and the tournament's totals (games first).

signal finished

const TrophyRoom := preload("res://src/ui/screens/trophy_room.gd")
const GOLD := Color("ffd83d")
const NAVY := Color("071b3f")
const ACCENTS := {"potw": Color("ffd83d"), "opotw": Color("ff8a1f"), "dpotw": Color("45dfff"), "rotw": Color("7fe35f")}
const T_HEAD := 0.08
const T_PORTRAIT := 0.3
const T_PLAQUE := 0.5
const T_STATS := 0.75
const T_DONE := 1.3
const PORTRAIT := Vector2i(78, 87)

var recs: Array = []        # the award records to show, in order
var i := 0
var t := 0.0
var c: Career
var motion := true
var cont: Button
var _sound := false

## Plays the records over `parent`; `done` once the last one is closed.
static func play(parent: Node, car: Career, list: Array, done: Callable = Callable(), with_motion: Variant = null) -> WeeklyAwardShow:
	var w := WeeklyAwardShow.new()
	w.c = car
	w.recs = list
	w.motion = Juice.enabled() if with_motion == null else bool(with_motion)
	w.set_anchors_preset(Control.PRESET_FULL_RECT)
	w.mouse_filter = Control.MOUSE_FILTER_STOP
	w.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if done.is_valid():
		w.finished.connect(done)
	parent.add_child(w)
	w._build()
	return w

func _build() -> void:
	cont = Deck.button("CONTINUE  >", _next, "primary", 150, 22)
	cont.name = "Continue"
	add_child(cont)
	resized.connect(_place)
	_place()
	_start()

func _place() -> void:
	var pr := _panel()
	cont.position = Vector2(floorf(pr.get_center().x - cont.size.x * 0.5), pr.end.y - cont.size.y - 6)

func _start() -> void:
	t = 0.0 if motion else T_DONE
	_sound = false
	queue_redraw()

func rec() -> Dictionary:
	return recs[i] if i < recs.size() else {}

func _process(dt: float) -> void:
	if recs.is_empty():
		return
	t += dt
	if not _sound and t >= T_HEAD:
		_sound = true
		Sfx.play("levelup")
	queue_redraw()

func _gui_input(ev: InputEvent) -> void:
	if (ev is InputEventMouseButton and ev.pressed) or (ev is InputEventScreenTouch and ev.pressed):
		accept_event()
		t = maxf(t, T_DONE)   # (a tap: straight to the finished picture)

## CONTINUE: the next award, or done.
func _next() -> void:
	i += 1
	if i >= recs.size():
		set_process(false)
		finished.emit()
		queue_free()
		return
	_start()

func _panel() -> Rect2:
	return Rect2(Vector2(14, 10), size - Vector2(28, 20))

# ------------------------------------------------------------------ the picture
func _draw() -> void:
	var r := rec()
	if r.is_empty():
		return
	var cat := String(r.get("cat", "potw"))
	var tourney := is_tourney(r)
	var nat := is_national(r)
	var acc: Color = ACCENTS.get(cat, GOLD)
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.01, 0.03, 0.1, 0.8))
	var pr := _panel()
	# the panel: navy, a thick gold border, the award's colour inside it (a tournament's: its own frame)
	draw_rect(Rect2(pr.position + Vector2(3, 3), pr.size), Color(0, 0, 0, 0.45))
	draw_rect(pr, NAVY)
	if tourney:
		_tourney_frame(pr, nat)
	else:
		draw_rect(pr, GOLD, false, 3.0)
		draw_rect(pr.grow(-4), Color(acc, 0.7), false, 1.0)
	var cx := pr.get_center().x
	# the award, popping in
	if t >= T_HEAD:
		var s := t - T_HEAD
		var sc := BarHit.pop(s) if s < BarHit.OUT_AT and motion else 1.0
		var titles: Dictionary = TourneyAwards.TITLES if tourney else ConfAwards.TITLES
		var word := String(titles.get(cat, "AWARD")) + "!"
		var fs := BarHit.word_fs(word, sc, pr.size.x - 40.0)
		var shade: Array = [BarHit.ORANGE, BarHit.RED] if cat in ["potw", "opotw", "pot", "opot"] else [acc.darkened(0.3), acc.darkened(0.65)]
		var word_y := pr.position.y + (32 if tourney else 24)
		BarHit.lettering(self, Vector2(cx + (BarHit.shake_x(s) if motion else 0.0), word_y), word, fs, 1.0, GOLD, shade[0], shade[1])
		if tourney:
			# the kicker, on a ribbon: CONFERENCE TOURNAMENT / NATIONAL CHAMPIONSHIP (gold for the national)
			var kick := "NATIONAL CHAMPIONSHIP" if nat else "CONFERENCE TOURNAMENT"
			var kw := Deck.text_w(kick, 8, "caps") + 16.0
			var rib := Rect2(Vector2(floorf(cx - kw * 0.5), pr.position.y + 7), Vector2(kw, 11))
			draw_rect(rib, GOLD if nat else NAVY)
			draw_rect(rib, GOLD, false, 1.0)
			UI.text(self, Vector2(rib.position.x, rib.position.y + 9), kick, 8, NAVY if nat else GOLD, "caps", HORIZONTAL_ALIGNMENT_CENTER, rib.size.x)
		UI.text(self, Vector2(pr.position.x, pr.position.y + (52 if tourney else 46)), subtitle(r),
			8, Color("5cc8ff"), "caps", HORIZONTAL_ALIGNMENT_CENTER, pr.size.x)
	var mid_top := pr.position.y + 56
	var p := ConfAwards.player_of(c, r) if c != null else null
	# the portrait, sliding in from the left
	if t >= T_PORTRAIT:
		var k := _ease(clampf((t - T_PORTRAIT) / 0.25, 0.0, 1.0))
		var box := Rect2(Vector2(pr.position.x + 18 - (1.0 - k) * 40.0, mid_top + 2), Vector2(PORTRAIT))
		box.position = box.position.round()
		draw_rect(box.grow(3), Color(GOLD, k))
		draw_rect(box.grow(1), Color(BarHit.ORANGE, k))
		draw_rect(box, Color("081650"))
		if p != null:
			var t_: PoloTeam = c.teams.get(String(r.get("team", "")), c.team())
			var col: Array = Portrait.colors_ours(p, t_)
			draw_texture_rect(Portrait.texture_zoomed(p, col[0], col[1], PORTRAIT), box, false, Color(1, 1, 1, k))
		# his name and the rest, beside it
		var ix := pr.position.x + 18 + PORTRAIT.x + 14
		var iw := 150.0
		var name := (("%s %s" % [p.first, p.last]) if p != null else String(r.get("name", ""))).to_upper()
		var ns := 16 if Deck.text_w(name, 16, "big") <= iw else 8
		Deck.text(self, ix, mid_top + 20, Deck.fit(name, iw, ns, "big" if ns == 16 else "caps"), ns, Color(UI.TEXT, k), "big" if ns == 16 else "caps")
		var num := int(p.number) if p != null else 0
		var pos := p.pos_long().to_upper() if p != null else ""
		Deck.text(self, ix, mid_top + 38, ("#%d  -  %s" % [num, pos]) if num > 0 else pos, 8, Color(acc, k))
		var school: String = ""
		if c != null and c.teams.has(String(r.get("team", ""))):
			school = Colleges.display_name((c.teams[String(r.team)] as PoloTeam).name).to_upper()
		Deck.text(self, ix, mid_top + 52, Deck.fit(school, iw), 8, Color(UI.TEXT, k))
		var cls: String = ["", "FRESHMAN", "SOPHOMORE", "JUNIOR", "SENIOR"][clampi(int(r.get("cls", p.year if p != null else 1)), 1, 4)]
		Deck.text(self, ix, mid_top + 66, cls, 8, Color(UI.DIM, k))
	# the plaque, the Trophy Room's, larger, a shine over it
	if t >= T_PLAQUE:
		var k2 := clampf((t - T_PLAQUE) / 0.2, 0.0, 1.0)
		var pw := 128.0
		var ph := 56.0
		var plaque := Rect2(Vector2(pr.end.x - 22 - pw, mid_top + 16 + (1.0 - k2) * 8.0), Vector2(pw, ph))
		plaque.position = plaque.position.round()
		_plaque(plaque, r, k2)
		var sh := t - T_PLAQUE - 0.2
		if motion and sh > 0.0 and sh < 0.45:
			var x := plaque.position.x + (sh / 0.45) * (pw + 20) - 10
			draw_colored_polygon(PackedVector2Array([Vector2(x, plaque.position.y), Vector2(x + 8, plaque.position.y),
				Vector2(x + 2, plaque.end.y), Vector2(x - 6, plaque.end.y)]), Color(1, 1, 1, 0.45))
		if t >= T_DONE and motion:
			var n := 12 if nat else (8 if tourney else 6)
			for j in n:
				var a := t * 2.0 + j * TAU / n
				var sp := plaque.get_center() + Vector2(cos(a) * (pw * 0.6), sin(a) * (ph * 0.75))
				if nat and j % 2 == 1:
					sp = plaque.get_center() + Vector2(cos(-a) * (pw * 0.72), sin(-a) * ph)   # (a second ring, turning the other way)
				var tw := 0.5 + 0.5 * sin(t * 6.0 + j)
				_sparkle(sp.round(), Color(GOLD, tw))
	# the week's numbers
	if t >= T_STATS:
		var by := pr.end.y - 72
		UI.text(self, Vector2(pr.position.x, by), "TOURNAMENT TOTALS" if tourney else "AWARD-WINNING PERFORMANCE", 8, GOLD, "caps", HORIZONTAL_ALIGNMENT_CENTER, pr.size.x)
		var st := stats_of(r)
		var bw := 74.0
		var gap := 8.0
		var total := st.size() * bw + maxf(0, st.size() - 1) * gap
		for j in st.size():
			var kj := clampf((t - T_STATS - j * 0.08) / 0.15, 0.0, 1.0)
			if kj <= 0.0:
				continue
			var b := Rect2(Vector2(floorf(cx - total * 0.5 + j * (bw + gap)), by + 6), Vector2(bw, 30))
			draw_rect(b, Color(Deck.NAVY_HEAD, kj))
			draw_rect(b, Color(acc, kj), false, 1.0)
			UI.text(self, Vector2(b.position.x, b.position.y + 15), String(st[j][0]), 16, Color(GOLD, kj), "big", HORIZONTAL_ALIGNMENT_CENTER, b.size.x)
			UI.text(self, Vector2(b.position.x, b.position.y + 26), String(st[j][1]), 8, Color(UI.DIM, kj), "caps", HORIZONTAL_ALIGNMENT_CENTER, b.size.x)

## The weekly plaque, as the Trophy Room hangs it (its brass, bevel, screws and engraving), at `r`.
func _plaque(r: Rect2, rc: Dictionary, a: float) -> void:
	var nat := is_national(rc)
	var dark: Color = Color("a8740c") if nat else TrophyRoom.BRASS_D   # (the national's: gold leaf)
	var mid: Color = GOLD if nat else TrophyRoom.BRASS
	var light: Color = Color("fff3a8") if nat else TrophyRoom.BRASS_L
	draw_rect(Rect2(r.position + Vector2(2, 2), r.size), Color(0, 0, 0, 0.4 * a))
	draw_rect(r, Color(dark, a))
	draw_rect(r.grow(-1), Color(mid, a))
	draw_rect(Rect2(r.position + Vector2(1, 1), Vector2(r.size.x - 2, 1)), Color(light, a))
	draw_rect(Rect2(r.position + Vector2(1, r.size.y - 2), Vector2(r.size.x - 2, 1)), Color(dark, a))
	for sx in [r.position.x + 6, r.end.x - 7]:
		draw_rect(Rect2(sx - 2, r.get_center().y - 2, 4, 4), Color("9aa0aa", a))
		draw_rect(Rect2(sx - 2, r.get_center().y - 1, 4, 1), Color("50545c", a))
	var yr := NationalAwards.earned_year(String(rc.get("season", "")))
	var what := String(rc.get("label", ""))
	var short := "%s %s" % [Colleges.conf_abbr(String(rc.get("conf", ""))), String(ConfAwards.SHORT.get(String(rc.get("cat", "")), ""))]
	if is_tourney(rc):
		var tid := String(rc.tid)
		what = "NCSA" if tid == "nat" else Colleges.conf_abbr(String(rc.get("conf", "")))
		short = String(TourneyAwards.SHORT.get(String(rc.get("cat", "")), ""))
	var top := ("%d %s" % [yr, what]) if yr > 0 else what
	UI.text(self, Vector2(r.position.x, r.position.y + 21), top.to_upper(), 16, Color(TrophyRoom.INK, a), "big", HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
	UI.text(self, Vector2(r.position.x, r.position.y + 42), short, 16, Color(TrophyRoom.INK, a), "big", HORIZONTAL_ALIGNMENT_CENTER, r.size.x)

func _sparkle(p: Vector2, col: Color) -> void:
	draw_rect(Rect2(p + Vector2(-1, 0), Vector2(3, 1)), col)
	draw_rect(Rect2(p + Vector2(0, -1), Vector2(1, 3)), col)

static func _ease(x: float) -> float:
	return 1.0 - pow(1.0 - x, 3.0)

## The week's numbers for the boxes, from the award's own line (only what it recorded): a keeper's
## saves, save rate and goals against; a field player's goals and assists, then the award's own
## kind (shots for the offensive award, steals and blocks otherwise). Three or four [value, label].
static func stats_of(r: Dictionary) -> Array:
	var ln: Dictionary = r.get("line", {})
	var out: Array = []
	var add := func(k: String, label: String) -> void:
		if ln.has(k):
			out.append([str(int(ln[k])), label])
	if is_tourney(r):
		# a tournament's totals: the games first, then what he did in them
		add.call("gp", "GAMES")
		if int(r.get("pos", -1)) == PoloPlayer.Pos.GK:
			add.call("sv", "SAVES")
			var faced := int(ln.get("sv", 0)) + int(ln.get("ga", 0))
			if faced > 0:
				out.append(["%d%%" % roundi(100.0 * int(ln.get("sv", 0)) / faced), "SAVE RATE"])
			add.call("ga", "GOALS ALLOWED")
		else:
			add.call("g", "GOALS")
			add.call("a", "ASSISTS")
			add.call("st", "STEALS")
			add.call("bl", "BLOCKS")
		return out.slice(0, 4)
	if int(r.get("pos", -1)) == PoloPlayer.Pos.GK:
		add.call("sv", "SAVES")
		if ln.has("sv") and ln.has("ga") and int(ln.sv) + int(ln.ga) > 0:
			out.append(["%d%%" % roundi(100.0 * int(ln.sv) / (int(ln.sv) + int(ln.ga))), "SAVE RATE"])
		add.call("ga", "GOALS ALLOWED")
		add.call("st", "STEALS")
	else:
		add.call("g", "GOALS")
		add.call("a", "ASSISTS")
		if String(r.get("cat", "")) == "opotw":
			add.call("sh", "SHOTS")
			add.call("ed", "EXCL DRAWN")
		else:
			add.call("st", "STEALS")
			add.call("bl", "BLOCKS")
	if out.size() < 3:
		add.call("gp", "GAMES")
	return out.slice(0, 4)

## A tournament's award (TourneyAwards' record: it names its tournament), not a week's.
static func is_tourney(r: Dictionary) -> bool:
	return r.has("tid")

## A national championship's (the NCSA's).
static func is_national(r: Dictionary) -> bool:
	return String(r.get("tid", "")) == "nat"

## The line under the award: the conference and the week, or the tournament and its year.
static func subtitle(r: Dictionary) -> String:
	if is_tourney(r):
		var tid := String(r.tid)
		var yr := NationalAwards.earned_year(String(r.get("season", "")))
		var name := "NCSA CHAMPIONSHIP"
		if tid != "nat":
			name = "%s TOURNAMENT" % Colleges.conf_abbr(String(r.get("conf", "")))
		return ("%s  -  %d" % [name, yr]) if yr > 0 else name
	var conf: String = String(Colleges.conference(String(r.get("conf", ""))).get("name", String(r.get("conf", ""))))
	return "%s  -  %s" % [conf.to_upper(), String(r.get("label", "")).to_upper()]

## A tournament's frame: a sunburst turning slowly behind everything, a double gold border, gold
## corner studs; the national's heavier (a 4px border with an orange line inside it, a gold checker
## trim top and bottom, brighter rays).
func _tourney_frame(pr: Rect2, nat: bool) -> void:
	var c0 := Vector2(pr.get_center().x, pr.position.y + 32)
	var spin := t * 0.15 if motion else 0.0
	var box := PackedVector2Array([pr.position, Vector2(pr.end.x, pr.position.y), pr.end, Vector2(pr.position.x, pr.end.y)])
	var reach := pr.size.length()
	var rays := 16
	for j in rays:
		var a0 := spin + j * TAU / rays
		var a1 := a0 + TAU / rays * 0.5
		var tri := PackedVector2Array([c0, c0 + Vector2(cos(a0), sin(a0)) * reach, c0 + Vector2(cos(a1), sin(a1)) * reach])
		for poly in Geometry2D.intersect_polygons(tri, box):
			draw_colored_polygon(poly, Color(GOLD, 0.09 if nat else 0.05))
	var w := 4.0 if nat else 3.0
	draw_rect(pr, GOLD, false, w)
	draw_rect(pr.grow(-w - 1), BarHit.ORANGE if nat else Color(GOLD, 0.8), false, 1.0)
	draw_rect(pr.grow(-w - 3), Color(GOLD, 0.5), false, 1.0)
	if nat:
		var x := pr.position.x + w + 5
		var k := 0
		while x + 4 <= pr.end.x - w - 5:
			if k % 2 == 0:
				draw_rect(Rect2(x, pr.end.y - w - 9, 4, 4), Color(GOLD, 0.55))
			x += 4
			k += 1
	for corner in [pr.position, Vector2(pr.end.x, pr.position.y), Vector2(pr.position.x, pr.end.y), pr.end]:
		var q := (corner as Vector2) - Vector2(4, 4)
		draw_rect(Rect2(q, Vector2(8, 8)), GOLD)
		draw_rect(Rect2(q + Vector2(2, 2), Vector2(4, 4)), BarHit.ORANGE if nat else NAVY)

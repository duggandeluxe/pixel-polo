class_name ChallengeShow
extends Control
## THE COACHING CHALLENGE RESULT (the Coaching Challenge Results Animation update): a statistical
## challenge you set in a COACHING EVENT (CoachEvents), settled by the game just played, shown
## one at a time, in HEATING UP!'s and the Weekly Award Celebration's spirit:
##   top      CHALLENGE COMPLETE! (gold, green accents) / CHALLENGE FAILED (muted red, a small
##            red flash and shake) / LEGENDARY CHALLENGE COMPLETE! (a rare 3X made: bigger,
##            more sparkles, a shine); the coaching event's name under it
##   left     his portrait (Portrait: the same face as everywhere), green or red framed
##   right    his name, number and position; the GOAL; what he did (ACTUAL, with its parts for a
##            combined stat); a bar filling to it (full at the target, never past); and, for a
##            challenge with a result too (THE LEARNING EXPERIENCE, a LEGENDARY LEADER), each
##            condition ticked or crossed
##   bottom   REWARD EARNED / PENALTY APPLIED / SPECIAL CHALLENGE COMPLETE!: exactly what was
##            applied (the result's `applied`: fixed XP, the multiplier he got, or none), and a
##            HOT STAR gain or loss when there was one
##   CONTINUE (usable at once: a tap anywhere else finishes the animation)
## It only REPORTS: everything comes from the settled result (Career.coach_results), written once
## by CoachEvents.award_game from his real line. Nothing here grants, takes or decides anything.

signal finished
signal dismissed(r: Dictionary)   # (each one, as it's closed: the caller marks it shown)

const GOLD := Color("ffd83d")
const GREEN := Color("5ee36a")
const RED := Color("e0564f")
const NAVY := Color("071b3f")
const CYAN := Color("5cc8ff")
const T_HEAD := 0.05
const T_PORTRAIT := 0.25
const T_GOAL := 0.42
const T_BAR := 0.58
const BAR_TIME := 0.45
const T_REWARD := 1.1
const T_DONE := 1.45
const PORTRAIT := Vector2i(78, 87)
const UNITS := {"g": ["GOALS", "GOALS"], "ga": ["GOALS + ASSISTS", "G+A"], "sv": ["SAVES", "SAVES"], "stbl": ["STEALS + BLOCKS", "STL+BLK"]}

var recs: Array = []
var i := 0
var t := 0.0
var c: Career
var motion := true
var tag := ""          # a mark across the top (Developer Mode's preview)
var cont: Button
var _sound := false

## Plays the settled results over `parent`; `done` once the last one is closed.
static func play(parent: Node, car: Career, list: Array, done: Callable = Callable(), with_motion: Variant = null, mark: String = "") -> ChallengeShow:
	var w := ChallengeShow.new()
	w.c = car
	w.recs = list
	w.tag = mark
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
	t = 0.0 if motion else done_at()
	_sound = false
	queue_redraw()

func rec() -> Dictionary:
	return recs[i] if i < recs.size() else {}

## The three looks: "legend" (a SPECIAL CHALLENGE made), "ok", "fail" (missed, or a LEGENDARY
## LEADER's win without his target: no bonus).
static func look(r: Dictionary) -> String:
	if String(r.get("outcome", "")) == "ok":
		return "legend" if bool(r.get("special", false)) else "ok"
	return "fail"

static func title_of(r: Dictionary) -> String:
	match look(r):
		"legend": return "LEGENDARY CHALLENGE COMPLETE!"
		"ok": return "CHALLENGE COMPLETE!"
	return "CHALLENGE FAILED"

## When the picture is finished (a made special one pauses a moment longer).
func done_at() -> float:
	return T_DONE + (0.25 if look(rec()) == "legend" else 0.0)

func _process(dt: float) -> void:
	if recs.is_empty():
		return
	t += dt
	if not _sound and t >= T_HEAD:
		_sound = true
		Sfx.play("levelup" if look(rec()) != "fail" else "error")
	queue_redraw()

func _gui_input(ev: InputEvent) -> void:
	if (ev is InputEventMouseButton and ev.pressed) or (ev is InputEventScreenTouch and ev.pressed):
		accept_event()
		t = maxf(t, done_at())   # (a tap: straight to the finished picture)

## CONTINUE: the next result, or done.
func _next() -> void:
	dismissed.emit(rec())
	i += 1
	if i >= recs.size():
		set_process(false)
		finished.emit()
		queue_free()
		return
	_start()

func _panel() -> Rect2:
	return Rect2(Vector2(14, 8), size - Vector2(28, 16))

# ------------------------------------------------------------------ the words (static: tested)
## The objective: "5 GOALS", "8 SAVES", "3 GOALS + ASSISTS".
static func goal_text(r: Dictionary) -> String:
	return "%d %s" % [int(r.get("n", 0)), String(UNITS.get(String(r.get("stat", "")), ["", ""])[0])]

## His number against it: "4 / 3 G+A".
static func progress_text(r: Dictionary) -> String:
	return "%d / %d %s" % [int(r.get("have", 0)), int(r.get("n", 0)), String(UNITS.get(String(r.get("stat", "")), ["", ""])[1])]

## A combined stat's parts, from his line: "2 GOALS + 2 ASSISTS", "2 STEALS + 1 BLOCK" ("" otherwise).
static func parts_text(r: Dictionary) -> String:
	var ln: Dictionary = r.get("line", {})
	var one := func(n: int, w: String) -> String: return "%d %s%s" % [n, w, "" if n == 1 else "S"]
	match String(r.get("stat", "")):
		"ga": return "%s + %s" % [one.call(int(ln.get("g", 0)), "GOAL"), one.call(int(ln.get("a", 0)), "ASSIST")]
		"stbl": return "%s + %s" % [one.call(int(ln.get("st", 0)), "STEAL"), one.call(int(ln.get("bl", 0)), "BLOCK")]
	return ""

## How full the bar is: his number over the target, never past full.
static func fill(r: Dictionary) -> float:
	return clampf(float(r.get("have", 0)) / maxf(1.0, float(r.get("n", 1))), 0.0, 1.0)

## Each condition and whether it was met: [[text, met], ...] (a result too: the team's first).
static func conditions(r: Dictionary) -> Array:
	var out: Array = []
	if r.has("cond"):
		var lose := String(r.cond) == "lose"
		out.append(["THE TEAM %s" % ("LOSES" if lose else "WINS"), bool(r.get("won", false)) != lose])
	out.append([goal_text(r), int(r.get("have", 0)) >= int(r.get("n", 0))])
	return out

## The consequence as applied: [heading, the big line, the small one].
static func consequence(r: Dictionary) -> Array:
	var ap: Dictionary = r.get("applied", {})
	var head := "PENALTY APPLIED"
	match look(r):
		"legend": head = "SPECIAL CHALLENGE COMPLETE!"
		"ok": head = "REWARD EARNED"
	var big := "NORMAL GAME XP"
	var small := ""
	match String(ap.get("kind", "none")):
		"xp":
			big = ("+%d XP" % int(ap.xp)) if int(ap.xp) > 0 else "NO XP: FULLY DEVELOPED"
		"mult":
			big = "%s GAME XP" % CoachEvents.mx(float(ap.mult))
			small = "%d -> %d XP" % [int(ap.base), int(ap.xp)]
			if not is_equal_approx(float(ap.mult), float(ap.get("intended", ap.mult))):
				small += "  (%s APPLIED INSTEAD: ONE A GAME)" % CoachEvents.mx(float(ap.mult))
	if look(r) == "fail" and String(ap.get("kind", "none")) == "none":
		head = "NO BONUS"
	for ln in r.get("lines", []):
		if String(ln[0]).contains("HOT STAR PROGRESS") and String(ln[1]) in ["bad", "good"]:
			small = (small + "   " if small != "" else "") + String(ln[0]).to_upper()
	return [head, big, small]

# ------------------------------------------------------------------ the picture
func _draw() -> void:
	var r := rec()
	if r.is_empty():
		return
	var lk := look(r)
	var acc: Color = GOLD if lk != "fail" else RED
	var edge: Color = GREEN if lk != "fail" else RED
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.01, 0.03, 0.1, 0.8))
	var pr := _panel()
	# a failure: a small red flash, the panel nudged
	if lk == "fail" and motion and t < 0.3:
		pr.position.x += roundf(sin(t * 70.0) * 3.0 * (1.0 - t / 0.3))
		draw_rect(Rect2(Vector2.ZERO, size), Color(RED, 0.18 * (1.0 - t / 0.3)))
	draw_rect(Rect2(pr.position + Vector2(3, 3), pr.size), Color(0, 0, 0, 0.45))
	draw_rect(pr, NAVY if lk != "fail" else Color("12122e"))
	draw_rect(pr, acc, false, 4.0 if lk == "legend" else 3.0)
	draw_rect(pr.grow(-4), Color(edge, 0.6), false, 1.0)
	var cx := pr.get_center().x
	if tag != "":
		UI.text(self, Vector2(pr.position.x + 8, pr.position.y + 10), tag, 8, CYAN, "caps")
	# the verdict, popping in; the event's name under it
	if t >= T_HEAD:
		var s := t - T_HEAD
		var pop := BarHit.pop(s) * (1.12 if lk == "legend" else 1.0) if s < BarHit.OUT_AT and motion else 1.0
		var word := title_of(r)
		var fs := BarHit.word_fs(word, pop, pr.size.x - 40.0)
		if lk == "fail":
			fs = mini(fs, 24)
			BarHit.lettering(self, Vector2(cx, pr.position.y + 24), word, fs, 1.0, Color("ff8a80"), RED.darkened(0.3), RED.darkened(0.65))
		else:
			BarHit.lettering(self, Vector2(cx + (BarHit.shake_x(s) if motion and lk == "legend" else 0.0), pr.position.y + 24), word, fs, 1.0, GOLD, BarHit.ORANGE, BarHit.RED)
		var sub := String(r.get("title", "")) + ("  -  SPECIAL CHALLENGE" if bool(r.get("special", false)) else "")
		UI.text(self, Vector2(pr.position.x, pr.position.y + 49), sub, 8, CYAN, "caps", HORIZONTAL_ALIGNMENT_CENTER, pr.size.x)
	var top := pr.position.y + 56
	var p := c.team().find_id(int(r.get("pid", -1))) if c != null else null
	# the portrait, sliding in from the left
	if t >= T_PORTRAIT:
		var k := _ease(clampf((t - T_PORTRAIT) / 0.22, 0.0, 1.0))
		var box := Rect2(Vector2(pr.position.x + 22 - (1.0 - k) * 40.0, top + 2), Vector2(PORTRAIT))
		box.position = box.position.round()
		draw_rect(box.grow(3), Color(edge, k))
		draw_rect(box.grow(1), Color(NAVY, k))
		draw_rect(box, Color("081650"))
		if p != null:
			var col: Array = Portrait.colors_ours(p, c.team())
			draw_texture_rect(Portrait.texture_zoomed(p, col[0], col[1], PORTRAIT), box, false, Color(1, 1, 1, k))
		var ix := pr.position.x + 22 + PORTRAIT.x + 14
		var iw := pr.end.x - 22 - ix
		var name := (("%s %s" % [p.first, p.last]) if p != null else "").to_upper()
		var ns := 16 if Deck.text_w(name, 16, "big") <= iw else 8
		Deck.text(self, ix, top + 10, Deck.fit(name, iw, ns, "big" if ns == 16 else "caps"), ns, Color(UI.TEXT, k), "big" if ns == 16 else "caps")
		if p != null:
			Deck.text(self, ix, top + 24, "#%d  -  %s" % [p.number, Deck.pos_tag(p)], 8, Color(CYAN, k))
		# the goal, then what he did, a bar filling to it
		if t >= T_GOAL:
			var kg := clampf((t - T_GOAL) / 0.12, 0.0, 1.0)
			Deck.text(self, ix, top + 38, "GOAL: " + goal_text(r), 8, Color(UI.TEXT, kg))
			var parts := parts_text(r)
			Deck.text(self, ix, top + 50, "ACTUAL: %d %s%s" % [int(r.get("have", 0)), String(UNITS.get(String(r.get("stat", "")), ["", ""])[0]),
				("  (%s)" % parts) if parts != "" else ""], 8, Color(UI.ACCENT, kg))
		if t >= T_BAR:
			var kb := clampf((t - T_BAR) / BAR_TIME, 0.0, 1.0) if motion else 1.0
			var bar := Rect2(Vector2(ix, top + 58), Vector2(minf(150.0, iw - 70.0), 8))
			draw_rect(bar.grow(1), UI.BORDER)
			draw_rect(bar, Color("0b1d5c"))
			var f := fill(r) * _ease(kb)
			var met := int(r.get("have", 0)) >= int(r.get("n", 0))
			draw_rect(Rect2(bar.position, Vector2(floorf(bar.size.x * f), bar.size.y)), GREEN if met else RED)
			draw_rect(Rect2(bar.position, Vector2(floorf(bar.size.x * f), 2)), Color(1, 1, 1, 0.3))
			Deck.text(self, bar.end.x + 6, top + 63, progress_text(r), 8, GREEN if met else Color("ff8a80"))
			# a challenge with a result too: each condition
			var conds := conditions(r)
			if conds.size() > 1 and kb >= 1.0:
				var x := ix
				for cd in conds:
					var txt := "%s %s" % ["+" if cd[1] else "x", String(cd[0])]
					Deck.text(self, x, top + 80, txt, 8, GREEN if cd[1] else Color("ff8a80"))
					x += Deck.text_w(txt) + 12
	# the consequence, exactly as applied
	if t >= T_REWARD:
		var kr := clampf((t - T_REWARD) / 0.15, 0.0, 1.0)
		var cq := consequence(r)
		var by := top + PORTRAIT.y + 10
		var box := Rect2(Vector2(pr.position.x + 60, by), Vector2(pr.size.x - 120, 44))
		draw_rect(box, Color(Deck.NAVY_HEAD, kr))
		draw_rect(box, Color(acc, kr), false, 1.0)
		UI.text(self, Vector2(box.position.x, box.position.y + 10), String(cq[0]), 8, Color(acc if lk != "fail" else Color("ff8a80"), kr), "caps", HORIZONTAL_ALIGNMENT_CENTER, box.size.x)
		var sc := 1.0 + (0.25 * (1.0 - kr) if motion else 0.0)
		UI.text(self, Vector2(box.position.x, box.position.y + 26), String(cq[1]), roundi(16 * sc) if sc > 1.01 else 16, Color(GOLD if lk != "fail" else Color("ff8a80"), kr), "big", HORIZONTAL_ALIGNMENT_CENTER, box.size.x)
		if String(cq[2]) != "":
			UI.text(self, Vector2(box.position.x, box.position.y + 38), String(cq[2]), 8, Color(UI.DIM, kr), "caps", HORIZONTAL_ALIGNMENT_CENTER, box.size.x)
	# sparkles for a success (more for a legend), a shine across the verdict
	if lk != "fail" and t >= done_at() - 0.2 and motion:
		var n := 10 if lk == "legend" else 5
		for j in n:
			var a := t * 1.6 + j * TAU / n
			var sp := Vector2(cx + cos(a) * pr.size.x * 0.42, pr.position.y + 26 + sin(a) * 14.0)
			_sparkle(sp.round(), Color(GOLD, 0.5 + 0.5 * sin(t * 6.0 + j)))
	if lk == "legend" and motion:
		var sh := t - T_HEAD - 0.3
		if sh > 0.0 and sh < 0.5:
			var x := pr.position.x + 20 + (sh / 0.5) * (pr.size.x - 40)
			draw_colored_polygon(PackedVector2Array([Vector2(x, pr.position.y + 10), Vector2(x + 10, pr.position.y + 10),
				Vector2(x + 2, pr.position.y + 36), Vector2(x - 8, pr.position.y + 36)]), Color(1, 1, 1, 0.35))

func _sparkle(p: Vector2, col: Color) -> void:
	draw_rect(Rect2(p + Vector2(-1, 0), Vector2(3, 1)), col)
	draw_rect(Rect2(p + Vector2(0, -1), Vector2(1, 3)), col)

static func _ease(x: float) -> float:
	return 1.0 - pow(1.0 - x, 3.0)

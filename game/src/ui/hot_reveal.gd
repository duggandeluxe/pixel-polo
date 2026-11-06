class_name HotReveal
extends Control
## The postgame HOT star reveal: after the final score, each of your players whose HEAT went up
## in that game gets his own roster card (Roster.paint_card, twice size, whole pixels), one at a
## time. Nobody heated up: nothing plays (heaters() is empty and the summary goes straight on).
##   in      the card slides in from the right to the middle. 0.3 s
##   heat    the next star heats up on his own bar (StarFx's heat: a warm glow, a yellow and
##           orange flash, the red pop and a pixel sparkle), HEATING UP! (a first red star) or
##           ON FIRE! (a second) pops in under the card as it turns red. 0.9 s
##   pulse   the new red star's rim blinks, then it settles: longer for a second red star, with
##           more sparkles round it. 0.35 s / 0.6 s
##   hold    the finished card, then it slides out to the left. 0.6 s (0.3 s with 3+), 0.2 s
## About 2.4 s for one player. Two levels in one game (the form system moves heat a level a game,
## so it can't today) would play both stars on the same card, one after the other.
## Every frame is worked out from `t` alone, so a test can set it. A tap skips the rest (skip()).
## Only drawing: it reads the form rows the game already made (PlayerForm.grade_team) and never
## grades, saves or changes a player. With reduce motion each card just shows, finished, STILL s.

signal finished

const Roster := preload("res://src/ui/screens/roster.gd")

const SCALE := 2.0            # the card, twice a roster card, still whole pixels
const LEAD := 0.15            # the result panel starts shrinking first
const SLIDE_IN := 0.3
const SLIDE_OUT := 0.2
const IGNITE := 0.31          # into StarFx's heat, the star turns red: the word comes in
const PULSE := {PlayerForm.HOT: 0.35, PlayerForm.VERY_HOT: 0.6}
const HOLD := 0.6
const HOLD_MANY := 0.3        # ... with MANY or more players, so the whole run stays short
const MANY := 3
const STILL := 1.2            # reduce motion: each finished card, this long
const WORDS := {PlayerForm.HOT: "HEATING UP!", PlayerForm.VERY_HOT: "ON FIRE!"}
const YELLOW := Color("ffd83d")
const NAVY := Color("071b3f")
const TOP := 44.0             # under the summary's strip

var items: Array = []         # [{p, from, to}] (heaters())
var team: PoloTeam            # whose caps the players wear
var plan: Array = []          # plan_of(items)
var t := 0.0
var top := TOP                # the space above PLAYER FORM
var motion := true
var running := false
var card: Control
var fx: StarFx
var _cued := {}

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	card = UI.canvas(int(Roster.CARD.x), int(Roster.CARD.y), _draw_card)
	card.size = Roster.CARD
	card.scale = Vector2(SCALE, SCALE)
	card.visible = false
	add_child(card)
	fx = StarFx.new()
	card.add_child(fx)

# ------------------------------------------------------------------ who, and when
## The players whose HEAT went up in the game these rows grade (PlayerForm.grade_team: "before"
## and "after" are his form either side of it), keeper first as the rows are: [{p, from, to}].
## The same or cooler (HOT stays HOT, VERY HOT drops to HOT, HOT to NORMAL) isn't shown.
static func heaters(rows: Array) -> Array:
	var out: Array = []
	for r in rows:
		var from := String(r.get("before", PlayerForm.NORMAL))
		var to := String(r.get("after", PlayerForm.NORMAL))
		if PlayerForm.level_of(to) > PlayerForm.level_of(from):
			out.append({"p": r.p, "from": from, "to": to})
	return out

## The red stars to heat, one level at a time: NORMAL to VERY HOT is two.
static func steps_of(from: String, to: String) -> Array:
	var out: Array = []
	for lv in range(PlayerForm.level_of(from), PlayerForm.level_of(to)):
		out.append([PlayerForm.state_of(lv), PlayerForm.state_of(lv + 1)])
	return out

static func word_for(state: String) -> String:
	return String(WORDS.get(state, ""))

## When everything happens: one entry an item, {start, steps: [{at, from, to}], out, end}, in
## seconds from the start. `at` is when that star starts heating, `out` when the card leaves.
static func plan_of(list: Array, with_motion: bool) -> Array:
	var out: Array = []
	var at := LEAD if with_motion else 0.0
	var hold := HOLD_MANY if list.size() >= MANY else HOLD
	for it in list:
		var e := {"start": at, "steps": []}
		var s: float = at + (SLIDE_IN if with_motion else 0.0)
		for st in steps_of(it.from, it.to):
			(e.steps as Array).append({"at": s, "from": st[0], "to": st[1]})
			if with_motion:
				s += StarFx.HEAT_TIME + float(PULSE[st[1]])
		e.out = s + (hold if with_motion else STILL)
		e.end = float(e.out) + (SLIDE_OUT if with_motion else 0.0)
		at = e.end
		out.append(e)
	return out

static func total_of(p: Array) -> float:
	return float(p.back().end) if not p.is_empty() else 0.0

## What shows at `time`: {i (the item, -1 none), slide (0 in the middle, 1 off to the right,
## -1 off to the left), step (its star heating now or last, -1 before the first), since (s into
## that step)}.
static func frame_at(p: Array, time: float) -> Dictionary:
	for i in p.size():
		var e: Dictionary = p[i]
		if time < float(e.start) or time >= float(e.end):
			continue
		var slide := 0.0
		var in_end: float = e.start + SLIDE_IN
		var steps: Array = e.steps
		if not steps.is_empty():
			in_end = minf(in_end, float(steps[0].at))
		if time < in_end:
			slide = 1.0 - _ease((time - float(e.start)) / maxf(0.001, in_end - float(e.start)))
		elif time >= float(e.out):
			slide = -_ease_in((time - float(e.out)) / maxf(0.001, float(e.end) - float(e.out)))
		var step := -1
		for j in steps.size():
			if time >= float(steps[j].at):
				step = j
		return {"i": i, "slide": slide, "step": step, "since": time - float(steps[step].at) if step >= 0 else -1.0}
	return {"i": -1, "slide": 0.0, "step": -1, "since": -1.0}

static func _ease(x: float) -> float:
	var u := clampf(x, 0.0, 1.0)
	return 1.0 - (1.0 - u) * (1.0 - u) * (1.0 - u)

static func _ease_in(x: float) -> float:
	var u := clampf(x, 0.0, 1.0)
	return u * u

# ------------------------------------------------------------------ playing
## Starts the reveal for `list` (heaters()); wearing `team_`'s caps. Returns false (and plays
## nothing) when the list is empty.
## `with_motion` null: as Settings say (Juice.enabled); true in the Developer Mode preview.
func start(list: Array, team_: PoloTeam, with_motion: Variant = null) -> bool:
	items = list
	team = team_
	motion = Juice.enabled() if with_motion == null else bool(with_motion)
	plan = plan_of(items, motion)
	t = 0.0
	_cued.clear()
	running = not items.is_empty()
	layout()
	return running

func total() -> float:
	return total_of(plan)

## A tap: the rest is skipped.
func skip() -> void:
	if running:
		_finish()

func _finish() -> void:
	running = false
	if card != null:
		card.visible = false
	queue_redraw()
	finished.emit()

func _process(delta: float) -> void:
	if not running:
		return
	t += delta
	_cues()
	if t >= total():
		_finish()
		return
	layout()

## The sounds, each once: a card coming in, a star turning red.
func _cues() -> void:
	if not motion:
		return
	for i in plan.size():
		var e: Dictionary = plan[i]
		if t >= float(e.start) and not _cued.has("in%d" % i):
			_cued["in%d" % i] = true
			Sfx.play("card")
		for j in (e.steps as Array).size():
			var st: Dictionary = e.steps[j]
			var key := "hot%d_%d" % [i, j]
			if t >= float(st.at) + IGNITE and not _cued.has(key):
				_cued[key] = true
				Sfx.play("record" if st.to == PlayerForm.VERY_HOT else "levelup")

# ------------------------------------------------------------------ drawing
## Where the card's top left goes, by how far it has slid.
func card_pos(slide: float) -> Vector2:
	var w := Roster.CARD.x * SCALE
	var x := (size.x - w) / 2.0 + slide * ((size.x + w) / 2.0 + 8.0)
	var room := size.y - top - 40.0
	return Vector2(roundf(x), roundf(top + maxf(10.0, (room - Roster.CARD.y * SCALE) / 2.0)))

## Puts the card where `t` has it and redraws (every frame while it runs; a test that sets `t`
## calls it itself).
func layout() -> void:
	if card == null:
		return
	var f := frame_at(plan, t)
	card.visible = running and int(f.i) >= 0
	if card.visible:
		card.position = card_pos(float(f.slide))
	card.queue_redraw()
	queue_redraw()

func _draw() -> void:
	var f := frame_at(plan, t)
	if not running or int(f.i) < 0:
		return
	var it: Dictionary = items[f.i]
	var p: PoloPlayer = it.p
	var at := card_pos(float(f.slide))
	var cw := Roster.CARD.x * SCALE
	var cx := at.x + cw / 2.0
	# a navy panel behind it all, as the summary's (it slides with the card)
	var panel := Rect2(at.x - 24.0, at.y - 18.0, cw + 48.0, Roster.CARD.y * SCALE + 58.0)
	draw_rect(panel, Color(NAVY, 0.9))
	draw_rect(panel, UI.BORDER, false, 1.0)
	# over the card: PLAYER FORM, and which of how many
	var head := "PLAYER FORM" if items.size() == 1 else "PLAYER FORM  %d / %d" % [int(f.i) + 1, items.size()]
	UI.text_shadow(self, Vector2(roundf(cx - 100.0), at.y - 6.0), head, 8, YELLOW, "caps", HORIZONTAL_ALIGNMENT_CENTER, 200.0)
	# under it: the word, once his star has turned red (straight away with reduce motion)
	var steps: Array = plan[f.i].steps
	var wy := at.y + Roster.CARD.y * SCALE + 22.0
	var st := -1
	var since := 99.0
	if not motion:
		st = steps.size() - 1
	elif int(f.step) >= 0:
		st = int(f.step)
		since = float(f.since) - IGNITE
		if since < 0.0:
			st -= 1
			since = 99.0
	if st >= 0:
		_draw_word(cx, wy, String(steps[st].to), since)
	var line := "%s %s   %s STARS" % [p.first.to_upper(), p.last.to_upper(), PlayerForm.star_text(p.stars)]
	UI.text(self, Vector2(roundf(cx - 150.0), wy + 13.0), Deck.fit(line, 296.0), 8, UI.DIM, "caps", HORIZONTAL_ALIGNMENT_CENTER, 300.0)
	if items.size() > 1 or motion:
		var blink := 0.6 + 0.4 * sin(t * 5.0) if motion else 1.0
		UI.text_shadow(self, Vector2(0, size.y - 4.0), "TAP TO SKIP", 8, Color(UI.TEXT, blink), "caps", HORIZONTAL_ALIGNMENT_CENTER, size.x)

## HEATING UP! (yellow) or ON FIRE! (red and bigger, flickering yellow as it lands), popping a
## size up as it comes in. `since`: seconds since the star turned red.
func _draw_word(cx: float, y: float, state: String, since: float) -> void:
	var fire := state == PlayerForm.VERY_HOT
	var size_ := 24 if fire else 16
	var col := PlayerForm.FIRE_RED if fire else YELLOW
	if since < 0.12:
		size_ += 8 if fire else 4
	if fire and since < 0.36 and int(since / 0.06) % 2 == 1:
		col = YELLOW
	UI.text_shadow(self, Vector2(roundf(cx - 150.0), roundf(y)), word_for(state), size_, col, "big", HORIZONTAL_ALIGNMENT_CENTER, 300.0,
		Color(NAVY, 0.9))

## The card itself (its own Control at SCALE): his roster card with the star heating as it goes,
## then the pulse and the sparkles round the new red star.
func _draw_card(ci: Control) -> void:
	var f := frame_at(plan, t)
	if not running or int(f.i) < 0:
		return
	var it: Dictionary = items[f.i]
	var p: PoloPlayer = it.p
	var steps: Array = plan[f.i].steps
	var state := String(it.to)
	if steps.is_empty():
		fx.pose(state, state, 0.0)
	elif not motion:
		state = fx.pose(it.from, it.to, 999.0)
	else:
		var j := maxi(0, int(f.step))
		var st: Dictionary = steps[j]
		state = fx.pose(st.from, st.to, float(f.since) if int(f.step) >= 0 else -1.0)
	Roster.paint_card(ci, p, team, fx, state, YELLOW)
	if motion and int(f.step) >= 0:
		var st: Dictionary = steps[f.step]
		_draw_pulse(ci, p, String(st.to), float(f.since))

## After the heat: the new red star's rim blinks (PULSE), and sparkles go off round it as it
## turns red: two small ones for a first red star, four bigger ones and a second ring for ON FIRE.
func _draw_pulse(ci: CanvasItem, p: PoloPlayer, to: String, since: float) -> void:
	var place := StarFx.form_place(p.stars, p.pot_stars, to)
	if place < 0:
		return   # (no form showing)
	var shape: Dictionary = Deck.STAR_SHAPE
	var at := Vector2(Roster.STAR_X + Deck.star_x(place, shape), Roster.STAR_Y).floor()
	var fire := to == PlayerForm.VERY_HOT
	var pt := since - StarFx.HEAT_TIME
	if pt >= 0.0 and pt < float(PULSE[to]):
		if int(pt / 0.1) % 2 == 0:
			var col := StarFx.RIM_FLASH if fire and int(pt / 0.2) % 2 == 0 else StarFx.RIM_POP
			for px in StarFx.rim(shape.star):
				ci.draw_rect(Rect2(at + Vector2(px), Vector2.ONE), col)
	var mid := at + Vector2(int(shape.w) >> 1, 3)
	var spots := [Vector2(-6, -4), Vector2(6, 4)]
	if fire:
		spots = [Vector2(-6, -4), Vector2(6, -4), Vector2(-6, 5), Vector2(6, 5)]
	for i in spots.size():
		var st := since - (IGNITE + i * 0.05)
		if st >= 0.0 and st < 0.24:
			_sparkle(ci, mid + spots[i], StarFx.SPARK if i % 2 == 0 else StarFx.EMBER_Y, 1 if st < 0.08 or st > 0.16 else 2)
		if fire:
			var st2 := since - (IGNITE + 0.3 + i * 0.05)
			if st2 >= 0.0 and st2 < 0.16:
				_sparkle(ci, mid + spots[i] * 1.7, StarFx.EMBER_Y if i % 2 == 0 else StarFx.WARM, 1)

## A little plus-shaped pixel sparkle, `r` px from its centre (as the summary's).
static func _sparkle(ci: CanvasItem, p: Vector2, col: Color, r: int) -> void:
	p = p.floor()
	ci.draw_rect(Rect2(p.x - r, p.y, r * 2 + 1, 1), col)
	ci.draw_rect(Rect2(p.x, p.y - r, 1, r * 2 + 1), col)

class_name VictoryShow
extends RefCounted
## THE VICTORY PRESENTATION: your win, before the full-time panel. Four different scenes, not one
## graphic four sizes. Presentation only: the result is already final, nothing here reaches the
## standings, awards, tournament or Trophy Room. A tap skips it. Only ever for your win.
##   Level 1 CLASSIC VICTORY     the graphic on the water: your seven, the team, the final score
##   Level 2 FIREWORKS VICTORY   the same graphic under a real fireworks show, ribbons in your colours
##   Level 3 TEAM HUDDLE         the pool deck by your bench: they gather, huddle, break it up with
##                               their arms in the air under the fireworks (VictoryScene)
##   Level 4 TROPHY CELEBRATION  the team in robes, the trophy raised together, confetti and fireworks
## How big the moment is follows the game: VICTORY!, BIG WIN!, CONFERENCE CHAMPIONS!, NATIONAL
## CHAMPIONS!. A title brings the TROPHY CEREMONY at Levels 1-3 (free: it's never paid for). Level 4
## is its own ceremony: the real trophy for a real title, and for an ordinary win a plain
## celebration cup, which is decoration, not an honour: it never reaches the Trophy Room.

const LENGTH := [2.2, 3.0, 5.2, 6.0]
const CEREMONY := 2.4          # the trophy, after the celebration
const GATHER_R := 4.0          # m: how close your seven are round the middle (Levels 1-2)
const CREW := [8, 10]          # men in the Level 3 / Level 4 scene, the whole bench if there's room
## Level 3's beats (s): they walk in, they huddle, they break it up.
const HUDDLE_AT := 1.3
const BREAK_AT := 2.7
## Level 4's: on stage, then the trophy goes up.
const LIFT_AT := 1.0
const LIFTED := 2.0
const SKIP_TEXT := "TAP TO SKIP  >>"

var level := 1
var calm := false
var team: PoloTeam
var title := ""                # "", "conf" or "nat"
var big := false
var score: Array = []          # [yours, theirs]: the final score on the graphic ([]: none)
var pool: PoolDef
var crowd := 0.6
var style := {}
var paint_body: Callable
var t := 0.0
var done := false
var skipped := false
var _men: Array[Swimmer] = []
var _crew: Array[PoloPlayer] = []   # Levels 3-4: who's on the deck
var _rv := PoolView.new()
var _fx := GoalFx.new()

func _init(p_team: PoloTeam, lv: int = 1, p_title: String = "", p_big: bool = false, p_calm: bool = false) -> void:
	team = p_team
	level = clampi(lv, 1, VisualUpgrades.MAX_LEVEL)
	title = p_title
	big = p_big
	calm = p_calm
	_fx.level = level
	_fx.calm = calm
	_fx.c1 = team.c1
	_fx.c2 = team.c2
	var seven := team.starters()
	if level >= 3:
		var most: int = CREW[level - 3]
		for p: PoloPlayer in seven + team.roster:
			if _crew.size() < most and not _crew.has(p):
				_crew.append(p)
		return
	for i in seven.size():
		var sw := Swimmer.new(seven[i], Swimmer.Side.US)
		var a := TAU * i / maxf(1.0, seven.size())
		sw.pos = Vector2(Geo.HALF + cos(a) * GATHER_R * 1.6, Geo.GOAL_Y + sin(a) * GATHER_R)
		sw.facing = 1.0 if cos(a) < 0.0 else -1.0
		sw.cheer = 1.0
		_men.append(sw)

func celebration() -> float:
	return float(LENGTH[level - 1]) * (1.25 if title != "" and level < 3 else 1.0)

## Level 4 raises its own trophy: no ceremony after it.
func has_ceremony() -> bool:
	return title != "" and level < 4

func length() -> float:
	return celebration() + (CEREMONY if has_ceremony() else 0.0)

func ceremony() -> bool:
	return has_ceremony() and t >= celebration()

func headline() -> String:
	match title:
		"nat":
			return "NATIONAL CHAMPIONS!"
		"conf":
			return "CONFERENCE CHAMPIONS!"
	return "BIG WIN!" if big else "VICTORY!"

## The trophy in the scene: the real one for a real title, or the plain celebration cup (never a
## championship: TrophyArt's "celebration" is in no honours list).
func trophy() -> Texture2D:
	if title == "":
		return TrophyArt.texture("celebration", false)
	var cat := {"nat": "ncsa_champ", "d2": "d2_champ", "d3": "d3_champ"}.get(title, "conf_champ") as String
	return TrophyArt.texture(cat, title == "nat")

## What this level and game draw, for the tests and the lab.
func parts() -> Dictionary:
	var moment := 2 if title == "nat" else (1 if title != "" else 0)
	return {"scene": ["classic", "fireworks", "huddle", "trophy"][level - 1],
		"confetti": 0 if level < 4 and title == "" else [40, 40, 60, 160][level - 1] * (1 + moment),
		"fireworks": 0 if level < 2 else [0, 8, 6, 7][level - 1] + moment * 3,
		"robes": level == 4, "bench": level >= 3, "players": _crew.size() if level >= 3 else _men.size(),
		"trophy": title != "" or level == 4, "title": title != ""}

func skip() -> void:
	if not done:
		skipped = true
		done = true

func step(dt: float) -> void:
	if done:
		return
	var was := t
	t += dt
	for s in _men:
		s.anim += dt * 2.0
		s.hop = 0.0 if calm else absf(sin(t * 7.0 + s.pos.x)) * 4.0
	if was < 0.05 and t >= 0.05:
		Sfx.play("cheer", 1.0, -2.0)
	if level >= 3:
		var beat := BREAK_AT if level == 3 else LIFTED
		if was < beat and t >= beat:
			Sfx.play("cheer", 1.1, -1.0)
	if has_ceremony() and was < celebration() and t >= celebration():
		Sfx.play("record", 1.0, -3.0)
	if t >= length():
		done = true

func draw(ci: CanvasItem, size: Vector2) -> void:
	if ceremony():
		_water(ci, size) if level < 3 else VictoryScene.stage(ci, size, team, t, calm)
		_ceremony(ci, size)
	elif level >= 4:
		_trophy_scene(ci, size)
	elif level == 3:
		_huddle_scene(ci, size)
	else:
		_water(ci, size)
		_graphic(ci, size)
	var sw := Deck.text_w(SKIP_TEXT) + 10
	ci.draw_rect(Rect2(size.x - sw - 4, size.y - 15, sw, 12), Color(UI.INK, 0.7))
	Deck.text(ci, size.x - sw + 1, size.y - 9, SKIP_TEXT, 8, UI.TEXT)

## Levels 1-2's water, your seven on it.
func _water(ci: CanvasItem, size: Vector2) -> void:
	_rv.width = size.x
	_rv.height = size.y
	_rv.zoom = 1.0
	_rv.zoom_to = 1.0
	_rv.cam = _rv._want(Vector2(Geo.HALF, Geo.GOAL_Y))
	PoolArt.draw_pool(ci, _rv, t, size, 1.0 if not calm else 0.0, pool, crowd, {}, style)
	var all: Array[Swimmer] = _men.duplicate()
	all.sort_custom(func(a: Swimmer, b: Swimmer): return a.pos.y < b.pos.y)
	for s in all:
		if paint_body.is_valid():
			paint_body.call(ci, _rv, s)
		else:
			PoolArt.draw_body(ci, _rv, s, Color.WHITE, team.c1)

## The victory graphic: the words, the team, the final score. Level 2 lights it up.
func _graphic(ci: CanvasItem, size: Vector2) -> void:
	var p := parts()
	if int(p.fireworks) > 0:
		# the lights go down, so the show can be seen against the pool
		ci.draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.04, 0.14, 0.55 * clampf(t / 0.3, 0.0, 1.0)))
		_fireworks(ci, size, int(p.fireworks))
		_ribbons(ci, size)
	if int(p.confetti) > 0:
		_fx.confetti(ci, size, fposmod(t + GoalShow.IMPACT_AT, 3.0), int(p.confetti) / (2 if calm else 1), 1.0)
	_words(ci, size, 58.0, 28 if title == "" else 18, clampf(t / 0.2, 0.0, 1.0))

func _words(ci: CanvasItem, size: Vector2, y: float, fs: int, u: float) -> void:
	BarHit.lettering(ci, Vector2(roundf(size.x * 0.5), y), headline(), fs, u)
	Deck.ctext(ci, Rect2(0, y + 22, size.x, 10), Colleges.display_name(team.name).to_upper(), 8, Color.WHITE)
	if score.size() == 2:
		var text := "FINAL  %d - %d" % [int(score[0]), int(score[1])]
		var w := Deck.text_w(text) + 12
		ci.draw_rect(Rect2(roundf((size.x - w) * 0.5), y + 33, w, 12), Color(UI.INK, 0.75))
		Deck.ctext(ci, Rect2(0, y + 35, size.x, 10), text, 8, UI.GOLD)

## Bursts over and over (Reduce Motion: one still frame of them).
func _fireworks(ci: CanvasItem, size: Vector2, n: int) -> void:
	var clock := 0.75 if calm else fposmod(t, 1.8)
	_fx.fireworks(ci, size, clock + GoalShow.IMPACT_AT, n)

## Your colours streaming out from either side of the words.
func _ribbons(ci: CanvasItem, size: Vector2) -> void:
	var gap := 96.0
	var run := (size.x * 0.5 - gap) * (1.0 if calm else minf(1.0, t / 0.5))
	for i in 3:
		var col: Color = [team.c1, team.c2, team.c1][i]
		var y := 48.0 + i * 3.0
		ci.draw_rect(Rect2(size.x * 0.5 - gap - run, y, run, 2), col)
		ci.draw_rect(Rect2(size.x * 0.5 + gap, y, run, 2), col)

## LEVEL 3: they come in along the deck, huddle up by the bench, and break it with their arms in
## the air. Back row first, so the front row stands in front of them.
func _huddle_scene(ci: CanvasItem, size: Vector2) -> void:
	VictoryScene.stage(ci, size, team, t, calm)
	var into := 1.0 if calm else clampf(t / HUDDLE_AT, 0.0, 1.0)
	var broke := calm or t >= BREAK_AT
	if broke:
		_fireworks(ci, size, int(parts().fireworks))
	var n := _crew.size()
	var mid := size.x * 0.5
	var back := size.y - 62.0
	var front := size.y - 20.0
	for row in 2:   # 0 the back row, 1 the front
		for i in n:
			if i % 2 != row:
				continue
			var row_i := i / 2
			var row_n := (n + 1 - row) / 2
			var step := 62.0 if row == 1 else 72.0
			var tight := mid + (row_i - (row_n - 1) * 0.5) * step
			var wide := size.x * (0.08 + 0.84 * float(i) / maxf(1.0, n - 1.0))
			var x := lerpf(wide, tight, into)
			var foot := front if row == 1 else back
			var arms := "down"
			var hop := 0.0
			if not calm:
				if t < HUDDLE_AT:
					hop = absf(sin(t * 9.0 + i)) * 4.0     # they run in
				elif not broke:
					hop = absf(sin(t * 6.0)) * 5.0         # the whole huddle bouncing as one
				else:
					hop = absf(sin(t * 8.0 + i * 1.3)) * 10.0
			if broke:
				arms = "up"
			elif into >= 1.0:
				arms = "out"
			VictoryScene.man(ci, x, foot - hop, _crew[i], team, arms, false, 0.0 if calm else sin(t * 7.0 + i) * 2.0)
	if broke:
		_words(ci, size, 22.0, 24 if title == "" else 16, 1.0 if calm else clampf((t - BREAK_AT) / 0.25, 0.0, 1.0))

## LEVEL 4: the team in robes in two rows, the trophy in the middle, and the men round it lifting
## it up together while everybody else has an arm in the air.
func _trophy_scene(ci: CanvasItem, size: Vector2) -> void:
	VictoryScene.stage(ci, size, team, t, calm)
	var up := 1.0 if calm else clampf((t - LIFT_AT) / (LIFTED - LIFT_AT), 0.0, 1.0)
	var lifted := up >= 1.0
	var p := parts()
	if lifted:
		_fireworks(ci, size, int(p.fireworks))
	var n := _crew.size()
	var mid := size.x * 0.5
	var back := size.y - 70.0
	var front := size.y - 20.0
	var enter := 1.0 if calm else clampf(t / 0.7, 0.0, 1.0)
	# the back row, the outside of the group
	var rows: Array = [[], []]
	for i in n:
		rows[0 if i >= 5 else 1].append(i)
	for i: int in rows[0]:
		var k: int = rows[0].find(i)
		var x: float = mid + (k - (rows[0].size() - 1) * 0.5) * 84.0
		var hop := 0.0 if calm or not lifted else absf(sin(t * 7.0 + i)) * 5.0
		VictoryScene.man(ci, x, back - hop + (1.0 - enter) * 60.0, _crew[i], team, "up" if lifted else "down", true, 0.0 if calm else sin(t * 6.0 + i) * 2.0)
	# the trophy goes up from the middle of the front row, on their hands
	var tex := trophy()
	var k := 2
	var dim := Vector2(tex.get_width(), tex.get_height()) * k
	var hand_y := front - (VictoryScene.BODY_H + 26.0) * VictoryScene.SCALE
	var top := roundf(lerpf(hand_y + 8.0, hand_y - dim.y + 10.0, up))
	ci.draw_texture_rect(tex, Rect2(Vector2(roundf(mid - dim.x * 0.5), top), dim), false)
	for i: int in rows[1]:
		var q: int = rows[1].find(i)
		var off: float = q - (rows[1].size() - 1) * 0.5
		var x: float = mid + off * 72.0
		var lift_man := absf(off) <= 1.0   # the three in the middle have it
		var hop := 0.0 if calm or not lifted or lift_man else absf(sin(t * 7.0 + i)) * 4.0
		var arms := "hold" if lift_man else ("up" if lifted else "down")
		VictoryScene.man(ci, x, front - hop + (1.0 - enter) * 60.0, _crew[i], team, arms, true, 0.0 if calm or lift_man else sin(t * 6.0 + i) * 2.0)
	if lifted:
		_fx.confetti(ci, size, fposmod(t - LIFTED + GoalShow.IMPACT_AT + 0.3, 3.0), int(p.confetti) / (2 if calm else 1), 1.0)
		_words(ci, size, 16.0, 20 if title == "" else 16, 1.0 if calm else clampf((t - LIFTED) / 0.25, 0.0, 1.0))

## The trophy, raised: a title at Levels 1-3. Light behind it; a title's words.
func _ceremony(ci: CanvasItem, size: Vector2) -> void:
	var u := clampf((t - celebration()) / 0.4, 0.0, 1.0)
	var c := Vector2(roundf(size.x * 0.5), roundf(size.y * 0.5))
	ci.draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.04, 0.12, 0.55 * u))
	var rays := 8 + level * 2
	for i in rays:
		var a := TAU * i / rays + (0.0 if calm else t * 0.3)
		var far := c + Vector2(cos(a), sin(a)) * size.x
		var far2 := c + Vector2(cos(a + 0.12), sin(a + 0.12)) * size.x
		ci.draw_colored_polygon(PackedVector2Array([c, far, far2]), Color(team.c1.lightened(0.3), 0.14 * u))
	var tex := trophy()
	var k := 3
	var dim := Vector2(tex.get_width(), tex.get_height()) * k
	var top := roundf(lerpf(size.y, c.y - dim.y * 0.5 - 8.0, u))
	ci.draw_texture_rect(tex, Rect2(Vector2(c.x - dim.x * 0.5, top), dim), false)
	BarHit.lettering(ci, Vector2(c.x, 30.0), headline(), 16 + level * 2, u)
	Deck.ctext(ci, Rect2(0, size.y - 30, size.x, 10), Colleges.display_name(team.name).to_upper(), 8, Color.WHITE)

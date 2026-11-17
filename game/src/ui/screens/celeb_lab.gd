extends "res://src/ui/screens/play_lab.gd"
## Developer Mode's GOAL CELEBRATION PREVIEW (Settings > Developer Mode): every goal celebration on
## demand, owned or not, through the match's own GoalShow and GoalFx.
##   CLASSIC / CONFETTI / WATER / FIREWORKS   the celebration to preview
##   PREVIEW            plays it at the goal, no goal scored (the show and the celebration alone)
##   REAL GOAL          a real possession, scored: the celebration as a match triggers it
##   GOAL: RIGHT / LEFT / RIGHT (DEFENDING)   which goal, and the view mirrored as when you defend
##   SPEED: 1X / 0.25X  slow motion, for the timing    MARKERS  the emitters (back posts, mouth)
##   MOTION             Reduce Motion's version        TEMP EQUIP  wear it in matches for testing
## Nothing is bought, owned, equipped or saved: TEMP EQUIP is GoalFx.dev_equip, in memory only.

const NAMES := ["CLASSIC", "CONFETTI", "WATER", "FIREWORKS"]
const ENDS := ["RIGHT", "LEFT", "RIGHT (DEFENDING)"]

var sel := VisualUpgrades.CONFETTI
var end_i := 0
var slow := false
var markers := false
var calm := false
var fired_at := ""             # the last preview, for the status line
var pick_btns: Array[Button] = []
var end_btn: Button
var speed_btn: Button
var mark_btn: Button
var motion_btn: Button
var equip_btn: Button

func _ready() -> void:
	lab_ready("GOAL CELEBRATION PREVIEW")
	var r1 := _row()
	for n in 4:
		var l: int = n
		var b := _btn(NAMES[n], func():
			sel = l
			_labels(), 78, "Celeb%d" % n)
		pick_btns.append(b)
		r1.add_child(b)
	var r2 := _row()
	r2.add_child(_btn("PREVIEW", preview, 74, "Preview", "primary"))
	r2.add_child(_btn("REAL GOAL", real_goal, 74, "RealGoal"))
	end_btn = _btn("", func():
		end_i = (end_i + 1) % ENDS.size()
		_idle()
		_labels(), 132, "GoalEnd", "ghost")
	r2.add_child(end_btn)
	speed_btn = _btn("", func():
		slow = not slow
		_labels(), 84, "Speed", "ghost")
	r2.add_child(speed_btn)
	var r3 := _row()
	mark_btn = _btn("", func():
		markers = not markers
		_labels(), 92, "Markers", "ghost")
	r3.add_child(mark_btn)
	motion_btn = _btn("", func():
		calm = not calm
		_labels(), 84, "Motion", "ghost")
	r3.add_child(motion_btn)
	equip_btn = _btn("", toggle_equip, 170, "TempEquip")
	r3.add_child(equip_btn)
	_labels()
	_idle.call_deferred()

func _row() -> HBoxContainer:
	var r := UI.hbox(3)
	r.alignment = BoxContainer.ALIGNMENT_CENTER
	body.add_child(r)
	return r

func _btn(text: String, cb: Callable, w: int, n: String, style := "normal") -> Button:
	var b := UI.button(text, cb, style, w, 18)
	b.name = n
	b.clip_text = true
	return b

func _labels() -> void:
	for n in pick_btns.size():
		UI.style_button(pick_btns[n], "primary" if n == sel else "normal")
	end_btn.text = "GOAL: %s" % ENDS[end_i]
	speed_btn.text = "SPEED: %s" % ("0.25X" if slow else "1X")
	mark_btn.text = "MARKERS: %s" % ("ON" if markers else "OFF")
	motion_btn.text = "MOTION: %s" % ("CALM" if calm else "FULL")
	equip_btn.text = "TEMP EQUIP: %s" % (NAMES[GoalFx.dev_equip] if GoalFx.dev_equip >= 0 else "OFF (REAL)")

## Which goal (pool metres: 0 or GOAL_X), and whether the view is mirrored (defending).
func goal_x() -> float:
	return 0.0 if end_i == 1 else Geo.GOAL_X

func _idle() -> void:
	new_play()
	paused = true
	view.mirror = end_i == 2
	view.snap_to(Vector2(goal_x(), Geo.GOAL_Y))

func settled() -> void:
	_idle()

## The celebration at the goal picked, no goal scored: the show and the celebration alone, the
## pool standing still under them.
func preview() -> void:
	_idle()
	var at := Vector2(goal_x(), Geo.GOAL_Y - 0.6)
	goal_show.start(0, null, scratch, Colleges.short_name(us).to_upper(), US_CAP, at)
	goal_show.cast(null, [], null)
	goal_fx.start(sel, goal_show, us.c1, us.c2, fire_still())
	end_t = goal_show.total()
	goals_shown += 1
	fired_at = ENDS[end_i]

## A real goal, as a match scores one (always into the attacking goal: RIGHT, or mirrored).
func real_goal() -> void:
	if end_i == 1:
		end_i = 0
	new_play()
	view.mirror = end_i == 2
	var s: Swimmer = play.attackers[0]
	for a in play.attackers:
		if a.pos.x > s.pos.x:
			s = a
	play.give_ball(s)
	paused = false
	play.dev_goal(Geo.GOAL_Y - 0.6, 0.55)
	fired_at = "REAL GOAL, " + ENDS[end_i]
	_labels()

func toggle_equip() -> void:
	GoalFx.dev_equip = -1 if GoalFx.dev_equip == sel else sel
	_labels()

func lab_goal_level() -> int:
	return sel

func fire_still() -> bool:
	return calm or HotFire.calm()

func focus() -> Vector2:
	return Vector2(goal_x(), Geo.GOAL_Y) if paused else view.attack_frame(play)

func _process(dt: float) -> void:
	super(dt * (0.25 if slow else 1.0))

func lab_tick(_dt: float) -> void:
	if paused:
		view.snap_to(focus())   # (the stage's size settles after the first frames)
	var what := String(VisualUpgrades.cat("goal").tiers[sel][0])
	if goal_fx.active():
		status = "LEVEL %d %s  %s  T+%.2fs" % [sel, what, fired_at, goal_fx.age()]
	elif goal_show.active():
		status = "LEVEL 0 CLASSIC  %s  T+%.2fs" % [fired_at, goal_show.t]
	else:
		status = "LEVEL %d %s: PREVIEW IT, NOTHING BOUGHT OR SAVED" % [sel, what]

## MARKERS: where the emitters are (the back posts' tops, the goalmouth) at the goal picked.
func lab_draw(ci: Control) -> void:
	if not markers:
		return
	var at := goal_show.mouth if goal_show.active() else Vector2(goal_x(), Geo.GOAL_Y)
	var g := GoalFx.points(view, at)
	for k in ["far", "near", "mouth"]:
		var p: Vector2 = g[k]
		var col := Color("ff3df2") if k != "mouth" else Color("3dff7a")
		ci.draw_rect(Rect2(p.x - 4, p.y, 9, 1), col)
		ci.draw_rect(Rect2(p.x, p.y - 4, 1, 9), col)
	ci.draw_rect(Rect2((g.far as Vector2).x - 30, float(g.water), 60, 1), Color(1, 1, 0, 0.7))   # the waterline

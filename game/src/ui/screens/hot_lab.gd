extends BaseScreen
## Developer Mode's HOT STAR REVEAL preview (Settings > Developer Mode): the postgame reveal
## (HotReveal, the real roster cards and StarFx) played on demand, with no game to finish first.
## Each test makes one game's form rows, the shape PlayerForm.grade_team makes them, and puts
## them through HotReveal.heaters exactly as the summary does, so the players who show are the
## ones the real check picks:
##   FIRST HOT STAR   NORMAL to HOT among six who didn't heat up: HEATING UP!
##   SECOND HOT STAR  HOT to VERY HOT: ON FIRE!
##   TWO PLAYERS      one of each, one after the other
##   NO HOT STARS     nobody heated up (same form, or cooler): the reveal is skipped
##   NORMAL > V.HOT   both stars on one card, one after the other (form can't do it in a game yet)
## REPLAY plays the last test again; a tap on the cards skips, as after a game. The players are
## made here (CollegeGen) and wear your caps if a career is loaded; no career, form or save is
## ever touched. Motion plays even with Settings > Reduce motion on.

const TESTS := [["FIRST HOT STAR", "first"], ["SECOND HOT STAR", "second"], ["TWO PLAYERS", "two"],
	["NO HOT STARS", "none"], ["NORMAL > V.HOT", "double"]]
const N := PlayerForm.NORMAL
const H := PlayerForm.HOT
const V := PlayerForm.VERY_HOT

var stage_cv: Control
var reveal: HotReveal
var team: PoloTeam
var seven: Array = []
var last := ""
var status := "PICK A TEST"

func _ready() -> void:
	build("HOT STAR REVEAL")
	team = Game.career.team() if Game.career != null else League.make_team(0)
	seven = sample_players()
	stage_cv = UI.canvas(0, 0, _draw_stage)
	stage_cv.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stage_cv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stage_cv.mouse_filter = Control.MOUSE_FILTER_STOP
	stage_cv.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			reveal.skip())
	body.add_child(stage_cv)
	reveal = HotReveal.new()
	reveal.top = 12.0
	reveal.finished.connect(func():
		status = "DONE  (REPLAY to see it again)"
		stage_cv.queue_redraw())
	stage_cv.add_child(reveal)
	var row := UI.hbox(3)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	body.add_child(row)
	for tst in TESTS:
		var key: String = tst[1]
		row.add_child(UI.button(tst[0], func(): play(key), "normal", 84, 18))
	var row2 := UI.hbox(3)
	row2.alignment = BoxContainer.ALIGNMENT_CENTER
	body.add_child(row2)
	row2.add_child(UI.button("REPLAY", func():
		if last == "":
			Game.toast("Pick a test first", UI.DIM)
			return
		play(last), "ghost", 70, 18))

func on_back() -> void:
	Sfx.play("back")
	Game.back("settings")

## Seven made-up players (a keeper and six), three stars or so so there's room on the bar for two
## red ones. Always the same seven.
static func sample_players() -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2024
	var used := {}
	var out: Array = []
	var shape := [[PoloPlayer.Pos.GK, 3.0, 3], [PoloPlayer.Pos.DRIVER, 3.0, 2], [PoloPlayer.Pos.CENTER, 3.5, 4],
		[PoloPlayer.Pos.UTILITY, 2.5, 1], [PoloPlayer.Pos.DEFENDER, 3.0, 3], [PoloPlayer.Pos.DRIVER, 3.5, 2],
		[PoloPlayer.Pos.WING, 2.5, 1]]
	for i in shape.size():
		var p := CollegeGen.make_starter(rng, shape[i][0], shape[i][1], shape[i][2], used)
		p.id = 90001 + i
		p.number = i + 1
		out.append(p)
	return out

## One game's form rows for a test, {p, before, after} like PlayerForm.grade_team's. The rest of
## the seven move every way that must NOT show: the same, cooler, or staying HOT / VERY HOT.
func rows_for(test: String) -> Array:
	var quiet := [[N, N], [H, H], [V, V], [V, H], [H, N], [N, N], [H, H]]
	var moves := {}
	match test:
		"first":
			moves = {1: [N, H]}
		"second":
			moves = {2: [H, V]}
		"two":
			moves = {1: [N, H], 5: [H, V]}
		"double":
			moves = {3: [N, V]}
	var out: Array = []
	for i in seven.size():
		var m: Array = moves.get(i, quiet[i])
		out.append({"p": seven[i], "before": m[0], "after": m[1]})
	return out

func play(test: String) -> void:
	last = test
	var list := HotReveal.heaters(rows_for(test))
	if reveal.start(list, team, true):
		status = ""
	else:
		status = "NOBODY HEATED UP: REVEAL SKIPPED"
		Sfx.play("click")
	stage_cv.queue_redraw()

func _draw_stage(ci: Control) -> void:
	if reveal != null and reveal.running:
		return
	UI.text(ci, Vector2(0, roundf(ci.size.y / 2.0)), status, 8, UI.GOLD if status.begins_with("NOBODY") else UI.DIM, "caps",
		HORIZONTAL_ALIGNMENT_CENTER, ci.size.x)
	if status.begins_with("NOBODY"):
		UI.text(ci, Vector2(0, roundf(ci.size.y / 2.0) + 12.0), "AFTER A GAME THE SUMMARY GOES STRAIGHT ON TO THE ROUND", 8, UI.DIM, "caps",
			HORIZONTAL_ALIGNMENT_CENTER, ci.size.x)

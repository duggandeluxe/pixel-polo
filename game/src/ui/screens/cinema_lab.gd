extends BaseScreen
## Developer Mode's PREGAME CINEMATIC TESTING (Settings > Developer Mode): the pregame entrance
## (PregameIntro, the very object a match plays) on demand, for any two schools, with no game.
##   < HOME > / < AWAY >   any of the 30 schools (your career's, or a setup made here)
##   GAME TYPE             REGULAR SEASON / CONFERENCE TOURNAMENT / NCSA CHAMPIONSHIP
##   PLAY FULL             the whole entrance
##   DOORS / REVEAL / MATCHUP   that part, then it holds
##   TEST SKIP             plays, skips at 1.2 s: one hand-over, a second skip does nothing
##   HALLWAY .. FINAL      the stages frozen (Level 3's dark corridor, closed, half-open, open,
##                         the doorway, the reveal, the game's camera). These and DOORS / REVEAL /
##                         MATCHUP are on the doors' clock: at Level 3 they start after the corridor
##   MOTION: FULL / CALM   Reduce Motion's version (the lab's own: the setting stays)
##   FULL SIZE             the stage alone, at the game's own size (a tap brings the buttons back)
##   LEVEL: n              the level everything above plays at (1 .. Pregame Presentation's top)
## Nothing is played, counted, spent or saved: no match, no season, no XP, no coins.

const TYPES := ["REGULAR SEASON", "CONFERENCE TOURNAMENT", "NCSA CHAMPIONSHIP"]
const STILLS := [["HALLWAY", -0.7], ["CLOSED", 0.3], ["HALF-OPEN", 1.15], ["OPEN", 1.7], ["DOORWAY", 2.3], ["REVEAL", 3.1], ["FINAL", 4.2]]

var teams: Array = []
var home_i := 0
var away_i := 1
var type_i := 0
var calm := false
var intro: PregameIntro
var stage_cv: Control
var motion_btn: Button
var type_btn: Button
var part_end := -1.0              # a part's preview stops (holds) here
var handovers := 0                # (TEST SKIP: how many times it handed over)
var status := "PICK A PREVIEW"
var level := 1
var rows: Array = []              # the button rows (FULL SIZE hides them)
var level_btn: Button

func _ready() -> void:
	build("PREGAME CINEMATIC TESTING")
	var src: Career = Game.career if Game.career != null else Career.new_setup(777)
	teams = src.teams.values()
	teams.sort_custom(func(a: PoloTeam, b: PoloTeam): return Colleges.short_name(a) < Colleges.short_name(b))
	if Game.career != null:
		home_i = teams.find(Game.career.team())
		away_i = (home_i + 1) % teams.size()
	stage_cv = UI.canvas(0, 0, func(ci: Control):
		if intro != null:
			intro.draw(ci, ci.size)
		ci.draw_rect(Rect2(0, ci.size.y - 12, ci.size.x, 12), Color(UI.INK, 0.75))
		UI.text(ci, Vector2(4, ci.size.y - 3), status, 8, UI.TEXT, "body"))
	stage_cv.name = "CinemaStage"
	stage_cv.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stage_cv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stage_cv.clip_contents = true
	body.add_child(stage_cv)
	var r1 := _row()
	r1.add_child(_btn("<", func(): _pick(true, -1), 20, "PrevHome"))
	r1.add_child(_btn("HOME >", func(): _pick(true, 1), 52, "NextHome"))
	r1.add_child(_btn("<", func(): _pick(false, -1), 20, "PrevAway"))
	r1.add_child(_btn("AWAY >", func(): _pick(false, 1), 52, "NextAway"))
	type_btn = _btn("", func():
		type_i = (type_i + 1) % TYPES.size()
		_labels(), 150, "GameType", "ghost")
	r1.add_child(type_btn)
	motion_btn = _btn("", func():
		calm = not calm
		_labels(), 84, "Motion", "ghost")
	r1.add_child(motion_btn)
	var r2 := _row()
	r2.add_child(_btn("PLAY FULL", func(): play(0.0, -1.0), 70, "PlayFull", "primary"))
	r2.add_child(_btn("DOORS", func(): play(at(0.4), at(1.7)), 56, "PreviewDoors"))
	r2.add_child(_btn("REVEAL", func(): play(at(2.4), at(3.9)), 56, "PreviewReveal"))
	r2.add_child(_btn("MATCHUP", func(): play(at(3.2), at(4.0)), 62, "PreviewMatchup"))
	r2.add_child(_btn("TEST SKIP", test_skip, 66, "TestSkip"))
	var r3 := _row()
	for st in STILLS:
		var st_at: float = st[1]
		var nm: String = st[0]
		r3.add_child(_btn(nm, func(): still(at(st_at), nm), 56, "Still" + nm.replace("-", "")))
	var r4 := _row()
	r4.add_child(_btn("FULL SIZE", full_size, 50, "FullSize"))
	level_btn = _btn("", func():
		level = level % VisualUpgrades.top("pregame") + 1
		_labels(), 44, "LabLevel", "ghost")
	r4.add_child(level_btn)
	_labels()
	still(0.3, "CLOSED")

func _row() -> HBoxContainer:
	var r := UI.hbox(3)
	r.alignment = BoxContainer.ALIGNMENT_CENTER
	body.add_child(r)
	rows.append(r)
	return r

func _btn(text: String, cb: Callable, w: int, n: String, style := "normal") -> Button:
	var b := UI.button(text, cb, style, w, 18)
	b.name = n
	b.clip_text = true
	return b

func on_back() -> void:
	Sfx.play("back")
	Sfx.crowd(0.0)
	Game.back("dev_settings")

func home() -> PoloTeam:
	return teams[home_i]

func away() -> PoloTeam:
	return teams[away_i]

func _pick(is_home: bool, d: int) -> void:
	if is_home:
		home_i = posmod(home_i + d, teams.size())
		if home_i == away_i:
			home_i = posmod(home_i + d, teams.size())
	else:
		away_i = posmod(away_i + d, teams.size())
		if away_i == home_i:
			away_i = posmod(away_i + d, teams.size())
	_labels()
	still(intro.t if intro != null else 0.3, "")

func _labels() -> void:
	type_btn.text = TYPES[type_i]
	motion_btn.text = "MOTION: %s" % ("CALM" if calm else "FULL")
	level_btn.text = "LEVEL: %d" % level

## A time `s` on the doors' clock as the entrance's own (after Level 3's corridor; never before 0).
func at(s: float) -> float:
	return maxf(0.0, s + PregameIntro.lead_for(level, calm))

## A fresh entrance for the picked schools (home on the left door).
func make() -> PregameIntro:
	var it := PregameIntro.new(home(), away(), true, TYPES[type_i], Colleges.venue_name(home().id))
	it.calm = calm
	it.set_level(level)
	var ev := PoolView.new()
	ev.width = maxf(stage_cv.size.x, 120.0)
	ev.height = maxf(stage_cv.size.y, 80.0)
	ev.snap_to(Sprint.new(home(), away(), 0.0).focus())
	it.end_view = ev
	return it

## The stage alone, or the buttons back.
func full_size() -> void:
	for r: Control in rows:
		r.visible = not r.visible

func _input(e: InputEvent) -> void:
	if not rows[0].visible and e is InputEventMouseButton and e.pressed:
		full_size()
		get_viewport().set_input_as_handled()

## Plays from `from` to `to` (-1: the end), then holds there.
func play(from: float, to: float) -> void:
	intro = make()
	intro.t = from
	part_end = to
	status = "PLAYING %s VS %s" % [Colleges.short_name(home()).to_upper(), Colleges.short_name(away()).to_upper()]

## A stage frozen at `at`.
func still(at: float, name: String) -> void:
	intro = make()
	intro.t = at
	intro.hold = at
	part_end = -1.0
	intro.step(0.0)
	status = "%s  (t %.2f s, %s)" % [name if name != "" else "STILL", at, intro.stage()]

## Plays, skips at 1.2 s; the hand-over happens once.
func test_skip() -> void:
	play(0.0, -1.0)
	handovers = 0
	status = "TEST SKIP: PLAYING..."
	get_tree().create_timer(1.2).timeout.connect(_do_skip)

func _do_skip() -> void:
	if intro == null:
		return
	for i in 2:
		var was := intro.done
		intro.skip()
		if intro.done and not was:
			handovers += 1
	status = "SKIPPED AT %.1f S: %d HAND-OVER%s (A SECOND SKIP DID NOTHING)" % [intro.t, handovers, "" if handovers == 1 else "S"]

func _process(dt: float) -> void:
	if intro != null and not intro.done:
		if part_end >= 0.0 and intro.t >= part_end and intro.hold < 0.0:
			intro.hold = part_end
			status = "HELD AT %.1f S (%s)" % [part_end, intro.stage()]
		intro.step(dt)
		if intro.done and not intro.skipped:
			status = "DONE: THE MATCH WOULD START NOW (NOTHING STARTED HERE)"
	stage_cv.queue_redraw()

extends BaseScreen
## Developer Mode's PREGAME CINEMATIC TESTING (Settings > Developer Mode): the pregame entrance
## (PregameIntro, the very object a match plays) on demand, for any two schools, with no game.
##   < HOME > / < AWAY >   any of the 30 schools (your career's, or a setup made here)
##   GAME TYPE             REGULAR SEASON / CONFERENCE TOURNAMENT / NCSA CHAMPIONSHIP
##   PLAY FULL             the whole entrance
##   DOORS / REVEAL / MATCHUP   that part, then it holds
##   TEST SKIP             plays, skips at 1.2 s: one hand-over, a second skip does nothing
##   CLOSED .. FINAL       the stages frozen (closed, half-open, open, the doorway, the reveal,
##                         the game's camera)
##   MOTION: FULL / CALM   Reduce Motion's version (the lab's own: the setting stays)
##   LEVEL 4: STARTING SEVEN SHOWCASE   the whole Level 4 entrance
##   HOME 7 / AWAY 7       that team's graphic, then it holds
##   LINEUP                the next bench man in for a home starter, through the team's own
##                         lineup; the team is put back at once, only this preview shows him
##   PORTRAITS             checks all 14 faces against the Roster's own pictures
##   FULL SIZE             the stage alone, at the game's own size (a tap brings the buttons back)
##   LEVEL: n              the level everything above plays at
## Nothing is played, counted, spent or saved: no match, no season, no XP, no coins.

const TYPES := ["REGULAR SEASON", "CONFERENCE TOURNAMENT", "NCSA CHAMPIONSHIP"]
const STILLS := [["CLOSED", 0.3], ["HALF-OPEN", 1.15], ["OPEN", 1.7], ["DOORWAY", 2.3], ["REVEAL", 3.1], ["FINAL", 4.2]]

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
var swaps := 0                    # LINEUP: how many bench men in (0: the real seven)
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
	r2.add_child(_btn("DOORS", func(): play(0.4, 1.7), 56, "PreviewDoors"))
	r2.add_child(_btn("REVEAL", func(): play(2.4, 3.9), 56, "PreviewReveal"))
	r2.add_child(_btn("MATCHUP", func(): play(3.2, 4.0), 62, "PreviewMatchup"))
	r2.add_child(_btn("TEST SKIP", test_skip, 66, "TestSkip"))
	var r3 := _row()
	for st in STILLS:
		var at: float = st[1]
		var nm: String = st[0]
		r3.add_child(_btn(nm, func(): still(at, nm), 56, "Still" + nm.replace("-", "")))
	var r4 := _row()
	r4.add_child(_btn("LEVEL 4: STARTING SEVEN SHOWCASE", showcase, 170, "Showcase", "primary"))
	r4.add_child(_btn("HOME 7", func(): seven(0), 44, "HomeSeven"))
	r4.add_child(_btn("AWAY 7", func(): seven(1), 44, "AwaySeven"))
	r4.add_child(_btn("LINEUP", change_lineup, 44, "ChangeLineup"))
	r4.add_child(_btn("PORTRAITS", portraits, 52, "PortraitTest"))
	r4.add_child(_btn("FULL SIZE", full_size, 50, "FullSize"))
	level_btn = _btn("", func():
		level = level % VisualUpgrades.MAX_LEVEL + 1
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
	Game.back("settings")

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

## A fresh entrance for the picked schools (home on the left door).
func make() -> PregameIntro:
	var it := PregameIntro.new(home(), away(), true, TYPES[type_i], Colleges.venue_name(home().id))
	it.calm = calm
	var kept := home().lineup.duplicate()
	if swaps > 0:
		_swap_in(home())
	it.set_level(level)
	home().lineup = kept
	var ev := PoolView.new()
	ev.width = maxf(stage_cv.size.x, 120.0)
	ev.height = maxf(stage_cv.size.y, 80.0)
	ev.snap_to(Sprint.new(home(), away(), 0.0).focus())
	it.end_view = ev
	return it

## The team's lineup with bench man number `swaps` in for a field starter (make() puts it back).
func _swap_in(t: PoloTeam) -> void:
	var seven := t.starters()
	var bench := t.roster.filter(func(q: PoloPlayer): return not seven.has(q) and not q.is_keeper())
	if bench.is_empty():
		return
	var ids: Array = []
	for p: PoloPlayer in seven:
		ids.append(p.id)
	ids[1 + (swaps - 1) % 6] = (bench[(swaps - 1) % bench.size()] as PoloPlayer).id
	t.lineup = ids

## The complete Level 4 entrance.
func showcase() -> void:
	level = 4
	_labels()
	play(0.0, -1.0)

## Team `i`'s Starting Seven, held when it's in.
func seven(i: int) -> void:
	level = 4
	_labels()
	var probe := make()
	play(probe.seven_at(i), probe.seven_at(i) + PregameIntro.SHOW_TIME - 0.1)
	status = "%s STARTING SEVEN" % ("HOME" if i == 0 else "AWAY")

## The next bench man into the home seven, on the preview only.
func change_lineup() -> void:
	swaps += 1
	level = 4
	_labels()
	var probe := make()
	intro = probe
	intro.t = probe.seven_at(0) + 1.0
	intro.hold = intro.t
	part_end = -1.0
	var left: Array = home().starters().filter(func(p: PoloPlayer): return not probe.sevens[0].men.has(p))
	status = "TEST LINEUP: %s OUT (THIS PREVIEW ONLY)" % (left[0] as PoloPlayer).last.to_upper() if not left.is_empty() else "NO BENCH MAN TO SWAP"

## All 14 faces against the Roster's own: how many match.
func portraits() -> int:
	level = 4
	_labels()
	var it := make()
	var same := 0
	for s: Dictionary in it.sevens:
		for p: PoloPlayer in s.men:
			var col := Portrait.colors_ours(p, s.team)
			if PregameIntro.face(p, s.team, Vector2i(52, 58)) == Portrait.texture(p, col[0], col[1]) and PregameIntro.face(p, s.team, Portrait.CARD_ZOOM) == Portrait.texture_zoomed(p, col[0], col[1], Portrait.CARD_ZOOM):
				same += 1
	status = "PORTRAITS: %d OF 14 ARE THE ROSTER'S OWN" % same
	return same

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
	get_tree().create_timer(3.8 if level >= 4 else 1.2).timeout.connect(_do_skip)

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

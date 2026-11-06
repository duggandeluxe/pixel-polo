extends "res://src/ui/screens/play_lab.gd"
## Developer Mode's HOT STAR TESTING (Settings > Developer Mode): what a player's Hot Stars do,
## without waiting for a run of games. Pick a player (your career's roster, or a made-up club
## with no career loaded) and see:
##   left   his permanent attributes against the ones he plays with (Attributes.effective: his
##          Hot bonus on top, past 10 too), the bonus, whether his spark ring is on, whether a
##          shot of his burns, and Reduce Motion
##   right  a real possession in the water (play_lab: Play, PoolArt, HotFire, the match's own
##          drawing calls) with him in it: on the ball at the point, or a keeper in goal
## PREVIEW 0 / 1 / 2 HOT STARS  the stars on the lab's copy of him (his `heat`, the one thing Hot
##                             Stars are), and he shoots (Play.dev_goal): 0 a plain shot, 1 the
##                             flaming shot, 2 the spark ring under him and the same flaming shot.
##                             A keeper never shoots, so the man on the ball takes it at his stars
## FLAMING SHOT                the flaming shot at his stars (one if he has none)
## 2-STAR SPARK RING           two stars and the possession plays on: the ring as he swims
## MOTION: FULL / CALM         the art as Reduce Motion draws it (the lab's own: the setting stays)
## RESET VISUAL PREVIEW        back to his real Hot Stars, full motion, a fresh possession
## APPLY TO TEST GAME          a full exhibition match (career: false) with the lab's copies,
##                             him at the stars set here: real gameplay, nothing counted
## < SCHOOL >                 any school: yours or a CPU one (the Universal Hot Star Balancing
##                             update: the same rules for everyone), its whole roster to pick from
## +1 GOOD GAME                his next grade a GOOD one, through PlayerForm.push_grade (the real
##                             momentum system, on the lab's copy): watch HOT PROGRESS move
## 1ST / 2ND-STAR THRESHOLD    from nothing (or from HOT), GOOD games until the star comes; checks
##                             a game just under the GOOD bar (PlayerForm.good_at) doesn't count
## The panel shows his HOT PROGRESS (PlayerForm.momentum) and the GLOBAL HOT STAR ACQUISITION
## DIFFICULTY (PlayerForm.HOT_STAR_ACQUISITION_MULTIPLIER: the GOOD bar every star is built from).
## Everything happens to copies made here (PoloTeam.from_dict of the real team): his saved
## attributes, his real heat, his form, the career and the save are never touched.

var schools: Array = []           # every school to pick from: yours first (PoloTeam, read only)
var school_i := 0
var source: PoloTeam              # the real team (read only)
var mine: PoloTeam                # the lab's copy of it
var opp: PoloTeam                 # who they play (a copy too)
var ids: Array = []               # the players to pick from, keeper first
var pick := 0
var real_heat := 0                # his heat in the real team
var still := false                # MOTION: CALM
var info_cv: Control
var motion_btn: Button
var mode := "PREVIEW"
var last_demo := ""

func _ready() -> void:
	build("HOT STAR TESTING")
	if Game.career != null:
		schools.append(Game.career.team())
		var rest: Array = Game.career.teams.values().filter(func(t): return t != Game.career.team())
		rest.sort_custom(func(a: PoloTeam, b: PoloTeam): return Colleges.short_name(a) < Colleges.short_name(b))
		schools.append_array(rest)
	else:
		for i in 4:
			schools.append(League.make_team(i + 2, 1))
	_school(0)
	var top := UI.hbox(4)
	top.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(top)
	info_cv = UI.canvas(196, 0, _draw_info)
	info_cv.name = "HotInfo"
	info_cv.size_flags_vertical = Control.SIZE_EXPAND_FILL
	top.add_child(info_cv)
	stage_cv = UI.canvas(0, 0, _draw_stage)
	stage_cv.name = "HotStage"
	stage_cv.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stage_cv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stage_cv.clip_contents = true
	top.add_child(stage_cv)
	var row := UI.hbox(3)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	body.add_child(row)
	row.add_child(_btn("<", func(): select(pick - 1), 22, "PrevPlayer"))
	row.add_child(_btn(">", func(): select(pick + 1), 22, "NextPlayer"))
	row.add_child(UI.label("PREVIEW", 8, UI.ACCENT, "caps"))
	for n in 3:
		var lv := n
		row.add_child(_btn("%d HOT STAR%s" % [n, "" if n == 1 else "S"], func(): preview_stars(lv), 76, "Preview%d" % n))
	motion_btn = _btn("", func():
		still = not still
		_labels(), 78, "Motion", "ghost")
	row.add_child(motion_btn)
	var row2 := UI.hbox(3)
	row2.alignment = BoxContainer.ALIGNMENT_CENTER
	body.add_child(row2)
	row2.add_child(_btn("FLAMING SHOT", preview_shot, 92, "PreviewShot"))
	row2.add_child(_btn("2-STAR SPARK RING", preview_ring, 104, "PreviewRing"))
	row2.add_child(_btn("RESET VISUAL PREVIEW", reset_state, 116, "ResetTest", "ghost"))
	row2.add_child(_btn("APPLY TO TEST GAME", apply_to_test_game, 104, "ApplyTest", "primary"))
	var row3 := UI.hbox(3)
	row3.alignment = BoxContainer.ALIGNMENT_CENTER
	body.add_child(row3)
	row3.add_child(_btn("< SCHOOL", func(): select_school(school_i - 1), 62, "PrevSchool"))
	row3.add_child(_btn("SCHOOL >", func(): select_school(school_i + 1), 62, "NextSchool"))
	row3.add_child(_btn("+1 GOOD GAME", add_good_game, 84, "GoodGame"))
	row3.add_child(_btn("1ST-STAR THRESHOLD", func(): test_star(1), 108, "TestFirst", "ghost"))
	row3.add_child(_btn("2ND-STAR THRESHOLD", func(): test_star(2), 108, "TestSecond", "ghost"))
	_labels()
	select.call_deferred(0)

## Picks school `i` (wraps): its roster to choose from, and an opponent for the stage.
func _school(i: int) -> void:
	school_i = posmod(i, schools.size())
	source = schools[school_i]
	var other: PoloTeam = null
	if Game.career != null:
		other = Game.career.teams.get(String(Game.career.next_game().get("opp", ""))) if source == Game.career.team() else Game.career.team()
	if other == null or other == source:
		other = schools[(school_i + 1) % schools.size()] if schools.size() > 1 else League.make_team(3, 1)
	opp = PoloTeam.from_dict(other.to_dict())
	ids.clear()
	for p: PoloPlayer in source.starters():
		ids.append(p.id)
	for p: PoloPlayer in source.roster:
		if not ids.has(p.id):
			ids.append(p.id)

func select_school(i: int) -> void:
	_school(i)
	select(0)

## Yours or the CPU's.
func cpu() -> bool:
	return Game.career == null or source != Game.career.team()

## +1 GOOD GAME: his next grade GOOD, through the momentum system itself (on the copy).
func add_good_game() -> void:
	var p := player()
	if p == null:
		return
	var was := p.heat
	PlayerForm.push_grade(p, PlayerForm.GOOD)
	mode = "SIMULATED PROGRESS (COPY)"
	last_demo = "+1 GOOD GAME"
	settled()
	status = "+1 GOOD GAME: %s%s" % [String(PlayerForm.momentum(p).status), "  (HOT STAR %d EARNED)" % p.heat if p.heat > was else ""]

## From scratch (1: NORMAL, no grades) or from HOT (2), GOOD games until star `n` comes, with a
## game just under the bar first (it mustn't count). {games, ok}; on the copy.
func test_star(n: int) -> Dictionary:
	var p := player()
	if p == null:
		return {"games": 0, "ok": false}
	p.form = []
	p.heat = 0
	p.heat_bonus = 0.0
	if n == 2:
		for i in PlayerForm.HOT_AT:
			PlayerForm.push_grade(p, PlayerForm.GOOD)
	var under := PlayerForm.grade_of(PlayerForm.good_at() - 0.01)
	var games := 0
	while p.heat < n and games < 10:
		PlayerForm.push_grade(p, PlayerForm.grade_of(PlayerForm.good_at()))
		games += 1
	var ok := p.heat == n and under == 0
	mode = "THRESHOLD TEST (COPY)"
	last_demo = "%s-STAR THRESHOLD" % ("1ST" if n == 1 else "2ND")
	settled()
	status = "%s: %d MORE GOOD GAME%s (EACH +%.2f OVER EXPECTED; +%.2f ISN'T ONE)  %s" % [last_demo, games, "" if games == 1 else "S",
		PlayerForm.good_at(), PlayerForm.good_at() - 0.01, "PASS" if ok else "FAIL"]
	return {"games": games, "ok": ok}

func _btn(text: String, cb: Callable, w: int, n: String, style := "normal") -> Button:
	var b := UI.button(text, cb, style, w, 18)
	b.name = n
	b.clip_text = true
	return b

func _labels() -> void:
	motion_btn.text = "MOTION: %s" % ("CALM" if still else "FULL")
	if info_cv != null:
		info_cv.queue_redraw()

# ------------------------------------------------------------------ the player
## The lab's copy of the player picked (null before the first pick).
func player() -> PoloPlayer:
	return mine.find_id(int(ids[pick])) if mine != null and not ids.is_empty() else null

## Pick player `i` (wraps): a fresh copy of the team, him in its seven, his real Hot Stars.
func select(i: int) -> void:
	if ids.is_empty():
		return
	pick = posmod(i, ids.size())
	mine = PoloTeam.from_dict(source.to_dict())
	var real := source.find_id(int(ids[pick]))
	real_heat = real.heat if real != null else 0
	_into_seven(player())
	mode = "SAVED STATE"
	last_demo = ""
	settled()

## Puts `p` in the copy's seven (in the place of a starter of his kind) if he isn't there, so the
## stage has him. Only the copy's lineup moves.
func _into_seven(p: PoloPlayer) -> void:
	if p == null:
		return
	var seven := mine.starters()
	if seven.has(p):
		return
	var line: Array = seven.map(func(q: PoloPlayer): return q.id)
	var at := 0
	if not p.is_keeper():
		at = 1
		for i in range(1, line.size()):
			if (mine.find_id(int(line[i])) as PoloPlayer).pos == p.pos:
				at = i
				break
	line[at] = p.id
	mine.lineup = line

## PREVIEW: `n` Hot Stars on the copy (the heat PlayerForm keeps: his effective attributes and
## his fire follow from it).
func set_stars(n: int) -> void:
	var p := player()
	if p == null:
		return
	p.heat = clampi(n, 0, PlayerForm.LEVELS.size() - 1)
	mode = "PREVIEW"
	settled()

func reset_state() -> void:
	still = false
	var p := player()
	if p != null:
		p.heat = real_heat
	if opp != null:
		for q: PoloPlayer in opp.roster:
			q.heat = 0
	mode = "SAVED STATE"
	last_demo = ""
	_labels()
	settled()

## PREVIEW n HOT STARS: the stars, and a shot at them (plain at 0, the flaming shot at 1 or 2).
func preview_stars(n: int) -> void:
	set_stars(n)
	last_demo = "%d HOT STAR%s" % [n, "" if n == 1 else "S"]
	_shoot(n, ["NORMAL PLAYER, NORMAL SHOT", "NORMAL PLAYER, FLAMING SHOT", "SPARK RING, FLAMING SHOT"][n])

## FLAMING SHOT: at his stars, one if he has none.
func preview_shot() -> void:
	var p := player()
	if p == null:
		return
	var n := maxi(1, Attributes.hot_stars(p))
	set_stars(n)
	last_demo = "FLAMING SHOT"
	_shoot(n, "FLAMING SHOT AT %d HOT STAR%s" % [n, "" if n == 1 else "S"])

## 2-STAR SPARK RING: two stars and the possession plays on.
func preview_ring() -> void:
	set_stars(2)
	last_demo = "2-STAR SPARK RING"
	_stage()
	paused = false
	status = "2-STAR SPARK RING: THE POSSESSION PLAYS ON"

## A shot at `n` stars from the man on the ball (him, or for a keeper the other side's man, given
## the keeper's stars so the shot shows them).
func _shoot(n: int, what: String) -> void:
	_stage()
	var shooter := play.holder
	if shooter != null and shooter.player != player():
		shooter.player.heat = n
	paused = false
	if not play.dev_goal(Geo.GOAL_Y - 0.6, 0.55):
		status = "COULDN'T SET UP THE SHOT"
		return
	status = "%s: %s%s" % [last_demo, what, "" if shooter == null or shooter.player == player() else " (BY %s)" % shooter.player.short_name().to_upper()]

## The live test: a whole match with the lab's copies (an exhibition: no career, nothing counted).
func apply_to_test_game() -> void:
	var p := player()
	if p == null:
		return
	mode = "TEST GAME"
	Game.match_cfg = {"us": mine, "them": PoloTeam.from_dict(opp.to_dict()), "seed": randi(), "career": false, "home": true,
		"minutes": float(MatchState.quarter_min_for(false))}
	Game.goto("match", Game.match_cfg)

# ------------------------------------------------------------------ the stage
## A fresh possession with him in it, still: a field player on the ball at the point, a keeper in
## goal against the other team's man on the ball.
func _stage() -> void:
	var p := player()
	if p == null:
		return
	if p.is_keeper():
		us = opp
		them = mine
	else:
		us = mine
		them = opp
	new_play()
	var holder: Swimmer = null
	if not p.is_keeper():
		for s in play.attackers:
			if s.player == p:
				holder = s
	if holder == null:
		holder = DefenseFormation.by_tag(play.attackers, "3")
	if holder == null:
		holder = play.attackers[0]
	var from := BarHit.DEMO_FROM
	holder.pos = from
	holder.vel = Vector2.ZERO
	holder.target = from
	holder.facing = 1.0
	play.give_ball(holder)
	view.snap_to(focus())

## A keeper: the camera on his goal, the shooter still in the picture; anyone else, the attack.
func focus() -> Vector2:
	var p := player()
	if play != null and p != null and p.is_keeper():
		return play.keeper.pos.lerp(play.ball.pos, 0.35)
	return view.attack_frame(play)

func settled() -> void:
	_stage()
	paused = true
	var p := player()
	if p != null and not p.is_available():
		status = "%s IS OUT (INJURED / SUSPENDED): A STAND-IN PLAYS" % p.short_name().to_upper()
	else:
		status = "PICK A PREVIEW" if last_demo == "" else "DONE: %s  (PREVIEW AGAIN TO REPLAY)" % last_demo
	if info_cv != null:
		info_cv.queue_redraw()

func fire_still() -> bool:
	return still or HotFire.calm()

func lab_tick(_dt: float) -> void:
	info_cv.queue_redraw()

## His mark in the water: a small white tick over him, so he's easy to find among fourteen.
func lab_draw(ci: Control) -> void:
	var p := player()
	if play == null or p == null:
		return
	for s in play.bodies():
		if s.player == p:
			var o := view.to_screen(s.pos) - Vector2(0, roundf(s.hop))
			var y := o.y - 22
			ci.draw_rect(Rect2(o.x - 2, y, 5, 1), Color.WHITE)
			ci.draw_rect(Rect2(o.x - 1, y + 1, 3, 1), Color.WHITE)
			ci.draw_rect(Rect2(o.x, y + 2, 1, 1), Color.WHITE)

# ------------------------------------------------------------------ the readout
## The rows of the left panel: [label, value, colour], for the drawing and the tests.
func rows() -> Array:
	var p := player()
	if p == null:
		return []
	var lv := Attributes.hot_stars(p)
	var fx := HotFire.status(p)
	var mo := PlayerForm.momentum(p)
	var out: Array = [["SCHOOL", "%s (%s)" % [Colleges.short_name(source).to_upper(), "CPU" if cpu() else "YOU"], UI.TEXT],
		["PLAYER", "%s  #%d %s" % [p.short_name().to_upper(), p.number, p.pos_text()], UI.TEXT],
		["HOT STARS", "%d  (%s)" % [lv, mode], UI.GOLD if lv == 0 else PlayerForm.FIRE_RED],
		["HOT PROGRESS", "%s %d%%" % [String(mo.status), roundi(float(mo.bar) * 100.0)], UI.TEXT],
		["ACQUISITION", "%.2fx ORIGINAL (GOOD +%.2f)" % [PlayerForm.acquisition, PlayerForm.good_at()], UI.GOLD],
		["BONUS", "%+.1f EACH" % Attributes.hot_bonus(p), UI.TEXT]]
	for k in Attributes.keys_for(p):
		out.append([String(Attributes.NAMES[k]).to_upper(), "%s|%s" % [Attributes.text(Attributes.value(p, k)), Attributes.text(Attributes.effective(p, k))], UI.ACCENT])
	out.append(["SPARK RING", "ON" if fx.ring else "OFF", UI.TEXT])
	out.append(["FLAMING SHOT", "ON" if fx.shot else "OFF", UI.TEXT])
	out.append(["REDUCE MOTION", ("ON" if HotFire.calm() else "OFF") + ("  (LAB: CALM)" if still else ""), UI.TEXT])
	return out

func _draw_info(ci: Control) -> void:
	var r := Rect2(Vector2.ZERO, ci.size)
	ci.draw_rect(r, Deck.NAVY)
	ci.draw_rect(Rect2(0, 0, r.size.x, 1), UI.BORDER)
	ci.draw_rect(Rect2(0, r.size.y - 1, r.size.x, 1), UI.BORDER)
	ci.draw_rect(Rect2(0, 0, 1, r.size.y), UI.BORDER)
	ci.draw_rect(Rect2(r.size.x - 1, 0, 1, r.size.y), UI.BORDER)
	var y := 8.0
	var head := false
	for row: Array in rows():
		var v := String(row[1])
		if v.contains("|"):
			if not head:
				Deck.text(ci, 5, y, "ATTRIBUTE", 8, UI.DIM)
				Deck.rtext(ci, 140, y, "BASE", 8, UI.DIM)
				Deck.rtext(ci, r.size.x - 5, y, "EFFECTIVE", 8, UI.DIM)
				y += 10.0
				head = true
			var parts := v.split("|")
			Deck.text(ci, 5, y, String(row[0]), 8, row[2])
			Deck.rtext(ci, 140, y, parts[0], 8, UI.TEXT)
			var boosted := float(parts[1]) > float(parts[0]) + 0.001
			Deck.rtext(ci, r.size.x - 5, y, parts[1], 8, PlayerForm.FIRE_RED if boosted else UI.TEXT)
		else:
			Deck.text(ci, 5, y, String(row[0]), 8, UI.ACCENT)
			Deck.rtext(ci, r.size.x - 5, y, Deck.fit(v, r.size.x - 80), 8, row[2])
		y += 10.0

extends "res://src/match/match_screen.gd"
## The tutorial on screen: one continuous lesson in four parts (Drill.ORDER), each a DrillFlow
## played by MatchScreen itself (the pool, the bodies, the aim guide, the banners, every touch
## read the way a match reads it), with the scoreboard swapped for the tutorial's strip (BACK, the
## instruction, the part and its progress, RESTART). Each part opens on a pop-up (Drill.BRIEFS,
## GOT IT) with the play held behind it. When a part's done its callout comes up ("NICE PASSING!" /
## "NOW LET'S RUN A COUNTER!") while the play runs on, then the next part's pop-up.
##
## Two ways in. A NEW CAREER opens here (`in_career`): always from part 1, SKIP TUTORIAL in BACK's
## place, TRAINING COMPLETE at the end, and either way out goes to the hub with Career.tutorial
## saved: that's all it ever writes to the career. The GAME GUIDE's PLAY THE TUTORIAL is the
## practice run: each part done is kept (a setting, tutorials_done), it picks up at the first part
## not done yet, and TUTORIAL COMPLETE leads back to the main menu. Nothing here touches the
## match stats.

const BAR_H := 24.0           # the tutorial strip: where the scoreboard is in a match (PoolView.HUD_H)
const PART_WAIT := 0.6        # seconds from a part's last rep counting to its callout
const SEGUE := 1.8            # seconds the callout's up before the next part starts
const SEGUE_SUB_Y := Hud.CALLOUT_BOTTOM   # px: the callout's second line, under the big word (Hud.callout)
const CARD_WAIT := 1.2        # seconds from the last part's last rep to the card
const CARD_W := 300.0
const CARD_H := 86.0
const BTN_H := 22.0
const SKIP_W := 74.0          # the strip's buttons
const RESTART_W := 46.0
const POP_W := 320.0          # the pop-ups: a title, a sentence in big type, big buttons...
const POP_H := 122.0
const POP_BTN := Vector2(150, 30)   # ...30 px is over 40 pt on a phone
const TOUCH_SLOP := 3.0       # px: a finger's allowance round every button
const SKIP_TITLE := "SKIP TUTORIAL?"
const NAVY := Color("0b1d5c")
const YELLOW := Color("ffd23f")

var drill: Drill
var part := 0                 # where we are in Drill.ORDER...
var drill_id := "frontcourt"  # ...and its id
var teams: Array = []
var done_t := -1.0            # seconds since the part was completed (-1: not yet)
var segue_t := -1.0           # seconds the callout between parts has been up (-1: none)
var card_on := false
var in_career := false        # opened by NEW CAREER (Game.career is the new career)
var popup := {}               # the pop-up up, the play held behind it: {title, lines, buttons: [[label, Callable, primary]]}
var popup_under := {}         # what the SKIP question covers: it comes back on CANCEL

func setup(params: Dictionary) -> void:
	in_career = bool(params.get("career", false)) and Game.career != null
	var done: Array = Game.settings.get("tutorials_done", [])
	var from := String(params.get("id", ""))
	part = Drill.ORDER.find(from) if from in Drill.ORDER else Drill.resume_part(done)
	if in_career:
		part = 0
	elif from == "" and part == 0 and done.size() >= Drill.ORDER.size():
		Game.settings["tutorials_done"] = []   # all done before: this is a fresh run through
	teams = [League.make_team(0), League.make_team(3)]
	pool = Pools.get_def(Pools.DEFAULT_ID)
	crowd = 0.25
	bot_rng.seed = 99
	_start_part(part, false)

## Part `i` from its start, behind its pop-up (`brief`). `follow`: it follows on from the part just done.
func _start_part(i: int, follow: bool, brief: bool = true) -> void:
	var prev: DrillFlow = flow as DrillFlow
	part = i
	drill_id = Drill.ORDER[i]
	drill = Drill.make(drill_id)
	if follow and prev != null:
		drill.follow_on(prev)
	level = drill.level
	flow = DrillFlow.new(drill, teams[0], teams[1], randi())
	flow.start_rep()
	done_t = -1.0
	segue_t = -1.0
	card_on = false
	end_timer = -1.0
	last_play = null
	banner.clear()
	aim.cancel()
	popup = {}
	if brief:
		_show_popup(drill.title(), Drill.BRIEFS[drill_id], [["GOT IT", _close_popup, true]])

func _show_popup(title: String, lines: Array, buttons_: Array) -> void:
	popup = {"title": title, "lines": lines, "buttons": buttons_}
	aim.cancel()
	Sfx.play("card")

func _close_popup() -> void:
	popup = {}

func is_last_part() -> bool:
	return part + 1 >= Drill.ORDER.size()

# ------------------------------------------------------------------ loop
func _process(dt: float) -> void:
	if paused:
		return
	if card_on or not popup.is_empty():
		# nothing moves: the part's first frame stands behind its pop-up
		t += dt
		view.width = get_viewport_rect().size.x
		view.height = get_viewport_rect().size.y
		if flow.phase != last_phase or flow.play != last_play:
			_enter_phase()
		banner.step(dt)
		canvas.queue_redraw()
		return
	super._process(dt)
	if flow.phase in [MatchFlow.Phase.ATTACK, MatchFlow.Phase.DEFENSE]:
		drill.tick(flow, dt)
	if not drill.complete:
		return
	if done_t < 0.0:
		done_t = 0.0
		_mark_done()
	done_t += dt
	if segue_t >= 0.0:
		segue_t += dt
		if segue_t >= SEGUE:
			_start_part(part + 1, true)
		return
	var settled: bool = flow.finished or end_timer < 0.0   # (the last rep's banner has had its moment)
	if not is_last_part():
		if done_t >= PART_WAIT and settled:
			segue_t = 0.0
			aim.cancel()
			Sfx.play("good")
	elif done_t >= CARD_WAIT and settled:
		card_on = true
		aim.cancel()
		Sfx.play("perfect")
		if in_career:
			_show_popup("TRAINING COMPLETE!", ["You're ready to start your career."],
				[["START CAREER", func(): _begin_career(Career.TUTORIAL_COMPLETED), true]])

## Each part done is kept, so the practice run picks up after it next time.
func _mark_done() -> void:
	if in_career:
		return
	var seen: Array = Game.settings.get("tutorials_done", [])
	if not drill_id in seen:
		seen.append(drill_id)
		Game.settings["tutorials_done"] = seen
		Game.save_settings()

func _handle_events() -> void:
	var evs := flow.events.duplicate()
	super._handle_events()
	for e in evs:
		drill.on_event(flow, e)

## A ball nobody got to isn't a turnover here: no banner, a quick fresh rep (the drill says why).
func _on_play_end(e: Dictionary) -> void:
	if String(e.outcome) in ["turnover", "steal", "shotclock", "buzzer"]:
		end_timer = 1.0
		return
	super._on_play_end(e)

# ------------------------------------------------------------------ input
func _input(event: InputEvent) -> void:
	if paused:
		return
	var held: bool = card_on or segue_t >= 0.0 or not popup.is_empty()
	if event is InputEventScreenTouch:
		if event.pressed:
			for h in buttons_now(get_viewport_rect().size):
				if (h[0] as Rect2).grow(TOUCH_SLOP).has_point(event.position):
					Sfx.play("click")
					aim.cancel()
					(h[2] as Callable).call()
					get_viewport().set_input_as_handled()
					return
		if held or (event.pressed and event.position.y < BAR_H):
			get_viewport().set_input_as_handled()
			return
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
		# (a keyboard: Enter or Space is the pop-up's yellow button)
		var keys: Array = popup.get("buttons", [])
		for b in keys:
			if b[2]:
				Sfx.play("click")
				(b[1] as Callable).call()
				get_viewport().set_input_as_handled()
				return
	elif held:
		return
	super._input(event)

func _press(pos: Vector2, index: int) -> void:
	var was := _dive_now()
	super._press(pos, index)
	var now := _dive_now()
	if flow.phase == MatchFlow.Phase.DEFENSE and now != null and now != was:
		drill.dived(now.side)

## Your keeper's dive, in the shot (the duel) or before it (a guess in the wind-up).
func _dive_now() -> KeeperDive:
	if flow.duel != null:
		return flow.duel.anim
	return flow.keeper_anim

func _tap_to_pass(p: Play, pos: Vector2) -> void:
	if not drill.passing:
		return
	var had := p.holder
	super._tap_to_pass(p, pos)
	if had != null and p.holder == null and p.ball.state == Ball.State.PASS:
		drill.thrown(flow)

func _pull_to_shoot(p: Play) -> void:
	if drill.shooting:
		super._pull_to_shoot(p)

## RESTART: this part again from its start (the parts already done stay done).
func _restart() -> void:
	Sfx.play("back")
	_start_part(part, false, false)

## START OVER: the whole tutorial again from part 1 (nothing's kept as done).
func _start_over() -> void:
	Sfx.play("back")
	Game.settings["tutorials_done"] = []
	Game.save_settings()
	_start_part(0, false)

func _to_menu() -> void:
	Sfx.crowd(0.0)
	Game.history.clear()
	Game.goto("title", {}, false)

func _new_career() -> void:
	Sfx.crowd(0.0)
	Game.history = ["title"]
	Game.goto("careers", {}, false)

## SKIP TUTORIAL: the question first, everything held behind it.
func _ask_skip() -> void:
	popup_under = popup
	_show_popup(SKIP_TITLE, ["You can skip training and jump", "straight into your career."],
		[["CANCEL", func(): popup = popup_under, false],
		["SKIP", func(): _begin_career(Career.TUTORIAL_SKIPPED), true]])

## Out of the tutorial into the new career, how it ended saved with it. (Once: the fade to the hub
## takes a moment, and a second tap mustn't go again.)
func _begin_career(how: String) -> void:
	if Game.career.tutorial == how:
		return
	Sfx.crowd(0.0)
	Game.career.tutorial = how
	Game.save_career()
	Game.history.clear()
	Game.goto("hub", {}, false)

func _pause() -> void:
	if card_on or not popup.is_empty():
		return   # (nothing's running behind a card)
	paused = true
	aim.cancel()
	var menu: Array = [["RESUME", func(): paused = false, "primary"],
		["RESTART PART", func():
			paused = false
			_restart()]]
	if in_career:
		menu.append(["SKIP TUTORIAL", func():
			paused = false
			_ask_skip()])
	else:
		menu.append(["START OVER", func():
			paused = false
			_start_over()])
		menu.append(["MAIN MENU", _to_menu])
	Game.dialog("PAUSED", "TUTORIAL: " + drill.title(), menu)

# ------------------------------------------------------------------ drawing
## The strip's two: BACK (SKIP TUTORIAL on a new career's run) and RESTART.
func _strip_buttons(size: Vector2) -> Array:
	var ins := _insets()
	var left: Array = [Rect2(ins.x + 3, 3, 40, 17), "BACK", _to_menu, false]
	if in_career:
		left = [Rect2(ins.x + 3, 3, SKIP_W, 17), "SKIP TUTORIAL", _ask_skip, false]
	return [left, [Rect2(size.x - ins.y - 3 - RESTART_W, 3, RESTART_W, 17), "RESTART", _restart, false]]

## What's tappable right now: [Rect2, label, Callable, primary]. The strip's two; behind a
## part's pop-up only the way out, behind the SKIP question or TRAINING COMPLETE neither; the
## pop-up's own, and the card's two once it's up. (Drawing and touches both go by this.)
func buttons_now(size: Vector2) -> Array:
	var out := _strip_buttons(size)
	if not popup.is_empty():
		out = [] if card_on or popup.title == SKIP_TITLE else [out[0]]
		out.append_array(_popup_buttons(size))
	elif card_on and not in_career:
		var r := _card_rect(size)
		var gap := 6.0
		var bw := floorf((CARD_W - 16 - gap) / 2.0)
		var bx := r.position.x + 8
		for a in [["MAIN MENU", _to_menu, true], ["NEW CAREER", _new_career, false]]:
			out.append([Rect2(bx, r.end.y - BTN_H - 8, bw, BTN_H), a[0], a[1], a[2]])
			bx += bw + gap
	return out

func _popup_rect(size: Vector2) -> Rect2:
	return Rect2(roundf((size.x - POP_W) / 2.0), roundf((size.y - POP_H) / 2.0), POP_W, POP_H)

## The pop-up's buttons, side by side at its foot.
func _popup_buttons(size: Vector2) -> Array:
	var r := _popup_rect(size)
	var list: Array = popup.buttons
	var gap := 8.0
	var x := roundf(r.get_center().x - (POP_BTN.x * list.size() + gap * (list.size() - 1)) / 2.0)
	var out: Array = []
	for b in list:
		out.append([Rect2(Vector2(x, r.end.y - POP_BTN.y - 10), POP_BTN), b[0], b[1], b[2]])
		x += POP_BTN.x + gap
	return out

func _card_rect(size: Vector2) -> Rect2:
	return Rect2(roundf((size.x - CARD_W) / 2.0), roundf((size.y - CARD_H) / 2.0) + 8, CARD_W, CARD_H)

## The strip's second line: where you are in the tutorial, and this part's counts.
func part_line() -> String:
	return "PART %d/%d: %s   %s" % [part + 1, Drill.ORDER.size(), drill.title(), drill.progress()]

func _draw_hud(ci: Control, size: Vector2) -> void:
	# the tutorial strip, where the scoreboard is in a match: never over the water
	ci.draw_rect(Rect2(0, 0, size.x, BAR_H), Color(0.02, 0.04, 0.1, 0.9))
	ci.draw_rect(Rect2(0, BAR_H - 1, size.x, 1), UI.GOLD)
	var btns := buttons_now(size)
	var strip_btns := _strip_buttons(size)
	var back: Rect2 = strip_btns[0][0]
	var restart: Rect2 = strip_btns[1][0]
	var mid_x := back.end.x + 4
	var mid_w := restart.position.x - 4 - mid_x
	var line := drill.instruction() if not drill.complete else (drill.title() + " COMPLETE")
	UI.text(ci, Vector2(mid_x, 10), line, 8, UI.TEXT, "body", HORIZONTAL_ALIGNMENT_CENTER, mid_w)
	UI.text(ci, Vector2(mid_x, 20), part_line(), 8, UI.GOLD, "caps", HORIZONTAL_ALIGNMENT_CENTER, mid_w)
	# the shooting stick: the match's own (ShotStick: the wedge, the knob at its point, its fade),
	# drawn as a match draws it whenever it's yours to shoot with
	if flow.phase == MatchFlow.Phase.ATTACK and flow.play != null and drill.shooting and not card_on and popup.is_empty():
		stick.draw(ci, aim.stick)
	if not popup.is_empty():
		_draw_popup(ci, size)
	elif segue_t >= 0.0:
		_draw_segue(ci, size)
	else:
		banner.draw(ci, size)
	if card_on and not in_career:
		_draw_card(ci, size)
	for b in btns:
		_button(ci, b[0], b[1], b[3])

## Between parts: the banners' own callout (what you did), and a line under it (what's next).
func _draw_segue(ci: Control, size: Vector2) -> void:
	var words: Array = Drill.SEGUES.get(drill_id, ["", ""])
	var fade := clampf((SEGUE - segue_t) / 0.2, 0.0, 1.0)
	Hud.callout(ci, size, String(words[0]), EventBanner.YELLOW, segue_t, SEGUE - segue_t)
	var sub := String(words[1])
	var tw := UI.text_width(sub, 8, "caps") + 16
	var r := Rect2(roundf((size.x - tw) / 2.0), SEGUE_SUB_Y, tw, 14)
	ci.draw_rect(r, Color(0, 0, 0, 0.88 * fade))
	UI.text(ci, Vector2(r.position.x, r.position.y + 10), sub, 8, Color(UI.TEXT, fade), "caps", HORIZONTAL_ALIGNMENT_CENTER, tw)

## A pop-up, centred: its title, its sentence in big type (the buttons are buttons_now's).
func _draw_popup(ci: Control, size: Vector2) -> void:
	ci.draw_rect(Rect2(0, BAR_H, size.x, size.y - BAR_H), Color(0.02, 0.04, 0.1, 0.6))
	var r := _popup_rect(size)
	ci.draw_rect(r, NAVY)
	ci.draw_rect(r, UI.GOLD, false, 1.0)
	UI.text(ci, r.position + Vector2(0, 28), String(popup.title), 16, UI.GOLD, "big", HORIZONTAL_ALIGNMENT_CENTER, POP_W)
	var lines: Array = popup.lines
	for i in lines.size():
		UI.text(ci, r.position + Vector2(0, 52 + i * 17), String(lines[i]), 16, UI.TEXT, "body", HORIZONTAL_ALIGNMENT_CENTER, POP_W)

## The practice run's done: TUTORIAL COMPLETE, YOU'RE READY TO PLAY! (the buttons are buttons_now's).
func _draw_card(ci: Control, size: Vector2) -> void:
	ci.draw_rect(Rect2(0, BAR_H, size.x, size.y - BAR_H), Color(0.02, 0.04, 0.1, 0.6))
	var r := _card_rect(size)
	ci.draw_rect(r, NAVY)
	ci.draw_rect(r, UI.GOLD, false, 1.0)
	UI.text(ci, r.position + Vector2(0, 24), "TUTORIAL COMPLETE", 16, UI.GOLD, "big", HORIZONTAL_ALIGNMENT_CENTER, CARD_W)
	UI.text(ci, r.position + Vector2(0, 42), "YOU'RE READY TO PLAY!", 8, UI.TEXT, "caps", HORIZONTAL_ALIGNMENT_CENTER, CARD_W)

## A flat button in the match HUD's style (ResultsPanel's): yellow for the way on, navy otherwise.
func _button(ci: Control, r: Rect2, label: String, primary: bool) -> void:
	ci.draw_rect(r, YELLOW if primary else NAVY)
	if not primary:
		ci.draw_rect(r, UI.BORDER, false, 1.0)
	var big := r.size.y >= POP_BTN.y   # (a pop-up's button: the label in big type)
	UI.text(ci, Vector2(r.position.x, r.position.y + roundf(r.size.y / 2.0) + (6 if big else 4)), label, 16 if big else 8, NAVY if primary else UI.TEXT, "caps", HORIZONTAL_ALIGNMENT_CENTER, r.size.x)

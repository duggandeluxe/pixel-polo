extends "res://src/ui/screens/settings.gd"
## DEVELOPER (dev_settings): reached only through Settings' DEV button and its code (DevPad), and
## only while DevGate's session is open: Game.goto sends anything else to Settings, and the session
## closes on the way back to Settings (or the title, the hub, a reset), so the next visit asks again.
## Settings' look and pieces (this extends it), three panels:
##   DEVELOPER MODE    the ON / OFF toggle, exactly as it was (off also clears the BarHit and
##                     Scoreboard overrides)
##   DANGER ZONE       RESET EVERYTHING, after the same two confirmations
##   DEVELOPER TOOLS   (Developer Mode on) every lab: the HOT form lab, the SHOT & TEMPO TEST, the
##                     ATTRIBUTE TEST LAB, the HOT STAR REVEAL preview, SPECIAL GOAL EFFECTS,
##                     DEFENSIVE TESTING, RECORD ROOM ANIMATIONS, COACHING EVENTS, HOT STAR TESTING,
##                     COIN WALLET TESTING, PREGAME CINEMATIC TESTING, VISUAL UPGRADE TESTING, DYNASTY
##                     REFINEMENT TESTS, the COUNTERATTACK CURL TEST, DEV RECRUITS, VIEW SEASON REVIEW,
##                     VIEW ROSTER SET, the SCOREBOARD and GOAL CELEBRATION previews, and PREVIEW
##                     SCOUT GARAGE ANIMATION (ScoutReveal.preview: the real Scout door over this
##                     screen, no screen change, nothing scouted or saved), and PREVIEW HOT STAR
##                     TUTORIAL (HotTutorial.preview: the first-HOT-star tutorial on the loaded
##                     dynasty, from its home screen; nothing saved or marked seen), and PREVIEW TEAM
##                     UNLOCK ANIMATION (TeamUnlock.preview: the Road to Glory unlock show, a
##                     different tier each press; nothing awarded or saved), and PREVIEW FELL JUST
##                     SHORT (the FELL JUST SHORT! screen with a sample; nothing saved), and WALK-ON
##                     TESTING (walkon_lab: the walk-on popup, examples and odds; nothing saved). A lab's Back
##                     comes here again (the session stays open while you're in the labs).

func _ready() -> void:
	if not DevGate.is_open():   # (never built without the code, however it was made)
		Game.goto.call_deferred("settings", {}, false)
		return
	build("DEVELOPER")
	_refresh()

func _refresh() -> void:
	_clear_body()
	var top := UI.hbox(5)
	top.name = "Main"
	body.add_child(top)
	var go := _options()
	go.size_flags_stretch_ratio = 1.0
	top.add_child(go)
	top.add_child(_danger())
	if bool(Game.settings.get("dev_mode", false)):
		body.add_child(_dev_tools())
	else:
		var hint := para("Turn DEVELOPER MODE on for the developer tools.", UI.DIM, 200)
		hint.name = "DevHint"
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		body.add_child(hint)
	_pop_changed()

## Back to Settings (by the history: Settings' own Back still leads out). The session closes there.
func on_back() -> void:
	Sfx.play("back")
	Game.back("settings")

# ------------------------------------------------------------------ DEVELOPER MODE
func _options() -> Control:
	var s := _section("DEVELOPER MODE", "wrench", "Options")
	var v: VBoxContainer = s[1]
	var dev: bool = Game.settings.get("dev_mode", false)
	v.add_child(_row("dev", "DEVELOPER MODE", _toggle(dev, func():
		Game.settings.dev_mode = not dev
		if dev:
			BarHit.override = BarHit.Override.NORMAL   # (its overrides never outlive it)
			Scoreboard.override = 0
		Game.save_settings()
		_pop = "Toggle_dev_mode"
		_refresh(), "Toggle_dev_mode")))
	return s[0]

## Developer Mode's tools (unchanged), in their own panel.
func _dev_tools() -> Control:
	var s := _section("DEVELOPER TOOLS", "dev", "DevTools")
	var g := GridContainer.new()
	g.columns = 4
	g.add_theme_constant_override("h_separation", 3)
	g.add_theme_constant_override("v_separation", 3)
	var tools: Array = [["TEST PLAYER FORM", "form_lab", "FormLab"], ["SHOT & TEMPO TEST", "tempo_lab", "TempoLab"], ["ATTRIBUTE TEST LAB", "attr_lab", "AttrLab"],
			["HOT STAR REVEAL", "hot_lab", "HotLab"], ["SPECIAL GOAL EFFECTS", "fx_lab", "FxLab"], ["DEFENSIVE TESTING", "defense_lab", "DefenseLab"],
			["RECORD ROOM ANIMATIONS", "record_lab", "RecordLab"], ["COACHING EVENTS", "coach_lab", "CoachLab"],
			["HOT STAR TESTING", "hot_star_lab", "HotStarLab"], ["COIN WALLET TESTING", "coin_lab", "CoinLab"],
			["PREGAME CINEMATIC TESTING", "cinema_lab", "CinemaLab"], ["VISUAL UPGRADE TESTING", "visual_lab", "VisualLab"],
			["DYNASTY REFINEMENT TESTS", "refine_lab", "RefineLab"], ["COUNTERATTACK CURL TEST", "counter_lab", "CounterLab"],
			["DEV RECRUITS", "dev_lab", "DevLab"], ["VIEW SEASON REVIEW", "review_lab", "ReviewLab"],
			["SEASON OVER TESTING", "elim_lab", "ElimLab"], ["ATTRIBUTE BAR EFFECTS", "bar_lab", "BarLab"],
			["VIEW ROSTER SET", "roster_set", "ViewRosterSet"], ["SCOREBOARD VISUAL PREVIEW", "scoreboard_lab", "ScoreboardLab"],
			["GOAL CELEBRATION PREVIEW", "celeb_lab", "CelebLab"], ["WALK-ON TESTING", "walkon_lab", "WalkOnLab"],
			["PREVIEW SCOUT GARAGE ANIMATION", "", "PreviewScoutGarage"],
			["PREVIEW HOT STAR TUTORIAL", "", "PreviewHotTutorial"],
			["PREVIEW TEAM UNLOCK ANIMATION", "", "PreviewTeamUnlock"],
			["PREVIEW FELL JUST SHORT", "", "PreviewFellShort"]]
	for t in tools:
		var to: String = t[1]
		# (a tool with no screen plays over this one: the Scout garage door, a preview only)
		var act: Callable = (func(): Game.goto(to))
		if to == "":
			match String(t[2]):
				"PreviewHotTutorial": act = func(): HotTutorial.preview()
				"PreviewTeamUnlock": act = func(): TeamUnlock.preview()
				"PreviewFellShort": act = func(): _preview_fell_short()
				_: act = func(): ScoutReveal.preview()
		var b := UI.button(String(t[0]), act, "ghost", 0, 18)
		if to == "":
			b.tooltip_text = String(t[0])
		b.name = String(t[2])
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.clip_text = true
		g.add_child(b)
	(s[1] as VBoxContainer).add_child(g)
	return s[0]

## PREVIEW FELL JUST SHORT: the screen with a made-up conference loss and NCSA bid (the loaded
## dynasty's team when there is one); nothing read from or written to the career. Back comes here.
func _preview_fell_short() -> void:
	var lab = load("res://src/ui/screens/elim_lab.gd")
	Game.goto("fell_short", {"preview": true, "back": "dev_settings", "model": lab.short_sample(Game.career, "conf_semi")})

# ------------------------------------------------------------------ DANGER ZONE
func _danger() -> Control:
	var s := _section("DANGER ZONE", "warn", "ResetRow", RED, RED)
	var p: PanelContainer = s[0]
	p.add_theme_stylebox_override("panel", UI.chunky(Color("2a0d22"), RED, false, false, 6, 4))
	var v: VBoxContainer = s[1]
	var rb := Deck.button("RESET EVERYTHING", _confirm_reset, "danger", 0, 18)
	rb.name = "ResetGame"
	rb.add_theme_stylebox_override("normal", UI.chunky(Color("c0322f"), Color.WHITE))
	v.add_child(rb)
	var warn := para("Erases ALL saved progress (every career, Road to Glory unlocks) and restores the default settings. Two confirmations first; it can't be undone.", Color("ffb3b3"), 100)
	warn.name = "ResetWarning"
	v.add_child(warn)
	return p

## Two steps: what goes, then are you sure. Nothing is touched until the second yes.
func _confirm_reset() -> void:
	Game.dialog("RESET GAME?", "This puts Pixel Polo back the way it was when you installed it:\n\n- every career save is deleted\n- Road to Glory unlocks are lost\n- settings go back to their defaults\n- PIXEL POLO + and ALL 30 TEAMS are removed from the game\n- purchased Polo Points are removed\n- visual upgrades are removed\n\nPurchased Polo Points can't be restored. Paid unlocks come back only if you use RESTORE PURCHASES in the store.", [
		["CONTINUE", _confirm_reset_again, "danger"],
		["CANCEL", Callable(), "ghost"]])

func _confirm_reset_again() -> void:
	Game.dialog("ARE YOU SURE?", "All of it is gone for good. This can't be undone.", [
		["RESET EVERYTHING", _reset, "danger"],
		["CANCEL", Callable(), "ghost"]])

func _reset() -> void:
	Game.reset_everything()
	Game.toast("Pixel Polo has been reset", UI.GOLD)
	Game.goto("title", {}, false)

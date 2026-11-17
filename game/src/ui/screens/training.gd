extends BaseScreen
## This week's practice: one team focus and an intensity. Practice gives every player XP
## (Development: never attribute points; those come from the upgrade tokens XP earns), processed
## once when the week ends (Career.train_week), so nothing here can be repeated for more. Focus at
## the left, intensity at the right (inactive for RECOVERY, which ignores it), both panels running
## down the page to the one-line summary of the plan at the bottom. (The coaching staff panel is gone from here: the staff and
## Facilities themselves are unchanged; Facilities is still on the MORE menu.)

const W := 416                       # the content column; the rest of the page is blue
const PANEL_GAP := 7
const ROYAL := Color("1f52c9")       # the summary bar
## The two panels' share of the column: fixed, so neither moves whatever the picks' texts are
## (the descriptions wrap rather than widen their panel).
const FOCUS_RATIO := 240.0
const INTENSITY_RATIO := 169.0
const INTENSITY_FONT := 20           # the LIGHT / NORMAL / HARD words: the headline font at its own size
## What each choice does, in a line or two (Training's numbers are the truth).
const FOCUS_TEXT := {
	"balanced": "Standard XP for all players.",
	"shooting": "Extra XP for players with weaker Shooting.",
	"passing": "Extra XP for players with weaker Passing.",
	"swimming": "Extra XP for players with weaker Defense or goalie Lunge Speed.",
	"strength": "Extra XP for players with weaker Strength or goalie Leg Strength.",
	"defense": "Extra XP for players with weaker Defense or goalie Blocking.",
	"recovery": "Heals all injuries. No XP gained.",
}

## "75% XP • 1% Injury Risk", from Development's numbers.
static func intensity_text(lv: int) -> String:
	return "%d%% XP \u2022 %d%% Injury Risk" % [roundi(float(Development.XP_MULT[lv]) * 100.0),
		roundi(float(Development.INJURY_RISK[lv]) * 100.0)]

func _ready() -> void:
	back_target = "hub"
	build_compact("TRAINING")
	_render()

func _render() -> void:
	for ch in body.get_children():
		ch.queue_free()
	var focus: String = c.training.get("focus", "balanced")
	var inten := clampi(int(c.training.get("intensity", 2)), 1, 3)
	body.add_child(UI.spacer(0, 4))
	# the two panels: the content column's width, centred, as tall as the page allows
	var row := UI.hbox(0)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(row)
	row.add_child(UI.spacer(0, 0, true))
	var top := UI.hbox(PANEL_GAP)
	top.name = "Panels"
	top.custom_minimum_size = Vector2(W, 0)
	row.add_child(top)
	row.add_child(UI.spacer(0, 0, true))
	var recovery := focus == "recovery"
	top.add_child(_focus_panel(focus))
	top.add_child(_intensity_panel(inten, recovery))
	body.add_child(UI.spacer(0, PANEL_GAP))
	var summary := centered(_summary(Training.FOCI[focus].name, "-" if recovery else Training.INTENSITY[inten]))
	summary.name = "Summary"
	body.add_child(summary)
	body.add_child(UI.spacer(0, 4))
	if c.is_eliminated():
		# SEASON OVER (Championship Elimination): no game left to practise for. The plan is on show,
		# read only; nothing trains until next season (Career.train_week)
		top.modulate = Color(1, 1, 1, 0.45)
		for n in top.find_children("*", "BaseButton", true, false):
			(n as BaseButton).disabled = true
		var note := UI.label("SEASON OVER: NO PRACTICE SESSIONS UNTIL NEXT SEASON", 8, UI.WARN, "caps")
		note.name = "SeasonOverNote"
		note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		body.add_child(note)
		body.move_child(note, 0)

func _set_focus(key: String) -> void:
	if c.is_eliminated():
		return
	c.training.focus = key
	Game.save_career()
	_render()

func _set_intensity(lv: int) -> void:
	if c.is_eliminated():
		return
	c.training.intensity = lv
	Game.save_career()
	_render()

# ------------------------------------------------------------------ panels
## Seven focus buttons in two columns (RECOVERY alone, same width), then what the pick does.
func _focus_panel(focus: String) -> Control:
	var v := UI.vbox(3)
	var p := navy_panel(v)
	v.add_child(_heading("TRAINING FOCUS"))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 4)
	v.add_child(grid)
	for k in Training.FOCUS_ORDER:
		var key: String = k
		var on := key == focus
		# (a step lighter than the panel, so they stand up off it; the pick a warmer fill and gold)
		var b := flat_button(Training.FOCI[key].name, func(): _set_focus(key),
			Deck.NAVY_HEAD.lerp(UI.GOLD, 0.14) if on else Deck.NAVY_HEAD, UI.GOLD if on else UI.BORDER, UI.GOLD if on else UI.TEXT, 16)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(b)
	v.add_child(UI.spacer(0, 1, true))   # (the panel runs down the page: the pick's text at its foot)
	v.add_child(divider_line())
	v.add_child(_choice(Training.FOCI[focus].name, FOCUS_TEXT.get(focus, "")))
	p.size_flags_vertical = Control.SIZE_EXPAND_FILL
	p.size_flags_stretch_ratio = FOCUS_RATIO
	return p

## LIGHT / NORMAL / HARD (the pick filled yellow): three full-width rows, stacked, sharing the
## panel's height down to what the pick means, their words big enough to fill them. A RECOVERY week ignores
## intensity: the buttons are dimmed and can't be pressed.
func _intensity_panel(inten: int, recovery: bool = false) -> Control:
	var v := UI.vbox(3)
	var p := navy_panel(v)
	v.add_child(_heading("TRAINING INTENSITY"))
	var h := UI.vbox(5)
	h.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(h)
	for i in range(1, 4):
		var lv := i
		var on := lv == inten and not recovery
		var b := flat_button(Training.INTENSITY[lv], func(): _set_intensity(lv),
			UI.GOLD if on else Deck.NAVY_HEAD, UI.GOLD if on else UI.BORDER, UI.INK if on else UI.TEXT, 20)
		b.name = "Intensity_" + Training.INTENSITY[lv]
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.size_flags_vertical = Control.SIZE_EXPAND_FILL
		# (the headings' chunky font, on a hard 1 px drop shadow: the panel's navy, or a deep gold
		# under the pick's ink, so the words stand up off the bar)
		b.add_theme_font_override("font", UI.font_big)
		b.add_theme_font_size_override("font_size", INTENSITY_FONT)
		b.add_theme_color_override("font_shadow_color", UI.GOLD.darkened(0.35) if on else Deck.NAVY)
		b.add_theme_constant_override("shadow_offset_x", 1)
		b.add_theme_constant_override("shadow_offset_y", 1)
		if recovery:
			b.disabled = true
			b.add_theme_stylebox_override("disabled", UI.chunky(Deck.NAVY, UI.DIM2, false, false, 4, 1, UI.BEVEL_SUNK))
			b.add_theme_color_override("font_disabled_color", UI.DIM2)
		h.add_child(b)
	v.add_child(UI.spacer(0, 4))
	v.add_child(divider_line())
	if recovery:
		v.add_child(_choice("INACTIVE", "Recovery ignores intensity:\nno XP, no injury risk."))
	else:
		v.add_child(_choice(Training.INTENSITY[inten], intensity_text(inten)))
	p.size_flags_vertical = Control.SIZE_EXPAND_FILL
	p.size_flags_stretch_ratio = INTENSITY_RATIO
	return p

## CURRENT TRAINING: X | INTENSITY: Y
func _summary(focus_name: String, inten_name: String) -> Control:
	var parts := [["CURRENT TRAINING:", focus_name], ["INTENSITY:", inten_name]]
	var gap := 8.0
	var pad := 14.0
	var widths: Array = parts.map(func(pt): return Deck.text_w(pt[0]) + gap + Deck.text_w(pt[1]))
	var bw := ceilf(pad * 4.0 + widths[0] + widths[1] + 1.0)
	var bh := 19.0
	return UI.canvas(int(bw), int(bh), func(ci: Control):
		Deck.frame(ci, Rect2(0, 0, bw, bh), ROYAL, UI.BORDER)
		var x := pad
		for i in parts.size():
			if i > 0:
				ci.draw_rect(Rect2(floorf(x), 5, 1, bh - 10), UI.ACCENT)
				x += pad + 1.0
			Deck.text(ci, x, floorf(bh * 0.5), parts[i][0], 8, UI.ACCENT)
			Deck.text(ci, x + Deck.text_w(parts[i][0]) + gap, floorf(bh * 0.5), parts[i][1], 8, UI.TEXT)
			x += widths[i] + pad)

func _heading(t: String) -> Control:
	return big_text(t, UI.ACCENT)

## The pick's name in yellow and a line or two of what it does.
func _choice(title: String, text: String) -> Control:
	var v := UI.vbox(0)
	v.add_child(big_text(title, UI.GOLD))
	v.add_child(UI.spacer(0, 2))
	var l := UI.label(text, 8, UI.TEXT, "body")
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART   # (wraps in its panel, never widens it)
	v.add_child(l)
	return v

extends BaseScreen
## Developer Mode's ATTRIBUTE TEST LAB (Settings > Developer Mode > ATTRIBUTE TEST LAB): a made-up
## field player or goalkeeper whose four attributes and ceilings you move a point at a time
## (- / +), with his OVERALL, POTENTIAL and unified star bar worked out again at once, a form to
## preview (NORMAL, HOT, VERY HOT, the StarFx animation playing), and what each attribute does in
## the pool, measured with the game's own code (AttrBench) against an all-5 player:
##   field    PASSING his catch-and-shoot edge and the goals it makes; SHOOTING his release, their
##            wind-up, the keeper's reaction; STRENGTH the 2 m battle and the press; DEFENSE
##            interceptions, fouls forced, his switch round the centre
##   keeper   COMMUNICATION his teammates' effective Defense; LUNGE SPEED his reaction and dive;
##            BLOCKING how often a ball in his hands stays out; LEG STRENGTH his span and how
##            long he stays up; then his saves against AI shots and in a shootout
## Test values only: no career, save or real player changes.

const LEFT_W := 236
const BTN := 14
const BAR_W := 50
const NAME_W := 72
const READ_W := 214

var keeper := false
var vals := {}                  # attribute -> 0-10
var pots := {}                  # attribute -> its ceiling
var state := PlayerForm.NORMAL  # the form previewed
var lab: PoloPlayer             # the made-up player (AttrBench.player)
var lines: Array = []           # the read-out: [label, value, colour] (the attributes' part, measured once a change)
var controls: VBoxContainer
var readout: VBoxContainer
var stars: Control
var fx: StarFx

func _ready() -> void:
	build("ATTRIBUTE TEST LAB")
	var row := UI.hbox(6)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(row)
	controls = UI.vbox(2)
	controls.custom_minimum_size = Vector2(LEFT_W, 0)
	row.add_child(controls)
	readout = UI.vbox(0)
	readout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(navy_panel(readout))
	set_kind(false)

func on_back() -> void:
	Sfx.play("back")
	Game.back("settings")

## Field player or goalkeeper: every attribute back to 5, every ceiling to 8.
func set_kind(gk: bool) -> void:
	keeper = gk
	vals = {}
	pots = {}
	for k in (Attributes.KEEPER if gk else Attributes.FIELD):
		vals[k] = 5.0
		pots[k] = 8.0
	_changed()

## One attribute (`ceiling` false) or ceiling up or down a point. A ceiling never goes below its
## attribute and an attribute pushes its ceiling up with it (the rules every player has).
func nudge(key: String, by: float, ceiling: bool = false) -> void:
	if ceiling:
		pots[key] = clampf(float(pots[key]) + by, float(vals[key]), Attributes.MAX)
	else:
		vals[key] = clampf(float(vals[key]) + by, 0.0, Attributes.MAX)
		pots[key] = maxf(float(pots[key]), float(vals[key]))
	_changed()

func set_form(to: String) -> void:
	if to == state:
		return
	var was := state
	state = to
	if fx != null:
		fx.play(was, to, true)
	_controls()
	_fill_readout()

func _changed() -> void:
	lab = AttrBench.player(vals, keeper, pots, PoloPlayer.Pos.CENTER)
	measure()
	_controls()

# ------------------------------------------------------------------ the measurements
## What each attribute does, his against an all-5 player's, with the game's own code.
func measure() -> void:
	lines = []
	var avg := AttrBench.player({}, keeper, {}, PoloPlayer.Pos.CENTER)
	var pct := func(v: float) -> String: return "%d%%" % roundi(v * 100.0)
	if keeper:
		var shooter := AttrBench.player({})
		var mate := AttrBench.player({})
		var comm := Attributes.comm_bonus(lab)
		_head("COMMUNICATION", vals["com"])
		_line("TEAM DEFENSE", "%+.2f (EFFECTIVE)" % comm)
		_line("TEAMMATE STEALS", "%s  (5: %s)" % [pct.call(AttrBench.intercept(mate, lab)), pct.call(AttrBench.intercept(mate, avg))])
		_line("TEAMMATE FOULS", "x%.2f FORCED" % Attributes.foul_mult(Attributes.eff_defense(mate, comm), AttrBench.player({})))
		var dv := AttrBench.dive(lab)
		var dv5 := AttrBench.dive(avg)
		_head("LUNGE SPEED", vals["lun"])
		_line("REACTION (AI)", "%.3f S  (5: %.3f)" % [AttrBench.reaction(lab, shooter), AttrBench.reaction(avg, shooter)])
		_line("TO FULL STRETCH", "%.3f S  (5: %.3f)" % [dv.extend, dv5.extend])
		_head("BLOCKING", vals["blk"])
		_line("IN HIS HANDS", "%s  (5: %s)" % [pct.call(AttrBench.blocking(lab, 0.3, 300)), pct.call(AttrBench.blocking(avg, 0.3, 300))])
		_line("FINGERTIPS", "%s  (5: %s)" % [pct.call(AttrBench.blocking(lab, 0.95, 300)), pct.call(AttrBench.blocking(avg, 0.95, 300))])
		_head("LEG STRENGTH", vals["leg"])
		_line("SPAN", "%.2f M  (5: %.2f)" % [dv.span, dv5.span])
		_line("UP FOR", "%.2f S  (5: %.2f)" % [dv.window, dv5.window])
		_head("ALL FOUR", lab.rating10())
		_line("AI SHOTS SAVED", "%s  (5: %s)" % [pct.call(AttrBench.shots(shooter, null, lab).save), pct.call(AttrBench.shots(shooter, null, avg).save)])
		_line("SHOOTOUT SAVES", "%s  (5: %s)" % [pct.call(AttrBench.duel_saves(lab, shooter)), pct.call(AttrBench.duel_saves(avg, shooter))])
	else:
		var gk := AttrBench.player({}, true)
		var shooter := AttrBench.player({})
		var cs := 0.2   # caught and let go at once: a full catch and shoot
		_head("PASSING", vals["pas"])
		_line("C&S EDGE", "%+d%%" % roundi(Attributes.pass_mod(lab) * 100.0))
		_line("C&S GOALS", "%s  (5: %s)" % [pct.call(AttrBench.shots(shooter, lab, gk, cs).goal), pct.call(AttrBench.shots(shooter, avg, gk, cs).goal)])
		_head("SHOOTING", vals["sho"])
		_line("RELEASE", "x%.2f  WIND-UP %.2f S" % [Attributes.release_mult(lab), AttrBench.windup(lab)])
		_line("KEEPER REACTS", "%.3f S  (5: %.3f)" % [AttrBench.reaction(gk, lab), AttrBench.reaction(gk, avg)])
		_line("GOALS", "%s  (5: %s)" % [pct.call(AttrBench.shots(lab, null, gk).goal), pct.call(AttrBench.shots(avg, null, gk).goal)])
		var as_c := AttrBench.centre(lab, avg)
		var as_g := AttrBench.centre(avg, lab)
		var even := AttrBench.centre(avg, AttrBench.player({}))
		_head("STRENGTH", vals["str"])
		_line("AS CENTER: WINS", "%.1f S  (5: %.1f)" % [as_c.win, even.win])
		_line("AS GUARD: HOLDS", "%.1f S, SEAL x%.2f" % [as_g.win, as_g.seal])
		_line("PRESSED: FOULED", "%.2f /S  (5: %.2f)" % [AttrBench.foul_rate(avg, lab), AttrBench.foul_rate(avg, avg)])
		_head("DEFENSE", vals["dfn"])
		_line("PASS THROUGH HIM", "%s PICKED  (5: %s)" % [pct.call(AttrBench.intercept(lab)), pct.call(AttrBench.intercept(avg))])
		_line("PRESSING: FOULS", "%.2f /S  (5: %.2f)" % [AttrBench.foul_rate(lab, avg), AttrBench.foul_rate(avg, avg)])
		_line("SWITCH WAIT", "%.2f S  (5: %.2f)" % [as_g.switch, even.switch])
	_fill_readout()

## The previewed form's lines (what HOT does to him): EFFECTIVE stars, and in a game his four
## attributes' Hot bonus (and the 0-100 ratings it moves); his saved attributes and ceilings never.
func _form_lines() -> Array:
	var form := float(PlayerForm.FORM_STARS[state])
	return [["FORM: " + String(PlayerForm.FORM_NAMES[state]), "", UI.GOLD],
		["EFFECTIVE STARS", "%s  (%+.1f)" % [PlayerForm.star_text(PlayerForm.effective(lab.stars, state)), form], UI.TEXT],
		["IN A GAME", "ATTRIBUTES %+.1f, RATINGS %+d" % [Attributes.HOT_PER_STAR * PlayerForm.level_of(state),
			roundi(Attributes.HOT_PER_STAR * PlayerForm.level_of(state) * Attributes.HOT_RATING_PER_POINT)], UI.TEXT]]

func _head(name: String, v: float) -> void:
	lines.append([name if v < 0.0 else "%s %s" % [name, Attributes.text(v)], "", UI.GOLD])

func _line(label: String, value: String) -> void:
	lines.append([label, value, UI.TEXT])

func _fill_readout() -> void:
	for ch in readout.get_children():
		ch.queue_free()
	for l in lines + _form_lines():
		var h := UI.hbox(0)
		readout.add_child(h)
		var a := UI.label(String(l[0]), 8, l[2] if String(l[1]) == "" else UI.ACCENT, "body")
		a.custom_minimum_size = Vector2(84, 0)
		a.clip_text = true
		h.add_child(a)
		if String(l[1]) != "":
			var b := UI.label(String(l[1]), 8, l[2], "body")
			b.clip_text = true
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			h.add_child(b)

# ------------------------------------------------------------------ the controls
func _controls() -> void:
	for ch in controls.get_children():
		ch.queue_free()
	var kind := UI.hbox(3)
	controls.add_child(kind)
	var kl := UI.label("PLAYER", 8, UI.ACCENT, "caps")
	kl.custom_minimum_size = Vector2(NAME_W, 0)
	kind.add_child(kl)
	kind.add_child(UI.button("FIELD", func(): set_kind(false), "tab" if keeper else "tab_on", 44, 16))
	kind.add_child(UI.button("GOALKEEPER", func(): set_kind(true), "tab_on" if keeper else "tab", 64, 16))
	for k in (Attributes.KEEPER if keeper else Attributes.FIELD):
		var key: String = k
		var r := UI.hbox(2)
		controls.add_child(r)
		var nl := UI.label(String(Attributes.NAMES[key]).to_upper(), 8, UI.TEXT, "caps")
		nl.custom_minimum_size = Vector2(NAME_W, 0)
		nl.clip_text = true
		r.add_child(nl)
		r.add_child(UI.button("-", func(): nudge(key, -1.0), "tab", BTN, BTN))
		r.add_child(UI.button("+", func(): nudge(key, 1.0), "tab", BTN, BTN))
		var v0 := float(vals[key])
		var p0 := float(pots[key])
		var bar := UI.canvas(BAR_W + 44, 12, func(ci: Control):
			Deck.attr_bar(ci, Rect2(0, 1, BAR_W, 10), v0 / Attributes.MAX, p0 / Attributes.MAX)
			Deck.text(ci, BAR_W + 3, 6, "%.0f / %.0f" % [v0, p0], 8, UI.TEXT))
		r.add_child(bar)
		r.add_child(UI.button("-", func(): nudge(key, -1.0, true), "ghost", BTN, BTN))
		r.add_child(UI.button("+", func(): nudge(key, 1.0, true), "ghost", BTN, BTN))
	controls.add_child(UI.label("ROW: ATTRIBUTE - +, BAR, THEN ITS CEILING - +", 8, UI.DIM, "body"))
	stars = UI.canvas(0, 36, _draw_stars)
	if fx == null or not is_instance_valid(fx):
		fx = StarFx.new()
		fx.force = true
	elif fx.get_parent() != null:
		fx.get_parent().remove_child(fx)
	fx.host = stars
	stars.add_child(fx)
	controls.add_child(stars)
	var fr := UI.hbox(2)
	controls.add_child(fr)
	for s in StarFx.LADDER:
		var st: String = s
		var word := String(PlayerForm.FORM_NAMES[st])
		fr.add_child(UI.button(word, func(): set_form(st), "tab_on" if st == state else "tab", 44, 16))

## OVERALL and POTENTIAL (the averages), the unified star bar with the previewed form, EFFECTIVE.
func _draw_stars(ci: Control) -> void:
	Deck.text(ci, 0, 5, "OVERALL", 8, UI.ACCENT)
	Deck.text(ci, 42, 5, Attributes.text(lab.rating10()), 8, UI.TEXT)
	Deck.text(ci, 90, 5, "POTENTIAL", 8, UI.ACCENT)
	Deck.text(ci, 142, 5, Attributes.text(lab.potential10()), 8, Color("45dfff"))
	fx.draw(ci, 0, 13, lab.stars, lab.pot_stars, state, Color(1, 1, 1, 0.14), Deck.STAR_SHAPE)
	var x := Deck.star_bar_w(Deck.STAR_SHAPE) + 6.0
	Deck.text(ci, x, 17, "%s / %s STARS" % [PlayerForm.star_text(lab.stars), PlayerForm.star_text(lab.pot_stars)], 8, UI.TEXT)
	Deck.text(ci, 0, 30, "EFFECTIVE %s" % PlayerForm.star_text(PlayerForm.effective(lab.stars, state)), 8, PlayerForm.form_color(state))

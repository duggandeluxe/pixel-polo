extends BaseScreen
## Developer Mode's DEV RECRUITS (Settings > Developer Tools): the two DEV Recruits (DevRecruits).
##
## THE OVERVIEW: BLAKE DUGGAN and LOGAN BAUMANN to pick from, then both side by side, each on the real
## market card (Recruiting's paint_recruit, light blue: DevArt) beside his details: hometown,
## position, his four as the real boxes with the corrupted bar past 10 ("2 → 6", "15/10 — MAXED"),
## his 200 PP recruiting cost and his generation status in the loaded dynasty.
##   FORCE SPAWN BLAKE / LOGAN  him onto the loaded career's market in an ordinary prospect's place,
##                              no roll and free (DevRecruits.force_spawn); signing him still
##                              costs 200 PP. Never a second copy: a clear message instead
##   RESET DEV RECRUIT TEST STATE  after a confirmation, only what force-spawning left
##                              (DevRecruits.reset_test_state): never a signed player, never
##                              history, never the rest of the market
## Nothing here rolls the natural 1 in 1,000 or changes its odds.
##
## INSPECTING ONE (pick a name or tap his card), at any time whatever he is in the dynasty:
##   ROSTER PREVIEW   his card as the Roster screen paints it (roster.gd's own paint_card: a
##                    starter's and a substitute's, actual size, and a 2x pixel zoom) and his market
##                    card; VIEW IN ROSTER: the real Roster screen, read only, on a copy of your team
##                    with him in it (dev_roster)
##   PLAYER PROFILE   his details and current and potential stars here, and OPEN FULL PROFILE: the
##                    real player page in its DEV PREVIEW (player.gd)
##   IN-GAME EFFECTS  each boosted attribute against an ordinary elite 10, the same man with only that
##                    attribute changed, measured with the game's own code (DevImpact): CALC rows are
##                    deterministic engine values, SIM rows a seeded sample's observed share; any
##                    engine bound that holds the boosted value back, and whether every probability
##                    stayed valid
##   TEST IN GAME     a real possession with him in it (dev_test_lab), COMPARE TO 10/10 and seeded trials
## Every preview is a fresh copy (DevRecruits.make): no career, save, player, XP or stats change.

const COL_W := 236
const CARD := Vector2(112, 88)
const ROW_H := 16
## The pixel arrow between an attribute and its ceiling (the caps font has no arrow).
const ARROW := ["..#..", "...#.", "#####", "...#.", "..#.."]
const TABS := ["ROSTER PREVIEW", "PLAYER PROFILE", "IN-GAME EFFECTS"]

var status: Label
var log_box: VBoxContainer
## What's on show, kept while you visit his profile, the roster preview or the test and come back.
static var pick := ""                 # the DEV Recruit inspected ("": the overview)
static var tab := "ROSTER PREVIEW"
static var cmp_id := "logan_sho"      # the comparison picked (DevImpact.COMPARISONS)
static var result := {}               # its last run (DevImpact.run), {} none yet
var running := false
var auto_run := true          # IN-GAME EFFECTS measures as soon as it opens (tests turn it off)

## {keep: true} (back from his profile, VIEW IN ROSTER or TEST IN GAME): as it was; otherwise
## (from Settings) the overview. {pick: key} opens straight on him.
func setup(params: Dictionary) -> void:
	if not bool(params.get("keep", false)):
		pick = ""
	if params.has("pick"):
		inspect_key(String(params.pick))
	if params.has("tab") and String(params.tab) in TABS:
		tab = String(params.tab)

func _ready() -> void:
	build("DEV RECRUITS")
	_render()

func on_back() -> void:
	Sfx.play("back")
	if pick != "":
		pick = ""
		_render()
		return
	Game.goto("dev_settings", {}, false)

## Inspect `key` ("": back to the overview).
func inspect(key: String) -> void:
	inspect_key(key)
	_render()

static func inspect_key(key: String) -> void:
	pick = key if DevRecruits.DEFS.has(key) else ""
	if pick != "" and String(DevImpact.find(cmp_id).get("key", "")) != pick:
		cmp_id = String(_comparisons(pick)[0].id)

func _render() -> void:
	for ch in body.get_children():
		body.remove_child(ch)
		ch.queue_free()
	body.add_theme_constant_override("separation", 4)
	title_label.text = "DEV RECRUITS" if pick == "" else "DEV RECRUIT  %s" % DevRecruits.full_name(pick)
	if pick != "":
		_render_inspect()
		return
	var picks := UI.hbox(4)
	picks.name = "Picks"
	picks.alignment = BoxContainer.ALIGNMENT_CENTER
	body.add_child(picks)
	var lead := UI.label("INSPECT:", 8, UI.DIM, "caps")
	lead.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	picks.add_child(lead)
	for key in DevRecruits.ORDER:
		var k: String = key
		var b := UI.button(DevRecruits.full_name(k), func():
			Sfx.play("click")
			inspect(k), "primary", 0, 18)
		b.name = "Pick_" + k
		b.tooltip_text = "Roster preview, player profile, in-game effects and TEST IN GAME"
		picks.add_child(b)
	var cols := UI.hbox(6)
	cols.name = "Recruits"
	cols.alignment = BoxContainer.ALIGNMENT_CENTER
	body.add_child(cols)
	for key in DevRecruits.ORDER:
		cols.add_child(_column(key))
	var row := UI.hbox(4)
	row.name = "Controls"
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	body.add_child(row)
	for key in DevRecruits.ORDER:
		var k: String = key
		var b := UI.button("FORCE SPAWN %s" % String(DevRecruits.DEFS[k].first).to_upper(), func(): _force(k), "primary", 0, 18)
		b.name = "Force_" + k
		b.disabled = Game.career == null
		b.tooltip_text = "Load a career first." if Game.career == null else ("Already generated in this dynasty: never again." if DevRecruits.generated(Game.career, k) else "Put him on the current Recruiting Market (free). Signing him costs %d PP." % DevRecruits.PRICE)
		row.add_child(b)
	var rb := UI.button("RESET DEV RECRUIT TEST STATE", _ask_reset, "danger", 0, 18)
	rb.name = "ResetTest"
	rb.disabled = Game.career == null
	row.add_child(rb)
	status = UI.label(_status_text(), 8, UI.ACCENT, "caps")
	status.name = "Status"
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(status)
	log_box = UI.vbox(1)
	log_box.name = "Log"
	body.add_child(log_box)

## One DEV Recruit: his card (tap: the profile preview) and his details, on the light-blue panel.
func _column(key: String) -> Control:
	var p := DevRecruits.make(key)   # (a copy for the look of it: nobody's, never saved)
	var panel := PanelContainer.new()
	panel.name = "Dev_" + key
	panel.add_theme_stylebox_override("panel", DevArt.stylebox(3))
	panel.custom_minimum_size = Vector2(COL_W, 0)
	var h := UI.hbox(3)
	panel.add_child(h)
	var team := Game.career.team() if Game.career != null else _plain_team()
	var RecruitingScreen := load("res://src/ui/screens/recruiting.gd")
	var card := Deck.card(CARD, func(ci, _r, mode):
		RecruitingScreen.paint_recruit(ci, CARD, p, team, mode, false, false, false, false, DevRecruits.PRICE), func():
		_card_tapped(key))
	card.name = "Card_" + key
	card.tooltip_text = ("Inspect %s" if pick == "" else "Open %s's full profile (preview)") % DevRecruits.full_name(key)
	card.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	card.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	h.add_child(card)
	var v := UI.vbox(1)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(v)
	v.add_child(_line(DevRecruits.full_name(key), DevArt.INK, 16, "big"))
	v.add_child(_line(Hometowns.shown(p.home).to_upper(), DevArt.INK_SOFT))
	v.add_child(_line(DevRecruits.role(p).to_upper(), DevArt.INK))
	for k in p.key_ratings():
		v.add_child(_attr_row(p, k))
	var cost := UI.canvas(0, 12, func(ci: Control):
		Deck.text(ci, 0, 6, "RECRUITING COST", 8, DevArt.INK)
		CreditCoin.draw_amount(ci, ci.size.x, 6, str(DevRecruits.PRICE), 8, DevArt.INK, "caps", 12, 2))
	cost.name = "Cost"
	cost.set_meta("price", DevRecruits.PRICE)
	v.add_child(cost)
	# his generation status in the loaded dynasty (DevRecruits.status): NOT GENERATED, AVAILABLE —
	# UNSIGNED, SIGNED — SCHOOL, NO LONGER ACTIVE
	var st := DevRecruits.status(Game.career, key) if Game.career != null else "NO CAREER LOADED"
	var sl := _line(st, DevArt.ELECTRIC if st.begins_with("SIGNED") or st.begins_with("AVAILABLE") else DevArt.INK_SOFT)
	sl.name = "Status_" + key
	v.add_child(sl)
	return panel

func _line(text: String, col: Color, size: int = 8, font: String = "caps") -> Control:
	var cv := UI.canvas(0, 12 if size >= 16 else 9, func(ci: Control):
		var f := font if size >= 16 or Deck.text_w(text, size, font) <= ci.size.x else "body"
		Deck.text(ci, 0, ci.size.y * 0.5, Deck.fit(text, ci.size.x, size, f), size, col, f))
	cv.set_meta("text", text)
	return cv

## "SHOOTING  2 → 6" / "STRENGTH  15/10 — MAXED", the real boxes under it (and the corrupted bar).
static func attr_text(p: PoloPlayer, key: String) -> String:
	var v := p.attr(key)
	var top := Attributes.ceiling(p, key)
	if top - v < Attributes.PRECISION:
		return "%s/10 — MAXED" % _num(v) if Attributes.over_max(v) else "%s — MAXED" % _num(v)
	return "%s → %s" % [_num(v), _num(top)]

## `s` right-aligned to `x_right`, its "→" drawn as the pixel ARROW.
static func draw_attr_text(ci: CanvasItem, x_right: float, y_mid: float, s: String, col: Color, font: String = "caps") -> void:
	var parts := s.split(" → ")
	if parts.size() != 2:
		Deck.rtext(ci, x_right, y_mid, s, 8, col, font)
		return
	var gap := 3.0
	var w := Deck.text_w(parts[0], 8, font) + gap + ARROW[0].length() + gap + Deck.text_w(parts[1], 8, font)
	var x := x_right - w
	Deck.text(ci, x, y_mid, parts[0], 8, col, font)
	x += Deck.text_w(parts[0], 8, font) + gap
	Deck.pat(ci, Vector2(x, roundf(y_mid - 2.5)), ARROW, {"#": col})
	Deck.text(ci, x + ARROW[0].length() + gap, y_mid, parts[1], 8, col, font)

static func _num(v: float) -> String:
	return str(roundi(v)) if is_equal_approx(v, roundf(v)) else Attributes.text(v)

func _attr_row(p: PoloPlayer, key: String) -> Control:
	var txt := attr_text(p, key)
	var cv := UI.canvas(0, ROW_H, func(ci: Control):
		var w := ci.size.x
		var nm := String(Attributes.NAMES[key]).to_upper()
		var tight := Deck.text_w(nm) + 4.0 + Deck.text_w(txt) > w
		Deck.text(ci, 0, 3.5, nm, 8, DevArt.INK, "body" if tight else "caps")
		draw_attr_text(ci, w, 3.5, txt, DevArt.ELECTRIC if Attributes.over_max(p.attr(key)) else DevArt.INK, "body" if tight else "caps")
		var r := Rect2(0, 8, w, 7)
		ci.draw_rect(r.grow(1), DevArt.LABEL_BG)
		Deck.attr_boxes(ci, r, p.attr(key), Attributes.ceiling(p, key))
		DevArt.overcharge(ci, r, p.attr(key), Time.get_ticks_msec() / 1000.0))
	cv.name = "Attr_" + key
	cv.set_meta("text", "%s: %s" % [String(Attributes.NAMES[key]).to_upper(), txt])
	if DevArt.animates(p.attr(key)):
		cv.set_process(true)
		var tick := Timer.new()
		tick.wait_time = 1.0 / DevArt.GLITCH_HZ
		tick.autostart = true
		tick.timeout.connect(cv.queue_redraw)
		cv.add_child(tick)
	return cv

static func _plain_team() -> PoloTeam:
	var t := PoloTeam.new()
	t.c1 = Color("1d3f9a")
	t.c2 = Color.WHITE
	return t

# ------------------------------------------------------------------ the controls
func _status_text() -> String:
	var c := Game.career
	if c == null:
		return "NO CAREER LOADED: PREVIEW ONLY. LOAD A CAREER TO FORCE SPAWN."
	return "   ".join(DevRecruits.ORDER.map(func(key): return "%s: %s" % [String(DevRecruits.DEFS[key].last).to_upper(), DevRecruits.status(c, key)]))

func _note(text: String, col: Color = UI.TEXT) -> void:
	var l := UI.label(text, 8, col, "caps")
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(440, 0)
	log_box.add_child(l)
	while log_box.get_child_count() > 4:
		var old := log_box.get_child(0)
		log_box.remove_child(old)
		old.queue_free()

func _force(key: String) -> void:
	var err := DevRecruits.force_spawn(Game.career, key)
	if err != "":
		Sfx.play("error")
		Game.dialog("CAN'T SPAWN %s" % DevRecruits.full_name(key), err, [["OK", Callable(), "primary"]])
		_note(err, UI.WARN)
		return
	Sfx.play("card")
	Game.save_career()
	Game.toast("%s IS ON THE RECRUITING MARKET" % DevRecruits.full_name(key), UI.GOLD)
	_render()
	_note("%s force-spawned onto the market (free). Signing him costs %d PP. He is now generated in this dynasty for good." % [DevRecruits.full_name(key), DevRecruits.PRICE], UI.GOOD)

func _ask_reset() -> void:
	Game.dialog("RESET DEV RECRUIT TEST STATE?", "Removes force-spawned DEV Recruits who are still unsigned on the market (the recruits they replaced come back).\n\nGeneration is permanent: a removed DEV Recruit is never generated again in this dynasty. Signed players, natural spawns, dynasty history and the rest of the market are never touched.", [
		["RESET", _reset, "danger"],
		["CANCEL", Callable(), "ghost"]])

func _reset() -> void:
	var lines := DevRecruits.reset_test_state(Game.career)
	Game.save_career()
	Sfx.play("click")
	_render()
	for l in lines:
		_note(String(l), UI.ACCENT)

func _card_tapped(key: String) -> void:
	Sfx.play("click")
	if pick == "":
		inspect(key)
	else:
		Game.goto("player", {"dev_preview": key})

# ------------------------------------------------------------------ inspecting one
func _render_inspect() -> void:
	var head := UI.hbox(3)
	head.name = "InspectHead"
	head.alignment = BoxContainer.ALIGNMENT_CENTER
	body.add_child(head)
	var all := UI.button("ALL DEV RECRUITS", func():
		Sfx.play("back")
		inspect(""), "ghost", 0, 18)
	all.name = "AllRecruits"
	head.add_child(all)
	for t in TABS:
		var tt: String = t
		var b := UI.button(tt, func():
			if tt != tab:
				Sfx.play("click")
				tab = tt
				_render(), "tab_on" if tt == tab else "tab", 0, 18)
		b.name = "Tab_" + tt.replace(" ", "_").replace("-", "_")
		head.add_child(b)
	var test := UI.button("TEST IN GAME", test_in_game, "primary", 0, 18)
	test.name = "TestInGame"
	test.tooltip_text = "A real possession with him in it: nothing counted or saved"
	head.add_child(test)
	match tab:
		"PLAYER PROFILE":
			_render_profile()
		"IN-GAME EFFECTS":
			_render_impact()
		_:
			_render_roster()

func test_in_game() -> void:
	Sfx.play("click")
	Game.goto("dev_test_lab", {"key": pick})

## A small caption over a preview.
func _cap(text: String, col: Color = UI.ACCENT) -> Control:
	var l := _line(text, col)
	l.custom_minimum_size.x = 100
	return l

# ------------------------------------------------------------------ ROSTER PREVIEW
const RosterPreview := preload("res://src/ui/screens/dev_roster.gd")

## His card exactly as the Roster screen paints it (roster.gd's paint_card, its CARD size), with
## the team's colours and a cap number from a copy of your team (dev_roster.make_preview).
func roster_card(bench: bool, zoom: float = 1.0) -> Control:
	var RosterScreen := load("res://src/ui/screens/roster.gd")
	var made := RosterPreview.make_preview(Game.career, pick)
	var p: PoloPlayer = made.p
	var team: PoloTeam = made.team
	var size: Vector2 = RosterScreen.CARD
	var fx := StarFx.new()
	var cv := UI.canvas(int(size.x), int(size.y), func(ci: Control):
		RosterScreen.paint_card(ci, p, team, fx, PlayerForm.NORMAL, UI.TEXT, bench, false, true, false))
	cv.add_child(fx)
	cv.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	cv.set_meta("player", p)
	if zoom == 1.0:
		cv.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		return cv
	var holder := Control.new()
	holder.custom_minimum_size = size * zoom
	holder.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	cv.scale = Vector2(zoom, zoom)
	holder.add_child(cv)
	return holder

func _render_roster() -> void:
	var h := UI.hbox(10)
	h.name = "RosterPreview"
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	body.add_child(h)
	var a := UI.vbox(2)
	a.add_child(_cap("STARTER (ACTUAL SIZE)"))
	var c1 := roster_card(false)
	c1.name = "RosterCard"
	a.add_child(c1)
	a.add_child(_cap("ON THE BENCH"))
	var c2 := roster_card(true)
	c2.name = "RosterCardBench"
	a.add_child(c2)
	h.add_child(a)
	var b := UI.vbox(2)
	b.add_child(_cap("2X PIXEL ZOOM"))
	var z := roster_card(false, 2.0)
	z.name = "RosterCardZoom"
	b.add_child(z)
	h.add_child(b)
	var m := UI.vbox(2)
	m.add_child(_cap("RECRUITING CARD"))
	var p := DevRecruits.make(pick)
	var team := Game.career.team() if Game.career != null else _plain_team()
	var RecruitingScreen := load("res://src/ui/screens/recruiting.gd")
	var mk := Deck.card(CARD, func(ci, _r, mode):
		RecruitingScreen.paint_recruit(ci, CARD, p, team, mode, false, false, false, false, DevRecruits.PRICE), func(): pass)
	mk.name = "MarketCard"
	mk.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mk.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	m.add_child(mk)
	var vr := UI.button("VIEW IN ROSTER", func():
		Sfx.play("click")
		Game.goto("dev_roster", {"key": pick}), "primary", 0, 18)
	vr.name = "ViewInRoster"
	vr.tooltip_text = "The real Roster screen, read only, on a copy of your team"
	m.add_child(vr)
	h.add_child(m)
	var note := para("The real roster renderer (roster.gd paint_card) on a copy of him: nothing is added to your roster. VIEW IN ROSTER puts him in a read-only copy of your team, beside ordinary players.", UI.DIM, 440)
	note.name = "RosterNote"
	body.add_child(note)

# ------------------------------------------------------------------ PLAYER PROFILE
func _render_profile() -> void:
	var h := UI.hbox(8)
	h.name = "Profile"
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	body.add_child(h)
	h.add_child(_column(pick))
	var p := DevRecruits.make(pick)
	var v := UI.vbox(3)
	v.custom_minimum_size.x = 170
	h.add_child(v)
	v.add_child(_star_row("CURRENT", p.stars, "StarsCurrent"))
	v.add_child(_star_row("POTENTIAL", p.pot_stars, "StarsPotential"))
	var full := UI.button("OPEN FULL PROFILE", func():
		Sfx.play("click")
		Game.goto("player", {"dev_preview": pick}), "primary", 0, 18)
	full.name = "OpenProfile"
	full.tooltip_text = "The real player page (DEV PREVIEW): nothing to sign"
	v.add_child(full)
	v.add_child(para("The real player page in its DEV PREVIEW: his portrait, the icy-blue card, DEV RECRUIT, every attribute out of 10 (14/10, 15/10, never clamped) with the corrupted bar past 10, current and potential stars.", UI.DIM, 170))

func _star_row(label: String, stars: float, nm: String) -> Control:
	var fx := StarFx.new()
	fx.bare = true
	var cv := UI.canvas(0, 20, func(ci: Control):
		Deck.text(ci, 0, 4, label, 8, UI.ACCENT)
		fx.draw(ci, 0, 9, stars, stars, PlayerForm.NORMAL, Color(1, 1, 1, 0.14), Deck.STAR_SHAPE))
	cv.add_child(fx)
	cv.name = nm
	cv.set_meta("stars", stars)
	return cv

# ------------------------------------------------------------------ IN-GAME EFFECTS
const COL := [168, 62, 62, 104, 34]   # METRIC, 10/10, DEV, DIFFERENCE, CALC/SIM
const ROW := 10

static func _comparisons(key: String) -> Array:
	return DevImpact.COMPARISONS.filter(func(x): return String(x.key) == key)

func _render_impact() -> void:
	var row := UI.hbox(3)
	row.name = "Comparisons"
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	body.add_child(row)
	for cmp in _comparisons(pick):
		var id := String(cmp.id)
		var a := String(cmp.attr)
		var b := UI.button("%s: 10 VS %d" % [String(Attributes.NAMES[a]).to_upper(), roundi(DevImpact.dev_value(pick, a))],
			func():
				if id != cmp_id:
					Sfx.play("click")
					cmp_id = id
					_render(), "tab_on" if id == cmp_id else "tab", 0, 18)
		b.name = "Cmp_" + id
		row.add_child(b)
	var run := UI.button("RUNNING..." if running else "RUN COMPARISON", _run_comparison, "primary", 0, 18)
	run.name = "RunComparison"
	run.disabled = running
	run.tooltip_text = "Evaluate the ordinary 10 and the DEV value with the game's own code. Changes nothing in the dynasty."
	row.add_child(run)
	var v := UI.vbox(1)
	v.name = "Impact"
	var sc := UI.scroll(v)
	sc.name = "ImpactScroll"
	var panel := navy_panel(sc)
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(panel)
	var cmp := DevImpact.find(cmp_id)
	var key := String(cmp.key)
	var attr := String(cmp.attr)
	v.add_child(_line("%s — %s" % [DevRecruits.full_name(key), String(Attributes.NAMES[attr]).to_upper()], UI.TEXT, 16, "big"))
	var vs := UI.canvas(0, 9, func(ci: Control):
		var x := Deck.text_w("NORMAL ELITE PLAYER: 10/10", 8, "caps")
		Deck.text(ci, 0, 4.5, "NORMAL ELITE PLAYER: 10/10", 8, UI.ACCENT)
		Deck.text(ci, x + 12.0, 4.5, "DEV RECRUIT: %d/10" % roundi(DevImpact.dev_value(key, attr)), 8, DevArt.ELECTRIC))
	vs.name = "Versus"
	v.add_child(vs)
	if result.is_empty() or String(result.get("id", "")) != cmp_id:
		var hint := para("Measuring: the same %s twice, once at 10 and once at %d, every other condition identical, by the real game engine..." % [
			DevRecruits.full_name(key), roundi(DevImpact.dev_value(key, attr))], UI.DIM, 440)
		hint.name = "Hint"
		v.add_child(hint)
		if not running and auto_run:
			_run_comparison.call_deferred()
		return
	v.add_child(_table_row(["METRIC", "10/10", "%d/10" % roundi(float(result.dev_v)), "DIFFERENCE", "TYPE"], [UI.DIM, UI.DIM, UI.DIM, UI.DIM, UI.DIM], true))
	for r in result.rows:
		var e := DevImpact.edge_sign(r)
		var dcol := UI.GOOD if e > 0 else (UI.WARN if e < 0 else UI.DIM)
		var kind := String(r.kind) + ((" %d" % int(r.n)) if r.has("n") else "")
		var tr := _table_row([String(r.label), DevImpact.fmt(float(r.base), String(r.fmt)), DevImpact.fmt(float(r.dev), String(r.fmt)), DevImpact.diff_text(r), kind],
			[UI.TEXT, UI.ACCENT, DevArt.ELECTRIC, dcol, UI.DIM])
		tr.tooltip_text = "%s  (%s)" % [String(r.label), String(r.src)]
		v.add_child(tr)
	v.add_child(_gap())
	var ok := bool(result.valid)
	var vl := _line("PROBABILITIES: %s" % ("ALL WITHIN 0-100%, NONE CERTAIN" if ok else "OUT OF RANGE — CHECK THE ENGINE"), UI.GOOD if ok else UI.WARN)
	vl.name = "Validity"
	v.add_child(vl)
	v.add_child(para("CALC = a deterministic engine value. SIM n = the observed share of a seeded sample of n (the same seed and dice for both players).", UI.DIM, 440))
	if not (result.notes as Array).is_empty():
		v.add_child(_line("ENGINE BOUNDS", UI.GOLD))
		for n in result.notes:
			v.add_child(para(String(n), UI.GOLD, 440))
	v.add_child(_line("CONDITIONS", UI.ACCENT))
	for t in result.conditions:
		v.add_child(para(String(t), UI.DIM, 440))
	v.add_child(para("Test players only: no career, save, player, XP, stats or recruiting status changes.", UI.DIM, 440))

func _gap() -> Control:
	return UI.canvas(0, 3, func(_ci): pass)

## One line of the comparison table, its cells in COL's widths (the last fills what's left).
func _table_row(cells: Array, cols: Array, head: bool = false) -> Control:
	var cv := UI.canvas(0, ROW, func(ci: Control):
		var x := 0.0
		for i in cells.size():
			var w: float = float(COL[i]) if i < COL.size() - 1 else maxf(20.0, ci.size.x - x)
			var t := String(cells[i])
			var f := "caps" if Deck.text_w(t, 8, "caps") <= w - 4.0 else "body"
			Deck.text(ci, x, ROW * 0.5, Deck.fit(t, w - 4.0, 8, f), 8, cols[i], f)
			x += w
		if head:
			ci.draw_rect(Rect2(0, ROW - 1, ci.size.x, 1), Color(1, 1, 1, 0.18)))
	cv.name = "Row_" + String(cells[0]).replace(" ", "_")
	cv.set_meta("cells", cells)
	cv.mouse_filter = Control.MOUSE_FILTER_PASS
	return cv

## RUN COMPARISON: the picked one, on test players (DevImpact.run), shown when it's done.
func _run_comparison() -> void:
	if running:
		return
	running = true
	Sfx.play("click")
	_render()
	await get_tree().process_frame
	await get_tree().process_frame
	result = DevImpact.run(cmp_id)
	running = false
	if is_inside_tree():
		_render()

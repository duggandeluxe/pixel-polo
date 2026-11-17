extends BaseScreen
## Developer Mode's WALK-ON TESTING (Settings > Developer Tools): the Automatic Walk-On update on
## demand, without playing a season out.
##   PREVIEW POPUP     WELCOMING ALL WALK-ONS! (WalkOnShow.play_preview) over this screen with a
##                     class of CLASS SIZE sample walk-ons (- / +, 1 to the roster's places)
##   EXAMPLES          one walk-on at each rating (0.5 to 2.5 stars) and a keeper, made by the real
##                     generator (WalkOns.make): portrait, position, class year, hometown, stars and
##                     his four attributes (each ceiling the attribute: no potential). REROLL makes
##                     a new set
##   THE ODDS          1,000 rolls of WalkOns.roll_stars and of the class year, beside their targets
## Read only: the samples are plain data made here (never on a roster, never saved) in the loaded
## dynasty's caps, or a plain blue team's with none. Developer Mode off: back to Settings.

const EX_STARS := [0.5, 1.0, 1.5, 2.0, 2.5]
const CARD := Vector2(150, 84)
const ROLLS := 1000

var rng := RandomNumberGenerator.new()
var size_n := 4
var examples: Array = []
var odds := {}
var years := {}
var sample_team: PoloTeam
var size_l: Label
var list: VBoxContainer

func _ready() -> void:
	back_target = "dev_settings"
	if not bool(Game.settings.get("dev_mode", false)):
		Game.goto.call_deferred("settings", {}, false)
		return
	build("WALK-ON TESTING")
	sample_team = c.team() if c != null else _plain_team()
	rng.randomize()
	list = UI.vbox(4)
	body.add_child(UI.scroll(list))
	_reroll()

static func _plain_team() -> PoloTeam:
	var t := PoloTeam.new()
	t.c1 = Color("1d3f9a")
	t.c2 = Color.WHITE
	return t

func _cap() -> int:
	return c.roster_cap(c.school) if c != null else Career.ROSTER_MAX + Career.BENCH_MAX

## A new set of examples and a new 1,000 rolls; the page again.
func _reroll() -> void:
	examples = []
	var used := {}
	var n := 0
	for s in EX_STARS:
		examples.append(_sample(CollegeGen.field_pos(rng), s, used, n))
		n += 1
	examples.append(_sample(PoloPlayer.Pos.GK, WalkOns.roll_stars(rng), used, n))
	odds = {}
	years = {}
	for _i in ROLLS:
		var st := WalkOns.roll_stars(rng)
		odds[st] = int(odds.get(st, 0)) + 1
		var y := rng.randi_range(1, 4)
		years[y] = int(years.get(y, 0)) + 1
	_render()

## One sample walk-on (the real generator), an id of his own so his face is his own.
func _sample(pos: int, stars: float, used: Dictionary, i: int) -> PoloPlayer:
	var p := WalkOns.make(rng, pos, stars, used)
	p.id = 9_000_000 + rng.randi_range(0, 999_999) * 10 + i
	p.number = i + 1
	return p

## A class for the popup: CLASS SIZE walk-ons at the positions an empty roster would get them.
func _class() -> Array:
	var used := {}
	var out: Array = []
	var gk := 0
	for i in size_n:
		var pos := PoloPlayer.Pos.GK if (i == 0 and size_n >= 4) or (i == 7 and gk < 2) else CollegeGen.field_pos(rng)
		if pos == PoloPlayer.Pos.GK:
			gk += 1
		out.append(_sample(pos, WalkOns.roll_stars(rng), used, i))
	return out

func _preview() -> void:
	var season := c.next_season_label() if c != null else "2027-28"
	WalkOnShow.play_preview(Game.overlay if Game.overlay != null else self, _class(), sample_team, season,
		func(): Game.toast("PREVIEW ONLY: NOTHING WAS ADDED", UI.GOLD))

func _size(by: int) -> void:
	size_n = clampi(size_n + by, 1, _cap())
	size_l.text = "CLASS SIZE: %d" % size_n

# ------------------------------------------------------------------ the page
func _render() -> void:
	for ch in list.get_children():
		ch.queue_free()
	var row := UI.hbox(3)
	row.name = "Controls"
	var minus := UI.button("-", func(): _size(-1), "ghost", 22, 18)
	minus.name = "SizeDown"
	row.add_child(minus)
	size_l = UI.label("CLASS SIZE: %d" % size_n, 8, UI.TEXT, "caps")
	size_l.name = "ClassSize"
	size_l.custom_minimum_size = Vector2(84, 18)
	size_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	size_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(size_l)
	var plus := UI.button("+", func(): _size(1), "ghost", 22, 18)
	plus.name = "SizeUp"
	row.add_child(plus)
	var pv := UI.button("PREVIEW POPUP", _preview, "primary", 110, 18)
	pv.name = "PreviewWalkOnPopup"
	row.add_child(pv)
	var rr := UI.button("REROLL EXAMPLES", _reroll, "normal", 110, 18)
	rr.name = "RerollWalkOns"
	row.add_child(rr)
	var center := CenterContainer.new()
	center.add_child(row)
	list.add_child(center)
	list.add_child(UI.label("WALK-ON EXAMPLES (DEV DATA ONLY)", 16, UI.GOLD, "big"))
	var g := GridContainer.new()
	g.name = "Examples"
	g.columns = 3
	g.add_theme_constant_override("h_separation", 4)
	g.add_theme_constant_override("v_separation", 4)
	for p: PoloPlayer in examples:
		var cv := UI.canvas(int(CARD.x), int(CARD.y), func(ci: Control): _paint_example(ci, p))
		cv.name = "Example_%s" % ("GK" if p.is_keeper() else PlayerForm.star_text(p.stars))
		g.add_child(cv)
	var gc := CenterContainer.new()
	gc.add_child(g)
	list.add_child(gc)
	list.add_child(UI.label("THE ODDS: %d ROLLS (TARGET IN BRACKETS)" % ROLLS, 16, UI.GOLD, "big"))
	var o := UI.canvas(0, 74, _paint_odds)
	o.name = "Odds"
	o.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_child(o)
	var note := UI.label("Samples only: nobody here is on a roster, nothing is saved. Every ceiling equals its attribute (no potential).", 8, UI.DIM)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	list.add_child(note)

## One example: portrait, name, position and class, hometown, stars; his four attributes as the
## player page's boxes (gold: the attribute, and nothing hollow above it: no potential).
func _paint_example(ci: Control, p: PoloPlayer) -> void:
	var r := Rect2(Vector2.ZERO, CARD)
	ci.draw_rect(r, Deck.NAVY)
	ci.draw_rect(r, Color("7fe35f") if not p.is_keeper() else BarHit.RED, false, 1.0)
	var face := Rect2(4, 4, 34, 38)
	ci.draw_rect(face, Color("081650"))
	var col: Array = Portrait.colors_ours(p, sample_team)
	ci.draw_texture_rect(Portrait.texture_zoomed(p, col[0], col[1], Vector2i(34, 38)), face, false)
	var x := 43.0
	Deck.text(ci, x, 8, Deck.fit("%s %s" % [p.first.to_upper(), p.last.to_upper()], CARD.x - x - 4), 8, UI.TEXT)
	Deck.text(ci, x, 18, "%s  %s  AGE %d" % [p.pos_text(), p.year_text(), p.age], 8, UI.ACCENT)
	Deck.text(ci, x, 28, Deck.fit(Hometowns.shown(p.home).to_upper(), CARD.x - x - 4), 8, UI.DIM)
	Deck.stars(ci, x, 33, p.stars, 3, UI.GOLD)
	Deck.text(ci, x + 34, 37, "%s*  OVR %s" % [PlayerForm.star_text(p.stars), p.ovr_text()], 8, UI.GOLD)
	var y := 48.0
	for k in p.key_ratings():
		var v := p.attr(k)
		Deck.text(ci, 5, y + 3, String(Attributes.NAMES.get(k, k)).to_upper(), 8, UI.DIM)
		for i in 10:
			var b := Rect2(80 + i * 5, y + 1, 4, 4)
			ci.draw_rect(b, UI.GOLD if i < roundi(v) else Color(1, 1, 1, 0.1))
		Deck.text(ci, 134, y + 3, "%d" % roundi(v), 8, UI.TEXT)
		y += 8.5

## Each rating's share of the rolls beside its target, then the class years'.
func _paint_odds(ci: Control) -> void:
	var w := ci.size.x
	var x0 := 60.0
	var bw := maxf(60.0, w * 0.5 - x0 - 50.0)
	var y := 4.0
	for e in WalkOns.STAR_ODDS:
		var st := float(e[0])
		var share := float(odds.get(st, 0)) / ROLLS
		Deck.text(ci, 4, y + 3, "%s STARS" % PlayerForm.star_text(st), 8, UI.TEXT)
		ci.draw_rect(Rect2(x0, y, bw, 6), Color(1, 1, 1, 0.08))
		ci.draw_rect(Rect2(x0, y, bw * share, 6), UI.GOLD)
		ci.draw_rect(Rect2(x0 + bw * float(e[1]) / 100.0, y - 1, 1, 8), Color("7fe35f"))
		Deck.text(ci, x0 + bw + 4, y + 3, "%.1f%% (%d%%)" % [share * 100.0, int(e[1])], 8, UI.DIM)
		y += 10
	var low := float(int(odds.get(0.5, 0)) + int(odds.get(1.0, 0)) + int(odds.get(1.5, 0))) / ROLLS
	Deck.text(ci, 4, y + 5, "0.5-1.5 STARS: %.1f%% (90%%)" % (low * 100.0), 8, UI.GOLD)
	var x1 := w * 0.5 + 10.0
	var y2 := 4.0
	for yr in [1, 2, 3, 4]:
		var share := float(years.get(yr, 0)) / ROLLS
		Deck.text(ci, x1, y2 + 3, ["", "FRESHMAN", "SOPHOMORE", "JUNIOR", "SENIOR"][yr], 8, UI.TEXT)
		ci.draw_rect(Rect2(x1 + 62, y2, bw * 0.6, 6), Color(1, 1, 1, 0.08))
		ci.draw_rect(Rect2(x1 + 62, y2, bw * 0.6 * share * 2.0, 6), UI.ACCENT)
		Deck.text(ci, x1 + 66 + bw * 0.6, y2 + 3, "%.1f%% (25%%)" % (share * 100.0), 8, UI.DIM)
		y2 += 10

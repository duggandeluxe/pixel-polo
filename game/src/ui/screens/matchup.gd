extends BaseScreen
## The game preview, opened from the hub's PLAY NEXT GAME: the two teams side by side (home on
## the left) with their logos, records and ratings, then PLAY or SIM.

const SIDE_W := 170   # every team's name on one line, in the big font

var busy := false   # the match or the summary is already on its way: ignore more taps
var tight := false  # a coaching strip to fit: the logos a size smaller

func _ready() -> void:
	c = Game.career
	if c == null or not c.has_game():
		Game.goto("hub" if c != null else "title", {}, false)
		return
	c.catch_up()   # the days before this game are played first
	back_target = "hub"
	var n := Schedule.game_no(c.schedule, c.school, c.my_game())
	build("GAME %d" % n if n > 0 else c.round_name().to_upper(), true, true)
	var round := UI.label(c.round_name().to_upper(), 8, UI.DIM, "caps")
	round.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(round)
	var stakes := _coaching_panel()
	tight = stakes != null
	body.add_child(UI.spacer(0, 0, true))
	var center := CenterContainer.new()
	center.add_child(_matchup(c.opponent()))
	body.add_child(center)
	body.add_child(centered(_venue_bar(c.venue_name())))
	if stakes != null:
		body.add_child(centered(stakes))
	body.add_child(UI.spacer(0, 0, true))
	# PLAY GAME and SIM THIS GAME side by side (room for the venue bar above them)
	var buttons := UI.hbox(6)
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	var play := Deck.button("PLAY GAME  >", _play, "primary", 190, 22)
	play.name = "Play"
	play.add_theme_font_override("font", UI.font_big)
	play.add_theme_font_size_override("font_size", 20)
	buttons.add_child(play)
	var sim := Deck.button("SIM THIS GAME", _sim, "ghost", 110, 22)
	sim.name = "Sim"
	buttons.add_child(sim)
	body.add_child(centered(buttons))
	body.add_child(UI.spacer(0, 1))
	Sfx.music("menu")

## What your coaching decisions have riding on this game (CoachEvents), in a slim two-line strip
## (the page keeps its PLAY and SIM): PROVE ME WRONG's wager in full, else the challenges and
## their rewards, and who's suspended. null when there's nothing.
func _coaching_panel() -> Control:
	var head := ""
	var segs: Array = []   # the second line: [text, color], joined
	var red := Color("ff5a5a")
	for e in c.coach_pending:
		if String(e.k) == "pmw":
			var n := CoachEvents._name(c, int(e.pid))
			head = "HIGH-STAKES COACHING DECISION: %s STARTING" % n
			segs = [["WIN: TEAM 1.5X / %s 2X XP" % n, UI.GOLD], ["LOSS: TEAM 0.75X / %s XP BAR RESET" % n, red]]
			break
	if head == "":
		var items: Array = c.coach_pending.map(func(e): return "%s - %s" % [String(e.label), String(e.reward)])
		if not items.is_empty():
			head = "COACHING CHALLENGE ACTIVE" + ("" if items.size() == 1 else " (%d)" % items.size())
			segs.append([String(items[0]), UI.ACCENT])
	for p in c.team().roster:
		if p.is_suspended():
			if head == "":
				head = "COACHING DECISION"
				segs.append(["%s SUSPENDED: MISSES THIS GAME" % p.short_name().to_upper(), red])
			else:
				head += "  -  %s SUSPENDED" % p.short_name().to_upper()
	if head == "":
		return null
	var v := UI.vbox(0)
	var t := UI.label(head, 8, UI.GOLD, "caps")
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var line := UI.hbox(6)
	line.alignment = BoxContainer.ALIGNMENT_CENTER
	for s in segs.slice(0, 2):
		line.add_child(UI.label(String(s[0]), 8, s[1], "caps"))
	v.add_child(line)
	var p := navy_panel(v)
	p.add_theme_stylebox_override("panel", UI.chunky(Deck.NAVY, UI.BORDER, false, false, 6, 1))
	p.name = "CoachingChallenge"
	return p

const VENUE_W := 300        # the venue bar: wide enough for every pool name in the big font
const VENUE_TEXT_W := 284   # (inside its padding)

## WHERE IT'S PLAYED: a navy bar, a thin white border, VENUE small above the pool's name (the
## home team's own: Career.venue_name) in the yellow big font, both centred. A name too long for
## one line in the big font wraps onto two; a neutral site says so.
func _venue_bar(named: String) -> Control:
	var v := UI.vbox(0)
	var p := navy_panel(v)
	p.add_theme_stylebox_override("panel", UI.chunky(Deck.NAVY, UI.BORDER, false, false, 8, 2))   # (a slim bar)
	p.name = "VenueBar"
	p.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	p.custom_minimum_size = Vector2(VENUE_W, 0)
	var head := UI.label("VENUE", 8, UI.ACCENT, "caps")
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(head)
	var name := UI.label("NEUTRAL SITE" if named == "" else named.to_upper(), 16, UI.GOLD, "big")
	name.name = "Venue"
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if UI.text_width(name.text, 16, "big") > VENUE_TEXT_W:
		name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		name.custom_minimum_size = Vector2(VENUE_TEXT_W, 0)
	v.add_child(name)
	return p

## Home on the left, away on the right.
func _matchup(opp: PoloTeam) -> Control:
	var home := c.team() if c.is_home() else opp
	var away := opp if c.is_home() else c.team()
	var h := UI.hbox(8)
	h.add_child(_side(home))
	var vs := UI.label("VS", 20, UI.DIM, "big")
	vs.custom_minimum_size.y = 60
	vs.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	vs.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	h.add_child(vs)
	h.add_child(_side(away))
	return h

## One team: big logo, name, seed and record, then its team overall as a big number (OVR), and
## under it OFFENSE, DEFENSE and GOALKEEPING in stars (PoloTeam.rating_stars of offense_display,
## defense_display, goalkeeping_display: the game's star bar, the same for all three). Display
## only: every number is the team's own, worked out as always.
func _side(t: PoloTeam) -> Control:
	var v := UI.vbox(0)   # (packed: the whole preview fits the page without scrolling)
	v.custom_minimum_size.x = SIDE_W
	var logo := TeamLogo.widget(t, TeamLogo.LARGE, 2 if tight else 3)
	logo.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(logo)
	v.add_child(UI.team_title(Colleges.display_name(t.name).to_upper(), t.mascot, SIDE_W, UI.GOLD if t.id == c.school else UI.TEXT))
	var seed := Schedule.seed_of(c.season, c.cur().kind, t.id, t.conf)
	# the team overall, big: the number, OVR beside it, then (small) its seed and record
	var ovr := t.overall_display()
	var big := UI.hbox(3)
	big.name = "Overall"
	big.set_meta("overall", ovr)
	big.alignment = BoxContainer.ALIGNMENT_CENTER
	# the number and OVR as one piece: the same dark outline on both, OVR centred on the number
	var n := UI.label(str(ovr), 24, UI.GOLD, "big")
	n.name = "OverallNumber"
	var tag := UI.label("OVR", 16, UI.TEXT, "big")
	tag.name = "OverallTag"
	for l in [n, tag]:
		l.add_theme_color_override("font_outline_color", UI.INK)
		l.add_theme_constant_override("outline_size", 2)
		l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		big.add_child(l)
	big.add_child(UI.spacer(6, 0))
	var rec := UI.label(("#%d  " % seed if seed > 0 else "") + c.record_text(t.id), 8, UI.DIM, "caps")
	rec.name = "Record"
	rec.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	big.add_child(rec)
	v.add_child(big)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 0)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	for row in [["OFFENSE", t.offense_display()], ["DEFENSE", t.defense_display()], ["GOALKEEPING", t.goalkeeping_display()]]:
		var l := UI.label(String(row[0]), 8, UI.DIM, "caps")
		l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		grid.add_child(l)
		var st := PoloTeam.rating_stars(float(row[1]))
		var bar := UI.canvas(int(Deck.star_bar_w()), 9, func(ci): Deck.star_bar(ci, 0, 0, st, float(Deck.STAR_PLACES)))
		bar.name = "Stars" + String(row[0])
		bar.set_meta("stars", st)
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		grid.add_child(bar)
	v.add_child(grid)
	return v

func _play() -> void:
	if busy:
		return
	busy = true
	Game.match_cfg = {"us": c.team(), "them": c.opponent(), "seed": randi(),
		"career": true, "home": c.is_home(), "pool": c.venue().id, "venue": c.venue_name(), "stage": PregameIntro.label_for(c.cur(), c.my_game()),
		"neutral": Schedule.is_neutral(c.my_game()), "importance": _importance(),
		"title": _title_at_stake(),
		"minutes": float(MatchState.quarter_min_for(true))}   # (read once: a change in Settings is for the next game)
	Game.goto("match", Game.match_cfg)

## The championship a win here takes: "conf", "nat", "d2" (the WWPA's final is Division II's), "d3".
func _title_at_stake() -> String:
	var kind := Schedule.game_kind(c.cur(), c.my_game())
	if kind == "conf_final" and c.team().conf == Colleges.D2_CONF:
		return "d2"
	return String({"conf_final": "conf", "nat_final": "nat", "d3_final": "d3"}.get(kind, ""))

## How much this game matters to the crowd: 2 the NCSA Championship, 1 the conference tournament
## or a big opponent (CoachEvents' own rule for a big game), 0 otherwise.
func _importance() -> int:
	var kind := String(c.cur().get("kind", ""))
	if kind.begins_with("nat_"):
		return 2
	return 1 if kind.begins_with("conf_") or CoachEvents.big_game(c) else 0

func _sim() -> void:
	if busy:
		return
	Game.dialog("SIM THIS GAME?", "The game is decided from the ratings. You won't play it.", [
		["SIM IT", func():
			if busy or not c.has_game():
				return
			busy = true
			c.last_summary = c.sim_my_game()
			Game.save_career()
			Game.goto("game_summary"), "primary"],
		["CANCEL", Callable(), "ghost"]])

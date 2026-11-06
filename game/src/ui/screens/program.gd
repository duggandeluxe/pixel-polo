extends BaseScreen
## PROGRAM OVERVIEW (the Dynasty Hub's PROGRAM): your program's headquarters, three panels, all
## from the dynasty's own data:
##   THE PROGRAM  logo, name, conference, home pool (Colleges.venue_name)
##   THIS SEASON  record, conference record and place, national rank (the latest poll), the team
##                overall big, OFF / DEF / GK in stars (PoloTeam.rating_stars)
##   THE COACH    his dynasty record and seasons, the trophy case (his titles: Career.coach
##                titles, conference and NCSA), his last seasons (Career.history)

func _ready() -> void:
	back_target = "more"
	build("PROGRAM OVERVIEW", true, true)
	var row := UI.hbox(6)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(row)
	row.add_child(_program())
	row.add_child(_season())
	row.add_child(_coach())

func _panel(v: VBoxContainer, name: String) -> PanelContainer:
	var p := navy_panel(v)
	p.name = name
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.size_flags_vertical = Control.SIZE_FILL
	return p

func _head(v: VBoxContainer, t: String) -> void:
	v.add_child(big_text(t, UI.ACCENT))
	v.add_child(divider_line())

func _kv(v: VBoxContainer, k: String, val: String, col: Color = UI.TEXT) -> Label:
	var h := UI.hbox(4)
	var kl := UI.label(k, 8, UI.DIM, "caps")
	kl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(kl)
	var vl := UI.label(val, 8, col, "caps")
	h.add_child(vl)
	v.add_child(h)
	return vl

func _program() -> Control:
	var t := c.team()
	var v := UI.vbox(3)
	var p := _panel(v, "Program")
	var logo := TeamLogo.widget(t, TeamLogo.LARGE, 3)
	logo.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(logo)
	v.add_child(UI.team_title(Colleges.display_name(t.name).to_upper(), t.mascot, 140, UI.GOLD))
	var conf := UI.label(c.conf_name().to_upper(), 8, UI.ACCENT, "caps")
	conf.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	conf.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	conf.custom_minimum_size.x = 140
	v.add_child(conf)
	v.add_child(divider_line())
	v.add_child(UI.label("HOME POOL", 8, UI.DIM, "caps"))
	var pool := UI.label(Colleges.venue_name(c.school).to_upper() if Colleges.venue_name(c.school) != "" else c.venue_home().name.to_upper(), 8, UI.GOLD, "caps")
	pool.name = "HomePool"
	pool.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pool.custom_minimum_size.x = 140
	v.add_child(pool)
	return p

func _season() -> Control:
	var t := c.team()
	var v := UI.vbox(3)
	var p := _panel(v, "Season")
	_head(v, "%s SEASON" % c.season_label())
	var big := UI.hbox(4)
	big.alignment = BoxContainer.ALIGNMENT_CENTER
	var n := UI.label(str(t.overall_display()), 24, UI.GOLD, "big")
	n.name = "Overall"
	n.add_theme_color_override("font_outline_color", UI.INK)
	n.add_theme_constant_override("outline_size", 2)
	big.add_child(n)
	var tag := UI.label("OVR", 16, UI.TEXT, "big")
	tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	big.add_child(tag)
	v.add_child(big)
	_kv(v, "RECORD", c.record_text(), UI.GOLD).name = "Record"
	_kv(v, "CONFERENCE", "%s  (#%d)" % [c.conf_record_text(), c.conf_rank()])
	var rank := Poll.rank_in(Poll.latest(c), c.school)
	_kv(v, "NATIONAL RANK", "#%d" % rank if rank > 0 and rank <= Poll.TOP else "UNRANKED", UI.GOLD if rank > 0 and rank <= Poll.TOP else UI.DIM).name = "NationalRank"
	v.add_child(divider_line())
	for r in [["OFFENSE", t.offense_display()], ["DEFENSE", t.defense_display()], ["GOALKEEPING", t.goalkeeping_display()]]:
		var h := UI.hbox(4)
		var l := UI.label(String(r[0]), 8, UI.DIM, "caps")
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(l)
		var st := PoloTeam.rating_stars(float(r[1]))
		var bar := UI.canvas(int(Deck.star_bar_w()), 9, func(ci): Deck.star_bar(ci, 0, 0, st, float(Deck.STAR_PLACES)))
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(bar)
		v.add_child(h)
	return p

func _coach() -> Control:
	var v := UI.vbox(3)
	var p := _panel(v, "Coach")
	_head(v, "COACH %s" % String(c.coach.last).to_upper())
	_kv(v, "DYNASTY RECORD", "%d-%d" % [int(c.coach.wins), int(c.coach.losses)], UI.GOLD).name = "DynastyRecord"
	_kv(v, "SEASONS", str(int(c.coach.seasons)))
	# the trophy case: his titles as they were won (Career.coach titles: "2026-27 PEC", "2026-27 NCSA")
	var titles: Array = c.coach.get("titles", [])
	var nat := titles.filter(func(x): return String(x).ends_with("NCSA")).size()
	var conf := titles.size() - nat
	v.add_child(UI.spacer(0, 2))
	v.add_child(big_text("TROPHY CASE", UI.ACCENT))
	_kv(v, "CONFERENCE TITLES", str(conf), UI.GOLD if conf > 0 else UI.DIM).name = "ConfTitles"
	_kv(v, "NATIONAL TITLES", str(nat), UI.GOLD if nat > 0 else UI.DIM).name = "NatTitles"
	v.add_child(UI.spacer(0, 2))
	v.add_child(UI.label("LAST SEASONS", 8, UI.ACCENT, "caps"))
	var hist: Array = c.history.duplicate()
	hist.reverse()
	for h in hist.slice(0, 3):
		var l := UI.label(Deck.fit("%s  %d-%d  %s" % [h.year, int(h.w), int(h.l), String(h.finish)], 140).to_upper(), 8, UI.TEXT, "caps")
		v.add_child(l)
	if hist.is_empty():
		v.add_child(UI.label("FIRST SEASON", 8, UI.DIM, "caps"))
	return p

func on_back() -> void:
	Sfx.play("back")
	Game.goto("more")

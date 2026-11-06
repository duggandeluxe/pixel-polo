extends BaseScreen
## Developer Mode's DIVISION EXPANSION TESTING. DATABASE: every school in a chosen test configuration
## as its generated players rate it, logo beside it, tap one to inspect its roster. The rest run
## DivisionChecks' groups. Everything here is a throwaway: nothing is saved, and the Store is
## only ever read, so no purchase record, coin or unlock can change.

static var config := 3
static var view := "DATABASE"
var world: Career
var page: VBoxContainer
var inspect := ""

func _ready() -> void:
	back_target = "settings"
	build("DIVISION EXPANSION TESTING", true, true)
	_make()
	_render()

func on_back() -> void:
	Sfx.play("back")
	Game.back("settings")

func _make() -> void:
	world = Career.new_setup(20261105, DivisionChecks.CONFIGS[config][1])

func _render() -> void:
	for ch in body.get_children():
		ch.queue_free()
	var names: Array = ["DATABASE"] + DivisionChecks.GROUPS.keys()
	body.add_child(tabs(names, view, func(t):
		view = t
		inspect = ""
		_render()))
	page = UI.vbox(1)
	page.name = "Page"
	body.add_child(UI.scroll(page))
	if view == "DATABASE":
		_database()
	else:
		_group()

func _database() -> void:
	var row := UI.hbox(2)
	row.name = "Configs"
	for i in DivisionChecks.CONFIGS.size():
		var k: int = i
		var b := UI.button("%s (%d)" % [DivisionChecks.CONFIGS[k][0], DivisionChecks.CONFIGS[k][2]], func():
			config = k
			_make()
			_render(), "tab_on" if config == k else "tab", 0, 14)
		b.name = "Config%d" % k
		row.add_child(b)
	page.add_child(row)
	if inspect != "":
		_roster(world.teams[inspect])
		return
	page.add_child(UI.label("TEAM, REAL INSPIRATION, HOME POOL  -  OVR TARGET > NOW, THEN OFF / DEF / GK STARS", 8, UI.ACCENT, "caps"))
	for s in Colleges.all_schools():
		if world.teams.has(s.short):
			page.add_child(_school_row(s, world.teams[s.short]))

func _school_row(s: Dictionary, t: PoloTeam) -> Control:
	var sid := String(s.short)
	var b := UI.button("", func():
		inspect = sid
		_render(), "normal", 0, 26)
	b.name = "Row_" + sid
	var h := UI.hbox(4)
	h.set_anchors_preset(Control.PRESET_FULL_RECT)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(h)
	var logo := TeamLogo.widget(t, TeamLogo.MEDIUM)
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(logo)
	var v := UI.vbox(0)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(v)
	var art_ok := TeamLogo.art(t, Vector2i(60, 60)) != null
	var ready := t.roster.size() >= Career.ROSTER_MAX and t.keeper() != null
	v.add_child(_line("%s  %s  D%d  %s  ROSTER %s  LOGO %s" % [sid, String(s.name).to_upper(), Colleges.division_of(sid), Colleges.conf_abbr(String(s.conf)), "OK" if ready else "BAD", "ART" if art_ok else "TEMPLATE"], UI.TEXT))
	v.add_child(_line("%s  -  %s" % [String(s.get("real", "Division I")), String(s.get("venue", ""))], UI.DIM))
	var nums := _line("%d > %d  %.1f / %.1f / %.1f" % [int(s.ovr), t.base_ovr(), PoloTeam.rating_stars(t.offense_display()), PoloTeam.rating_stars(t.defense_display()), PoloTeam.rating_stars(t.goalkeeping_display())], UI.GOLD)
	nums.name = "Numbers"
	nums.clip_text = false
	nums.custom_minimum_size.x = 110
	nums.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	h.add_child(nums)
	return b

func _line(text: String, col: Color) -> Label:
	var l := UI.label(text, 8, col)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.clip_text = true
	return l

## Every generated player of one school.
func _roster(t: PoloTeam) -> void:
	var back := UI.button("<  ALL SCHOOLS", func():
		inspect = ""
		_render(), "ghost", 0, 14)
	back.name = "BackToList"
	page.add_child(back)
	page.add_child(UI.label("%s  -  OVR %d" % [t.name.to_upper(), t.base_ovr()], 8, UI.GOLD, "caps"))
	for p: PoloPlayer in t.roster:
		var vals: Array = p.key_ratings().map(func(k): return "%s %d" % [String(k).to_upper(), int(p.attr(k))])
		page.add_child(UI.label("#%d %s  %s  YR %d  %s*/%s*  %s  %s" % [p.number, p.short_name(), p.pos_text(), p.year, PlayerForm.star_text(p.stars), PlayerForm.star_text(p.pot_stars), " ".join(vals), p.home], 8, UI.TEXT))

func _group() -> void:
	var head := UI.label("RUNNING %s..." % String(DivisionChecks.GROUPS[view]), 8, UI.ACCENT, "caps")
	head.name = "Summary"
	page.add_child(head)
	_run.call_deferred(view, head)

func _run(g: String, head: Label) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if not is_instance_valid(head):
		return
	var results := DivisionChecks.run(g)
	var fails := results.filter(func(r): return not r.ok).size()
	head.text = "%s: %d CHECKS, %d FAILED" % [String(DivisionChecks.GROUPS[g]), results.size(), fails]
	head.add_theme_color_override("font_color", UI.BAD if fails > 0 else UI.GOOD)
	for r in results:
		var l := UI.label("%s  %s" % ["OK  " if r.ok else "FAIL", String(r.text)], 8, UI.TEXT if r.ok else UI.BAD)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = 440
		page.add_child(l)

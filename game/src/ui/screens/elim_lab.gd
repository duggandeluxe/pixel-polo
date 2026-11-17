extends BaseScreen
## Developer Mode's SEASON OVER TESTING (Settings > Developer Tools): the whole Championship
## Elimination flow, whenever you like.
##   OH NO! SCREEN       the announcement for each way a season can end (made-up results, drawn
##                       with the loaded career's teams when there is one); nothing is saved
##   LOADED CAREER       read only: its season state, the SEASON OVER hub as it would look, the
##                       season so far (the live Season Review), its own OH NO! screen
##   SANDBOX SEASON      a throwaway career made in memory (never Game.career, never saved) played
##                       out by the sim until it's knocked out, then SIM TO OFFSEASON: a report
##                       of what happened, checking the rules (no XP for your team after it, the
##                       sim runs once, the champion decided, a single season in the history)
## Developer Mode off, the screen sends you back to Settings.

const SAMPLES := [["NCSA FIRST ROUND LOSS", "nat_r1"], ["NCSA QUARTERFINAL (SHOOTOUT)", "nat_qf"], ["NCSA SEMIFINAL LOSS", "nat_sf"],
	["NCSA FINAL LOSS", "nat_final"], ["NOT SELECTED FOR THE NCSA", "missed"]]

var report: VBoxContainer

func _ready() -> void:
	back_target = "dev_settings"
	if not bool(Game.settings.get("dev_mode", false)):
		Game.goto.call_deferred("settings", {}, false)
		return
	build("SEASON OVER TESTING")
	var v := UI.vbox(4)
	body.add_child(UI.scroll(v))
	# the announcement
	v.add_child(UI.label("OH NO! SCREEN (SAMPLE RESULTS)", 16, UI.GOLD, "big"))
	var g := _grid("Samples")
	for s in SAMPLES:
		var kind: String = s[1]
		g.add_child(_btn(String(s[0]), "Sample_" + kind, func(): Game.goto("season_over", {"preview": true, "model": sample(c, kind)})))
	g.add_child(_btn("SEASON SO FAR (SAMPLE)", "SampleLive", func(): Game.goto("recap", {"preview": true, "sample": true, "model": live_sample()})))
	v.add_child(g)
	# and the other half: winning it all
	v.add_child(UI.spacer(0, 3))
	v.add_child(UI.label("CHAMPIONS! SCREEN (SAMPLE RESULTS)", 16, UI.GOLD, "big"))
	var cg0 := _grid("ChampSamples")
	for s in [["NCSA CHAMPIONS", "nat"], ["CONFERENCE + NCSA DOUBLE", "double"], ["WON IN A SHOOTOUT", "so"], ["BLOWOUT FINAL", "big"]]:
		var kind: String = s[1]
		cg0.add_child(_btn(String(s[0]), "Champ_" + kind, func(): Game.goto("champions", {"preview": true, "model": champ_sample(c, kind)})))
	v.add_child(cg0)
	# out of the conference tournament, into the NCSA
	v.add_child(UI.spacer(0, 3))
	v.add_child(UI.label("FELL JUST SHORT! SCREEN (SAMPLE RESULTS)", 16, UI.GOLD, "big"))
	var fg := _grid("ShortSamples")
	for s in [["LOST CONF SEMIFINAL (AT-LARGE)", "conf_semi"], ["LOST CONF FINAL IN PENALTIES", "conf_final"]]:
		var kind: String = s[1]
		fg.add_child(_btn(String(s[0]), "Short_" + kind, func(): Game.goto("fell_short", {"preview": true, "model": short_sample(c, kind)})))
	v.add_child(fg)
	# the loaded career
	v.add_child(UI.spacer(0, 3))
	v.add_child(UI.label("LOADED CAREER (READ ONLY)", 16, UI.GOLD, "big"))
	if c == null:
		var none := UI.label("No career is loaded. Load one to preview its SEASON OVER hub and season so far.", 8, UI.DIM)
		none.name = "NoCareer"
		v.add_child(none)
	else:
		var st := UI.label(_state_text(c), 8, UI.TEXT)
		st.name = "State"
		st.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(st)
		var cg := _grid("Career")
		cg.add_child(_btn("PREVIEW SEASON OVER HUB", "PreviewHub", func(): Game.goto("hub", {"elim_preview": true})))
		cg.add_child(_btn("PREVIEW SEASON SO FAR", "PreviewLive", func(): Game.goto("recap", {"live": true, "preview": true})))
		cg.add_child(_btn("PREVIEW THIS CAREER'S OH NO!", "PreviewMine", func(): Game.goto("season_over", {"preview": true, "model": mine(c)})))
		cg.add_child(_btn("VIEW NCSA BRACKET", "ViewBracket", func(): Game.goto("conference", {"tab": "PLAYOFFS", "fam": "nat"})))
		v.add_child(cg)
	# the sandbox
	v.add_child(UI.spacer(0, 3))
	v.add_child(UI.label("SANDBOX SEASON (NOTHING SAVED)", 16, UI.GOLD, "big"))
	var sg := _grid("Sandbox")
	sg.add_child(_btn("WEAK SCHOOL (MISSES THE NCSA)", "SandboxWeak", func(): _run(false)))
	sg.add_child(_btn("STRONG SCHOOL (NCSA RUN)", "SandboxStrong", func(): _run(true)))
	v.add_child(sg)
	report = UI.vbox(1)
	report.name = "Report"
	v.add_child(report)
	var note := UI.label("Previews and the sandbox never touch your saves: nothing is simmed, saved or awarded in the loaded career.", 8, UI.DIM)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(note)

func _grid(n: String) -> GridContainer:
	var g := GridContainer.new()
	g.name = n
	g.columns = 2
	g.add_theme_constant_override("h_separation", 3)
	g.add_theme_constant_override("v_separation", 3)
	g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return g

func _btn(t: String, n: String, cb: Callable) -> Button:
	var b := UI.button(t, cb, "ghost", 0, 18)
	b.name = n
	b.clip_text = true
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return b

static func _state_text(cr: Career) -> String:
	var s := "SEASON %s  -  STATE: %s  -  PHASE: %s  -  %s" % [cr.season_label(), cr.season_state, cr.phase.to_upper(), cr.week_text()]
	if not cr.elim.is_empty():
		s += "\nELIMINATED: %s  (OH NO! %s, SIM TO OFFSEASON %s)" % [String(cr.elim.get("round", "")),
			"SEEN" if bool(cr.elim.get("shown", false)) else "NOT SEEN", "RUN" if bool(cr.elim.get("simmed", false)) else "NOT RUN"]
	return s

# ------------------------------------------------------------------ samples
## A team to draw: the career's, else the school's own data.
static func _team(cr: Career, id: String) -> Variant:
	if cr != null and cr.teams.has(id):
		return cr.teams[id]
	var s := Colleges.school(id)
	return {"short": id, "name": String(s.get("name", id)), "c1": s.get("c1", "2a68f5"), "c2": s.get("c2", "ffffff")} if s.is_empty() else s

## A made-up elimination of `kind` for the OH NO! screen.
static func sample(cr: Career, kind: String) -> Dictionary:
	var ids: Array = Colleges.SCHOOLS.map(func(s): return String(s.short))
	var me := cr.school if cr != null else String(ids[0])
	var opp := String(ids[1]) if String(ids[1]) != me else String(ids[2])
	var m := {"team": _team(cr, me), "opp": _team(cr, opp), "season": cr.season_label() if cr != null else "2026-27",
		"us": 7, "them": 9, "so": [], "won": false, "final": kind == "nat_final"}
	match kind:
		"nat_qf":
			m.merge({"us": 10, "them": 10, "so": [3, 4]}, true)
		"nat_sf":
			m.merge({"us": 6, "them": 11}, true)
		"nat_final":
			m.merge({"us": 8, "them": 9}, true)
	if kind == "missed":
		m["selected"] = false
		m["conf"] = true
		m["round"] = "NOT SELECTED FOR THE NCSA CHAMPIONSHIP"
		m["game_round"] = "CONFERENCE SEMIFINAL"
	else:
		m["round"] = String(Schedule.ROUND_NAMES[kind])
		m["game_round"] = m.round
	return m

## A made-up conference tournament loss of `kind` with an NCSA bid, for the FELL JUST SHORT! screen.
static func short_sample(cr: Career, kind: String) -> Dictionary:
	var ids: Array = Colleges.SCHOOLS.map(func(s): return String(s.short))
	var me := cr.school if cr != null else String(ids[0])
	var opp := String(ids[1]) if String(ids[1]) != me else String(ids[2])
	var m := {"team": _team(cr, me), "opp": _team(cr, opp), "season": cr.season_label() if cr != null else "2026-27",
		"round": String(Schedule.ROUND_NAMES[kind]), "us": 8, "them": 10, "so": [], "seed": 6, "at_large": true, "record": "19-7"}
	if kind == "conf_final":
		m.merge({"us": 9, "them": 9, "so": [3, 4], "seed": 3}, true)
	return m

## A made-up NCSA title of `kind` for the CHAMPIONS! screen.
static func champ_sample(cr: Career, kind: String) -> Dictionary:
	var ids: Array = Colleges.SCHOOLS.map(func(s): return String(s.short))
	var me := cr.school if cr != null else String(ids[0])
	var opp := String(ids[1]) if String(ids[1]) != me else String(ids[2])
	var m := {"team": _team(cr, me), "opp": _team(cr, opp), "season": cr.season_label() if cr != null else "2026-27",
		"us": 9, "them": 8, "so": [], "record": "24-3", "conf_title": kind == "double",
		"conf_abbr": cr.conf_abbr() if cr != null else "NCC"}
	match kind:
		"so":
			m.merge({"us": 11, "them": 11, "so": [5, 4]}, true)
		"big":
			m.merge({"us": 15, "them": 6, "record": "27-0"}, true)
	return m

## The loaded career's own: its elimination, or (still in it) its last game as if it had been.
static func mine(cr: Career) -> Dictionary:
	if not cr.elim.is_empty():
		var m := preload("res://src/ui/screens/season_over.gd").model_of(cr)
		if m.has("opp"):
			return m
	var m := sample(cr, "nat_qf")
	var lp := cr.last_played()
	if not lp.is_empty():
		var g: Dictionary = lp[1]
		var home: bool = g.h == cr.school
		m.merge({"opp": cr.teams[String(g.a if home else g.h)], "us": int(g.r.s[0] if home else g.r.s[1]), "them": int(g.r.s[1] if home else g.r.s[0]),
			"so": [], "won": Schedule.winner(g) == cr.school, "game_round": Schedule.game_label(lp[0], g)}, true)
	return m

## The live Season Review with sample data (no career needed): pending sections and all.
static func live_sample() -> Dictionary:
	var m: Dictionary = preload("res://src/ui/screens/review_lab.gd").sample("normal")
	m.national = {}
	m.awards = []
	m.teams = []
	m.postseason = (m.postseason as Array).filter(func(g): return String(g.get("tid", "")) != "nat")
	m.merge({"live": true, "national_pending": true, "awards_pending": true, "teams_pending": true, "nat_honours_pending": true,
		"remaining": {"round": "NCSA SEMIFINAL", "alive": 4},
		"leaders": [{"key": "g", "title": "GOALS", "name": "Tomas Castro", "v": 41}, {"key": "a", "title": "ASSISTS", "name": "Ezra Whitfield", "v": 27},
			{"key": "st", "title": "STEALS", "name": "Mateo Moreau", "v": 19}, {"key": "sv", "title": "SAVES", "name": "Rhys Albescu", "v": 188}],
		"recruiting": {"signed": 2, "pinned": 1, "graduating": 3, "projected": 9, "max": 10, "over": 0}}, true)
	return m

# ------------------------------------------------------------------ the sandbox
func _run(strong: bool) -> void:
	for ch in report.get_children():
		ch.queue_free()
	report.add_child(UI.label("RUNNING A SANDBOX SEASON...", 8, UI.GOLD, "caps"))
	await get_tree().process_frame
	await get_tree().process_frame
	var lines := sandbox(strong, int(Time.get_ticks_usec() & 0x7fffffff))
	if not is_inside_tree():
		return
	for ch in report.get_children():
		ch.queue_free()
	for ln in lines:
		var l := UI.label(String(ln), 8, UI.BAD if String(ln).begins_with("FAIL") else (UI.GOOD if String(ln).begins_with("OK") else UI.TEXT), "caps")
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		report.add_child(l)

## A throwaway season to elimination and on to the off-season, checked. Lines for the report.
static func sandbox(strong: bool, seed_value: int) -> Array:
	var schools: Array = Colleges.SCHOOLS.duplicate()
	schools.sort_custom(func(a, b): return float(a.ovr) < float(b.ovr))
	var pick := String(schools[schools.size() - 1 if strong else 0].short)
	var keep_pick := Difficulty.new_career_pick
	var cr := Career.new_game(pick, "Dev", "Sandbox", seed_value)
	Difficulty.new_career_pick = keep_pick   # (the New Career screen's pick is left as it was)
	cr.sandbox = true
	var out: Array = ["SCHOOL: %s (SEED %d)" % [cr.team().name.to_upper(), seed_value]]
	var guard := 400
	while cr.phase == "season" and not cr.is_eliminated() and guard > 0:
		guard -= 1
		if cr.has_game():
			cr.sim_my_game()
			cr.close_postgame()
		else:
			cr.sim_week_without_me()
			cr.end_week()
	out.append("RECORD %s (%s CONF)  -  %s" % [cr.record_text(), cr.conf_record_text(), String(cr.season.get("finish", "")).to_upper()])
	if not cr.is_eliminated():
		out.append("NOT ELIMINATED: %s" % ("WON THE NCSA" if String(cr.season.get("champion", "")) == cr.school else
			("LOST THE NCSA FINAL (OH NO! %s)" % ("QUEUED" if cr.elim_pending() else "MISSING") if cr._lost_final() else "STATE " + cr.season_state)))
		if cr._lost_final():
			out.append(("OK" if cr.elim_pending() else "FAIL") + ": A FINAL LOSS STILL GETS THE OH NO! SCREEN")
			out.append(("OK" if not cr.champ_pending() else "FAIL") + ": AND NO CHAMPIONS! SCREEN")
		elif String(cr.season.get("champion", "")) == cr.school:
			out.append(("OK" if cr.champ_pending() and not cr.elim_pending() else "FAIL") + ": THE TITLE GETS THE CHAMPIONS! SCREEN, NOT OH NO!")
			out.append(("OK" if int(cr.champ.get("us", 0)) > int(cr.champ.get("them", 0)) or not (cr.champ.get("so", []) as Array).is_empty() else "FAIL") + ": IT SHOWS THE FINAL YOU WON (%d-%d)" % [int(cr.champ.get("us", 0)), int(cr.champ.get("them", 0))])
			var back := Career.from_dict(JSON.parse_string(JSON.stringify(cr.to_dict())))
			out.append(("OK" if back.champ_pending() else "FAIL") + ": STILL TO SEE AFTER A SAVE AND LOAD")
		return out
	out.append("ELIMINATED IN WEEK %d: %s" % [cr.week + 1, String(cr.elim.get("round", ""))])
	out.append(("OK" if cr.elim_pending() else "FAIL") + ": OH NO! SCREEN QUEUED ONCE")
	out.append(("OK" if cr.week_text() == "SEASON OVER" else "FAIL") + ": HUB READS SEASON OVER")
	cr.elim["shown"] = true   # (as VIEW SEASON REVIEW does)
	var elim_round := String(cr.elim.get("round", ""))
	var xp_before := CoachEvents.xp_sum(cr.team())
	var games_before := Schedule.team_games(cr.schedule, cr.school).filter(func(e): return e[1].r != null).size()
	var weeks_left := cr.schedule.size() - cr.week
	var t0 := Time.get_ticks_msec()
	var ran := cr.sim_to_offseason()
	var ms := Time.get_ticks_msec() - t0
	out.append(("OK" if ran and cr.phase != "season" else "FAIL") + ": SIM TO OFFSEASON REACHED THE OFF-SEASON (%d WEEKS, %d MS)" % [weeks_left, ms])
	out.append(("OK" if not cr.sim_to_offseason() else "FAIL") + ": SIM TO OFFSEASON CAN'T RUN TWICE")
	out.append(("OK" if CoachEvents.xp_sum(cr.team()) == xp_before else "FAIL") + ": NO XP FOR YOUR TEAM AFTER ELIMINATION")
	out.append(("OK" if Schedule.team_games(cr.schedule, cr.school).filter(func(e): return e[1].r != null).size() == games_before else "FAIL") + ": NO NEW GAMES FOR YOUR TEAM")
	var champ := String(cr.season.get("champion", ""))
	out.append(("OK" if champ != "" and champ != cr.school else "FAIL") + ": NCSA CHAMPION DECIDED: %s" % (cr.teams[champ].name.to_upper() if cr.teams.has(champ) else "NONE"))
	out.append(("OK" if cr.history.filter(func(h): return String(h.year) == cr.season_label()).size() == 1 else "FAIL") + ": ONE SEASON IN THE HISTORY")
	out.append(("OK" if cr.season_state == Career.STATE_OFFSEASON else "FAIL") + ": STATE NOW OFFSEASON")
	out.append(("OK" if not cr.elim_pending() and String(cr.elim.get("round", "")) == elim_round else "FAIL") + ": NO SECOND OH NO! SCREEN")
	var cr2 := Career.from_dict(cr.to_dict())
	out.append(("OK" if cr2.season_state == cr.season_state and cr2.elim.size() == cr.elim.size() else "FAIL") + ": STATE SURVIVES SAVE AND LOAD")
	return out
